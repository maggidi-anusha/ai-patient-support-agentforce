public with sharing class AgentReportIntake {

    // Base64 encoding makes the callout body larger than the file, and sync Apex
    // has a 6 MB heap limit, so uploads are limited to 2 MB
    @TestVisible
    private static Integer maxFileBytes = 2 * 1024 * 1024;

    // The base64 encoding of '%PDF', the first bytes of every PDF file
    private static final String PDF_BASE64_PREFIX = 'JVBERi';

    private static final Map<String, String> GENDER_VALUES = new Map<String, String>{
        'male' => 'Male',
        'female' => 'Female',
        'other' => 'Other',
        'prefer not to say' => 'Prefer not to say'
    };

    public class Request {
        @InvocableVariable(label='Patient Name' description='Full name of the patient' required=true)
        public String patientName;

        @InvocableVariable(label='Age' description='Age of the patient in years' required=true)
        public Decimal age;

        @InvocableVariable(label='Gender' description='Male, Female, Other or Prefer not to say' required=true)
        public String gender;

        @InvocableVariable(label='Email' description='Email address of the patient' required=true)
        public String email;

        @InvocableVariable(label='Phone' description='Phone number of the patient' required=true)
        public String phone;

        @InvocableVariable(label='File Id' description='Id of the PDF report uploaded in this conversation' required=true)
        public String fileId;

        @InvocableVariable(label='File Name' description='Name of the uploaded file')
        public String fileName;

        @InvocableVariable(label='File MIME Type' description='MIME type of the uploaded file')
        public String mimeType;
    }

    public class Result {
        @InvocableVariable(label='Success' description='True if the report was analyzed and saved')
        public Boolean success = false;

        @InvocableVariable(label='Message' description='Explanation to give the patient if the report could not be processed')
        public String message;

        @InvocableVariable(label='Summary' description='Plain-language summary of the report')
        public String summary;

        @InvocableVariable(label='Urgency' description='Low, Moderate or High')
        public String urgency;

        @InvocableVariable(label='Suggested Action' description='Suggested next step')
        public String suggestedAction;

        @InvocableVariable(label='Disclaimer' description='Medical disclaimer to show with the summary')
        public String disclaimer;

        @InvocableVariable(label='Appointment Created' description='True if an appointment request was created')
        public Boolean appointmentCreated = false;
    }

    private class IntakeException extends Exception {}

    @InvocableMethod(
        label='Submit Patient Report'
        description='Creates the patient and medical report from an uploaded PDF, analyzes it with Gemini, and returns the summary.'
    )
    public static List<Result> submitReport(List<Request> requests) {

        List<Result> results = new List<Result>();

        for (Integer i = 0; i < requests.size(); i++) {
            // A callout can't follow the database changes made for an earlier
            // request in the same transaction, so only one report is processed
            results.add(
                i == 0
                    ? processRequest(requests[i])
                    : failure('Only one report can be submitted at a time.')
            );
        }

        return results;
    }

    private static Result processRequest(Request request) {

        Savepoint sp;

        try {
            String gender = validateDetails(request);
            ContentVersion file = findFile(request);
            String base64Pdf = readPdf(file);

            // The callout runs before any database change, so a failed
            // analysis leaves no partial records behind
            ReportAnalysisResponse analysis = MedicalReportProcessor.parseAnalysis(
                GeminiService.analyzeReportPdf(base64Pdf)
            );

            sp = Database.setSavepoint();

            Patient__c patient = new Patient__c(
                Name = request.patientName.trim().abbreviate(80),
                Age__c = request.age.intValue(),
                Gender__c = gender,
                Email__c = request.email.trim(),
                Phone__c = request.phone.trim()
            );
            insert patient;

            Medical_Report__c report = new Medical_Report__c(
                Name = ('Uploaded Report - ' + patient.Name).abbreviate(80),
                Patient__c = patient.Id,
                Report_Text__c = 'Uploaded PDF report: ' + file.Title,
                Status__c = 'New'
            );
            insert report;

            Boolean appointmentCreated =
                MedicalReportProcessor.applyAnalysis(report, analysis);

            linkFile(file.ContentDocumentId, report.Id);

            Result result = new Result();
            result.success = true;
            result.summary = report.AI_Summary__c;
            result.urgency = report.Urgency_Level__c;
            result.suggestedAction = report.Suggested_Action__c;
            result.disclaimer = report.Disclaimer__c;
            result.appointmentCreated = appointmentCreated;
            return result;

        } catch (IntakeException ex) {
            return failure(ex.getMessage());

        } catch (Exception ex) {
            if (sp != null) {
                Database.rollback(sp);
            }
            System.debug(LoggingLevel.ERROR, 'AGENT_INTAKE_ERROR ' + ex.getMessage());
            return failure(
                'We could not analyze your report right now. Please try again later.'
            );
        }
    }

    private static String validateDetails(Request request) {

        if (String.isBlank(request.patientName)) {
            throw new IntakeException('Please provide the patient name.');
        }
        if (request.age == null || request.age < 0 || request.age > 130) {
            throw new IntakeException('Please provide a valid age.');
        }
        if (String.isBlank(request.email) ||
            !Pattern.matches('[^@\\s]+@[^@\\s]+\\.[^@\\s]+', request.email.trim())) {
            throw new IntakeException('Please provide a valid email address.');
        }
        if (String.isBlank(request.phone)) {
            throw new IntakeException('Please provide a phone number.');
        }

        String gender = String.isBlank(request.gender)
            ? null
            : GENDER_VALUES.get(request.gender.trim().toLowerCase());
        if (gender == null) {
            throw new IntakeException(
                'Please choose a gender: Male, Female, Other or Prefer not to say.'
            );
        }
        return gender;
    }

    private static ContentVersion findFile(Request request) {

        String fileId = request.fileId;
        String prefix = String.isBlank(fileId) ? '' : fileId.left(3);

        // Diagnostic detail only: no file content and no file URL
        System.debug(
            'AGENT_INTAKE_FILE prefix=' + prefix +
            ' mimeType=' + request.mimeType + ' name=' + request.fileName
        );

        List<ContentVersion> files;
        if (prefix == '068') {
            files = [
                SELECT Title, ContentDocumentId, ContentSize, FileExtension
                FROM ContentVersion
                WHERE Id = :fileId
                LIMIT 1
            ];
        } else if (prefix == '069') {
            files = [
                SELECT Title, ContentDocumentId, ContentSize, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId = :fileId AND IsLatest = true
                LIMIT 1
            ];
        } else {
            files = new List<ContentVersion>();
        }

        if (files.isEmpty()) {
            throw new IntakeException(
                'We could not read the uploaded file. Please upload your PDF report again.'
            );
        }

        ContentVersion file = files[0];
        if (file.ContentSize > maxFileBytes) {
            throw new IntakeException(
                'That file is too large. Please upload a PDF smaller than 2 MB.'
            );
        }
        return file;
    }

    private static String readPdf(ContentVersion file) {

        String base64Pdf = EncodingUtil.base64Encode(
            [SELECT VersionData FROM ContentVersion WHERE Id = :file.Id].VersionData
        );

        if (!base64Pdf.startsWith(PDF_BASE64_PREFIX)) {
            throw new IntakeException('Please upload your report as a PDF file.');
        }
        return base64Pdf;
    }

    private static void linkFile(Id contentDocumentId, Id reportId) {
        // The analysis is already saved, so failing to attach the file
        // should not lose the patient's summary
        try {
            insert new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = reportId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
        } catch (DmlException ex) {
            System.debug(LoggingLevel.ERROR, 'AGENT_INTAKE_LINK_ERROR ' + ex.getMessage());
        }
    }

    private static Result failure(String message) {
        Result result = new Result();
        result.message = message;
        return result;
    }
}