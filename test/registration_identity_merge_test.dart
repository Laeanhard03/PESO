import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_logic/registration_identity_merge.dart';

void main() {
  test('AI preview cannot overwrite existing registered name and contacts', () {
    final registered = <String, String>{
      'firstName': 'QA',
      'lastName': 'Browser Applicant',
      'email': 'registered@example.test',
      'phone': '+639171234567',
    };
    final merged = mergeResumeIdentityForNsrp(registered, {
      'fullName': 'QA Sample Applicant',
      'email': 'wrong@example.test',
      'phoneNumber': '+639999999999',
    });
    expect(merged, registered);
  });

  test('only truly missing registration details may be suggested', () {
    final merged = mergeResumeIdentityForNsrp(
      {'firstName': 'QA', 'lastName': '', 'email': 'signedin@example.test'},
      {
        'fullName': 'QA Sample Applicant',
        'email': 'untrusted@example.test',
        'phoneNumber': '+639181112222',
      },
    );
    expect(merged['firstName'], 'QA');
    expect(merged['lastName'], 'Applicant');
    expect(merged['email'], 'signedin@example.test');
    expect(merged['phone'], '+639181112222');
  });

  test('unknown extracted fields never create fabricated entries', () {
    final merged = mergeResumeIdentityForNsrp(
      {'firstName': 'QA', 'lastName': 'Applicant'},
      {'fullName': '', 'email': '', 'phoneNumber': ''},
    );
    expect(merged, {'firstName': 'QA', 'lastName': 'Applicant'});
  });
}
