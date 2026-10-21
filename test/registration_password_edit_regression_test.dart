import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/register_ui.dart';

void main() {
  testWidgets('pasted registration password can be edited and backspaced', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RegisterForm(
              pesoGreen: const Color(0xFF236349),
              isLight: false,
              onSwitchToLogin: () {},
              onProceedToOnboarding: (_) {},
              onEmailVerificationRequired: (_) {},
            ),
          ),
        ),
      ),
    );
    final password = find.byKey(const Key('registration-password-field'));
    await tester.ensureVisible(password);
    await tester.enterText(password, 'PastedPassword123');
    await tester.pump();
    expect(
      tester.widget<TextField>(password).controller!.text,
      'PastedPassword123',
    );
    // Reproduce the browser's selection after pasting, then delete one char.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'PastedPassword123',
        selection: TextSelection.collapsed(offset: 17),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(
      tester.widget<TextField>(password).controller!.text,
      'PastedPassword12',
    );
    await tester.enterText(password, 'NewPassword!');
    await tester.pump();
    expect(tester.widget<TextField>(password).controller!.text, 'NewPassword!');
    expect(tester.takeException(), isNull);
  });
}
