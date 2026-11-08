# Patient Support Chat Agent

An Agentforce Service Agent (`AI_Patient_Support_Agent`) that patients use from a website
chat window. It collects the patient's details one at a time, asks for the medical report
as a PDF, runs the existing Apex and Gemini analysis, saves the records, and explains the
result in the conversation.

> The agent explains reports in simple language. It does not diagnose conditions or
> replace a doctor. Use fictional details and the sample reports in `scripts/demo-reports`.

## Conversation Flow

1. The patient opens the chat on the website. The agent greets them, says it is not a
   doctor, and gives the emergency and crisis-helpline guidance.
2. The agent asks for each detail in turn: full name, age, gender, email and phone.
3. The agent asks the patient to upload the report as a PDF with the attachment button
   and type "done".
4. The agent calls `AgentReportIntake`, which reads the newest PDF in the conversation,
   sends it to Gemini, creates the patient and medical report records, applies the triage
   rules and links the PDF to the report.
5. The agent shows the summary, urgency, suggested next step and disclaimer. For High
   urgency it tells the patient to seek immediate medical attention and says an
   appointment request was created but is not yet confirmed.
6. Follow-up messages are answered from the patient's own results only. The agent closes
   politely when the patient is finished, and points other requests to a new chat.

## Agent Structure

The agent is defined in Agent Script:
`force-app/main/default/aiAuthoringBundles/AI_Patient_Support_Agent/AI_Patient_Support_Agent.agent`.

| Part | Purpose |
|---|---|
| Agent Router | Runs the safety check on every message, then routes it. A detected crisis goes to Urgent Help, and once the summary has been given every message goes to After Report. Other messages are routed by intent. |
| Report Intake | Collects the five details with `ask for`, asks for the PDF, runs `submit_patient_report` and presents the results. |
| After Report | Answers follow-up questions using only the patient's results and closes the conversation. |
| Urgent Help | Fixed message directing the user to emergency services or a crisis helpline. |
| Off Topic / Ambiguous Question | Explains what the agent can do and offers to continue. |

Flow control that must always happen the same way (safety check, routing after the
summary, submitting the report once all details are present) is written as
deterministic `before_reasoning` logic. Instructions for the model describe goals and
limits rather than exact phrases, so the agent can respond to how patients actually
write. Fixed wording is kept only for safety messages.

## Apex Actions

| Class | Action | Responsibility |
|---|---|---|
| `AgentReportIntake` | Submit Patient Report | Validates the details, finds the PDF (by file ID or as the newest PDF on the messaging session), checks it is a PDF under 2 MB, calls `GeminiService.analyzeReportPdf`, then creates the Patient and Medical Report, applies `MedicalReportProcessor.applyAnalysis` and links the file. The Gemini call happens before any database change, and a savepoint rolls back on errors, so a failed analysis leaves no partial records. |
| `AgentSafetyCheck` | Check Safety | Keyword check for self-harm, suicide and medical emergencies, run before the model reasons about each message. |

The triage rules and urgency-to-status mapping are shared with the original app
(`GeminiService`, `MedicalReportProcessor`), so a report analyzed in the chat follows the
same rules: High → Escalated plus an Appointment Request, Moderate → In Progress,
Low → Reviewed.

## How the PDF Upload Works

Agentforce's built-in file handling did not process uploads in this org (the agent replied
that it was unable to process the file). Instead, file handling in the agent is turned off
(`file_upload: mode: "disabled"`) and the chat channel accepts the attachment as a normal
messaging file. Salesforce stores it on the `MessagingSession` record, and
`AgentReportIntake` reads the newest PDF linked to the session. The session ID comes from
the agent's linked `RoutableId` variable, never from user input.

The agent user cannot see session files through normal sharing, so a small
`without sharing` helper reads only that session's newest PDF and links it to the new
report.

## Channel

| Component | Name |
|---|---|
| Messaging channel (Enhanced Chat) | `Patient_Support_Chat` |
| Embedded Service Deployment | `Patient_Support_Chat` |
| Omni-Channel routing flow | `Route_Messaging_To_Patient_Agent` (routes to the agent) |
| Fallback queue | `Patient_Support_Messaging` |
| Demo website | `scripts/chat-test-page/index.html` |

## Security and Access

- The agent runs as a dedicated Einstein Agent user with the Agentforce Service Agent User
  permission set and `AI_Patient_Support_Access`.
- `AI_Patient_Support_Access` includes read access to `UserExternalCredential`, which the
  agent user needs for the Gemini callout through the External Credential.
- Uploaded content is treated as data: the Gemini prompt tells the model never to follow
  instructions written inside the PDF.
- The agent only discusses the report submitted in the current conversation.

## Testing

| Test | What it covers |
|---|---|
| `AgentReportIntakeTest` (13 tests) | High/Moderate urgency, file lookup by ID and by session, missing PDF, non-PDF and oversized files, invalid details rejected before the callout, API and parsing errors leaving no records, one report per request. |
| `AgentSafetyCheckTest` (3 tests) | Crisis messages flagged, ordinary messages not flagged, empty input. |
| `AI_Patient_Support_Agent_Tests` | Agent test suite (`specs/AI_Patient_Support_Agent-testSpec.yaml`) for greetings, scope questions, off-topic and urgent-help routing. |
| `scripts/agent-tests/chat_upload_test.py` | End-to-end test through the real chat channel: answers the questions, uploads a sample PDF and prints the agent's replies. |

## Known Limitations

- **Self-harm messages:** Salesforce's built-in safety layer flags some self-harm messages
  as inappropriate content and replies with a generic refusal before the agent's own
  logic runs. The welcome message therefore always includes crisis-helpline guidance.
  Medical-emergency messages, such as chest pain, reach the agent's urgent-help reply.
- **After activation:** for a few minutes after a new agent version is activated, the chat
  service can reject new conversations or lose a message. Wait a few minutes before a
  demo.
- **Borderline reports:** the low-urgency sample is sometimes classified as Moderate.
- **File size:** PDFs must be under 2 MB (Apex heap limit for the base64-encoded callout).
- **One report per chat:** the patient starts a new chat to analyze another report.
