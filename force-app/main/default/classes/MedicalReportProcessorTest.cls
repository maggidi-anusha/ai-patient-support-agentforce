@IsTest
private class MedicalReportProcessorTest {

    @IsTest
    static void testAnalyzeAndUpdateReport() {

        // Mock Gemini API
        Test.setMock(
            HttpCalloutMock.class,
            new GeminiMockResponse()
        );

        // Create test Medical Report
        Medical_Report__c report = new Medical_Report__c();

        report.Name = 'Test Report';

        report.Report_Text__c =
            'Hemoglobin levels are slightly low.';

        insert report;

        Test.startTest();

        MedicalReportProcessor.analyzeAndUpdateReport(
            report.Id
        );

        Test.stopTest();

        // Retrieve updated record
        Medical_Report__c updatedReport = [

            SELECT AI_Summary__c,
                   Urgency_Level__c,
                   Suggested_Action__c,
                   Disclaimer__c
            FROM Medical_Report__c
            WHERE Id = :report.Id

        ];

        System.assertNotEquals(
            null,
            updatedReport.AI_Summary__c
        );

        System.assertEquals(
            'Low',
            updatedReport.Urgency_Level__c
        );

    }

    @IsTest
    static void testHighUrgencyCreatesAppointment() {

        Medical_Report__c report = createReport('High Urgency Report');

        Test.setMock(
            HttpCalloutMock.class,
            new AnalysisMock(200, geminiBody('High'))
        );

        Test.startTest();
        MedicalReportProcessor.analyzeAndUpdateReport(report.Id);
        Test.stopTest();

        Medical_Report__c updatedReport = getReport(report.Id);

        System.assertEquals('High', updatedReport.Urgency_Level__c);
        System.assertEquals('Escalated', updatedReport.Status__c);
        System.assertEquals('Test summary', updatedReport.AI_Summary__c);
        System.assertEquals('Test recommendation', updatedReport.Suggested_Action__c);
        System.assertEquals('Test disclaimer', updatedReport.Disclaimer__c);
        System.assertNotEquals(null, updatedReport.Analysis_Date__c);

        List<Appointment_Request__c> appointments = getAppointments(report.Id);

        System.assertEquals(1, appointments.size());
        System.assertEquals('New', appointments[0].Status__c);
        System.assertEquals(report.Patient__c, appointments[0].Patient__c);

    }

    @IsTest
    static void testDuplicateAppointmentNotCreated() {

        Medical_Report__c report = createReport('Existing Appointment Report');

        // Appointment already linked to this report
        Appointment_Request__c existing = new Appointment_Request__c(
            Medical_Report__c = report.Id,
            Patient__c = report.Patient__c,
            Status__c = 'Scheduled'
        );
        insert existing;

        Test.setMock(
            HttpCalloutMock.class,
            new AnalysisMock(200, geminiBody('High'))
        );

        Test.startTest();
        MedicalReportProcessor.analyzeAndUpdateReport(report.Id);
        Test.stopTest();

        List<Appointment_Request__c> appointments = getAppointments(report.Id);

        System.assertEquals(1, appointments.size());
        System.assertEquals(existing.Id, appointments[0].Id);
        System.assertEquals('Escalated', getReport(report.Id).Status__c);

    }

    @IsTest
    static void testModerateUrgencyNoAppointment() {

        Medical_Report__c report = createReport('Moderate Urgency Report');

        Test.setMock(
            HttpCalloutMock.class,
            new AnalysisMock(200, geminiBody('Moderate'))
        );

        Test.startTest();
        MedicalReportProcessor.analyzeAndUpdateReport(report.Id);
        Test.stopTest();

        Medical_Report__c updatedReport = getReport(report.Id);

        System.assertEquals('Moderate', updatedReport.Urgency_Level__c);
        System.assertEquals('In Progress', updatedReport.Status__c);
        System.assertEquals(0, getAppointments(report.Id).size());

    }

