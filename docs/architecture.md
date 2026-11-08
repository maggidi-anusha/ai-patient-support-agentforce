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

## Patient Chat (Agentforce Service Agent)

The chat agent reuses the same Gemini integration and triage rules. Details:
[agent.md](agent.md).

```text
Website chat window (Enhanced Chat, Patient_Support_Chat)
   ↓
Omni-Channel flow Route_Messaging_To_Patient_Agent
   ↓
AI_Patient_Support_Agent (Agent Script)
   ├─ AgentSafetyCheck on every message → Urgent Help reply if needed
   ├─ Collects name, age, gender, email, phone (one question at a time)
   └─ Patient uploads a PDF → stored on the MessagingSession record
   ↓
AgentReportIntake.submitReport
   ├─ Reads the newest PDF on the session
   ├─ GeminiService.analyzeReportPdf(base64Pdf) ── callout:Gemini_API ──► Gemini API
   ├─ MedicalReportProcessor.parseAnalysis
   ├─ Creates Patient__c and Medical_Report__c
   ├─ MedicalReportProcessor.applyAnalysis → status, Appointment_Request__c for High
   └─ Links the PDF to the report
   ↓
Summary, urgency, next step and disclaimer shown in the chat
   ↓
After Report: follow-up questions answered from the patient's results only
```

| Component | Responsibility |
|---|---|
| `AgentReportIntake` | Invocable action for the agent: validates the details, reads the PDF, calls Gemini before any database change, creates the records and links the file. |
| `AgentSafetyCheck` | Invocable action: keyword check for self-harm and medical emergencies, run before the model reasons about each message. |
| `GeminiService.analyzeReportPdf` | Sends the PDF inline to Gemini with the same triage rules as text analysis. |
| `MedicalReportProcessor.parseAnalysis` / `applyAnalysis` | Shared parsing and urgency-to-status logic used by both the original workflow and the agent. |
