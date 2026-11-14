import 'package:flutter_test/flutter_test.dart';

import '../lib/peso_ui/Admin/admin_models.dart';

void main() {
  group('Admin match status models', () {
    test(
      'all supported match states retain their labels and status colors',
      () {
        expect(
          kMatchStyles.keys,
          containsAll(['matched', 'pending', 'not_matched']),
        );
        expect(kMatchStyles['matched']!.label, 'Matched to a Job');
        expect(kMatchStyles['pending']!.label, 'Resume Under Review');
        expect(
          kMatchStyles['not_matched']!.label,
          'Users with Low Qualification',
        );
      },
    );

    test('applicant fields remain explicit and unchanged', () {
      final registered = DateTime(2026, 10, 28);
      final applicant = Applicant(
        uid: 'synthetic-user',
        id: 7,
        name: 'Sample Applicant',
        barangay: 'San Jose',
        targetJob: 'Data Entry Clerk',
        registeredDate: registered,
        yearsExperience: 2,
        resumeSubmitted: true,
        formSubmitted: false,
        matchStatus: 'pending',
        matchedJobsCount: 1,
        resumeFileName: 'sample-resume.pdf',
      );

      expect(applicant.uid, 'synthetic-user');
      expect(applicant.id, 7);
      expect(applicant.registeredDate, registered);
      expect(applicant.resumeSubmitted, isTrue);
      expect(applicant.formSubmitted, isFalse);
      expect(applicant.matchStatus, 'pending');
      expect(applicant.matchedJobsCount, 1);
    });

    test('concerns default to unresolved and can be resolved', () {
      final concern = Concern(
        id: 12,
        applicantName: 'Sample Applicant',
        barangay: 'San Jose',
        targetJob: 'Data Entry Clerk',
        message: 'Please review my job match.',
        submittedDate: DateTime(2026, 10, 28),
      );

      expect(concern.resolved, isFalse);
      concern.resolved = true;
      expect(concern.resolved, isTrue);
    });
  });

  group('Admin account action policy', () {
    test('another administrator can be deleted while admin mutations stay protected', () {
      const currentUid = 'current-admin';
      const otherAdmin = <String, dynamic>{
        'uid': 'other-admin',
        'role': 'admin',
        'customAdmin': true,
      };

      expect(
        isProtectedAdminAccountMutation(otherAdmin, currentUid: currentUid),
        isTrue,
      );
      expect(
        canDeleteManagedAccount(
          uid: 'other-admin',
          currentUid: currentUid,
          busy: false,
          profileStoreReady: true,
        ),
        isTrue,
      );
    });

    test(
      'only self, busy, missing UID, or unavailable MongoDB block deletion',
      () {
        expect(
          canDeleteManagedAccount(
            uid: 'current-admin',
            currentUid: 'current-admin',
            busy: false,
            profileStoreReady: true,
          ),
          isFalse,
        );
        expect(
          canDeleteManagedAccount(
            uid: '',
            currentUid: 'current-admin',
            busy: false,
            profileStoreReady: true,
          ),
          isFalse,
        );
        expect(
          canDeleteManagedAccount(
            uid: 'other-admin',
            currentUid: 'current-admin',
            busy: true,
            profileStoreReady: true,
          ),
          isFalse,
        );
        expect(
          canDeleteManagedAccount(
            uid: 'other-admin',
            currentUid: 'current-admin',
            busy: false,
            profileStoreReady: false,
          ),
          isFalse,
        );
      },
    );
  });

  test('admin navigation items have unique tabs and stable core sections', () {
    final tabs = kNavItems.map((item) => item.tab).toList();

    expect(tabs.toSet().length, tabs.length);
    expect(tabs, contains(AdminTab.analytics));
    expect(tabs, contains(AdminTab.users));
    expect(tabs, contains(AdminTab.concerns));
    expect(tabs, contains(AdminTab.developmentNotes));
    expect(
      kNavItems
          .firstWhere((item) => item.tab == AdminTab.developmentNotes)
          .label,
      'Development Notepad',
    );
    expect(tabs, contains(AdminTab.jobs));
    expect(tabs, contains(AdminTab.applications));
    expect(tabs, contains(AdminTab.siteContent));
    expect(tabs, contains(AdminTab.settings));
    expect(tabs, contains(AdminTab.profile));
    expect(kNavItems.every((item) => item.label.isNotEmpty), isTrue);
    expect(kNavItems.every((item) => item.title.isNotEmpty), isTrue);
  });
}
