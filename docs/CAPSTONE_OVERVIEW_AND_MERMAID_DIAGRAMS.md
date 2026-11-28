# JobKonek — Capstone Overview and Mermaid Diagrams

**Codebase reviewed:** C:/Users/Admin/Desktop/Prototype
**Review date:** 23 October 2026
**Modeling basis:** Current Flutter/React clients, Node.js/Express API, MongoDB/GridFS data paths, Firebase Authentication, Gemini integration, Go Mini-AI, and recent project test checkpoints.

## 1. Recommended Capstone Overview

JobKonek is an AI-assisted employment-services prototype for jobseekers and the Public Employment Service Office (PESO) in Rodriguez (Montalban), Rizal. Its integrated Flutter application supports jobseeker profiles, NSRP Form 1 and resume preparation through an embedded React workspace, vacancy browsing, job-specific screening, application tracking, and a role-controlled IT Admin area.

Firebase Authentication provides account identity, while a protected Node.js/Express API verifies identity tokens and applies role, ownership, and required eligibility checks. MongoDB Atlas stores profiles, vacancies, applications, preferences, outcomes, and ingestion metadata, while GridFS stores private resume and document files. Server-side Gemini supports profile extraction and processing of configured public PESO PDF sources. The developers built the Mini-AI training/evaluation pipeline and inference runtime in Go rather than Python, targeting fast, lightweight CPU execution. Its job-fit and career-guidance results are advisory. PESO Jobseeker and IT Admin are the only application roles: jobseekers browse gathered vacancies and submit applications, while IT Admin maintains the system rather than making PESO hiring decisions. The prototype is configured for a unified site, but full production-authenticated acceptance and operational privacy/security review must be evidenced separately.

## 2. High-Level System Workflow (Flowchart)

This is the workflow/activity view. The true DFD Level 0 context diagram is in Section 3.

~~~mermaid
flowchart TB
    subgraph Applicant["PESO Jobseeker Workflow"]
        direction TB
        A0([Start]) --> A1["Register or sign in"]
        A1 --> A2["Firebase Authentication"]
        A2 --> A3["API verifies identity and access"]
        A3 --> A4["Complete or update profile"]
        A4 --> A5["Create NSRP Form 1 or resume in embedded React workspace"]
        A5 --> A6["Save profile and private documents"]
        A6 --> A7["Browse active Walk-in and LRA vacancies"]
        A7 --> A8["Optional Go-implemented Mini-AI job-fit guidance, designed for fast CPU execution"]
        A8 --> A9["Select vacancy and answer screening questions"]
        A9 --> A10{"PESO residency verified?"}
        A10 -->|No| A11["Submit or update residency details and await review"]
        A11 --> A10
        A10 -->|Yes| A12["Submit application through the API"]
        A12 --> A13["View application history and status updates"]
    end

    subgraph Admin["IT Admin System Operations"]
        direction TB
        P0["IT Admin"] --> P1["Maintain job records and system configuration"]
        P0 --> P2["Manage accounts and required profile records"]
        P0 --> P3["Configure AI services and public-PDF ingestion"]
        P0 --> P4["Export available application/report data"]
    end

    subgraph Ingestion["Configured Public-Vacancy Ingestion"]
        direction TB
        S0["Allowlisted Montalban PESO PDF sources"] --> S1["Read PDF pages and extract vacancy notices with Gemini"]
        S1 --> S2["Keep source/page evidence and synchronize job records"]
    end

    REC["Employer or recruitment contact (external recipient)"]
    P1 -->|Saved active vacancies| A7
    S2 --> A7
    P3 --> S1
    P2 -->|Required account/profile data, if applicable| A10
    A12 -->|Application/referral information for selected vacancy, where supported| REC

    classDef actor fill:#eaf2ff,stroke:#3568a8,color:#182c4b,stroke-width:1px;
    classDef process fill:#f8fafc,stroke:#64748b,color:#172033,stroke-width:1px;
    classDef decision fill:#fff7dd,stroke:#b7791f,color:#543b0a,stroke-width:1px;
    classDef store fill:#e9f8ef,stroke:#278453,color:#12452b,stroke-width:1px;
    class A0,A1,P0,S0 actor;
    class A2,A3,A4,A5,A6,A7,A8,A9,A11,A12,A13,P1,P2,P3,P4,S1,S2 process;
    class A10 decision;
