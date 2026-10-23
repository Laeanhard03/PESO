import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Reusable_Designs/peso_images.dart';
import '../Reusable_Designs/peso_employer_branding.dart';
import '../../peso_models/job_posting.dart';
import '../../peso_logic/job_listing_localization.dart';
import 'notice_role_selector.dart';
import '../Reusable_Designs/responsive_layout.dart';
import '../Reusable_Designs/animated_entrance.dart';
import '../Reusable_Designs/peso_premium_ui.dart';

void _ignoreCategoryChange(String category) {}
Future<void> _openPublicPdfSource(String? value) async {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      !const {'montalban.gov.ph', 'dev.montalban.gov.ph'}.contains(uri.host)) {
    return;
  }
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Keep an unsupported or unavailable external browser from breaking the feed.
  }
}

class UserJobFeedTab extends StatelessWidget {
  final String userName;
  final List<Map<String, dynamic>> availableJobs;
  final bool jobsLoading;
  final String? jobLoadError;
  final VoidCallback? onRetryJobs;
  final bool hasMoreJobs;
  final bool loadingMoreJobs;
  final VoidCallback? onLoadMoreJobs;
  final List<String> interestLabels;
  final String preferredOccupation;
  final TextEditingController? searchController;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final String selectedLanguage;
  final Map<String, dynamic>? translatedJob;
  final bool translationLoading;
  final bool translationFailed;
  final VoidCallback? onRetryTranslation;
  final bool newRegistration;
  final Map<String, dynamic>? selectedJob;
  final Function(Map<String, dynamic>) onSelectJob;
  final ValueChanged<Map<String, dynamic>> onEvaluateJob;
  final List<Map<String, dynamic>> linkedRoles;
  final ValueChanged<List<Map<String, dynamic>>>? onCompareRoles;
  final String Function(String) translate;
  final Color primary;
  final Color textDark;
  final Color textLight;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final GlobalKey? detailsAnchor;

