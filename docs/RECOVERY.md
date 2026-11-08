# Recovery Guide: Deploying to a New Salesforce Org

Use this guide if the original Developer Edition org expires or becomes unavailable.
All project metadata is in this repository. Secrets (the Gemini API key) and records
are not, and must be set up again.

> Verified on 2026-11-03 in a brand-new Developer Edition org: validation (53 components,
> 10/10 tests passing), quick deploy, permission set assignment, credential configuration
> and demo data creation (steps 1–3 and 6) all succeeded. Entering the API key and the
> live Gemini call (steps 4–5) were verified in the original org.
>
> The chat agent (step 8) was added later and set up in the original org between
> 2026-11-04 and 2026-11-08. Its steps have not yet been repeated in a fresh org, so
> Setup labels may differ slightly.

## Prerequisites

- Git, Node.js and the Salesforce CLI (`npm install --global @salesforce/cli`)
- A Gemini API key from Google AI Studio (https://aistudio.google.com)

## 1. Create an org and get the code

1. Sign up for a free Developer Edition org at https://developer.salesforce.com/signup.
2. Clone the repository:

   ```bash
   git clone https://github.com/maggidi-anusha/ai-patient-support-agentforce.git
   cd ai-patient-support-agentforce
   ```

3. Authorize the CLI (opens a browser login):

   ```bash
   sf org login web --alias ai-patient-org --set-default
   ```

## 2. Deploy the project metadata

`manifest/project-package.xml` lists only this project's components: 3 custom objects
(with fields and list views), tabs, page layouts, Apex classes and tests (including the
chat agent's Apex actions), the Gemini Named and External Credentials, report types,
reports, the dashboard and the `AI_Patient_Support_Access` permission set. The chat
routing components are in a separate manifest and are deployed in step 8.

Validate first (check-only, nothing is saved):

```bash
sf project deploy validate --manifest manifest/project-package.xml --target-org ai-patient-org --test-level RunSpecifiedTests --tests GeminiServiceTest --tests MedicalReportProcessorTest --tests AgentReportIntakeTest --tests AgentSafetyCheckTest
```

Then deploy the validated job (use the Deploy ID printed by the validation):

```bash
sf project deploy quick --job-id <DEPLOY_ID> --target-org ai-patient-org
```

Deploy with the manifest rather than `--source-dir force-app`: the `force-app` folder
also contains the agent and routing metadata, which depend on setup done in step 8.

If the deployment fails on the permission set's `MessagingSession` or `MessagingEndUser`
permissions, the org does not have Messaging enabled yet. Enable it (step 8.4), then
deploy again.

## 3. Grant access

```bash
sf org assign permset --name AI_Patient_Support_Access --target-org ai-patient-org
```

This grants the three objects and all their fields, the tabs, the Apex classes and
access to the Gemini credential principal.

## 4. Add the Gemini API key (Salesforce Setup only)

The key is never stored in metadata or Git.

1. Setup → **Named Credentials** → **External Credentials** → **Gemini_External_Credential**.
2. **Principals** → `DefaultPrincipal` → **Edit**.
3. **Authentication Parameters** → **Add**: name `apiKey`, value = your Gemini API key → **Save**.
4. Check that the **Custom Header** `x-goog-api-key` has the value
   `{!$Credential.Gemini_External_Credential.apiKey}`.
5. Setup → **Named Credentials** → **Gemini_API**: confirm **Allow Formulas in HTTP Header**
   is checked (it is included in the deployed metadata).

## 5. Verify the connection

This makes one Gemini API call:

```bash
echo "System.debug(GeminiService.analyzeReport('Hemoglobin levels are slightly below normal.'));" | sf apex run --target-org ai-patient-org
```

The debug output should contain JSON with `summary`, `urgency`, `recommendation` and
`disclaimer`. If it shows `Gemini API returned 400 ... API key not valid`, re-enter the
key in step 4.

## 6. Create demo data and analyze it

```bash
sf apex run --file scripts/apex/create-demo-data.apex --target-org ai-patient-org
```

Then analyze each report, one per run (edit `reportName` in the script each time):

```bash
sf apex run --file scripts/apex/analyze-report.apex --target-org ai-patient-org
```

Demo report names: `Chest Pain Evaluation` (expected High), `Blood Pressure Follow-up`
(expected Moderate), `Routine Blood Test` (expected Low).

## 7. Check the app

- **Medical Reports** → list views *High Urgency Reports* and *Recent Medical Reports*
- **Appointment Requests** → list view *Pending Appointment Requests*
- **Dashboards** → *AI Patient Monitoring Dashboard* → **Refresh**

## Notes

- The Gemini free tier allows a limited number of requests per day (20 for
  `gemini-2.5-flash` at the time of writing). A `429` error means the quota is used up.
- Only one report can be analyzed per transaction (callout after DML is not allowed).
- Records are not part of the repository; demo data comes from `create-demo-data.apex`.
- The dashboard runs as the logged-in user (a dynamic dashboard). Developer Edition orgs
  allow only a few dynamic dashboards; if the deployment fails on the dashboard for that
  reason, delete an unused dynamic dashboard in the target org and deploy again.

## 8. Set up the chat agent

This adds the Agentforce Service Agent that patients use from a website chat window.
See [agent.md](agent.md) for how it works. Steps 1–5 must be complete first.

### 8.1 Turn on Agentforce

1. Setup → **Einstein Setup** → turn on Einstein.
2. Setup → **Agentforce Agents** → turn on Agentforce.
3. If Setup asks for Data 360 (Data Cloud), turn it on. It was enabled in the original
   org.

### 8.2 Create the agent user

1. Setup → **Users** → **New User**.
2. **User License:** Einstein Agent. **Profile:** Einstein Agent User. Use a username that
   is unique across Salesforce, for example `patient-agent@<your-domain>.com`.
3. Assign these permission sets to the user: **Agentforce Service Agent User** and
   **AI Patient Support Access**:

   ```bash
   sf org assign permset --name AI_Patient_Support_Access --on-behalf-of <agent-username> --target-org ai-patient-org
   ```

`AI Patient Support Access` includes read access to `UserExternalCredential`. Without it,
the agent's Gemini callout fails with a permissions error.

### 8.3 Publish and activate the agent

1. In `force-app/main/default/aiAuthoringBundles/AI_Patient_Support_Agent/AI_Patient_Support_Agent.agent`,
   set `default_agent_user` to the agent username from 8.2.
2. Validate, publish and activate:

   ```bash
   sf agent validate authoring-bundle --api-name AI_Patient_Support_Agent --target-org ai-patient-org
   ```

   ```bash
   sf agent publish authoring-bundle --api-name AI_Patient_Support_Agent --target-org ai-patient-org
   ```

   ```bash
   sf agent activate --api-name AI_Patient_Support_Agent --target-org ai-patient-org
   ```

   The command lists the published versions; choose the newest. After activating, wait a
   few minutes before testing the chat.

### 8.4 Create the chat channel and routing

1. Setup → **Omni-Channel Settings** → enable Omni-Channel.
2. Setup → **Messaging Settings** → **New Channel** → **Enhanced Chat**. Name it
   `Patient Support Chat` (API name `Patient_Support_Chat`).
3. Before deploying the routing components, update the org-specific values:
   - `force-app/main/default/queues/Patient_Support_Messaging.queue-meta.xml`: replace the
     `<user>` with your admin username, or remove the `<queueMembers>` block.
4. Deploy the queue, routing configuration and routing flow:

   ```bash
   sf project deploy start --manifest manifest/agent-routing-package.xml --target-org ai-patient-org
   ```

5. Open the flow **Route Messaging To Patient Agent** in Flow Builder. In the
   **Route to Agent** element, select **Patient Support Messaging** as the fallback queue
   (the queue ID in the repository belongs to the original org), then save and activate.
6. In the **Patient Support Chat** channel settings:
   - Set routing to the Omni-Channel flow **Route Messaging To Patient Agent**, with the
     fallback queue **Patient Support Messaging**.
   - Allow customers to upload files, with PDF as an allowed file type.
   - Make sure the **fallback message** is turned off. While it is on, the chat window
     always shows "Looks like something went wrong, and we can't display the
     conversation" instead of the chat.

### 8.5 Create the website chat deployment

1. Setup → **Embedded Service Deployments** → **New** → Messaging for In-App and Web →
   Web. Name it `Patient_Support_Chat` and select the **Patient Support Chat** channel.
2. Click **Publish** on the deployment. Publish again after any channel or deployment
   change; the website uses the published copy.
3. From the deployment's **Code Snippet**, note the org ID, the site URL and the
   `scrt2URL`.

### 8.6 Allow the demo website

The demo page runs at `http://localhost:8765`. Salesforce must allow that site to load
the chat:

1. Setup → **CORS** → **New**: Origin URL Pattern `http://localhost:8765`.
2. Setup → **Sites** → open the deployment's site (its URL ends in `vforcesite`) →
   **Edit** → Clickjack Protection Level **Allow framing of site pages on external
   domains (Good protection)** → **Save**. Then add `http://localhost:8765` under
   **Trusted Domains for Inline Frames**.
3. Setup → **Digital Experiences** → **All Sites** → **Builder** next to the deployment's
   site → **Settings** → **Security & Privacy**: choose the same clickjack level, add
   `http://localhost:8765` as a trusted domain, then **Publish**.

Changes can take a few minutes to reach Salesforce's chat servers.

### 8.7 Configure and open the demo website

1. In `scripts/chat-test-page/index.html`, update the values in
   `embeddedservice_bootstrap.init(...)` and the script URL from the code snippet (8.5).
   Use the **15-character** org ID: with the 18-character ID the chat window stays on
   "Reconnecting…" because the chat service rejects its live updates.
2. Start the page:

   ```bash
   python3 -m http.server 8765 --bind 127.0.0.1 --directory scripts/chat-test-page
   ```

3. Open http://localhost:8765 and follow the patient walkthrough in [DEMO.md](DEMO.md).

### 8.8 Optional: test the channel from the command line

This makes one Gemini call:

```bash
python3 -I scripts/agent-tests/chat_upload_test.py <org-id> <scrt2-url> Patient_Support_Chat http://localhost:8765 scripts/demo-reports/low-urgency-report.pdf
```

It answers the agent's questions with fictional details, uploads the PDF, types "done"
and prints the agent's replies.

### Troubleshooting the chat

| Symptom | Cause and fix |
|---|---|
| No chat button on the page; console shows a CORS error | Add the site to the CORS list (8.6) and wait a few minutes. |
| Console shows "violates … frame-ancestors" | Add the trusted framing domain on both sites (8.6). |
| "Looks like something went wrong, and we can't display the conversation" | The channel's fallback message is on. Turn it off and republish the deployment (8.4, 8.5). |
| Chat shows "Reconnecting…" and no agent replies | The embed code uses the 18-character org ID; use the 15-character one (8.7). |
| The agent says it could not analyze the report | Check the Gemini key (step 4), the daily quota, and that the agent user has `AI Patient Support Access`. |
| Errors or repeated questions just after activating a new agent version | Wait a few minutes and start a new chat. |