~~~

## 3. DFD Level 0 — Context Diagram

A context diagram represents the whole application as one process and shows only its direct external actors/systems and their major data flows. Internal database stores are intentionally omitted here; they are shown in Level 1. Some academic templates use “Level 0” differently, so follow the numbering convention required by the capstone adviser.

~~~mermaid
flowchart LR
    JS["PESO Jobseeker"]
    ITA["IT Admin"]
    FA["Firebase Authentication"]
    GA["Google Gemini API"]
    PDF["Allowlisted Montalban PESO PDF Sources"]
    REC["Employer or recruitment contact (external recipient)"]
    SYS(("0. JobKonek Employment Services System"))

    JS -->|"Firebase ID token, profile/NSRP/resume data, job searches and application answers"| SYS
    SYS -->|"Vacancies, generated documents, advisory guidance and application receipt/status"| JS

    ITA -->|"System settings, job records, account administration and report requests"| SYS
    SYS -->|"System status, managed records, ingestion status and available exports"| ITA

    JS <-->|"Account sign-in and ID-token issuance"| FA
    SYS <-->|"Server-side ID-token verification and identity claims"| FA
    SYS <-->|"Profile/PDF extraction requests and structured AI responses"| GA
    PDF -->|"Public vacancy notices and page content"| SYS
    SYS -->|"Application/referral information for a selected vacancy, where supported"| REC

    classDef actor fill:#eaf2ff,stroke:#3568a8,color:#182c4b,stroke-width:1px;
    classDef service fill:#f5edff,stroke:#7a54a1,color:#392655,stroke-width:1px;
    classDef system fill:#e9f8ef,stroke:#278453,color:#12452b,stroke-width:2px;
    class JS,ITA actor;
    class FA,GA,PDF,REC service;
    class SYS system;
~~~

## 4. DFD Level 1 — Major Processes and Data Stores

The Level 1 decomposition is based on the current implementation. Data stores are connected through processes; external users/services do not write directly into database stores. Only PESO Jobseeker and IT Admin are application roles. Employer/recruitment contacts are external recipients, not log-in roles.

