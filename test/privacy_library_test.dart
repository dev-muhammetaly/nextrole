import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_portal/core/services/backend.dart';
import 'package:job_portal/core/services/platform_store.dart';
import 'package:job_portal/core/theme/app_theme.dart';
import 'package:job_portal/features/account/privacy_requests_screen.dart';
import 'package:job_portal/features/workspace/resume_library.dart';
import 'package:job_portal/features/workspace/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_test.dart' as fixtures;

const files = [
  ResumeFile(
    id: 'design-2',
    libraryId: 'design',
    name: 'Design.pdf',
    title: 'Design CV',
    version: 2,
    path: 'candidate/2.pdf',
    bytes: 1200,
  ),
  ResumeFile(
    id: 'design-1',
    libraryId: 'design',
    name: 'Original.pdf',
    title: 'Design CV',
    version: 1,
    path: 'candidate/1.pdf',
    bytes: 1100,
    current: false,
  ),
  ResumeFile(
    id: 'engineering-1',
    libraryId: 'engineering',
    name: 'Engineering.pdf',
    title: 'Engineering CV',
    version: 1,
    path: 'candidate/3.pdf',
    bytes: 1400,
  ),
];
Uint8List fixturesBytes(String text) => Uint8List.fromList(text.codeUnits);

class PrivacyStore extends fixtures.WorkspaceStore {
  PrivacyStore() : super('employee');
  bool rejectWrite = false;
  final history = <PlatformRow>[];
  @override
  Future<List<PlatformRow>> privacyRequests({bool admin = false}) async =>
      history;
  @override
  Future<PlatformRow> action(String name, PlatformRow payload) async {
    if (rejectWrite) throw StateError('Offline');
    calls.add({'action': name, ...payload});
    if (name == 'privacy_request') {
      history.add({
        'id': 'request',
        ...payload,
        'status': 'pending',
        'response': '',
        'created_at': '2026-10-17',
      });
    }
    return {'id': 'request'};
  }
}

class ReportStore extends fixtures.WorkspaceStore {
  ReportStore() : super('admin');
  late final records = fixtures.fixture('admin');
  @override
  Future<PlatformData> load() async => records;
}

