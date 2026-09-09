import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'landingpage_ui.dart';

// =====================================================================
// THEME (matched to the React design: slate-950 sidebar, blue-600 accent,
// emerald/rose/amber status colors)
// =====================================================================
class _C {
  static const sidebar = Color(0xFF020617); // slate-950
  static const primary = Color(0xFF2563EB); // blue-600
  static const primaryDark = Color(0xFF1D4ED8); // blue-700
  static const indigo = Color(0xFF4F46E5);
  static const emerald = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const rose = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const amber = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const purple = Color(0xFF9333EA);
  static const bg = Color(0xFFF1F5F9); // slate-100
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF0F172A);
}

// =====================================================================
// STATUS STYLES
// =====================================================================
class StatusStyle {
  final String label;
  final Color text;
  final Color bg;
  final Color dot;
  const StatusStyle(this.label, this.text, this.bg, this.dot);
}

// Job-matching status (replaces the old AI-exam / assessment status).
const Map<String, StatusStyle> kMatchStyles = {
  'matched': StatusStyle('Matched to a Job', Color(0xFF047857),
      Color(0xFFECFDF5), Color(0xFF10B981)),
  'not_matched': StatusStyle('No Match Yet', Color(0xFFBE123C),
      Color(0xFFFFF1F2), Color(0xFFF43F5E)),
  'pending': StatusStyle('Resume Under Review', Color(0xFFB45309),
      Color(0xFFFFFBEB), Color(0xFFF59E0B)),
};

const Map<String, StatusStyle> kUserStatusStyles = {
  'active': StatusStyle(
      'Active', Color(0xFF047857), Color(0xFFECFDF5), Color(0xFF10B981)),
  'inactive': StatusStyle(
      'Inactive', Color(0xFF64748B), Color(0xFFF1F5F9), Color(0xFF94A3B8)),
};

// =====================================================================
// MODELS
// =====================================================================
class Applicant {
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

class JobSeekerUser {
  final int id;
  final String name;
  final String email;
  final String barangay;
  final DateTime registeredDate;
  String lastLogin;
  String status; // active | inactive

  JobSeekerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.barangay,
    required this.registeredDate,
    required this.lastLogin,
    required this.status,
  });
}

class IngestionLog {
  final int id;
  final String job;
  final String employer;
  final String batch;
  final String uploaded;
  final String status;
  final int matchedAccounts;

  IngestionLog({
    required this.id,
    required this.job,
    required this.employer,
    required this.batch,
    required this.uploaded,
    required this.status,
    this.matchedAccounts = 0,
  });
}

class AuditEntry {
  final int id;
  final String actor;
  final String action; // deactivated | activated | deleted
  final String detail;
  final String timestamp;

