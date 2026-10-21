import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_ai_profile_tab.dart';

void main() {
  testWidgets('AI profile tab fits a 360px viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final name = TextEditingController(text: 'Job Seeker');
    final title = TextEditingController(text: 'Professional');
    final bio = TextEditingController();
    addTearDown(name.dispose);
    addTearDown(title.dispose);
    addTearDown(bio.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserAiProfileTab(
            nameController: name,
            titleController: title,
            bioController: bio,
            userSkills: const [],
            aiProfileData: const {},
            resumeData: const {},
            pesoFormData: const {},
            artifacts: const [],
            translate: (value) => value,
            primary: Colors.green,
            textDark: Colors.black,
            textLight: Colors.grey,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });
}
