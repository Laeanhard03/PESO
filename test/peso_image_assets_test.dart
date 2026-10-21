import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = <String>[
    'lib/assets/peso_hero_career.jpg',
    'lib/assets/peso_programs_workshop.jpg',
    'lib/assets/peso_about_team.jpg',
    'lib/assets/peso_gallery_conference.jpg',
    'lib/assets/peso_gallery_workspace.jpg',
    'lib/assets/peso_gallery_team.jpg',
    'lib/assets/peso_gallery_meeting.jpg',
    'lib/assets/peso_gallery_event.jpg',
    'lib/assets/peso_gallery_career.jpg',
    'lib/assets/peso_job_default.jpg',
    'lib/assets/peso_job_technology.jpg',
  ];

  for (final asset in assets) {
    test('bundles the persistent PESO image asset: $asset', () async {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(1024), reason: '$asset must contain image bytes');
    });
  }
}
