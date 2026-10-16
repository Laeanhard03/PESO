import 'dart:ui';

import 'package:flutter/material.dart';

import '../Landingpage/landingpage_ui.dart';
import '../../peso_services/auth_service.dart';
import '../../peso_services/profile_artifact_service.dart';

// Tab File Imports
import 'user_job_feed_tab.dart';
import 'user_ai_profile_tab.dart';
import 'user_outcomes_tab.dart';
import 'user_settings_tab.dart';
import 'user_account_tab.dart';

class UserProfile extends StatefulWidget {
  final Map<String, dynamic>? aiProfileData;

  const UserProfile({super.key, this.aiProfileData});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  int _selectedIndex = 0;
  bool _isLoggingOut = false;
  String _selectedLanguage = 'English';
  bool _emailNotifications = true;
  bool _appNotifications = true;
  Map<String, dynamic> _accountProfile = <String, dynamic>{};
  Map<String, dynamic> _aiProfileData = <String, dynamic>{};
  Map<String, dynamic> _resumeData = <String, dynamic>{};
  Map<String, dynamic> _pesoFormData = <String, dynamic>{};
  List<Map<String, dynamic>> _profileArtifacts = <Map<String, dynamic>>[];

  // Controllers for AI Profile Tab
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _bioController;

  // AI Extracted Variables
  List<String> _userSkills = [];
  String _userName = 'Job Seeker';
  String _userTitle = 'Professional';

  // --- JOB FEED DATA ---
  final List<Map<String, dynamic>> _availableJobs = [
    {
      'title': 'IT Support Specialist',
      'company': 'Montalban LGU',
      'location': 'San Mateo (Hybrid)',
      'salary': 'PHP 18,000 - 25,000',
      'type': 'Contract',
      'vacancies': '5',
      'match': 65,
      'logoColor': Colors.green,
      'image': 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?auto=format&fit=crop&w=600&q=80',
      'description': 'Join the municipal IT team to provide hardware and software support for local government offices. This role requires excellent troubleshooting and communication skills.',
      'reqs': [
        'Hardware troubleshooting',
        'Network setup & maintenance',
        'Customer service oriented',
      ],
    },
    {
      'title': 'Administrative Assistant',
      'company': 'Rizal Prov. Gov',
      'location': 'Antipolo (On-site)',
      'salary': 'PHP 16,000 - 20,000',
      'type': 'Full-time',
      'vacancies': '8',
      'match': 55,
      'logoColor': Colors.orange,
      'image': 'https://images.unsplash.com/photo-1556761175-4b46a572b786?auto=format&fit=crop&w=600&q=80',
      'description': 'Manage daily administrative operations including scheduling, document routing, and front-desk reception for regional government offices.',
      'reqs': [
        'Excellent communication skills',
        'Office management',
        'Organization',
      ],
    },
  ];

  Map<String, dynamic>? _selectedJob;
  final List<Map<String, dynamic>> _assessmentOutcomes = [];

  final Color _primary = const Color(0xFF2E7D32);
  final Color _bgColor = const Color(0xFFF4F7F9);
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textLight = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _initializeAIProfileData();
    _loadAccountProfile();
    if (_availableJobs.isNotEmpty) {
      _selectedJob = _availableJobs[0];
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

      _generateDynamicAIJobs();
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
      try {
        profileArtifacts = await ProfileArtifactService.getCurrentUserArtifacts();
      } catch (error) {
        debugPrint('[PROFILE] Could not load saved documents: $error');
      }

      setState(() {
        _resumeData = resumeData;
        _pesoFormData = pesoFormData;
        _profileArtifacts = profileArtifacts;
        _accountProfile = data;
        _aiProfileData = widget.aiProfileData != null && widget.aiProfileData!.isNotEmpty
            ? Map<String, dynamic>.from(widget.aiProfileData!)
            : aiProfile;
        if (fullName != null && fullName.isNotEmpty) _userName = fullName;
        if (preferences['language'] is String) {
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
            ..addAll(savedOutcomes.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
        }
        if (widget.aiProfileData == null && aiProfile.isNotEmpty) {
          _userTitle = aiProfile['professionalTitle']?.toString() ?? _userTitle;
          _nameController.text = aiProfile['fullName']?.toString() ?? _userName;
          _titleController.text = _userTitle;
          _bioController.text = aiProfile['bilingualBio']?.toString() ?? _bioController.text;
          final skills = aiProfile['skills'];
          if (skills is List) _userSkills = skills.map((item) => item.toString()).toList();
        } else if (widget.aiProfileData == null) {
          _nameController.text = _userName;
        }
      });

      if (aiProfile.isNotEmpty && _availableJobs.length == 2) {
        _generateDynamicAIJobs();
      }
    } catch (error) {
      debugPrint('[PROFILE] Could not load user profile: $error');
    }
  }

