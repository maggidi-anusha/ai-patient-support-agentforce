# 5-Minute Demo Script

**Gemini budget:** 2 API calls (one analysis, one duplicate check). The free tier allows
about 20 calls per day, so do not run test calls on demo day.

## Before the demo (the day before)

- [ ] Log in to the org (keeps it active) and run `sf org display --target-org ai-patient-org`.
- [ ] Demo data exists and is analyzed: *Chest Pain Evaluation* (High),
      *Blood Pressure Follow-up* (Moderate), *Routine Blood Test* (Low).
- [ ] Create one new, **unanalyzed** report for the live part, for example
      *Live Demo - Cardiac Assessment* for patient Aarav Sharma, with this text:
      > Sudden crushing chest pain for 30 minutes with sweating and nausea. Troponin
      > elevated. ECG shows ST elevation in the anterior leads.
- [ ] Open browser tabs: the new report, *High Urgency Reports*, *Pending Appointment
      Requests*, the dashboard, Developer Console, and the GitHub repository.
- [ ] In `scripts/apex/analyze-report.apex`, set `reportName` to the live report's name.

## Script

### 0:00 – 0:45 · Problem and solution

> "Medical reports often contain complex terminology that patients find hard to
> understand. They struggle to identify the important findings, the urgency, and what
> to do next. I built a Salesforce-based patient support system that uses the Gemini
> API to simplify report text, classify urgency, suggest next steps, and create an
> appointment request automatically for high-urgency reports. It is a
> report-understanding tool. It does not diagnose or replace a doctor."

### 0:45 – 1:15 · Data model

Setup → Object Manager (or Schema Builder):

> "Three custom objects: Patient, Medical Report, and Appointment Request. A Medical
> Report looks up to a Patient; an Appointment Request looks up to both."

### 1:15 – 2:30 · Live analysis (Gemini call 1)

1. Show the unanalyzed report: only the report text, Status = New.
2. Developer Console → Execute Anonymous → run the `analyze-report.apex` snippet.
3. Refresh the report:

> "Gemini returned a plain-language summary, the urgency, a suggested action and a
> disclaimer. Urgency is High, so the status changed to Escalated and the analysis
> date was recorded."

4. Open the **Related** tab or *Pending Appointment Requests*:

> "Because it's High urgency, an Appointment Request was created automatically with
> status New."

### 2:30 – 3:00 · Duplicate prevention (Gemini call 2)

Run the same snippet again, then refresh:

> "Before inserting, the code checks whether this report already has an appointment.
> Running the analysis again does not create a second one. The debug log says
> 'Appointment already exists'."

### 3:00 – 3:30 · Moderate and Low (no calls)

Open *Blood Pressure Follow-up* (Moderate → In Progress) and *Routine Blood Test*
(Low → Reviewed):

> "Only High urgency creates an appointment. Moderate and Low reports are updated but
> don't get one."

### 3:30 – 4:00 · Monitoring

*High Urgency Reports* list view, then the **AI Patient Monitoring Dashboard** → Refresh:

> "Staff can monitor reports by urgency, pending appointment requests, and the patient
> directory."

### 4:00 – 5:00 · Implementation and GitHub

Show in VS Code or GitHub:

- `GeminiService.cls`: callout through `callout:Gemini_API`. The API key is held in an
  encrypted External Credential, never in code. The request uses JSON mode,
  temperature 0 and triage rules for consistent results, and it checks the HTTP status.
- `MedicalReportProcessor.cls`: parsing, safe defaults, urgency → status mapping,
  duplicate check.
- Tests: 10 Apex tests with mocked callouts (no real API calls), 98–100% coverage.

> "The project is version-controlled on GitHub with a deployment manifest and a recovery
> guide, so it can be redeployed to a new org."

## If Gemini fails during the demo

If the analysis does not update the report (for example a `429` quota error):

- Open the debug log: it shows *Gemini API returned 429 Too Many Requests*.
- Explain the behaviour: "Errors are caught and logged, and the report is left
  unchanged instead of being partially updated. That is covered by a unit test."
- Continue with the already analyzed *Chest Pain Evaluation* record to show the
  results and its appointment.

## Likely questions

| Question | Short answer |
|---|---|
| How does Salesforce call Gemini? | An Apex HTTP callout through a Named Credential. |
| Where is the API key stored? | In an encrypted External Credential principal parameter, referenced by a formula in the request header. |
| How do you test without calling the API? | `HttpCalloutMock` implementations return fixed Gemini responses. |
| How did you make the AI output consistent? | JSON response mode, temperature 0, no thinking step, and explicit triage rules in the prompt. |
| How is analysis triggered? | By calling `MedicalReportProcessor.analyzeAndUpdateReport(reportId)`. Callouts can't follow DML in the same transaction, so automating it would mean moving it to a Queueable job. |
| Does it diagnose patients? | No. It explains report text in simple language, flags urgency and always includes a disclaimer. |
