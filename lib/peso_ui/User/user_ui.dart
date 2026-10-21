import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../peso_services/app_toast.dart';

import '../Landingpage/landingpage_ui.dart';
import '../../peso_services/auth_service.dart';
import '../../peso_logic/peso_ai_engine.dart';
import '../../peso_logic/onboarding_ai_evidence.dart';
import '../../peso_logic/job_interest_recommendations.dart';
import '../../peso_models/profile_artifact.dart';
import '../../peso_services/profile_artifact_service.dart';
import '../../peso_services/peso_api_client.dart';
import '../../peso_services/applicant_draft_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../peso_models/job_posting.dart';
import '../Reusable_Designs/peso_images.dart';
import '../Reusable_Designs/design_tokens.dart';
import '../Reusable_Designs/pesoform_ui.dart';
import '../Reusable_Designs/resumebuilder_ui.dart';

// Tab File Imports
import 'user_job_feed_tab.dart';
import 'user_ai_profile_tab.dart';
import 'user_outcomes_tab.dart';
import 'user_settings_tab.dart';
import 'user_account_tab.dart';
import 'user_profile_avatar.dart';
import 'job_readiness_dialog.dart';
import 'job_readiness_model.dart';
import 'job_evaluation_result_dialog.dart';
import 'notice_role_comparison_dialog.dart';
import 'readiness_report_card.dart';
import 'user_qualifications_editor.dart';

class UserProfile extends StatefulWidget {
  final Map<String, dynamic>? aiProfileData;
  final bool newRegistration;

  final Map<String, dynamic> initialResumeData;
  final Map<String, dynamic> initialPesoFormData;
  final String? initialOnboardingText;
  final List<ProfileArtifactInput> retryArtifacts;
  final bool aiExtractionUnavailable;
  final bool onboardingSourcesSaved;

  const UserProfile({
    super.key,
    this.aiProfileData,
    this.newRegistration = false,
    this.initialResumeData = const {},
    this.initialPesoFormData = const {},
    this.initialOnboardingText,
    this.retryArtifacts = const [],
    this.aiExtractionUnavailable = false,
    this.onboardingSourcesSaved = true,
  });

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  int _selectedIndex = 0;
  final GlobalKey _jobDetailsAnchor = GlobalKey();
  String? _submittingReportId;
  bool _isLoggingOut = false;
  String _selectedLanguage = 'English';
  bool _languageChosenInThisSession = false;
  bool _emailNotifications = true;
  bool _appNotifications = true;
  bool _aiUnavailable = false;
  bool _retryingAi = false;
  bool _regeneratingNsrp = false;
  Map<String, dynamic> _accountProfile = <String, dynamic>{};
  Map<String, dynamic> _accountDocuments = <String, dynamic>{};
  bool _onboardingModalShown = false;
  bool _welcomeFinished = true;
  Uint8List? _profilePhotoBytes;
  String? _loadedPhotoId;
  Map<String, dynamic> _aiProfileData = <String, dynamic>{};
  Map<String, dynamic> _resumeData = <String, dynamic>{};
  Map<String, dynamic> _pesoFormData = <String, dynamic>{};
  List<Map<String, dynamic>> _profileArtifacts = <Map<String, dynamic>>[];
  ProfileArtifactInput? _pendingResumeExtraction;
  String _selectedJobCategory = PesoJobCategories.all;
  final TextEditingController _jobSearchController = TextEditingController();
  String _jobSearchQuery = '';
  final Map<String, Map<String, dynamic>> _jobTranslationCache = {};
  final Set<String> _translationPending = {};
  final Set<String> _translationErrors = {};
  Timer? _jobExpiryTimer;
  Timer? _jobSearchDebounce;
  int _jobRequestGeneration = 0;
  int _expiryRefreshTicks = 0;
  String? _nextJobPageToken;
  bool _loadingMoreJobs = false;

  // Controllers for AI Profile Tab
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _bioController;

  // AI Extracted Variables
  List<String> _userSkills = [];
  String _userName = 'Job Seeker';
  String _userTitle = 'Professional';

  // --- JOB FEED DATA ---
  final List<Map<String, dynamic>> _availableJobs = <Map<String, dynamic>>[];
  bool _jobsLoading = true;
  String? _jobLoadError;
  bool _refreshingCareerRecommendations = false;
  DateTime? _lastCareerRecommendationAttempt;
  Map<String, dynamic>? _careerRecommendations;

  Map<String, dynamic>? _selectedJob;
  bool _hasManuallySelectedJob = false;
  final List<Map<String, dynamic>> _assessmentOutcomes = [];
  List<Map<String, dynamic>> _myApplications = const [];
  bool _applicationsLoading = true;
  String? _applicationsError;
  String? _focusedApplicationId;

  final Color _primary = const Color(0xFF236349);
  final Color _textDark = const Color(0xFF17352B);
  final Color _textLight = const Color(0xFF52675D);

