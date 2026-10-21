import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:peso_prototype/peso_ui/Admin/gemini_api_key_management_section.dart';

class FakeGeminiKeyManagementApi implements GeminiKeyManagementApi {
  final List<Map<String, dynamic>> records = <Map<String, dynamic>>[];
  final List<String> calls = <String>[];
  bool activated = false;
  String? lastCreatedKey;
  String? lastUpdatedKey;
  int testCalls = 0;
  int deleteCalls = 0;
  bool failSave = false;
  Map<String, dynamic>? modelQuota;

  Map<String, dynamic> _metadata(String id, String label, String key) =>
      <String, dynamic>{
        'id': id,
        'label': label,
        'maskedSuffix': '••••${key.substring(key.length - 4)}',
        'enabled': true,
        'health': 'ready',
        'cooldownUntil': null,
        'lastUsedAt': null,
        'lastTestedAt': null,
        'lastErrorCategory': null,
        'createdAt': '2026-10-18T00:00:00.000Z',
        'updatedAt': '2026-10-18T00:00:00.000Z',
      };

  @override
  Future<Map<String, dynamic>> listKeys() async => <String, dynamic>{
    'ok': true,
    'keys': records.map((e) => Map<String, dynamic>.from(e)).toList(),
    'managedPoolActivated': activated,
    'legacyFallbackConfigured': !activated,
    'model': 'gemini-3.8-flash',
    'modelQuota': modelQuota,
  };

  @override
  Future<Map<String, dynamic>> createKey({
    required String label,
    required String apiKey,
  }) async {
    calls.add('create');
    if (failSave) throw StateError('Server rejected the submitted key.');
    lastCreatedKey = apiKey;
    activated = true;
    final metadata = _metadata('key-${records.length + 1}', label, apiKey);
    records.add(metadata);
    return <String, dynamic>{'ok': true, 'key': metadata};
  }

  @override
  Future<Map<String, dynamic>> updateKey(
    String id, {
    String? label,
    String? apiKey,
  }) async {
    calls.add('update');
    lastUpdatedKey = apiKey;
    final index = records.indexWhere((item) => item['id'] == id);
    if (index < 0) throw StateError('Not found');
    final old = records[index];
    final key = apiKey ?? 'fake-default-key-0000';
    records[index] = _metadata(id, label ?? old['label'] as String, key)
      ..['enabled'] = old['enabled'];
    return <String, dynamic>{'ok': true, 'key': records[index]};
  }

  @override
  Future<Map<String, dynamic>> setKeyEnabled(
    String id, {
    required bool enabled,
  }) async {
    calls.add('toggle');
    final index = records.indexWhere((item) => item['id'] == id);
    if (index < 0) throw StateError('Not found');
    records[index]['enabled'] = enabled;
    records[index]['health'] = enabled ? 'ready' : 'disabled';
    return <String, dynamic>{'ok': true, 'key': records[index]};
  }

  @override
  Future<Map<String, dynamic>> deleteKey(String id) async {
    calls.add('delete');
    deleteCalls += 1;
    records.removeWhere((item) => item['id'] == id);
    return <String, dynamic>{'ok': true, 'deleted': true};
  }

  @override
  Future<Map<String, dynamic>> testKey(String id) async {
    calls.add('test');
    testCalls += 1;
    return <String, dynamic>{
      'ok': true,
      'test': <String, dynamic>{
        'passed': true,
        'category': 'test_success',
        'retryAfterSeconds': null,
        'testedAt': '2026-10-18T00:00:00.000Z',
      },
    };
  }
}

class RecordingGeminiHttpClient extends http.BaseClient {
  final List<http.BaseRequest> requests = <http.BaseRequest>[];
  String responseBody =
      '{"ok":true,"keys":[],"managedPoolActivated":false,"legacyFallbackConfigured":false}';
  int responseStatus = 200;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(responseBody)),
      responseStatus,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

