import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_logic/registration_identity_merge.dart';

void main() {
  test('only an explicit sex/gender statement is accepted', () {
    expect(explicitResumeSex('Sex: Female\nEducation: Secondary'), 'Female');
    expect(explicitResumeSex('Gender - Other\nPhone: +63'), 'Other');
    expect(explicitResumeSex('Name: Maria Female\nPhotograph: attached'), isNull);
    expect(explicitResumeSex('Title: Mr. Senior Officer'), isNull);
  });
  test('AI predictions alone cannot assert sex', () {
    expect(verifiedResumeSex({'sex': 'Male'}), isNull);
    expect(verifiedResumeSex({'verifiedSexEvidence': {
      'verified': true, 'sex': 'Female', 'sourceQuote': 'Sex: Female',
    }}), 'Female');
    expect(verifiedResumeSex({'verifiedSexEvidence': {
      'verified': false, 'sex': 'Other', 'sourceQuote': 'Gender: Other',
    }}), isNull);
  });
}
