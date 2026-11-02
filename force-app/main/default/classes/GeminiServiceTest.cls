@IsTest
private class GeminiServiceTest {

    @IsTest
    static void testAnalyzeReport() {

        Test.setMock(
            HttpCalloutMock.class,
            new GeminiMockResponse()
        );

        Test.startTest();

        String response =
            GeminiService.analyzeReport(
                'Hemoglobin levels are slightly low.'
            );

        Test.stopTest();

        System.assertNotEquals(null, response);

        System.assert(
            response.contains('summary')
        );

    }
}