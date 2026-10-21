import 'package:flutter/material.dart';

import '../../peso_services/app_toast.dart';

import 'user_job_feed_tab.dart'; // Imports FadeSlideEntrance
import 'user_ai_profile_tab.dart'; // Imports SectionWrapper
import '../Reusable_Designs/peso_premium_ui.dart';

class UserSettingsTab extends StatelessWidget {
  final String selectedLanguage;
  final Function(String) onLanguageChanged;
  final bool emailNotifications;
  final Function(bool) onEmailNotificationsChanged;
  final bool appNotifications;
  final Function(bool) onAppNotificationsChanged;
  final String Function(String) translate;
  final Color primary;
  final Color textDark;
  final Color textLight;

  const UserSettingsTab({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.emailNotifications,
    required this.onEmailNotificationsChanged,
    required this.appNotifications,
    required this.onAppNotificationsChanged,
    required this.translate,
    required this.primary,
    required this.textDark,
    required this.textLight,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;
    final medium = screenWidth < 1024;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : (medium ? 24 : 50)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: PesoPageHeader(
                  title: translate('Account Settings'),
                  description: translate(
                    'Manage your language preferences and system notifications.',
                  ),
                  eyebrow: 'Make JobKonek yours',
                  icon: Icons.tune_rounded,
                  detail: PesoHeaderPill(
                    icon: Icons.translate_rounded,
                    label: 'Language: $selectedLanguage',
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeSlideEntrance(
                delay: 200,
                child: SectionWrapper(
                  title: 'System Language / Wika ng Sistema',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose the language you are most comfortable with.',
                        style: TextStyle(color: textLight, fontSize: 16),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 520;
                            final options = [
                              _buildLanguageTab(
                                'English',
                                'English',
                                expanded: !narrow,
                              ),
                              _buildLanguageTab(
                                'Tagalog',
                                'Modern Tagalog',
                                expanded: !narrow,
                              ),
                              _buildLanguageTab(
                                'Taglish',
                                'Taglish (Mixed)',
                                expanded: !narrow,
                              ),
                            ];
                            return narrow
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: options,
                                  )
                                : Row(children: options);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FadeSlideEntrance(
                delay: 300,
                child: SectionWrapper(
                  title: 'Notification Preferences',
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          title: Text(
                            'Email Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: textDark,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Receive success emails when you pass an AI qualification match.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          value: emailNotifications,
                          activeThumbColor: primary,
                          activeTrackColor: primary.withValues(alpha: 0.3),
                          onChanged: onEmailNotificationsChanged,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          title: Text(
                            'In-App Alerts',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: textDark,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Get instant platform alerts for TESDA upskilling recommendations.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          value: appNotifications,
                          activeThumbColor: primary,
                          activeTrackColor: primary.withValues(alpha: 0.3),
                          onChanged: onAppNotificationsChanged,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FadeSlideEntrance(
                delay: 400,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => AppToast.success(
                      context,
                      'Settings saved successfully.',
                    ),
                    icon: Icon(Icons.check_rounded, size: compact ? 18 : 22),
                    label: Text(
                      'Save Preferences',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 16 : 18,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 16 : 40,
                        vertical: compact ? 18 : 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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

  Widget _buildLanguageTab(
    String languageKey,
    String label, {
    bool expanded = true,
  }) {
    final isSelected = selectedLanguage == languageKey;
    final option = GestureDetector(
      onTap: () => onLanguageChanged(languageKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? primary : textLight,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
    return expanded ? Expanded(child: option) : option;
  }
}
