import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'peso_logo.dart';
import 'peso_images.dart';

/// Responsive, static hero. Photography is bundled and paints only once at rest.
class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    this.exploreJobsKey,
    this.createAccountKey,
    this.backgroundAsset = PesoImageAssets.heroBanner,
  });

  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;
  final String backgroundAsset;
  final GlobalKey? exploreJobsKey;
  final GlobalKey? createAccountKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final wide = constraints.maxWidth >= 1000;
        final copy = _HeroCopy(
          compact: compact,
          onPrimaryTap: onPrimaryTap,
          onSecondaryTap: onSecondaryTap,
          exploreJobsKey: exploreJobsKey,
          createAccountKey: createAccountKey,
        );
        return RepaintBoundary(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: PesoTokens.surfaceDark,
              image: DecorationImage(
                image: AssetImage(backgroundAsset),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFA102E25),
                    Color(0xE0102E25),
                    Color(0xC4194538),
                  ],
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 24 : 40,
                vertical: compact ? 36 : 64,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: PesoTokens.maxContentWidth,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 6, child: copy),
                            const SizedBox(width: 64),
                            const Expanded(flex: 4, child: _OpportunityPanel()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            copy,
                            const SizedBox(height: 32),
                            const _OpportunityPanel(),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.compact,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    this.exploreJobsKey,
    this.createAccountKey,
  });
  final GlobalKey? exploreJobsKey;
  final GlobalKey? createAccountKey;
  final bool compact;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              color: Color(0xFFE4C68C),
              size: 16,
            ),
            Text(
              'PESO MONTALBAN',
              style: TextStyle(
                color: Color(0xFFE4C68C),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Your next opportunity\nstarts here.',
          style: PesoTokens.displayLarge.copyWith(
            color: Colors.white,
            fontSize: compact ? 38 : 56,
            height: 1.12,
            letterSpacing: -1.6,
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Discover local jobs, build your professional profile, and take the next step in your career.',
            style: TextStyle(
              color: const Color(0xFFD6E5DE),
              fontSize: compact ? 16 : 18,
              height: 1.65,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              key: exploreJobsKey,
              onPressed: onPrimaryTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE4C68C),
                foregroundColor: const Color(0xFF19382C),
                minimumSize: const Size(48, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text(
                'Explore Job Openings',
                textAlign: TextAlign.center,
              ),
            ),
            OutlinedButton(
              key: createAccountKey,
              onPressed: onSecondaryTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF8CA99A)),
                minimumSize: const Size(48, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create an account',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _ServiceLabel(
              icon: Icons.work_outline_rounded,
              label: 'Local opportunities',
            ),
            _ServiceLabel(
              icon: Icons.person_outline_rounded,
              label: 'Career support',
            ),
          ],
        ),
      ],
    );
  }
}

class _ServiceLabel extends StatelessWidget {
  const _ServiceLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: const Color(0xFFB4CDBF), size: 16),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFCBDCD2), fontSize: 12),
        ),
      ),
    ],
  );
}

class _OpportunityPanel extends StatelessWidget {
  const _OpportunityPanel();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAF8),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFDCE7E0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            PesoLogo.animated(
              size: MediaQuery.sizeOf(context).width < 600
                  ? 40
                  : PesoTokens.logoSizeHero,
              delay: Duration(milliseconds: 100),
            ),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR CAREER STARTS HERE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: PesoTokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'A clearer path\nto your next step.',
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 600
                          ? 18
                          : 22,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: PesoTokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFFDCE5E0), height: 1),
        const SizedBox(height: 8),
        const _FeatureRow(
          number: '01',
          icon: Icons.work_outline_rounded,
          title: 'Find Jobs',
          subtitle: 'Browse available job listings',
        ),
        const _FeatureRow(
          number: '02',
          icon: Icons.school_outlined,
          title: 'Explore Programs',
          subtitle: 'Discover training and livelihood options',
        ),
        const _FeatureRow(
          number: '03',
          icon: Icons.person_add_alt_1_outlined,
          title: 'Get Started',
          subtitle: 'Register for a jobseeker account',
        ),
      ],
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PesoTokens.brandGreenLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: PesoTokens.brandGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: PesoTokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: PesoTokens.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          number,
          style: const TextStyle(color: PesoTokens.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}
