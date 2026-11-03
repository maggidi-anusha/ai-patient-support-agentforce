// Creates three fictional demo patients, each with one unanalyzed medical report
// (one expected High, one Moderate, one Low). Safe to run more than once:
// patients and reports that already exist are skipped.
//
// Run: sf apex run --file scripts/apex/create-demo-data.apex --target-org <alias>

Map<String, Patient__c> patients = new Map<String, Patient__c>{
    'Aarav Sharma' => new Patient__c(Name = 'Aarav Sharma', Age__c = 58, Gender__c = 'Male',
        Email__c = 'aarav.sharma@example.com', Notes__c = 'Fictional demo patient.'),
    'Meera Iyer' => new Patient__c(Name = 'Meera Iyer', Age__c = 46, Gender__c = 'Female',
        Email__c = 'meera.iyer@example.com', Notes__c = 'Fictional demo patient.'),
    'Rohan Das' => new Patient__c(Name = 'Rohan Das', Age__c = 29, Gender__c = 'Male',
        Email__c = 'rohan.das@example.com', Notes__c = 'Fictional demo patient.')
};

for (Patient__c existing : [SELECT Id, Name FROM Patient__c WHERE Name IN :patients.keySet()]) {
    patients.get(existing.Name).Id = existing.Id;
}

List<Patient__c> newPatients = new List<Patient__c>();
for (Patient__c p : patients.values()) {
    if (p.Id == null) {
        newPatients.add(p);
    }
}
insert newPatients;

Map<String, Medical_Report__c> reports = new Map<String, Medical_Report__c>{
    'Chest Pain Evaluation' => new Medical_Report__c(
        Name = 'Chest Pain Evaluation',
        Patient__c = patients.get('Aarav Sharma').Id,
        Status__c = 'New',
        Report_Text__c =
            'Patient reports chest pain radiating to the left arm for the past two hours, ' +
            'with shortness of breath and sweating. Troponin I is elevated at 2.4 ng/mL ' +
            '(reference < 0.04 ng/mL). ECG shows ST-segment elevation in leads II, III and aVF.'
    ),
    'Blood Pressure Follow-up' => new Medical_Report__c(
        Name = 'Blood Pressure Follow-up',
        Patient__c = patients.get('Meera Iyer').Id,
        Status__c = 'New',
        Report_Text__c =
            'Blood pressure readings over the past four weeks have been consistently elevated, ' +
            'averaging 148/94 mmHg. No chest pain, headache or vision changes reported. ' +
            'Kidney function and electrolytes are within normal limits.'
    ),
    'Routine Blood Test' => new Medical_Report__c(
        Name = 'Routine Blood Test',
        Patient__c = patients.get('Rohan Das').Id,
        Status__c = 'New',
        Report_Text__c =
            'Complete blood count: hemoglobin 11.8 g/dL (reference 13.5-17.5 g/dL), slightly below normal. ' +
            'Ferritin mildly low. White blood cell and platelet counts are normal. ' +
            'Findings suggest mild iron deficiency.'
    )
};

for (Medical_Report__c existing : [SELECT Name FROM Medical_Report__c WHERE Name IN :reports.keySet()]) {
    reports.remove(existing.Name);
}
insert reports.values();

System.debug('DEMO_DATA patients created: ' + newPatients.size() + ', reports created: ' + reports.size());
