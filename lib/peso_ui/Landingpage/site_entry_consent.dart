import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../Login_register_pages/privacy_notice.dart';

class SiteNoticeDecision {
  const SiteNoticeDecision({required this.remember});

  final bool remember;
}

class SiteEntryNoticeDialog extends StatefulWidget {
  const SiteEntryNoticeDialog({
    super.key,
    this.initialTab = 0,
    this.initialRemember = false,
  });

  final int initialTab;
  final bool initialRemember;

  static Future<SiteNoticeDecision?> show(
    BuildContext context, {
    int initialTab = 0,
    bool initialRemember = false,
  }) {
    return showDialog<SiteNoticeDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SiteEntryNoticeDialog(
        initialTab: initialTab,
        initialRemember: initialRemember,
      ),
    );
  }

  @override
  State<SiteEntryNoticeDialog> createState() => _SiteEntryNoticeDialogState();
}

class _SiteEntryNoticeDialogState extends State<SiteEntryNoticeDialog> {
  late int _selectedTab;
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1).toInt();
    _remember = widget.initialRemember;
  }

  String get _title =>
      _selectedTab == 0 ? 'Privacy Notice' : 'Terms and Conditions';

  String get _policyText =>
      _selectedTab == 0 ? pesoPrivacyNoticeText : pesoTermsAndConditionsText;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = math.max(0.0, math.min(720.0, screen.width - 24)).toDouble();
    final height = math
        .max(260.0, math.min(760.0, screen.height - 24))
        .toDouble();

    return Dialog(
      key: const Key('site-entry-notice-dialog'),
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxWidth: 720, maxHeight: height),
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                color: const Color(0xFF174B37),
                child: Row(
                  children: [
                    const Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.white,
                      size: 25,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'PESO JOBKONEK • PROTOTYPE NOTICE',
                            style: TextStyle(
                              color: Color(0xFFD8E7DE),
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      key: const Key('site-notice-privacy-tab'),
                      label: const Text('Privacy Notice'),
                      selected: _selectedTab == 0,
                      onSelected: (_) => setState(() => _selectedTab = 0),
                      selectedColor: const Color(0xFFDCEBE2),
                    ),
                    ChoiceChip(
                      key: const Key('site-notice-terms-tab'),
                      label: const Text('Terms & Conditions'),
                      selected: _selectedTab == 1,
                      onSelected: (_) => setState(() => _selectedTab = 1),
                      selectedColor: const Color(0xFFDCEBE2),
                    ),
                  ],
                ),
              ),
              if (_selectedTab == 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5D9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE9D49A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFF785A16),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Prototype status: the responsible LGU has not yet confirmed the official data controller, privacy contact, and retention schedule.',
                          style: TextStyle(
                            color: Color(0xFF624C1B),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: const Key('site-notice-policy-scroll'),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                    child: SelectableText(
                      _policyText,
                      style: const TextStyle(
                        color: Color(0xFF33483E),
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE1E8E3)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      key: const Key('site-notice-remember-checkbox'),
                      value: _remember,
                      onChanged: (value) =>
                          setState(() => _remember = value == true),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        "Don't show this again",
                        style: TextStyle(
                          color: Color(0xFF33483E),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'This website acknowledgement does not replace the separate consent required during registration.',
                        style: TextStyle(
                          color: Color(0xFF65766D),
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('site-notice-accept'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF174B37),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(SiteNoticeDecision(remember: _remember)),
                        child: const Text(
                          'I UNDERSTAND & ACCEPT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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
    );
  }
}

class CookieConsentBanner extends StatelessWidget {
  const CookieConsentBanner({
    super.key,
    required this.onAcceptAll,
    required this.onEssentialOnly,
    required this.onViewPrivacy,
  });

  final VoidCallback onAcceptAll;
  final VoidCallback onEssentialOnly;
  final VoidCallback onViewPrivacy;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;

    final description = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.cookie_outlined, color: Color(0xFF174B37), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cookies & browser storage',
                style: TextStyle(
                  color: Color(0xFF17352B),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 5),
        Text(
          'We use essential storage for sign-in and saved choices. Optional analytics and advertising cookies are off in this prototype.',
          style: TextStyle(
            color: Color(0xFF52675D),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );

    final privacyLink = TextButton(
      key: const Key('cookie-learn-more'),
      onPressed: onViewPrivacy,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF23664C),
        minimumSize: const Size(0, 24),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: const Text('Privacy details'),
    );

    final choices = Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('cookie-essential-only'),
            onPressed: onEssentialOnly,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF174B37),
              side: const BorderSide(color: Color(0xFFB8CFC1)),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Essential only', maxLines: 1, softWrap: false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            key: const Key('cookie-accept-all'),
            onPressed: onAcceptAll,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF174B37),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Accept all', maxLines: 1, softWrap: false),
          ),
        ),
      ],
    );

    return Material(
      key: const Key('cookie-consent-banner'),
      color: Colors.white,
      elevation: 18,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFDCE5DE))),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          description,
                          const SizedBox(height: 4),
                          privacyLink,
                          const SizedBox(height: 4),
                          choices,
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: description),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 300,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                privacyLink,
                                const SizedBox(height: 4),
                                choices,
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
