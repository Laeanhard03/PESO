import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_job_feed_tab.dart';

void main() {
  testWidgets(
    'selected role shows translated details and retains original requirements',
    (tester) async {
      tester.view.physicalSize = const Size(1060, 1450);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final role = <String, dynamic>{
        'id': '507f191e810c19729de860ea',
        'title': 'Welder',
        'company': 'Public Employer',
        'location': 'Rodriguez, Rizal',
        'salary': 'PHP 22,000',
        'type': 'Full-time',
        'vacancies': '1',
        'match': 0,
        'description': 'Must have TESDA NC II.',
        'reqs': <String>['TESDA NC II'],
        'image': '',
        'category': 'walk_in_application',
        'status': 'active',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserJobFeedTab(
              userName: 'Demo User',
              availableJobs: [role],
              selectedJob: role,
              selectedLanguage: 'Tagalog',
              translatedJob: const {
                'title': 'Manghihinang',
                'description': 'Kailangan ang TESDA NC II.',
                'requirements': ['TESDA NC II'],
              },
              onSelectJob: (_) {},
              onEvaluateJob: (_) {},
              translate: (value) => value,
              primary: Colors.green,
              textDark: Colors.black,
              textLight: Colors.grey,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('Manghihinang'), findsWidgets);
      expect(find.text('Kailangan ang TESDA NC II.'), findsWidgets);
      expect(
        find.text('Original English description & requirements'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
