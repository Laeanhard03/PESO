import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Reusable card components for the PESO JobKonek landing page.
/// Implements consistent styling, hover/tap states, and responsive behavior.

/// Job card with company logo, title, location, salary, and tags.
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.title,
    required this.company,
    required this.location,
    this.salary,
    this.type,
    this.tags = const [],
    this.logoAsset,
    this.onTap,
    this.isLoading = false,
  });

  final String title;
  final String company;
  final String location;
  final String? salary;
  final String? type;
  final List<String> tags;
  final String? logoAsset;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const tokens = PesoDesignTokens();
    final theme = Theme.of(context);

    return AnimatedContainer(
      constraints: const BoxConstraints(maxWidth: 360),
      duration: PesoTokens.cardTransitionDuration,
      curve: PesoTokens.cardTransitionCurve,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
        boxShadow: const <BoxShadow>[],
        border: Border.all(color: const Color(0xFFDCE5E0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(PesoTokens.spacingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: logo + company
                Row(
                  children: [
                    _CompanyLogo(
                      logoAsset: logoAsset,
                      size: 48,
                      tokens: tokens,
                    ),
                    const SizedBox(width: PesoTokens.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company,
                            style: PesoTokens.labelMedium.copyWith(
                              color: PesoTokens.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: PesoTokens.headlineSmall.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: PesoTokens.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (salary != null)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: PesoTokens.spacingSM,
                          vertical: PesoTokens.space1,
                        ),
                        decoration: BoxDecoration(
                          color: PesoTokens.brandGreenLight,
                          borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
                        ),
                        child: Text(
                          salary!,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: PesoTokens.labelMedium.copyWith(
                            color: PesoTokens.brandGreenDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: PesoTokens.spacingLG),

                // Location & type
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: PesoTokens.textMuted,
                    ),
                    const SizedBox(width: PesoTokens.space2),
                    Expanded(
                      child: Text(
                        location,
                        style: PesoTokens.bodySmall.copyWith(color: PesoTokens.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (type != null) ...[
                      const SizedBox(width: PesoTokens.spacingMD),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PesoTokens.spacingSM,
                          vertical: PesoTokens.space1,
                        ),
                        decoration: BoxDecoration(
                          color: PesoTokens.surfaceNeutral,
                          borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
                        ),
                        child: Text(
                          type!,
                          style: PesoTokens.labelSmall.copyWith(color: PesoTokens.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: PesoTokens.spacingLG),

                // Tags
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: PesoTokens.space2,
                    runSpacing: PesoTokens.space2,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PesoTokens.spacingSM,
                          vertical: PesoTokens.space1,
                        ),
                        decoration: BoxDecoration(
                          color: PesoTokens.brandGreenPale,
                          borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
                          border: Border.all(color: PesoTokens.brandGreenLight),
                        ),
                        child: Text(
                          tag,
                          style: PesoTokens.labelSmall.copyWith(color: PesoTokens.brandGreenDark),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({
    required this.logoAsset,
    required this.size,
    required this.tokens,
  });

  final String? logoAsset;
  final double size;
  final PesoDesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (logoAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
        child: Image.asset(
          logoAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(size, tokens),
        ),
      );
    }
    return _placeholder(size, tokens);
  }

  Widget _placeholder(double size, PesoDesignTokens tokens) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PesoTokens.brandGreenLight,
        borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
      ),
      child: Icon(
        Icons.business_rounded,
        color: PesoTokens.brandGreen,
        size: size * 0.5,
      ),
    );
  }
}

/// Program card for PESO employment programs (SPES, GIP, TUPAD, etc.)
class ProgramCard extends StatelessWidget {
  const ProgramCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
    this.stats = const [],
    this.onTap,
    this.isLoading = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;
  final List<ProgramStat> stats;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const tokens = PesoDesignTokens();
    final theme = Theme.of(context);
    final color = accentColor ?? PesoTokens.brandGreen;

    return AnimatedContainer(
      constraints: const BoxConstraints(maxWidth: 360),
      duration: PesoTokens.cardTransitionDuration,
      curve: PesoTokens.cardTransitionCurve,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
        boxShadow: const <BoxShadow>[],
        border: Border.all(color: const Color(0xFFDCE5E0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(PesoTokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(PesoTokens.spacingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + title row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: PesoTokens.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: PesoTokens.headlineSmall.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: PesoTokens.space1),
                          Text(
                            description,
                            style: PesoTokens.bodyMedium.copyWith(color: PesoTokens.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PesoTokens.spacingLG),

                // Stats row
                if (stats.isNotEmpty)
                  Wrap(
                    spacing: PesoTokens.spacingLG,
                    runSpacing: PesoTokens.spacingSM,
                    children: [
                      for (final stat in stats)
                        _StatItem(
                          tokens: tokens,
                          label: stat.label,
                          value: stat.value,
                          color: color,
                        ),
                    ],
                  ),

                const SizedBox(height: PesoTokens.spacingLG),

                // CTA
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onTap,
                      icon: Icon(Icons.arrow_forward_rounded, size: 18, color: color),
                      label: Text(
                        'Learn More',
                        style: PesoTokens.labelLarge.copyWith(color: color, fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PesoTokens.spacingSM,
                          vertical: PesoTokens.spacingSM,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.tokens,
    required this.label,
    required this.value,
    required this.color,
  });

  final PesoDesignTokens tokens;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: PesoTokens.headlineMedium.copyWith(
            fontSize: 24,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: PesoTokens.space1),
        Text(
          label,
          style: PesoTokens.bodySmall.copyWith(color: PesoTokens.textMuted),
        ),
      ],
    );
  }
}

class ProgramStat {
  const ProgramStat({required this.label, required this.value});
  final String label;
  final String value;
}

/// Feature card for "How it works" and similar sections.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
    this.onTap,
  });

  final int number;
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? PesoTokens.brandGreen;

    return AnimatedContainer(
      constraints: const BoxConstraints(maxWidth: 360),
      duration: PesoTokens.cardTransitionDuration,
      curve: PesoTokens.cardTransitionCurve,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
        boxShadow: const <BoxShadow>[],
        border: Border.all(color: const Color(0xFFDCE5E0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
          child: Padding(
            padding: const EdgeInsets.all(PesoTokens.spacingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Number badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: PesoTokens.headlineMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PesoTokens.spacingLG),

                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: PesoTokens.spacingLG),

                // Title
                Text(
                  title,
                  style: PesoTokens.headlineMedium.copyWith(fontSize: 22),
                ),
                const SizedBox(height: PesoTokens.spacingMD),

                // Description
                Text(
                  description,
                  style: PesoTokens.bodyMedium.copyWith(color: PesoTokens.textSecondary, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Timeline node for History page.
class TimelineNode extends StatelessWidget {
  const TimelineNode({
    super.key,
    required this.year,
    required this.title,
    required this.description,
    this.color,
    this.isLast = false,
    this.isFirst = false,
  });

  final String year;
  final String title;
  final String description;
  final Color? color;
  final bool isLast;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? PesoTokens.brandGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: PesoTokens.spacing3XL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 80,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: PesoTokens.spacing2XL,
                    color: const Color(0xFFDCE5E0),
                  ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: PesoTokens.spacing2XL,
                    color: const Color(0xFFDCE5E0),
                  ),
              ],
            ),
          ),
          const SizedBox(width: PesoTokens.spacingLG),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PesoTokens.spacingSM,
                    vertical: PesoTokens.space1,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
                  ),
                  child: Text(
                    year,
                    style: PesoTokens.labelLarge.copyWith(color: c, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: PesoTokens.spacingMD),
                Text(
                  title,
                  style: PesoTokens.headlineMedium.copyWith(fontSize: 24),
                ),
                const SizedBox(height: PesoTokens.spacingSM),
                Text(
                  description,
                  style: PesoTokens.bodyMedium.copyWith(color: PesoTokens.textSecondary, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}