import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Login_register_pages/auth_ui.dart';
import '../Reusable_Designs/reusable_ui.dart';
import '../Reusable_Designs/peso_images.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _jobSearchController = TextEditingController();

  int _activePageIndex = 0;
  String _selectedJobFilter = 'All roles';
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final isScrolled = _scrollController.offset > 24;
    if (isScrolled != _isScrolled && mounted) {
      setState(() => _isScrolled = isScrolled);
    }
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

  void _openJobSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _activePageIndex = 1);
    _scrollToTop();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _jobSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.white,
      appBar: AdaptiveNavBar(
        activeIndex: _activePageIndex,
        isScrolled: _isScrolled,
        onTabSelected: (index) {
          setState(() => _activePageIndex = index);
          _scrollToTop();
        },
        onRegisterTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AuthPage(initialIsLogin: false),
          ),
        ),
        onLoginTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AuthPage(initialIsLogin: true),
          ),
        ),
        showAuthActions: true,
      ),
      bottomNavigationBar: isMobile
          ? MobileBottomNavBar(
              activeIndex: _activePageIndex,
              onTabSelected: (index) {
                setState(() => _activePageIndex = index);
                _scrollToTop();
              },
            )
          : null,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: Container(
                key: ValueKey<int>(_activePageIndex),
                child: _buildActiveContent(),
              ),
            ),
            GlobalFooter(
              pesoGreen: PesoTokens.brandGreen,
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

  Widget _buildActiveContent() {
    switch (_activePageIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildDedicatedJobsPage();
      case 2:
        return _buildGalleryPage();
      case 3:
        return _buildHistoryPage();
      case 4:
        return _buildDedicatedAboutPage();
      default:
        return _buildHomeContent();
    }
  }

  // ==========================================
  // TAB 0: HOME PAGE
  // ==========================================
  Widget _buildHomeContent() {
    return Column(
      children: [
        _ScrollReveal(
          scrollController: _scrollController,
          child: HeroSection(
            onPrimaryTap: () {
              setState(() => _activePageIndex = 1);
              _scrollToTop();
            },
            onSecondaryTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuthPage(initialIsLogin: false),
              ),
            ),
          ),
        ),
        _ScrollReveal(
          scrollController: _scrollController,
          child: _buildHowItWorks(),
        ),
        _homeSectionBridge(Colors.white, PesoTokens.surfaceNeutral),
        _ScrollReveal(
          scrollController: _scrollController,
          child: _buildSearchAndFilters(isDedicated: false),
        ),
        _ScrollReveal(
          scrollController: _scrollController,
          child: _buildRecommendedJobs(),
        ),
        _homeSectionBridge(PesoTokens.surfaceNeutral, PesoTokens.brandGreen),
        _ScrollReveal(
          key: const ValueKey<String>('home-programs-scroll-reveal'),
          scrollController: _scrollController,
          child: _buildPesoPrograms(),
        ),
      ],
    );
  }

  // A shared, subtle color bridge makes the home page read as a continuous
  // journey rather than unrelated full-bleed sections.
  Widget _homeSectionBridge(Color from, Color to) {
    final compact =
        MediaQuery.sizeOf(context).width < PesoTokens.breakpointCompact;
    return Container(
      width: double.infinity,
      height: compact ? 28 : 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [from, to],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: DEDICATED JOBS PAGE
  // ==========================================
  Widget _buildDedicatedJobsPage() {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;
    final searchQuery = _jobSearchController.text.trim().toLowerCase();
    final visibleJobs = _landingJobs.where((job) {
      final matchesSearch =
          searchQuery.isEmpty ||
          <String>[
            job.title,
            job.company,
            job.location,
            job.type,
            ...job.tags,
          ].any((value) => value.toLowerCase().contains(searchQuery));
      final matchesFilter =
          _selectedJobFilter == 'All roles' ||
          (_selectedJobFilter == 'Entry level'
              ? job.tags.contains('Entry Level')
              : job.type == _selectedJobFilter);
      return matchesSearch && matchesFilter;
    }).toList();

    return Container(
      color: PesoTokens.surfaceNeutral,
      padding: EdgeInsets.fromLTRB(
        isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
        isMobile ? PesoTokens.spacingLG : PesoTokens.spacing3XL,
        isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
        PesoTokens.spacing3XL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedEntrance(delay: 0, child: _buildJobsIntro(isMobile)),
                const SizedBox(height: PesoTokens.spacingLG),
                AnimatedEntrance(
                  delay: 100,
                  child: _buildJobsSearchAndFilters(isMobile),
                ),
                const SizedBox(height: PesoTokens.spacing3XL),
                AnimatedEntrance(
                  delay: 180,
                  child: _buildJobsResults(visibleJobs, isMobile),
                ),
                const SizedBox(height: PesoTokens.spacing3XL),
                AnimatedEntrance(
                  delay: 260,
                  child: _buildJobsCallToAction(isMobile),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsIntro(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(
        isMobile ? PesoTokens.spacingLG : PesoTokens.spacing3XL,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PesoTokens.brandGreenDark, PesoTokens.brandGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
        boxShadow: PesoTokens.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PesoTokens.spacingMD,
              vertical: PesoTokens.spacingSM,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(PesoTokens.radiusFull),
            ),
            child: Text(
              'PESO MONTALBAN JOB BOARD',
              style: PesoTokens.labelSmall.copyWith(
                color: Colors.white,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: PesoTokens.spacingLG),
          Text(
            'Find work that moves you forward.',
            style: PesoTokens.displaySmall.copyWith(
              color: Colors.white,
              fontSize: isMobile ? 32 : 42,
              height: 1.12,
            ),
          ),
          const SizedBox(height: PesoTokens.spacingSM),
          Text(
            'Explore local opportunities, compare the details, and sign in to check your fit and apply.',
            style: PesoTokens.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsSearchAndFilters(bool isMobile) {
    const filters = <String>[
      'All roles',
      'Entry level',
      'Full-Time',
      'Part-Time',
      'Internship',
      'Contract',
    ];

    return Container(
      padding: EdgeInsets.all(
        isMobile ? PesoTokens.spacingMD : PesoTokens.spacingLG,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
        border: Border.all(color: const Color(0xFFDCE5E0)),
        boxShadow: PesoTokens.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _jobSearchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by role, organization, or location',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _jobSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _jobSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: PesoTokens.surfaceNeutral,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PesoTokens.radiusInput),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: PesoTokens.spacingMD,
                vertical: PesoTokens.spacingMD,
              ),
            ),
          ),
          const SizedBox(height: PesoTokens.spacingMD),
          Wrap(
            spacing: PesoTokens.spacingSM,
            runSpacing: PesoTokens.spacingSM,
            children: filters.map((filter) {
              final selected = _selectedJobFilter == filter;
              return ChoiceChip(
                label: Text(filter),
                selected: selected,
                onSelected: (_) => setState(() => _selectedJobFilter = filter),
                selectedColor: PesoTokens.brandGreenLight,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? PesoTokens.brandGreen.withValues(alpha: 0.45)
                      : const Color(0xFFDCE5E0),
                ),
                labelStyle: PesoTokens.labelMedium.copyWith(
                  color: selected
                      ? PesoTokens.brandGreenDark
                      : PesoTokens.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PesoTokens.radiusFull),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsResults(List<_LandingJob> jobs, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open opportunities',
                    style: PesoTokens.headlineLarge.copyWith(
                      fontSize: isMobile ? 25 : 32,
                    ),
                  ),
                  const SizedBox(height: PesoTokens.spacingXS),
                  Text(
                    '${jobs.length} ${jobs.length == 1 ? 'role' : 'roles'} to explore',
                    style: PesoTokens.bodyMedium.copyWith(
                      color: PesoTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.tune_rounded,
              color: PesoTokens.brandGreen,
              size: 24,
            ),
          ],
        ),
        const SizedBox(height: PesoTokens.spacingLG),
        if (jobs.isEmpty)
          _buildJobsEmptyState()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 1000
                  ? (constraints.maxWidth - PesoTokens.spacingLG * 2) / 3
                  : constraints.maxWidth >= 650
                  ? (constraints.maxWidth - PesoTokens.spacingLG) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: PesoTokens.spacingLG,
                runSpacing: PesoTokens.spacingLG,
                children: jobs
                    .map(
                      (job) => SizedBox(
                        width: cardWidth,
                        child: _LandingJobCard(
                          job: job,
                          onApply: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AuthPage(initialIsLogin: true),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildJobsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PesoTokens.spacing3XL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
        border: Border.all(color: const Color(0xFFDCE5E0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 38,
            color: PesoTokens.textMuted,
          ),
          const SizedBox(height: PesoTokens.spacingMD),
          Text('No roles match your search', style: PesoTokens.headlineSmall),
          const SizedBox(height: PesoTokens.spacingSM),
          Text(
            'Try another keyword or choose a different role type.',
            textAlign: TextAlign.center,
            style: PesoTokens.bodyMedium.copyWith(color: PesoTokens.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsCallToAction(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(
        isMobile ? PesoTokens.spacingLG : PesoTokens.spacing2XL,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
        border: Border.all(color: PesoTokens.brandGreenLight),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _jobsCallToActionCopy(),
                const SizedBox(height: PesoTokens.spacingLG),
                _jobsSignInButton(),
                const SizedBox(height: PesoTokens.spacingSM),
                _jobsRegisterButton(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _jobsCallToActionCopy()),
                const SizedBox(width: PesoTokens.spacingLG),
                _jobsSignInButton(),
                const SizedBox(width: PesoTokens.spacingSM),
                _jobsRegisterButton(),
              ],
            ),
    );
  }

  Widget _jobsCallToActionCopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ready for your next step?', style: PesoTokens.headlineSmall),
        const SizedBox(height: PesoTokens.spacingXS),
        Text(
          'Sign in to review your qualifications and continue with an application.',
          style: PesoTokens.bodySmall.copyWith(color: PesoTokens.textMuted),
        ),
      ],
    );
  }

  Widget _jobsSignInButton() {
    return OutlinedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage(initialIsLogin: true)),
      ),
      child: const Text('Sign in'),
    );
  }

  Widget _jobsRegisterButton() {
    return FilledButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthPage(initialIsLogin: false),
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: PesoTokens.brandGreen,
        foregroundColor: Colors.white,
      ),
      child: const Text('Create account'),
    );
  }

  // ==========================================
  // TAB 2: GALLERY PAGE
  // ==========================================
  Widget _buildGalleryPage() {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;
    final List<String> images = PesoImageAssets.gallery;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: isMobile ? PesoTokens.spacing3XL : PesoTokens.spacing4XL,
        bottom: PesoTokens.spacing3XL,
        left: isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
        right: isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedEntrance(
            delay: 0,
            child: Text(
              'PESO Montalban in Action',
              style: PesoTokens.displayMedium.copyWith(
                fontSize: isMobile ? 36 : 48,
              ),
            ),
          ),
          const SizedBox(height: PesoTokens.spacingSM),
          AnimatedEntrance(
            delay: 100,
            child: Text(
              'A glimpse into our job fairs, training seminars, and community outreach programs.',
              style: PesoTokens.bodyLarge.copyWith(color: PesoTokens.textMuted),
            ),
          ),
          const SizedBox(height: PesoTokens.spacing2XL),
          Wrap(
            spacing: PesoTokens.spacingLG,
            runSpacing: PesoTokens.spacingLG,
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

  Widget _buildGalleryImageCard(String imagePath) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;

    return Container(
      width: isMobile ? width - 32 : 400,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
        boxShadow: PesoTokens.shadowMD,
        image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
      ),
    );
  }

  // ==========================================
  // TAB 3: HISTORY PAGE
  // ==========================================
  Widget _buildHistoryPage() {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;

    return Container(
      color: PesoTokens.surfaceNeutral,
      padding: EdgeInsets.fromLTRB(
        isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
        isMobile ? PesoTokens.spacingLG : PesoTokens.spacing3XL,
        isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
        PesoTokens.spacing3XL,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedEntrance(delay: 0, child: _buildHistoryIntro(isMobile)),
              const SizedBox(height: PesoTokens.spacing3XL),
              AnimatedEntrance(
                delay: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milestones along the way',
                      style: PesoTokens.headlineLarge.copyWith(
                        fontSize: isMobile ? 26 : 34,
                      ),
                    ),
                    const SizedBox(height: PesoTokens.spacingSM),
                    Text(
                      'A look at how local employment support has grown and where it is headed.',
                      style: PesoTokens.bodyMedium.copyWith(
                        color: PesoTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: PesoTokens.spacingLG),
                    for (
                      var index = 0;
                      index < _historyMilestones.length;
                      index++
                    )
                      _HistoryMilestone(
                        milestone: _historyMilestones[index],
                        isLast: index == _historyMilestones.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: PesoTokens.spacingLG),
              AnimatedEntrance(
                delay: 200,
                child: _buildHistoryClosing(isMobile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryIntro(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(
        isMobile ? PesoTokens.spacingLG : PesoTokens.spacing3XL,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
        border: Border.all(color: PesoTokens.brandGreenLight),
        boxShadow: PesoTokens.shadowSM,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _historyIntroIcon(),
                const SizedBox(height: PesoTokens.spacingLG),
                _historyIntroCopy(isMobile),
              ],
            )
          : Row(
              children: [
                _historyIntroIcon(),
                const SizedBox(width: PesoTokens.spacing2XL),
                Expanded(child: _historyIntroCopy(isMobile)),
              ],
            ),
    );
  }

  Widget _historyIntroIcon() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: PesoTokens.brandGreenPale,
        borderRadius: BorderRadius.circular(PesoTokens.radiusLG),
      ),
      child: const Icon(
        Icons.account_balance_rounded,
        size: 42,
        color: PesoTokens.brandGreen,
      ),
    );
  }

  Widget _historyIntroCopy(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OUR STORY',
          style: PesoTokens.labelMedium.copyWith(
            color: PesoTokens.brandGreen,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: PesoTokens.spacingSM),
        Text(
          'A bridge to opportunity.',
          style: PesoTokens.displaySmall.copyWith(
            fontSize: isMobile ? 31 : 40,
            height: 1.1,
          ),
        ),
        const SizedBox(height: PesoTokens.spacingSM),
        Text(
          'Tracing the milestones of PESO Montalban and its continuing work to connect residents with employment support.',
          style: PesoTokens.bodyLarge.copyWith(color: PesoTokens.textMuted),
        ),
      ],
    );
  }

  Widget _buildHistoryClosing(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(
        isMobile ? PesoTokens.spacingLG : PesoTokens.spacing2XL,
      ),
      decoration: BoxDecoration(
        color: PesoTokens.brandGreenDark,
        borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _historyClosingCopy(),
                const SizedBox(height: PesoTokens.spacingLG),
                _historyJobsButton(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _historyClosingCopy()),
                const SizedBox(width: PesoTokens.spacingLG),
                _historyJobsButton(),
              ],
            ),
    );
  }

  Widget _historyClosingCopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The work continues.',
          style: PesoTokens.headlineMedium.copyWith(color: Colors.white),
        ),
        const SizedBox(height: PesoTokens.spacingSM),
        Text(
          'Explore current opportunities and take your next step with PESO Montalban.',
          style: PesoTokens.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }

  Widget _historyJobsButton() {
    return FilledButton.icon(
      onPressed: () {
        setState(() => _activePageIndex = 1);
        _scrollToTop();
      },
      icon: const Icon(Icons.work_outline_rounded),
      label: const Text('Explore jobs'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: PesoTokens.brandGreenDark,
      ),
    );
  }

  // ==========================================
  // TAB 4: DEDICATED ABOUT PAGE
  // ==========================================
  Widget _buildDedicatedAboutPage() {
    return Column(
      children: [
        AnimatedEntrance(delay: 0, child: _buildAboutSection()),
        AnimatedEntrance(delay: 200, child: _buildWhyChooseUs()),
        AnimatedEntrance(delay: 400, child: _buildDevelopers()),
      ],
    );
  }

  // ==========================================
  // SHARED SECTIONS
  // ==========================================

  Widget _buildHowItWorks() {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? PesoTokens.spacing2XL : PesoTokens.spacing4XL,
        horizontal: isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
      ),
      color: Colors.white,
      child: Column(
        children: [
          Text('How JobKonek Works', style: PesoTokens.headlineLarge),
          const SizedBox(height: PesoTokens.spacingSM),
          Text(
            'No manual waiting. Just AI skill matching and direct PESO routing.',
            style: PesoTokens.bodyLarge.copyWith(color: PesoTokens.textMuted),
          ),
          const SizedBox(height: PesoTokens.spacing2XL),
          Wrap(
            spacing: PesoTokens.spacingLG,
            runSpacing: PesoTokens.spacingLG,
            alignment: WrapAlignment.center,
            children: [
              FeatureCard(
                number: 1,
                title: 'Inclusive Profiling',
                description: 'Build your digital identity. Upload a PDF resume or write a bilingual bio (Tagalog/English) so our AI can extract your soft and technical skills.',
                icon: Icons.person_add_alt_1_rounded,
                accentColor: PesoTokens.brandGreen,
              ),
              FeatureCard(
                number: 2,
                title: 'AI Skill Vetting',
                description: 'Select a target job to trigger an instant AI qualification check. The system analyzes your resume skills against employer requirements to measure job fit.',
                icon: Icons.auto_awesome_rounded,
                accentColor: PesoTokens.infoBlue,
              ),
              FeatureCard(
                number: 3,
                title: 'Smart Routing',
                description: 'Fully qualified candidates are pre-vetted for DOLE SPRS extraction. Need upskilling? Get alternative job matches and TESDA course recommendations.',
                icon: Icons.alt_route_rounded,
                accentColor: PesoTokens.warningAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters({bool isDedicated = false}) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isDedicated ? PesoTokens.spacing3XL : PesoTokens.spacing2XL,
        horizontal: isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
      ),
      color: PesoTokens.surfaceNeutral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDedicated ? 'Live Job Board' : 'Featured PESO Listings',
            style: PesoTokens.headlineLarge.copyWith(
              fontSize: isMobile ? 32 : 48,
            ),
          ),
          const SizedBox(height: PesoTokens.spacingSM),
          Text(
            'These jobs were bulk-uploaded by the PESO Admin. Login to check your skill qualification and apply.',
            style: PesoTokens.bodyMedium.copyWith(color: PesoTokens.textMuted),
          ),
          const SizedBox(height: PesoTokens.spacingLG),
          Container(
            padding: isMobile
                ? const EdgeInsets.all(PesoTokens.spacingSM)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
              border: Border.all(color: PesoTokens.brandGreenLight),
              boxShadow: PesoTokens.shadowSM,
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _jobSearchController,
                        onSubmitted: (_) => _openJobSearch(),
                        decoration: InputDecoration(
                          hintText: 'Search roles in Montalban...',
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: PesoTokens.textMuted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: PesoTokens.spacingMD,
                          ),
                        ),
                      ),
                      const SizedBox(height: PesoTokens.spacingSM),
                      FilledButton(
                        onPressed: _openJobSearch,
                        style: FilledButton.styleFrom(
                          backgroundColor: PesoTokens.brandGreen,
                          foregroundColor: PesoTokens.textOnGreen,
                          padding: const EdgeInsets.symmetric(
                            vertical: PesoTokens.spacingMD,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PesoTokens.radiusButton,
                            ),
                          ),
                        ),
                        child: Text(
                          'Search jobs',
                          style: PesoTokens.buttonMedium,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _jobSearchController,
                          onSubmitted: (_) => _openJobSearch(),
                          decoration: InputDecoration(
                            hintText: 'Search roles in Montalban...',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: PesoTokens.textMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: PesoTokens.spacingLG,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(PesoTokens.spacingSM),
                        child: FilledButton(
                          onPressed: _openJobSearch,
                          style: FilledButton.styleFrom(
                            backgroundColor: PesoTokens.brandGreen,
                            foregroundColor: PesoTokens.textOnGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: PesoTokens.spacingLG,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PesoTokens.radiusButton,
                              ),
                            ),
                          ),
                          child: Text(
                            'Search jobs',
                            style: PesoTokens.buttonMedium,
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

  Widget _buildRecommendedJobs() {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;

    return Container(
      color: PesoTokens.surfaceNeutral,
      padding: EdgeInsets.only(
        bottom: PesoTokens.spacing3XL,
        left: isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
        right: isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
      ),
      width: double.infinity,
      child: Wrap(
        spacing: PesoTokens.spacingLG,
        runSpacing: PesoTokens.spacingLG,
        alignment: WrapAlignment.start,
        children: [
          JobCard(
            title: 'IT Support Intern',
            company: 'Montalban LGU',
            location: 'Rosario, Montalban',
            salary: '₱10,000 - ₱12,000',
            type: 'Internship',
            tags: ['Entry Level', 'Internship', 'On-site'],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuthPage(initialIsLogin: true),
              ),
            ),
          ),
          JobCard(
            title: 'Software QA Tester',
            company: 'OmniCore',
            location: 'San Jose, Montalban',
            salary: '₱20,000 - ₱25,000',
            type: 'Full-Time',
            tags: ['Associate', 'Full-Time', 'Hybrid'],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuthPage(initialIsLogin: true),
              ),
            ),
          ),
          JobCard(
            title: 'Data Encoder',
            company: 'Prime BPO',
            location: 'San Mateo, Rizal',
            salary: '₱15,000 - ₱18,000',
            type: 'Part-Time',
            tags: ['Entry Level', 'Part-Time', 'On-site'],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuthPage(initialIsLogin: true),
              ),
            ),
          ),
          JobCard(
            title: 'Administrative Assistant',
            company: 'Local Government',
            location: 'Montalban, Rizal',
            salary: '₱12,000 - ₱15,000',
            type: 'Full-Time',
            tags: ['Entry Level', 'Full-Time', 'On-site'],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuthPage(initialIsLogin: true),
              ),
            ),
          ),
          JobCard(
            title: 'Network Technician',
            company: 'TechNova',
            location: 'Rodriguez, Rizal',
            salary: '₱25,000 - ₱30,000',
            type: 'Contract',
            tags: ['Mid Level', 'Contract', 'On-site'],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuthPage(initialIsLogin: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: PesoTokens.spacing4XL,
        horizontal: isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: isMobile ? 250 : 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
                image: const DecorationImage(
                  image: AssetImage(PesoImageAssets.aboutBanner),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          if (!isMobile) const SizedBox(width: PesoTokens.spacing3XL),
          if (isMobile) const SizedBox(height: PesoTokens.spacing2XL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About JobKonek',
                  style: PesoTokens.labelLarge.copyWith(
                    color: PesoTokens.brandGreen,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: PesoTokens.spacingLG),
                Text(
                  'Eliminating Manual Bottlenecks for Montalban.',
                  style: PesoTokens.displayMedium.copyWith(
                    fontSize: isMobile ? 36 : 48,
                  ),
                ),
                const SizedBox(height: PesoTokens.spacingLG),
                Text(
                  'JobKonek is an advanced digital initiative designed specifically for the Montalban PESO office. Recognizing that employers already use DOLE\'s PhilJobNet, our system acts strictly as an AI-driven skill pre-screening bridge for local residents.',
                  style: PesoTokens.bodyLarge.copyWith(
                    color: PesoTokens.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: PesoTokens.spacingMD),
                Text(
                  'By taking offline Excel job postings and returning DOLE SPRS-formatted pre-vetted candidates, we optimize municipal placement while guiding jobseekers toward suitable roles or targeted upskilling.',
                  style: PesoTokens.bodyLarge.copyWith(
                    color: PesoTokens.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseUs() {
    return Container(
      padding: PesoTokens.horizontalPadding(context)
          .add(EdgeInsets.symmetric(vertical: PesoTokens.spacing4XL)),
      color: PesoTokens.surfaceNeutral,
      width: double.infinity,
      child: Column(
        children: [
          Text('The JobKonek Advantage', style: PesoTokens.headlineLarge),
          const SizedBox(height: PesoTokens.spacing2XL),
          Wrap(
            spacing: PesoTokens.spacing2XL,
            runSpacing: PesoTokens.spacing2XL,
            alignment: WrapAlignment.center,
            children: [
              FeatureCard(
                number: 1,
                title: 'AI Skill Matching Engine',
                description: 'Our intelligent AI engine automatically parses your profile and maps your technical skills directly against local job openings.',
                icon: Icons.memory_rounded,
                accentColor: PesoTokens.infoBlue,
              ),
              FeatureCard(
                number: 2,
                title: 'Actionable Upskilling',
                description: 'Missing key requirements isn\'t a dead end. Receive instant alternative job matches and local TESDA center course recommendations.',
                icon: Icons.school_rounded,
                accentColor: PesoTokens.warningAmber,
              ),
              FeatureCard(
                number: 3,
                title: 'DOLE SPRS Compliant',
                description: 'Your qualification data is automatically batched, formatted, and emailed to PESO Admins for seamless regional reporting.',
                icon: Icons.insert_chart_outlined_rounded,
                accentColor: PesoTokens.brandGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPesoPrograms() {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < PesoTokens.breakpointCompact;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PesoTokens.surfaceDark,
        image: const DecorationImage(
          image: AssetImage(PesoImageAssets.programsBanner),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: PesoTokens.brandGreen.withValues(alpha: 0.9),
        padding: EdgeInsets.symmetric(
          vertical: PesoTokens.spacing4XL,
          horizontal: isMobile ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
        ),
        child: Column(
          children: [
            Text(
              'PESO Core Programs Support',
              style: PesoTokens.headlineLarge.copyWith(color: Colors.white),
            ),
            const SizedBox(height: PesoTokens.spacingSM),
            Text(
              'Your digital portal for national employment assistance initiatives.',
              style: PesoTokens.bodyLarge.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: PesoTokens.spacing2XL),
            Wrap(
              spacing: PesoTokens.spacingLG,
              runSpacing: PesoTokens.spacingLG,
              alignment: WrapAlignment.center,
              children: [
                ProgramCard(
                  title: 'SPES',
                  description: 'Special Program for Employment of Students',
                  icon: Icons.school_rounded,
                  accentColor: Colors.amber,
                  stats: const [
                    ProgramStat(label: 'Students/Year', value: '500+'),
                    ProgramStat(label: 'LGU Partners', value: '12'),
                  ],
                  onTap: () => launchUrl(
                    Uri.parse('https://tesda.gov.ph'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ProgramCard(
                  title: 'TUPAD',
                  description:
                      'Tulong Panghanapbuhay sa Ating Disadvantaged Workers',
                  icon: Icons.work_history_rounded,
                  accentColor: Colors.lightBlue,
                  stats: const [
                    ProgramStat(label: 'Beneficiaries', value: '1,200+'),
                    ProgramStat(label: 'Barangays', value: '26'),
                  ],
                  onTap: () => launchUrl(
                    Uri.parse('https://dole.gov.ph'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ProgramCard(
                  title: 'RA 11261',
                  description: 'First Time Jobseekers Assistance Verification',
                  icon: Icons.verified_user_rounded,
                  accentColor: Colors.pinkAccent,
                  stats: const [
                    ProgramStat(label: 'Verified', value: '800+'),
                    ProgramStat(label: 'Fee Waivers', value: '100%'),
                  ],
                  onTap: () => launchUrl(
                    Uri.parse('https://www.tesda.gov.ph/ra-11261'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevelopers() {
    return Container(
      width: double.infinity,
      padding: PesoTokens.horizontalPadding(context)
          .add(EdgeInsets.symmetric(vertical: PesoTokens.spacing4XL)),
      color: Colors.white,
      child: Column(
        children: [
          Text('Project Developers', style: PesoTokens.headlineLarge),
          const SizedBox(height: PesoTokens.spacing2XL),
          Wrap(
            spacing: PesoTokens.spacingLG,
            runSpacing: PesoTokens.spacingLG,
            alignment: WrapAlignment.center,
            children: [
              _buildDeveloperCard(
                name: 'Josh Lander Ferrera',
                role: 'Lead Full Stack Engineer & Architect',
                description: 'The driving force behind the platform architecture, bridging backend logic, AI LLM integrations, and the Flutter web application.',
                imageAsset: 'lib/assets/josh.png',
              ),
              _buildDeveloperCard(
                name: 'Lovely Anne C. Ilaya',
                role: 'Full Stack & Lead UI/UX Designer',
                description: 'Creates intuitive design systems and accessible web interfaces while contributing to full-stack frontend development.',
              ),
              _buildDeveloperCard(
                name: 'Edward Marcelino',
                role: 'Full Stack Engineer (Core Functionalities)',
                description: 'Bridges frontend interfaces and backend databases, maintaining API routing and system stability.',
                imageAsset: 'lib/assets/edward.png',
              ),
              _buildDeveloperCard(
                name: 'John Paul Cesneros',
                role: 'Frontend Engineer & Documentation Lead',
                description: 'Drives frontend UI implementation and technical documentation for municipal system compliance.',
                imageAsset: 'lib/assets/cesneros.png',
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
    String? imageAsset,
  }) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Container(
      width: 350,
      padding: const EdgeInsets.all(PesoTokens.spacingLG),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
        boxShadow: PesoTokens.shadowMD,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: PesoTokens.brandGreen, width: 3),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: PesoTokens.surfaceNeutral,
              backgroundImage: imageAsset != null
                  ? AssetImage(imageAsset)
                  : null,
              child: imageAsset == null
                  ? Text(
                      initials,
                      style: PesoTokens.headlineMedium.copyWith(
                        fontSize: 30,
                        color: PesoTokens.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: PesoTokens.spacingLG),
          Text(
            name,
            textAlign: TextAlign.center,
            style: PesoTokens.headlineSmall.copyWith(fontSize: 22),
          ),
          const SizedBox(height: PesoTokens.space1),
          Text(
            role,
            textAlign: TextAlign.center,
            style: PesoTokens.labelLarge.copyWith(
              color: PesoTokens.brandGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PesoTokens.spacingLG),
          Text(
            description,
            textAlign: TextAlign.center,
            style: PesoTokens.bodyMedium.copyWith(
              color: PesoTokens.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

const List<_LandingJob> _landingJobs = [
  _LandingJob(
    title: 'IT Support Intern',
    company: 'Montalban LGU',
    location: 'Rosario, Montalban',
    salary: '₱10,000 - ₱12,000',
    type: 'Internship',
    tags: ['Entry Level', 'On-site'],
  ),
  _LandingJob(
    title: 'Software QA Tester',
    company: 'OmniCore',
    location: 'San Jose, Montalban',
    salary: '₱20,000 - ₱25,000',
    type: 'Full-Time',
    tags: ['Associate', 'Hybrid'],
  ),
  _LandingJob(
    title: 'Data Encoder',
    company: 'Prime BPO',
    location: 'San Mateo, Rizal',
    salary: '₱15,000 - ₱18,000',
    type: 'Part-Time',
    tags: ['Entry Level', 'On-site'],
  ),
  _LandingJob(
    title: 'Administrative Assistant',
    company: 'Local Government',
    location: 'Montalban, Rizal',
    salary: '₱12,000 - ₱15,000',
    type: 'Full-Time',
    tags: ['Entry Level', 'On-site'],
  ),
  _LandingJob(
    title: 'Network Technician',
    company: 'TechNova',
    location: 'Rodriguez, Rizal',
    salary: '₱25,000 - ₱30,000',
    type: 'Contract',
    tags: ['Mid Level', 'On-site'],
  ),
];

const List<_HistoryMilestoneData> _historyMilestones = [
  _HistoryMilestoneData(
    year: '2018',
    title: 'PESO Office Established',
    description: 'The local government officially launched the Public Employment Service Office to bridge employers and local residents.',
    icon: Icons.account_balance_rounded,
    color: PesoTokens.brandGreen,
  ),
  _HistoryMilestoneData(
    year: '2020',
    title: 'Pandemic Response Initiatives',
    description: 'Transitioned to online job boards and implemented TUPAD programs to assist displaced workers during lockdowns.',
    icon: Icons.diversity_1_rounded,
    color: PesoTokens.infoBlue,
  ),
  _HistoryMilestoneData(
    year: '2023',
    title: 'Record High Placements',
    description: 'Successfully placed over 5,000 Montalban residents in regular positions across Metro Manila and Rizal.',
    icon: Icons.trending_up_rounded,
    color: PesoTokens.warningAmber,
  ),
  _HistoryMilestoneData(
    year: '2026',
    title: 'JobKonek AI Launch',
    description: 'Revolutionized job placement by introducing Generative AI skill extraction and DOLE SPRS matching integration.',
    icon: Icons.auto_awesome_rounded,
    color: PesoTokens.brandGreen,
  ),
];

class _LandingJob {
  const _LandingJob({
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.type,
    required this.tags,
  });

  final String title;
  final String company;
  final String location;
  final String salary;
  final String type;
  final List<String> tags;
}

class _LandingJobCard extends StatelessWidget {
  const _LandingJobCard({required this.job, required this.onApply});

  final _LandingJob job;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PesoTokens.spacingLG),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
        border: Border.all(color: const Color(0xFFDCE5E0)),
        boxShadow: PesoTokens.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: PesoTokens.brandGreenPale,
                  borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: PesoTokens.brandGreen,
                ),
              ),
              const SizedBox(width: PesoTokens.spacingMD),
              Expanded(
                child: Text(
                  job.company,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PesoTokens.labelLarge.copyWith(
                    color: PesoTokens.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PesoTokens.spacingSM,
                  vertical: PesoTokens.space1,
                ),
                decoration: BoxDecoration(
                  color: PesoTokens.brandGreenPale,
                  borderRadius: BorderRadius.circular(PesoTokens.radiusFull),
                ),
                child: Text(
                  job.type,
                  style: PesoTokens.labelSmall.copyWith(
                    color: PesoTokens.brandGreenDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PesoTokens.spacingLG),
          Text(
            job.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PesoTokens.headlineSmall.copyWith(fontSize: 21),
          ),
          const SizedBox(height: PesoTokens.spacingSM),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 17,
                color: PesoTokens.textMuted,
              ),
              const SizedBox(width: PesoTokens.spacingXS),
              Expanded(
                child: Text(
                  job.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PesoTokens.bodySmall.copyWith(
                    color: PesoTokens.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PesoTokens.spacingLG),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(PesoTokens.spacingMD),
            decoration: BoxDecoration(
              color: PesoTokens.surfaceNeutral,
              borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SALARY',
                  style: PesoTokens.labelSmall.copyWith(
                    letterSpacing: 0.8,
                    color: PesoTokens.textMuted,
                  ),
                ),
                const SizedBox(height: PesoTokens.space1),
                Text(
                  job.salary,
                  style: PesoTokens.labelLarge.copyWith(
                    color: PesoTokens.brandGreenDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PesoTokens.spacingMD),
          Wrap(
            spacing: PesoTokens.spacingSM,
            runSpacing: PesoTokens.spacingSM,
            children: job.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PesoTokens.spacingSM,
                      vertical: PesoTokens.space1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        PesoTokens.radiusFull,
                      ),
                      border: Border.all(color: const Color(0xFFDCE5E0)),
                    ),
                    child: Text(tag, style: PesoTokens.labelSmall),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: PesoTokens.spacingMD),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View and apply'),
              style: TextButton.styleFrom(
                foregroundColor: PesoTokens.brandGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryMilestoneData {
  const _HistoryMilestoneData({
    required this.year,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String year;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class _HistoryMilestone extends StatelessWidget {
  const _HistoryMilestone({required this.milestone, required this.isLast});

  final _HistoryMilestoneData milestone;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(top: PesoTokens.spacingLG),
                  decoration: BoxDecoration(
                    color: milestone.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: milestone.color.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(
                        vertical: PesoTokens.spacingSM,
                      ),
                      color: const Color(0xFFDCE5E0),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: PesoTokens.spacingLG),
              padding: const EdgeInsets.all(PesoTokens.spacingLG),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
                border: Border.all(color: const Color(0xFFDCE5E0)),
                boxShadow: PesoTokens.shadowSM,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PesoTokens.spacingMD,
                          vertical: PesoTokens.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: milestone.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            PesoTokens.radiusFull,
                          ),
                        ),
                        child: Text(
                          milestone.year,
                          style: PesoTokens.labelLarge.copyWith(
                            color: milestone.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(milestone.icon, color: milestone.color, size: 21),
                    ],
                  ),
                  const SizedBox(height: PesoTokens.spacingMD),
                  Text(
                    milestone.title,
                    style: PesoTokens.headlineSmall.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: PesoTokens.spacingSM),
                  Text(
                    milestone.description,
                    style: PesoTokens.bodyMedium.copyWith(
                      color: PesoTokens.textSecondary,
                      height: 1.55,
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
}

class _ScrollReveal extends StatefulWidget {
  const _ScrollReveal({
    super.key,
    required this.child,
    required this.scrollController,
  });

  final Widget child;
  final ScrollController scrollController;

  @override
  State<_ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<_ScrollReveal>
    with SingleTickerProviderStateMixin {
  final GlobalKey _contentKey = GlobalKey();
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  bool _hasRevealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = animation;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(animation);
    // ScrollNotification bubbles upward, never to a descendant of the
    // Scrollable. Listen to the owning controller so sections that start below
    // the viewport are revealed when the user reaches them.
    widget.scrollController.addListener(_revealIfVisible);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealIfVisible());
  }

  @override
  void didUpdateWidget(covariant _ScrollReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController == widget.scrollController) return;
    oldWidget.scrollController.removeListener(_revealIfVisible);
    widget.scrollController.addListener(_revealIfVisible);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealIfVisible());
  }

  void _revealIfVisible() {
    if (_hasRevealed || !mounted) return;
    final renderObject = _contentKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (top < viewportHeight * 0.9 && bottom > 0) {
      _hasRevealed = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_revealIfVisible);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: KeyedSubtree(key: _contentKey, child: widget.child),
      ),
    );
  }
}
