import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Reusable_Designs/design_tokens.dart';

/// Public PESO/DOLE information, not a guarantee of local applications.
@immutable
class PesoServiceEntry {
  const PesoServiceEntry({
    required this.code,
    required this.title,
    required this.summary,
    required this.details,
    required this.sourceUrl,
    required this.sourceLabel,
    required this.group,
    required this.icon,
  });

  final String code;
  final String title;
  final String summary;
  final String details;
  final String sourceUrl;
  final String sourceLabel;
  final String group;
  final IconData icon;
}

class PesoPublicServices extends StatefulWidget {
  const PesoPublicServices({super.key});

  static const String pesoGroup = 'PESO assistance';
  static const String programsGroup = 'Programs & benefits';

  /// Sources: official PESO PEIS pages, DOLE, RA11261 and the LGU home page.
  /// Current SEAP implementation in Montalban is unverified.
  static const List<PesoServiceEntry> catalog = [
    PesoServiceEntry(
      code: "job-matching",
      title: "Job Matching & Referral",
      summary: "Help finding vacancies and referring qualified applicants to employers.",
      details: "PESO connects registered jobseekers with employer vacancies and employment referrals. Register through PhilJobNet or inquire at your local PESO for current procedures.",
      sourceUrl: "https://peis.philjobnet.gov.ph/register.aspx",
      sourceLabel: "PEIS: jobseeker registration",
      group: "PESO assistance",
      icon: Icons.work_outline_rounded,
    ),
    PesoServiceEntry(
      code: "job-fairs",
      title: "Job Fairs & Local Recruitment",
      summary:
          "Information about recruitment activities and employer interviews.",
      details: "Job fairs bring employers and jobseekers together. PESO Montalban recruitment and job fairs appear in the supplied project reference photos. Confirm dates and participating employers with PESO.",
      sourceUrl: "https://peis.philjobnet.gov.ph/peso.aspx",
      sourceLabel: "PEIS: special PESO services",
      group: "PESO assistance",
      icon: Icons.groups_rounded,
    ),
    PesoServiceEntry(
      code: "career-guidance",
      title: "Career Guidance & Coaching",
      summary:
          "Job-search coaching, career orientation and employment counseling.",
      details: "PESO provides career guidance and employment coaching to help jobseekers understand career paths, prepare applications and identify appropriate vacancies.",
      sourceUrl: "https://peis.philjobnet.gov.ph/register.aspx",
      sourceLabel: "PEIS: jobseeker services",
      group: "PESO assistance",
      icon: Icons.school_outlined,
    ),
    PesoServiceEntry(
      code: "labor-market",
      title: "Labor Market Information",
      summary: "Information on demand for jobs, careers and employer needs.",
      details: "PESO provides labor market information to jobseekers, employers, students, researchers and planners. Inquire for local occupational information.",
      sourceUrl: "https://peis.philjobnet.gov.ph/register.aspx",
      sourceLabel: "PEIS: PESO jobseeker/employer services",
      group: "PESO assistance",
      icon: Icons.bar_chart_rounded,
    ),
    PesoServiceEntry(
      code: "orientation",
      title: "Pre-employment Orientation",
      summary: "Orientation for prospective local and overseas workers.",
      details: "PESO's core functions include pre-employment counseling and orientation. Confirm available sessions and refer overseas recruitment questions to the relevant government offices.",
      sourceUrl: "https://peis.philjobnet.gov.ph/peso.aspx",
      sourceLabel: "PEIS: PESO functions",
      group: "PESO assistance",
      icon: Icons.record_voice_over_outlined,
    ),
    PesoServiceEntry(
      code: "nsrp",
      title: "NSRP / Jobseeker Registration",
      summary: "Help registering employment profiles and skill information.",
      details: "The National Skills Registration Program records skills and employment information. Jobseekers may register through PhilJobNet or visit PESO. JobKonek is a separate project platform and does not replace official registration.",
      sourceUrl: "https://peis.philjobnet.gov.ph/register.aspx",
      sourceLabel: "PEIS: jobseeker registration",
      group: "PESO assistance",
      icon: Icons.app_registration_rounded,
    ),
    PesoServiceEntry(
      code: "skills-training",
      title: "Skills Training Referrals",
      summary: "Referrals to vocational training and relevant TESDA programs.",
      details: "PESO supports referrals to skills-training opportunities. Confirm qualifications, available schedules and certificates with the appropriate training provider or TESDA.",
      sourceUrl: "https://www.tesda.gov.ph/",
      sourceLabel: "TESDA official website",
      group: "PESO assistance",
      icon: Icons.handyman_outlined,
    ),
    PesoServiceEntry(
      code: "livelihood-referrals",
      title: "Livelihood & Self-employment Referrals",
      summary: "Information on livelihood opportunities and entrepreneurship support.",
      details: "PESO may assess interested clients and refer them to relevant government or partner livelihood programs. Referral does not guarantee a grant or loan.",
      sourceUrl: "https://peis.philjobnet.gov.ph/peso.aspx",
      sourceLabel: "PEIS: livelihood and self-employment functions",
      group: "PESO assistance",
      icon: Icons.storefront_outlined,
    ),
    PesoServiceEntry(
      code: "employer-services",
      title: "Employer Vacancy Support",
      summary: "Assistance for employers with vacancies and labor market information.",
      details: "Employers can inquire about candidate referrals, employment matching and labor market information. Official PhilJobNet employer accreditation rules still apply.",
      sourceUrl: "https://peis.philjobnet.gov.ph/register.aspx",
      sourceLabel: "PEIS: employer services",
      group: "PESO assistance",
      icon: Icons.business_outlined,
    ),
    PesoServiceEntry(
      code: "inclusive-support",
      title: "Inclusive Employment Support",
      summary:
          "Employment referrals for PWDs, displaced workers and other groups.",
      details: "PESO is designed for diverse jobseekers, including persons with disabilities and displaced workers. Confirm available referrals and accommodations locally.",
      sourceUrl: "https://peis.philjobnet.gov.ph/peso.aspx",
      sourceLabel: "PEIS: PESO clients and special services",
      group: "PESO assistance",
      icon: Icons.accessibility_new_rounded,
    ),
    PesoServiceEntry(
      code: "SEAP",
      title: "SEAP - PESO Inquiry",
      summary: "Ask PESO Montalban for details on the requested SEAP service.",
      details: "SEAP was requested for JobKonek. No official Montalban-specific published information establishing the full local program name, eligibility, or application schedule has been verified. Please confirm these directly with PESO Montalban.",
      sourceUrl: "https://montalban.gov.ph/",
      sourceLabel: "Montalban LGU (SEAP-specific page unverified)",
      group: "Programs & benefits",
      icon: Icons.help_outline_rounded,
    ),
    PesoServiceEntry(
      code: "GIP",
      title: "Government Internship Program (GIP)",
      summary:
          "Structured work exposure with government agencies under DOLE rules.",
      details: "GIP provides government work experience and career development. DOLE revised program guidelines in July 2026. Verify current qualifications, available slots and local schedules with DOLE and PESO.",
      sourceUrl: "https://dole.gov.ph/news/dole-strengthens-government-internship-program-with-revised-guidelines/",
      sourceLabel: "DOLE: revised GIP guidelines, July 2026",
      group: "Programs & benefits",
      icon: Icons.account_balance_outlined,
    ),
    PesoServiceEntry(
      code: "SPES",
      title: "Special Program for Employment of Students (SPES)",
      summary:
          "Temporary employment for eligible students and out-of-school youth.",
      details: "SPES is a DOLE youth employment program. Application periods, qualifications and local participation depend on official implementing announcements.",
      sourceUrl: "https://ro8.dole.gov.ph/core-process/",
      sourceLabel: "DOLE: SPES program overview",
      group: "Programs & benefits",
      icon: Icons.cast_for_education_outlined,
    ),
    PesoServiceEntry(
      code: "TUPAD",
      title: "TUPAD Emergency Employment",
      summary: "Temporary work assistance for eligible disadvantaged workers.",
      details: "TUPAD supports eligible disadvantaged, displaced or underemployed workers through temporary employment. Benefits and procedures depend on updated DOLE rules and available funding.",
      sourceUrl: "https://bwsc.dole.gov.ph/dileep/",
      sourceLabel: "DOLE BWSC: livelihood and emergency employment",
      group: "Programs & benefits",
      icon: Icons.construction_outlined,
    ),
    PesoServiceEntry(
      code: "DILP",
      title: "DOLE Integrated Livelihood Program",
      summary: "Kabuhayan opportunities for qualified vulnerable workers.",
      details: "DILP (Kabuhayan) supports eligible workers with approved livelihood assistance through recognized partners and implementing offices. Approval and local availability are not guaranteed.",
      sourceUrl: "https://bwsc.dole.gov.ph/dileep/",
      sourceLabel: "DOLE BWSC: DILEEP",
      group: "Programs & benefits",
      icon: Icons.savings_outlined,
    ),
    PesoServiceEntry(
      code: "JobStart",
      title: "JobStart Philippines",
      summary: "Employment readiness and work-transition opportunities.",
      details: "PEIS lists JobStart as a national employment program for jobseekers and employers. Ask PESO whether a local program currently accepts applications.",
      sourceUrl: "https://peis.philjobnet.gov.ph/register.aspx",
      sourceLabel: "PEIS: JobStart program listing",
      group: "Programs & benefits",
      icon: Icons.rocket_launch_outlined,
    ),
    PesoServiceEntry(
      code: "RA11261",
      title: "First Time Jobseekers Assistance",
      summary: "One-time government fee waivers for qualifying new jobseekers.",
      details: "Republic Act No. 11261 waives specified government fees for eligible first-time jobseekers, subject to exceptions. A barangay certification is generally required; benefits may be used once.",
      sourceUrl:
          "https://lawphil.net/statutes/repacts/ra2019/ra_11261_2019.html",
      sourceLabel: "Republic Act No. 11261 (Lawphil)",
      group: "Programs & benefits",
      icon: Icons.verified_user_outlined,
    ),
    PesoServiceEntry(
      code: "WHIP",
      title: "Workers Hiring for Infrastructure Projects",
      summary: "Information on local hiring provisions for government infrastructure.",
      details: "The PESO services framework describes WHIP in connection with Republic Act No. 6685. Ask PESO about qualifying projects; this is not a current Montalban vacancy listing.",
      sourceUrl: "https://peis.philjobnet.gov.ph/peso.aspx",
      sourceLabel: "PEIS: PESO special services",
      group: "Programs & benefits",
      icon: Icons.engineering_outlined,
    ),
    PesoServiceEntry(
      code: "WAP",
      title: "Work Appreciation Program",
      summary: "Exposure to work practices and workplace values.",
      details: "PESO describes WAP as a program to develop workplace values and ethics through exposure to actual work situations. Confirm locally whether a session is available.",
      sourceUrl: "https://peis.philjobnet.gov.ph/peso.aspx",
      sourceLabel: "PEIS: PESO special services",
      group: "Programs & benefits",
      icon: Icons.psychology_outlined,
    ),
  ];

