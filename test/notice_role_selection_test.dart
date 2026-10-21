import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/notice_role_selector.dart';
import 'package:peso_prototype/peso_ui/User/notice_role_comparison_dialog.dart';

void main() {
  const roles = <Map<String, dynamic>>[
    {'id': 'w', 'title': 'WELDER — JCRCC',
     'requirementScope': 'unattributed_notice'},
    {'id': 'e', 'title': 'EHS STAFF — JCRCC',
     'requirementScope': 'explicit_role'},
    {'id': 'b', 'title': 'BULLDOZER OPERATOR — JCRCC',
     'requirementScope': 'unattributed_notice'},
  ];

  testWidgets('notice provides exact role actions and only selected-role comparison', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewed = <String>[];
    final evaluated = <String>[];
    final compared = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: NoticeRoleSelector(
        roles: roles,
        onView: (role) => viewed.add(role['id'].toString()),
        onEvaluate: (role) => evaluated.add(role['id'].toString()),
        onCompare: (chosen) => compared.addAll(chosen.map((r) => r['id'].toString())),
      )),
    )));
    expect(find.byKey(const Key('notice-role-row-w')), findsOneWidget);
    expect(find.byKey(const Key('notice-role-row-b')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('notice-compare-selected'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('notice-role-checkbox-w')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('notice-role-checkbox-e')));
    await tester.tap(find.byKey(const Key('notice-role-checkbox-e')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('notice-compare-selected')));
    await tester.tap(find.byKey(const Key('notice-compare-selected')));
    expect(compared, ['w', 'e']);
    await tester.ensureVisible(find.byKey(const Key('notice-role-evaluate-e')));
    await tester.tap(find.byKey(const Key('notice-role-evaluate-e')));
    expect(evaluated, ['e']);
    await tester.ensureVisible(find.text('View details').first);
    await tester.tap(find.text('View details').first);
    expect(viewed, ['w']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unattributed requirements hide raw comparison score without blocking evaluation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? evaluated;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NoticeRoleComparisonDialog(
      roles: roles.take(2).toList(),
      result: <String, dynamic>{
        'modelVersion': 'peso-mini-ai-v1',
        'results': [
          {'jobId': 'w', 'score': 99, 'confidence': 'medium',
           'needsReview': ['Role requirements not confirmed'], 'missingMandatory': []},
          {'jobId': 'e', 'score': 74, 'confidence': 'medium',
           'needsReview': [], 'missingMandatory': ['Safety certification']},
        ],
      },
      onEvaluate: (role) => evaluated = role['id'].toString(),
    ))));
    expect(find.textContaining('99/100'), findsNothing);
    expect(find.textContaining('more verified qualification evidence'), findsOneWidget);
    expect(find.textContaining('74/100'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('compare-evaluate-w')));
    await tester.tap(find.byKey(const Key('compare-evaluate-w')));
    expect(evaluated, 'w');
    expect(tester.takeException(), isNull);
  });

  testWidgets('notice without provenance-linked roles explains the limitation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: NoticeRoleSelector(
        roles: const [],
        onView: (_) {},
        onEvaluate: (_) {},
        onCompare: (_) {},
      ),
    )));
    expect(find.textContaining('No individual job cards could be verified'), findsOneWidget);
    expect(find.byKey(const Key('notice-compare-selected')), findsNothing);
  });

  testWidgets('short and narrow notice picker remains scrollable without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: NoticeRoleSelector(
        roles: roles,
        onView: (_) {},
        onEvaluate: (_) {},
        onCompare: (_) {},
      )),
    )));
    await tester.ensureVisible(find.byKey(const Key('notice-compare-selected')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
