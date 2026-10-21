import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'peso_logo.dart';

/// Adaptive navigation bar that provides:
/// - Desktop: Horizontal nav with pill indicator (>= 1024dp)
/// - Tablet: Compact horizontal nav or NavigationRail (600-1023dp)
/// - Mobile: Bottom NavigationBar (< 600dp)
class AdaptiveNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveNavBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    this.onRegisterTap,
    this.onLoginTap,
    this.showAuthActions = true,
    this.isScrolled = false,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onLoginTap;
  final bool showAuthActions;
  final bool isScrolled;

  static const List<_NavDestination> _destinations = [
    _NavDestination(index: 0, label: 'Home', icon: Icons.home_rounded),
    _NavDestination(index: 1, label: 'Jobs', icon: Icons.work_outline_rounded),
    _NavDestination(
      index: 2,
      label: 'Gallery',
      icon: Icons.photo_library_outlined,
    ),
    _NavDestination(index: 3, label: 'History', icon: Icons.history_rounded),
    _NavDestination(index: 4, label: 'About', icon: Icons.info_outline_rounded),
  ];

  @override
  Size get preferredSize =>
      const Size.fromHeight(PesoTokens.headerHeightDesktop);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= PesoTokens.breakpointDesktop) {
          return _DesktopNavBar(
            activeIndex: activeIndex,
            onTabSelected: onTabSelected,
            onRegisterTap: onRegisterTap,
            onLoginTap: onLoginTap,
            showAuthActions: showAuthActions,
            isScrolled: isScrolled,
          );
        } else if (width >= PesoTokens.breakpointCompact) {
          return _TabletNavBar(
            activeIndex: activeIndex,
            onTabSelected: onTabSelected,
            onRegisterTap: onRegisterTap,
            onLoginTap: onLoginTap,
            showAuthActions: showAuthActions,
            isScrolled: isScrolled,
          );
        } else {
          return _MobileNavBar(
            activeIndex: activeIndex,
            onTabSelected: onTabSelected,
            onRegisterTap: onRegisterTap,
            onLoginTap: onLoginTap,
            showAuthActions: showAuthActions,
            isScrolled: isScrolled,
          );
        }
      },
    );
  }
}