    @IsTest
    static void testLowUrgencyNoAppointment() {

        Medical_Report__c report = createReport('Low Urgency Report');

        Test.setMock(
            HttpCalloutMock.class,
            new AnalysisMock(200, geminiBody('Low'))
        );

        Test.startTest();
        MedicalReportProcessor.analyzeAndUpdateReport(report.Id);
        Test.stopTest();

        Medical_Report__c updatedReport = getReport(report.Id);

        System.assertEquals('Low', updatedReport.Urgency_Level__c);
        System.assertEquals('Reviewed', updatedReport.Status__c);
        System.assertEquals(0, getAppointments(report.Id).size());

    }

    @IsTest
    static void testMissingFieldsUseDefaults() {

        Medical_Report__c report = createReport('Incomplete Response Report');

        // Gemini returns JSON without any of the expected fields
        Test.setMock(
            HttpCalloutMock.class,
            new AnalysisMock(200, wrapInGeminiResponse('{}'))
        );

        Test.startTest();
        MedicalReportProcessor.analyzeAndUpdateReport(report.Id);
        Test.stopTest();

        Medical_Report__c updatedReport = getReport(report.Id);

        System.assertEquals('Summary unavailable', updatedReport.AI_Summary__c);
        System.assertEquals('Consult a healthcare professional.', updatedReport.Suggested_Action__c);
        System.assertEquals('This is not medical advice.', updatedReport.Disclaimer__c);
        System.assertEquals('Moderate', updatedReport.Urgency_Level__c);
        System.assertEquals('In Progress', updatedReport.Status__c);

    }

    @IsTest
    static void testApiErrorLeavesReportUnchanged() {

        Medical_Report__c report = createReport('API Error Report');

        // Gemini error response has no candidates
        Test.setMock(
            HttpCalloutMock.class,
            new AnalysisMock(
                400,
                '{"error":{"code":400,"message":"API key not valid","status":"INVALID_ARGUMENT"}}'
            )
        );

        Test.startTest();
        MedicalReportProcessor.analyzeAndUpdateReport(report.Id);
        Test.stopTest();

        Medical_Report__c updatedReport = getReport(report.Id);

        // Errors are caught and logged, so the report is not updated
        System.assertEquals(null, updatedReport.Status__c);
        System.assertEquals(null, updatedReport.AI_Summary__c);
        System.assertEquals(null, updatedReport.Analysis_Date__c);
        System.assertEquals(0, getAppointments(report.Id).size());

    }

    // Test data and response helpers

    private static Medical_Report__c createReport(String name) {

        Patient__c patient = new Patient__c(Name = 'Test Patient');
        insert patient;

        Medical_Report__c report = new Medical_Report__c(
            Name = name,
            Patient__c = patient.Id,
            Report_Text__c = 'Sample report text.'
        );
        insert report;

        return report;
    }

    private static Medical_Report__c getReport(Id reportId) {

        return [
            SELECT AI_Summary__c,
                   Urgency_Level__c,
                   Suggested_Action__c,
                   Disclaimer__c,
                   Status__c,
                   Analysis_Date__c
            FROM Medical_Report__c
            WHERE Id = :reportId
        ];
    }

    private static List<Appointment_Request__c> getAppointments(Id reportId) {

        return [
            SELECT Id, Status__c, Patient__c
            FROM Appointment_Request__c
            WHERE Medical_Report__c = :reportId
        ];
    }

    // Builds a Gemini response whose text is the analysis JSON wrapped in a
    // Markdown code block, matching the format Gemini actually returns
    private static String geminiBody(String urgency) {

        Map<String, Object> analysis = new Map<String, Object>{
            'summary' => 'Test summary',
            'urgency' => urgency,
            'recommendation' => 'Test recommendation',
            'disclaimer' => 'Test disclaimer'
        };

        return wrapInGeminiResponse(
            '```json\n' + JSON.serialize(analysis) + '\n```'
        );
    }

    private static String wrapInGeminiResponse(String text) {

        return JSON.serialize(new Map<String, Object>{
            'candidates' => new List<Object>{
                new Map<String, Object>{
                    'content' => new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{ 'text' => text }
                        }
                    }
                }
            }
        });
    }

    private class AnalysisMock implements HttpCalloutMock {

        private Integer statusCode;
        private String body;

        AnalysisMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(body);
            return response;
        }
    }
}