@IsTest
private class AgentReportIntakeTest {

    @IsTest
    static void testHighUrgencyCreatesRecordsAndAppointment() {

        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, geminiBody('High')));

        Test.startTest();
        AgentReportIntake.Result result = submit(request(file.Id));
        Test.stopTest();

        System.assertEquals(true, result.success, 'Message: ' + result.message);
        System.assertEquals('High', result.urgency);
        System.assertEquals('Test summary', result.summary);
        System.assertEquals('Test recommendation', result.suggestedAction);
        System.assertEquals('Test disclaimer', result.disclaimer);
        System.assertEquals(true, result.appointmentCreated);

        Patient__c patient = [
            SELECT Name, Age__c, Gender__c, Email__c, Phone__c FROM Patient__c
        ];
        System.assertEquals('Test Patient', patient.Name);
        System.assertEquals(40, patient.Age__c);
        System.assertEquals('Female', patient.Gender__c);

        Medical_Report__c report = [
            SELECT Patient__c, Status__c, Urgency_Level__c, Analysis_Date__c, Report_Text__c
            FROM Medical_Report__c
        ];
        System.assertEquals(patient.Id, report.Patient__c);
        System.assertEquals('Escalated', report.Status__c);
        System.assertNotEquals(null, report.Analysis_Date__c);
        System.assert(report.Report_Text__c.contains('Sample Report'));

        Appointment_Request__c appointment = [
            SELECT Patient__c, Medical_Report__c, Status__c FROM Appointment_Request__c
        ];
        System.assertEquals('New', appointment.Status__c);
        System.assertEquals(patient.Id, appointment.Patient__c);
        System.assertEquals(report.Id, appointment.Medical_Report__c);

        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :report.Id
        ]);
    }

    @IsTest
    static void testModerateUrgencyNoAppointment() {

        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, geminiBody('Moderate')));

        Test.startTest();
        AgentReportIntake.Result result = submit(request(file.Id));
        Test.stopTest();

        System.assertEquals(true, result.success, 'Message: ' + result.message);
        System.assertEquals('Moderate', result.urgency);
        System.assertEquals(false, result.appointmentCreated);
        System.assertEquals(0, [SELECT COUNT() FROM Appointment_Request__c]);
        System.assertEquals('In Progress', [SELECT Status__c FROM Medical_Report__c].Status__c);
    }

    @IsTest
    static void testContentDocumentIdIsAccepted() {

        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, geminiBody('Low')));

        Test.startTest();
        AgentReportIntake.Result result = submit(request(file.ContentDocumentId));
        Test.stopTest();

        System.assertEquals(true, result.success, 'Message: ' + result.message);
        System.assertEquals('Low', result.urgency);
    }

    @IsTest
    static void testNonPdfFileIsRejected() {

        ContentVersion file = createFile(Blob.valueOf('this is not a pdf'));

        Test.startTest();
        AgentReportIntake.Result result = submit(request(file.Id));
        Test.stopTest();

        assertRejected(result, 'PDF');
    }

    @IsTest
    static void testOversizedFileIsRejected() {

        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));
        AgentReportIntake.maxFileBytes = 1;

        Test.startTest();
        AgentReportIntake.Result result = submit(request(file.Id));
        Test.stopTest();

        assertRejected(result, 'too large');
    }

    @IsTest
    static void testUnknownFileIdIsRejected() {

        AgentReportIntake.Request input = request('not-a-salesforce-id');

        Test.startTest();
        AgentReportIntake.Result result = submit(input);
        Test.stopTest();

        assertRejected(result, 'upload your PDF report again');
    }

    @IsTest
    static void testInvalidDetailsAreRejectedBeforeCallout() {

        // No mock is set: reaching the callout would make the test fail
        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));

        AgentReportIntake.Request badEmail = request(file.Id);
        badEmail.email = 'not-an-email';

        AgentReportIntake.Request badAge = request(file.Id);
        badAge.age = 200;

        AgentReportIntake.Request badGender = request(file.Id);
        badGender.gender = 'Unknown';

        AgentReportIntake.Request noName = request(file.Id);
        noName.patientName = ' ';

        AgentReportIntake.Request noPhone = request(file.Id);
        noPhone.phone = '';

        Test.startTest();
        assertRejected(submit(badEmail), 'email');
        assertRejected(submit(badAge), 'age');
        assertRejected(submit(badGender), 'gender');
        assertRejected(submit(noName), 'name');
        assertRejected(submit(noPhone), 'phone');
        Test.stopTest();
    }

    @IsTest
    static void testApiErrorSavesNothing() {

        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));
        Test.setMock(HttpCalloutMock.class, new GeminiMock(429, '{"error":{"code":429}}'));

        Test.startTest();
        AgentReportIntake.Result result = submit(request(file.Id));
        Test.stopTest();

        assertRejected(result, 'try again later');
    }

    @IsTest
    static void testUnreadableAiResponseSavesNothing() {

        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));
        Test.setMock(
            HttpCalloutMock.class,
            new GeminiMock(200, wrapInGeminiResponse('this is not json'))
        );

        Test.startTest();
        AgentReportIntake.Result result = submit(request(file.Id));
        Test.stopTest();

        assertRejected(result, 'try again later');
    }

    @IsTest
    static void testDatabaseErrorSavesNothing() {

        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, geminiBody('Low')));

        // Valid for the action's checks, but too long for the Phone__c field
        AgentReportIntake.Request input = request(file.Id);
        input.phone = '1'.repeat(500);

        Test.startTest();
        AgentReportIntake.Result result = submit(input);
        Test.stopTest();

        assertRejected(result, 'try again later');
    }

    @IsTest
    static void testOnlyOneReportPerRequest() {

        ContentVersion file = createFile(Blob.valueOf('%PDF-1.4 sample'));
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, geminiBody('Low')));

        Test.startTest();
        List<AgentReportIntake.Result> results = AgentReportIntake.submitReport(
            new List<AgentReportIntake.Request>{ request(file.Id), request(file.Id) }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Message: ' + results[0].message);
        System.assertEquals(false, results[1].success);
        System.assertEquals(1, [SELECT COUNT() FROM Medical_Report__c]);
    }

    private static void assertRejected(AgentReportIntake.Result result, String expectedText) {
        System.assertEquals(false, result.success);
        System.assert(
            result.message.containsIgnoreCase(expectedText),
            'Unexpected message: ' + result.message
        );
        System.assertEquals(0, [SELECT COUNT() FROM Patient__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Medical_Report__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Appointment_Request__c]);
    }

    private static AgentReportIntake.Result submit(AgentReportIntake.Request input) {
        return AgentReportIntake.submitReport(
            new List<AgentReportIntake.Request>{ input }
        )[0];
    }

    private static AgentReportIntake.Request request(String fileId) {
        AgentReportIntake.Request input = new AgentReportIntake.Request();
        input.patientName = 'Test Patient';
        input.age = 40;
        input.gender = 'female';
        input.email = 'test.patient@example.com';
        input.phone = '5550100';
        input.fileId = fileId;
        input.fileName = 'Sample Report.pdf';
        input.mimeType = 'application/pdf';
        return input;
    }

    private static ContentVersion createFile(Blob data) {
        ContentVersion file = new ContentVersion(
            Title = 'Sample Report',
            PathOnClient = 'Sample Report.pdf',
            VersionData = data
        );
        insert file;
        return [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :file.Id];
    }

    private static String geminiBody(String urgency) {
        return wrapInGeminiResponse(JSON.serialize(new Map<String, Object>{
            'summary' => 'Test summary',
            'urgency' => urgency,
            'recommendation' => 'Test recommendation',
            'disclaimer' => 'Test disclaimer'
        }));
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

    private class GeminiMock implements HttpCalloutMock {

        private Integer statusCode;
        private String body;

        GeminiMock(Integer statusCode, String body) {
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
