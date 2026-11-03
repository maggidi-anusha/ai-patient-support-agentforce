# Triage Rules

These rules are included in the Gemini prompt (`GeminiService.cls`).

LOW
- Routine findings
- Mild deficiencies
- No immediate concern

MODERATE
- Abnormal findings that need follow-up with a doctor

HIGH
- Critical findings
- Emergency indicators
- Immediate medical attention needed

Urgency is based on the findings in the report, not on whether seeing a doctor is
generally advisable (the model recommends a doctor for almost every report).