void main() {
  testWidgets(
    'key editor renders across compact, tablet and desktop widths without overflow',
    (WidgetTester tester) async {
      final api = FakeGeminiKeyManagementApi();
      for (final size in <Size>[
        const Size(360, 800),
        const Size(768, 1024),
        const Size(1366, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GeminiApiKeyManagementSection(api: api)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Gemini API Keys'), findsOneWidget);
        expect(find.byKey(const Key('gemini-key-value-field')), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );

  testWidgets(
    'new key form obscures input and clears key text after save; list displays masked metadata only',
    (WidgetTester tester) async {
      final api = FakeGeminiKeyManagementApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GeminiApiKeyManagementSection(api: api)),
        ),
      );
      await tester.pumpAndSettle();

      final keyFieldFinder = find.byKey(const Key('gemini-key-value-field'));
      expect(tester.widget<TextField>(keyFieldFinder).obscureText, isTrue);
      const fakeKey = 'fake-gemini-key-for-widget-test-1234';
      await tester.enterText(
        find.byKey(const Key('gemini-key-label-field')),
        'Main key',
      );
      await tester.enterText(keyFieldFinder, fakeKey);
      await tester.tap(find.text('Save Key'));
      await tester.pumpAndSettle();

      expect(api.lastCreatedKey, fakeKey);
      expect(
        tester.widget<TextField>(keyFieldFinder).controller!.text,
        isEmpty,
      );
      expect(find.text('••••1234'), findsOneWidget);
      expect(find.text(fakeKey), findsNothing);
      expect(find.text('Main key'), findsOneWidget);
    },
  );

  testWidgets(
    'failed save does not display submitted key in the visible error state',
    (WidgetTester tester) async {
      final api = FakeGeminiKeyManagementApi()..failSave = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GeminiApiKeyManagementSection(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      const fakeKey = 'fake-gemini-key-failure-test-9876';
      await tester.enterText(
        find.byKey(const Key('gemini-key-label-field')),
        'Bad key',
      );
      await tester.enterText(
        find.byKey(const Key('gemini-key-value-field')),
        fakeKey,
      );
      await tester.tap(find.text('Save Key'));
      await tester.pumpAndSettle();
      expect(find.text(fakeKey), findsNothing);
    },
  );

  testWidgets(
    'testing a key requires an explicit quota/cost confirmation before the API call',
    (WidgetTester tester) async {
      final api = FakeGeminiKeyManagementApi()
        ..records.add(<String, dynamic>{
          'id': 'key-1',
          'label': 'Stored key',
          'maskedSuffix': '••••ABCD',
          'enabled': true,
          'health': 'ready',
          'cooldownUntil': null,
          'lastUsedAt': null,
          'lastTestedAt': null,
          'lastErrorCategory': null,
        });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GeminiApiKeyManagementSection(api: api)),
        ),
      );
      await tester.pumpAndSettle();

      final testButton = find.byKey(const Key('gemini-key-test-key-1'));
      await tester.ensureVisible(testButton);
      await tester.pumpAndSettle();
      await tester.tap(testButton);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('may consume API quota or incur usage charges'),
        findsOneWidget,
      );
      expect(api.testCalls, 0);
      await tester.tap(find.text('Send One Test Request'));
      await tester.pumpAndSettle();
      expect(api.testCalls, 1);
    },
  );

  testWidgets(
    'delete needs confirmation and does not execute before confirming',
    (WidgetTester tester) async {
      final api = FakeGeminiKeyManagementApi()
        ..records.add(<String, dynamic>{
          'id': 'key-1',
          'label': 'Stored key',
          'maskedSuffix': '••••ABCD',
          'enabled': true,
          'health': 'ready',
          'cooldownUntil': null,
          'lastUsedAt': null,
          'lastTestedAt': null,
          'lastErrorCategory': null,
        });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GeminiApiKeyManagementSection(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      final deleteButton = find.byKey(const Key('gemini-key-delete-key-1'));
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(api.deleteCalls, 0);
      await tester.tap(find.text('Remove Key'));
      await tester.pumpAndSettle();
      expect(api.deleteCalls, 1);
    },
  );

  test(
    'Admin key GET requests must not carry a JSON body in browser fetch',
    () {
      final source = File(
        'lib/peso_ui/Admin/gemini_api_key_management_section.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('if (body != null)'),
        reason: 'Only methods with an explicit body should serialize one.',
      );
      expect(
        source,
        isNot(contains('..body = jsonEncode(body ?? <String, dynamic>{})')),
        reason:
            'An unconditional {} body makes browser fetch reject GET requests.',
      );
    },
  );

  test(
    'real Gemini admin transport sends bodyless GET and JSON only for writes',
    () async {
      final client = RecordingGeminiHttpClient();
      final api = PesoGeminiKeyAdminApi(
        client: client,
        tokenProvider: () async => 'fake-firebase-token-for-transport-test',
      );

      await api.listKeys();
      expect(client.requests, hasLength(1));
      final listRequest = client.requests.single as http.Request;
      expect(listRequest.method, 'GET');
      expect(listRequest.body, isEmpty);
      expect(listRequest.headers.containsKey('content-type'), isFalse);

      client.responseBody =
          '{"ok":true,"key":{"id":"507f1f77bcf86cd799439011"}}';
      await api.createKey(
        label: 'Transport test key',
        apiKey: 'fake-gemini-key-for-transport-test-1234',
      );
      expect(client.requests, hasLength(2));
      final createRequest = client.requests.last as http.Request;
      expect(createRequest.method, 'POST');
      expect(jsonDecode(createRequest.body), <String, dynamic>{
        'label': 'Transport test key',
        'apiKey': 'fake-gemini-key-for-transport-test-1234',
      });
      expect(createRequest.headers['content-type'], 'application/json');
    },
  );

  testWidgets('model quota status is visible without exposing key contents', (
    tester,
  ) async {
    final api = FakeGeminiKeyManagementApi()
      ..modelQuota = {
        'model': 'gemini-3.8-flash',
        'scope': 'daily',
        'metric': 'RPD',
        'quotaUntil': '2099-01-01T08:00:00.000Z',
        'retryAfterSeconds': 3600,
      };
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GeminiApiKeyManagementSection(api: api)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const Key('gemini-project-quota-warning')),
      findsOneWidget,
    );
    expect(find.textContaining('midnight Pacific Time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
