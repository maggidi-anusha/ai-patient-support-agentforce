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
}