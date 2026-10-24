# JobKonek — System / Project Overview

**Review date:** 23 October 2026
**Project location:** C:/Users/Admin/Desktop/Prototype
**Purpose:** Concise, capstone-ready description based on current source code and project checkpoints.

## System Overview

JobKonek is a localized, AI-assisted employment-services prototype for jobseekers and the Public Employment Service Office (PESO) serving Rodriguez (Montalban), Rizal. It brings jobseeker profiles, employment-document preparation, vacancy discovery, job-specific screening, application tracking, and IT Admin functions into one integrated application ecosystem.

The primary client is built with Flutter and provides role-controlled jobseeker and IT Admin experiences. An embedded React/Vite workspace provides the NSRP Form 1 interface and template-based resume builder; completed fields and generated documents return to Flutter through a restricted web bridge. The current Windows launcher opens the web application in an Edge app-mode window; it is not a packaged native Windows executable.

Firebase Authentication handles registration and sign-in, including email/password and Google sign-in and email-based password recovery. The Node.js/Express API verifies Firebase ID tokens and enforces role and owner-access checks. MongoDB Atlas stores application data, including user profiles, onboarding data, job postings, applications, preferences, outcomes, and vacancy-ingestion records. Private resume and document files are stored with MongoDB GridFS. Cross-device synchronization depends on correctly configured and reachable API, database, authentication, and deployment services.

Gemini is used server-side for supported profile extraction and for processing configured, allowlisted Montalban PESO public-PDF vacancy sources. The developers built the Mini-AI training/evaluation pipeline and inference runtime in Go rather than Python, targeting fast, lightweight CPU execution and straightforward deployment. The Go Mini-AI provides advisory job-fit and career-guidance results using saved applicant information and supported evidence; these results are not official hiring decisions. PESO jobseekers can browse Walk-in Application and Local Recruitment Activity (LRA) vacancies, answer job-specific screening questions, and submit applications for selected opportunities. JobKonek records applications for tracking and vacancy-related referral/reporting. The only application roles are PESO Jobseeker and IT Admin; IT Admin manages the system and does not act as a PESO recruitment administrator.

The IT Admin experience focuses on technical/system administration, job and account records, configured public-PDF vacancy ingestion, Gemini-key management, and available application/report exports. IT Admin is the only administrator role; there is no PESO Administrator role. The source is configured for a single-origin Vercel application with the Flutter client, embedded NSRP/resume routes, and API routes under the same site. A configured deployment or passing local test does not by itself prove every authenticated production workflow is operational.

## Implementation Status and Limitations

The latest recorded isolated release checkpoint (22 October 2026) reports 259/259 backend tests and 177/177 Flutter tests passing, plus successful Flutter web and React/Vite builds. Targeted isolated browser tests also passed for several administration and document flows. These are recorded local/isolated results, not a blanket production sign-off. Real authenticated production acceptance, interrupted-upload recovery, some legacy structured-only document cases, and full operational/privacy review remain separate verification items.

JobKonek should therefore be described as an integrated employment-services prototype with authenticated application data, AI-assisted information processing, vacancy management, and application workflows. Do not describe it as an autonomous hiring system, a separate IT-monitoring platform, or a formally certified Philippine Data Privacy Act-compliant service without additional implementation review and evidence.

## Diagram Mapping

See CAPSTONE_OVERVIEW_AND_MERMAID_DIAGRAMS.md for the high-level workflow, DFD Level 0 context diagram, DFD Level 1 decomposition, core logical MongoDB ERD, and notes identifying inaccuracies in the earlier diagrams.

Implementation note: the reviewed Flutter admin UI still contains legacy “PESO Admin” and “Handoff to PESO Admin” labels. Those strings conflict with the intended two-role model and should be cleaned up in the UI. The reviewed source did not establish automatic email delivery to employers; avoid claiming that applicant records are emailed automatically unless that integration is implemented and verified.