import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'landingpage_ui.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex =
      0; // 0: Overview, 1: Ingestion, 2: Pipeline, 3: Analytics
  bool _isLoggingOut = false;

  // --- THEME COLORS (Premium Executive Palette) ---
  final Color _primary = const Color(0xFF2E7D32); // PESO Green
  final Color _secondary = const Color(0xFF4F46E5); // Indigo for AI/Analytics
  final Color _sidebarColor = const Color(0xFF0B1120); // Deep rich slate
  final Color _bgColor = const Color(0xFFF8FAFC); // Very light slate/grey
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textLight = const Color(0xFF64748B);

  // --- MOCK DATABASE STATES ---
  final List<Map<String, dynamic>> _ingestedJobs = [
    {
      'id': 'BATCH-042',
      'title': 'IT Support Specialist',
      'company': 'Montalban LGU',
      'uploaded_at': 'Today, 08:30 AM',
      'vacancies': 5,
      'status': 'Synced',
      'color': Colors.green,
    },
    {
      'id': 'BATCH-042',
      'title': 'Data Encoder',
      'company': 'Prime BPO',
      'uploaded_at': 'Today, 08:30 AM',
      'vacancies': 12,
      'status': 'Synced',
      'color': Colors.green,
    },
    {
      'id': 'BATCH-041',
      'title': 'Customer Service Rep',
      'company': 'OmniCore',
      'uploaded_at': 'Yesterday, 14:15 PM',
      'vacancies': 20,
      'status': 'Processing',
      'color': Colors.orange,
    },
  ];

  final List<Map<String, dynamic>> _preVettedPassers = [
    {
      'applicant': 'Juan Dela Cruz',
      'target_job': 'IT Support Specialist',
      'ai_score': 88,
      'date_vetted': 'Oct 24, 2026',
      'status': 'Ready',
      'color': Colors.blue,
    },
    {
      'applicant': 'Maria Santos',
      'target_job': 'Data Encoder',
      'ai_score': 92,
      'date_vetted': 'Oct 24, 2026',
      'status': 'Ready',
      'color': Colors.blue,
    },
    {
      'applicant': 'Mark Reyes',
      'target_job': 'Customer Service Rep',
      'ai_score': 85,
      'date_vetted': 'Oct 23, 2026',
      'status': 'Exported',
      'color': Colors.green,
    },
    {
      'applicant': 'Lovely Ilaya',
      'target_job': 'UI/UX Designer',
      'ai_score': 96,
      'date_vetted': 'Oct 23, 2026',
      'status': 'Ready',
      'color': Colors.blue,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Row(
            children: [
              _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildFloatingHeader(),
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
              ),
            ],
          ),
          if (_isLoggingOut) _buildLogoutOverlay(),
        ],
      ),
    );
  }

  // ==========================================
  // SIDEBAR & HEADER
  // ==========================================
  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _sidebarColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Text(
                      'JobKonek',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      child: const Text(
                        'SA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PESO IT Dept',
                          style: TextStyle(
                            color: _textLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Divider(color: Colors.white12, thickness: 1),
          ),
          const SizedBox(height: 15),

          _buildSidebarItem(Icons.dashboard_outlined, 'Executive Overview', 0),
          _buildSidebarItem(
            Icons.cloud_upload_outlined,
            'Job Batch Ingestion',
            1,
          ),
          _buildSidebarItem(Icons.people_alt_outlined, 'DOLE SPRS Pipeline', 2),
          _buildSidebarItem(Icons.memory_outlined, 'AI Engine Health', 3),

          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Divider(color: Colors.white12, thickness: 1),
          ),
          _buildSidebarItem(Icons.logout, 'Secure Logout', 99, isLogout: true),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    int index, {
    bool isLogout = false,
  }) {
    bool isActive = _selectedIndex == index;
    Color activeColor = _primary;
    Color iconColor = isLogout
        ? Colors.redAccent
        : (isActive ? activeColor : Colors.white54);
    Color textColor = isLogout
        ? Colors.redAccent
        : (isActive ? Colors.white : Colors.white54);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive
            ? activeColor.withValues(alpha: 0.15)
            : Colors.transparent,
        leading: Icon(icon, color: iconColor, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        onTap: () async {
          if (isLogout) {
            setState(() => _isLoggingOut = true);
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LandingPage()),
              );
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }

  Widget _buildFloatingHeader() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 50),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHeaderSubtitle(),
                  style: TextStyle(
                    fontSize: 14,
                    color: _textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildHeaderActionButton(Icons.search, 'Search...'),
              const SizedBox(width: 15),
              _buildHeaderActionButton(Icons.notifications_none, ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: text.isEmpty ? 12 : 20,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: _textLight, size: 20),
          if (text.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(color: _textLight, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Executive Overview';
      case 1:
        return 'Offline Job Ingestion';
      case 2:
        return 'DOLE SPRS Pipeline';
      case 3:
        return 'AI Engine & Platform Health';
      default:
        return 'Dashboard';
    }
  }

  String _getHeaderSubtitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Real-time platform metrics and statistical analysis.';
      case 1:
        return 'Bulk upload Excel files to populate the matching database.';
      case 2:
        return 'Review pre-vetted candidates and export to official PhilJobNet structures.';
      case 3:
        return 'Monitor live LLM API traffic, latency, and pipeline metrics.';
      default:
        return '';
    }
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return _buildExecutiveOverview();
      case 1:
        return _buildJobIngestionView();
      case 2:
        return _buildPipelineView();
      case 3:
        return _buildAnalyticsView();
      default:
        return const Center(child: Text('View not found'));
    }
  }

  // ==========================================
  // VIEW 0: EXECUTIVE OVERVIEW (NEW)
  // ==========================================
  Widget _buildExecutiveOverview() {
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
                child: Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        'Total Job Seekers',
                        8420,
                        Icons.people,
                        _primary,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildKpiCard(
                        'Pre-Vetted Candidates',
                        1254,
                        Icons.verified_user,
                        _secondary,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildKpiCard(
                        'AI Exams Conducted',
                        3492,
                        Icons.psychology,
                        Colors.orange.shade600,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildKpiCard(
                        'System Uptime',
                        99,
                        Icons.health_and_safety,
                        Colors.teal,
                        isPercentage: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: FadeSlideEntrance(
                      delay: 200,
                      child: _SectionWrapper(
                        title: 'Weekly AI Traffic & Exam Volume',
                        child: SizedBox(
                          height: 300,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildMockBar('Mon', 120),
                              _buildMockBar('Tue', 180),
                              _buildMockBar('Wed', 250, isPeak: true),
                              _buildMockBar('Thu', 210),
                              _buildMockBar('Fri', 190),
                              _buildMockBar('Sat', 90),
                              _buildMockBar('Sun', 60),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 1,
                    child: FadeSlideEntrance(
                      delay: 300,
                      child: _SectionWrapper(
                        title: 'Live Activity Feed',
                        child: Column(
                          children: [
                            _buildActivityRow(
                              'Lovely Ilaya finished an exam.',
                              '2m ago',
                              true,
                            ),
                            _buildActivityRow(
                              'Batch-042 synced successfully.',
                              '15m ago',
                              false,
                            ),
                            _buildActivityRow(
                              'System matched 45 users.',
                              '1h ago',
                              true,
                            ),
                            _buildActivityRow(
                              'John Cesneros registered.',
                              '3h ago',
                              false,
                            ),
                            _buildActivityRow(
                              'API token usage warning (80%).',
                              '4h ago',
                              false,
                              isAlert: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    int targetValue,
    IconData icon,
    Color color, {
    bool isPercentage = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Icon(Icons.trending_up, color: Colors.green.shade400, size: 20),
            ],
          ),
          const SizedBox(height: 25),
          AnimatedCounterText(
            targetValue: targetValue,
            isPercentage: isPercentage,
            textStyle: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: _textDark,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: _textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockBar(String label, double height, {bool isPeak = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedBar(
          height: height,
          color: isPeak ? _secondary : _primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 15),
        Text(
          label,
          style: TextStyle(
            color: _textLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRow(
    String text,
    String time,
    bool isUser, {
    bool isAlert = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isAlert
                ? Colors.red.shade50
                : (isUser
                      ? _secondary.withValues(alpha: 0.1)
                      : _primary.withValues(alpha: 0.1)),
            child: Icon(
              isAlert
                  ? Icons.warning
                  : (isUser ? Icons.person : Icons.settings),
              size: 14,
              color: isAlert ? Colors.red : (isUser ? _secondary : _primary),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 1: JOB INGESTION
  // ==========================================
  Widget _buildJobIngestionView() {
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
                child: _SectionWrapper(
                  title: 'Secure Data Importer',
                  actionWidget: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download .xlsx Schema'),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 60,
                      horizontal: 40,
                    ),
                    decoration: BoxDecoration(
                      color: _secondary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _secondary.withValues(alpha: 0.3),
                        width: 2,
                      ),
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
                                color: _secondary.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.cloud_upload_rounded,
                            size: 48,
                            color: _secondary,
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          'Drop PESO Master Excel File Here',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'System will automatically map columns to the AI Vector Database.',
                          style: TextStyle(color: _textLight, fontSize: 14),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.folder_open),
                          label: const Text(
                            'Browse Files',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 35,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              FadeSlideEntrance(
                delay: 200,
                child: Text(
                  'Recent Pipeline Ingestions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              ...List.generate(_ingestedJobs.length, (index) {
                return FadeSlideEntrance(
                  delay: 300 + (index * 100),
                  child: _buildIngestedJobCard(_ingestedJobs[index]),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngestedJobCard(Map<String, dynamic> job) {
    Color statusColor = job['color'];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work, color: _textLight, size: 24),
              ),
              const SizedBox(width: 25),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job['title'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        job['company'],
                        style: TextStyle(
                          color: _secondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 15),
                      Text(
                        'Batch ID: ${job['id']}',
                        style: TextStyle(color: _textLight, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Vacancies',
                    style: TextStyle(color: _textLight, fontSize: 12),
                  ),
                  Text(
                    '${job['vacancies']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 30),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  job['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 2: DOLE SPRS PIPELINE
  // ==========================================
  Widget _buildPipelineView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.grey),
                  const SizedBox(width: 15),
                  Text(
                    'Showing ${_preVettedPassers.length} Validated Passers',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send),
                label: const Text('Export SPRS to DOLE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(50),
            itemCount: _preVettedPassers.length,
            itemBuilder: (context, index) {
              return FadeSlideEntrance(
                delay: index * 100,
                child: _buildPipelineCard(_preVettedPassers[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineCard(Map<String, dynamic> passer) {
    Color statusColor = passer['color'];
    double score = passer['ai_score'] / 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _secondary.withValues(alpha: 0.1),
                child: Text(
                  passer['applicant'][0],
                  style: TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 25),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    passer['applicant'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${passer['target_job']}',
                    style: TextStyle(
                      color: _textLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Column(
                children: [
                  Text(
                    'Vetting Score',
                    style: TextStyle(
                      color: _textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    width: 40,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: score,
                          backgroundColor: Colors.grey.shade200,
                          color: _primary,
                          strokeWidth: 4,
                        ),
                        Center(
                          child: Text(
                            '${passer['ai_score']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 40),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  passer['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 3: AI PLATFORM HEALTH
  // ==========================================
  Widget _buildAnalyticsView() {
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
                child: _SectionWrapper(
                  title: 'Gemini LLM Processing Core',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: _sidebarColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _secondary.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.memory,
                          size: 50,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Google Gemini API V1.5 Pro',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Status: Healthy',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Token Quota Limit (Monthly)',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '35% Used',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: 0.35,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blueAccent,
                                ),
                                minHeight: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              FadeSlideEntrance(
                delay: 200,
                child: _SectionWrapper(
                  title: 'Live Inference Terminal',
                  child: Container(
                    width: double.infinity,
                    height: 250,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _sidebarColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTerminalLine(
                          '[sys] API Gateway Connected. Latency: 240ms',
                          Colors.greenAccent,
                        ),
                        _buildTerminalLine(
                          '[infer] Generating exam for "IT Support Specialist"...',
                          Colors.white70,
                        ),
                        _buildTerminalLine(
                          '[infer] Success. Prompt Tokens: 452, Completion Tokens: 890',
                          Colors.blueAccent,
                        ),
                        _buildTerminalLine(
                          '[infer] Evaluating answers for UserID: JDelaCruz...',
                          Colors.white70,
                        ),
                        _buildTerminalLine(
                          '[sys] Security Check: PII scrubbed before sending.',
                          Colors.yellow,
                        ),
                        _buildTerminalLine(
                          '[infer] Vetting complete. Score: 88%. Route to SPRS.',
                          Colors.greenAccent,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Text(
                              '>',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 8,
                              height: 16,
                              color: Colors.greenAccent,
                            ), // Blinking cursor mock
                          ],
                        ),
                      ],
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

  Widget _buildTerminalLine(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }

  // ==========================================
  // UTILITIES
  // ==========================================
  Widget _buildLogoutOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: _sidebarColor.withValues(alpha: 0.6),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(50),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _primary, strokeWidth: 4),
                  const SizedBox(height: 30),
                  Text(
                    'Securing session...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Safely logging you out of the Admin Portal.',
                    style: TextStyle(color: _textLight),
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

// =====================================================================
// CUSTOM ANIMATION WIDGETS
// =====================================================================
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
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              actionWidget ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 25),
          const Divider(color: Colors.black12),
          const SizedBox(height: 25),
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

class AnimatedCounterText extends StatefulWidget {
  final int targetValue;
  final TextStyle textStyle;
  final bool isPercentage;

  const AnimatedCounterText({
    super.key,
    required this.targetValue,
    required this.textStyle,
    this.isPercentage = false,
  });

  @override
  State<AnimatedCounterText> createState() => _AnimatedCounterTextState();
}

class _AnimatedCounterTextState extends State<AnimatedCounterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = IntTween(
      begin: 0,
      end: widget.targetValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Formatting with commas
        String formattedNumber = _animation.value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        return Text(
          '${widget.isPercentage ? '' : ''}$formattedNumber${widget.isPercentage ? '%' : ''}',
          style: widget.textStyle,
        );
      },
    );
  }
}

class AnimatedBar extends StatefulWidget {
  final double height;
  final Color color;

  const AnimatedBar({super.key, required this.height, required this.color});

  @override
  State<AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<AnimatedBar> {
  double _currentHeight = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _currentHeight = widget.height);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      width: 40,
      height: _currentHeight,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
