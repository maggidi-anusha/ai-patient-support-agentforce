public with sharing class GeminiService {

    public static String analyzeReport(String reportText) {

        HttpRequest req = new HttpRequest();

        req.setEndpoint(
'callout:Gemini_API/v1beta/models/gemini-2.5-flash:generateContent'
);

        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        String prompt =
'You are an AI healthcare assistant.\n' +
'Explain the report in simple language.\n' +
'Determine urgency as Low, Moderate, or High using these rules:\n' +
'- Low: routine findings, mild deficiencies, no immediate concern.\n' +
'- Moderate: abnormal findings that need follow-up with a doctor.\n' +
'- High: critical findings, emergency indicators, immediate medical attention needed.\n' +
'Base urgency on the findings in the report, not on whether seeing a doctor is generally advisable.\n' +
'Provide recommendation and disclaimer.\n' +
'Return ONLY JSON with fields:\n' +
'summary\n' +
'urgency\n' +
'recommendation\n' +
'disclaimer\n\n' +
'Medical Report:\n' +
reportText;
        Map<String,Object> body = new Map<String,Object>{
    'contents' => new List<Object>{
        new Map<String,Object>{
            'parts' => new List<Object>{
                new Map<String,Object>{
                    'text' => prompt
                }
            }
        }
    },
    // Temperature 0 and no thinking step keep urgency classification consistent;
    // JSON mode returns plain JSON instead of a Markdown code block
    'generationConfig' => new Map<String,Object>{
        'temperature' => 0,
        'responseMimeType' => 'application/json',
        'thinkingConfig' => new Map<String,Object>{
            'thinkingBudget' => 0
        }
    }
};

req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new GeminiApiException(
                'Gemini API returned ' + res.getStatusCode() + ' ' +
                res.getStatus() + ': ' + res.getBody().left(500)
            );
        }

Map<String,Object> responseMap =
    (Map<String,Object>)JSON.deserializeUntyped(res.getBody());

List<Object> candidates =
    (List<Object>)responseMap.get('candidates');

Map<String,Object> candidate =
    (Map<String,Object>)candidates[0];

Map<String,Object> content =
    (Map<String,Object>)candidate.get('content');

List<Object> parts =
    (List<Object>)content.get('parts');

Map<String,Object> firstPart =
    (Map<String,Object>)parts[0];

String textResponse =
    (String)firstPart.get('text');

return textResponse;
    }

    public class GeminiApiException extends Exception {}
}