import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_services/auth_service.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/register_ui.dart';

void main() {
  testWidgets('registration name and phone fields reject unsupported characters while typing', (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RegisterForm(
            pesoGreen: Colors.green,
            isLight: true,
            onSwitchToLogin: () {},
            onProceedToOnboarding: (_) {},
            onEmailVerificationRequired: (_) {},
          ),
        ),
      ),
    ));

    Finder field(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );

    await tester.enterText(field('First Name'), 'Anne123<>');
    await tester.pump();
    expect(tester.widget<TextField>(field('First Name')).controller!.text, 'Anne');

    await tester.enterText(field('Last Name'), "Dela-Cruz 123!");
    await tester.pump();
    expect(tester.widget<TextField>(field('Last Name')).controller!.text, 'Dela-Cruz ');

    await tester.enterText(field('Phone Number (optional)'), '0917ABC1234567');
    await tester.pump();
    expect(tester.widget<TextField>(field('Phone Number (optional)')).controller!.text, '09171234567');
    expect(tester.takeException(), isNull);
  });

  group('Philippine mobile number validation', () {
    test('accepts local and Philippine international mobile formats', () {
      expect(AuthService.isValidPhilippineMobileNumber('09171234567'), isTrue);
      expect(AuthService.normalizePhoneNumber('0917 123 4567'), '+639171234567');
      expect(AuthService.normalizePhoneNumber('(0917) 123-4567'), '+639171234567');
      expect(AuthService.normalizePhoneNumber('+639171234567'), '+639171234567');
      expect(AuthService.normalizePhoneNumber('639171234567'), '+639171234567');
      expect(AuthService.normalizePhoneNumber('9171234567'), '+639171234567');
    });

    test('rejects foreign codes, letters, landlines, and invalid lengths', () {
      for (final value in [
        '+12025550123',
        '0917123456',
        '091712345678',
        '0412345678',
        '0917ABC4567',
        '+63 917 123 4567 ext 2',
      ]) {
        expect(AuthService.isValidPhilippineMobileNumber(value), isFalse, reason: value);
      }
      expect(
        () => AuthService.normalizePhoneNumber('+12025550123'),
        throwsFormatException,
      );
    });

    test('empty phone stays optional', () {
      expect(AuthService.normalizePhoneNumber('  '), isEmpty);
      expect(AuthService.isValidPhilippineMobileNumber(''), isFalse);
    });
  });

  group('registration name validation', () {
    test('allows multi-part and Unicode names', () {
      for (final name in ['Maria Santos', "Ma. Angel O'Neil", 'Juan Dela-Cruz', String.fromCharCodes([209, 111, 114, 97, 32, 80, 101, 241, 97]), String.fromCharCodes([26446, 26126])]) {
        expect(AuthService.isValidPersonName(name), isTrue, reason: name);
      }
    });

    test('rejects blank names, digits, symbols, and excessive length', () {
      for (final name in ['', '   ', 'Juan2', '<Admin>', 'John@Doe', 'A' * 81]) {
        expect(AuthService.isValidPersonName(name), isFalse, reason: name);
      }
    });
  });
}
