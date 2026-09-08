import 'package:flutter/material.dart';

import 'landingpage_ui.dart';
import 'auth_ui.dart';

// =====================================================================
// EXPORTED COMPONENT 1: GLOBAL NAV BAR (ANIMATED)
// =====================================================================
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
    // Dynamic Colors based on scroll state
    Color bgColor = isScrolled ? pesoGreen : Colors.white;
    Color brandColor = isScrolled ? Colors.white : pesoGreen;
    Color linkColor = isScrolled ? Colors.white70 : Colors.black87;
    Color activeLinkColor = isScrolled ? Colors.white : pesoGreen;
    Color btnOutlinedText = isScrolled ? Colors.white : Colors.black87;
    Color btnOutlinedBorder = isScrolled ? Colors.white : Colors.grey.shade300;
    Color btnElevatedBg = isScrolled ? Colors.white : pesoGreen;
    Color btnElevatedText = isScrolled ? pesoGreen : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isScrolled ? 0.2 : 0.05),
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isScrolled
                          ? Colors.white.withValues(alpha: 0.2)
                          : pesoGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.work, color: brandColor, size: 28),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    'JobKonek',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: brandColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _buildNavLink('Home', 0, linkColor, activeLinkColor),
                  _buildNavLink('Jobs', 1, linkColor, activeLinkColor),
                  _buildNavLink('Gallery', 2, linkColor, activeLinkColor),
                  _buildNavLink('History', 3, linkColor, activeLinkColor),
                  _buildNavLink('About', 4, linkColor, activeLinkColor),
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
                      foregroundColor: btnOutlinedText,
                      side: BorderSide(color: btnOutlinedBorder, width: 2),
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
                      backgroundColor: btnElevatedBg,
                      foregroundColor: btnElevatedText,
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

  Widget _buildNavLink(
    String title,
    int index,
    Color normalColor,
    Color activeColor,
  ) {
    bool isActive = activePageIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: TextButton(
        onPressed: () => onTabSelected(index),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          backgroundColor: isActive
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: isActive ? activeColor : normalColor,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
            fontFamily: 'Roboto', // Change if using a custom font
          ),
          child: Text(title),
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
