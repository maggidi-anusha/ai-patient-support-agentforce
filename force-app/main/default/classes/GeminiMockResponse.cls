@IsTest
global class GeminiMockResponse implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse response = new HttpResponse();

        response.setStatusCode(200);

        response.setBody(
            '{"candidates":[{"content":{"parts":[{"text":"{\\"summary\\":\\"Mild iron deficiency detected\\",\\"urgency\\":\\"Low\\",\\"recommendation\\":\\"Consult your doctor for dietary advice\\",\\"disclaimer\\":\\"AI-generated content only\\"}"}]}}]}'
        );

        return response;
    }
}