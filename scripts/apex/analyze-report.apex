// Analyzes one Medical Report with Gemini and prints the result.
// Change reportName, then run:
//   sf apex run --file scripts/apex/analyze-report.apex --target-org <alias>
// or paste into Developer Console > Debug > Open Execute Anonymous Window.
//
// Each run makes one Gemini API call. Analyze one report per run: Salesforce does not
// allow a callout after a database update in the same transaction.

String reportName = 'Chest Pain Evaluation';

Medical_Report__c report = [
    SELECT Id FROM Medical_Report__c WHERE Name = :reportName ORDER BY CreatedDate DESC LIMIT 1
];

MedicalReportProcessor.analyzeAndUpdateReport(report.Id);

Medical_Report__c result = [
    SELECT Name, Urgency_Level__c, Status__c, Analysis_Date__c, AI_Summary__c,
           (SELECT Name, Status__c FROM Appointment_Requests__r)
    FROM Medical_Report__c
    WHERE Id = :report.Id
];

System.debug('RESULT ' + result.Name + ' | Urgency: ' + result.Urgency_Level__c +
    ' | Status: ' + result.Status__c + ' | Analysis Date: ' + result.Analysis_Date__c +
    ' | Appointments: ' + result.Appointment_Requests__r.size());
System.debug('SUMMARY ' + result.AI_Summary__c);
