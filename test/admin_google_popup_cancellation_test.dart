import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_ui.dart';

void main() {
  testWidgets('Admin Google popup can be cancelled and admin gate unlocked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pending = Completer<UserCredential>();
    await tester.pumpWidget(
      MaterialApp(home: AdminDashboard(googleSignIn: () => pending.future)),
    );
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 40));
    expect(
      find.text('Cancel Google verification / unlock form'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel Google verification / unlock form'));
    await tester.pump();
    expect(find.text('Continue with Google'), findsOneWidget);
    final googleButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue with Google'),
    );
    expect(googleButton.onPressed, isNotNull);
    expect(find.textContaining('verification was cancelled'), findsOneWidget);

    // Even if a now-invalid pending popup completes with an error, its stale
    // callback cannot disable or navigate away from the admin form.
    pending.completeError(FirebaseAuthException(code: 'popup-closed-by-user'));
    await tester.pump();
    expect(find.text('Protected Admin Area'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
