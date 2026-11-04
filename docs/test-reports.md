# Sample Test Reports

Reference inputs used to check urgency classification against the live Gemini API.

| # | Report text | Expected urgency |
|---|---|---|
| 1 | Hemoglobin levels are slightly below normal. Mild iron deficiency suspected. | Low |
| 2 | Blood pressure readings consistently elevated. | Moderate |
| 3 | Chest pain with elevated cardiac markers. | High |

With the current prompt (triage rules, temperature 0, JSON mode, no thinking step), each
report returned the expected urgency in 3 out of 3 runs.
