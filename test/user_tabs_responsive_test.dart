import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_ui.dart';
import 'package:peso_prototype/peso_ui/User/user_ai_profile_tab.dart';
import 'package:peso_prototype/peso_ui/User/user_outcomes_tab.dart';
import 'package:peso_prototype/peso_ui/User/user_settings_tab.dart';
import 'package:peso_prototype/peso_ui/User/user_account_tab.dart';

void main() {
  testWidgets('compact dashboard menu opens all non-home screens without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: UserProfile()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    final destinations = <Map<String, Object>>[
      {'label': 'Outcomes', 'value': 2, 'type': UserOutcomesTab},
      {'label': 'AI Profile', 'value': 1, 'type': UserAiProfileTab},
      {'label': 'Settings', 'value': 3, 'type': UserSettingsTab},
      {'label': 'My Account', 'value': 4, 'type': UserAccountTab},
    ];

    for (final destination in destinations) {
      final label = destination['label'];
      await tester.tap(find.byTooltip('Open dashboard navigation'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      final menuEntry = find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuItem<int> &&
            widget.value == destination['value'],
      );
      expect(menuEntry, findsOneWidget,
          reason: 'menu entry $label should be visible');

      await tester.tap(menuEntry);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byType(destination['type'] as Type),
        findsOneWidget,
        reason: 'navigation should open $label',
      );
      final screenException = tester.takeException();
      if (screenException != null) {
        debugPrint('CAPTURED_SCREEN_EXCEPTION ($label): $screenException');
      }
      expect(screenException, isNull, reason: 'screen $label');
    }
  });
}