void main() {
  late fixtures.WorkspaceBackend backend;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = fixtures.WorkspaceBackend();
    Backend.instance = backend;
  });
  tearDown(() {
    Backend.instance = Backend();
    PlatformStore.instance = PlatformStore();
  });
  Future<void> desktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('PDF validation rejects disguised or oversized files', () {
    expect(
      () => PlatformStore.validatePdf(
        PreparedResume(files.first, fixturesBytes('not a pdf')).bytes,
      ),
      throwsStateError,
    );
    expect(
      () => PlatformStore.validatePdf(fixturesBytes('%PDF-1.4')),
      returnsNormally,
    );
    final oversized = Uint8List(5 * 1024 * 1024 + 1)
      ..setRange(0, 5, '%PDF-'.codeUnits);
    expect(() => PlatformStore.validatePdf(oversized), throwsStateError);
  });

  testWidgets(
    'Library shows separate current files and exposes prior versions deliberately',
    (tester) async {
      final store = fixtures.WorkspaceStore('employee')..library.addAll(files);
      PlatformStore.instance = store;
      await desktop(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: Nextrole.theme,
          home: const Scaffold(
            body: SingleChildScrollView(child: PrivateResumeManager()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Design CV'), findsOneWidget);
      expect(find.text('Engineering CV'), findsOneWidget);
      expect(find.text('Original.pdf · v1 · previous version'), findsNothing);
      await fixtures.tap(tester, find.text('Previous private versions'));
      await tester.pumpAndSettle();
      expect(find.text('Original.pdf · v1 · previous version'), findsOneWidget);
      expect(find.text('Submitted versions stay unchanged'), findsOneWidget);
    },
  );

  testWidgets(
    'Application review sends the exact older version the candidate selected',
    (tester) async {
      final store = fixtures.WorkspaceStore('employee')
        ..library.addAll(files)
        ..existingApplication = false;
      PlatformStore.instance = store;
      await desktop(tester);
      await tester.pumpWidget(
        MaterialApp(theme: Nextrole.theme, home: const WorkspaceScreen()),
      );
      await tester.pumpAndSettle();
      await fixtures.tap(
        tester,
        find.byKey(const ValueKey('workspace-nav-Discover')),
      );
      await tester.pumpAndSettle();
      await fixtures.tap(tester, find.text('View job'));
      await tester.pumpAndSettle();
      await fixtures.tap(tester, find.text('Prepare application'));
      await tester.pumpAndSettle();
      await fixtures.tap(tester, find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await fixtures.tap(
        tester,
        find.text('Original.pdf · v1 · previous version').last,
      );
      await tester.pumpAndSettle();
      await fixtures.tap(tester, find.text('Continue to review'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Original.pdf · v1 · previous version'),
        findsOneWidget,
      );
      expect(store.calls, isEmpty);
      await fixtures.tap(tester, find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(store.calls.single['selected_version'], 'design-1');
      expect(
        String.fromCharCodes(store.calls.single['selected_bytes']),
        contains('selected design-1'),
      );
    },
  );

  testWidgets(
    'Privacy request preserves text on failure and stores one successful request',
    (tester) async {
      final store = PrivacyStore()..rejectWrite = true;
      PlatformStore.instance = store;
      await desktop(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: Nextrole.theme,
          home: const PrivacyRequestsScreen(initialKind: 'export'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Please export the information in my account.',
      );
      await fixtures.tap(tester, find.text('Send privacy request'));
      await tester.pumpAndSettle();
      expect(
        find.text('Please export the information in my account.'),
        findsOneWidget,
      );
      expect(store.calls, isEmpty);
      store.rejectWrite = false;
      await fixtures.tap(tester, find.text('Send privacy request'));
      await tester.pumpAndSettle();
      expect(store.calls.single['kind'], 'export');
      expect(find.text('Pending'), findsOneWidget);
      backend.active = false;
      backend.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        find.text('Please export the information in my account.'),
        findsNothing,
      );
      expect(find.text('Sign in to contact the operator'), findsOneWidget);
    },
  );

  testWidgets('Privacy sign-in returns to the request screen', (tester) async {
    backend.active = false;
    PlatformStore.instance = PrivacyStore();
    await desktop(tester);
    await tester.pumpWidget(
      MaterialApp(theme: Nextrole.theme, home: const PrivacyRequestsScreen()),
    );
    await tester.pumpAndSettle();
    await fixtures.tap(tester, find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'candidate@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'fictional-test-password',
    );
    await fixtures.tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Send a privacy request'), findsOneWidget);
    expect(find.text('Your request history'), findsOneWidget);
  });

  testWidgets(
    'Report resolution requires confirmation and keeps the public message separate',
    (tester) async {
      final store = ReportStore();
      PlatformStore.instance = store;
      store.records.rows('reports').add({
        'id': 'report',
        'job_id': 'job',
        'reason': 'The role wording needs clarification.',
        'status': 'open',
        'assigned_revision': 3,
        'created_at': '2026-10-17',
      });
      store.records.rows('report_work').add({
        'report_id': 'report',
        'investigation_note': 'SECRET PRIVATE NOTE',
      });
      await desktop(tester);
      await tester.pumpWidget(
        MaterialApp(theme: Nextrole.theme, home: const WorkspaceScreen()),
      );
      await tester.pumpAndSettle();
      await fixtures.tap(
        tester,
        find.byKey(const ValueKey('workspace-nav-Reports')),
      );
      await tester.pumpAndSettle();
      await fixtures.tap(tester, find.text('Open report detail'));
      await tester.pumpAndSettle();
      await fixtures.tap(tester, find.text('Resolve report…'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Private resolution summary / decision reason',
        ),
        'PRIVATE RESOLUTION REASON',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Message to share with reporter and employer (optional)',
        ),
        'The listing wording was reviewed.',
      );
      await fixtures.tap(tester, find.text('Confirm resolved'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.calls, isEmpty);
      await fixtures.tap(tester, find.text('Confirm outcome'));
      await tester.pumpAndSettle();
      expect(store.calls.single['expected_revision'], 3);
      expect(store.calls.single['reason'], 'PRIVATE RESOLUTION REASON');
      expect(
        store.calls.single['public_message'],
        'The listing wording was reviewed.',
      );
      expect(store.calls.single.containsKey('investigation_note'), isFalse);
    },
  );
}
