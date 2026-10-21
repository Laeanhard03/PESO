import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_settings_tab.dart';

void main() {
  testWidgets('settings tab fits a 360px viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserSettingsTab(
            selectedLanguage: 'English',
            onLanguageChanged: (_) {},
            emailNotifications: true,
            onEmailNotificationsChanged: (_) {},
            appNotifications: true,
            onAppNotificationsChanged: (_) {},
            translate: (value) => value,
            primary: Colors.green,
            textDark: Colors.black,
            textLight: Colors.grey,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
