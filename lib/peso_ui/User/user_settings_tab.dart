import 'package:flutter/material.dart';

import 'user_job_feed_tab.dart'; // Imports FadeSlideEntrance
import 'user_ai_profile_tab.dart'; // Imports SectionWrapper

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: Text(
                  translate('Account Settings'),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FadeSlideEntrance(
                delay: 100,
                child: Text(
                  translate(
                    'Manage your language preferences and system notifications.',
                  ),
                  style: TextStyle(fontSize: 18, color: textLight),
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
                        child: Row(
                          children: [
                            _buildLanguageTab('English', 'English'),
                            _buildLanguageTab('Tagalog', 'Modern Tagalog'),
                            _buildLanguageTab('Taglish', 'Taglish (Mixed)'),
                          ],
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
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Settings saved successfully.'),
                        backgroundColor: primary,
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 22),
                    label: const Text(
                      'Save Preferences',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 24,
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

  Widget _buildLanguageTab(String languageKey, String label) {
    bool isSelected = selectedLanguage == languageKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => onLanguageChanged(languageKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
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
      ),
    );
  }
}
