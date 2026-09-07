import 'package:flutter/material.dart';

import 'auth_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _activePageIndex = 0;

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color pesoGreen = const Color(0xFF2E7D32);

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildAdvancedFiltersDrawer(pesoGreen),
      backgroundColor: Colors.white,
      appBar: GlobalNavBar(
        pesoGreen: pesoGreen,
        activePageIndex: _activePageIndex,
        onTabSelected: (index) {
          setState(() => _activePageIndex = index);
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
        },
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                key: ValueKey<int>(_activePageIndex),
                child: _buildActiveContent(pesoGreen),
              ),
            ),
            GlobalFooter(
              pesoGreen: pesoGreen,
              onTabSelected: (index) {
                setState(() => _activePageIndex = index);
                _scrollToTop();
              },
              onScrollToTop: _scrollToTop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveContent(Color pesoGreen) {
    if (_activePageIndex == 0 || _activePageIndex == 4) {
      return _buildHomeContent(pesoGreen);
    }
    if (_activePageIndex == 1) return _buildJobsContent(pesoGreen);
    return _buildPlaceholderContent();
  }

  // ==========================================
  // TAB 1: DESIGNER HOME PAGE CONTENT
  // ==========================================
  Widget _buildHomeContent(Color pesoGreen) {
    return Column(
      children: [
        _buildHeroSection(pesoGreen),
        _buildHowItWorks(pesoGreen),
        _buildAboutSection(pesoGreen),
        _buildWhyChooseUs(pesoGreen),
        _buildPesoPrograms(pesoGreen),
        _buildDevelopers(pesoGreen),
      ],
    );
  }

  Widget _buildHeroSection(Color pesoGreen) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 600),
      decoration: const BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1573164713988-8665fc963095?ixlib=rb-4.0.3&auto=format&fit=crop&w=1920&q=80',
          ),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              pesoGreen.withValues(alpha: 0.7),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'AI-Driven Job Matching System',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Bridging Talent and Opportunity\nin Montalban.',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            const SizedBox(
              width: 800,
              child: Text(
                'Experience a modern career bridge. JobKonek uses AI to dynamically assess your skills, route you to pre-vetted local job queues, or generate custom TESDA upskilling plans if you fall short. Completely free for Montalban residents.',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _activePageIndex = 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: pesoGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 22,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Browse Offline Jobs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 20),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthPage(initialIsLogin: false),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 22,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Register Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks(Color pesoGreen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
      color: Colors.white,
      child: Column(
        children: [
          const Text(
            'How JobKonek Works',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'No manual waiting. Just AI-powered matching and direct PESO routing.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 70),
          Wrap(
            spacing: 30,
            runSpacing: 40,
            alignment: WrapAlignment.center,
            children: [
              _buildStepCard(
                '01',
                'Inclusive Profiling',
                'Build your digital identity. Upload a PDF resume or write a bilingual bio (Tagalog/English) so our AI can extract your core soft and technical skills.',
                Icons.person_add_alt_1,
                pesoGreen,
              ),
              _buildStepCard(
                '02',
                'Dynamic AI Exam',
                'Select a job to trigger a custom, non-repeating assessment. The AI merges your profile with the job description to test your exact knowledge gaps.',
                Icons.psychology,
                Colors.blue[700]!,
              ),
              _buildStepCard(
                '03',
                'Smart Routing',
                'Score 50% or higher to be pre-vetted for DOLE SPRS extraction. Fall short? Get an instant AI action plan with alternative jobs and TESDA recommendations.',
                Icons.alt_route,
                Colors.orange[700]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(
    String stepNum,
    String title,
    String desc,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
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
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, size: 35, color: color),
              ),
              Text(
                stepNum,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade200,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Text(
            desc,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(Color pesoGreen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1522071820081-009f0129c71c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                  ),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About JobKonek',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: pesoGreen,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Eliminating Manual Bottlenecks for Montalban.',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  'JobKonek is an advanced digital initiative designed specifically for the Montalban PESO office. Recognizing that employers already use DOLE\'s PhilJobNet, our system acts strictly as an AI-driven pre-screening bridge for local residents.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'By taking offline Excel job postings and returning DOLE SPRS-formatted pre-vetted passers, we optimize the municipality\'s workflow while guiding jobseekers toward success or targeted upskilling.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseUs(Color pesoGreen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
      color: Colors.white,
      width: double.infinity,
      child: Column(
        children: [
          const Text(
            'The JobKonek Advantage',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 50,
            runSpacing: 50,
            alignment: WrapAlignment.center,
            children: [
              _buildFeature(
                Icons.memory,
                'Generative AI Exams',
                'Say goodbye to static quizzes. Our LLM API generates custom technical and general knowledge questions on the fly.',
              ),
              _buildFeature(
                Icons.school,
                'Actionable Upskilling',
                'Failing an exam isn\'t a dead end. Receive instant alternative job matches and local TESDA center course recommendations.',
              ),
              _buildFeature(
                Icons.insert_chart_outlined,
                'DOLE SPRS Compliant',
                'Your success data is automatically batched, formatted, and emailed to the PESO Admins to integrate perfectly with regional standards.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 25),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.5,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPesoPrograms(Color pesoGreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
      decoration: BoxDecoration(
        color: pesoGreen,
        image: DecorationImage(
          image: const NetworkImage(
            'https://images.unsplash.com/photo-1552664730-d307ca884978?ixlib=rb-4.0.3&auto=format&fit=crop&w=1920&q=80',
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            pesoGreen.withValues(alpha: 0.9),
            BlendMode.srcOver,
          ),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'PESO Core Programs Support',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Your digital portal for national employment assistance initiatives.',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 30,
            runSpacing: 30,
            alignment: WrapAlignment.center,
            children: [
              _buildProgramCard(
                'SPES',
                'Special Program for Employment of Students',
              ),
              _buildProgramCard(
                'TUPAD',
                'Tulong Panghanapbuhay sa Ating Disadvantaged Workers',
              ),
              _buildProgramCard(
                'RA 11261',
                'First Time Jobseekers Assistance Verification',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(String title, String desc) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevelopers(Color pesoGreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          const Text(
            'Project Developer',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 60),
          Container(
            width: 450,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: pesoGreen, width: 3),
                  ),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    backgroundImage: NetworkImage(
                      'https://via.placeholder.com/150',
                    ), // Placeholder for developer photo
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Josh Lander Ferrea',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'Lead Developer & IT Student',
                  style: TextStyle(
                    color: pesoGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Developed as a Capstone project for Colegio de Montalban. Engineered using Flutter for cross-platform UI, integrating NoSQL logic and Google Gemini APIs for dynamic AI assessments.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.6, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: JOBS PAGE CONTENT
  // ==========================================
  Widget _buildJobsContent(Color pesoGreen) {
    return Column(
      children: [
        _buildSearchAndFilters(pesoGreen),
        _buildRecommendedJobs(pesoGreen),
      ],
    );
  }

  Widget _buildSearchAndFilters(Color pesoGreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 80),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore PESO Offline Listings',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'These jobs were bulk-uploaded by the PESO Admin. Login to take the AI exam and apply.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 40),
          Container(
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search roles in Montalban...',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      contentPadding: EdgeInsets.symmetric(vertical: 22),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pesoGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Search AI Matches',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFiltersDrawer(Color pesoGreen) {
    return Drawer(
      width: 400,
      backgroundColor: Colors.white,
      child: const Center(child: Text('Filters UI')), // Placeholder
    );
  }

  Widget _buildRecommendedJobs(Color pesoGreen) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Ingested Roles',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 25,
            runSpacing: 25,
            children: [
              _buildRoleCard(
                'IT Support Intern',
                'Montalban LGU',
                ['Entry', 'Internship', 'Rosario'],
                '₱10,000 - ₱12,000',
                pesoGreen,
              ),
              _buildRoleCard(
                'Software QA Tester',
                'OmniCore',
                ['Associate', 'Full-Time', 'San Jose'],
                '₱20,000 - ₱25,000',
                pesoGreen,
              ),
              _buildRoleCard(
                'Data Encoder',
                'Prime BPO',
                ['Entry', 'Part-Time', 'San Mateo'],
                '₱15,000 - ₱18,000',
                pesoGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    String title,
    String company,
    List<String> tags,
    String salary,
    Color pesoGreen,
  ) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            company,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 25),
          const Divider(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                salary,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: pesoGreen,
                  fontSize: 18,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AuthPage(initialIsLogin: true),
                  ),
                ),
                icon: const Icon(Icons.psychology, size: 18),
                label: const Text('Login to Take Exam'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pesoGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    return Container(
      height: 600,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'Page Under Construction',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// EXPORTED COMPONENT 1: GLOBAL NAV BAR
// =====================================================================
class GlobalNavBar extends StatelessWidget implements PreferredSizeWidget {
  final Color pesoGreen;
  final int activePageIndex;
  final Function(int) onTabSelected;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onLoginTap;

  const GlobalNavBar({
    super.key,
    required this.pesoGreen,
    required this.activePageIndex,
    required this.onTabSelected,
    this.onRegisterTap,
    this.onLoginTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(90);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          child: Row(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pesoGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.work, color: pesoGreen, size: 28),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    'JobKonek',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: pesoGreen,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _buildNavLink('Home', 0),
                  _buildNavLink('Jobs', 1),
                  _buildNavLink('Gallery', 2),
                  _buildNavLink('History', 3),
                  _buildNavLink('About', 4),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  OutlinedButton(
                    onPressed:
                        onRegisterTap ??
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AuthPage(initialIsLogin: false),
                          ),
                        ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 18,
                      ),
                    ),
                    child: const Text(
                      'Register',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    onPressed:
                        onLoginTap ??
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AuthPage(initialIsLogin: true),
                          ),
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pesoGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 18,
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildNavLink(String title, int index) {
    bool isActive = activePageIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: TextButton(
        onPressed: () => onTabSelected(index),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          backgroundColor: isActive
              ? pesoGreen.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? pesoGreen : Colors.black87,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// EXPORTED COMPONENT 2: GLOBAL FOOTER
// =====================================================================
class GlobalFooter extends StatelessWidget {
  final Color pesoGreen;
  final Function(int) onTabSelected;
  final VoidCallback onScrollToTop;

  const GlobalFooter({
    super.key,
    required this.pesoGreen,
    required this.onTabSelected,
    required this.onScrollToTop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.only(top: 80, left: 80, right: 80, bottom: 40),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.account_balance,
                            color: pesoGreen,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Text(
                            'Trabaho sa PESO\nBayan ng Montalban',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'An AI-Driven employment bridge built to integrate local residents with DOLE SPRS reporting.',
                      style: TextStyle(
                        color: Colors.white54,
                        height: 1.6,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 60),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Links',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildFooterLink('Home', 0),
                    _buildFooterLink('Offline Jobs', 1),
                    _buildFooterLink('Gallery', 2),
                    _buildFooterLink('About', 4),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Us',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildFooterContact(Icons.email, 'peso.rod@gmail.com'),
                    _buildFooterContact(Icons.phone, '+63 123 456 7890'),
                    _buildFooterContact(
                      Icons.location_on,
                      'Montalban, Rizal, Philippines',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          const Divider(color: Colors.white12),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '© 2026 Developed by Josh Lander Ferrea. All Rights Reserved.',
                style: TextStyle(color: Colors.white38),
              ),
              FloatingActionButton.small(
                onPressed: onScrollToTop,
                backgroundColor: pesoGreen,
                elevation: 0,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text, int targetIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: () => onTabSelected(targetIndex),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterContact(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