  AuditEntry({
    required this.id,
    required this.actor,
    required this.action,
    required this.detail,
    required this.timestamp,
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

// =====================================================================
// MOCK DATA GENERATION
// =====================================================================
const List<String> kBarangays = [
  'Balite', 'Burgos', 'Geronimo', 'Macabud', 'Manggahan', 'Mascap',
  'Montalban (Poblacion)', 'Puray', 'Rosario', 'San Isidro', 'San Jose',
  'San Rafael', 'Santa Ana', 'Santo Nino', 'Wawa',
];
const List<String> kJobs = [
  'IT Support Specialist',
  'Data Encoder',
  'Senior Flutter Developer',
  'Warehouse Assistant',
  'Bookkeeper',
];
const List<String> kFirstNames = [
  'Juan', 'Maria', 'Jose', 'Ana', 'Pedro', 'Liza', 'Mark', 'Rosa', 'Carlo',
  'Ella', 'Ramon', 'Kim',
];
const List<String> kLastNames = [
  'Dela Cruz', 'Santos', 'Reyes', 'Bautista', 'Garcia', 'Torres', 'Flores',
  'Ramos',
];

const List<String> kConcernTemplates = [
  'Wala pa pong available na trabaho na tugma sa aking taon ng karanasan. Sana po ay may maidagdag pang listahan.',
  'Pumasa naman po ako sa aking hinati-hating kasanayan pero wala pa rin pong na-match na employer. Paki-check po.',
  'Baka po masyadong mataas ang required years of experience sa job na ito \u2014 puwede po bang i-relax nang kaunti?',
  'Nag-upload na po ako ng resume at form kaso wala pa rin pong update ilang araw na. Sana po ma-prioritize.',
  'Interesado po ako sa trabaho pero malayo sa aking barangay \u2014 meron po bang mas malapit na opsyon?',
  'Sana po ay may paraan para malaman kung ano pa ang kulang sa aking qualifications para mag-match.',
];

class _SeededRandom {
  int _seed;
  _SeededRandom(this._seed);
  double next() {
    _seed = (_seed * 9301 + 49297) % 233280;
    return _seed / 233280;
  }
}

T _pick<T>(List<T> list, _SeededRandom rand) =>
    list[(rand.next() * list.length).floor().clamp(0, list.length - 1)];

List<Applicant> _generateApplicants({int days = 14}) {
  final rand = _SeededRandom(42);
  final today = DateTime(2026, 9, 8);
  final rows = <Applicant>[];
  var id = 1;
  for (var d = days - 1; d >= 0; d--) {
    final date = today.subtract(Duration(days: d));
    final registrationsToday = 4 + (rand.next() * 9).floor();
    for (var i = 0; i < registrationsToday; i++) {
      final resumeSubmitted = rand.next() > 0.18;
      final formSubmitted = resumeSubmitted && rand.next() > 0.1;
      final years = (rand.next() * 9).floor();
      String matchStatus;
      var matchedJobsCount = 0;
      if (!resumeSubmitted || !formSubmitted) {
        matchStatus = 'pending';
      } else {
        final isMatched = rand.next() > 0.35;
        if (isMatched) {
          matchStatus = 'matched';
          matchedJobsCount = 1 + (rand.next() * 4).floor();
        } else {
          matchStatus = 'not_matched';
          matchedJobsCount = 0;
        }
      }
      final name = '${_pick(kFirstNames, rand)} ${_pick(kLastNames, rand)}';
      rows.add(Applicant(
        id: id++,
        name: name,
        barangay: _pick(kBarangays, rand),
        targetJob: _pick(kJobs, rand),
        registeredDate: date,
        yearsExperience: years,
        resumeSubmitted: resumeSubmitted,
        formSubmitted: formSubmitted,
        matchStatus: matchStatus,
        matchedJobsCount: matchedJobsCount,
        resumeFileName:
            '${name.toLowerCase().replaceAll(' ', '_')}_resume.pdf',
      ));
    }
  }
  return rows;
}

List<JobSeekerUser> _generateJobSeekerUsers(List<Applicant> applicants) {
  final rand = _SeededRandom(7);
  final seen = <String>{};
  final users = <JobSeekerUser>[];
  var i = 0;
  final today = DateTime(2026, 9, 8);
  for (final a in applicants) {
    if (seen.contains(a.name)) continue;
    seen.add(a.name);
    i += 1;
    final isActive = rand.next() > 0.28;
    final lastLoginDaysAgo =
        isActive ? (rand.next() * 3).floor() : 4 + (rand.next() * 20).floor();
    final lastLoginDate = today.subtract(Duration(days: lastLoginDaysAgo));
    users.add(JobSeekerUser(
      id: i,
      name: a.name,
      email: '${a.name.toLowerCase().replaceAll(' ', '.')}$i@gmail.com',
      barangay: a.barangay,
      registeredDate: a.registeredDate,
      lastLogin: lastLoginDaysAgo == 0 ? 'Today' : _fmtDate(lastLoginDate),
      status: isActive ? 'active' : 'inactive',
    ));
  }
  return users;
}

List<Concern> _generateConcerns(List<Applicant> applicants) {
  final rand = _SeededRandom(19);
  final notMatched = applicants.where((a) => a.matchStatus == 'not_matched').toList();
  final concerns = <Concern>[];
  var id = 1;
  final today = DateTime(2026, 9, 8);
  for (final a in notMatched) {
    if (rand.next() > 0.45) continue; // not everyone leaves a concern
    final daysAgo = (rand.next() * 5).floor();
    concerns.add(Concern(
      id: id++,
      applicantName: a.name,
      barangay: a.barangay,
      targetJob: a.targetJob,
      message: _pick(kConcernTemplates, rand),
      submittedDate: today.subtract(Duration(days: daysAgo)),
      resolved: rand.next() > 0.7,
    ));
  }
  concerns.sort((a, b) => b.submittedDate.compareTo(a.submittedDate));
  return concerns;
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtDateTime(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
    'Nov', 'Dec',
  ];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  final min = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, ${d.year}, $h:$min $ampm';
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// =====================================================================
// NAVIGATION
// =====================================================================
enum AdminTab { analytics, users, concerns, ingestion, export, platform }

class _NavItem {
  final AdminTab tab;
  final String label;
  final IconData icon;
  final String title;
  final String description;
  const _NavItem(
      this.tab, this.label, this.icon, this.title, this.description);
}

const List<_NavItem> kNavItems = [
  _NavItem(
    AdminTab.analytics,
    'Applicant Analytics',
    Icons.insights_outlined,
    'Applicant Analytics',
    'Job seeker registrations and resume-based job matching outcomes across Montalban barangays.',
  ),
  _NavItem(
    AdminTab.users,
    'User Management',
    Icons.manage_accounts_outlined,
    'Job Seeker Accounts',
    "See who has logged in, mark accounts active or inactive, and remove accounts.",
  ),
  _NavItem(
    AdminTab.concerns,
    'Concerns & Feedback',
    Icons.forum_outlined,
    'Concerns & Feedback',
    'Messages from job seekers who were not matched to a job, and other concerns they raised.',
  ),
  _NavItem(
    AdminTab.ingestion,
    'Job Batch Ingestion',
    Icons.cloud_upload_outlined,
    'Job Batch Ingestion',
    'Batch upload Excel files from PESO Admins \u2014 new jobs are auto-matched to qualified job seeker accounts.',
  ),
  _NavItem(
    AdminTab.export,
    'DOLE SPRS Export',
    Icons.download_outlined,
    'Matched Candidates Pipeline',
    'Extract matched candidates and export data strictly into DOLE SPRS-compliant formats.',
  ),
  _NavItem(
    AdminTab.platform,
    'Platform Analytics',
    Icons.bar_chart_outlined,
    'AI Matching Engine & System Health',
    'Monitor resume processing, auto-matching, and system uptime.',
  ),
];

// =====================================================================
// TOAST HELPER
// =====================================================================
void showToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle,
  Color iconColor = _C.emerald,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _C.slate900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(20),
      duration: const Duration(seconds: 3),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

// =====================================================================
// ANIMATION HELPERS
// =====================================================================

/// Fades + slides a child upward into place. Give each item in a list an
/// increasing [delayMs] to get a staggered "cascade" entrance.
class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Duration duration;
  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 480),
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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

/// Animates an integer value counting up from 0 to [value], with comma
/// formatting and an optional prefix/suffix (e.g. '%').
class AnimatedCounterText extends StatefulWidget {
  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;
  const AnimatedCounterText({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedCounterText> createState() => _AnimatedCounterTextState();
}

class _AnimatedCounterTextState extends State<AnimatedCounterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _animation = IntTween(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = IntTween(begin: oldWidget.value, end: widget.value)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
      _controller.forward(from: 0);
    }
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
        final formatted = _animation.value.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
        return Text('${widget.prefix}$formatted${widget.suffix}', style: widget.style);
      },
    );
  }
}

// =====================================================================
// ROOT WIDGET
// =====================================================================
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminTab _activeTab = AdminTab.analytics;
  bool _isLoggingOut = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Applicant> _applicants = _generateApplicants();
  late final List<JobSeekerUser> _users = _generateJobSeekerUsers(_applicants);
  late final List<Concern> _concerns = _generateConcerns(_applicants);

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LandingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItem = kNavItems.firstWhere((n) => n.tab == _activeTab);
    final unresolvedConcerns = _concerns.where((c) => !c.resolved).length;
    final badgeCounts = <AdminTab, int>{
      if (unresolvedConcerns > 0) AdminTab.concerns: unresolvedConcerns,
    };
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 980;
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: _C.bg,
        drawer: isWide
            ? null
            : Drawer(
                backgroundColor: _C.sidebar,
                child: _Sidebar(
                  activeTab: _activeTab,
                  badgeCounts: badgeCounts,
                  onSelect: (t) {
                    setState(() => _activeTab = t);
                    Navigator.pop(context);
                  },
                  onLogout: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ),
        body: Stack(
          children: [
            Row(
              children: [
                if (isWide)
                  SizedBox(
                    width: 300,
                    child: _Sidebar(
                      activeTab: _activeTab,
                      badgeCounts: badgeCounts,
                      onSelect: (t) => setState(() => _activeTab = t),
                      onLogout: _logout,
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        title: navItem.title,
                        subtitle: navItem.description,
                        onMenuTap: isWide
                            ? null
                            : () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.03),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Padding(
                            key: ValueKey(_activeTab),
                            padding: const EdgeInsets.all(24),
                            child: _buildActiveSection(),
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
    });
  }

  Widget _buildActiveSection() {
    switch (_activeTab) {
      case AdminTab.analytics:
        return ApplicantAnalyticsSection(applicants: _applicants);
      case AdminTab.users:
        return UserManagementSection(initialUsers: _users);
      case AdminTab.concerns:
        return ConcernsSection(initialConcerns: _concerns);
      case AdminTab.ingestion:
        return const JobBatchIngestionSection();
      case AdminTab.export:
        return DoleSprsExportSection(applicants: _applicants);
      case AdminTab.platform:
        return PlatformAnalyticsSection(applicants: _applicants);
    }
  }

  Widget _buildLogoutOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: _C.sidebar.withValues(alpha: 0.6),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _C.primary, strokeWidth: 4),
                    const SizedBox(height: 24),
                    const Text(
                      'Securing session...',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.slate900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Safely logging you out of the Admin Portal.',
                      style: TextStyle(color: _C.slate500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// SIDEBAR
// =====================================================================
class _Sidebar extends StatelessWidget {
  final AdminTab activeTab;
  final ValueChanged<AdminTab> onSelect;
  final VoidCallback onLogout;
  final Map<AdminTab, int> badgeCounts;
  const _Sidebar({
    required this.activeTab,
    required this.onSelect,
    required this.onLogout,
    this.badgeCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.sidebar,
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _C.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: _C.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('System Admin',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      SizedBox(height: 2),
                      Text('IT & Data Operations',
                          style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: List.generate(kNavItems.length, (index) {
                  final item = kNavItems[index];
                  final isActive = item.tab == activeTab;
                  final badge = badgeCounts[item.tab] ?? 0;
                  return FadeSlideEntrance(
                    delayMs: index * 60,
                    duration: const Duration(milliseconds: 380),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isActive
                            ? const Color(0xFF0F172A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelect(item.tab),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 3,
                                  height: isActive ? 20 : 0,
                                  decoration: BoxDecoration(
                                      color: _C.primary,
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                                SizedBox(width: isActive ? 10 : 13),
                                AnimatedScale(
                                  scale: isActive ? 1.1 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(item.icon,
                                      size: 18,
                                      color: isActive
                                          ? const Color(0xFF60A5FA)
                                          : Colors.white54),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      color: isActive
                                          ? const Color(0xFF60A5FA)
                                          : Colors.white54,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                    child: Text(item.label),
                                  ),
                                ),
                                if (badge > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: _C.rose,
                                        borderRadius: BorderRadius.circular(20)),
                                    child: Text('$badge',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onLogout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Color(0xFFFB7185)),
                      SizedBox(width: 12),
                      Text('Secure Logout',
                          style: TextStyle(
                              color: Color(0xFFFB7185),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// TOP BAR
// =====================================================================
class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onMenuTap;
  const _TopBar({required this.title, required this.subtitle, this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _C.slate200)),
      ),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu),
                color: _C.slate600),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.25), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(title),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _C.slate900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: _C.slate500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _iconBtn(Icons.settings_outlined, _C.slate600, _C.slate100),
          const SizedBox(width: 10),
          _iconBtn(Icons.person_outline, _C.primary, const Color(0xFFDBEAFE)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, Color bg) {
    return _PulseTapIcon(icon: icon, color: color, bg: bg);
  }
}

class _PulseTapIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  const _PulseTapIcon({required this.icon, required this.color, required this.bg});

  @override
  State<_PulseTapIcon> createState() => _PulseTapIconState();
}

class _PulseTapIconState extends State<_PulseTapIcon> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.88),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: widget.bg, shape: BoxShape.circle),
          child: Icon(widget.icon, size: 18, color: widget.color),
        ),
      ),
    );
  }
}

// =====================================================================
// SHARED WIDGETS
// =====================================================================
class _SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget child;
  const _SectionCard(
      {this.title, this.icon, this.iconColor, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.slate200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null)
                      Icon(icon, size: 20, color: iconColor ?? _C.primary),
                    if (icon != null) const SizedBox(width: 8),
                    Text(title!,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _C.slate900)),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
          if (title != null) const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final String label;
  final int numericValue;
  final String suffix;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;
  const _KpiCard({
    required this.label,
    required this.numericValue,
    this.suffix = '',
    required this.icon,
    required this.color,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _hover ? widget.color.withValues(alpha: 0.35) : _C.slate200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.03),
                blurRadius: _hover ? 22 : 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 14, color: _C.slate500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _C.slate500)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedCounterText(
              value: widget.numericValue,
              suffix: widget.suffix,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: widget.color),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 3),
              Text(widget.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: widget.subtitleColor ?? _C.slate400,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StatusStyle style;
  const _StatusBadge(this.style);
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: style.bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: style.dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(style.label,
                style: TextStyle(
                    color: style.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// DONUT CHART — animated arc growth
// =====================================================================
class DonutChart extends StatefulWidget {
  final List<MapEntry<String, double>> segments;
  final Map<String, Color> colors;
  const DonutChart({super.key, required this.segments, required this.colors});

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _progress =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) => CustomPaint(
        painter: _DonutPainter(widget.segments, widget.colors, _progress.value),
        size: Size.infinite,
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> segments;
  final Map<String, Color> colors;
  final double progress;
  _DonutPainter(this.segments, this.colors, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (sum, e) => sum + e.value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 26.0;
    var startAngle = -math.pi / 2;
    for (final seg in segments) {
      final fullSweep = (seg.value / total) * 2 * math.pi;
      final sweep = fullSweep * progress;
      final gap = fullSweep > 0.04 ? 0.03 : 0.0;
      final paint = Paint()
        ..color = colors[seg.key] ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        (sweep - gap).clamp(0, 2 * math.pi),
        false,
        paint,
      );
      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =====================================================================
// INTERACTIVE TREND CHART — hover/tap a day to see its numbers
// (This is what answers "pag inano ko yong mouse nandon yong day at
// ilan ang nag-match" — hover or tap a point on the line to see that
// day's registrations vs matches.)
// =====================================================================
class TrendSeries {
  final String label;
  final Color color;
  final List<double> values;
  const TrendSeries(this.label, this.color, this.values);
}

class InteractiveTrendChart extends StatefulWidget {
  final List<DateTime> dates;
  final List<TrendSeries> series;
  const InteractiveTrendChart({super.key, required this.dates, required this.series});

  @override
  State<InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<InteractiveTrendChart> {
  int? _hoverIndex;

  void _updateHover(Offset localPos, double width) {
    if (widget.dates.length < 2) return;
    final stepX = width / (widget.dates.length - 1);
    final idx = (localPos.dx / stepX).round().clamp(0, widget.dates.length - 1);
    if (idx != _hoverIndex) setState(() => _hoverIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: widget.series
                .map((s) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 9,
                            height: 9,
                            decoration:
                                BoxDecoration(color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(s.label,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _C.slate600)),
                      ],
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          MouseRegion(
            onHover: (e) => _updateHover(e.localPosition, width),
            onExit: (_) => setState(() => _hoverIndex = null),
            child: GestureDetector(
              onPanUpdate: (d) => _updateHover(d.localPosition, width),
              onPanDown: (d) => _updateHover(d.localPosition, width),
              onTapDown: (d) => _updateHover(d.localPosition, width),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MultiLinePainter(widget.dates, widget.series, _hoverIndex),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _hoverIndex != null
              ? _buildTooltipRow(widget.dates[_hoverIndex!], _hoverIndex!)
              : const Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: _C.slate400),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'I-hover o i-tap ang graph para makita ang detalye ng araw na iyon.',
                          style: TextStyle(fontSize: 11, color: _C.slate400)),
                    ),
                  ],
                ),
        ],
      );
    });
  }

  Widget _buildTooltipRow(DateTime date, int idx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _C.slate100, borderRadius: BorderRadius.circular(14)),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 8,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today, size: 12, color: _C.slate500),
            const SizedBox(width: 6),
            Text(_fmtDate(date),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12, color: _C.slate900)),
          ]),
          for (final s in widget.series)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${s.label}: ${s.values[idx].toInt()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12, color: _C.slate700)),
            ]),
        ],
      ),
    );
  }
}