  @override
  void initState() {
    super.initState();
    _initializeAIProfileData();
    _resumeData = Map<String, dynamic>.from(widget.initialResumeData);
    _pesoFormData = Map<String, dynamic>.from(widget.initialPesoFormData);
    _aiUnavailable = widget.aiExtractionUnavailable;
    if (_aiUnavailable) {
      _userTitle = '';
      _userSkills = [];
      _titleController.clear();
      _bioController.clear();
      _nameController.clear();
    }
    _loadAccountProfile();
    _loadJobPostings();
    _loadMyApplications();
    _welcomeFinished = !widget.newRegistration;
    if (widget.newRegistration) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _welcomeNewApplicant();
        _welcomeFinished = true;
        if (mounted) unawaited(_showRequiredOnboarding());
      });
    }
    _jobExpiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final visible = _filteredAvailableJobs();
      setState(() {
        if (_selectedJob != null && !visible.contains(_selectedJob)) {
          _selectedJob = visible.isEmpty ? null : visible.first;
        }
      });
      // Reconcile deletes and newly published jobs without excessive polling.
      _expiryRefreshTicks++;
      if (_expiryRefreshTicks % 2 == 0 && !_jobsLoading && !_loadingMoreJobs) {
        unawaited(_loadJobPostings());
        unawaited(_loadMyApplications());
      }
    });
  }

  Future<void> _welcomeNewApplicant() async {
    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(
          children: [
            Icon(Icons.celebration_rounded, color: Color(0xFF236349)),
            SizedBox(width: 10),
            Expanded(child: Text('Welcome to PESO JobKonek!')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your registration is complete. Which language would you prefer for your job-search workspace?',
              ),
              const SizedBox(height: 8),
              const Text(
                'English is the default. You can switch anytime in Settings > System Language. Original employer requirements remain available in English.',
                style: TextStyle(fontSize: 12, color: Color(0xFF52675D)),
              ),
              const SizedBox(height: 14),
              for (final lang in const ['English', 'Tagalog', 'Taglish'])
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    lang == 'English' ? Icons.language : Icons.translate,
                    color: const Color(0xFF236349),
                  ),
                  title: Text(
                    lang,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: lang == 'Taglish'
                      ? const Text('Mixed English / Filipino')
                      : null,
                  onTap: () => Navigator.of(dialogContext).pop(lang),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (chosen != null) {
      setState(() {
        _selectedLanguage = chosen;
        _languageChosenInThisSession = true;
      });
      await _persistPreferences();
      unawaited(_translateSelectedJob());
    }
  }

  String get _preferredOccupation {
    final preferences = <String>{};
    for (final source in [_pesoFormData, _resumeData]) {
      final essentials = source['applicantEssentials'];
      if (essentials is Map) {
        final desired =
            essentials['preferredOccupation']?.toString().trim() ?? '';
        if (desired.isNotEmpty) preferences.add(desired);
      }
      final entries = source['entries'];
      if (entries is List) {
        for (final item in entries.whereType<Map>()) {
          final label = item['label']?.toString() ?? '';
          if (RegExp(
            r'preferred occupation|desired (job|position)|job preference',
            caseSensitive: false,
          ).hasMatch(label)) {
            final desired = item['value']?.toString().trim() ?? '';
            if (desired.isNotEmpty) preferences.add(desired);
          }
        }
      }
    }
    return preferences.join(', ');
  }

  List<String> get _sourceSupportedSkills {
    final terms = <String>[];
    final extracted = _accountProfile['aiMatchingExtraction'];
    if (extracted is Map) {
      for (final key in [
        'skills',
        'certifications',
        'education',
        'occupationCategories',
      ]) {
        final facts = extracted[key];
        if (facts is List) {
          for (final fact in facts) {
            final term = fact is Map
                ? fact['field']?.toString() ?? ''
                : fact.toString();
            if (term.isNotEmpty) terms.add(term);
          }
        }
      }
    }
    for (final form in [_pesoFormData, _resumeData]) {
      final essentials = form['applicantEssentials'];
      if (essentials is Map &&
          essentials['skillsStage'] == 'Has skills or training to list') {
        terms.add(essentials['skills']?.toString() ?? '');
      }
      for (final fieldKey in ['entries', 'fields']) {
        final fields = form[fieldKey];
        if (fields is! List) continue;
        for (final field in fields.whereType<Map>()) {
          final label = [
            field['section'],
            field['label'],
          ].whereType<String>().join(' ');
          if (RegExp(
                r'skill|training|certificat|occupation|work experience|employment history|course|qualification',
                caseSensitive: false,
              ).hasMatch(label) &&
              !RegExp(
                r'name|birth|gender|sex|phone|email|address|religion|civil status',
                caseSensitive: false,
              ).hasMatch(label)) {
            terms.add(field['value']?.toString() ?? '');
          }
        }
      }
    }
    return terms
        .expand((term) => term.split(RegExp(r'[,;\n]+')))
        .map((term) => term.trim())
        .where((term) => term.length >= 3 && term.length <= 90)
        .toSet()
        .take(60)
        .toList();
  }

  List<Map<String, dynamic>> _filteredAvailableJobs([String? category]) {
    final selectedCategory = category ?? _selectedJobCategory;
    final query = _jobSearchQuery.trim().toLowerCase();
    const filipinoRoleNames = <String, String>{
      'karpintero': 'carpenter',
      'manghihinang': 'welder',
      'drayber': 'driver',
      'tsuper': 'driver',
      'kahera': 'cashier',
      'kusinero': 'cook',
      'tagalinis': 'cleaner',
      'guro': 'teacher',
      'bantay': 'guard',
      'konstruksyon': 'construction',
      'opisina': 'office',
      'panadero': 'baker',
      'trabaho': 'job',
    };
    final translatedQuery = query
        .split(RegExp(r'\s+'))
        .map((word) => filipinoRoleNames[word] ?? word)
        .join(' ');
    final filtered = _availableJobs
        .where(PesoJobCategories.isVisible)
        // Search always respects the selected posting category.
        .where(
          (job) =>
              selectedCategory == PesoJobCategories.all ||
              job['category']?.toString() == selectedCategory,
        )
        .where((job) {
          if (query.isEmpty) return true;
          final cached =
              _jobTranslationCache['${job['id']}|$_selectedLanguage'];
          return [
                'title',
                'company',
                'location',
                'description',
                'type',
                'category',
              ].any((field) {
                final raw = (job[field]?.toString() ?? '').toLowerCase();
                return raw.contains(query) || raw.contains(translatedQuery);
              }) ||
              (cached?['title']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (cached?['description']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false);
        })
        .toList();
    if (query.isNotEmpty) return filtered;
    final goMatching =
        _careerRecommendations ?? _accountProfile['latestAiJobMatch'];
    return rankJobOpportunities(
      filtered,
      preferredOccupations: _preferredOccupation,
      sourceSupportedSkills: _sourceSupportedSkills,
      goMatching: goMatching is Map
          ? Map<String, dynamic>.from(goMatching)
          : null,
    );
  }

  Future<void> _translateSelectedJob({bool forceRetry = false}) async {
    final selected = _selectedJob;
    final language = _selectedLanguage;
    if (!mounted || selected == null || language == 'English') return;
    final jobId = selected['id']?.toString() ?? '';
    if (jobId.isEmpty) return;
    final key = '$jobId|$language';
    if (_translationPending.contains(key) ||
        (!forceRetry &&
            (_jobTranslationCache.containsKey(key) ||
                _translationErrors.contains(key)))) {
      return;
    }
    setState(() {
      _translationPending.add(key);
      _translationErrors.remove(key);
    });
    try {
      final response = await PesoApiClient.translateJob(
        jobId: jobId,
        language: language,
      );
      final translation = response['translation'];
      if (translation is! Map) {
        throw const FormatException('Translation missing');
      }
      if (!mounted) return;
      setState(
        () =>
            _jobTranslationCache[key] = Map<String, dynamic>.from(translation),
      );
    } catch (_) {
      if (mounted) setState(() => _translationErrors.add(key));
    } finally {
      if (mounted) setState(() => _translationPending.remove(key));
    }
  }

  Map<String, dynamic> _jobPostingForFeed(Map<String, dynamic> job) {
    final requirements = job['requirements'];
    final rawMatch = job['matchScore'] ?? job['match'];
    final imageUrl =
        (job['imageUrl'] ?? job['image'] ?? job['bannerUrl'] ?? job['photoUrl'])
            ?.toString() ??
        '';
    final rawDescription = job['description']?.toString() ?? '';
    final sourceMarker = RegExp(
      r'^\[PESO_PUBLIC_PDF_LISTING\|title=([^|]+)\|url=([^|]+)\|pages=(\d+)-(\d+)\]\s*',
    ).firstMatch(rawDescription);
    final isPublicPdfListing =
        job['isPublicPdfListing'] == true || sourceMarker != null;
    final sourcePageStart =
        int.tryParse(job['sourcePageStart']?.toString() ?? '') ??
        int.tryParse(sourceMarker?.group(3) ?? '') ??
        1;
    final sourcePageEnd =
        int.tryParse(job['sourcePageEnd']?.toString() ?? '') ??
        int.tryParse(sourceMarker?.group(4) ?? '') ??
        sourcePageStart;
    return <String, dynamic>{
      ...job,
      '_persistedPosting': true,
      'id': job['id']?.toString() ?? '',
      'title': job['title']?.toString() ?? 'Untitled job',
      'company': job['company']?.toString() ?? 'Employer',
      'location': job['location']?.toString() ?? 'Location not provided',
      'salary': job['salary']?.toString() ?? 'Salary not provided',
      'type':
          job['employmentType']?.toString() ??
          job['type']?.toString() ??
          'Not specified',
      'vacancies':
          job['listingLabel']?.toString() ??
          (isPublicPdfListing
              ? 'Multiple roles'
              : (job['vacancies'] ?? 1).toString()),
      'match': rawMatch is num ? rawMatch.toInt() : 0,
      'image': imageUrl.trim(),
      'imageFallback': PesoImageAssets.jobFallbackFor(job),
      'isPublicPdfListing': isPublicPdfListing,
      'listingLabel':
          job['listingLabel']?.toString() ??
          (isPublicPdfListing ? 'Multiple roles' : ''),
      'sourceTitle':
          job['sourceTitle']?.toString() ?? sourceMarker?.group(1) ?? '',
      'sourceUrl': job['sourceUrl']?.toString() ?? sourceMarker?.group(2) ?? '',
      'sourcePageStart': sourcePageStart,
      'sourcePageEnd': sourcePageEnd,
      'availabilityNote':
          job['availabilityNote']?.toString() ??
          (isPublicPdfListing
              ? 'The PDF does not confirm whether these openings are still available. Contact PESO Montalban before applying.'
              : ''),
      'description': sourceMarker == null
          ? rawDescription
          : rawDescription.substring(sourceMarker.end).trim(),
      'reqs': requirements is List
          ? requirements.map((item) => item.toString()).toList()
          : <String>[],
    };
  }

  List<Map<String, dynamic>> _linkedRolesForSelectedNotice() {
    final notice = _selectedJob;
    if (notice == null || notice['aiListingKind'] != 'notice') return [];
    final embedded = notice['linkedRoles'];
    if (embedded is List) {
      return embedded.whereType<Map>()
          .map((row) => _jobPostingForFeed(Map<String, dynamic>.from(row)))
          .where(PesoJobCategories.isVisible).toList();
    }
    final rawIds = notice['linkedRoleIds'];
    if (rawIds is! List) return [];
    final visibleById = <String, Map<String, dynamic>>{
      for (final job in _availableJobs.where(PesoJobCategories.isVisible))
        if (job['aiListingKind'] == 'role' &&
            job['id']?.toString().isNotEmpty == true)
          job['id'].toString(): job,
    };
    return rawIds
        .map((id) => visibleById[id.toString()])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  String get _serverJobSearch {
    const translated = <String, String>{
      'karpintero': 'carpenter',
      'manghihinang': 'welder',
      'drayber': 'driver',
      'tsuper': 'driver',
      'kahera': 'cashier',
      'kusinero': 'cook',
      'tagalinis': 'cleaner',
      'guro': 'teacher',
      'bantay': 'guard',
      'konstruksyon': 'construction',
      'opisina': 'office',
      'panadero': 'baker',
      'trabaho': 'job',
    };
    return _jobSearchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((word) => translated[word] ?? word)
        .join(' ');
  }

  void _scheduleJobSearch() {
    _jobSearchDebounce?.cancel();
    _jobSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_loadJobPostings()),
    );
  }

  Future<void> _loadJobPostings() async {
    final generation = ++_jobRequestGeneration;
    if (mounted) {
      setState(() {
        _jobsLoading = true;
        _jobLoadError = null;
      });
    }
    try {
      final result = await PesoApiClient.listJobsPage(
        limit: 60,
        search: _serverJobSearch,
        category: _selectedJobCategory,
      );
      final rows = result['jobs'];
      if (rows is! List) {
        throw const FormatException('Invalid PESO job response');
      }
      final postings = rows
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(PesoJobCategories.isVisible)
          .map(_jobPostingForFeed)
          .toList();
      if (!mounted || generation != _jobRequestGeneration) return;
      setState(() {
        _jobsLoading = false;
        _jobLoadError = null;
        _nextJobPageToken = result['nextPageToken']?.toString();
        _availableJobs
          ..clear()
          ..addAll(postings);
        final visible = _filteredAvailableJobs();
        final selectedId = _selectedJob?['id']?.toString();
        final retained = visible.where(
          (job) => job['id']?.toString() == selectedId,
        );
        if (!_hasManuallySelectedJob || retained.isEmpty) {
          _selectedJob = visible.isEmpty ? null : visible.first;
          _hasManuallySelectedJob = false;
        } else {
          _selectedJob = retained.first;
        }
      });
      unawaited(_translateSelectedJob());
      unawaited(_refreshCareerRecommendations());
    } catch (error) {
      if (!mounted || generation != _jobRequestGeneration) return;
      debugPrint('[JOBS] API unavailable (${error.runtimeType}).');
      setState(() {
        _jobsLoading = false;
        _jobLoadError =
            error is PesoApiException &&
                (error.code == 'unauthenticated' ||
                    error.code == 'invalid_or_expired_token')
            ? 'Your session expired. Sign in again, then reload the job feed.'
            : 'Could not load PESO job openings. Existing listings were not deleted; retry.';
      });
    }
  }

  Future<void> _loadMoreJobPostings() async {
    final token = _nextJobPageToken;
    if (_loadingMoreJobs || _jobsLoading || token == null) return;
    final generation = _jobRequestGeneration;
    setState(() => _loadingMoreJobs = true);
    try {
      final result = await PesoApiClient.listJobsPage(
        limit: 60,
        pageToken: token,
        search: _serverJobSearch,
        category: _selectedJobCategory,
      );
      final rows = result['jobs'];
      if (rows is! List) {
        throw const FormatException('Invalid PESO job response');
      }
      if (!mounted || generation != _jobRequestGeneration) return;
      final existing = _availableJobs
          .map((job) => job['id']?.toString())
          .toSet();
      final additions = rows
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(PesoJobCategories.isVisible)
          .map(_jobPostingForFeed)
          .where((job) => existing.add(job['id']?.toString()))
          .toList();
      setState(() {
        _availableJobs.addAll(additions);
        _nextJobPageToken = result['nextPageToken']?.toString();
        _jobLoadError = null;
      });
    } catch (error) {
      if (mounted && generation == _jobRequestGeneration) {
        setState(
          () => _jobLoadError = 'More PESO jobs could not be loaded. Retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMoreJobs = false);
    }
  }

  Future<void> _loadMyApplications() async {
    if (!mounted) return;
    setState(() {
      _applicationsLoading = true;
      _applicationsError = null;
    });
    try {
      final all = <Map<String, dynamic>>[];
      String? pageToken;
      do {
        final result = await PesoApiClient.listMyApplications(
          limit: 100,
          pageToken: pageToken,
        );
        final rows = result['applications'];
        if (rows is! List) {
          throw const FormatException('Invalid application history');
        }
        all.addAll(
          rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)),
        );
        pageToken = result['nextPageToken']?.toString();
      } while (pageToken != null && pageToken.isNotEmpty && all.length < 500);
      if (!mounted) return;
      setState(() {
        _myApplications = all;
        _applicationsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _applicationsLoading = false;
        _applicationsError = 'Could not refresh application statuses.';
      });
    }
  }

  Future<void> _openNotifications() async {
    List<Map<String, dynamic>> notices;
    try {
      notices = await PesoApiClient.listNotifications();
    } catch (_) {
      if (!mounted) return;
      AppToast.warning(
        context,
        'Could not load notifications. Check your connection and retry.',
      );
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.76,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PESO application notifications',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Updates shown here come from your saved PESO applications.',
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: notices.isEmpty
                      ? const Center(
                          child: Text(
                            'No submitted applications or updates yet.',
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: notices.length,
                          itemBuilder: (_, index) {
                            final notice = notices[index];
                            final id =
                                notice['applicationId']?.toString() ?? '';
                            return ListTile(
                              key: ValueKey('notification-application-$id'),
                              leading: const Icon(
                                Icons.assignment_turned_in_outlined,
                              ),
                              title: Text(
                                notice['title']?.toString() ??
                                    'Application update',
                              ),
                              subtitle: Text(
                                notice['message']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: id.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      if (!mounted) return;
                                      setState(() {
                                        _focusedApplicationId = id;
                                        _selectedIndex = 2;
                                      });
                                      unawaited(_loadMyApplications());
                                    },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    if (!mounted) return;
                    setState(() {
                      _selectedIndex = 2;
                      _focusedApplicationId = null;
                    });
                    unawaited(_loadMyApplications());
                  },
                  child: const Text('View all applications in Outcomes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Refresh recommendations against all saved, active job postings after both
  /// profile and job feed have loaded. This uses only saved source evidence
  /// and the existing Go Mini-AI endpoint; no unverified Gemini claims or MRQ.
  Future<void> _refreshCareerRecommendations() async {
    if (_refreshingCareerRecommendations ||
        !mounted ||
        _availableJobs.isEmpty ||
        (_pesoFormData.isEmpty &&
            _resumeData.isEmpty &&
            _accountProfile['aiMatchingExtraction'] is! Map)) {
      return;
    }
    final now = DateTime.now();
    if (_lastCareerRecommendationAttempt != null &&
        now.difference(_lastCareerRecommendationAttempt!) <
            const Duration(minutes: 2)) {
      return;
    }
    _lastCareerRecommendationAttempt = now;
    _refreshingCareerRecommendations = true;
    try {
      final result = await PesoApiClient.evaluateCareerRecommendations();
      if (!mounted ||
          result['status'] != 'ready' ||
          result['results'] is! List) {
        return;
      }
      setState(() {
        _careerRecommendations = <String, dynamic>{
          'status': 'ready',
          'jobId': null,
          'modelVersion': result['modelVersion'],
          'results': result['results'],
        };
        if (!_hasManuallySelectedJob) {
          final ranked = _filteredAvailableJobs();
          _selectedJob = ranked.isEmpty ? null : ranked.first;
        }
      });
    } on PesoApiException catch (error) {
      debugPrint('[JOBS] Mini-AI recommendations unavailable: ${error.code}');
    } catch (_) {
      debugPrint('[JOBS] Mini-AI recommendations could not be refreshed.');
    } finally {
      _refreshingCareerRecommendations = false;
    }
  }

  void _initializeAIProfileData() {
    _nameController = TextEditingController(text: 'Unknown Applicant');
    _titleController = TextEditingController(text: 'General Professional');
    _bioController = TextEditingController(text: 'Walang bio na nakuha.');

    if (widget.aiProfileData != null && widget.aiProfileData!.isNotEmpty) {
      final data = widget.aiProfileData!;
      _aiProfileData = Map<String, dynamic>.from(data);

      _userName = data['fullName'] ?? 'Applicant';
      _userTitle = data['professionalTitle'] ?? 'Professional';

      _nameController.text = _userName;
      _titleController.text = _userTitle;
      _bioController.text = data['bilingualBio'] ?? 'Walang bio na nakuha.';

      if (data['skills'] != null) {
        _userSkills = List<String>.from(data['skills']);
      }
    }
  }

  Future<void> _showRequiredOnboarding() async {
    if (!mounted || !_welcomeFinished || _onboardingModalShown ||
        _accountDocuments.isEmpty) return;
    final resumeMissing = _accountDocuments['resumeSubmitted'] != true;
    final nsrpMissing = _accountDocuments['formSubmitted'] != true;
    if (!resumeMissing && !nsrpMissing) return;
    _onboardingModalShown = true;
    final choice = await showDialog<String>(
      context: context, barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish your PESO JobKonek onboarding'),
        content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(resumeMissing ? 'Resume: Missing' : 'Resume: Submitted'),
            const SizedBox(height: 8),
            Text(nsrpMissing ? 'NSRP Form 1: Missing' : 'NSRP Form 1: Submitted'),
            const SizedBox(height: 12),
            const Text('Complete these steps: (1) create or upload a resume, '
              '(2) complete NSRP Form 1, (3) review AI extraction. '
              'Gemini errors do not erase saved documents.',
              style: TextStyle(height: 1.5)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'account'),
            child: const Text('Open My Account')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'continue'),
            child: const Text('Continue onboarding')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'continue') {
      if (resumeMissing) {
        await _chooseResumePath();
      } else if (nsrpMissing) {
        await _editOfficialNsrp();
      }
    } else {
      setState(() => _selectedIndex = 4);
    }
  }

  Future<void> _chooseResumePath() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resume onboarding'),
        content: const Text('Use the current resume builder or upload an existing document.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
          OutlinedButton(onPressed: () => Navigator.pop(dialogContext, 'upload'),
            child: const Text('Upload resume')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'build'),
            child: const Text('Create resume')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'build') await _openResumeBuilder();
    if (choice == 'upload') {
      final saved = await _replacePdf('resume_upload');
      if (saved && mounted && _accountDocuments['formSubmitted'] != true) {
        await _editOfficialNsrp();
      }
    }
  }

  Future<void> _openResumeBuilder() async {
    await Navigator.push<void>(context, MaterialPageRoute(
      builder: (_) => ResumeBuilderWizard(
        initialValues: <String, String>{
          'firstName': _accountProfile['firstName']?.toString() ?? '',
          'lastName': _accountProfile['lastName']?.toString() ?? '',
          'email': _accountProfile['email']?.toString() ?? '',
          'phone': _accountProfile['phoneNumber']?.toString() ?? '',
        },
        onComplete: (payload) {
          Navigator.of(context).pop();
          unawaited(_saveBuiltResume(payload));
        },
      ),
    ));
  }

  Future<void> _saveBuiltResume(Map<String, dynamic> payload) async {
    final rawData = payload['resumeData'];
    if (rawData is! Map) return;
    try {
      await PesoApiClient.saveOnboarding(<String, dynamic>{
        'resumeData': Map<String, dynamic>.from(rawData),
      });
      final artifact = ProfileArtifactInput.fromBridgePayload(payload['artifact']);
      var documentConfirmed = false;
      if (artifact != null) {
        final saved = await ProfileArtifactService.saveArtifacts([artifact]);
        documentConfirmed = saved.records.isNotEmpty && saved.warnings.isEmpty;
        if (!documentConfirmed && mounted) {
          AppToast.warning(context, 'Resume details saved; PDF upload needs a retry.');
        }
      }
      if (documentConfirmed) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        await ApplicantDraftService.clear(uid, 'resume');
      }
      await _loadAccountProfile();
      if (!mounted) return;
      AppToast.success(context, 'Your resume was saved.');
      if (_accountDocuments['formSubmitted'] != true) {
        await _editOfficialNsrp();
      } else {
        setState(() => _selectedIndex = 1);
        unawaited(_retryAiExtraction());
      }
    } catch (_) {
      if (mounted) AppToast.error(context,
        'Could not sync the resume. Your encrypted draft remains available.');
    }
  }

  Future<void> _loadAccountProfile() async {
    try {
      final data = await AuthService.getCurrentUserProfile();
      if (!mounted || data.isEmpty) return;

      final preferences = data['preferences'] is Map
          ? Map<String, dynamic>.from(data['preferences'] as Map)
          : <String, dynamic>{};
      final savedOutcomes = data['assessmentOutcomes'];
      final aiProfile = data['aiProfile'] is Map
          ? Map<String, dynamic>.from(data['aiProfile'] as Map)
          : <String, dynamic>{};
      final fullName = (data['displayName'] as String?)?.trim();
      final resumeData = data['resumeData'] is Map
          ? Map<String, dynamic>.from(data['resumeData'] as Map)
          : <String, dynamic>{};
      final pesoFormData = data['pesoFormData'] is Map
          ? Map<String, dynamic>.from(data['pesoFormData'] as Map)
          : <String, dynamic>{};
      var profileArtifacts = <Map<String, dynamic>>[];
      var documentStatus = <String, dynamic>{};
      try {
        documentStatus = await PesoApiClient.getAccountDocuments();
      } catch (_) {
        // If the API is unavailable, do not mistakenly report missing records.
      }
      try {
        profileArtifacts =
            await ProfileArtifactService.getCurrentUserArtifacts();
      } catch (error) {
        debugPrint('[PROFILE] Could not load saved documents: $error');
      }

      setState(() {
        _resumeData = resumeData.isNotEmpty ? resumeData : _resumeData;
        _pesoFormData = pesoFormData.isNotEmpty ? pesoFormData : _pesoFormData;
        _profileArtifacts = profileArtifacts
            .where((item) => item['category'] != 'profile_photo')
            .toList();
        _accountProfile = data;
        if (documentStatus.isNotEmpty) _accountDocuments = documentStatus;
        final sorted = _filteredAvailableJobs();
        if (!_hasManuallySelectedJob && sorted.isNotEmpty) {
          _selectedJob = sorted.first;
        }
        // Backend extraction status is authoritative after refresh/login.
        // An offline warning from the previous screen must not hide a saved
        // extraction, nor may an old profile imply that the latest retry worked.
        final persistedStatus = data['aiExtractionStatus']?.toString();
        _aiUnavailable =
            persistedStatus == 'failed' ||
            (persistedStatus != 'completed' &&
                aiProfile.isEmpty &&
                (widget.aiExtractionUnavailable || _aiProfileData.isEmpty));
        _aiProfileData =
            widget.aiProfileData != null && widget.aiProfileData!.isNotEmpty
            ? Map<String, dynamic>.from(widget.aiProfileData!)
            : aiProfile;
        if (fullName != null && fullName.isNotEmpty) _userName = fullName;
        // The preferences GET can finish after the applicant selects a new
        // language in the welcome modal. Do not overwrite that new selection
        // with an older English preference from an in-flight request.
        if (!_languageChosenInThisSession &&
            preferences['language'] is String) {
          _selectedLanguage = preferences['language'] as String;
        }
        if (preferences['emailNotifications'] is bool) {
          _emailNotifications = preferences['emailNotifications'] as bool;
        }
        if (preferences['appNotifications'] is bool) {
          _appNotifications = preferences['appNotifications'] as bool;
        }
        if (savedOutcomes is List) {
          _assessmentOutcomes
            ..clear()
            ..addAll(
              savedOutcomes.whereType<Map>().map(
                (item) => Map<String, dynamic>.from(item),
              ),
            );
        }
        if (!_aiUnavailable &&
            widget.aiProfileData == null &&
            aiProfile.isNotEmpty) {
          final savedTitle = data['professionalTitle']?.toString().trim() ?? '';
          final savedBio = data['bio']?.toString().trim() ?? '';
          _userTitle = savedTitle.isNotEmpty
              ? savedTitle
              : (aiProfile['professionalTitle']?.toString() ?? _userTitle);
          _nameController.text = _userName;
          _titleController.text = _userTitle;
          _bioController.text = savedBio.isNotEmpty
              ? savedBio
              : (aiProfile['bilingualBio']?.toString() ?? _bioController.text);
          final skills = aiProfile['skills'];
          if (skills is List) {
            _userSkills = skills.map((item) => item.toString()).toList();
          }
        } else if (widget.aiProfileData == null) {
          _nameController.text = _userName;
        }
      });
      unawaited(_translateSelectedJob());
      unawaited(_refreshCareerRecommendations());
      if (_accountDocuments.isNotEmpty && !_onboardingModalShown &&
          _welcomeFinished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showRequiredOnboarding());
        });
      }
      final photoId = data['photoArtifactId']?.toString() ?? '';
      if (data['avatarStyle'] == 'photo' &&
          photoId.isNotEmpty &&
          photoId != _loadedPhotoId) {
        await _loadProfilePhoto(photoId);
      }
    } catch (error) {
      debugPrint('[PROFILE] Could not load user profile: $error');
    }
  }

  Future<void> _retryAiExtraction() async {
    if (_retryingAi) return;
    setState(() => _retryingAi = true);
    try {
      final safeText = buildOnboardingAiEvidence(
        resumeData: _resumeData,
        pesoFormData: _pesoFormData,
        onboardingText:
            widget.initialOnboardingText ??
            _accountProfile['onboardingText']?.toString(),
      );
      final newResume = _pendingResumeExtraction;
      final extracted = await PesoAIEngine.generateProfile(
        artifacts: newResume == null
            ? widget.retryArtifacts : <ProfileArtifactInput>[newResume],
        rawText: safeText,
      );
      if (extracted.isEmpty) throw const FormatException('Empty extraction');
      // POST /api/ai/profile already persisted the verified extraction.
      if (!mounted) return;
      setState(() {
        _aiUnavailable = false;
        _aiProfileData = extracted;
        _userSkills = extracted['skills'] is List
            ? List<String>.from(extracted['skills'])
            : [];
        _userTitle = extracted['professionalTitle']?.toString() ?? '';
        _titleController.text = _userTitle;
        _bioController.text = extracted['bilingualBio']?.toString() ?? '';
      });
      _pendingResumeExtraction = null;
      AppToast.success(context, 'AI extraction was completed.');
    } catch (error) {
      debugPrint('[PROFILE] AI retry unavailable (${error.runtimeType}).');
      if (mounted) {
        AppToast.warning(
          context,
          'AI extraction is still unavailable. Your source forms remain accessible.',
        );
      }
    } finally {
      if (mounted) setState(() => _retryingAi = false);
    }
  }

  Future<void> _editOfficialNsrp() async {
    if (_regeneratingNsrp) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PesoRegistrationWizard(
          savedFormData: _pesoFormData,
          initialValues: <String, String>{
            'firstName': _accountProfile['firstName']?.toString() ?? '',
            'lastName': _accountProfile['lastName']?.toString() ?? '',
            'email': _accountProfile['email']?.toString() ?? '',
            'phone': _accountProfile['phoneNumber']?.toString() ?? '',
          },
          onComplete: (payload) {
            if (_regeneratingNsrp) return;
            _regeneratingNsrp = true;
            Navigator.of(context).pop();
            unawaited(_saveRegeneratedNsrp(payload));
          },
        ),
      ),
    );
  }

  Future<void> _saveRegeneratedNsrp(Map<String, dynamic> payload) async {
    try {
      final form = payload['formData'];
      final artifact = ProfileArtifactInput.fromBridgePayload(
        payload['artifact'],
      );
      if (form is! Map ||
          artifact == null ||
          artifact.category != 'nsrp_form' ||
          artifact.mimeType != 'application/pdf') {
        throw const FormatException('Updated Form 1 PDF missing.');
      }
      final saved = await ProfileArtifactService.saveArtifacts([artifact]);
      if (saved.records.isEmpty) {
        throw StateError(
          saved.warnings.isEmpty
              ? 'Updated PDF was not saved.'
              : saved.warnings.join(' '),
        );
      }
      await PesoApiClient.saveOnboarding(<String, dynamic>{
        'pesoFormData': Map<String, dynamic>.from(form),
      });
      await ApplicantDraftService.clear(
        FirebaseAuth.instance.currentUser?.uid ?? '', 'nsrp');
      await _loadAccountProfile();
      if (mounted) {
        AppToast.success(context, 'Updated NSRP Form 1 and PDF saved.');
        setState(() => _selectedIndex = 1);
        unawaited(_retryAiExtraction());
      }
    } catch (error) {
      debugPrint('[NSRP] Revision sync failed (${error.runtimeType}).');
      if (mounted) {
        AppToast.error(
          context,
          'Saving the updated NSRP PDF failed. Please review and retry.',
        );
      }
    } finally {
      _regeneratingNsrp = false;
    }
  }

  Future<void> _saveNsrpForm(Map<String, dynamic> updatedForm) async {
    await PesoApiClient.saveOnboarding(<String, dynamic>{
      'pesoFormData': updatedForm,
    });
    await _loadAccountProfile();
    if (mounted) {
      AppToast.success(context, 'Your NSRP form details were saved in PESO.');
    }
  }

  /// Users can replace their own stored PDF. The old version remains in
  /// private GridFS for audit/history, and only the newest is shown first.
  Future<bool> _replacePdf(String category) async {
    if (!const {
      'resume_upload',
      'resume_builder',
      'nsrp_form',
    }.contains(category)) {
      if (mounted) {
        AppToast.error(context, 'This document type cannot be replaced.');
      }
      return false;
    }
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: category == 'nsrp_form'
            ? const ['pdf'] : const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return false;
      final file = picked.files.single;
      final bytes = file.bytes;
      final validPdf = bytes != null && bytes.length >= 5 &&
          bytes[0] == 0x25 && bytes[1] == 0x50 &&
          bytes[2] == 0x44 && bytes[3] == 0x46 && bytes[4] == 0x2d;
      final validPng = bytes != null && bytes.length >= 8 &&
          bytes[0] == 0x89 && bytes[1] == 0x50 &&
          bytes[2] == 0x4e && bytes[3] == 0x47;
      final validJpg = bytes != null && bytes.length >= 3 &&
          bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
      if (bytes == null || bytes.length > ProfileArtifactService.maxArtifactBytes ||
          !(validPdf || (category != 'nsrp_form' && (validPng || validJpg)))) {
        if (mounted) AppToast.error(context,
          'Choose a PDF/JPG/PNG resume under 20 MB or a PDF for NSRP.');
        return false;
      }
      final newCategory = category == 'nsrp_form'
          ? 'nsrp_form'
          : 'resume_upload';
      await PesoApiClient.uploadArtifact(
        fileName: file.name,
        category: newCategory,
        mimeType: validPdf ? 'application/pdf' :
          validPng ? 'image/png' : 'image/jpeg',
        bytes: bytes,
      );
      if (newCategory == 'resume_upload') {
        _pendingResumeExtraction = ProfileArtifactInput(
          fileName: file.name, category: 'resume_upload',
          mimeType: validPdf ? 'application/pdf' :
            validPng ? 'image/png' : 'image/jpeg',
          bytes: bytes,
        );
        try {
          await PesoApiClient.saveOnboarding(<String, dynamic>{
            'resumeData': <String, dynamic>{
              ..._resumeData,
              'fileName': file.name,
              'lastDocumentUpdatedAt': DateTime.now().toUtc().toIso8601String(),
            },
          });
        } catch (_) {
          if (mounted) {
            AppToast.warning(
              context,
              'The revised PDF was uploaded, but resume metadata needs a refresh.',
            );
          }
        }
      }
      await _loadAccountProfile();
      if (mounted) {
        AppToast.success(context, 'Revised resume/document saved to your PESO account.');
        if (newCategory == 'resume_upload' &&
            _accountDocuments['formSubmitted'] == true) {
          setState(() => _selectedIndex = 1);
          unawaited(_retryAiExtraction());
        }
      }
      return true;
    } on PesoApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
      return false;
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not save the PDF. Try again.');
      }
      return false;
    }
  }

  Future<void> _loadProfilePhoto(String artifactId) async {
    try {
      final bytes = await PesoApiClient.readArtifactBytes(artifactId);
      if (!mounted) return;
      setState(() {
        _loadedPhotoId = artifactId;
        _profilePhotoBytes = bytes;
      });
    } catch (_) {
      if (mounted) {
        AppToast.warning(
          context,
          'Your profile photo could not be loaded. You can choose another photo from My Account.',
        );
      }
    }
  }

  Future<void> _setAvatarStyle(String style) async {
    if (!pesoAvatarStyles.contains(style)) return;
    try {
      await PesoApiClient.updateProfile(<String, dynamic>{
        'avatarStyle': style,
      });
      await _loadAccountProfile();
      if (mounted) AppToast.success(context, 'Your avatar has been saved.');
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not save your avatar. Try again.');
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
        if (mounted) {
          AppToast.warning(
            context,
            'Choose a JPG or PNG profile photo smaller than 3 MB.',
          );
        }
        return;
      }
      final extension = (file.extension ?? '').toLowerCase();
      await PesoApiClient.uploadArtifact(
        fileName: file.name,
        category: 'profile_photo',
        mimeType: extension == 'png' ? 'image/png' : 'image/jpeg',
        bytes: bytes,
      );
      await _loadAccountProfile();
      if (mounted) {
        AppToast.success(context, 'Profile photo uploaded privately to PESO.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          'Your profile photo could not be uploaded. Use a valid JPG or PNG and try again.',
        );
      }
    }
  }

  Future<void> _savePersonalEdits() async {
    final nameParts = _nameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    final firstName = nameParts.isEmpty ? '' : nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    if (firstName.isEmpty || lastName.isEmpty) {
      AppToast.warning(
        context,
        'Complete your name in My Account before saving.',
      );
      setState(() => _selectedIndex = 4);
      return;
    }
    try {
      await AuthService.saveAccountProfile({
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': _accountProfile['phoneNumber']?.toString() ?? '',
        'location': _accountProfile['location']?.toString() ?? '',
        'educationLevel': _accountProfile['educationLevel']?.toString() ?? '',
        'employmentStatus':
            _accountProfile['employmentStatus']?.toString() ?? '',
        'professionalTitle': _titleController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      await _loadAccountProfile();
      if (mounted) {
        AppToast.success(
          context,
          'Your personal profile changes were saved. Verified AI extraction remains unchanged.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          'Could not save your profile. Please try again.',
        );
      }
    }
  }

  Future<void> _saveAccountProfile(Map<String, dynamic> updates) async {
    final previousEducation =
        _accountProfile['educationLevel']?.toString().trim() ?? '';
    await AuthService.saveAccountProfile(updates);
    final latest = await AuthService.getCurrentUserProfile();
    if (!mounted) return;
    final educationChanged =
        previousEducation !=
        (latest['educationLevel']?.toString().trim() ?? '');
    setState(() {
      _accountProfile = latest;
      _userName = latest['displayName']?.toString() ?? _userName;
      if (educationChanged) {
        markReadinessReportsForRecheck(
          _assessmentOutcomes,
          reason: 'Your education in My Account was updated.',
        );
      }
    });
    if (educationChanged) await _persistOutcomes();
  }

  Future<void> _persistPreferences() async {
    try {
      await AuthService.savePreferences({
        'language': _selectedLanguage,
        'emailNotifications': _emailNotifications,
        'appNotifications': _appNotifications,
      });
    } catch (error) {
      debugPrint('[PROFILE] Could not save preferences: $error');
    }
  }

  Future<void> _persistOutcomes() async {
    try {
      await AuthService.saveAssessmentOutcomes(_assessmentOutcomes);
    } catch (error) {
      debugPrint('[PROFILE] Could not save assessment outcomes: $error');
    }
  }

  @override
  void dispose() {
    _jobExpiryTimer?.cancel();
    _jobSearchDebounce?.cancel();
    _jobSearchController.dispose();
    _nameController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F4),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.02, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey<int>(_selectedIndex),
                    child: _buildCurrentView(),
                  ),
                ),
              ),
              if (MediaQuery.sizeOf(context).width < 1100)
                _buildCompactNavigation(),
            ],
          ),
          if (_isLoggingOut) _buildLogoutOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth < 1100) {
      return Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, const Color(0xFF3C8261)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: Colors.white,
                  child: Image.asset(
                    'lib/assets/peso_app_icon.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'JobKonek',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'PESO application notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => unawaited(_openNotifications()),
            ),
            PopupMenuButton<int>(
              tooltip: 'Open dashboard navigation',
              icon: Icon(Icons.menu, color: _primary),
              onSelected: (value) async {
                if (value < 4) {
                  setState(() => _selectedIndex = value);
                } else if (value == 4) {
                  setState(() => _selectedIndex = 4);
                } else {
                  setState(() => _isLoggingOut = true);
                  try {
                    await AuthService.signOut();
                  } catch (error) {
                    debugPrint('[AUTH] Sign-out issue: $error');
                  }
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LandingPage()),
                      (route) => false,
                    );
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 0, child: Text('Job Feed')),
                PopupMenuItem(value: 1, child: Text('AI Profile')),
                PopupMenuItem(value: 2, child: Text('Outcomes')),
                PopupMenuItem(value: 3, child: Text('Settings')),
                PopupMenuItem(value: 4, child: Text('My Account')),
                PopupMenuItem(value: 5, child: Text('Logout')),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      height: 90,
      padding: EdgeInsets.symmetric(horizontal: screenWidth < 1450 ? 24 : 50),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, const Color(0xFF3C8261)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Image.asset(
                      'lib/assets/peso_app_icon.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Text(
                'JobKonek',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNavTab('Job Feed', 0),
              _buildNavTab('AI Profile', 1),
              _buildNavTab('Outcomes', 2),
              _buildNavTab('Settings', 3),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 26),
                color: _textLight,
                tooltip: 'View PESO application notifications',
                onPressed: () => unawaited(_openNotifications()),
              ),
              const SizedBox(width: 20),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              const SizedBox(width: 20),
              InkWell(
                onTap: () => setState(() => _selectedIndex = 4),
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            (_accountProfile['location'] as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? _accountProfile['location'] as String
                                : 'My Account',
                            style: TextStyle(
                              color: _textLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 15),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _primary, width: 2),
                        ),
                        child: PesoProfileAvatar(
                          radius: 20,
                          style:
                              _accountProfile['avatarStyle']?.toString() ??
                              'person',
                          photoBytes: _profilePhotoBytes,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 15),
              IconButton(
                icon: const Icon(Icons.logout, size: 22),
                color: Colors.redAccent,
                tooltip: 'Logout',
                onPressed: () async {
                  setState(() => _isLoggingOut = true);
                  try {
                    await AuthService.signOut();
                  } catch (error) {
                    debugPrint('[AUTH] Sign-out issue: $error');
                  }
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LandingPage()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactNavigation() {
    const icons = <IconData>[
      Icons.work_outline_rounded,
      Icons.auto_awesome_outlined,
      Icons.bar_chart_outlined,
      Icons.tune_outlined,
      Icons.person_outline_rounded,
    ];
    const names = <String>[
      'Job Feed',
      'AI Profile',
      'Outcomes',
      'Settings',
      'My Account',
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Color(0xFCFFFFFF),
          border: Border(top: BorderSide(color: Color(0xFFDCE9E1))),
        ),
        child: Row(
          children: List.generate(icons.length, (index) {
            final active = index == _selectedIndex;
            return Expanded(
              child: Center(
                child: IconButton(
                  tooltip: names[index],
                  isSelected: active,
                  onPressed: () => setState(() => _selectedIndex = index),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: active
                        ? const Color(0xFFE1F0E6)
                        : Colors.transparent,
                    foregroundColor: active ? _primary : _textLight,
                  ),
                  icon: Icon(icons[index], size: 23),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavTab(String title, int index) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : PesoTokens.durationNormal,
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 1450 ? 8 : 22,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE8F3ED) : Colors.transparent,
            border: Border.all(
              color: isActive ? const Color(0xFFCEE2D4) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            _translate(title),
            style: TextStyle(
              color: isActive ? _primary : _textLight,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return UserJobFeedTab(
          userName: _userName,
          availableJobs: _filteredAvailableJobs(),
          jobsLoading: _jobsLoading,
          jobLoadError: _jobLoadError,
          onRetryJobs: () => unawaited(_loadJobPostings()),
          hasMoreJobs: _nextJobPageToken != null,
          loadingMoreJobs: _loadingMoreJobs,
          onLoadMoreJobs: () => unawaited(_loadMoreJobPostings()),
          interestLabels: recognizedJobInterests(_preferredOccupation),
          preferredOccupation: _preferredOccupation,
          translatedJob:
              _jobTranslationCache['${_selectedJob?['id']}|$_selectedLanguage'],
          translationLoading: _translationPending.contains(
            '${_selectedJob?['id']}|$_selectedLanguage',
          ),
          translationFailed: _translationErrors.contains(
            '${_selectedJob?['id']}|$_selectedLanguage',
          ),
          onRetryTranslation: () =>
              unawaited(_translateSelectedJob(forceRetry: true)),
          linkedRoles: _linkedRolesForSelectedNotice(),
          onCompareRoles: _compareNoticeRoles,
          searchController: _jobSearchController,
          searchQuery: _jobSearchQuery,
          onSearchChanged: (query) {
            setState(() {
              _jobSearchQuery = query;
              final visible = _filteredAvailableJobs();
              _selectedJob = visible.isEmpty ? null : visible.first;
              _hasManuallySelectedJob = false;
            });
            _scheduleJobSearch();
          },
          selectedLanguage: _selectedLanguage,
          newRegistration: widget.newRegistration,
          selectedCategory: _selectedJobCategory,
          onCategoryChanged: (category) {
            final visible = _filteredAvailableJobs(category);
            setState(() {
              _selectedJobCategory = category;
              _selectedJob = visible.isEmpty ? null : visible.first;
              _hasManuallySelectedJob = false;
            });
            unawaited(_loadJobPostings());
          },
          selectedJob: _selectedJob,
          detailsAnchor: _jobDetailsAnchor,
          onSelectJob: (job) {
            setState(() {
              _selectedJob = job;
              _hasManuallySelectedJob = true;
            });
            unawaited(_translateSelectedJob());
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final target = _jobDetailsAnchor.currentContext;
              if (target == null) return;
              Scrollable.ensureVisible(
                target,
                alignment: 0.05,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
              );
            });
          },
          onEvaluateJob: _evaluateJobQualification,
          translate: _translate,
          primary: _primary,
          textDark: _textDark,
          textLight: _textLight,
        );
      case 1:
        return UserAiProfileTab(
          nameController: _nameController,
          titleController: _titleController,
          bioController: _bioController,
          userSkills: _userSkills,
          aiProfileData: _aiProfileData,
          aiExtractionUnavailable: _aiUnavailable,
          sourcesSaved: widget.onboardingSourcesSaved,
          retryingAi: _retryingAi,
          onRetryAi: _retryAiExtraction,
          onSavePersonalDetails: _savePersonalEdits,
          onEditQualifications: () => _editQualifications(<String, dynamic>{}),
          resumeData: _resumeData,
          pesoFormData: _pesoFormData,
          artifacts: _profileArtifacts,
          onReplacePdf: _replacePdf,
          onSaveNsrp: _saveNsrpForm,
          onRebuildNsrp: _editOfficialNsrp,
          translate: _translate,
          primary: _primary,
          textDark: _textDark,
          textLight: _textLight,
        );
      case 2:
        return UserOutcomesTab(
          assessmentOutcomes: _assessmentOutcomes,
          applications: _myApplications,
          applicationsLoading: _applicationsLoading,
          applicationsError: _applicationsError,
          focusedApplicationId: _focusedApplicationId,
          onRefreshApplications: () => unawaited(_loadMyApplications()),
          onSubmitReadiness: _submitReadinessApplication,
          onEditQualifications: _editQualifications,
          onEditPersonalInfo: () => setState(() => _selectedIndex = 4),
          onRecheckReadiness: _recheckSavedReadiness,
          submittingReportId: _submittingReportId,
          translate: _translate,
          primary: _primary,
          textDark: _textDark,
          textLight: _textLight,
        );
      case 3:
        return UserSettingsTab(
          selectedLanguage: _selectedLanguage,
          onLanguageChanged: (lang) {
            setState(() {
              _selectedLanguage = lang;
              _languageChosenInThisSession = true;
            });
            _persistPreferences();
            unawaited(_translateSelectedJob());
          },
          emailNotifications: _emailNotifications,
          onEmailNotificationsChanged: (val) {
            setState(() => _emailNotifications = val);
            _persistPreferences();
          },
          appNotifications: _appNotifications,
          onAppNotificationsChanged: (val) {
            setState(() => _appNotifications = val);
            _persistPreferences();
          },
          translate: _translate,
          primary: _primary,
          textDark: _textDark,
          textLight: _textLight,
        );
      case 4:
        return UserAccountTab(
          profile: _accountProfile,
          documents: _accountDocuments,
          onEditNsrp: () => unawaited(_editOfficialNsrp()),
          onCreateResume: () => unawaited(_openResumeBuilder()),
          onReplaceResume: () => _replacePdf('resume_upload'),
          onReviewAi: () => setState(() => _selectedIndex = 1),
          photoBytes: _profilePhotoBytes,
          onUploadPhoto: _uploadProfilePhoto,
          onChooseAvatar: _setAvatarStyle,
          onSave: _saveAccountProfile,
          primary: _primary,
          textDark: _textDark,
          textLight: _textLight,
        );
      default:
        return const Center(child: Text('View not found'));
    }
  }

  /// A readiness preview is private; submission requires a separate consent.
  /// No rule-based score is sent or used to disqualify job seekers.
  Future<void> _submitReadinessApplication(Map<String, dynamic> report) async {
    if (_submittingReportId != null || report['applicationSubmitted'] == true) {
      return;
    }
    // MRQ is collected only AFTER the saved-profile AI evaluation, when the
    // applicant explicitly chooses to continue or submit an application.
    // Its answers are PESO screening information, not training/scoring input.
    final jobId = report['jobId']?.toString() ?? '';
    final title = report['job']?.toString() ?? '';
    final company = report['company']?.toString() ?? '';
    final candidates = _availableJobs.where((job) {
      if (jobId.isNotEmpty && job['id']?.toString() == jobId) return true;
      return job['title']?.toString() == title &&
          job['company']?.toString() == company;
    }).toList();
    if (candidates.isEmpty) {
      AppToast.info(
        context,
        'This job is no longer in the active feed. Check the latest openings before applying.',
      );
      return;
    }
    var answers = report['answers'];
    if (answers is! Map || answers.length < 10) {
      final screening = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: true,
        builder: (_) =>
            JobReadinessDialog(job: candidates.first, primary: _primary),
      );
      if (!mounted || screening == null) return;
      final responses = screening['answers'];
      if (responses is! Map || responses.length < 10) {
        AppToast.warning(
          context,
          'Complete all 10 PESO application questions.',
        );
        return;
      }
      setState(() {
        report['answers'] = Map<String, String>.from(responses);
        report['questionnaireStatus'] = 'completed';
        // Keep self-reported MRQ guidance separate from model evidence.
        report['mrqGuidance'] = <String, dynamic>{
          'strengths': screening['strengths'],
          'improvements': screening['improvements'],
          'nextSteps': screening['nextSteps'],
        };
      });
      // Save to the applicant's authenticated outcomes even if they later
      // decide not to submit the separate PESO job application.
      await _persistOutcomes();
      if (!mounted) return;
      answers = report['answers'];
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Send application to PESO?'),
        content: const Text(
          'Your screening answers and the selected job will be submitted to the PESO office for review. '
          'This is optional; the readiness report itself is not an application. '
          'Submitting does not guarantee an interview or an offer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit my application'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;

    final requestId = report['createdAt']?.toString() ?? title;
    setState(() => _submittingReportId = requestId);
    try {
      final applicationResponse = await PesoApiClient.submitJobApplication(
        job: <String, dynamic>{...candidates.first, 'match': null},
        answers: Map<String, dynamic>.from(answers),
      );
      if (!mounted) return;
      final application = applicationResponse['application'];
      if (application is! Map) {
        throw StateError('The PESO API did not confirm the submission.');
      }
      setState(() {
        report['applicationSubmitted'] = true;
        report['applicationId'] = application['id']?.toString() ?? '';
        report['applicationStatus'] =
            application['status']?.toString() ?? 'submitted';
        report['submittedAt'] = application['submittedAt'];
      });
      await _persistOutcomes();
      unawaited(_loadMyApplications());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF218352)),
              SizedBox(width: 10),
              Expanded(child: Text('Application submitted')),
            ],
          ),
          content: const Text(
            'PESO received your application for review. This is not an employer hiring decision or guarantee of an interview. View its progress in Outcomes.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          error is PesoApiException
              ? error.message
              : 'Your application was not confirmed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submittingReportId = null);
    }
  }

  Future<void> _compareNoticeRoles(List<Map<String, dynamic>> roles) async {
    final notice = _selectedJob;
    if (notice == null || notice['aiListingKind'] != 'notice') return;
    final noticeId = notice['id']?.toString() ?? '';
    final permittedIds = _linkedRolesForSelectedNotice()
        .map((role) => role['id']?.toString() ?? '')
        .toSet();
    final roleIds = roles.map((role) => role['id']?.toString() ?? '').toList();
    if (noticeId.isEmpty ||
        roleIds.length < 2 ||
        roleIds.length > 6 ||
        roleIds.toSet().length != roleIds.length ||
        roleIds.any((id) => id.isEmpty || !permittedIds.contains(id))) {
      AppToast.warning(
        context,
        'Choose two to six positions from this hiring notice.',
      );
      return;
    }
    final overlay = OverlayEntry(
      builder: (_) => const JobMatchProgressOverlay(
        jobTitle: 'Comparing individually selected roles',
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(overlay);
    Map<String, dynamic>? result;
    try {
      result = await PesoApiClient.compareNoticeRoles(
        noticeId: noticeId,
        jobIds: roleIds,
      );
    } on PesoApiException catch (error) {
      if (mounted) AppToast.warning(context, error.message);
    } catch (_) {
      if (mounted) {
        AppToast.warning(
          context,
          'Role comparison is unavailable. You can still evaluate or apply for an individual position.',
        );
      }
    } finally {
      overlay.remove();
      overlay.dispose();
    }
    if (!mounted || result == null) return;
    final reported = result['results'];
    final matchedIds = reported is List
        ? reported
              .whereType<Map>()
              .map((row) => row['jobId']?.toString())
              .toSet()
        : <String?>{};
    if (result['status'] != 'ready' ||
        !roleIds.every((id) => matchedIds.contains(id))) {
      AppToast.warning(
        context,
        'The model could not verify every selected position. Individual applications remain available.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => NoticeRoleComparisonDialog(
        roles: roles,
        result: result!,
        onEvaluate: (role) {
          Navigator.of(dialogContext).pop();
          if (mounted) {
            unawaited(_evaluateJobQualification(role));
          }
        },
      ),
    );
  }

  Future<void> _evaluateJobQualification(Map<String, dynamic> job) async {
    // Evaluate using previously verified NSRP/resume evidence: no MRQ yet.
    final report = buildJobReadinessReport(job, const <String, String>{});
    report['questionnaireStatus'] = 'not_started';
    await _runJobMatch(report, job);
    if (!mounted) return;
    setState(() => _assessmentOutcomes.insert(0, report));
    await _persistOutcomes();
    if (!mounted) return;
    await _showJobEvaluationResult(report);
  }

  Future<void> _showJobEvaluationResult(Map<String, dynamic> report) async {
    if (!mounted) return;
    final jobId = report['jobId']?.toString() ?? '';
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => JobEvaluationResultDialog(
        report: report,
        loadFeedback: report['aiMatchingStatus'] == 'ready' && jobId.isNotEmpty
            ? () => PesoApiClient.explainJobMatch(jobId: jobId)
            : null,
      ),
    );
    if (!mounted) return;
    // Any explanation is saved with Outcomes, but Go evidence and its score
    // remain unchanged. The popup itself never sends an application.
    await _persistOutcomes();
    if (!mounted) return;
    if (choice != null && choice.startsWith('job:')) {
      final targetId = choice.substring(4);
      final candidates = _availableJobs
          .where((job) => job['id']?.toString() == targetId)
          .toList();
      if (candidates.isNotEmpty) {
        setState(() {
          _selectedJob = candidates.first;
          _hasManuallySelectedJob = true;
          _selectedIndex = 0;
        });
        AppToast.info(
          context,
          'Related job selected. Review its details before evaluating or applying.',
        );
        return;
      }
    }
    setState(() => _selectedIndex = 2);
    if (choice == 'apply') {
      await _submitReadinessApplication(report);
    }
  }

  Future<void> _runJobMatch(
    Map<String, dynamic> report,
    Map<String, dynamic> job,
  ) async {
    // Older model evidence must never linger after a profile correction.
    report.remove('modelMatch');
    report.remove('modelVersion');
    report.remove('jobFeedback');
    report.remove('aiMatchingProblem');
    final oldReviewNotes = (report['modelReviewNotes'] as List?) ?? const [];
    if (report['nextSteps'] is List) {
      report['nextSteps'] = (report['nextSteps'] as List)
          .where((item) => !oldReviewNotes.contains(item))
          .toList();
    }
    report.remove('modelReviewNotes');
    for (final key in ['strengths', 'improvements']) {
      if (report[key] is List) {
        report[key] = (report[key] as List).where((item) {
          final text = item.toString();
          return !text.startsWith('Relevant skill: ') &&
              !text.startsWith('Role-related skill you listed: ') &&
              !text.startsWith('Optional skill area to explore: ') &&
              !text.startsWith('Requirement to review: ');
        }).toList();
      }
    }
    final jobId = job['id']?.toString() ?? '';
    if (job['aiListingKind']?.toString().toLowerCase() == 'notice') {
      // A compilation notice is not an individual job. Do not suggest
      // that the trained model scored it, but keep the PESO application open.
      report['aiMatchingStatus'] = 'notice';
    } else if (jobId.isEmpty) {
      // Never request all jobs and accidentally display another role's score.
      report['aiMatchingStatus'] = 'missing_job';
    } else {
      final progress = OverlayEntry(
        builder: (_) => JobMatchProgressOverlay(
          jobTitle: job['title']?.toString() ?? 'Selected job',
        ),
      );
      final clock = Stopwatch()..start();
      Overlay.of(context, rootOverlay: true).insert(progress);
      try {
        final result = await PesoApiClient.evaluateJobMatch(jobId: jobId);
        final entries = result['results'];
        Map<String, dynamic>? match;
        if (entries is List) {
          for (final entry in entries) {
            if (entry is Map && entry['jobId']?.toString() == jobId) {
              match = Map<String, dynamic>.from(entry);
              break;
            }
          }
        }
        if (result['status'] == 'ready' &&
            match != null &&
            match['score'] is num) {
          report['modelMatch'] = match;
          report['modelVersion'] = result['modelVersion'];
          report['aiMatchingStatus'] = 'ready';
          final assessmentBasis = match['assessmentBasis']?.toString() ?? '';
          final titleCluesOnly =
              assessmentBasis == 'job_title_clues_only' ||
              assessmentBasis == 'occupation_category_clues_only';
          report['message'] = titleCluesOnly
              ? 'PESO Mini-AI compared the occupation fields saved during your Gemini NSRP/resume intake with this job category. Employer-specific requirements were not verified, so no qualification score is displayed. These are optional career suggestions, not hiring requirements.'
              : assessmentBasis == 'job_details_unverified'
              ? 'PESO Mini-AI checked this selected role and your saved background. The posting does not yet contain enough role-attributed requirements to justify a numerical alignment score. Review your questionnaire guidance and ask PESO for the actual job qualifications.'
              : 'PESO Mini-AI compared your source-supported career categories with this job. A numeric result reflects broad occupational similarity only; any actual employer requirements are displayed separately for human verification. It is not a hiring decision or employment probability.';
          report['strengths'] = [
            ...((report['strengths'] as List?) ?? <dynamic>[]),
            ...((match['matchedSkills'] as List?) ?? <dynamic>[]).map(
              (item) =>
                  'Relevant skill: ${item.toString().replaceAll('_', ' ')}',
            ),
            if (titleCluesOnly)
              ...((match['matchedTitleClues'] as List?) ?? <dynamic>[]).map(
                (item) =>
                    'Role-related skill you listed: ${item.toString().replaceAll('_', ' ')} (job-title clue only)',
              ),
          ];
          report['improvements'] = [
            ...((report['improvements'] as List?) ?? <dynamic>[]),
            ...((match['missingMandatory'] as List?) ?? <dynamic>[]).map(
              (item) => 'Requirement to review: $item',
            ),
            if (titleCluesOnly)
              ...((match['skillsToExplore'] as List?) ?? <dynamic>[]).map(
                (item) =>
                    'Optional skill area to explore: ${item.toString().replaceAll('_', ' ')} (not an employer requirement)',
              ),
          ];
          final reviewNotes = ((match['needsReview'] as List?) ?? <dynamic>[])
              .map((item) => item.toString())
              .toList();
          report['modelReviewNotes'] = reviewNotes;
          report['nextSteps'] = [
            ...((report['nextSteps'] as List?) ?? <dynamic>[]),
            ...reviewNotes,
          ];
        } else {
          report['aiMatchingStatus'] = result['status'] == 'ready'
              ? 'incomplete'
              : result['status']?.toString() ?? 'unavailable';
        }
      } on PesoApiException catch (error) {
        report['aiMatchingStatus'] = 'unavailable';
        report['aiMatchingProblem'] =
            error.code; // Safe code, never resume PII.
      } catch (_) {
        report['aiMatchingStatus'] = 'unavailable';
      } finally {
        // Let users actually see that a request happened, even when it is fast.
        // This is an indeterminate spinner, never fabricated progress or scoring.
        final remaining = const Duration(milliseconds: 950) - clock.elapsed;
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
        progress.remove();
        progress.dispose();
      }
    }
  }

  Future<void> _editQualifications(Map<String, dynamic> report) async {
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      builder: (_) => UserQualificationsEditor(
        pesoFormData: _pesoFormData,
        resumeData: _resumeData,
        accountProfile: _accountProfile,
        onSave: (updated) async {
          // The authenticated API persists only this user's editable source.
          // Do not overwrite account identity, AI facts, or the original PDFs.
          final safeEvidence = buildOnboardingAiEvidence(
            resumeData: _resumeData,
            pesoFormData: updated,
          );
          await AuthService.saveOnboardingData(
            pesoFormData: updated,
            onboardingText: safeEvidence,
          );
          if (!mounted) return;
          setState(() {
            _pesoFormData = updated;
            _accountProfile = {..._accountProfile, 'pesoFormData': updated};
            markReadinessReportsForRecheck(
              _assessmentOutcomes,
              reason: 'Your applicant-owned NSRP details have been updated.',
            );
          });
          await _persistOutcomes();
        },
      ),
    );
  }

  Future<void> _recheckSavedReadiness(Map<String, dynamic> report) async {
    final jobId = report['jobId']?.toString() ?? '';
    final matches = _availableJobs
        .where((item) => item['id']?.toString() == jobId)
        .toList();
    if (jobId.isEmpty || matches.isEmpty) {
      if (mounted) {
        AppToast.info(
          context,
          'This job is not currently available for an AI recheck. You can still contact PESO.',
        );
      }
      return;
    }
    final job = matches.first;
    await _runJobMatch(report, job);
    if (!mounted) return;
    setState(() => _selectedIndex = 2);
    await _persistOutcomes();
    if (!mounted) return;
    await _showJobEvaluationResult(report);
  }

  String _translate(String text) {
    if (_selectedLanguage == 'English') return text;
    final Map<String, Map<String, String>> dictionary = {
      'AI Extracted Profile': {
        'Tagalog': 'AI Extracted Profile',
        'Taglish': 'AI Profile Extracted',
      },
      'Job Feed': {'Tagalog': 'Lokal na Trabaho', 'Taglish': 'Job Feed'},
      'Welcome back, ${_userName.split(" ")[0]}!': {
        'Tagalog': 'Maligayang pagbabalik, ${_userName.split(" ")[0]}!',
        'Taglish': 'Welcome back, ${_userName.split(" ")[0]}!',
      },
      'Discover your top AI-matched opportunities based on your extracted skills.':
          {
            'Tagalog': 'Tuklasin ang iyong mga nangungunang AI-matched na trabaho mula sa iyong skills.',
            'Taglish':
                'Discover your top AI-matched roles based on your skills.',
          },
      'Outcomes & Action Plans': {
        'Tagalog': 'Mga Resulta at Plano',
        'Taglish': 'Qualification Results & Plans',
      },
      'Account Settings': {
        'Tagalog': 'Mga Setting ng Account',
        'Taglish': 'Account Settings',
      },
    };
    if (dictionary.containsKey(text)) {
      return dictionary[text]![_selectedLanguage] ?? text;
    }
    return text;
  }

  Widget _buildLogoutOverlay() {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(50),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _primary, strokeWidth: 4),
                  const SizedBox(height: 30),
                  Text(
                    _translate('Securing session...'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _translate('Safely logging you out of JobKonek.'),
                    style: TextStyle(color: _textLight, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
