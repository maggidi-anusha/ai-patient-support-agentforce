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

    @IsTest
    static void testRequestUsesGenerationConfig() {

        RequestCaptureMock mock = new RequestCaptureMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        GeminiService.analyzeReport('Hemoglobin levels are slightly low.');
        Test.stopTest();

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(mock.requestBody);
        Map<String, Object> config =
            (Map<String, Object>) body.get('generationConfig');

        System.assertNotEquals(null, config);
        System.assertEquals(0, config.get('temperature'));
        System.assertEquals('application/json', config.get('responseMimeType'));
        System.assert(mock.requestBody.contains('Hemoglobin levels are slightly low.'));

    }

    @IsTest
    static void testApiErrorThrowsException() {

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        try {
            GeminiService.analyzeReport('Hemoglobin levels are slightly low.');
            System.assert(false, 'Expected GeminiApiException');
        } catch (GeminiService.GeminiApiException ex) {
            System.assert(ex.getMessage().contains('400'));
            System.assert(ex.getMessage().contains('API key not valid'));
        }
        Test.stopTest();

    }

    // Returns a valid response and keeps the request body for assertions
    private class RequestCaptureMock implements HttpCalloutMock {

        public String requestBody;

        public HttpResponse respond(HttpRequest req) {
            requestBody = req.getBody();
            return new GeminiMockResponse().respond(req);
        }
    }

    private class ErrorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(400);
            response.setStatus('Bad Request');
            response.setBody('{"error":{"code":400,"message":"API key not valid","status":"INVALID_ARGUMENT"}}');
            return response;
        }
    }
}