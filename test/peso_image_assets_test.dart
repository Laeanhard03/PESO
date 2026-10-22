import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = <String>[
    'lib/assets/peso_hero_career.jpg',
    'lib/assets/peso_programs_workshop.jpg',
    'lib/assets/peso_about_team.jpg',
    'lib/assets/peso_about_reference.jpg',
    'lib/assets/peso_cover.jpg',
    'lib/assets/peso_gallery_conference.jpg',
    'lib/assets/peso_gallery_workspace.jpg',
    'lib/assets/peso_gallery_team.jpg',
    'lib/assets/peso_gallery_meeting.jpg',
    'lib/assets/peso_gallery_event.jpg',
    'lib/assets/peso_gallery_career.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_one.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_two.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_tre.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_four.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_five.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_six.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m1.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m15.jpg',
    'lib/assets/peso_job_default.jpg',
    'lib/assets/peso_job_technology.jpg',
    'lib/assets/josh.png',
    'lib/assets/edward.png',
    'lib/assets/cesneros.png',
    'lib/assets/ilaya.jpg',
    'lib/assets/peso_partners/JOLLIBEE LOGO.png',
    'lib/assets/peso_partners/EEI CORPORATION LOGO.png',
    'lib/assets/peso_partners/SAVEMORE.jpg',
    'lib/assets/peso_partners/SAGULITIY.jpg',
    'lib/assets/peso_partners/JRCC.jpg',
    'lib/assets/peso_partners/SHOPWISE.jpg',
    'lib/assets/peso_partners/RUDER SPARK.jpg',
    'lib/assets/peso_partners/OMNICORES.png',
    'lib/assets/peso_partners/ROBINSON.png',
    'lib/assets/peso_partners/EXCEL SOURCE.jpg',
    'lib/assets/peso_partners/SM.png',
    'lib/assets/peso_partners/joBNET.png',
    'lib/assets/peso_partners/PUREGOLD.webp',
    'lib/assets/peso_partners/AVILON.png',
    'lib/assets/peso_partners/XENTRO MALL.jpg',
  ];

  for (final asset in assets) {
    test('bundles the persistent PESO image asset: $asset', () async {
      final data = await rootBundle.load(asset);
      expect(
        data.lengthInBytes,
        greaterThan(1024),
        reason: '$asset must contain image bytes',
      );
    });
  }
}