  const UserJobFeedTab({
    super.key,
    required this.userName,
    required this.availableJobs,
    this.jobsLoading = false,
    this.jobLoadError,
    this.onRetryJobs,
    this.hasMoreJobs = false,
    this.loadingMoreJobs = false,
    this.onLoadMoreJobs,
    this.interestLabels = const [],
    this.preferredOccupation = '',
    this.searchController,
    this.searchQuery = '',
    this.onSearchChanged,
    this.selectedLanguage = 'English',
    this.translatedJob,
    this.translationLoading = false,
    this.translationFailed = false,
    this.onRetryTranslation,
    this.newRegistration = false,
    required this.selectedJob,
    required this.onSelectJob,
    required this.onEvaluateJob,
    this.linkedRoles = const [],
    this.onCompareRoles,
    required this.translate,
    required this.primary,
    required this.textDark,
    required this.textLight,
    this.selectedCategory = PesoJobCategories.all,
    this.onCategoryChanged = _ignoreCategoryChange,
    this.detailsAnchor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < pesoCompactBreakpoint;
    final medium = screenWidth < pesoExpandedBreakpoint;
    final suggestedCount = availableJobs
        .where((job) => job['suggestedForInterest'] == true)
        .length;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : (medium ? 24 : 50)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: PesoPageHeader(
                  title: newRegistration
                      ? selectedLanguage == 'Tagalog'
                            ? 'Maligayang pagdating sa JobKonek, ${userName.split(" ")[0]}!'
                            : selectedLanguage == 'Taglish'
                            ? 'Welcome sa JobKonek, ${userName.split(" ")[0]}!'
                            : 'Welcome to JobKonek, ${userName.split(" ")[0]}!'
                      : translate('Welcome back, ${userName.split(" ")[0]}!'),
                  description: selectedLanguage == 'English'
                      ? 'Explore recommended opportunities and search every active PESO job, even if it is not an AI match.'
                      : 'Tingnan ang mga rekomendasyon at hanapin ang lahat ng aktibong trabahong available sa PESO.',
                  eyebrow: localizedJobHeading(
                    'Your career workspace',
                    selectedLanguage,
                  ),
                  icon: Icons.work_outline_rounded,
                  detail: Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      PesoHeaderPill(
                        icon: Icons.business_center_outlined,
                        label: '${availableJobs.length} available roles',
                      ),
                      PesoHeaderPill(
                        icon: Icons.tune_rounded,
                        label: selectedCategory == PesoJobCategories.all
                            ? localizedJobHeading(
                                'All categories',
                                selectedLanguage,
                              )
                            : localizedJobHeading(
                                'Filtered opportunities',
                                selectedLanguage,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (jobsLoading || jobLoadError != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const ValueKey('job-feed-service-status'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: jobsLoading
                          ? const Color(0xFFEAF5EF)
                          : const Color(0xFFFFF5E6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: jobsLoading
                            ? const Color(0xFF9ECCAD)
                            : const Color(0xFFEAC58F),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (jobsLoading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else
                          const Icon(
                            Icons.cloud_off_outlined,
                            color: Color(0xFF965F16),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            jobsLoading
                                ? 'Loading published PESO vacancies...'
                                : jobLoadError!,
                            style: const TextStyle(
                              color: Color(0xFF24483A),
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (!jobsLoading && onRetryJobs != null)
                          TextButton.icon(
                            key: const ValueKey('retry-peso-jobs'),
                            onPressed: onRetryJobs,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 18 : 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE5F6E9), Color(0xFFF9FCF7)],
                  ),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: const Color(0xFF98D5B2),
                    width: 1.3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12236349),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.travel_explore_rounded,
                          color: primary,
                          size: 25,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            selectedLanguage == 'English'
                                ? 'Search your preferred job in Montalban, Rizal'
                                : 'Hanapin ang trabahong gusto mo sa Montalban, Rizal',
                            style: TextStyle(
                              fontSize: compact ? 16 : 19,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      selectedLanguage == 'English'
                          ? 'Search job titles, employers, skills or locations. All active openings are included, even without an AI match.'
                          : 'Maghanap ayon sa trabaho, employer, kasanayan o lugar. Kasama ang lahat ng aktibong posisyon.',
                      style: TextStyle(fontSize: 13, color: textLight),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      key: const Key('all-jobs-search'),
                      controller: searchController,
                      onChanged: onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: selectedLanguage == 'English'
                            ? 'Try: construction, driver, cashier, or company name'
                            : 'Halimbawa: construction, driver, cashier, o pangalan ng kumpanya',
                        prefixIcon: Icon(Icons.search_rounded, color: primary),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear job search',
                                onPressed: () {
                                  searchController?.clear();
                                  onSearchChanged?.call('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 15,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF94CBA9),
                            width: 1.3,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primary, width: 2.3),
                        ),
                      ),
                    ),
                    if (searchQuery.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${availableJobs.length} active job ${availableJobs.length == 1 ? 'result' : 'results'} across all categories (AI match not required)',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  localizedJobHeading(
                    searchQuery.isNotEmpty
                        ? 'SEARCH RESULTS'
                        : suggestedCount > 0
                        ? 'RECOMMENDED FOR YOUR INTERESTS'
                        : 'EXPLORE OPPORTUNITIES',
                    selectedLanguage,
                  ),
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.25,
                  ),
                ),
              ),
              if (searchQuery.isEmpty &&
                  preferredOccupation.trim().isNotEmpty) ...[
                Text(
                  suggestedCount > 0
                      ? selectedLanguage == 'Tagalog'
                            ? 'May $suggestedCount na nakapaskil na posisyong kaugnay ng iyong interes: $preferredOccupation. Hindi ito garantiya na kuwalipikado ka; suriin ang mga kailangan ng employer.'
                            : selectedLanguage == 'Taglish'
                            ? 'May $suggestedCount published role(s) na related sa interests mo: $preferredOccupation. Check pa rin ang employer requirements.'
                            : 'Showing $suggestedCount published role(s) related to your stated interests: $preferredOccupation. Recommendations are not proof of eligibility; check each employer’s requirements.'
                      : selectedLanguage == 'Tagalog'
                      ? 'Wala pang nakapaskil na posisyong direktang tumutugma sa $preferredOccupation. Maaari mong tingnan ang iba pang trabaho o maghanap ayon sa posisyon.'
                      : selectedLanguage == 'Taglish'
                      ? 'Wala pang posted roles na match sa $preferredOccupation. Browse muna ng ibang jobs o search ng specific role.'
                      : 'No currently published positions directly match your preferred work ($preferredOccupation). Browse other openings below or search by role; we will not invent vacancies.',
                  style: TextStyle(
                    color: const Color(0xFF52675D),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (interestLabels.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: interestLabels
                        .map(
                          (interest) => Chip(
                            avatar: const Icon(
                              Icons.favorite_border_rounded,
                              size: 16,
                              color: Color(0xFF236349),
                            ),
                            label: Text(interest),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFFEAF5EF),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(
                      localizedJobHeading('All jobs', selectedLanguage),
                    ),
                    selected: selectedCategory == PesoJobCategories.all,
                    onSelected: (_) => onCategoryChanged(PesoJobCategories.all),
                  ),
                  ChoiceChip(
                    label: Text(
                      localizedJobHeading(
                        'Walk-in Application',
                        selectedLanguage,
                      ),
                    ),
                    selected:
                        selectedCategory == PesoJobCategories.walkInApplication,
                    onSelected: (_) =>
                        onCategoryChanged(PesoJobCategories.walkInApplication),
                  ),
                  ChoiceChip(
                    label: Text(
                      localizedJobHeading(
                        'Local Recruitment Activity',
                        selectedLanguage,
                      ),
                    ),
                    selected:
                        selectedCategory ==
                        PesoJobCategories.localRecruitmentActivity,
                    onSelected: (_) => onCategoryChanged(
                      PesoJobCategories.localRecruitmentActivity,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FadeSlideEntrance(
                delay: 200,
                child: SizedBox(
                  height: compact ? 285 : 320,
                  child: availableJobs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy_outlined,
                                size: 30,
                                color: textLight,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                selectedCategory ==
                                        PesoJobCategories
                                            .localRecruitmentActivity
                                    ? selectedLanguage == 'Tagalog'
                                          ? 'Wala pang kumpirmadong aktibong lokal na recruitment ngayon.'
                                          : selectedLanguage == 'Taglish'
                                          ? 'Wala pang confirmed active local recruitment ngayon.'
                                          : 'No confirmed active local recruitment activities at the moment.'
                                    : selectedLanguage == 'Tagalog'
                                    ? 'Wala pang aktibong trabaho sa kategoryang ito.'
                                    : selectedLanguage == 'Taglish'
                                    ? 'Wala pang active jobs sa category na ito.'
                                    : 'No active jobs in this category yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (selectedCategory ==
                                  PesoJobCategories
                                      .localRecruitmentActivity) ...[
                                const SizedBox(height: 7),
                                const Text(
                                  '2020 PESO LRA PDF is a historical reference, not a confirmed open recruitment event.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _openPublicPdfSource(
                                    'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/PARA-SA-MONTALBENO.pdf',
                                  ),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text(
                                    'View historical LRA source PDF',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : FeaturedOpportunitiesCarousel(
                          itemCount: availableJobs.length,
                          itemBuilder: (context, index) {
                            final job = availableJobs[index];
                            final logoUrl = (job['logoUrl']?.toString() ?? '')
                                .trim();
                            final logoAsset =
                                PesoEmployerBranding.logoAssetForJob(job);
                            final isSelected = selectedJob == job;
                            final rawMatch = job['match'];
                            final matchScore = rawMatch is num
                                ? rawMatch.toInt()
                                : 0;
                            final bool isTopMatch = matchScore >= 90;

                            return PesoHoverLift(
                              child: GestureDetector(
                                onTap: () => onSelectJob(job),
                                child: AnimatedContainer(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 180),
                                  width: compact ? 272 : 300,
                                  margin: const EdgeInsets.only(
                                    right: 16,
                                    bottom: 14,
                                    top: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(23),
                                    border: Border.all(
                                      color: isSelected
                                          ? primary
                                          : const Color(0xFFDCE9E1),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? primary.withValues(alpha: 0.16)
                                            : const Color(0x10173E31),
                                        blurRadius: isSelected ? 22 : 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(21),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              PesoNetworkImage(
                                                imageUrl: job['image']
                                                    ?.toString(),
                                                fallbackAsset:
                                                    job['imageFallback']
                                                        ?.toString() ??
                                                    PesoImageAssets.jobFallbackFor(
                                                      job,
                                                    ),
                                                fit: BoxFit.cover,
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
                                              if (logoUrl.isNotEmpty ||
                                                  logoAsset != null)
                                                Positioned(
                                                  bottom: 12,
                                                  right: 12,
                                                  child: Container(
                                                    width:
                                                        logoAsset ==
                                                            PesoEmployerBranding
                                                                .puregoldLogoAsset
                                                        ? 88
                                                        : 50,
                                                    height: 50,
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: PesoEmployerLogo(
                                                      company:
                                                          job['company']
                                                              ?.toString() ??
                                                          job['title']
                                                              ?.toString(),
                                                      logoUrl: logoUrl,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                              if (job['category'] != null)
                                                Positioned(
                                                  top: 15,
                                                  left: 15,
                                                  child: Container(
                                                    constraints:
                                                        const BoxConstraints(
                                                          maxWidth: 190,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 7,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.94,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      PesoJobCategories.labelWithShortName(
                                                        job['category']
                                                            ?.toString(),
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF1D4ED8,
                                                        ),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              Positioned(
                                                top: 15,
                                                right: 15,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  child: RepaintBoundary(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF17352B,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.auto_awesome,
                                                            color: isTopMatch
                                                                ? Colors
                                                                      .amberAccent
                                                                : Colors.white,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            matchScore > 0
                                                                ? '$matchScore% Match'
                                                                : job['suggestedForInterest'] ==
                                                                      true
                                                                ? localizedJobHeading(
                                                                    'Your interests',
                                                                    selectedLanguage,
                                                                  )
                                                                : localizedJobHeading(
                                                                    'New posting',
                                                                    selectedLanguage,
                                                                  ),
                                                            style: TextStyle(
                                                              color: isTopMatch
                                                                  ? Colors
                                                                        .amberAccent
                                                                  : Colors
                                                                        .white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
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
                                        Expanded(
                                          flex: 4,
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  localizedNoticeTitle(
                                                    job['title']?.toString() ??
                                                        '',
                                                    selectedLanguage,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    color: textDark,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.business,
                                                      size: 14,
                                                      color: textLight,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Expanded(
                                                      child: Text(
                                                        job['company'],
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: textLight,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 20),
              if (hasMoreJobs)
                Align(
                  alignment: Alignment.center,
                  child: FilledButton.tonalIcon(
                    onPressed: loadingMoreJobs ? null : onLoadMoreJobs,
                    icon: loadingMoreJobs
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      loadingMoreJobs
                          ? 'Loading more jobs...'
                          : 'Load more PESO jobs',
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (selectedJob != null)
                KeyedSubtree(
                  key: detailsAnchor,
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
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
                      key: ValueKey(
                        selectedJob!['id'] ?? selectedJob!['title'],
                      ),
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
                          Container(
                            height: compact ? 270 : (medium ? 260 : 240),
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PesoNetworkImage(
                                  imageUrl: selectedJob!['image']?.toString(),
                                  fallbackAsset:
                                      selectedJob!['imageFallback']
                                          ?.toString() ??
                                      PesoImageAssets.jobFallbackFor(
                                        selectedJob!,
                                      ),
                                  fit: BoxFit.cover,
                                ),
                                Container(
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
                                  padding: EdgeInsets.all(
                                    compact ? 16 : (medium ? 20 : 30),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: PesoEmployerLogo(
                                              company:
                                                  selectedJob!['company']
                                                      ?.toString() ??
                                                  selectedJob!['title']
                                                      ?.toString(),
                                              logoUrl: selectedJob!['logoUrl']
                                                  ?.toString(),
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: Text(
                                              selectedJob!['company'],
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
                                        selectedLanguage == 'English'
                                            ? selectedJob!['title']
                                            : (translatedJob?['title']
                                                      ?.toString() ??
                                                  localizedNoticeTitle(
                                                    selectedJob!['title']
                                                            ?.toString() ??
                                                        '',
                                                    selectedLanguage,
                                                  )),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: compact
                                              ? 26
                                              : (medium ? 30 : 36),
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(
                              compact ? 18 : (medium ? 26 : 36),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildInfoBadge(
                                          Icons.location_on,
                                          localizedJobHeading(
                                            selectedJob!['location']
                                                    ?.toString() ??
                                                '',
                                            selectedLanguage,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        _buildInfoBadge(
                                          Icons.work,
                                          localizedJobHeading(
                                            selectedJob!['type']?.toString() ??
                                                '',
                                            selectedLanguage,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        _buildInfoBadge(
                                          Icons.people,
                                          selectedJob!['isPublicPdfListing'] ==
                                                  true
                                              ? (selectedJob!['listingLabel']
                                                        ?.toString() ??
                                                    'Multiple roles')
                                              : '${selectedJob!['vacancies']} Slots',
                                        ),
                                        if (selectedJob!['category'] != null)
                                          _buildInfoBadge(
                                            Icons.category_outlined,
                                            localizedJobHeading(
                                              PesoJobCategories.labelWithShortName(
                                                selectedJob!['category']
                                                    ?.toString(),
                                              ),
                                              selectedLanguage,
                                            ),
                                          ),
                                        if (selectedJob!['category'] != null)
                                          _buildInfoBadge(
                                            Icons.schedule,
                                            localizedJobHeading(
                                              PesoJobCategories.expiryText(
                                                selectedJob!,
                                              ),
                                              selectedLanguage,
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      localizedJobHeading(
                                        selectedJob!['salary']?.toString() ??
                                            '',
                                        selectedLanguage,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: primary,
                                        fontSize: compact
                                            ? 19
                                            : (medium ? 22 : 26),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 35),
                                Text(
                                  localizedJobHeading(
                                    'Role Description',
                                    selectedLanguage,
                                  ),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: textDark,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  selectedLanguage == 'English'
                                      ? selectedJob!['description']
                                      : (translatedJob?['description']
                                                ?.toString() ??
                                            localizedNoticeDescription(
                                              selectedJob!['description']
                                                      ?.toString() ??
                                                  '',
                                              selectedLanguage,
                                            )),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                    height: 1.8,
                                  ),
                                ),
                                if (selectedLanguage != 'English') ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.translate_rounded,
                                        size: 18,
                                        color: Color(0xFF236349),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          translationLoading
                                              ? 'Translating the selected listing...'
                                              : translatedJob != null
                                              ? 'Translated for reading; original English remains authoritative.'
                                              : selectedLanguage == 'Tagalog'
                                              ? 'Kasalukuyang bahagyang isinalin ang karaniwang teksto. Nananatili sa orihinal na Ingles ang ilang detalye at kwalipikasyon.'
                                              : 'May Taglish na standard text, pero English pa rin ang ilang employer details habang unavailable ang full translation.',
                                          style: TextStyle(
                                            color: textLight,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (translationFailed &&
                                          onRetryTranslation != null)
                                        TextButton(
                                          onPressed: onRetryTranslation,
                                          child: const Text('Retry'),
                                        ),
                                    ],
                                  ),
                                  if (translatedJob != null)
                                    Material(
                                      color: Colors.transparent,
                                      child: ExpansionTile(
                                        dense: true,
                                        title: const Text(
                                          'Original English description & requirements',
                                        ),
                                        children: [
                                          Text(
                                            selectedJob!['description']
                                                    ?.toString() ??
                                                '',
                                            style: TextStyle(color: textLight),
                                          ),
                                          for (final req
                                              in (selectedJob!['reqs']
                                                  as List<dynamic>))
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 5,
                                                  ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check,
                                                    size: 15,
                                                    color: Color(0xFF236349),
                                                  ),
                                                  const SizedBox(width: 9),
                                                  Expanded(
                                                    child: Text(req.toString()),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                                if (selectedJob!['isPublicPdfListing'] ==
                                    true) ...[
                                  const SizedBox(height: 22),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      border: Border.all(
                                        color: const Color(0xFFFED7AA),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.info_outline,
                                              color: Color(0xFF9A3412),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Public source listing — current availability not confirmed',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: textDark,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          selectedJob!['availabilityNote']
                                                  ?.toString() ??
                                              'Confirm current availability with PESO Montalban before applying.',
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Source: ${selectedJob!['sourceTitle'] ?? 'PESO Montalban PDF'} · pages ${selectedJob!['sourcePageStart'] ?? 1}–${selectedJob!['sourcePageEnd'] ?? 1}',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                            onPressed: () =>
                                                _openPublicPdfSource(
                                                  selectedJob!['sourceUrl']
                                                      ?.toString(),
                                                ),
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text(
                                              'Open official source PDF',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (selectedJob!['aiListingKind'] ==
                                    'notice') ...[
                                  const SizedBox(height: 24),
                                  NoticeRoleSelector(
                                    roles: linkedRoles,
                                    onView: onSelectJob,
                                    onEvaluate: onEvaluateJob,
                                    onCompare: onCompareRoles,
                                  ),
                                ],
                                const SizedBox(height: 35),
                                Text(
                                  selectedJob!['aiListingKind'] == 'notice'
                                      ? 'Notice-level qualifications (not role-verified)'
                                      : 'AI Extracted Requirements',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: textDark,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children:
                                      ((selectedLanguage != 'English' &&
                                                  translatedJob?['requirements']
                                                      is List &&
                                                  (translatedJob!['requirements']
                                                              as List)
                                                          .length ==
                                                      (selectedJob!['reqs']
                                                              as List)
                                                          .length)
                                              ? translatedJob!['requirements']
                                                    as List
                                              : selectedJob!['reqs']
                                                    as List<dynamic>)
                                          .map(
                                            (req) =>
                                                _buildReqChip(req.toString()),
                                          )
                                          .toList(),
                                ),
                                const SizedBox(height: 50),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          primary,
                                          Colors.green.shade800,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          onEvaluateJob(selectedJob!),
                                      icon: const Icon(
                                        Icons.auto_awesome,
                                        size: 24,
                                      ),
                                      label: Text(
                                        'Evaluate Job Qualification',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: compact ? 14 : 18,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: compact ? 14 : 36,
                                          vertical: compact ? 17 : 22,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textLight),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textDark,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReqChip(String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cancellable, reduced-motion-aware entrance shared across user tabs.
class FadeSlideEntrance extends StatelessWidget {
  const FadeSlideEntrance({
    super.key,
    required this.child,
    required this.delay,
  });

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedEntrance(
      delay: delay.clamp(0, 300),
      duration: const Duration(milliseconds: 300),
      beginOffset: const Offset(0, 0.025),
      child: child,
    );
  }
}

/// Horizontal featured opportunities with real previous/next controls.
/// The list remains touch/swipe and trackpad scrollable.
class FeaturedOpportunitiesCarousel extends StatefulWidget {
  const FeaturedOpportunitiesCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<FeaturedOpportunitiesCarousel> createState() =>
      _FeaturedOpportunitiesCarouselState();
}

class _FeaturedOpportunitiesCarouselState
    extends State<FeaturedOpportunitiesCarousel> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrowState);
  }

  void _updateArrowState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_updateArrowState);
    _controller.dispose();
    super.dispose();
  }

  void _scroll(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final distance = position.viewportDimension * 0.85;
    final next = (_controller.offset + direction * distance).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _controller.animateTo(
      next.toDouble(),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPrevious =
        _controller.hasClients &&
        _controller.offset > _controller.position.minScrollExtent + 1;
    final canNext =
        _controller.hasClients &&
        _controller.offset < _controller.position.maxScrollExtent - 1;
    return Stack(
      children: [
        ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          itemCount: widget.itemCount,
          itemBuilder: widget.itemBuilder,
        ),
        if (canPrevious)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton.filledTonal(
              tooltip: 'Previous featured opportunities',
              onPressed: () => _scroll(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
          ),
        if (canNext)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filledTonal(
              tooltip: 'Next featured opportunities',
              onPressed: () => _scroll(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ),
      ],
    );
  }
}
