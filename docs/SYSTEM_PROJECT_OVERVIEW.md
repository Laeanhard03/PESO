# JobKonek — System / Project Overview

**Codebase reviewed:** `C:\\Users\\Admin\\Desktop\\Prototype`  
**Review date:** 19 October 2026  
**Scope:** Source and project-document review. This overview distinguishes implemented code from features that are planned, incomplete, or not verified in a production deployment.

## System / Project Overview

JobKonek is a localized, AI-assisted employment-services prototype designed for the Public Employment Service Office (PESO) serving Rodriguez (Montalban), Rizal. Its purpose is to help jobseekers prepare employment information and documents, discover PESO-posted opportunities, and submit job-specific screening responses, while giving authorized PESO staff tools to manage job postings, applicant accounts, and submitted applications.

The main client is built with Flutter and includes jobseeker and PESO-administration experiences behind role-based access checks. A separate React/Vite workspace supplies the NSRP Form 1 and resume-building interfaces; these are opened from the Flutter application and send completed form data and generated PDF artifacts back through a Flutter-to-web bridge. The repository contains cross-platform Flutter targets, but that does not by itself establish that a production website, mobile builds, or every native target has been deployed and tested. The current Windows desktop-style launcher opens the local application in an Edge app-mode window; it is not yet a packaged native Windows executable.

## Authentication and Application Data

Firebase Authentication provides account identity and sign-in through email/password and Google, with email-based password reset. SMS authentication has been removed from the current application flow. After sign-in, the client sends its Firebase ID token to the Node.js/Express PESO API. The API verifies the token and determines the application role from the MongoDB user profile before permitting protected operations.

MongoDB Atlas is the intended primary store for current application data when its connection and credentials are configured. The backend uses MongoDB collections for user profiles, job postings, applications, preferences, onboarding information, AI-extracted profile data, and assessment outcomes. Private resume and document bytes are stored through MongoDB GridFS. The service also maintains records and searchable chunks for the approved public PESO PDF sources and stores metadata/audit records for administrator-managed Gemini API keys.

The active architecture therefore separates Firebase Authentication from the application-data database; it should not be described as a single Firebase/Firestore database. Older Firebase Functions and Firestore-related code remain in the repository for earlier integration paths and should be treated as legacy or separately deployable code unless the corresponding deployed flow is explicitly verified. Cross-device, real-time production synchronization also depends on a reachable, correctly configured API and database; the source code alone does not prove that public cloud hosting is active.

## Jobseeker Features

Jobseekers can register or sign in, maintain a profile, complete onboarding, use the embedded NSRP Form 1 interface, and build a resume using editable templates. The form and resume interfaces can generate PDF files and return structured field data to Flutter. The client can then save profile/onboarding data and, when the backend is ready, upload private resume and form documents to GridFS through authenticated API routes. Users can view their saved profile information and AI-extracted background.

The backend integrates Gemini for structured profile extraction from resume text and supported attachments, plus a general authenticated AI-query endpoint. Gemini processing is performed through the server-side provider; credentials are not intended to be embedded in the client. AI profile extraction is not the same thing as a job-to-resume semantic matching algorithm.

The job feed retrieves active job postings from the API. It includes two posting categories: **Walk-in Application** and **Local Recruitment Activity (LRA)**. LRA listings expire after 24 hours; walk-in postings remain active until deactivated. Jobseekers can answer a deterministic, job-specific screening questionnaire whose questions depend on the job description, requirements, and role. Those answers are submitted to the API as an application for PESO review.

## PESO Administration

The role-protected PESO administration area has API-backed workflows for listing and managing job postings, reviewing submitted applications and their screening answers, updating application status, viewing registered user/profile information, and performing permitted user-account actions. It also provides administrator controls for Gemini API key records and public-information ingestion routes. These operations rely on the Node API, a connected MongoDB database, and valid administrator authorization.

The public-job ingestion workflow is narrower than a general offline vacancy importer. It is designed around a fixed allowlist of public Montalban PESO PDF sources, including walk-in vacancy compilations and the “Para sa Montalbeño” compilation. The backend can download those PDFs under size/source limits, have Gemini read them in page ranges, retain page/source provenance, index searchable text, and synchronize extracted notices/roles into the job feed. The service includes scheduled refresh and recovery of incomplete reads. This does **not** establish automatic detection or import of arbitrary offline Excel vacancy lists.

The repository also contains a backend route that builds an XLSX workbook with a “DOLE SPRS” worksheet from stored applications, applicant/profile details, screening answers, status, and any recorded match score. However, the current Flutter administration source still needs a verified end-to-end check that its visible export tab is correctly connected to that backend route. Do not claim the entire report-export user workflow is production-verified merely because the backend workbook generator exists.

## Matching and Qualification Assessment — Important Limitation

A production-ready NLP/semantic compatibility-scoring algorithm is **not verified in the current implementation**. The job-feed UI looks for an optional `match` value on each job and displays a percentage if that value is supplied, while the API's public job-posting mapper does not provide a computed user-to-job match score. The qualification screen applies a threshold to the score it receives; it does not itself compute semantic similarity from the saved resume, profile, and vacancy requirements. The application API accepts a score supplied by the client rather than independently recalculating it on the server.

Accordingly, the system should not currently be described as delivering validated, precision-based semantic match percentages, AI-ranked recommendations, or bias-reduction outcomes. The active, verifiable workflow is job discovery plus a job-specific screening questionnaire and application submission. Reliable semantic ranking, score provenance, and server-side recalculation would need to be implemented and tested before those claims are included as completed functionality.

The current source also does not establish a push-notification service for newly matched jobs. Do not promise automatic personalized match notifications until a notification channel and end-to-end delivery are implemented and tested.

## Platform and Privacy Boundaries

The current codebase contains one role-gated Flutter application rather than three independently deployed products for jobseekers, PESO staff, and IT administration. No separate IT-administration desktop product or complete infrastructure-monitoring console was verified. Some administration views—such as concerns/feedback handling, applicant analytics fields, and the generic job-batch ingestion screen—are still empty, locally derived, or not connected to a dedicated live backend workflow. Account-management data can include registration and sign-in metadata when available from the authentication provider, but this is not equivalent to comprehensive IT activity monitoring.

The backend includes important security controls: verified Firebase ID tokens, role checks for administrative endpoints, server-derived user identity, owner-scoped private-document access, input/file-type limits, short-lived file links, and server-side handling of Gemini credentials. These controls are useful foundations, but source inspection does not certify complete encryption across every deployment, an independently audited security posture, or compliance with the Philippine Data Privacy Act of 2012 (Republic Act No. 10173). Formal privacy compliance should be claimed only after reviewing consent and transparency notices, retention/deletion policies, access controls, logs, deployment/TLS configuration, and operational procedures.

## Deployment Status and Wording Guidance

The code supports a local-development path using the Node API (port 3000 by default), the Flutter web shell, and the React NSRP/resume workspace. The API binds to loopback by default. Use from other devices requires a deliberately configured reachable HTTPS backend and the matching client API URL. A production deployment, every cross-platform build, and all administrator workflows must be checked in their actual target environments before the system is described as fully cloud-hosted or end-to-end operational.

For an accurate project description, present JobKonek as a **Flutter-based PESO employment-services prototype with Firebase Authentication, a MongoDB-backed API/data model, Gemini-assisted profile extraction and public-PDF vacancy ingestion, and job-specific application screening**. Describe semantic matching, automatic Excel ingestion, push notifications, independent IT monitoring, fully working report-export UI, production cloud synchronization, and formal privacy-law compliance as future work or pending verification—not established features.