~~~mermaid
flowchart LR
    JS["PESO Jobseeker"]
    ITA["IT Admin"]
    FA["Firebase Authentication"]
    GA["Google Gemini API"]
    PDF["Allowlisted Public PESO PDFs"]
    REC["Employer or recruitment contact (external recipient)"]

    subgraph System["JobKonek Internal Processes"]
        direction TB
        P1(["1.0 Authenticate and authorize"])
        P2(["2.0 Manage profile, onboarding and documents"])
        P3(["3.0 Provide vacancies, collect applications and prepare referral data"])
        P4(["4.0 Gemini profile extraction and Go Mini-AI advisory inference"])
        P5(["5.0 Ingest public PDFs and synchronize vacancies"])
        P6(["6.0 IT system administration and reporting"])
    end

    D1[("D1 MongoDB: users and profile data")]
    D2[("D2 MongoDB: jobPostings")]
    D3[("D3 MongoDB: jobApplications")]
    D4[("D4 MongoDB GridFS: profileArtifacts")]
    D5[("D5 MongoDB: publicInformationSources and publicInformationChunks")]
    D6[("D6 MongoDB: Gemini key settings and audit records")]

    JS <-->|"Account sign-in and ID-token issuance"| FA
    JS -->|"Firebase ID token and authenticated API requests"| P1
    P1 <-->|"Server-side token verification and identity claims"| FA
    P1 -->|"Verified UID and access context"| P2
    P1 -->|"Verified UID and access context"| P3
    P1 -->|"Verified UID and access context"| P4
    P1 -->|"IT Admin role and access context"| P6

    JS -->|"Profile fields, NSRP and resume data"| P2
    P2 <-->|"Profile, onboarding, preferences and outcomes"| D1
    P2 <-->|"Private file metadata and document bytes"| D4
    P2 -->|"Supported resume/NSRP evidence"| P4
    P2 -->|"Saved profile and document status"| JS

    JS -->|"Search filters and screening/application input"| P3
    D2 -->|"Active vacancy records"| P3
    P3 -->|"Job search filters"| D2
    P3 <-->|"Application answers, status and history"| D3
    D1 -->|"Profile and residency status"| P3
    P3 -->|"Vacancy pages, application receipt and saved updates"| JS
    P3 -->|"Application/referral data for a selected vacancy, where supported"| REC

    P4 <-->|"Structured profile extraction requests/results"| GA
    P4 <-->|"Saved profile facts and outcomes"| D1
    D2 -->|"Vacancy requirements for advisory job-fit evaluation"| P4
    P4 -->|"Extracted profile facts and non-binding guidance"| JS

    PDF -->|"Allowed source PDFs and page content"| P5
    P5 <-->|"Page-based notice extraction"| GA
    P5 <-->|"Source metadata, page evidence and indexed chunks"| D5
    P5 -->|"Validated source-backed vacancy updates"| D2

    ITA -->|"System configuration, job records, user access and report requests"| P6
    P6 <-->|"User records and required profile data"| D1
    P6 <-->|"Create, deactivate, archive and inspect postings"| D2
    D3 -->|"Stored application records for authorized reporting"| P6
    P6 <-->|"Authorized private document metadata/content access"| D4
    P6 <-->|"Ingestion status and source review"| D5
    P6 <-->|"Gemini-key administration and audit data"| D6
    P6 -->|"System status, managed records, ingestion status and available exports"| ITA

    classDef actor fill:#eaf2ff,stroke:#3568a8,color:#182c4b,stroke-width:1px;
    classDef process fill:#f8fafc,stroke:#64748b,color:#172033,stroke-width:1px;
    classDef datastore fill:#e9f8ef,stroke:#278453,color:#12452b,stroke-width:1px;
    classDef service fill:#f5edff,stroke:#7a54a1,color:#392655,stroke-width:1px;
    class JS,ITA actor;
    class P1,P2,P3,P4,P5,P6 process;
    class D1,D2,D3,D4,D5,D6 datastore;
    class FA,GA,PDF,REC service;
~~~

## 5. ERD — Core Logical MongoDB Data Model

This ERD represents the principal persisted application records. Firebase Authentication remains an external identity provider; passwords and Firebase credentials are not stored in a MongoDB User_Account table. GridFS stores document content and file metadata. This is a logical view, not a complete field-by-field MongoDB schema.

