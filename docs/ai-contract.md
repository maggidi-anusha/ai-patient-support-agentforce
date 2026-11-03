# AI Response Contract

Gemini is asked to return JSON with these four fields. `ReportAnalysisResponse.cls`
deserializes it, and `MedicalReportProcessor` maps it to the Medical Report.

```json
{
  "summary": "Simple explanation of the report",
  "urgency": "Low | Moderate | High",
  "recommendation": "Suggested next action",
  "disclaimer": "This is not medical advice"
}
```

| JSON field | Medical Report field | Default if missing |
|---|---|---|
| `summary` | `AI_Summary__c` | `Summary unavailable` |
| `urgency` | `Urgency_Level__c` | `Moderate` |
| `recommendation` | `Suggested_Action__c` | `Consult a healthcare professional.` |
| `disclaimer` | `Disclaimer__c` | `This is not medical advice.` |

Urgency is normalized case-insensitively: a value containing "high" becomes `High`, one
containing "low" becomes `Low`, and anything else becomes `Moderate`.
