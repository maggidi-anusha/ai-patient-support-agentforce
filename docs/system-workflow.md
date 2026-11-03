1. Patient submits report.

2. Report stored in Medical_Report__c.

3. Apex sends report text to Gemini.

4. Gemini returns JSON.

5. Salesforce parses JSON.

6. Medical_Report__c updated.

7. Urgency checked.

8. If HIGH:
      Create Appointment_Request__c.

9. Patient views summary.