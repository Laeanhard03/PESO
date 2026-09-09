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

const Map<String, StatusStyle> kAssessmentStyles = {
  'passed': StatusStyle('Passed \u00b7 Pre-Vetted', Color(0xFF047857),
      Color(0xFFECFDF5), Color(0xFF10B981)),
  'failed': StatusStyle('Did Not Pass', Color(0xFFBE123C), Color(0xFFFFF1F2),
      Color(0xFFF43F5E)),
  'pending': StatusStyle('Assessment Pending', Color(0xFFB45309),
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
  final String assessmentStatus; // pending | passed | failed
  final int? score;

  Applicant({
    required this.id,
    required this.name,
    required this.barangay,
    required this.targetJob,
    required this.registeredDate,
    required this.assessmentStatus,
    this.score,
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

  IngestionLog({
    required this.id,
    required this.job,
    required this.employer,
    required this.batch,
    required this.uploaded,
    required this.status,
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
      final tookAssessment = rand.next() > 0.22;
      var status = 'pending';
      int? score;
      if (tookAssessment) {
        score = (rand.next() * 100).floor();
        status = score >= 50 ? 'passed' : 'failed';
      }
      rows.add(Applicant(
        id: id++,
        name: '${_pick(kFirstNames, rand)} ${_pick(kLastNames, rand)}',
        barangay: _pick(kBarangays, rand),
        targetJob: _pick(kJobs, rand),
        registeredDate: date,
        assessmentStatus: status,
        score: score,
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
enum AdminTab { analytics, users, ingestion, export, platform }

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
    'Job seeker registrations and AI assessment outcomes across Montalban barangays.',
  ),
  _NavItem(
    AdminTab.users,
    'User Management',
    Icons.manage_accounts_outlined,
    'Job Seeker Accounts',
    "See who has logged in, mark accounts active or inactive, and remove accounts.",
  ),
  _NavItem(
    AdminTab.ingestion,
    'Job Batch Ingestion',
    Icons.cloud_upload_outlined,
    'Job Batch Ingestion',
    'Batch upload Excel files from PESO Admins to populate the core database.',
  ),
  _NavItem(
    AdminTab.export,
    'DOLE SPRS Export',
    Icons.download_outlined,
    'Pre-Vetted Candidates Pipeline',
    'Extract passers and export data strictly into DOLE SPRS-compliant formats.',
  ),
  _NavItem(
    AdminTab.platform,
    'Platform Analytics',
    Icons.bar_chart_outlined,
    'AI Engine & System Health',
    'Monitor live API traffic, exam generation, and system uptime.',
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
    this.duration = const Duration(milliseconds: 560),
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
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
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = IntTween(begin: oldWidget.value, end: widget.value)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
      case AdminTab.ingestion:
        return const JobBatchIngestionSection();
      case AdminTab.export:
        return DoleSprsExportSection(applicants: _applicants);
      case AdminTab.platform:
        return const PlatformAnalyticsSection();
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
  const _Sidebar(
      {required this.activeTab, required this.onSelect, required this.onLogout});

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
// MINI AREA CHART (sparkline) — animated left-to-right wipe reveal
// =====================================================================
class MiniAreaChart extends StatefulWidget {
  final List<double> values;
  final Color color;
  const MiniAreaChart({super.key, required this.values, required this.color});

  @override
  State<MiniAreaChart> createState() => _MiniAreaChartState();
}

class _MiniAreaChartState extends State<MiniAreaChart>
    with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(covariant MiniAreaChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_listEquals(oldWidget.values, widget.values)) {
      _controller.forward(from: 0);
    }
  }

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
      builder: (context, child) => RepaintBoundary(
        child: CustomPaint(
          painter: _AreaPainter(widget.values, widget.color, _progress.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double progress;
  _AreaPainter(this.values, this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress.clamp(0, 1), size.height));

    final maxV = values.reduce(math.max);
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    final stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;

    final linePath = Path();
    final fillPath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / safeMax) * size.height;
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo((values.length - 1) * stepX, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AreaPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.values != values ||
      oldDelegate.color != color;
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
      builder: (context, child) => RepaintBoundary(
        child: CustomPaint(
          painter: _DonutPainter(widget.segments, widget.colors, _progress.value),
          size: Size.infinite,
        ),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final passed = filtered.where((a) => a.assessmentStatus == 'passed').length;
    final failed = filtered.where((a) => a.assessmentStatus == 'failed').length;
    final pending = filtered.where((a) => a.assessmentStatus == 'pending').length;
    final took = passed + failed;
    final passRate = took > 0 ? ((passed / took) * 100).round() : 0;

    final today = DateTime(2026, 9, 8);
    final dates = List.generate(14, (i) => today.subtract(Duration(days: 13 - i)));
    final regSeries = <double>[];
    final passSeries = <double>[];
    final failSeries = <double>[];
    for (final d in dates) {
      final dayApplicants = filtered.where((a) => _isSameDate(a.registeredDate, d));
      regSeries.add(dayApplicants.length.toDouble());
      passSeries.add(
          dayApplicants.where((a) => a.assessmentStatus == 'passed').length.toDouble());
      failSeries.add(
          dayApplicants.where((a) => a.assessmentStatus == 'failed').length.toDouble());
    }

    final recent = [...filtered]..sort((a, b) => b.registeredDate.compareTo(a.registeredDate));
    final recentTop = recent.take(12).toList();

    final donutSegments = [
      if (passed > 0) MapEntry('Passed', passed.toDouble()),
      if (failed > 0) MapEntry('Did not pass', failed.toDouble()),
      if (pending > 0) MapEntry('Pending', pending.toDouble()),
    ];
    final donutColors = {
      'Passed': _C.emerald,
      'Did not pass': _C.rose,
      'Pending': _C.amber,
    };

    final kpiCards = [
      _KpiCard(
          label: 'REGISTERED JOB SEEKERS',
          numericValue: filtered.length,
          icon: Icons.groups_outlined,
          color: _C.slate900,
          subtitle: 'Signed up in the last 14 days'),
      _KpiCard(
          label: 'PASSED ASSESSMENT',
          numericValue: passed,
          icon: Icons.check_circle_outline,
          color: _C.emerald600,
          subtitle: 'Pre-vetted, routed to PESO queue',
          subtitleColor: _C.emerald600),
      _KpiCard(
          label: 'DID NOT PASS',
          numericValue: failed,
          icon: Icons.cancel_outlined,
          color: _C.rose600,
          subtitle: 'Sent an AI-generated Action Plan'),
      _KpiCard(
          label: 'PASS RATE',
          numericValue: passRate,
          suffix: '%',
          icon: Icons.trending_up,
          color: _C.purple,
          subtitle: 'Of $took who completed an assessment'),
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
          const Text('Registrations & Assessment Outcomes',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: _C.slate900)),
          const SizedBox(height: 4),
          const Text(
              'Daily new sign-ups versus how many passed or failed their AI assessment.',
              style: TextStyle(fontSize: 12, color: _C.slate500)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final isRow = c.maxWidth > 900;
            final cards = [
              _trendCard('Registered', filtered.length, _C.slate700, regSeries, 0),
              _trendCard('Passed', passed, _C.emerald, passSeries, 100),
              _trendCard('Did not pass', failed, _C.rose, failSeries, 200),
            ];
            return isRow
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cards
                        .map((w) => Expanded(
                            child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: w)))
                        .toList(),
                  )
                : Column(
                    children:
                        cards.map((w) => Padding(padding: const EdgeInsets.only(bottom: 16), child: w)).toList());
          }),
          const SizedBox(height: 4),
          FadeSlideEntrance(
            delayMs: 480,
            child: _SectionCard(
              title: 'Assessment Breakdown',
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
            delayMs: 560,
            child: _SectionCard(
              title: 'Recent Registrations & Assessment Records',
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
                    DataColumn(label: Text('Score')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: recentTop
                      .map((a) => DataRow(cells: [
                            DataCell(Text(a.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataCell(Text('Brgy. ${a.barangay}', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(a.targetJob, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_fmtDate(a.registeredDate),
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                            DataCell(Text(a.score != null ? '${a.score}%' : '\u2014',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataCell(_StatusBadge(kAssessmentStyles[a.assessmentStatus]!)),
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

  Widget _trendCard(String label, int total, Color color, List<double> series, int delayMs) {
    return FadeSlideEntrance(
      delayMs: 400 + delayMs,
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _C.slate600)),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedCounterText(
              value: total,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 90, child: MiniAreaChart(values: series, color: color)),
            const SizedBox(height: 6),
            const Text('Last 14 days', style: TextStyle(fontSize: 11, color: _C.slate400)),
          ],
        ),
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
// SECTION 3: JOB BATCH INGESTION
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
        status: 'Active'),
    IngestionLog(
        id: 2,
        job: 'Data Encoder',
        employer: 'Prime BPO',
        batch: 'BATCH-001',
        uploaded: 'Today, 08:30 AM',
        status: 'Active'),
    IngestionLog(
        id: 3,
        job: 'Warehouse Assistant',
        employer: 'Manggahan Logistics Co.',
        batch: 'BATCH-002',
        uploaded: 'Yesterday, 04:12 PM',
        status: 'Active'),
    IngestionLog(
        id: 4,
        job: 'Bookkeeper',
        employer: 'Rosario Trading',
        batch: 'BATCH-002',
        uploaded: 'Yesterday, 04:12 PM',
        status: 'Active'),
  ];
  int _nextId = 5;
  bool _hover = false;

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
        ),
      );
    });
    showToast(context, 'Ingested "$fileName" \u2014 added to the job listings.');
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
                        'Only .xlsx files following the Montalban offline job template are supported.',
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
// SECTION 4: DOLE SPRS EXPORT
// =====================================================================
class DoleSprsExportSection extends StatefulWidget {
  final List<Applicant> applicants;
  const DoleSprsExportSection({super.key, required this.applicants});

  @override
  State<DoleSprsExportSection> createState() => _DoleSprsExportSectionState();
}

class _DoleSprsExportSectionState extends State<DoleSprsExportSection> {
  late List<Applicant> _passers;
  final Set<int> _handedOff = {};

  @override
  void initState() {
    super.initState();
    _passers = widget.applicants.where((a) => a.assessmentStatus == 'passed').take(15).toList();
  }

  void _generateExcel() {
    if (_passers.isEmpty) {
      showToast(context, 'No pre-vetted candidates to export yet.',
          icon: Icons.error_outline, iconColor: _C.rose);
      return;
    }
    showToast(context, 'Generated DOLE SPRS export for ${_passers.length} candidate(s).');
  }

  void _handoff() {
    final pending = _passers.where((a) => !_handedOff.contains(a.id)).toList();
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
                    Text('Showing ${_passers.length} Pre-Vetted Candidates',
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
            children: List.generate(_passers.length, (i) {
              final a = _passers[i];
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
                            const Text('AI Assessment Score', style: TextStyle(fontSize: 10, color: _C.slate400)),
                            Text('${a.score}%',
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
// SECTION 5: PLATFORM ANALYTICS
// =====================================================================
class PlatformAnalyticsSection extends StatefulWidget {
  const PlatformAnalyticsSection({super.key});

  @override
  State<PlatformAnalyticsSection> createState() => _PlatformAnalyticsSectionState();
}

class _PlatformAnalyticsSectionState extends State<PlatformAnalyticsSection>
    with SingleTickerProviderStateMixin {
  static const _defaultDuration = 45.0;
  static const _defaultQuestions = 20.0;
  static const _defaultPassing = 50.0;

  double _duration = _defaultDuration;
  double _questions = _defaultQuestions;
  double _passing = _defaultPassing;
  double _savedDuration = _defaultDuration;
  double _savedQuestions = _defaultQuestions;
  double _savedPassing = _defaultPassing;

  late final AnimationController _pulseController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _hasUnsaved =>
      _duration != _savedDuration || _questions != _savedQuestions || _passing != _savedPassing;

  void _save() {
    setState(() {
      _savedDuration = _duration;
      _savedQuestions = _questions;
      _savedPassing = _passing;
    });
    showToast(context,
        'Exam settings saved: ${_duration.round()} min \u00b7 ${_questions.round()} items \u00b7 ${_passing.round()}% passing.');
  }

  void _reset() {
    setState(() {
      _duration = _defaultDuration;
      _questions = _defaultQuestions;
      _passing = _defaultPassing;
      _savedDuration = _defaultDuration;
      _savedQuestions = _defaultQuestions;
      _savedPassing = _defaultPassing;
    });
    showToast(context, 'Exam settings reset to default.');
  }

  @override
  Widget build(BuildContext context) {
    final kpiCards = [
      _KpiCard(
          label: 'AI EXAMS GENERATED',
          numericValue: 1420,
          icon: Icons.lightbulb_outline,
          color: _C.primary),
      _KpiCard(
          label: 'PRE-VETTED PASSERS',
          numericValue: 842,
          icon: Icons.verified_outlined,
          color: _C.emerald600),
      _KpiCard(
          label: 'ACTION PLANS CREATED',
          numericValue: 578,
          icon: Icons.alt_route_outlined,
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
              title: 'AI Exam Settings',
              icon: Icons.timer_outlined,
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
                      _settingSlider('Exam duration (minutes)', Icons.timer_outlined, _duration, 10, 120,
                          (v) => setState(() => _duration = v), 'Applicants must submit before the timer runs out.'),
                      _settingSlider('Questions per exam', Icons.checklist_outlined, _questions, 5, 50,
                          (v) => setState(() => _questions = v), 'Items the AI generates per applicant per exam.'),
                      _settingSlider('Passing score (%)', Icons.check_circle_outline, _passing, 30, 90,
                          (v) => setState(() => _passing = v), 'Minimum score to be marked pre-vetted.'),
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
                        label: const Text('Save Exam Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                              child: Icon(Icons.podcasts, color: _C.primary, size: 26),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('LLM API Connection Status',
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
                    divisions: ((max - min) / 5).round(),
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