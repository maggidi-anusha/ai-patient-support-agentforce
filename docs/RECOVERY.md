# Recovery Guide: Deploying to a New Salesforce Org

Use this guide if the original Developer Edition org expires or becomes unavailable.
All project metadata is in this repository. Secrets (the Gemini API key) and records
are not, and must be set up again.

> Status: the deployment manifest has been validated (check-only deploy, all tests
> passing) against the original org. A full deployment to a brand-new org has not
> been performed yet.

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
(with fields and list views), tabs, page layouts, Apex classes and tests, the Gemini
Named and External Credentials, report types, reports, the dashboard and the
`AI_Patient_Support_Access` permission set.

Validate first (check-only, nothing is saved):

```bash
sf project deploy validate --manifest manifest/project-package.xml --target-org ai-patient-org --test-level RunSpecifiedTests --tests GeminiServiceTest --tests MedicalReportProcessorTest
```

Then deploy the validated job (use the Deploy ID printed by the validation):

```bash
sf project deploy quick --job-id <DEPLOY_ID> --target-org ai-patient-org
```

The manifest and the `force-app` folder contain the same components, so
`sf project deploy start --source-dir force-app` works too; the manifest makes the
deployment scope explicit.

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
