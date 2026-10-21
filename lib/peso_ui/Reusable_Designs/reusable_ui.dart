import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'adaptive_nav_bar.dart';
import 'design_tokens.dart';
import '../Landingpage/landingpage_ui.dart';

export 'design_tokens.dart';
export 'animated_entrance.dart';
export 'peso_logo.dart';
export 'adaptive_nav_bar.dart';
export 'hero_section.dart';
export 'cards.dart';

// =====================================================================
// EXPORTED COMPONENT 1: GLOBAL NAV BAR (ANIMATED) - LEGACY
// =====================================================================
/// @deprecated Use AdaptiveNavBar from adaptive_nav_bar.dart instead.
/// This is kept for backward compatibility.
class GlobalNavBar extends StatelessWidget implements PreferredSizeWidget {
  final Color pesoGreen;
  final int activePageIndex;
  final Function(int) onTabSelected;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onLoginTap;
  final bool isScrolled; // Added scroll state

  const GlobalNavBar({
    super.key,
    required this.pesoGreen,
    required this.activePageIndex,
    required this.onTabSelected,
    this.onRegisterTap,
    this.onLoginTap,
    this.isScrolled = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(90);

  @override
  Widget build(BuildContext context) {
    // Delegate to the new AdaptiveNavBar but maintain old API
    return AdaptiveNavBar(
      activeIndex: activePageIndex,
      onTabSelected: onTabSelected,
      onRegisterTap: onRegisterTap,
      onLoginTap: onLoginTap,
      showAuthActions: true,
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
  final ValueChanged<String>? onServiceRequested;

  const GlobalFooter({
    super.key,
    required this.pesoGreen,
    required this.onTabSelected,
    required this.onScrollToTop,
    this.onServiceRequested,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final veryCompact = MediaQuery.sizeOf(context).width < 520;
    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: pesoGreen.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: pesoGreen.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'lib/assets/peso_app_icon.png',
                  width: 68,
                  height: 68,
                  fit: BoxFit.contain,
                ),
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
          style: TextStyle(color: Colors.white70, height: 1.6, fontSize: 15),
        ),
      ],
    );
    final quickLinks = Column(
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
        _buildFooterLink('Jobs', 1),
        _buildFooterLink('Gallery', 2),
        _buildFooterLink('About', 4),
        _buildServiceLink('SEAP', 'SEAP'),
        _buildServiceLink('GIP', 'GIP'),
        _buildOfficialLink(
          'Montalban Local Government',
          'https://montalban.gov.ph/',
        ),
      ],
    );
    final contacts = Column(
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
        _buildFooterContact(
          Icons.info_outline,
          'For current contact details, consult the official Montalban website.',
        ),
        _buildFooterContact(Icons.location_on, 'Montalban, Rizal, Philippines'),
      ],
    );

    return Container(
      width: double.infinity,
      color: PesoTokens.surfaceDark,
      padding: EdgeInsets.only(
        top: compact ? 42 : 80,
        left: compact ? 24 : 80,
        right: compact ? 24 : 80,
        bottom: 40,
      ),
      child: Column(
        children: [
          if (compact) ...[
            brand,
            const SizedBox(height: 36),
            if (veryCompact) ...[
              quickLinks,
              const SizedBox(height: 28),
              contacts,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: quickLinks),
                  const SizedBox(width: 20),
                  Expanded(child: contacts),
                ],
              ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(flex: 2, child: brand),
                const SizedBox(width: 60),
                Expanded(flex: 1, child: quickLinks),
                Expanded(flex: 1, child: contacts),
              ],
            ),
          SizedBox(height: compact ? 36 : 60),
          const Divider(color: Colors.white12),
          const SizedBox(height: 30),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Text(
                '© 2026 Developed by Josh Lander Ferrea. All Rights Reserved.',
                style: TextStyle(color: Colors.white70),
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
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildServiceLink(String label, String code) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: InkWell(
      onTap: () {
        if (onServiceRequested != null) {
          onServiceRequested!(code);
        } else {
          launchUrl(
            Uri.parse('https://peis.philjobnet.gov.ph/register.aspx'),
            mode: LaunchMode.externalApplication,
          );
        }
      },
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _buildOfficialLink(String label, String url) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white70,
        ),
      ),
    ),
  );

  Widget _buildFooterContact(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

// Keep the existing Sidebar/Stat components here as well
Widget buildSidebarItem(
  IconData icon,
  String title,
  bool isActive,
  BuildContext context, {
  bool isLogout = false,
}) {
  return ListTile(
    leading: Icon(
      icon,
      color: isActive
          ? Theme.of(context).colorScheme.secondary
          : Colors.white70,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: isActive
            ? Theme.of(context).colorScheme.secondary
            : Colors.white70,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    onTap: () {
      if (isLogout) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
      }
    },
  );
}

Widget buildStatCard(String title, String count, Color accentColor) {
  return Container(
    width: 250,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 5,
          spreadRadius: 1,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 10),
        Text(
          count,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      ],
    ),
  );
}