class _DesktopNavBar extends StatelessWidget {
  const _DesktopNavBar({
    required this.activeIndex,
    required this.onTabSelected,
    this.onRegisterTap,
    this.onLoginTap,
    required this.showAuthActions,
    required this.isScrolled,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onLoginTap;
  final bool showAuthActions;
  final bool isScrolled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: AnimatedContainer(
        duration: PesoTokens.durationMedium,
        curve: PesoTokens.curveStandard,
        height: PesoTokens.headerHeightDesktop,
        padding: const EdgeInsets.symmetric(horizontal: PesoTokens.spacingMD),
        decoration: BoxDecoration(
          color: isScrolled
              ? PesoTokens.brandGreenDark
              : theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Logo lockup
            PesoLogo.full(
              size: PesoTokens.logoSizeMedium,
              showTagline: false,
              wordmarkStyle: PesoTokens.headlineSmall.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isScrolled ? Colors.white : PesoTokens.textPrimary,
              ),
            ),
            const SizedBox(width: PesoTokens.spacingMD),
            // Navigation pills
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (
                    int i = 0;
                    i < AdaptiveNavBar._destinations.length;
                    i++
                  ) ...[
                    if (i > 0) const SizedBox(width: PesoTokens.space2),
                    _DesktopNavPill(
                      destination: AdaptiveNavBar._destinations[i],
                      isActive:
                          activeIndex == AdaptiveNavBar._destinations[i].index,
                      isDark: isScrolled,
                      onTap: () =>
                          onTabSelected(AdaptiveNavBar._destinations[i].index),
                    ),
                  ],
                ],
              ),
            ),
            // Auth actions
            if (showAuthActions) ...[
              const SizedBox(width: PesoTokens.spacingMD),
              _AuthActions(
                onRegisterTap: onRegisterTap,
                onLoginTap: onLoginTap,
                isDark: isScrolled,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DesktopNavPill extends StatelessWidget {
  const _DesktopNavPill({
    required this.destination,
    required this.isActive,
    this.isDark = false,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PesoTokens.navTransitionDuration,
      curve: PesoTokens.navTransitionCurve,
      decoration: BoxDecoration(
        color: isActive
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : PesoTokens.brandGreenLight)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PesoTokens.space2,
              vertical: PesoTokens.spacingSM,
            ),
            child: Text(
              destination.label,
              style: PesoTokens.navLabel.copyWith(
                color: isDark
                    ? Colors.white
                    : (isActive
                          ? PesoTokens.brandGreenDark
                          : PesoTokens.textSecondary),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabletNavBar extends StatelessWidget {
  const _TabletNavBar({
    required this.activeIndex,
    required this.onTabSelected,
    this.onRegisterTap,
    this.onLoginTap,
    required this.showAuthActions,
    required this.isScrolled,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onLoginTap;
  final bool showAuthActions;
  final bool isScrolled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: AnimatedContainer(
        duration: PesoTokens.durationMedium,
        curve: PesoTokens.curveStandard,
        height: PesoTokens.headerHeightCompact,
        padding: const EdgeInsets.symmetric(horizontal: PesoTokens.spacingLG),
        decoration: BoxDecoration(
          color: isScrolled
              ? PesoTokens.brandGreenDark
              : theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Compact logo
            PesoLogo.full(
              size: PesoTokens.logoSizeSmall,
              showTagline: false,
              wordmark: 'JobKonek',
              wordmarkStyle: PesoTokens.headlineSmall.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isScrolled ? Colors.white : PesoTokens.textPrimary,
              ),
            ),
            const SizedBox(width: PesoTokens.spacingLG),
            // Navigation pills (compact)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (
                      int i = 0;
                      i < AdaptiveNavBar._destinations.length;
                      i++
                    ) ...[
                      if (i > 0) const SizedBox(width: PesoTokens.space2),
                      _DesktopNavPill(
                        destination: AdaptiveNavBar._destinations[i],
                        isActive:
                            activeIndex ==
                            AdaptiveNavBar._destinations[i].index,
                        isDark: isScrolled,
                        onTap: () => onTabSelected(
                          AdaptiveNavBar._destinations[i].index,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Auth actions (compact)
            if (showAuthActions) ...[
              const SizedBox(width: PesoTokens.spacingLG),
              _AuthActions(
                onRegisterTap: onRegisterTap,
                onLoginTap: onLoginTap,
                compact: true,
                isDark: isScrolled,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MobileNavBar extends StatelessWidget implements PreferredSizeWidget {
  const _MobileNavBar({
    required this.activeIndex,
    required this.onTabSelected,
    this.onRegisterTap,
    this.onLoginTap,
    required this.showAuthActions,
    required this.isScrolled,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onLoginTap;
  final bool showAuthActions;
  final bool isScrolled;

  @override
  Size get preferredSize =>
      const Size.fromHeight(PesoTokens.headerHeightCompact);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: AnimatedContainer(
        duration: PesoTokens.durationMedium,
        curve: PesoTokens.curveStandard,
        height: PesoTokens.headerHeightCompact,
        padding: const EdgeInsets.symmetric(horizontal: PesoTokens.spacingMD),
        decoration: BoxDecoration(
          color: isScrolled
              ? PesoTokens.brandGreenDark
              : theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Compact logo
            PesoLogo.full(
              size: PesoTokens.logoSizeSmall,
              showTagline: false,
              wordmark: 'JobKonek',
              wordmarkStyle: PesoTokens.headlineSmall.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isScrolled ? Colors.white : PesoTokens.textPrimary,
              ),
            ),
            const Spacer(),
            if (showAuthActions)
              PopupMenuButton<int>(
                tooltip: 'Account options',
                icon: Icon(
                  Icons.account_circle_outlined,
                  color: isScrolled
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                onSelected: (value) {
                  if (value == 0) onRegisterTap?.call();
                  if (value == 1) onLoginTap?.call();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<int>(value: 0, child: Text('Register')),
                  PopupMenuItem<int>(value: 1, child: Text('Log in')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom navigation bar for mobile - primary navigation on small screens.
class MobileBottomNavBar extends StatelessWidget {
  const MobileBottomNavBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        height: PesoTokens.bottomNavHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: activeIndex,
          onDestinationSelected: onTabSelected,
          height: PesoTokens.bottomNavHeight,
          backgroundColor: Colors.transparent,
          indicatorColor: PesoTokens.brandGreenLight,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
          ),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          animationDuration: PesoTokens.navTransitionDuration,
          destinations: [
            for (final dest in AdaptiveNavBar._destinations)
              NavigationDestination(
                icon: Icon(
                  dest.icon,
                  size: 24,
                  color: activeIndex == dest.index
                      ? PesoTokens.brandGreenDark
                      : PesoTokens.textMuted,
                ),
                selectedIcon: Icon(
                  dest.icon,
                  size: 24,
                  color: PesoTokens.brandGreenDark,
                ),
                label: dest.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthActions extends StatelessWidget {
  const _AuthActions({
    this.onRegisterTap,
    this.onLoginTap,
    this.compact = false,
    this.isDark = false,
  });

  final VoidCallback? onRegisterTap;
  final VoidCallback? onLoginTap;
  final bool compact;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final register =
        onRegisterTap ??
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const _AuthPagePlaceholder(initialIsLogin: false),
          ),
        );
    final login =
        onLoginTap ??
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const _AuthPagePlaceholder(initialIsLogin: true),
          ),
        );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: register,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : PesoTokens.textPrimary,
              side: BorderSide(
                color: isDark ? Colors.white54 : theme.dividerColor,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: PesoTokens.spacingMD,
                vertical: PesoTokens.spacingSM,
              ),
            ),
            child: Text(
              'Register',
              style: PesoTokens.labelLarge.copyWith(
                color: isDark ? Colors.white : PesoTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: PesoTokens.spacingSM),
          FilledButton(
            onPressed: login,
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? Colors.white : PesoTokens.brandGreen,
              foregroundColor: isDark
                  ? PesoTokens.brandGreenDark
                  : PesoTokens.textOnGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: PesoTokens.spacingMD,
                vertical: PesoTokens.spacingSM,
              ),
            ),
            child: Text(
              'Login',
              style: PesoTokens.labelLarge.copyWith(
                color: isDark
                    ? PesoTokens.brandGreenDark
                    : PesoTokens.textOnGreen,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: register,
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : PesoTokens.textPrimary,
            side: BorderSide(
              color: isDark ? Colors.white54 : theme.dividerColor,
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: PesoTokens.spacingLG,
              vertical: PesoTokens.spacingMD,
            ),
          ),
          child: Text(
            'Register',
            style: PesoTokens.buttonMedium.copyWith(
              color: isDark ? Colors.white : PesoTokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: PesoTokens.spacingMD),
        FilledButton(
          onPressed: login,
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? Colors.white : PesoTokens.brandGreen,
            foregroundColor: isDark
                ? PesoTokens.brandGreenDark
                : PesoTokens.textOnGreen,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PesoTokens.radiusButton),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: PesoTokens.spacingLG,
              vertical: PesoTokens.spacingMD,
            ),
          ),
          child: Text(
            'Login',
            style: PesoTokens.buttonMedium.copyWith(
              color: isDark ? PesoTokens.brandGreenDark : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// Placeholder - will be replaced by actual AuthPage import
class _AuthPagePlaceholder extends StatelessWidget {
  const _AuthPagePlaceholder({required this.initialIsLogin});
  final bool initialIsLogin;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('Auth: ${initialIsLogin ? "Login" : "Register"}')),
  );

  // This will be fixed when we update the imports in reusable_ui.dart
}

class _NavDestination {
  const _NavDestination({
    required this.index,
    required this.label,
    required this.icon,
  });
  final int index;
  final String label;
  final IconData icon;
}