class _MultiLinePainter extends CustomPainter {
  final List<DateTime> dates;
  final List<TrendSeries> series;
  final int? hoverIndex;
  _MultiLinePainter(this.dates, this.series, this.hoverIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty) return;
    final maxV = series
        .expand((s) => s.values)
        .fold<double>(0, (p, e) => math.max(p, e));
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    final stepX = dates.length > 1 ? size.width / (dates.length - 1) : size.width;

    final gridPaint = Paint()
      ..color = _C.slate200
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final s in series) {
      final path = Path();
      for (var i = 0; i < s.values.length; i++) {
        final x = i * stepX;
        final y = size.height - (s.values[i] / safeMax) * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);

      for (var i = 0; i < s.values.length; i++) {
        final x = i * stepX;
        final y = size.height - (s.values[i] / safeMax) * size.height;
        final isHover = hoverIndex == i;
        canvas.drawCircle(Offset(x, y), isHover ? 4.5 : 2.5, Paint()..color = s.color);
        if (isHover) {
          canvas.drawCircle(
              Offset(x, y), 8, Paint()..color = s.color.withValues(alpha: 0.20));
        }
      }
    }

    if (hoverIndex != null) {
      final x = hoverIndex! * stepX;
      final linePaint = Paint()
        ..color = _C.slate400
        ..strokeWidth = 1;
      const dashHeight = 4.0, dashGap = 4.0;
      var startY = 0.0;
      while (startY < size.height) {
        canvas.drawLine(Offset(x, startY),
            Offset(x, math.min(startY + dashHeight, size.height)), linePaint);
        startY += dashHeight + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLinePainter oldDelegate) =>
      oldDelegate.hoverIndex != hoverIndex ||
      oldDelegate.series != series ||
      oldDelegate.dates != dates;
}

