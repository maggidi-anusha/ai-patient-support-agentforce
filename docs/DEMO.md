# Demo Walkthrough

Two demos: the patient chat with the agent (about 3 minutes), and the original
Salesforce workflow (about 5 minutes).

## Part 1: Patient Chat with the Agent

**Gemini usage:** 1 API call per uploaded report.

### Preparation

- The agent is active and the demo website is set up ([RECOVERY.md](RECOVERY.md), step 8).
- Do not activate a new agent version just before the demo; the chat service can be
  unreliable for a few minutes afterwards.
- Start the demo website from the project folder:

  ```bash
  python3 -m http.server 8765 --bind 127.0.0.1 --directory scripts/chat-test-page
  ```

### Walkthrough

1. Open http://localhost:8765 in Chrome and click the **chat bubble** in the bottom-right
   corner. The agent joins and greets you, says it is not a doctor, and gives the
   emergency and crisis-helpline guidance.
2. Answer each question, pressing **Enter** after each one. Replies take about 5–10
   seconds. Use fictional details only:

   | The agent asks for | Type |
   |---|---|
   | Full name | `Rohan Test` |
   | Age | `29` |
   | Gender | Click **Male** (or type it) |
   | Email | `rohan.test@example.com` |
   | Phone | `5550100` |

3. When the agent asks for the report, click the **paperclip**, choose
   `scripts/demo-reports/high-urgency-report.pdf`, then type `done` and press **Enter**.
   The file and the message are sent together.
4. After about 20–40 seconds the agent shows the summary, urgency, suggested next step
   and disclaimer. For this High-urgency sample it tells the patient to seek immediate
   medical attention and says an appointment request was created but is not confirmed.
5. Ask a follow-up, for example *"What is troponin?"*. The agent explains it using only
   the patient's results. Then say *"no, that's all"*: the agent closes the conversation.
6. In Salesforce, open **Medical Reports**: the new *Uploaded Report – Rohan Test* is
   Escalated, with the PDF attached and a new **Appointment Request** (Status New).

Use `low-urgency-report.pdf` or `moderate-urgency-report.pdf` to show the other levels.

## Part 2: Salesforce Workflow

**Gemini usage:** 2 API calls (one analysis and one repeat analysis). The Gemini free tier
has a small daily request quota, so avoid other test calls on the same day.

### Preparation

- Log in to the org and confirm the CLI connection: `sf org display --target-org <alias>`.
- Create and analyze the demo data (see [RECOVERY.md](RECOVERY.md), step 6):
  *Chest Pain Evaluation* (High), *Blood Pressure Follow-up* (Moderate),
  *Routine Blood Test* (Low).
- Create one new, unanalyzed Medical Report for the live step, for example
  *Live Demo - Cardiac Assessment* for patient Aarav Sharma, with this text:
  > Sudden crushing chest pain for 30 minutes with sweating and nausea. Troponin
  > elevated. ECG shows ST elevation in the anterior leads.
- In `scripts/apex/analyze-report.apex`, set `reportName` to the new report's name.

### Walkthrough

| Time | Step | What it shows |
|---|---|---|
| 0:00 – 0:45 | Introduce the problem and the solution. | Purpose of the application and its limits (no diagnosis). |
| 0:45 – 1:15 | Setup → Object Manager or Schema Builder. | Patient, Medical Report and Appointment Request and their lookups. |
| 1:15 – 2:30 | Open the unanalyzed report (Status = New), run `analyze-report.apex` in Developer Console → Execute Anonymous, then refresh the record. | AI Summary, Urgency Level (High), Suggested Action, Disclaimer, Analysis Date and Status (Escalated) populated; a new Appointment Request with Status New in the **Related** tab. |
| 2:30 – 3:00 | Run the same script again and refresh. | Duplicate prevention: still one Appointment Request; the debug log shows "Appointment already exists". |
| 3:00 – 3:30 | Open *Blood Pressure Follow-up* and *Routine Blood Test*. | Moderate → In Progress and Low → Reviewed, with no appointment. |
| 3:30 – 4:00 | *High Urgency Reports* and *Pending Appointment Requests* list views, then **AI Patient Monitoring Dashboard** → Refresh. | Monitoring by urgency, pending appointments and the patient directory. |
| 4:00 – 5:00 | `GeminiService.cls`, `MedicalReportProcessor.cls`, the test classes and the GitHub repository. | Named Credential callout without a key in code, JSON mode and triage rules, urgency-to-status mapping, duplicate check, 10 tests with mocked callouts. |

### If the Gemini call fails

If the report is not updated (for example a `429` quota error):

1. Open the debug log: it shows `Gemini API returned <status code> ...`.
2. The report is left unchanged; this behaviour is covered by
   `MedicalReportProcessorTest.testApiErrorLeavesReportUnchanged`.
3. Continue with the already analyzed *Chest Pain Evaluation* report and its appointment.