  Future<void> _saveAccountProfile(Map<String, dynamic> updates) async {
    await AuthService.saveAccountProfile(updates);
    final latest = await AuthService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() {
      _accountProfile = latest;
      _userName = latest['displayName']?.toString() ?? _userName;
    });
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

  void _generateDynamicAIJobs() {
    Map<String, dynamic> topMatch = {
      'title': 'Senior $_userTitle',
      'company': 'Montalban Tech Hub',
      'location': 'Remote / Online Work',
      'salary': 'PHP 45,000 - 65,000',
      'type': 'Full-time',
      'vacancies': '1',
      'match': 98,
      'logoColor': Colors.indigo,
      'image': 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=600&q=80',
      'description':
          'AI Match System Alert: Based on your newly uploaded resume, your skills perfectly align with this remote position. We are urgently looking for a $_userTitle with your exact background.',
      'reqs': _userSkills.isNotEmpty
          ? _userSkills.take(3).toList()
          : ['Domain Expertise', 'Remote Communication', 'Project Management'],
    };

    Map<String, dynamic> secondaryMatch = {
      'title': '$_userTitle (Associate)',
      'company': 'Prime BPO & Tech',
      'location': 'Hybrid (Eastwood/Montalban)',
      'salary': 'PHP 25,000 - 40,000',
      'type': 'Contract',
      'vacancies': '3',
      'match': 92,
      'logoColor': Colors.blueAccent,
      'image': 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=600&q=80',
      'description': 'AI Match System Alert: Your background makes you a highly competitive candidate for this hybrid role. Rapid career growth and flexible scheduling provided.',
      'reqs': _userSkills.isNotEmpty
          ? _userSkills.skip(1).take(3).toList()
          : ['Analytical Skills', 'Team Collaboration', 'Problem Solving'],
    };

    _availableJobs.insert(0, secondaryMatch);
    _availableJobs.insert(0, topMatch);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
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
            ],
          ),
          if (_isLoggingOut) _buildLogoutOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 50),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, Colors.greenAccent.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.work, color: Colors.white, size: 28),
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
                onPressed: () {},
              ),
              const SizedBox(width: 20),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              const SizedBox(width: 20),
              InkWell(
                onTap: () => setState(() => _selectedIndex = 4),
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                            (_accountProfile['location'] as String?)?.isNotEmpty == true
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
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: _primary.withValues(alpha: 0.1),
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
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

  Widget _buildNavTab(String title, int index) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? _primary.withValues(alpha: 0.1)
                : Colors.transparent,
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
          availableJobs: _availableJobs,
          selectedJob: _selectedJob,
          onSelectJob: (job) => setState(() => _selectedJob = job),
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
          resumeData: _resumeData,
          pesoFormData: _pesoFormData,
          artifacts: _profileArtifacts,
          translate: _translate,
          primary: _primary,
          textDark: _textDark,
          textLight: _textLight,
        );
      case 2:
        return UserOutcomesTab(
          assessmentOutcomes: _assessmentOutcomes,
          translate: _translate,
          primary: _primary,
          textDark: _textDark,
          textLight: _textLight,
        );
      case 3:
        return UserSettingsTab(
          selectedLanguage: _selectedLanguage,
          onLanguageChanged: (lang) {
            setState(() => _selectedLanguage = lang);
            _persistPreferences();
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
          onSave: _saveAccountProfile,
          primary: _primary,
          textDark: _textDark,
          textLight: _textLight,
        );
      default:
        return const Center(child: Text('View not found'));
    }
  }

  void _evaluateJobQualification(
    String jobTitle,
    String company,
    int matchScore,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QualificationEvaluationDialog(
        jobTitle: jobTitle,
        company: company,
        matchScore: matchScore,
        pesoGreen: _primary,
        onComplete: (score, isPassed) {
          setState(() {
            if (isPassed) {
              _assessmentOutcomes.insert(0, {
                'job': jobTitle,
                'company': company,
                'status': 'passed',
                'score': score,
                'message': 'Your profile is pre-vetted and has been routed to the Montalban PESO Admin queue for employer review.',
              });
            } else {
              _assessmentOutcomes.insert(0, {
                'job': jobTitle,
                'company': company,
                'status': 'action_plan',
                'score': score,
                'failed_skills': [
                  'Advanced Technical Knowledge',
                  'Domain Certification Gap',
                ],
                'alt_jobs': ['Junior $jobTitle', 'Administrative Assistant'],
                'training': 'Recommended TESDA Skills Upskilling',
              });
            }
            _selectedIndex = 2; // Route user directly to Outcomes & Plans tab
          });
          _persistOutcomes();
        },
      ),
    );
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
