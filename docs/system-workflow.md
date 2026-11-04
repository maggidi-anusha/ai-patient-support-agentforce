# System Workflow

1. A Patient record is created.
2. A Medical Report is created with the report text and linked to the patient.
3. `MedicalReportProcessor.analyzeAndUpdateReport(reportId)` is called.
4. Apex sends the report text to Gemini through the `Gemini_API` Named Credential.
5. Gemini returns JSON with `summary`, `urgency`, `recommendation` and `disclaimer`.
6. Salesforce parses the JSON and applies default values for any missing fields.
7. The Medical Report is updated with the AI fields, the analysis date and a status:

   | Urgency | Status |
   |---|---|
   | High | Escalated |
   | Moderate | In Progress |
   | Low | Reviewed |

8. If urgency is High and the report has no appointment yet, an Appointment Request
   is created with status New.
9. Staff monitor reports and appointments through list views, reports and the
   AI Patient Monitoring Dashboard.

If the Gemini call fails (for example an invalid API key or a rate limit), the error
is logged and the report is left unchanged.
