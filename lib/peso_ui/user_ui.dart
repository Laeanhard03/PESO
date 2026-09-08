import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'landingpage_ui.dart';
import 'exampage_ui.dart';
import 'pesoform_ui.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  bool _isPesoRegistrationCompleted = false;

  int _selectedIndex = 0;
  bool _isLoggingOut = false;
  String _selectedLanguage = 'English';
  bool _emailNotifications = true;
  bool _appNotifications = true;

  // --- RICH JOB FEED DATA (WITH IMAGES) ---
  final List<Map<String, dynamic>> _availableJobs = [
    {
      'title': 'Senior Flutter Developer',
      'company': 'TechNova Solutions',
      'location': 'Rodriguez (On-site)',
      'salary': 'PHP 45,000 - 60,000',
      'type': 'Full-time',
      'vacancies': '2',
      'match': 94,
      'logoColor': Colors.blue,
      'image': 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?auto=format&fit=crop&w=600&q=80',
      'description': 'We are looking for an experienced Flutter developer to lead our mobile team. You will be architecting high-performance applications and mentoring junior developers from the Montalban area.',
      'reqs': [
        '3+ years Flutter/Dart experience',
        'State Management (BLoC/Riverpod)',
        'RESTful API integration',
      ],
    },
    {
      'title': 'IT Support Specialist',
      'company': 'Montalban LGU',
      'location': 'San Mateo (Hybrid)',
      'salary': 'PHP 18,000 - 25,000',
      'type': 'Contract',
      'vacancies': '5',
      'match': 88,
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
      'title': 'Data Encoder',
      'company': 'Prime BPO',
      'location': 'QC / Montalban Border',
      'salary': 'PHP 15,000 - 18,000',
      'type': 'Part-time',
      'vacancies': '12',
      'match': 75,
      'logoColor': Colors.purple,
      'image': 'https://images.unsplash.com/photo-1573164713988-8665fc963095?auto=format&fit=crop&w=600&q=80',
      'description': 'Fast-paced data entry role for a growing BPO. Requires high typing speed and attention to detail. Great entry-level opportunity with flexible shifts.',
      'reqs': [
        '60+ WPM Typing Speed',
        'Basic Excel/Spreadsheet knowledge',
        'High attention to detail',
      ],
    },
    {
      'title': 'Creative Graphic Designer',
      'company': 'PixelPerfect',
      'location': 'Montalban (Remote)',
      'salary': 'PHP 25,000 - 35,000',
      'type': 'Full-time',
      'vacancies': '1',
      'match': 65,
      'logoColor': Colors.pink,
      'image': 'https://images.unsplash.com/photo-1561070791-2526d30994b5?auto=format&fit=crop&w=600&q=80',
      'description': 'Seeking a highly creative graphic designer to produce marketing materials, social media posts, and brand identities for local businesses.',
      'reqs': [
        'Adobe Creative Suite',
        'Strong Portfolio',
        'Creative Typography',
      ],
    },
    {
      'title': 'Administrative Assistant',
      'company': 'Rizal Prov. Gov',
      'location': 'Antipolo (On-site)',
      'salary': 'PHP 16,000 - 20,000',
      'type': 'Full-time',
      'vacancies': '8',
      'match': 82,
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

  final List<Map<String, dynamic>> _assessmentOutcomes = [
    {
      'job': 'Data Encoder',
      'company': 'Prime BPO',
      'status': 'passed',
      'score': 85,
      'message': 'Your profile is pre-vetted and has been routed to the Montalban PESO Admin queue.',
    },
  ];

  // --- THEME COLORS ---
  final Color _primary = const Color(0xFF2E7D32);
  final Color _bgColor = const Color(0xFFF4F7F9); // Sleek modern light grey
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textLight = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    if (_availableJobs.isNotEmpty) {
      _selectedJob = _availableJobs[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPesoRegistrationCompleted) {
      return PesoRegistrationWizard(
        onComplete: () => setState(() => _isPesoRegistrationCompleted = true),
      );
    }

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

  // ==========================================
  // TOP NAVIGATION
  // ==========================================
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
              Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Juan Dela Cruz',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Montalban Resident',
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
                        'JD',
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
              const SizedBox(width: 15),
              IconButton(
                icon: const Icon(Icons.logout, size: 22),
                color: Colors.redAccent,
                tooltip: 'Logout',
                onPressed: () async {
                  setState(() => _isLoggingOut = true);
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (mounted)
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LandingPage()),
                    );
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
        return _buildJobDiscoveryDashboard();
      case 1:
        return _buildProfileBuilderView();
      case 2:
        return _buildOutcomesTrackerView();
      case 3:
        return _buildSettingsView();
      default:
        return const Center(child: Text('View not found'));
    }
  }

  // ==========================================
  // DASHBOARD 1: JOB FEED & PREVIEW
  // ==========================================
  Widget _buildJobDiscoveryDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: Text(
                  _translate('Welcome back, Juan!'),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FadeSlideEntrance(
                delay: 100,
                child: Text(
                  _translate(
                    'Discover your top AI-matched opportunities from PESO Montalban.',
                  ),
                  style: TextStyle(fontSize: 18, color: _textLight),
                ),
              ),
              const SizedBox(height: 40),

              // HORIZONTAL IMAGE-RICH JOB CAROUSEL
              FadeSlideEntrance(
                delay: 200,
                child: SizedBox(
                  height: 320,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableJobs.length,
                    itemBuilder: (context, index) {
                      final job = _availableJobs[index];
                      final isSelected = _selectedJob == job;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedJob = job),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 300,
                          margin: const EdgeInsets.only(
                            right: 25,
                            bottom: 20,
                            top: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? _primary : Colors.transparent,
                              width: isSelected ? 3 : 0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? _primary.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: isSelected ? 20 : 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cover Image Area using CachedNetworkImage
                                Expanded(
                                  flex: 5,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: job['image'],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.error),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(
                                                alpha: 0.8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 15,
                                        right: 15,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 10,
                                              sigmaY: 10,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.auto_awesome,
                                                    color: Colors.amberAccent,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '${job['match']}% Match',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Text Content Area
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          job['title'],
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _textDark,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.business,
                                              size: 14,
                                              color: _textLight,
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                job['company'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _textLight,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // DETAILED PREVIEW
              if (_selectedJob != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey(_selectedJob!['title']),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Header using CachedNetworkImageProvider
                        Container(
                          height: 240,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(
                                _selectedJob!['image'],
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.business,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Text(
                                        _selectedJob!['company'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
                                          letterSpacing: 1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _selectedJob!['title'],
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Body Content
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildInfoBadge(
                                        Icons.location_on,
                                        _selectedJob!['location'],
                                      ),
                                      const SizedBox(width: 15),
                                      _buildInfoBadge(
                                        Icons.work,
                                        _selectedJob!['type'],
                                      ),
                                      const SizedBox(width: 15),
                                      _buildInfoBadge(
                                        Icons.people,
                                        '${_selectedJob!['vacancies']} Slots',
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _selectedJob!['salary'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: _primary,
                                      fontSize: 26,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 35),
                              Text(
                                'Role Description',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _textDark,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                _selectedJob!['description'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  height: 1.8,
                                ),
                              ),
                              const SizedBox(height: 35),
                              Text(
                                'AI Extracted Requirements',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _textDark,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children:
                                    (_selectedJob!['reqs'] as List<String>)
                                        .map((req) => _buildReqChip(req))
                                        .toList(),
                              ),
                              const SizedBox(height: 50),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_primary, Colors.green.shade800],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primary.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startLiveExam(
                                      _selectedJob!['title'],
                                      _selectedJob!['company'],
                                    ),
                                    icon: const Icon(
                                      Icons.auto_awesome,
                                      size: 24,
                                    ),
                                    label: const Text(
                                      'Start AI Assessment',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 24,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _textLight),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReqChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DASHBOARD 2: PROFILE BUILDER
  // ==========================================
  Widget _buildProfileBuilderView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: Text(
                  _translate('AI Profile Builder'),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FadeSlideEntrance(
                delay: 100,
                child: Text(
                  _translate(
                    'Configure your digital identity to improve match accuracy.',
                  ),
                  style: TextStyle(fontSize: 18, color: _textLight),
                ),
              ),
              const SizedBox(height: 40),

              FadeSlideEntrance(
                delay: 200,
                child: _SectionWrapper(
                  title: 'AI Readiness & Resume',
                  actionWidget: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: _primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '85% Match Ready',
                          style: TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(50),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.blue.shade100, width: 2),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.cloud_upload_rounded,
                            size: 48,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          'Upload your latest PDF resume',
                          style: TextStyle(
                            color: _textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Our AI will automatically extract and update your skills.',
                          style: TextStyle(color: _textLight, fontSize: 15),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.folder_open),
                          label: const Text(
                            'Browse Files',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              FadeSlideEntrance(
                delay: 300,
                child: _SectionWrapper(
                  title: 'Extracted Profile Context',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDesignerTextField(
                              'Full Name',
                              'Juan Dela Cruz',
                            ),
                          ),
                          const SizedBox(width: 30),
                          Expanded(
                            child: _buildDesignerTextField(
                              'Professional Title',
                              'Junior Software Developer',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Bilingual Bio (Tagalog/English)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Ikwento ang iyong mga karanasan...',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.all(25),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: _primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'AI Extracted Skills',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSkillChip('Flutter Development'),
                          _buildSkillChip('Customer Service'),
                          _buildSkillChip('Database Management'),
                          _buildSkillChip('Dart Programming'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              FadeSlideEntrance(
                delay: 400,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Profile saved successfully.'),
                        backgroundColor: _primary,
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 22),
                    label: const Text(
                      'Save Profile Updates',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
  // DASHBOARD 3: OUTCOMES TRACKER
  // ==========================================
  Widget _buildOutcomesTrackerView() {
    if (_assessmentOutcomes.isEmpty) {
      return Center(
        child: FadeSlideEntrance(
          delay: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'No Assessments Taken Yet',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Complete an AI exam from the Job Feed to generate plans.',
                style: TextStyle(color: _textLight, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: Text(
                  _translate('Outcomes & Action Plans'),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FadeSlideEntrance(
                delay: 100,
                child: Text(
                  _translate(
                    'Review pre-vetted statuses or recommended TESDA courses.',
                  ),
                  style: TextStyle(fontSize: 18, color: _textLight),
                ),
              ),
              const SizedBox(height: 40),
              ...List.generate(_assessmentOutcomes.length, (index) {
                final outcome = _assessmentOutcomes[index];
                return FadeSlideEntrance(
                  delay: 200 + (index * 100),
                  child: outcome['status'] == 'passed'
                      ? _buildPassCard(outcome)
                      : _buildActionPlanCard(outcome),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.green.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['job'],
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: _textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          data['company'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        'Score: ${data['score']}% - PRE-VETTED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  data['message'],
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
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
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border(
          top: BorderSide(color: Colors.orange.shade400, width: 6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
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
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.orange,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 25),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Career Action Plan',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${data['job']} @ ${data['company']}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: ${data['score']}% - UPSKILLING REQUIRED',
                  style: TextStyle(
                    color: _textLight,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(color: Colors.black12),
          const SizedBox(height: 40),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: (data['failed_skills'] as List<String>)
                          .map((skill) => _buildGapChip(skill))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alternative Local Jobs',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: (data['alt_jobs'] as List<String>)
                          .map((job) => _buildAltJobChip(job))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.school,
                        color: Colors.blue.shade700,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 25),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommended TESDA Course',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          data['training'],
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: _textDark,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'View Local Center',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DASHBOARD 4: SETTINGS
  // ==========================================
  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: Text(
                  _translate('Account Settings'),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FadeSlideEntrance(
                delay: 100,
                child: Text(
                  _translate(
                    'Manage your language preferences and system notifications.',
                  ),
                  style: TextStyle(fontSize: 18, color: _textLight),
                ),
              ),
              const SizedBox(height: 40),

              FadeSlideEntrance(
                delay: 200,
                child: _SectionWrapper(
                  title: 'System Language / Wika ng Sistema',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose the language you are most comfortable with.',
                        style: TextStyle(color: _textLight, fontSize: 16),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            _buildLanguageTab('English', 'English'),
                            _buildLanguageTab('Tagalog', 'Modern Tagalog'),
                            _buildLanguageTab('Taglish', 'Taglish (Mixed)'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FadeSlideEntrance(
                delay: 300,
                child: _SectionWrapper(
                  title: 'Notification Preferences',
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          title: Text(
                            'Email Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Receive success emails when you pass an AI assessment.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          value: _emailNotifications,
                          activeColor: _primary,
                          onChanged: (val) =>
                              setState(() => _emailNotifications = val),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          title: Text(
                            'In-App Alerts',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Get instant platform alerts for TESDA recommendations.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          value: _appNotifications,
                          activeColor: _primary,
                          onChanged: (val) =>
                              setState(() => _appNotifications = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FadeSlideEntrance(
                delay: 400,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Settings saved successfully.'),
                        backgroundColor: _primary,
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 22),
                    label: const Text(
                      'Save Preferences',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
  // LOGIC & UTILITIES
  // ==========================================
  void _startLiveExam(String jobTitle, String company) async {
    final score = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AIExamPage(jobTitle: jobTitle, company: company),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutExpo)),
            ),
            child: child,
          );
        },
      ),
    );
    if (score != null && mounted) {
      if (score >= 50) {
        setState(() {
          _assessmentOutcomes.insert(0, {
            'job': jobTitle,
            'company': company,
            'status': 'passed',
            'score': score,
            'message': 'Your profile is pre-vetted and has been routed to the Montalban PESO Admin queue.',
          });
          _selectedIndex = 2;
        });
      } else {
        setState(() {
          _assessmentOutcomes.insert(0, {
            'job': jobTitle,
            'company': company,
            'status': 'action_plan',
            'score': score,
            'failed_skills': [
              'Identified Logic Gap',
              'Specific Tech Knowledge',
            ],
            'alt_jobs': ['Alternative Match 1', 'Alternative Match 2'],
            'training': 'Recommended TESDA Short Course',
          });
          _selectedIndex = 2;
        });
      }
    }
  }

  String _translate(String text) {
    if (_selectedLanguage == 'English') return text;
    final Map<String, Map<String, String>> dictionary = {
      'AI Profile Builder': {
        'Tagalog': 'Tagabuo ng AI Profile',
        'Taglish': 'Set up your AI Profile',
      },
      'Job Feed': {'Tagalog': 'Lokal na Trabaho', 'Taglish': 'Job Feed'},
      'Welcome back, Juan!': {
        'Tagalog': 'Maligayang pagbabalik, Juan!',
        'Taglish': 'Welcome back, Juan!',
      },
      'Discover your top AI-matched opportunities from PESO Montalban.': {
        'Tagalog': 'Ito ang iyong mga nangungunang AI-matched na trabaho mula sa PESO Montalban.',
        'Taglish': 'Here are your top AI-matched roles from PESO Montalban.',
      },
      'Outcomes & Action Plans': {
        'Tagalog': 'Mga Resulta at Plano',
        'Taglish': 'Exam Results & Plans',
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

  // ==========================================
  // DESIGNER COMPONENT UTILS
  // ==========================================
  Widget _buildLanguageTab(String languageKey, String label) {
    bool isSelected = _selectedLanguage == languageKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedLanguage = languageKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? _primary : _textLight,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesignerTextField(String label, String hint, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.grey.shade400, size: 22)
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 25,
              vertical: 22,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.memory, size: 18, color: Colors.blue.shade500),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildAltJobChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
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

class _SectionWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? actionWidget;

  const _SectionWrapper({
    required this.title,
    required this.child,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              actionWidget ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 30),
          const Divider(color: Colors.black12),
          const SizedBox(height: 30),
          child,
        ],
      ),
    );
  }
}

class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final int delay;

  const FadeSlideEntrance({
    super.key,
    required this.child,
    required this.delay,
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
