@IsTest
private class AgentSafetyCheckTest {

    @IsTest
    static void testCrisisMessagesAreFlagged() {

        List<String> crisisMessages = new List<String>{
            'I feel like hurting myself',
            'I don’t want to live anymore',
            'I want to KILL MYSELF',
            'I have severe chest pain right now',
            'My father is not breathing',
            'I am bleeding heavily'
        };

        for (String message : crisisMessages) {
            System.assertEquals(true, check(message), 'Should be flagged: ' + message);
        }
    }

    @IsTest
    static void testOrdinaryMessagesAreNotFlagged() {

        List<String> ordinaryMessages = new List<String>{
            'Hi',
            'Rohan Test',
            '29',
            'Male',
            'rohan.test@example.com',
            '5550100',
            'What can you do?',
            ''
        };

        for (String message : ordinaryMessages) {
            System.assertEquals(false, check(message), 'Should not be flagged: ' + message);
        }
    }

    @IsTest
    static void testNullMessageIsNotFlagged() {
        System.assertEquals(false, check(null));
    }

    private static Boolean check(String text) {
        AgentSafetyCheck.Request request = new AgentSafetyCheck.Request();
        request.text = text;
        return AgentSafetyCheck.check(
            new List<AgentSafetyCheck.Request>{ request }
        )[0].isCrisis;
    }
}
