import 'dart:ui';

import 'package:flutter/material.dart';

import 'landing_page.dart';
import 'exam_page.dart'; // Integrating the new Exam Page

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  int _selectedIndex = 0;
  bool _isLoggingOut = false; // Controls the logout animation overlay

  // Settings States
  String _selectedLanguage = 'English'; // Options: English, Tagalog, Taglish
  bool _emailNotifications = true;
  bool _appNotifications = true;

  // --- MOCK DATABASE: AI ASSESSMENT OUTCOMES ---
  final List<Map<String, dynamic>> _assessmentOutcomes = [
    {
      'job': 'Data Encoder',
      'company': 'Prime BPO',
      'status': 'passed',
      'score': 85,
      'message': 'Your profile is pre-vetted and has been routed to the Montalban PESO Admin queue.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final Color pesoGreen = const Color(0xFF2E7D32);
    final Color sidebarColor = const Color(0xFF142015);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          Row(
            children: [
              // --- DESIGNER SIDEBAR ---
              Container(
                width: 280,
                color: sidebarColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: pesoGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.psychology,
                              color: pesoGreen,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Juan Dela Cruz',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Montalban Resident',
                            style: TextStyle(
                              color: Colors.greenAccent.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: Divider(color: Colors.white12, thickness: 1),
                    ),
                    const SizedBox(height: 15),
                    _buildSidebarItem(
                      Icons.person_outline,
                      _translate('AI Profile Builder'),
                      0,
                      pesoGreen,
                    ),
                    _buildSidebarItem(
                      Icons.work_outline,
                      _translate('Explore Local Jobs'),
                      1,
                      pesoGreen,
                    ),
                    _buildSidebarItem(
                      Icons.track_changes,
                      _translate('Outcomes & Action Plans'),
                      2,
                      pesoGreen,
                    ),
                    _buildSidebarItem(
                      Icons.settings_outlined,
                      _translate('Account Settings'),
                      3,
                      pesoGreen,
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: Divider(color: Colors.white12, thickness: 1),
                    ),
                    _buildSidebarItem(
                      Icons.logout,
                      _translate('Secure Logout'),
                      99,
                      Colors.redAccent,
                      isLogout: true,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // --- MAIN CONTENT AREA ---
              Expanded(
                child: Column(
                  children: [
                    // Minimalist Top Header
                    Container(
                      height: 90,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Column(
                              key: ValueKey<int>(_selectedIndex),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getHeaderTitle(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getHeaderSubtitle(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_active,
                                  color: Colors.orange,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 20),
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: pesoGreen.withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  'JD',
                                  style: TextStyle(
                                    color: pesoGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Dynamic View with Slide & Fade Animation
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.02, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                        child: Container(
                          key: ValueKey<int>(_selectedIndex),
                          child: _buildCurrentView(pesoGreen),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // --- LOGOUT ANIMATION OVERLAY ---
          if (_isLoggingOut)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 25),
                          Text(
                            _translate('Securing session and logging out...'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- LANGUAGE TRANSLATION HELPER ---
  String _translate(String text) {
    if (_selectedLanguage == 'English') return text;

    // Modern Tagalog & Taglish Dictionary Mockup
    final Map<String, Map<String, String>> dictionary = {
      'AI Profile Builder': {
        'Tagalog': 'Tagabuo ng AI Profile',
        'Taglish': 'Set up your AI Profile',
      },
      'Explore Local Jobs': {
        'Tagalog': 'Maghanap ng Trabaho Lokal',
        'Taglish': 'Hanap Work in Montalban',
      },
      'Outcomes & Action Plans': {
        'Tagalog': 'Mga Resulta at Plano',
        'Taglish': 'Exam Results & Action Plans',
      },
      'Account Settings': {
        'Tagalog': 'Mga Setting ng Account',
        'Taglish': 'Account Settings',
      },
      'Secure Logout': {
        'Tagalog': 'Ligtas na Pag-logout',
        'Taglish': 'Safe Logout',
      },
      'Securing session and logging out...': {
        'Tagalog': 'Sinisiguro ang session at nagla-log out...',
        'Taglish': 'Securing your session, logging out na...',
      },
    };

    if (dictionary.containsKey(text)) {
      return dictionary[text]![_selectedLanguage] ?? text;
    }
    return text;
  }

  String _getHeaderTitle() {
    switch (_selectedIndex) {
      case 0:
        return _translate('AI Profile Builder');
      case 1:
        return _translate('Explore Local Jobs');
      case 2:
        return _translate('Outcomes & Action Plans');
      case 3:
        return _translate('Account Settings');
      default:
        return 'Dashboard';
    }
  }

  String _getHeaderSubtitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Configure your digital identity for accurate exam generation.';
      case 1:
        return 'Browse offline jobs provided by PESO and take your custom AI assessments.';
      case 2:
        return 'Review your pre-vetted statuses and recommended TESDA upskilling courses.';
      case 3:
        return 'Manage your language preferences and notification settings.';
      default:
        return '';
    }
  }

  Widget _buildCurrentView(Color pesoGreen) {
    switch (_selectedIndex) {
      case 0:
        return _buildProfileBuilderView(pesoGreen);
      case 1:
        return _buildJobDiscoveryView(pesoGreen);
      case 2:
        return _buildOutcomesTrackerView(pesoGreen);
      case 3:
        return _buildSettingsView(pesoGreen);
      default:
        return const Center(child: Text('View not found'));
    }
  }

  // ==========================================
  // 1. PROFILE & BIO BUILDER
  // ==========================================
  Widget _buildProfileBuilderView(Color pesoGreen) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Container(
          width: 850,
          padding: const EdgeInsets.all(40),
          decoration: _designerCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Personal Data Context',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          value: 0.85,
                          strokeWidth: 3,
                          backgroundColor: Colors.grey.shade200,
                          color: pesoGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '85% Profile Ready',
                        style: TextStyle(
                          color: pesoGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Upload your latest PDF resume to automatically update your extracted skills.',
                      style: TextStyle(color: Colors.black87, fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Browse Files'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: _buildModernTextField('Full Name', 'Juan Dela Cruz'),
                  ),
                  const SizedBox(width: 25),
                  Expanded(
                    child: _buildModernTextField(
                      'Professional Title',
                      'Junior Software Developer',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              const Text(
                'Bilingual Bio (Tagalog/English)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ikwento ang iyong mga karanasan...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: pesoGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                'Extracted System Skills (For AI Context)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildSkillChip('Flutter Development'),
                  _buildSkillChip('Customer Service'),
                  _buildSkillChip('Database Management'),
                ],
              ),
              const SizedBox(height: 40),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Profile saved successfully.'),
                      backgroundColor: pesoGreen,
                    ),
                  ),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save Profile Updates'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pesoGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. JOB DISCOVERY & LIVE ASSESSMENT
  // ==========================================
  Widget _buildJobDiscoveryView(Color pesoGreen) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search roles in Montalban (e.g., Data Encoder, IT Support)...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView(
              children: [
                _buildJobCard(
                  'Senior Flutter Developer',
                  'TechNova Solutions',
                  'Rodriguez (On-site)',
                  'PHP 45,000 - 60,000',
                  'Full-time',
                  '2',
                  pesoGreen,
                ),
                _buildJobCard(
                  'IT Support Specialist',
                  'Montalban LGU',
                  'San Mateo (Hybrid)',
                  'PHP 18,000 - 25,000',
                  'Contract',
                  '5',
                  pesoGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(
    String title,
    String company,
    String location,
    String salary,
    String type,
    String vac,
    Color pesoGreen,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(30),
      decoration: _designerCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$vac Vacancies Available',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.business, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 5),
                    Text(
                      company,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      location,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                salary,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: pesoGreen,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                // --- INTEGRATION: Opens the new AIExamPage ---
                onPressed: () => _startLiveExam(title, company),
                icon: const Icon(Icons.psychology, size: 18),
                label: const Text('Take Custom Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pesoGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 25,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Integrates routing to the external exam_page.dart
  void _startLiveExam(String jobTitle, String company) async {
    final score = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AIExamPage(jobTitle: jobTitle, company: company),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutExpo;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

    // When the user finishes or quits the exam, process the returned score
    if (score != null && mounted) {
      _processThresholdRouting(jobTitle, company, score as int);
    }
  }

  void _processThresholdRouting(String job, String company, int score) {
    if (score >= 50) {
      setState(() {
        _assessmentOutcomes.insert(0, {
          'job': job,
          'company': company,
          'status': 'passed',
          'score': score,
          'message': 'Your profile is pre-vetted and has been routed to the Montalban PESO Admin queue.',
        });
        _selectedIndex = 2; // Jump to Outcomes tab
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Awesome! You passed with $score%. Profile routed.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _assessmentOutcomes.insert(0, {
          'job': job,
          'company': company,
          'status': 'action_plan',
          'score': score,
          'failed_skills': ['Identified Logic Gap', 'Specific Tech Knowledge'],
          'alt_jobs': [
            'Alternative Match 1 (Local)',
            'Alternative Match 2 (Local)',
          ],
          'training': 'Recommended TESDA Short Course',
        });
        _selectedIndex = 2;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Score: $score%. AI Action Plan generated.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ==========================================
  // 3. AI OUTCOMES & UPSKILLING PLANS
  // ==========================================
  Widget _buildOutcomesTrackerView(Color pesoGreen) {
    if (_assessmentOutcomes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              'No Assessments Taken Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(40),
      child: ListView.builder(
        itemCount: _assessmentOutcomes.length,
        itemBuilder: (context, index) {
          final outcome = _assessmentOutcomes[index];
          if (outcome['status'] == 'passed') {
            return _buildPassCard(outcome, pesoGreen);
          } else {
            return _buildActionPlanCard(outcome);
          }
        },
      ),
    );
  }

  Widget _buildPassCard(Map<String, dynamic> data, Color pesoGreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 30,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${data['job']} @ ${data['company']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Score: ${data['score']}% - PRE-VETTED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data['message'],
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPlanCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Career Action Plan',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data['job']} @ ${data['company']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: ${data['score']}% - REQUIRES UPSKILLING',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Divider(),
          const SizedBox(height: 25),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identified Skill Gaps',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (data['failed_skills'] as List<String>)
                          .map((skill) => _buildGapChip(skill))
                          .toList(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alternative Local Jobs',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (data['alt_jobs'] as List<String>)
                          .map((job) => _buildAltJobChip(job))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: Colors.blue.shade700, size: 28),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommended TESDA Upskilling',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['training'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View Local Center'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. ACCOUNT SETTINGS (LANGUAGE & PREFS)
  // ==========================================
  Widget _buildSettingsView(Color pesoGreen) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Container(
          width: 850,
          padding: const EdgeInsets.all(40),
          decoration: _designerCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'System Language / Wika ng Sistema',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose the language you are most comfortable with for navigation and instructions.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 25),

              // Custom Segmented Control for Language
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    _buildLanguageTab('English', 'English'),
                    _buildLanguageTab('Tagalog', 'Modern Tagalog'),
                    _buildLanguageTab('Taglish', 'Taglish (Mixed)'),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 40),

              const Text(
                'Notification Preferences',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 25),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Email Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Receive success emails when you pass an AI assessment.',
                ),
                value: _emailNotifications,
                activeColor: pesoGreen,
                onChanged: (val) => setState(() => _emailNotifications = val),
              ),
              const SizedBox(height: 15),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'In-App Alerts',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Get instant platform alerts for TESDA recommendations.',
                ),
                value: _appNotifications,
                activeColor: pesoGreen,
                onChanged: (val) => setState(() => _appNotifications = val),
              ),
              const SizedBox(height: 40),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Settings saved successfully.'),
                      backgroundColor: pesoGreen,
                    ),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Preferences'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pesoGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTab(String languageKey, String label) {
    bool isSelected = _selectedLanguage == languageKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedLanguage = languageKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // --- LOGOUT LOGIC & ANIMATION ---
  void _handleLogout() async {
    setState(() => _isLoggingOut = true);
    await Future.delayed(
      const Duration(milliseconds: 1500),
    ); // Play animation for 1.5s
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    }
  }

  // --- DESIGNER UI UTILS ---

  BoxDecoration _designerCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 20,
          offset: const Offset(0, 5),
        ),
      ],
      border: Border.all(color: Colors.grey.shade100),
    );
  }

  Widget _buildModernTextField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.memory, size: 16, color: Colors.blue.shade400),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAltJobChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    int index,
    Color activeColor, {
    bool isLogout = false,
  }) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive
            ? activeColor.withValues(alpha: 0.15)
            : Colors.transparent,
        leading: Icon(
          icon,
          color: isActive || isLogout ? activeColor : Colors.white54,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive || isLogout ? activeColor : Colors.white54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () {
          if (isLogout) {
            _handleLogout();
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }
}