// =====================================================================
// MINI TREND CARD — a single-metric card with a colored dot + label,
// a big animated number, and a smooth gradient-filled sparkline below
// it. Hovering/tapping the sparkline shows a small floating tooltip
// with that day's date and value (mirrors the reference design where
// "Registered", "Passed"/"Matched" and "Did not pass"/"No match" are
// each shown as their own standalone card).
// =====================================================================
class _TrendMiniCard extends StatefulWidget {
  final String label;
  final Color color;
  final int value;
  final List<DateTime> dates;
  final List<double> values;
  const _TrendMiniCard({
    required this.label,
    required this.color,
    required this.value,
    required this.dates,
    required this.values,
  });

  @override
  State<_TrendMiniCard> createState() => _TrendMiniCardState();
}

class _TrendMiniCardState extends State<_TrendMiniCard> {
  int? _hoverIndex;

  void _updateHover(Offset localPos, double width) {
    if (widget.dates.length < 2) return;
    final stepX = width / (widget.dates.length - 1);
    final idx = (localPos.dx / stepX).round().clamp(0, widget.dates.length - 1);
    if (idx != _hoverIndex) setState(() => _hoverIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.slate200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _C.slate600)),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedCounterText(
            value: widget.value,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: widget.color),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: LayoutBuilder(builder: (context, c) {
              return MouseRegion(
                onHover: (e) => _updateHover(e.localPosition, c.maxWidth),
                onExit: (_) => setState(() => _hoverIndex = null),
                child: GestureDetector(
                  onPanUpdate: (d) => _updateHover(d.localPosition, c.maxWidth),
                  onPanDown: (d) => _updateHover(d.localPosition, c.maxWidth),
                  onTapDown: (d) => _updateHover(d.localPosition, c.maxWidth),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: CustomPaint(
                          painter: _AreaSparklinePainter(widget.values, widget.color, _hoverIndex),
                        ),
                      ),
                      if (_hoverIndex != null) _buildTooltip(c.maxWidth),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _C.slate200),
          const SizedBox(height: 8),
          const Text('Last 14 days',
              style: TextStyle(fontSize: 11.5, color: _C.slate400, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTooltip(double width) {
    final idx = _hoverIndex!;
    final stepX = widget.dates.length > 1 ? width / (widget.dates.length - 1) : width;
    final x = idx * stepX;
    final alignRight = x > width / 2;
    return Positioned(
      top: 0,
      left: alignRight ? null : (x - 10).clamp(0.0, math.max(0.0, width - 20)),
      right: alignRight ? (width - x - 10).clamp(0.0, math.max(0.0, width - 20)) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.slate200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_fmtShortDate(widget.dates[idx]),
                style: const TextStyle(
                    fontSize: 10.5, color: _C.slate500, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${widget.label} : ${widget.values[idx].toInt()}',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: widget.color)),
          ],
        ),
      ),
    );
  }

  String _fmtShortDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _AreaSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int? hoverIndex;
  _AreaSparklinePainter(this.values, this.color, this.hoverIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.fold<double>(0, (p, e) => math.max(p, e));
    final minV = values.fold<double>(maxV, (p, e) => math.min(p, e));
    final range = (maxV - minV) <= 0 ? 1.0 : (maxV - minV);
    final n = values.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width;
    const topPad = 8.0;
    const bottomPad = 2.0;
    final chartHeight = math.max(1.0, size.height - topPad - bottomPad);

    final points = List.generate(n, (i) {
      final x = i * stepX;
      final normalized = (values[i] - minV) / range;
      final y = topPad + chartHeight - normalized * chartHeight;
      return Offset(x, y);
    });

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final areaPath = Path()
      ..addPath(linePath, Offset.zero)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(areaPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    if (hoverIndex != null && hoverIndex! >= 0 && hoverIndex! < points.length) {
      final hp = points[hoverIndex!];
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      const dashH = 4.0, dashG = 4.0;
      var startY = 0.0;
      while (startY < size.height) {
        canvas.drawLine(
            Offset(hp.dx, startY), Offset(hp.dx, math.min(startY + dashH, size.height)), dashPaint);
        startY += dashH + dashG;
      }
      canvas.drawCircle(hp, 8, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(hp, 4, Paint()..color = color);
      canvas.drawCircle(
          hp, 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaSparklinePainter oldDelegate) =>
      oldDelegate.hoverIndex != hoverIndex ||
      oldDelegate.values != values ||
      oldDelegate.color != color;
}

// =====================================================================
// SECTION 1: APPLICANT ANALYTICS
// =====================================================================
class ApplicantAnalyticsSection extends StatefulWidget {
  final List<Applicant> applicants;
  const ApplicantAnalyticsSection({super.key, required this.applicants});

  @override
  State<ApplicantAnalyticsSection> createState() =>
      _ApplicantAnalyticsSectionState();
}

class _ApplicantAnalyticsSectionState extends State<ApplicantAnalyticsSection> {
  String _barangayFilter = 'All';

  List<Applicant> get _filtered => _barangayFilter == 'All'
      ? widget.applicants
      : widget.applicants.where((a) => a.barangay == _barangayFilter).toList();

  void _openResume(Applicant a) {
    showToast(
      context,
      'Opening ${a.resumeFileName} \u2014 kasama ang sinagutang application form ni ${a.name}.',
      icon: Icons.picture_as_pdf,
      iconColor: _C.rose,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final matched = filtered.where((a) => a.matchStatus == 'matched').length;
    final notMatched = filtered.where((a) => a.matchStatus == 'not_matched').length;
    final pending = filtered.where((a) => a.matchStatus == 'pending').length;
    final processed = matched + notMatched;
    final matchRate = processed > 0 ? ((matched / processed) * 100).round() : 0;

    final today = DateTime(2026, 9, 8);
    final dates = List.generate(14, (i) => today.subtract(Duration(days: 13 - i)));
    final regSeries = <double>[];
    final matchedSeries = <double>[];
    final notMatchedSeries = <double>[];
    for (final d in dates) {
      final dayApplicants = filtered.where((a) => _isSameDate(a.registeredDate, d));
      regSeries.add(dayApplicants.length.toDouble());
      matchedSeries.add(
          dayApplicants.where((a) => a.matchStatus == 'matched').length.toDouble());
      notMatchedSeries.add(
          dayApplicants.where((a) => a.matchStatus == 'not_matched').length.toDouble());
    }

    final recent = [...filtered]..sort((a, b) => b.registeredDate.compareTo(a.registeredDate));
    final recentTop = recent.take(12).toList();

    final donutSegments = [
      if (matched > 0) MapEntry('Matched', matched.toDouble()),
      if (notMatched > 0) MapEntry('No match yet', notMatched.toDouble()),
      if (pending > 0) MapEntry('Under review', pending.toDouble()),
    ];
    final donutColors = {
      'Matched': _C.emerald,
      'No match yet': _C.rose,
      'Under review': _C.amber,
    };

    final kpiCards = [
      _KpiCard(
          label: 'REGISTERED JOB SEEKERS',
          numericValue: filtered.length,
          icon: Icons.groups_outlined,
          color: _C.slate900,
          subtitle: 'Signed up in the last 14 days'),
      _KpiCard(
          label: 'MATCHED TO A JOB',
          numericValue: matched,
          icon: Icons.check_circle_outline,
          color: _C.emerald600,
          subtitle: 'Resume + form matched to an employer listing',
          subtitleColor: _C.emerald600),
      _KpiCard(
          label: 'NO MATCH YET',
          numericValue: notMatched,
          icon: Icons.cancel_outlined,
          color: _C.rose600,
          subtitle: 'Reviewed but no qualifying job found'),
      _KpiCard(
          label: 'MATCH RATE',
          numericValue: matchRate,
          suffix: '%',
          icon: Icons.trending_up,
          color: _C.purple,
          subtitle: 'Of $processed with a completed resume review'),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.55,
              children: List.generate(
                kpiCards.length,
                (i) => FadeSlideEntrance(delayMs: i * 80, child: kpiCards[i]),
              ),
            );
          }),
          const SizedBox(height: 20),
          FadeSlideEntrance(
            delayMs: 320,
            child: Row(
              children: [
                const Text('Barangay:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: _C.slate500)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: _C.slate300),
                      borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _barangayFilter,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _C.slate700),
                      items: ['All', ...kBarangays]
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setState(() => _barangayFilter = v ?? 'All'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideEntrance(
            delayMs: 380,
            child: LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 760 ? 3 : (c.maxWidth > 480 ? 2 : 1);
              const cardHeight = 260.0;
              final cellWidth = (c.maxWidth - (cols - 1) * 16) / cols;
              final cards = [
                _TrendMiniCard(
                    label: 'Registered',
                    color: _C.slate900,
                    value: filtered.length,
                    dates: dates,
                    values: regSeries),
                _TrendMiniCard(
                    label: 'Matched',
                    color: _C.emerald,
                    value: matched,
                    dates: dates,
                    values: matchedSeries),
                _TrendMiniCard(
                    label: 'No match',
                    color: _C.rose,
                    value: notMatched,
                    dates: dates,
                    values: notMatchedSeries),
              ];
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: cellWidth / cardHeight,
                children: List.generate(
                  cards.length,
                  (i) => FadeSlideEntrance(delayMs: 420 + i * 100, child: cards[i]),
                ),
              );
            }),
          ),
          FadeSlideEntrance(
            delayMs: 460,
            child: _SectionCard(
              title: 'Matching Breakdown',
              icon: Icons.auto_awesome,
              iconColor: _C.amber,
              child: LayoutBuilder(builder: (context, c) {
                final stacked = c.maxWidth < 480;
                final donut = SizedBox(
                  width: 170,
                  height: 170,
                  child: donutSegments.isEmpty
                      ? const SizedBox()
                      : DonutChart(segments: donutSegments, colors: donutColors),
                );
                final legend = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: donutSegments
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: donutColors[s.key], shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text(s.key,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: _C.slate600,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 24),
                                Text('${s.value.toInt()}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _C.slate900)),
                              ],
                            ),
                          ))
                      .toList(),
                );
                return stacked
                    ? Column(children: [donut, const SizedBox(height: 20), legend])
                    : Row(children: [donut, const SizedBox(width: 32), Expanded(child: legend)]);
              }),
            ),
          ),
          FadeSlideEntrance(
            delayMs: 540,
            child: _SectionCard(
              title: 'Recent Registrations, Resumes & Matching Records',
              icon: Icons.list_alt_outlined,
              trailing: OutlinedButton.icon(
                onPressed: () => showToast(
                  context,
                  filtered.isEmpty
                      ? 'No records to export for this barangay yet.'
                      : 'Exported ${filtered.length} record(s) to Excel.',
                  icon: Icons.download,
                  iconColor: _C.primary,
                ),
                icon: const Icon(Icons.download, size: 15),
                label: const Text('Export to Excel',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _C.slate700,
                    side: const BorderSide(color: _C.slate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 60,
                  headingRowColor: MaterialStateProperty.all(_C.slate100),
                  columns: const [
                    DataColumn(label: Text('Job Seeker')),
                    DataColumn(label: Text('Barangay')),
                    DataColumn(label: Text('Target Job')),
                    DataColumn(label: Text('Registered')),
                    DataColumn(label: Text('Yrs. Exp.')),
                    DataColumn(label: Text('Matched Jobs')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Resume')),
                  ],
                  rows: recentTop
                      .map((a) => DataRow(cells: [
                            DataCell(Text(a.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataCell(Text('Brgy. ${a.barangay}', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(a.targetJob, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_fmtDate(a.registeredDate),
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                            DataCell(Text('${a.yearsExperience}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataCell(Text(a.matchStatus == 'matched' ? '${a.matchedJobsCount}' : '\u2014',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataCell(_StatusBadge(kMatchStyles[a.matchStatus]!)),
                            DataCell(
                              a.resumeSubmitted
                                  ? IconButton(
                                      tooltip: 'View resume (PDF) & form',
                                      icon: const Icon(Icons.picture_as_pdf, size: 17, color: _C.rose600),
                                      onPressed: () => _openResume(a),
                                    )
                                  : const Text('Not yet submitted',
                                      style: TextStyle(fontSize: 11, color: _C.slate400)),
                            ),
                          ]))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SECTION 2: USER MANAGEMENT
// =====================================================================
class UserManagementSection extends StatefulWidget {
  final List<JobSeekerUser> initialUsers;
  const UserManagementSection({super.key, required this.initialUsers});

  @override
  State<UserManagementSection> createState() => _UserManagementSectionState();
}

class _UserManagementSectionState extends State<UserManagementSection> {
  late List<JobSeekerUser> _users;
  String _statusFilter = 'All';
  String _search = '';
  final List<AuditEntry> _auditLog = [];
  int _nextAuditId = 1;

  @override
  void initState() {
    super.initState();
    _users = List.of(widget.initialUsers);
  }

  List<JobSeekerUser> get _filtered => _users.where((u) {
        final matchesStatus = _statusFilter == 'All' || u.status == _statusFilter;
        final q = _search.trim().toLowerCase();
        final matchesSearch =
            q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
        return matchesStatus && matchesSearch;
      }).toList();

  void _logAction(String action, String detail) {
    setState(() {
      _auditLog.insert(
        0,
        AuditEntry(
          id: _nextAuditId++,
          actor: 'System Admin',
          action: action,
          detail: detail,
          timestamp: _fmtDateTime(DateTime.now()),
        ),
      );
    });
  }

  void _toggleStatus(JobSeekerUser user) {
    final next = user.status == 'active' ? 'inactive' : 'active';
    setState(() => user.status = next);
    _logAction(
      next == 'inactive' ? 'deactivated' : 'activated',
      next == 'inactive'
          ? "marked ${user.name}'s account as inactive."
          : "re-activated ${user.name}'s account.",
    );
    showToast(context, '${user.name} is now $next.');
  }

  Future<void> _confirmDelete(JobSeekerUser user) async {
    final confirmed =
        await showDialog<bool>(context: context, builder: (ctx) => _DeleteUserDialog(user: user));
    if (confirmed == true) {
      setState(() => _users.removeWhere((u) => u.id == user.id));
      _logAction('deleted', "deleted ${user.name}'s account (${user.email}).");
      showToast(context, "Deleted ${user.name}'s account.",
          icon: Icons.delete_outline, iconColor: _C.rose);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _users.length;
    final active = _users.where((u) => u.status == 'active').length;
    final inactive = total - active;
    final filtered = _filtered;

    final kpiCards = [
      _KpiCard(
          label: 'TOTAL ACCOUNTS',
          numericValue: total,
          icon: Icons.groups_outlined,
          color: _C.slate900,
          subtitle: 'Job seekers who have registered'),
      _KpiCard(
          label: 'ACTIVE',
          numericValue: active,
          icon: Icons.power_settings_new,
          color: _C.emerald600,
          subtitle: 'Logged in within the last few days'),
      _KpiCard(
          label: 'INACTIVE',
          numericValue: inactive,
          icon: Icons.block_outlined,
          color: _C.slate500,
          subtitle: "Disabled or haven't logged in in a while"),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 700 ? 3 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.1,
              children: List.generate(
                  kpiCards.length, (i) => FadeSlideEntrance(delayMs: i * 80, child: kpiCards[i])),
            );
          }),
          const SizedBox(height: 20),
          FadeSlideEntrance(
            delayMs: 260,
            child: _SectionCard(
              title: 'Job Seeker Accounts',
              icon: Icons.manage_accounts_outlined,
              trailing: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search name or email',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _C.slate300)),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        border: Border.all(color: _C.slate300),
                        borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _C.slate700),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All statuses')),
                          DropdownMenuItem(value: 'active', child: Text('Active only')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive only')),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
                      ),
                    ),
                  ),
                ],
              ),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                          child: Text('No accounts match your search or filter.',
                              style: TextStyle(color: _C.slate400))))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 64,
                        headingRowColor: MaterialStateProperty.all(_C.slate100),
                        columns: const [
                          DataColumn(label: Text('Job Seeker')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Barangay')),
                          DataColumn(label: Text('Last Login')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filtered
                            .map((u) => DataRow(cells: [
                                  DataCell(Text(u.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 12))),
                                  DataCell(Text(u.email,
                                      style: const TextStyle(fontSize: 12, color: _C.slate500))),
                                  DataCell(Text('Brgy. ${u.barangay}', style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(u.lastLogin,
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                                  DataCell(_StatusBadge(kUserStatusStyles[u.status]!)),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _toggleStatus(u),
                                        icon: Icon(Icons.power_settings_new,
                                            size: 13,
                                            color:
                                                u.status == 'active' ? _C.amber600 : _C.emerald600),
                                        label: Text(u.status == 'active' ? 'Deactivate' : 'Activate',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: u.status == 'active'
                                                    ? _C.amber600
                                                    : _C.emerald600)),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _confirmDelete(u),
                                        icon: Icon(Icons.delete_outline, size: 13, color: _C.rose600),
                                        label: Text('Delete',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _C.rose600)),
                                      ),
                                    ],
                                  )),
                                ]))
                            .toList(),
                      ),
                    ),
            ),
          ),
          FadeSlideEntrance(
            delayMs: 340,
            child: _SectionCard(
              title: 'Audit Log',
              icon: Icons.history,
              child: _auditLog.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text('No account actions yet. Actions you take above will appear here.',
                              style: TextStyle(color: _C.slate400, fontSize: 12))))
                  : Column(
                      children: List.generate(_auditLog.length,
                          (i) => FadeSlideEntrance(delayMs: i * 50, child: _auditRow(_auditLog[i]))),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditRow(AuditEntry e) {
    IconData icon;
    Color color;
    Color bg;
    switch (e.action) {
      case 'deactivated':
        icon = Icons.shield_moon_outlined;
        color = _C.amber600;
        bg = const Color(0xFFFFFBEB);
        break;
      case 'activated':
        icon = Icons.power_settings_new;
        color = _C.emerald600;
        bg = const Color(0xFFECFDF5);
        break;
      default:
        icon = Icons.delete_outline;
        color = _C.rose600;
        bg = const Color(0xFFFFF1F2);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(border: Border.all(color: _C.slate200), borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, color: _C.slate700),
                      children: [
                        TextSpan(
                            text: '${e.actor} ',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: _C.slate900)),
                        TextSpan(text: e.detail),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(e.timestamp,
                      style: const TextStyle(fontSize: 10, color: _C.slate400, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteUserDialog extends StatelessWidget {
  final JobSeekerUser user;
  const _DeleteUserDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.warning_amber_rounded, color: _C.rose600),
              ),
              const SizedBox(height: 14),
              const Text('Delete this account?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.slate900)),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: _C.slate500),
                  children: [
                    TextSpan(
                        text: user.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _C.slate700)),
                    const TextSpan(
                        text: " will lose access to JobKonek and will need to register again. This can't be undone."),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _C.rose600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
}

// =====================================================================
// SECTION 3: CONCERNS & FEEDBACK
// (Inbox for messages from job seekers who did not get matched, or
// who have any other concern.)
// =====================================================================
class ConcernsSection extends StatefulWidget {
  final List<Concern> initialConcerns;
  const ConcernsSection({super.key, required this.initialConcerns});

  @override
  State<ConcernsSection> createState() => _ConcernsSectionState();
}

class _ConcernsSectionState extends State<ConcernsSection> {
  late List<Concern> _concerns;
  String _filter = 'unresolved'; // all | unresolved | resolved

  @override
  void initState() {
    super.initState();
    _concerns = List.of(widget.initialConcerns);
  }

  List<Concern> get _filtered {
    switch (_filter) {
      case 'unresolved':
        return _concerns.where((c) => !c.resolved).toList();
      case 'resolved':
        return _concerns.where((c) => c.resolved).toList();
      default:
        return _concerns;
    }
  }

  void _toggleResolved(Concern c) {
    setState(() => c.resolved = !c.resolved);
    showToast(
      context,
      c.resolved
          ? "Marked ${c.applicantName}'s concern as resolved."
          : "Reopened ${c.applicantName}'s concern.",
      icon: c.resolved ? Icons.check_circle : Icons.mark_email_unread_outlined,
      iconColor: c.resolved ? _C.emerald : _C.amber600,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _concerns.length;
    final unresolved = _concerns.where((c) => !c.resolved).length;
    final resolved = total - unresolved;
    final filtered = _filtered;

    final kpiCards = [
      _KpiCard(
          label: 'TOTAL CONCERNS',
          numericValue: total,
          icon: Icons.forum_outlined,
          color: _C.slate900,
          subtitle: 'From job seekers with no job match yet'),
      _KpiCard(
          label: 'NEEDS RESPONSE',
          numericValue: unresolved,
          icon: Icons.priority_high,
          color: _C.rose600,
          subtitle: 'Waiting for a PESO admin follow-up'),
      _KpiCard(
          label: 'RESOLVED',
          numericValue: resolved,
          icon: Icons.check_circle_outline,
          color: _C.emerald600,
          subtitle: 'Already addressed'),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 700 ? 3 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.1,
              children: List.generate(
                  kpiCards.length, (i) => FadeSlideEntrance(delayMs: i * 80, child: kpiCards[i])),
            );
          }),
          const SizedBox(height: 20),
          FadeSlideEntrance(
            delayMs: 240,
            child: Row(
              children: [
                const Text('Show:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: _C.slate500)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: _C.slate300),
                      borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filter,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _C.slate700),
                      items: const [
                        DropdownMenuItem(value: 'unresolved', child: Text('Needs response')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                        DropdownMenuItem(value: 'all', child: Text('All concerns')),
                      ],
                      onChanged: (v) => setState(() => _filter = v ?? 'unresolved'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                  child: Text('Wala pang concerns dito.', style: TextStyle(color: _C.slate400))),
            )
          else
            Column(
              children: List.generate(filtered.length, (i) {
                final c = filtered[i];
                return FadeSlideEntrance(delayMs: i * 60, child: _concernCard(c));
              }),
            ),
        ],
      ),
    );
  }

  Widget _concernCard(Concern c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: c.resolved ? _C.emerald.withValues(alpha: 0.35) : _C.slate200),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFFFF1F2),
                    child: Icon(Icons.person_outline, color: _C.rose600, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.applicantName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13, color: _C.slate900)),
                      const SizedBox(height: 2),
                      Text('Brgy. ${c.barangay} \u00b7 Target: ${c.targetJob} \u00b7 ${_fmtDate(c.submittedDate)}',
                          style: const TextStyle(fontSize: 11, color: _C.slate500)),
                    ],
                  ),
                ),
                _StatusBadge(c.resolved
                    ? const StatusStyle('Resolved', Color(0xFF047857), Color(0xFFECFDF5), Color(0xFF10B981))
                    : const StatusStyle('Needs Response', Color(0xFFBE123C), Color(0xFFFFF1F2), Color(0xFFF43F5E))),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _C.slate100, borderRadius: BorderRadius.circular(14)),
              child: Text(c.message, style: const TextStyle(fontSize: 12.5, color: _C.slate700, height: 1.4)),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _toggleResolved(c),
                icon: Icon(c.resolved ? Icons.replay : Icons.check_circle_outline,
                    size: 15, color: c.resolved ? _C.slate500 : _C.emerald600),
                label: Text(c.resolved ? 'Reopen' : 'Mark as Resolved',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.resolved ? _C.slate500 : _C.emerald600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// SECTION 4: JOB BATCH INGESTION
// Uploading an Excel job batch now also auto-matches each job to
// qualified job seeker accounts (by target job + years of experience).
// =====================================================================
class JobBatchIngestionSection extends StatefulWidget {
  const JobBatchIngestionSection({super.key});

  @override
  State<JobBatchIngestionSection> createState() => _JobBatchIngestionSectionState();
}

class _JobBatchIngestionSectionState extends State<JobBatchIngestionSection> {
  final List<IngestionLog> _logs = [
    IngestionLog(
        id: 1,
        job: 'IT Support Specialist',
        employer: 'Montalban LGU',
        batch: 'BATCH-001',
        uploaded: 'Today, 08:30 AM',
        status: 'Active',
        matchedAccounts: 6),
    IngestionLog(
        id: 2,
        job: 'Data Encoder',
        employer: 'Prime BPO',
        batch: 'BATCH-001',
        uploaded: 'Today, 08:30 AM',
        status: 'Active',
        matchedAccounts: 4),
    IngestionLog(
        id: 3,
        job: 'Warehouse Assistant',
        employer: 'Manggahan Logistics Co.',
        batch: 'BATCH-002',
        uploaded: 'Yesterday, 04:12 PM',
        status: 'Active',
        matchedAccounts: 9),
    IngestionLog(
        id: 4,
        job: 'Bookkeeper',
        employer: 'Rosario Trading',
        batch: 'BATCH-002',
        uploaded: 'Yesterday, 04:12 PM',
        status: 'Active',
        matchedAccounts: 2),
  ];
  int _nextId = 5;
  bool _hover = false;
  final _rand = _SeededRandom(101);

  Future<void> _simulateUpload() async {
    final controller = TextEditingController(text: 'New_Job_Batch.xlsx');
    final fileName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Simulate Excel Upload'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'File name', hintText: 'e.g. Montalban_Batch_003.xlsx'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Ingest')),
        ],
      ),
    );
    if (fileName == null || fileName.trim().isEmpty) return;
    if (!fileName.toLowerCase().endsWith('.xlsx')) {
      showToast(
        context,
        '"$fileName" is not a .xlsx file \u2014 please upload a file matching the Montalban offline job template.',
        icon: Icons.error_outline,
        iconColor: _C.rose,
      );
      return;
    }
    final matchedAccounts = 2 + (_rand.next() * 12).floor();
    setState(() {
      _logs.insert(
        0,
        IngestionLog(
          id: _nextId++,
          job: fileName.replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), ''),
          employer: 'Uploaded by IT Admin',
          batch: 'BATCH-${(_logs.length + 1).toString().padLeft(3, '0')}',
          uploaded: 'Just now',
          status: 'Active',
          matchedAccounts: matchedAccounts,
        ),
      );
    });
    showToast(
      context,
      'Ingested "$fileName" \u2014 auto-matched to $matchedAccounts job seeker account(s) based on their submitted qualifications.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideEntrance(
            delayMs: 0,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                onTap: _simulateUpload,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 30),
                  decoration: BoxDecoration(
                    color: _hover ? _C.primary.withValues(alpha: 0.10) : _C.primary.withValues(alpha: 0.05),
                    border: Border.all(color: _C.primary.withValues(alpha: _hover ? 0.5 : 0.25), width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      AnimatedScale(
                        scale: _hover ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: _C.primary.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 4),
                            ],
                          ),
                          child: Icon(Icons.cloud_upload_outlined, size: 28, color: _C.primary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Select or drop PESO Excel file here',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.slate900)),
                      const SizedBox(height: 8),
                      Text(
                        'Only .xlsx files following the Montalban offline job template are supported. New listings are auto-matched to job seeker accounts by qualification.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: _C.primaryDark),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _simulateUpload,
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Browse Files', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideEntrance(
            delayMs: 150,
            child: _SectionCard(
              title: 'Recent Ingestion Logs',
              icon: Icons.receipt_long_outlined,
              child: Column(
                children: List.generate(_logs.length, (i) {
                  final log = _logs[i];
                  return FadeSlideEntrance(
                    delayMs: 200 + i * 60,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            border: Border.all(color: _C.slate200), borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration:
                                  BoxDecoration(color: _C.slate100, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.work_outline, size: 18, color: _C.slate600),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log.job,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800, fontSize: 13, color: _C.slate900),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Text('${log.employer} \u00b7 Batch: ${log.batch} | Uploaded: ${log.uploaded}',
                                      style: const TextStyle(fontSize: 11, color: _C.slate500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_search, size: 12, color: _C.emerald600),
                                      const SizedBox(width: 4),
                                      Text('Matched ${log.matchedAccounts} job seeker account(s)',
                                          style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w700, color: _C.emerald600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(StatusStyle(
                                log.status, _C.emerald600, const Color(0xFFECFDF5), _C.emerald)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SECTION 5: DOLE SPRS EXPORT
// =====================================================================
class DoleSprsExportSection extends StatefulWidget {
  final List<Applicant> applicants;
  const DoleSprsExportSection({super.key, required this.applicants});

  @override
  State<DoleSprsExportSection> createState() => _DoleSprsExportSectionState();
}

class _DoleSprsExportSectionState extends State<DoleSprsExportSection> {
  late List<Applicant> _matched;
  final Set<int> _handedOff = {};

  @override
  void initState() {
    super.initState();
    _matched = widget.applicants.where((a) => a.matchStatus == 'matched').take(15).toList();
  }

  void _generateExcel() {
    if (_matched.isEmpty) {
      showToast(context, 'No matched candidates to export yet.',
          icon: Icons.error_outline, iconColor: _C.rose);
      return;
    }
    showToast(context, 'Generated DOLE SPRS export for ${_matched.length} candidate(s).');
  }

  void _handoff() {
    final pending = _matched.where((a) => !_handedOff.contains(a.id)).toList();
    if (pending.isEmpty) {
      showToast(context, 'Everyone here has already been handed off to PESO Admin.');
      return;
    }
    setState(() => _handedOff.addAll(pending.map((a) => a.id)));
    showToast(context, 'Handed off ${pending.length} candidate(s) to PESO Admin.');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideEntrance(
            delayMs: 0,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list, size: 15, color: _C.slate500),
                    const SizedBox(width: 8),
                    Text('Showing ${_matched.length} Matched Candidates',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _C.slate600)),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _generateExcel,
                      icon: const Icon(Icons.download, size: 15),
                      label: const Text('Generate DOLE SPRS Excel',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _C.slate700,
                          side: const BorderSide(color: _C.slate300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    ElevatedButton.icon(
                      onPressed: _handoff,
                      icon: const Icon(Icons.send, size: 15),
                      label: const Text('Handoff to PESO Admin',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _C.emerald600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(_matched.length, (i) {
              final a = _matched[i];
              final isHandedOff = _handedOff.contains(a.id);
              return FadeSlideEntrance(
                delayMs: 100 + i * 60,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: isHandedOff ? _C.emerald.withValues(alpha: 0.4) : _C.slate200),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFECFDF5),
                            child: Icon(Icons.person_outline, color: _C.emerald600)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 14, color: _C.slate900)),
                              const SizedBox(height: 3),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 12, color: _C.slate500),
                                  children: [
                                    const TextSpan(text: 'Target Job: '),
                                    TextSpan(
                                        text: a.targetJob,
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: _C.slate700)),
                                    const TextSpan(text: '  \u00b7  '),
                                    TextSpan(
                                        text: '${a.yearsExperience} yrs experience',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: _C.slate700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: isHandedOff
                              ? Padding(
                                  key: const ValueKey('handed-off'),
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: _C.slate100, borderRadius: BorderRadius.circular(20)),
                                    child: const Text('Handed off',
                                        style: TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w700, color: _C.slate500)),
                                  ),
                                )
                              : const SizedBox(key: ValueKey('pending')),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Matched Jobs', style: TextStyle(fontSize: 10, color: _C.slate400)),
                            Text('${a.matchedJobsCount}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.emerald600)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        AnimatedScale(
                          scale: isHandedOff ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(color: _C.emerald, shape: BoxShape.circle),
                            child: const Icon(Icons.check, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SECTION 6: PLATFORM ANALYTICS
// (AI exam settings are gone \u2014 replaced by the resume-matching engine.)
// =====================================================================
class PlatformAnalyticsSection extends StatefulWidget {
  final List<Applicant> applicants;
  const PlatformAnalyticsSection({super.key, required this.applicants});

  @override
  State<PlatformAnalyticsSection> createState() => _PlatformAnalyticsSectionState();
}

class _PlatformAnalyticsSectionState extends State<PlatformAnalyticsSection>
    with SingleTickerProviderStateMixin {
  static const _defaultMinYears = 1.0;
  static const _defaultConfidence = 70.0;
  static const _defaultMaxMatches = 5.0;

  double _minYears = _defaultMinYears;
  double _confidence = _defaultConfidence;
  double _maxMatches = _defaultMaxMatches;
  double _savedMinYears = _defaultMinYears;
  double _savedConfidence = _defaultConfidence;
  double _savedMaxMatches = _defaultMaxMatches;

  late final AnimationController _pulseController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _hasUnsaved =>
      _minYears != _savedMinYears || _confidence != _savedConfidence || _maxMatches != _savedMaxMatches;

  void _save() {
    setState(() {
      _savedMinYears = _minYears;
      _savedConfidence = _confidence;
      _savedMaxMatches = _maxMatches;
    });
    showToast(context,
        'Matching settings saved: ${_minYears.round()} yr min \u00b7 ${_confidence.round()}% confidence \u00b7 up to ${_maxMatches.round()} matches.');
  }

  void _reset() {
    setState(() {
      _minYears = _defaultMinYears;
      _confidence = _defaultConfidence;
      _maxMatches = _defaultMaxMatches;
      _savedMinYears = _defaultMinYears;
      _savedConfidence = _defaultConfidence;
      _savedMaxMatches = _defaultMaxMatches;
    });
    showToast(context, 'Matching settings reset to default.');
  }

  @override
  Widget build(BuildContext context) {
    final resumesProcessed =
        widget.applicants.where((a) => a.resumeSubmitted && a.formSubmitted).length;
    final autoMatched = widget.applicants.where((a) => a.matchStatus == 'matched').length;
    final pendingReview = widget.applicants.where((a) => a.matchStatus == 'pending').length;

    final kpiCards = [
      _KpiCard(
          label: 'RESUMES PROCESSED',
          numericValue: resumesProcessed,
          icon: Icons.description_outlined,
          color: _C.primary),
      _KpiCard(
          label: 'AUTO-MATCHED CANDIDATES',
          numericValue: autoMatched,
          icon: Icons.verified_outlined,
          color: _C.emerald600),
      _KpiCard(
          label: 'PENDING MANUAL REVIEW',
          numericValue: pendingReview,
          icon: Icons.pending_actions_outlined,
          color: _C.amber600),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 700 ? 3 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.3,
              children: List.generate(
                  kpiCards.length, (i) => FadeSlideEntrance(delayMs: i * 80, child: kpiCards[i])),
            );
          }),
          const SizedBox(height: 20),
          FadeSlideEntrance(
            delayMs: 260,
            child: _SectionCard(
              title: 'Job Matching Engine Settings',
              icon: Icons.tune,
              iconColor: _C.indigo,
              trailing: _hasUnsaved
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.7, end: 1.0),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(20)),
                        child: Text('Unsaved changes',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.amber600)),
                      ),
                    )
                  : null,
              child: Column(
                children: [
                  LayoutBuilder(builder: (context, c) {
                    final wide = c.maxWidth > 760;
                    final sliders = [
                      _settingSlider('Minimum years of experience', Icons.timeline_outlined, _minYears, 0, 10,
                          (v) => setState(() => _minYears = v),
                          'Applicants below this are routed to manual review instead of auto-match.'),
                      _settingSlider('Auto-match confidence threshold (%)', Icons.psychology_outlined, _confidence,
                          40, 95, (v) => setState(() => _confidence = v),
                          'How closely the resume + form must fit a job posting to auto-match.'),
                      _settingSlider('Max matches shown per job seeker', Icons.list_alt_outlined, _maxMatches, 1,
                          10, (v) => setState(() => _maxMatches = v),
                          'Caps how many matched job postings a job seeker sees at once.'),
                    ];
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: sliders
                                .map((s) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: s)))
                                .toList(),
                          )
                        : Column(
                            children: sliders.map((s) => Padding(padding: const EdgeInsets.only(bottom: 20), child: s)).toList(),
                          );
                  }),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined, size: 15),
                        label: const Text('Save Matching Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _C.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt, size: 15),
                        label: const Text('Reset to Default', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _C.slate600,
                            side: const BorderSide(color: _C.slate300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          FadeSlideEntrance(
            delayMs: 360,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _C.slate200)),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final t = _pulseController.value;
                      return SizedBox(
                        width: 70,
                        height: 70,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: (1 - t).clamp(0, 1),
                              child: Transform.scale(
                                scale: 1 + t,
                                child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration:
                                        BoxDecoration(color: _C.primary.withValues(alpha: 0.3), shape: BoxShape.circle)),
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: _C.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                              child: Icon(Icons.hub_outlined, color: _C.primary, size: 26),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('AI Matching Engine Status',
                      style: TextStyle(fontWeight: FontWeight.w800, color: _C.slate900)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 15, color: _C.emerald600),
                        const SizedBox(width: 6),
                        Text('100% Uptime - Healthy',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.emerald600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingSlider(String label, IconData icon, double value, double min, double max,
      ValueChanged<double> onChanged, String helper) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: _C.slate600),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.slate600))),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _C.indigo,
                    thumbColor: _C.indigo,
                    overlayColor: _C.indigo.withValues(alpha: 0.15)),
                child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: math.max(1, ((max - min) / 1).round()),
                    onChanged: onChanged),
              ),
            ),
            SizedBox(
              width: 46,
              child: AnimatedCounterText(
                value: value.round(),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _C.slate900),
                duration: const Duration(milliseconds: 200),
              ),
            ),
          ],
        ),
        Text(helper, style: const TextStyle(fontSize: 11, color: _C.slate400)),
      ],
    );
  }
}