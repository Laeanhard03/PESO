import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'auth_ui.dart';
import 'common_widgets_ui.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _activePageIndex = 0;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 50 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: GlobalNavBar(
        pesoGreen: pesoGreen,
        activePageIndex: _activePageIndex,
        isScrolled: _isScrolled,
        onTabSelected: (index) {
          setState(() => _activePageIndex = index);
          _scrollToTop();
        },
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
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
    switch (_activePageIndex) {
      case 0:
        return _buildHomeContent(pesoGreen);
      case 1:
        return _buildDedicatedJobsPage(pesoGreen);
      case 2:
        return _buildGalleryPage(pesoGreen);
      case 3:
        return _buildHistoryPage(pesoGreen);
      case 4:
        return _buildDedicatedAboutPage(pesoGreen);
      default:
        return _buildHomeContent(pesoGreen);
    }
  }

  // ==========================================
  // TAB 0: HOME PAGE (Unified View)
  // ==========================================
  Widget _buildHomeContent(Color pesoGreen) {
    return Column(
      children: [
        _buildHeroSection(pesoGreen),
        _buildHowItWorks(pesoGreen),
        _buildSearchAndFilters(pesoGreen, isDedicated: false),
        _buildRecommendedJobs(pesoGreen),
        _buildPesoPrograms(pesoGreen),
      ],
    );
  }

  // ==========================================
  // TAB 1: DEDICATED JOBS PAGE
  // ==========================================
  Widget _buildDedicatedJobsPage(Color pesoGreen) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.only(top: 90),
      child: Column(
        children: [
          AnimatedEntrance(
            delay: 0,
            child: _buildSearchAndFilters(pesoGreen, isDedicated: true),
          ),
          AnimatedEntrance(delay: 200, child: _buildRecommendedJobs(pesoGreen)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: GALLERY PAGE (Animated Grid)
  // ==========================================
  Widget _buildGalleryPage(Color pesoGreen) {
    final List<String> images = [
      'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1528605105345-5344ea20e269?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1556761175-4b46a572b786?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1517048676732-d65bc937f952?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(
        top: 150,
        bottom: 100,
        left: 80,
        right: 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnimatedEntrance(
            delay: 0,
            child: Text(
              'PESO Montalban in Action',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 15),
          AnimatedEntrance(
            delay: 100,
            child: Text(
              'A glimpse into our job fairs, training seminars, and community outreach programs.',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: List.generate(images.length, (index) {
              return AnimatedEntrance(
                delay: 200 + (index * 100),
                child: _buildGalleryImageCard(images[index]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryImageCard(String imageUrl) {
    return Container(
      width: 400,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        image: DecorationImage(
          image: CachedNetworkImageProvider(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          hoverColor: Colors.black.withValues(alpha: 0.2),
          onTap: () {},
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: HISTORY PAGE (Animated Timeline)
  // ==========================================
  Widget _buildHistoryPage(Color pesoGreen) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.only(top: 150, bottom: 100),
      child: Column(
        children: [
          const AnimatedEntrance(
            delay: 0,
            child: Text(
              'Our Journey',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 15),
          AnimatedEntrance(
            delay: 100,
            child: Text(
              'Tracing the milestones of PESO Montalban.',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 80),
          _buildTimelineNode(
            '2018',
            'PESO Office Established',
            'The local government officially launched the Public Employment Service Office to bridge employers and local residents.',
            pesoGreen,
            200,
          ),
          _buildTimelineNode(
            '2020',
            'Pandemic Response Initatives',
            'Transitioned to online job boards and implemented TUPAD programs to assist displaced workers during the lockdowns.',
            Colors.blue,
            300,
          ),
          _buildTimelineNode(
            '2023',
            'Record High Placements',
            'Successfully placed over 5,000 Montalban residents in regular positions across Metro Manila and Rizal.',
            Colors.orange,
            400,
          ),
          _buildTimelineNode(
            '2026',
            'JobKonek AI Launch',
            'Revolutionized the application process by introducing Generative AI screening and localized DOLE SPRS integration.',
            pesoGreen,
            500,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(
    String year,
    String title,
    String description,
    Color accentColor,
    int delayMs, {
    bool isLast = false,
  }) {
    return AnimatedEntrance(
      delay: delayMs,
      child: SizedBox(
        width: 800,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    year,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 4,
                    height: 120,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 40),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(35),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 4: DEDICATED ABOUT PAGE
  // ==========================================
  Widget _buildDedicatedAboutPage(Color pesoGreen) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 90),
      child: Column(
        children: [
          AnimatedEntrance(delay: 0, child: _buildAboutSection(pesoGreen)),
          AnimatedEntrance(delay: 200, child: _buildWhyChooseUs(pesoGreen)),
          AnimatedEntrance(delay: 400, child: _buildDevelopers(pesoGreen)),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED SECTIONS (Used across Home & Dedicated Pages)
  // ==========================================

  Widget _buildHeroSection(Color pesoGreen) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 800),
      decoration: const BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: CachedNetworkImageProvider(
            'https://images.unsplash.com/photo-1573164713988-8665fc963095?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
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
            const SizedBox(height: 50),
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
                  onPressed: () {
                    setState(() => _activePageIndex = 1);
                    _scrollToTop();
                  },
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
                    'Browse Job Board',
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
            blurRadius: 8,
            offset: const Offset(0, 4),
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

  Widget _buildSearchAndFilters(Color pesoGreen, {bool isDedicated = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isDedicated ? 80 : 60,
        horizontal: 80,
      ),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDedicated ? 'Live Job Board' : 'Featured PESO Listings',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'These jobs were bulk-uploaded by the PESO Admin. Login to take the AI exam and apply.',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
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
                  blurRadius: 8,
                  offset: const Offset(0, 4),
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

  Widget _buildRecommendedJobs(Color pesoGreen) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.only(bottom: 80, left: 80, right: 80),
      width: double.infinity,
      child: Wrap(
        spacing: 25,
        runSpacing: 25,
        alignment: WrapAlignment.start,
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
          _buildRoleCard(
            'Administrative Assistant',
            'Local Gov',
            ['Entry', 'Full-Time', 'Montalban'],
            '₱12,000 - ₱15,000',
            pesoGreen,
          ),
          _buildRoleCard(
            'Network Technician',
            'TechNova',
            ['Mid', 'Contract', 'Rodriguez'],
            '₱25,000 - ₱30,000',
            pesoGreen,
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
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
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

  Widget _buildAboutSection(Color pesoGreen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: CachedNetworkImageProvider(
                    'https://images.unsplash.com/photo-1522071820081-009f0129c71c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                  ),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
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
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.1,
                    letterSpacing: -1,
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
      color: Colors.grey.shade50,
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
      decoration: const BoxDecoration(
        color: Colors.black, // Fallback color
        image: DecorationImage(
          image: CachedNetworkImageProvider(
            'https://images.unsplash.com/photo-1552664730-d307ca884978?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: pesoGreen.withValues(
          alpha: 0.9,
        ), // Moved color filter overlay here
        padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
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
      color: Colors.white,
      child: Column(
        children: [
          const Text(
            'Project Developers',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 40,
            runSpacing: 40,
            alignment: WrapAlignment.center,
            children: [
              _buildDeveloperCard(
                name: 'Josh Lander Ferrera',
                role: 'Lead Full Stack Engineer & Architect',
                description: 'The all-around driving force behind the platform. Orchestrates the entire architecture, from bridging complex NoSQL backend logic and AI LLM integrations to building the seamless, cross-platform Flutter frontend.',
                imageUrl: 'https://upload.wikimedia.org/wikipedia/en/8/86/Einstein_tongue.jpg',
                pesoGreen: pesoGreen,
              ),
              _buildDeveloperCard(
                name: 'Lovely Anne C. Ilaya',
                role: 'Full Stack & Lead UI/UX Designer',
                description: 'Focuses heavily on creating an intuitive, modern, and accessible design system while actively contributing to full-stack development. Ensures the platform is as beautiful as it is functional.',
                imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/7/74/Jeon_Jung-kook_for_Dispatch_%22Boy_With_Luv%22_MV_behind_the_scene_shooting%2C_15_March_2019_04.jpg',
                pesoGreen: pesoGreen,
              ),
              _buildDeveloperCard(
                name: 'Edward Marcelino',
                role: 'Full Stack Engineer (Core Functionalities)',
                description: 'The balanced core of the development team. Bridges the gap between frontend interfaces and backend databases, focusing heavily on robust functionalities, API routing, and system stability.',
                imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d7/Henry_Cavill_by_Gage_Skidmore_2.jpg',
                pesoGreen: pesoGreen,
              ),
              _buildDeveloperCard(
                name: 'John Paul Cesneros',
                role: 'Frontend Engineer & Documentation Lead',
                description: 'Drives the frontend implementation and handles the crucial technical documentation (papers) of the system. Ensures all functionalities are well-documented, tested, and perfectly aligned.',
                imageUrl: 'https://i.kym-cdn.com/entries/icons/original/000/026/152/gigachad.jpg',
                pesoGreen: pesoGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard({
    required String name,
    required String role,
    required String description,
    required String imageUrl,
    required Color pesoGreen,
  }) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: CachedNetworkImageProvider(imageUrl),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            role,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: pesoGreen,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.6,
              color: Colors.grey.shade700,
              fontSize: 14,
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
      child: const Center(child: Text('Filters UI')),
    );
  }
}

// =====================================================================
// HELPER WIDGET: ANIMATED ENTRANCE
// Creates a smooth slide-up and fade-in effect for the dedicated pages.
// =====================================================================
class AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final int delay;

  const AnimatedEntrance({super.key, required this.child, required this.delay});

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
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
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
