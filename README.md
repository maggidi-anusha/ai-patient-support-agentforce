# AI Patient Support & Medical Report Simplifier
An AI-powered Salesforce application that analyzes medical reports, simplifies complex medical terminology, determines urgency levels, and automatically creates appointment requests for critical cases.

# Problem Statement
Medical reports often contain complex terminology that patients may find difficult to understand. Delays in identifying critical conditions can negatively impact patient care.
This project aims to bridge that gap by leveraging Artificial Intelligence to simplify reports and improve healthcare workflows.

# Solution
The application integrates Salesforce with Google's Gemini API to:
-  Simplify medical reports
-  Determine urgency levels
-  Generate recommendations
-  Generate disclaimers
-  Update report status automatically
-  Create appointment requests for critical cases

# Features
AI Features
-  Medical report simplification using Gemini AI
-  Urgency classification (Low, Moderate, High)
-  Suggested actions for patients
-  Disclaimer generation

Salesforce Features
-  Custom Objects
-  Page Layouts
-  List Views
-  Reports
-  Dashboards

Automation Features
-  Automatic appointment creation for high urgency reports
-  Duplicate appointment prevention
-  Analysis date tracking
-  Status updates based on urgency

Technical Features
-  Apex Classes
-  HTTP Callouts
-  JSON Parsing
-  Exception Handling
-  Test Classes

# Tech Stack
-  Salesforce Platform
-  Apex
-  SOQL
-  HTTP Callouts
-  Gemini API
-  JSON Serialization / Deserialization
-  Reports & Dashboards
-  Git & GitHub

# Custom Objects
- Patient : Stores patient information.
- Medical Report :
Stores
	-Report text
	-AI Summary
	-Urgency Level
	-Suggested Action
	-Disclaimer
	-Analysis Date
	-Status
- Appointment Request : Stores appointment requests generated for critical cases.

# Reports Created
-	Medical Reports by Urgency
-	Appointment Requests Overview
-	Patient Directory

# Dashboard
- AI Patient Monitoring Dashboard
Includes:
	-Medical Reports widget
	-Appointment Requests widget
	-Patient Directory widget

# List Views
Medical Reports
-	High Urgency Reports
-	Recent Medical Reports
Appointment Requests
-	Pending Appointment Requests

# Architecture

```text
Medical Report Created
        ↓
Gemini API Analysis
        ↓
AI Summary Generated
        ↓
Urgency Assigned
        ↓
Status Updated
        ↓
Suggested Action Generated
        ↓
Analysis Date Stored
        ↓
Appointment Request Created
        ↓
Dashboard Updated
```

# Workflow
1. User creates a Medical Report.
2. Apex sends report text to Gemini API.
3. AI generates summary and urgency level.
4. Salesforce updates the Medical Report.
5. High urgency cases trigger appointment creation.
6. Reports and dashboards provide monitoring.

# Testing
The project includes:
-  GeminiServiceTest
-  MedicalReportProcessorTest
Both test classes execute successfully and provide coverage for the core business logic.

# Challenges Faced
JSON Parsing Errors : Gemini responses occasionally returned Markdown code blocks.
Solution : Removed code fences before JSON deserialization.

Null Pointer Exceptions : Missing values caused failures.
Solution : Added null checks and default values.

Duplicate Appointment Creation : Repeated execution created duplicate records.
Solution : Implemented duplicate-check logic before insertion.

Metadata Retrieval Issues : Retrieving the whole org introduced unnecessary metadata.
Solution : Planned repository cleanup to retain only project-specific files.

Salesforce CLI Issues : Source tracking and org retrieval caused errors.
Solution : Used proper target org configuration and corrected retrieval commands.

# Setup Instructions
1. Clone the repository.
2. Authorize your Salesforce org.
3. Deploy metadata to the org.
4. Configure Named Credentials for Gemini API.
5. Run Apex tests.
6. Create sample Medical Report records.
7. Execute `MedicalReportProcessor` to analyze reports.

# Project Structure
ai-patient-support-agentforce

```text
├── force-app/              # Salesforce metadata and source code
├── screenshots/            # Project screenshots
├── scripts/                # Utility scripts
├── config/                 # Project configuration
├── README.md               # Project documentation
├── project-notes.txt       # Development notes
├── interview-notes.txt     # Interview preparation notes
├── package.xml
└── sfdx-project.json
```

# Project Screenshots

## Gemini API Integration Success

![Gemini Integration](screenshots/day4-gemini-success.png)

## Medical Report Analysis

![Medical Report](screenshots/day10-medical-report.png)

## Appointment Request

![Appointment Request](screenshots/day10-appointment-request.png)

## Dashboard

![Dashboard](screenshots/day10-dashboard.png)

## High Urgency Reports List View

![List View](screenshots/day10-high-urgency-list.png)

## Apex Test Results

![Test Results](screenshots/day10-test-results.png)



# Future Enhancements
-  Lightning Web Components (LWC)
-  Email notifications for critical cases
-  Agentforce integration
-  Enhanced analytics
-  Electronic Health Record (EHR) integration

# Author
**Anusha Maggidi**
-Aspiring Software Developer passionate about building AI-powered solutions and solving real-world problems through technology.
GitHub: https://github.com/maggidi-anusha