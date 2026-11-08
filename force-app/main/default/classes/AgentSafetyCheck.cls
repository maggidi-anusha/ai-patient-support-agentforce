public with sharing class AgentSafetyCheck {

    // Phrases that always get the urgent-help reply. Matching is deterministic,
    // so a safety reply never depends on the language model; it can miss
    // unusual wording, which the agent's urgent-help subagent also covers.
    @TestVisible
    private static final List<String> CRISIS_PHRASES = new List<String>{
        'kill myself', 'killing myself', 'hurt myself', 'hurting myself',
        'harm myself', 'harming myself', 'self harm', 'self-harm', 'suicide',
        'suicidal', 'end my life', 'take my life', 'want to die',
        'don\'t want to live', 'dont want to live', 'do not want to live',
        'no reason to live', 'better off dead', 'overdose',
        'chest pain', 'can\'t breathe', 'cant breathe', 'cannot breathe',
        'trouble breathing', 'difficulty breathing', 'not breathing',
        'bleeding heavily', 'heavy bleeding', 'severe bleeding',
        'unconscious', 'passed out', 'seizure', 'stroke', 'heart attack'
    };

    public class Request {
        @InvocableVariable(label='Text' description='The user message to check')
        public String text;
    }

    public class Result {
        @InvocableVariable(label='Is Crisis' description='True if the message mentions self-harm, suicide or a medical emergency')
        public Boolean isCrisis = false;
    }

    @InvocableMethod(
        label='Check Message Safety'
        description='Returns true if a message mentions self-harm, suicide or a possible medical emergency.'
    )
    public static List<Result> check(List<Request> requests) {

        List<Result> results = new List<Result>();
        for (Request request : requests) {
            Result result = new Result();
            result.isCrisis = isCrisis(request.text);
            results.add(result);
        }
        return results;
    }

    @TestVisible
    private static Boolean isCrisis(String text) {

        if (String.isBlank(text)) {
            return false;
        }

        String normalized = text.toLowerCase()
            .replace('’', '\'')
            .normalizeSpace();

        for (String phrase : CRISIS_PHRASES) {
            if (normalized.contains(phrase)) {
                return true;
            }
        }
        return false;
    }
}