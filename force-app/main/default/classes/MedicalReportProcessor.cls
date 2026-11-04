public with sharing class MedicalReportProcessor {

    public static ReportAnalysisResponse processReport(String reportText) {

        String jsonResponse =
    GeminiService.analyzeReport(reportText);

jsonResponse = jsonResponse.replace('```json', '');
jsonResponse = jsonResponse.replace('```', '');
jsonResponse = jsonResponse.trim();

        ReportAnalysisResponse result =
            (ReportAnalysisResponse)
            JSON.deserialize(
                jsonResponse,
                ReportAnalysisResponse.class
            );

        return result;
    }
    
    public static void analyzeAndUpdateReport(Id reportId) {

    try {

        Medical_Report__c report = [
            SELECT Id,
                   Report_Text__c,
                   Patient__c,
                   Analysis_Date__c
            FROM Medical_Report__c
            WHERE Id = :reportId
        ];

        ReportAnalysisResponse response =
            processReport(report.Report_Text__c);

        if(response == null){
            return;
        }

        // Safe default values
        String summary =
            response.summary != null
            ? response.summary
            : 'Summary unavailable';

        String recommendation =
            response.recommendation != null
            ? response.recommendation
            : 'Consult a healthcare professional.';

        String disclaimer =
            response.disclaimer != null
            ? response.disclaimer
            : 'This is not medical advice.';

        // Normalize urgency
        String urgency = 'Moderate';

        if(response.urgency != null){

            String value =
                response.urgency.trim().toLowerCase();

            if(value.contains('high')){
                urgency = 'High';
            }
            else if(value.contains('low')){
                urgency = 'Low';
            }
        }
        
        String status = 'In Progress';

if(urgency == 'High'){
    status = 'Escalated';
}
else if(urgency == 'Low'){
    status = 'Reviewed';
}

        // Update Medical Report
        report.AI_Summary__c = summary;
        report.Urgency_Level__c = urgency;
        report.Suggested_Action__c = recommendation;
        report.Disclaimer__c = disclaimer;
        report.Status__c = status;
        report.Analysis_Date__c = System.now();

        update report;

        // Create appointment only for High urgency
        if(urgency == 'High'){

            List<Appointment_Request__c> existingAppointments = [
                SELECT Id
                FROM Appointment_Request__c
                WHERE Medical_Report__c = :report.Id
            ];

            if(existingAppointments.isEmpty()){

                Appointment_Request__c appointment =
                    new Appointment_Request__c();

                appointment.Patient__c = report.Patient__c;
                appointment.Medical_Report__c = report.Id;
                appointment.Status__c = 'New';

                insert appointment;

                System.debug('Appointment created');

            }
            else{

                System.debug('Appointment already exists');

            }
        }

    }
    catch(Exception ex){

    System.debug(
        'ERROR MESSAGE: ' +
        ex.getMessage()
    );

    System.debug(
        'LINE NUMBER: ' +
        ex.getLineNumber()
    );

}
}
}