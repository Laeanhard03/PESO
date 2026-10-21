import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_services/onboarding_draft_sync.dart';

void main() {
  late Map<String, String> disk;
  late Map<String, dynamic> remote;
  late bool offline;
  late int writes;
  late OnboardingDraftSync sync;

  setUp(() {
    disk = <String, String>{};
    remote = <String, dynamic>{
      'onboardingRevision': 0,
      'resumeData': <String, dynamic>{},
      'pesoFormData': <String, dynamic>{},
    };
    offline = false;
    writes = 0;
    sync = OnboardingDraftSync(
      read: (key) async => disk[key],
      write: (key, value) async { disk[key] = value; },
      delete: (key) async { disk.remove(key); },
      getProfile: () async {
        if (offline) throw StateError('Simulated offline');
        return {'profile': Map<String, dynamic>.from(remote)};
      },
      post: (data) async {
        if (offline) throw StateError('Simulated offline');
        writes++;
        final revision = data['expectedRevision'] as int;
        if (revision != remote['onboardingRevision']) {
          throw StateError('Unexpected stale write in test');
        }
        for (final field in ['resumeData', 'pesoFormData']) {
          if (data[field] is Map) {
            remote[field] = {
              ...(remote[field] as Map<String, dynamic>),
              ...Map<String, dynamic>.from(data[field] as Map),
            };
          }
        }
        if (data.containsKey('onboardingText')) {
          remote['onboardingText'] = data['onboardingText'];
        }
        remote['onboardingRevision'] = revision + 1;
        remote['onboardingLastMutationId'] = data['mutationId'];
        return {'profile': Map<String, dynamic>.from(remote)};
      },
    );
  });

  tearDown(() => sync.stopRetry());

  test('offline edit encrypts to scoped pending queue and syncs after reconnect',
      () async {
    await sync.rememberProfile('applicant-1', remote);
    offline = true;
    await expectLater(
      sync.save(uid: 'applicant-1', data: {
        'resumeData': {'skills': 'Welding'},
        'pesoFormData': {'dateOfBirth': '2000-02-29'},
      }),
      throwsA(isA<OnboardingDraftQueuedException>()),
    );
    expect(await sync.hasPending('applicant-1'), isTrue);
    expect(await sync.hasPending('other-user'), isFalse);
    expect(writes, 0);
    offline = false;
    expect(await sync.retryPending('applicant-1'), isTrue);
    expect(await sync.hasPending('applicant-1'), isFalse);
    expect(remote['resumeData'], {'skills': 'Welding'});
    expect(remote['pesoFormData'], {'dateOfBirth': '2000-02-29'});
    expect(writes, 1);
  });

  test('overlapping changes remain queued and never overwrite the server',
      () async {
    remote['resumeData'] = {'skills': 'Old skill'};
    await sync.rememberProfile('applicant-1', remote);
    offline = true;
    await expectLater(sync.save(uid: 'applicant-1',
        data: {'resumeData': {'skills': 'User edit'}}),
      throwsA(isA<OnboardingDraftQueuedException>()));
    remote['resumeData'] = {'skills': 'Other device edit'};
    remote['onboardingRevision'] = 2;
    offline = false;
    await expectLater(sync.retryPending('applicant-1'),
      throwsA(isA<OnboardingDraftConflictException>()));
    expect(writes, 0);
    expect(await sync.hasPending('applicant-1'), isTrue);
    expect(remote['resumeData'], {'skills': 'Other device edit'});
  });

  test('disjoint remote edits allow merge with revision compare-and-swap',
      () async {
    remote['resumeData'] = {'skills': 'Old skill'};
    await sync.rememberProfile('applicant-1', remote);
    offline = true;
    await expectLater(sync.save(uid: 'applicant-1',
        data: {'resumeData': {'skills': 'Better skill'}}),
      throwsA(isA<OnboardingDraftQueuedException>()));
    remote['resumeData'] = {'skills': 'Old skill', 'education': 'TVET'};
    remote['onboardingRevision'] = 3;
    offline = false;
    expect(await sync.retryPending('applicant-1'), isTrue);
    expect(remote['resumeData'],
      {'skills': 'Better skill', 'education': 'TVET'});
    expect(remote['onboardingRevision'], 4);
  });

  test('already-committed mutation is acknowledged without duplicate writes',
      () async {
    await sync.rememberProfile('applicant-1', remote);
    offline = true;
    await expectLater(sync.save(uid: 'applicant-1',
        data: {'pesoFormData': {'occupation': 'Welder'}}),
      throwsA(isA<OnboardingDraftQueuedException>()));
    final saved = jsonDecode(disk['peso.form.pending.applicant-1']!)
        as Map<String, dynamic>;
    remote['onboardingLastMutationId'] = saved['id'];
    remote['onboardingRevision'] = 1;
    remote['pesoFormData'] = {'occupation': 'Welder'};
    offline = false;
    expect(await sync.retryPending('applicant-1'), isTrue);
    expect(writes, 0);
    expect(await sync.hasPending('applicant-1'), isFalse);
  });

  test('two overlapping saves serialize; delayed acknowledgement cannot drop newer source',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final localDisk = <String, String>{};
    final localRemote = <String, dynamic>{
      'onboardingRevision': 0,
      'resumeData': <String, dynamic>{},
    };
    var requests = 0;
    final guarded = OnboardingDraftSync(
      read: (key) async => localDisk[key],
      write: (key, value) async { localDisk[key] = value; },
      delete: (key) async { localDisk.remove(key); },
      getProfile: () async => {'profile': Map<String, dynamic>.from(localRemote)},
      post: (payload) async {
        requests++;
        if (requests == 1) {
          started.complete();
          await release.future;
        }
        final revision = payload['expectedRevision'] as int;
        expect(revision, localRemote['onboardingRevision']);
        final changed = payload['resumeData'] as Map<String, dynamic>;
        localRemote['resumeData'] = {
          ...(localRemote['resumeData'] as Map<String, dynamic>),
          ...changed,
        };
        localRemote['onboardingRevision'] = revision + 1;
        localRemote['onboardingLastMutationId'] = payload['mutationId'];
        return {'profile': Map<String, dynamic>.from(localRemote)};
      },
    );
    addTearDown(guarded.stopRetry);
    final first = guarded.save(
      uid: 'applicant-1', data: {'resumeData': {'skills': 'Welding'}});
    await started.future;
    final second = guarded.save(
      uid: 'applicant-1', data: {'resumeData': {'skills': 'Plumbing'}});
    release.complete();
    await Future.wait([first, second]);
    expect(requests, 2);
    expect((localRemote['resumeData'] as Map)['skills'], 'Plumbing');
    expect(await guarded.hasPending('applicant-1'), isFalse);
  });

  test('UID switching cannot send queued documents or edits to a different account',
      () async {
    final localDisk = <String, String>{};
    final guarded = OnboardingDraftSync(
      read: (key) async => localDisk[key],
      write: (key, value) async { localDisk[key] = value; },
      delete: (key) async { localDisk.remove(key); },
      getProfile: () async => throw StateError('must not execute'),
      post: (payload) async => throw StateError('must not execute'),
      activeUid: () async => 'other-user',
    );
    addTearDown(guarded.stopRetry);
    await expectLater(
      guarded.save(uid: 'victim-account',
        data: {'resumeData': {'skills': 'Confidential'}}),
      throwsStateError,
    );
    expect(localDisk, isEmpty);
    expect(await guarded.retryPending('victim-account'), isFalse);
  });

}