  static Future<void> _openOfficial(
    BuildContext context,
    PesoServiceEntry service,
  ) async {
    final uri = Uri.parse(service.sourceUrl);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not open ${service.sourceUrl}')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not open ${service.sourceUrl}')),
        );
      }
    }
  }

  /// Called by the public page cards and by SEAP/GIP footer shortcuts.
  static Future<void> showDetails(BuildContext context, String serviceCode) {
    final matches = catalog.where((service) => service.code == serviceCode);
    if (matches.isEmpty) return Future.value();
    final service = matches.first;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: Key('service-detail-${service.code}'),
        scrollable: true,
        title: Text(service.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 530),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(service.details, style: const TextStyle(height: 1.55)),
              const SizedBox(height: 20),
              const Text(
                'Availability in Montalban',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Confirm current eligibility, documents, schedules and open '
                'slots with PESO Montalban. National program listings do not '
                'guarantee that local applications are currently open.',
              ),
              const SizedBox(height: 16),
              Text(
                'Official reference: ${service.sourceLabel}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF435249)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => _openOfficial(dialogContext, service),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('Official source'),
          ),
        ],
      ),
    );
  }

  @override
  State<PesoPublicServices> createState() => _PesoPublicServicesState();
}

class _PesoPublicServicesState extends State<PesoPublicServices> {
  final TextEditingController _search = TextEditingController();
  String _group = 'All services';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    final query = _search.text.trim().toLowerCase();
    final entries = PesoPublicServices.catalog.where((entry) {
      if (_group != 'All services' && entry.group != _group) {
        return false;
      }
      if (query.isEmpty) return true;
      return ('${entry.title} ${entry.summary} ${entry.code}')
          .toLowerCase()
          .contains(query);
    }).toList();