~~~mermaid
erDiagram
    USER_PROFILE {
        string uid PK "Firebase UID"
        string email
        string displayName
        string role
        object resumeData
        object pesoFormData
        object aiProfile
        object preferences
        object outcomes
        string residencyStatus
        int onboardingRevision
    }

    JOB_POSTING {
        string id PK "MongoDB ObjectId"
        string title
        string company
        string category
        string status
        datetime recruitmentDate
        datetime recruitmentEndDate
        string publicPdfSourceId
        datetime deletedAt
    }

    JOB_APPLICATION {
        string id PK "MongoDB ObjectId"
        string uid FK
        string jobId FK
        string status
        object answers
        float matchScore "Advisory value when present"
        datetime submittedAt
    }

    PROFILE_ARTIFACT {
        string fileId PK "GridFS file ID"
        string ownerUid FK
        string category
        string filename
        string contentType
        datetime uploadedAt
    }

    PUBLIC_PDF_SOURCE {
        string sourceId PK
        string title
        string url
        string syncStatus
        datetime lastSuccessfulSyncAt
    }

    PUBLIC_PDF_CHUNK {
        string chunkId PK
        string sourceIds "Array of source IDs"
        int pageStart
        int pageEnd
        string text
    }

    RESIDENCY_AUDIT {
        string auditId PK
        string uid FK
        string actorUid
        string status
        int revision
        datetime createdAt
    }

    USER_PROFILE ||--o{ JOB_APPLICATION : submits
    JOB_POSTING ||--o{ JOB_APPLICATION : receives
    USER_PROFILE ||--o{ PROFILE_ARTIFACT : owns
    USER_PROFILE ||--o{ RESIDENCY_AUDIT : has_review_history
    PUBLIC_PDF_SOURCE o|--o{ JOB_POSTING : may_supply
    PUBLIC_PDF_SOURCE }o--o{ PUBLIC_PDF_CHUNK : indexes
~~~

### Notes on the ERD

- USER_PROFILE corresponds to the MongoDB users collection keyed by the Firebase UID; Firebase stores the account identity and sign-in credentials externally.
- JOB_POSTING corresponds to jobPostings. Walk-in and LRA are the supported main categories; LRA visibility follows its scheduled final recruitment date in the Philippine time zone. Soft deletion retains history.
- JOB_APPLICATION corresponds to jobApplications. Application answers and official status are stored with the application. Any matchScore is advisory and is not a hiring decision.
- PROFILE_ARTIFACT represents GridFS profileArtifacts file metadata and its owner/category restrictions; the binary bytes are held by GridFS.
- PUBLIC_PDF_SOURCE and PUBLIC_PDF_CHUNK represent the allowlisted source registry and indexed page/text evidence used during ingestion.
- Residency review events are recorded in residencyAudit. Gemini key-management collections are operational configuration and are omitted from this core applicant/job ERD.
- Notifications shown to applicants are generated from saved application updates; do not add a separate Notification_Log entity unless a distinct persisted collection is implemented. Likewise, the code does not establish standalone Exam_Attempt, Question_Results, Application_Intent, Batch_Job_Upload, Data_Export, or AI_Recommendation collections.

## 6. What Changed from the Original Charts

1. Removed the generated-exam/50% automatic pre-vetting gate. Career/job-fit results are advisory; application submissions are recorded against selected vacancies; the system has no PESO Administrator review actor.
2. The two application roles are PESO Jobseeker and IT Admin. There is no PESO Administrator role.
3. Corrected authentication/data responsibilities: Firebase Authentication owns account identity; the API verifies ID tokens; MongoDB and GridFS persist application profiles and documents.
4. Replaced unsupported ERD entities with records visible in the source: users, jobPostings, jobApplications, GridFS profileArtifacts, publicInformationSources, publicInformationChunks, and residencyAudit.
5. Separated a real context-level DFD from the Level 1 decomposition. The supplied second image is structurally closer to a decomposed DFD because it already contains numbered processes and data stores, but its specific flows must be updated.
6. The developers implemented the Mini-AI training/evaluation pipeline and inference runtime in Go rather than Python, targeting fast CPU-friendly execution; performance comparisons should be reported only when supported by benchmarks.

## 7. Modeling and Capstone References

The overview is kept focused on system purpose, target users, principal capabilities, architecture, scope and limitations—the usual purpose of a capstone system overview. Follow your department's manuscript template if it prescribes different section headings.

- [Sample capstone requirements and system-overview structure](https://lilianyangc.github.io/capstone-summary-doc/files/main/T29_RequirementsAnalysisandDesignv1.0.pdf)
- [Mermaid official flowchart syntax](https://mermaid.js.org/syntax/flowchart.html)
- [IBM — Data Flow Diagrams and levels](https://www.ibm.com/think/topics/data-flow-diagram)
- [University of Waterloo — Context diagram conventions](https://uwaterloo.ca/vpaf-project-management-office/tools-and-templates/tools/context-diagram)

### Role accuracy and referral note

The intended application roles are **PESO Jobseeker** and **IT Admin** only. IT Admin manages the system and does not act as a PESO recruitment administrator or make hiring decisions. The external employer/recruitment-contact node represents a referral destination, not an application login role. The reviewed backend stores application records and offers report/export paths but does not establish automatic email delivery. Do not claim automated employer emailing without implementation and tests. The Flutter admin UI still contains legacy “PESO Admin” and “Handoff to PESO Admin” phrases; these labels conflict with the intended two-role model and should be cleaned up separately in the application code.