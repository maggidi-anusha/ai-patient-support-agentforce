# Architecture

```text
Patient__c
   ↓ (lookup)
Medical_Report__c  ── Report_Text__c
   ↓
MedicalReportProcessor.analyzeAndUpdateReport(reportId)
   ↓
GeminiService.analyzeReport(reportText)
   ↓  HTTP POST via Named Credential (callout:Gemini_API)
Gemini API (gemini-2.5-flash, JSON response mode)
   ↓
JSON response → ReportAnalysisResponse
   ↓
Medical_Report__c updated
   (AI_Summary__c, Urgency_Level__c, Suggested_Action__c,
    Disclaimer__c, Status__c, Analysis_Date__c)
   ↓
If Urgency = High and no existing appointment for the report
   ↓
Appointment_Request__c created (Status = New)
```

## Components

| Component | Responsibility |
|---|---|
| `GeminiService` | Builds the prompt, calls Gemini through the `Gemini_API` Named Credential, checks the HTTP status and returns the model's text. |
| `MedicalReportProcessor` | Loads the report, parses the AI response, applies safe defaults, maps urgency to status, updates the report and creates an appointment for High urgency (with a duplicate check). |
| `ReportAnalysisResponse` | Wrapper class for JSON deserialization (`summary`, `urgency`, `recommendation`, `disclaimer`). |
| `Gemini_API` (Named Credential) | Base URL `https://generativelanguage.googleapis.com`. |
| `Gemini_External_Credential` | Sends the `x-goog-api-key` header from an encrypted principal parameter (`apiKey`). |

## Trigger

Analysis is started explicitly by calling `MedicalReportProcessor.analyzeAndUpdateReport(reportId)`
(for example from Anonymous Apex). There is no trigger or Flow.

Each call makes an HTTP callout followed by DML, so only one report can be analyzed per
transaction. Moving the call into a Queueable job (`Database.AllowsCallouts`) would allow
automatic or bulk processing.