    return Container(
      key: const Key('peso-public-services'),
      width: double.infinity,
      color: PesoTokens.brandGreenDark,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 36,
        vertical: compact ? 36 : 54,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            children: [
              Text(
                'PESO Services & Programs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 29 : 37,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Explore official PESO services and national employment '
                'programs. Ask PESO Montalban to confirm local availability '
                'before applying.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: TextField(
                  key: const Key('peso-service-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Search e.g. SEAP, GIP, training',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear service search',
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final group in const [
                    'All services',
                    PesoPublicServices.pesoGroup,
                    PesoPublicServices.programsGroup,
                  ])
                    ChoiceChip(
                      label: Text(group),
                      selected: _group == group,
                      onSelected: (_) => setState(() => _group = group),
                      selectedColor: const Color(0xFFD0EDDB),
                      backgroundColor: Colors.white,
                      labelStyle: const TextStyle(color: Color(0xFF173F2C)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = compact
                      ? constraints.maxWidth
                      : constraints.maxWidth >= 1010
                      ? (constraints.maxWidth - 36) / 3
                      : constraints.maxWidth >= 680
                      ? (constraints.maxWidth - 18) / 2
                      : constraints.maxWidth;

                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'No matching PESO services. Try a different keyword.',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      for (final entry in entries)
                        SizedBox(
                          width: cardWidth,
                          child: _ServiceCard(
                            entry: entry,
                            onDetails: () => PesoPublicServices.showDetails(
                              context,
                              entry.code,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Sources: DOLE, PhilJobNet/PEIS, RA 11261 and supplied PESO '
                'Montalban photographs. SEAP local program details '
                'remain unverified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.entry, required this.onDetails});

  final PesoServiceEntry entry;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('service-card-${entry.code}'),
      color: Colors.white,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 195,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(entry.icon, color: PesoTokens.brandGreenDark, size: 27),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.45, fontSize: 14),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline_rounded, size: 17),
                  label: const Text('View details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
