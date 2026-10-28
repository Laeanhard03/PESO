import 'package:flutter/material.dart';

class StatusStyle {
  final String label;
  final Color text;
  final Color bg;
  final Color dot;

  const StatusStyle(this.label, this.text, this.bg, this.dot);
}

// Job-matching status (replaces the old AI-exam / assessment status).
const Map<String, StatusStyle> kMatchStyles = {
  'matched': StatusStyle(
    'Matched to a Job',
    Color(0xFF047857),
    Color(0xFFECFDF5),
    Color(0xFF10B981),
  ),
  'not_matched': StatusStyle(
    'Users with Low Qualification',
    Color(0xFFBE123C),
    Color(0xFFFFF1F2),
    Color(0xFFF43F5E),
  ),
  'pending': StatusStyle(
    'Resume Under Review',
    Color(0xFFB45309),
    Color(0xFFFFFBEB),
    Color(0xFFF59E0B),
  ),
};

class Applicant {
  final String uid;
  final int id;
  final String name;
  final String barangay;
  final String targetJob;
  final DateTime registeredDate;
  final int yearsExperience;
  final bool resumeSubmitted;
  final bool formSubmitted;
  final String matchStatus; // pending | matched | not_matched
  final int matchedJobsCount;
  final String resumeFileName;

  Applicant({
    required this.uid,
    required this.id,
    required this.name,
    required this.barangay,
    required this.targetJob,
    required this.registeredDate,
    required this.yearsExperience,
    required this.resumeSubmitted,
    required this.formSubmitted,
    required this.matchStatus,
    required this.matchedJobsCount,
    required this.resumeFileName,
  });
}

class Concern {
  final int id;
  final String applicantName;
  final String barangay;
  final String targetJob;
  final String message;
  final DateTime submittedDate;
  bool resolved;

  Concern({
    required this.id,
    required this.applicantName,
    required this.barangay,
    required this.targetJob,
    required this.message,
    required this.submittedDate,
    this.resolved = false,
  });
}

enum AdminTab {
  analytics,
  users,
  concerns,
  jobs,
  applications,
  ingestion,
  export,
  geminiKeys,
  platform,
  siteContent,
}

class NavItem {
  final AdminTab tab;
  final String label;
  final IconData icon;
  final String title;
  final String description;

  const NavItem(this.tab, this.label, this.icon, this.title, this.description);
}

const List<NavItem> kNavItems = [
  NavItem(
    AdminTab.analytics,
    'Applicant Analytics',
    Icons.insights_outlined,
    'Applicant Analytics',
    'Job seeker registrations and resume-based job matching outcomes across Montalban barangays.',
  ),
  NavItem(
    AdminTab.users,
    'User Management',
    Icons.manage_accounts_outlined,
    'Job Seeker Accounts',
    'Review Firebase Authentication accounts with profile fields stored in MongoDB through the trusted PESO API.',
  ),
  NavItem(
    AdminTab.concerns,
    'Concerns & Feedback',
    Icons.forum_outlined,
    'Concerns & Feedback',
    'Messages from job seekers who were not matched to a job, and other concerns they raised.',
  ),
  NavItem(
    AdminTab.jobs,
    'Jobs & Sources',
    Icons.work_outline,
    'Jobs & PDF Sources',
    'Manage existing job postings and review verified recruitment PDF links.',
  ),
  NavItem(
    AdminTab.applications,
    'Recruitment Pipeline',
    Icons.assignment_outlined,
    'Applications & DOLE Records',
    'Review job applications and access live DOLE SPRS export records.',
  ),
  NavItem(
    AdminTab.geminiKeys,
    'AI & Platform',
    Icons.tune_outlined,
    'AI Configuration & Platform',
    'Manage Gemini API keys, model matching preferences, and platform statistics.',
  ),
  NavItem(
    AdminTab.siteContent,
    'Landing Content',
    Icons.photo_library_outlined,
    'Landing Page Content',
    'Manage public PESO gallery photos and employer-partner logos without changing code.',
  ),
];
