import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_portal/core/services/backend.dart';
import 'package:job_portal/core/services/platform_store.dart';
import 'package:job_portal/core/theme/app_theme.dart';
import 'package:job_portal/features/workspace/workspace_screen.dart';
import 'package:job_portal/features/account/account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkspaceBackend extends Backend {
  bool active = true;
  bool fileExists = false;
  @override
  Future<bool> hasResume() async => fileExists;
  @override
  bool get signedIn => active;
  @override
  bool get configured => true;
  @override
  String? get userId => active ? 'candidate' : null;
  @override
  String get email => 'candidate@example.invalid';
  @override
  Future<void> signIn(String email, String password) async {
    active = true;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    active = false;
    notifyListeners();
  }
}

class WorkspaceStore extends PlatformStore {
  WorkspaceStore(this.role);
  final String role;
  final calls = <Map<String, dynamic>>[];
  bool fail = false;
  bool existingApplication = true;
  final library = <ResumeFile>[];
  @override
  Future<List<ResumeFile>> resumeChoices() async => library.isNotEmpty
      ? library
      : await backend.hasResume()
      ? [
          const ResumeFile(
            id: 'legacy',
            libraryId: 'legacy',
            name: 'resume.pdf',
            title: 'Previous PDF',
            version: 1,
            path: 'candidate/resume.pdf',
            bytes: 5,
            legacy: true,
          ),
        ]
      : [];
  @override
  Future<PreparedResume> prepareResume(ResumeFile file) async => PreparedResume(
    file,
    Uint8List.fromList('%PDF-1.4 selected ${file.id}'.codeUnits),
  );
  @override
  Future<List<PlatformRow>> privacyRequests({bool admin = false}) async => [];
  @override
  Future<PlatformData> load() async {
    if (fail) throw StateError('Offline');
    final result = fixture(role);
    if (!existingApplication) result.rows('applications').clear();
    return result;
  }

  @override
  Future<PlatformData> loadPublic() async => fixture('guest');
  @override
  Future<PlatformRow> action(String name, PlatformRow payload) async {
    calls.add({'action': name, ...payload});
    return {};
  }

  @override
  Future<void> submitApplication(
    PlatformRow job,
    PlatformRow fields, {
    PreparedResume? resume,
  }) async {
    calls.add({
      'action': 'application_submit',
      'job_id': job['id'],
      ...fields,
      'selected_version': resume?.file.id,
      'selected_bytes': resume?.bytes,
    });
  }
}

PlatformData fixture(String role) => PlatformData(
  member: {
    'id': 'candidate',
    'role': role,
    'full_name': 'Alex',
    'email': 'candidate@example.invalid',
    'profile': <String, dynamic>{},
  },
  tables: {
    'settings': [
      {
        'categories': ['Design', 'Engineering'],
        'locations': ['Remote'],
        'maintenance_notice': '',
      },
    ],
    'companies': [
      {
        'id': 'company',
        'owner_id': 'candidate',
        'name': 'Fictional Studio',
        'status': 'pending',
        'description': 'A fictional company',
        'location': 'Remote',
        'industry': 'Design',
        'website': '',
      },
    ],
    'jobs': [
      {
        'id': 'job',
        'owner_id': 'candidate',
        'company_id': 'company',
        'title': 'Junior Designer',
        'location': 'Remote',
        'salary': 'RM 2000 per month',
        'employment_type': 'Full-time',
        'arrangement': 'Remote',
        'category': 'Design',
        'status': 'published',
        'description': 'A fictional role with useful design responsibilities.',
        'requirements': 'Curiosity',
        'benefits': 'Mentoring',
        'closes_at': '2027-12-31',
        'created_at': '2026-10-17',
      },
    ],
    'applications': [
      {
        'id': 'application',
        'job_id': 'job',
        'candidate_id': 'candidate',
        'status': 'submitted',
        'created_at': '2026-10-17',
        'snapshot': {
          'full_name': 'Alex',
          'email': 'candidate@example.invalid',
          'job_title': 'Junior Designer',
          'company_name': 'Fictional Studio',
          'introduction': 'My introduction',
        },
        'resume_path': 'candidate/application.pdf',
      },
    ],
    'application_events': [
      {
        'application_id': 'application',
        'status': 'submitted',
        'message': 'Application submitted.',
        'created_at': '2026-10-17',
      },
    ],
    'application_notes': role == 'employer'
        ? [
            {
              'application_id': 'application',
              'note': 'Employer confidential note',
            },
          ]
        : [],
    'saved': [
      {'job_id': 'job', 'user_id': 'candidate'},
    ],
    'drafts': [],
    'notifications': [],
    'members': [],
    'audit': [],
    'reports': [],
    'account_requests': [],
  },
);
Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
}

void main() {
  late WorkspaceBackend backend;
  late WorkspaceStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = WorkspaceBackend();
    Backend.instance = backend;
    store = WorkspaceStore('employee');
    PlatformStore.instance = store;
  });
  tearDown(() {
    PlatformStore.instance = PlatformStore();
    Backend.instance = Backend();
  });
  Future<void> open(
    WidgetTester tester, {
    String? requiredRole,
    bool public = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Nextrole.theme,
        home: WorkspaceScreen(requiredRole: requiredRole, publicBrowse: public),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> desktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Normal sign-in opens the server-selected employer workspace', (
    tester,
  ) async {
    backend.active = false;
    store = WorkspaceStore('employer');
    PlatformStore.instance = store;
    await desktop(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: Nextrole.theme,
        home: const Scaffold(body: Text('Home')),
        routes: {
          '/login': (_) => const AccountScreen(),
          '/workspace': (_) => const WorkspaceScreen(),
        },
      ),
    );
    Navigator.of(tester.element(find.byType(Scaffold))).pushNamed('/login');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'candidate@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'test-password',
    );
    await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Employer dashboard'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-nav-Applicants')),
      findsOneWidget,
    );
    expect(find.text('Welcome back.'), findsNothing);
  });

  testWidgets('Candidate cannot enter administrator workspace', (tester) async {
    await open(tester, requiredRole: 'admin');
    expect(find.text('This workspace is restricted.'), findsOneWidget);
    expect(find.text('Approve employer'), findsNothing);
  });
  testWidgets(
    'Employee workspace filters saved records and keeps private notes hidden',
    (tester) async {
      await desktop(tester);
      await open(tester);
      await tap(
        tester,
        find.byKey(const ValueKey('workspace-nav-Applications')),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('View application'));
      await tester.pumpAndSettle();
      expect(find.text('Employer confidential note'), findsNothing);
      expect(find.text('Withdraw application'), findsOneWidget);
      expect(find.text('Update status'), findsNothing);
      backend.active = false;
      backend.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('My introduction'), findsNothing);
      expect(find.text('Your workspace awaits.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Employer gets applicant review and private notes without admin controls',
    (tester) async {
      await desktop(tester);
      store = WorkspaceStore('employer');
      PlatformStore.instance = store;
      await open(tester, requiredRole: 'employer');
      expect(find.byKey(const ValueKey('workspace-nav-Users')), findsNothing);
      await tap(tester, find.byKey(const ValueKey('workspace-nav-Applicants')));
      await tester.pumpAndSettle();
      await tap(tester, find.text('View application'));
      await tester.pumpAndSettle();
      expect(find.text('Employer confidential note'), findsOneWidget);
      await tap(tester, find.text('Update status'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Candidate-visible message (optional)',
        ),
        'We are reviewing your application.',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Update status'));
      await tester.pumpAndSettle();
      expect(store.calls.single['action'], 'application_status');
      expect(store.calls.single['id'], 'application');
      expect(
        store.calls.single['message'],
        'We are reviewing your application.',
      );
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Admin moderation requires reason before sending mutation', (
    tester,
  ) async {
    await desktop(tester);
    store = WorkspaceStore('admin');
    PlatformStore.instance = store;
    await open(tester, requiredRole: 'admin');
    await tap(tester, find.byKey(const ValueKey('workspace-nav-Employers')));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Review employer request'));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Approve employer'));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Confirm decision'));
    await tester.pumpAndSettle();
    expect(store.calls, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Decision reason'),
      'Approved fictional company.',
    );
    await tap(tester, find.text('Confirm decision'));
    await tester.pumpAndSettle();
    expect(store.calls.single['action'], 'company_review');
    expect(store.calls.single['status'], 'approved');
    expect(find.byType(Dialog), findsNothing);
  });
  testWidgets(
    'Guests browse published job details and see contextual sign-in gate',
    (tester) async {
      backend.active = false;
      await open(tester, public: true);
      await tester.ensureVisible(find.text('View job'));
      await tap(tester, find.text('View job'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to apply'), findsOneWidget);
      expect(find.text('Prepare application'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Mobile employee workspace supports enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    expect(tester.takeException(), isNull);
    await tap(tester, find.text('Saved'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Workspace load failure gives retry and preserves role gate', (
    tester,
  ) async {
    store.fail = true;
    await open(tester);
    expect(find.text('Try again'), findsOneWidget);
    store.fail = false;
    await tap(tester, find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Opening your workspace…'), findsNothing);
    expect(find.text('Welcome back, Alex'), findsOneWidget);
  });
  testWidgets('Guided profile setup preserves values across saved steps', (
    tester,
  ) async {
    final saves = <PlatformRow>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: Nextrole.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => GuidedProfileSetup(
                  initial: {'full_name': 'Alex'},
                  onSave: (values) async {
                    saves.add({...values});
                    return true;
                  },
                ),
              ),
              child: const Text('Start setup'),
            ),
          ),
        ),
      ),
    );
    await tap(tester, find.text('Start setup'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Professional headline (optional)'),
      'Junior designer',
    );
    await tester.ensureVisible(find.text('Save and continue'));
    await tap(tester, find.text('Save and continue'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Location (optional)'),
      'Kuala Lumpur',
    );
    await tap(tester, find.text('Save and continue'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Skills (optional)'),
      'Figma, Flutter',
    );
    await tester.ensureVisible(find.text('Save and continue'));
    await tap(tester, find.text('Save and continue'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Preferred roles and work arrangements (optional)',
      ),
      'Design internship · Hybrid',
    );
    await tap(tester, find.text('Save and continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finish profile'));
    await tap(tester, find.text('Finish profile'));
    await tester.pumpAndSettle();
    expect(saves.length, 5);
    expect(saves.last['headline'], 'Junior designer');
    expect(saves.last['skills'], 'Figma, Flutter');
    expect(saves.last['location'], 'Kuala Lumpur');
    expect(saves.last['preferences'], 'Design internship · Hybrid');
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'Review is a separate step and shares nothing before explicit submission',
    (tester) async {
      await desktop(tester);
      backend.fileExists = true;
      store.existingApplication = false;
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('workspace-nav-Discover')));
      await tester.pumpAndSettle();
      await tap(tester, find.text('View job'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Prepare application'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Introduction / cover note (optional)',
        ),
        'The exact note I choose to share.',
      );
      await tap(tester, find.text('Continue to review'));
      await tester.pumpAndSettle();
      expect(find.text('Review before you submit'), findsOneWidget);
      expect(find.text('The exact note I choose to share.'), findsOneWidget);
      expect(store.calls, isEmpty);
      await tap(tester, find.text('Back to editing'));
      await tester.pumpAndSettle();
      expect(find.text('The exact note I choose to share.'), findsOneWidget);
      await tap(tester, find.text('Continue to review'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(store.calls.single['action'], 'application_submit');
      expect(
        store.calls.single['introduction'],
        'The exact note I choose to share.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Job wizard keeps completed steps while moving back and saves only at final review',
    (tester) async {
      final calls = <PlatformRow>[];
      await desktop(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: Nextrole.theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StagedJobEditor(
                fields: const [
                  FormFieldSpec('title', 'Job title'),
                  FormFieldSpec('category', 'Category', choices: ['Design']),
                  FormFieldSpec('description', 'Responsibilities'),
                  FormFieldSpec('location', 'Location'),
                  FormFieldSpec(
                    'employment_type',
                    'Employment type',
                    choices: ['Internship'],
                  ),
                  FormFieldSpec(
                    'arrangement',
                    'Arrangement',
                    choices: ['Hybrid'],
                  ),
                  FormFieldSpec('salary', 'Salary'),
                  FormFieldSpec('benefits', 'Benefits', required: false),
                  FormFieldSpec(
                    'requirements',
                    'Requirements',
                    required: false,
                  ),
                  FormFieldSpec('closes_at', 'Closing date'),
                ],
                initial: const {
                  'title': 'Design intern',
                  'description': 'Learn through useful design work.',
                  'location': 'Kuala Lumpur',
                  'salary': 'RM 2000 / month',
                  'closes_at': '2027-01-30',
                },
                onSave: (values) async {
                  calls.add(values);
                  return false;
                },
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Location'),
        'Penang',
      );
      await tap(tester, find.text('Previous step'));
      await tester.pumpAndSettle();
      expect(find.text('Design intern'), findsOneWidget);
      await tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Penang'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tap(tester, find.text('Continue'));
        await tester.pumpAndSettle();
      }
      expect(calls, isEmpty);
      await tap(tester, find.text('Save job draft'));
      await tester.pumpAndSettle();
      expect(calls.single['location'], 'Penang');
      expect(find.text('Save job draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Dirty editor asks before discarding input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Nextrole.theme,
        home: Scaffold(
          body: RecordEditor(
            title: 'Edit profile',
            fields: const [FormFieldSpec('name', 'Name')],
            onSave: (_) async => false,
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Unsaved input');
    await tap(tester, find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tap(tester, find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved input'), findsOneWidget);
  });
}
