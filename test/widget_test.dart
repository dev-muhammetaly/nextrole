import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_portal/main.dart';
import 'package:job_portal/core/services/backend.dart';
import 'package:job_portal/features/account/account_screen.dart';
import 'package:job_portal/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBackend extends Backend {
  final rows = <String, Map<String, dynamic>>{};
  @override
  bool get configured => true;
  @override
  bool get signedIn => true;
  @override
  String? get userId => 'test-user';
  @override
  String get email => 'alex@example.com';
  @override
  Future<List<Map<String, dynamic>>> drafts() async => rows.values.toList();
  @override
  Future<bool> hasResume() async => false;
  @override
  Future<void> saveDraft(
    String jobId,
    String name,
    String email,
    String note,
  ) async {
    rows[jobId] = {
      'job_id': jobId,
      'full_name': name,
      'email': email,
      'introduction': note,
    };
  }
}

class AuthTestBackend extends FakeBackend {
  bool active = false;
  int resetRequests = 0, registrations = 0, passwordUpdates = 0;
  @override
  Future<void> updatePassword(String password) async {
    passwordUpdates++;
    recoveringPassword = false;
  }

  @override
  Future<void> resetPassword(String email) async {
    resetRequests++;
  }

  @override
  Future<bool> signUp(String name, String email, String password) async {
    registrations++;
    return false;
  }

  @override
  bool get signedIn => active;
  @override
  String? get userId => active ? 'test-user' : null;
  @override
  Future<void> signIn(String email, String password) async {
    active = true;
    notifyListeners();
  }
}

void main() {
  test('Static document paths map to home while app routes remain intact', () {
    expect(normalizeInitialRoute('/app.html'), '/');
    expect(normalizeInitialRoute('/app.html?role=example'), '/');
    expect(normalizeInitialRoute('/index.html'), '/');
    expect(normalizeInitialRoute('/admin'), '/admin');
    expect(normalizeInitialRoute('/missing'), '/missing');
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Backend.instance = Backend();
  });
  testWidgets('Opening app.html directly starts discovery instead of 404', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/app.html';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(const JobApp());
    await tester.pumpAndSettle();
    expect(find.text('Find your next possibility.'), findsOneWidget);
    expect(find.text('404 — This path took a detour.'), findsNothing);
  });
  testWidgets('Direct admin route reaches the sign-in gate instead of 404', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/admin';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(const JobApp());
    await tester.pumpAndSettle();
    expect(find.text('Your workspace awaits.'), findsOneWidget);
    expect(find.text('404 — This path took a detour.'), findsNothing);
  });
  testWidgets(
    'Consumed recovery callback opens reset form instead of token route',
    (tester) async {
      Backend.instance = AuthTestBackend()
        ..recoveringPassword = true
        ..initialAuthRoute = '/account';
      tester.platformDispatcher.defaultRouteNameTestValue =
          '/access_token=example&type=recovery';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(const JobApp());
      await tester.pumpAndSettle();
      expect(find.text('A fresh start, securely.'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
      expect(find.text('404 — This path took a detour.'), findsNothing);
    },
  );
  testWidgets(
    'Leaving recovery clears the reset state without changing password',
    (tester) async {
      final backend = AuthTestBackend()
        ..recoveringPassword = true
        ..initialAuthRoute = '/account';
      Backend.instance = backend;
      await tester.pumpWidget(const JobApp());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Back to exploring'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(AccountScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Back to exploring'));
      await tester.pumpAndSettle();
      expect(backend.recoveringPassword, isFalse);
      expect(backend.passwordUpdates, 0);
      expect(find.text('A fresh start, securely.'), findsNothing);
      expect(find.text('Find your next possibility.'), findsOneWidget);
    },
  );
  testWidgets('Recovery requires matching new passwords', (tester) async {
    final backend = AuthTestBackend()..recoveringPassword = true;
    Backend.instance = backend;
    await tester.pumpWidget(
      MaterialApp(theme: Nextrole.theme, home: const AccountScreen()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'sample-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'different-password',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(backend.passwordUpdates, 0);
    expect(find.text('Your passwords do not match'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'sample-password',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(backend.passwordUpdates, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search narrows opportunities and handles empty results', (
    tester,
  ) async {
    await tester.pumpWidget(const JobApp());
    expect(find.text('Find your next possibility.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Flutter');
    await tester.pump();
    expect(find.text('Junior Flutter Developer'), findsOneWidget);
    expect(find.text('Product Design Intern'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing role');
    await tester.pump();
    expect(find.text('No matching opportunities'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile navigation and layout work', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JobApp());
    expect(find.text('nextrole'), findsOneWidget);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Your next favorites belong here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small phone supports enlarged text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const JobApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Save a job and prepare a validated application draft', (
    tester,
  ) async {
    Backend.instance = FakeBackend();
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JobApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save job').first);
    await tester.tap(find.text('Saved jobs'));
    await tester.pumpAndSettle();
    expect(find.text('Product Design Intern'), findsOneWidget);
    expect(find.text('Junior Flutter Developer'), findsNothing);
    await tester.tap(find.text('View job ↗'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare application'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your name'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Alex Lee',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'alex@example.com',
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applications'));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Guest application requires registration and keeps selected job',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const JobApp());
      await tester.tap(find.text('View job ↗').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in to apply'));
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Save draft'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(
        await Backend.instance.takePendingJob(),
        'Fieldwork-Product Design Intern',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unknown route displays a recoverable 404', (tester) async {
    await tester.pumpWidget(const JobApp());
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).pushNamed('/missing');
    await tester.pumpAndSettle();
    expect(find.text('404 — This path took a detour.'), findsOneWidget);
    await tester.tap(find.text('Explore jobs'));
    await tester.pumpAndSettle();
    expect(find.text('nextrole'), findsOneWidget);
  });

  testWidgets('Named sign-in route resumes a pending application once', (
    tester,
  ) async {
    Backend.instance = AuthTestBackend();
    await Backend.instance.rememberJob('Notion-Frontend Engineer');
    await tester.pumpWidget(const JobApp());
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).pushNamed('/login');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'alex@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'example-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Your next step'), findsOneWidget);
    expect(find.text('Frontend Engineer at Notion'), findsOneWidget);
    expect(await Backend.instance.takePendingJob(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Signing out clears private drafts from the workspace', (
    tester,
  ) async {
    final backend = AuthTestBackend()..active = true;
    backend.rows['Fieldwork-Product Design Intern'] = {
      'job_id': 'Fieldwork-Product Design Intern',
      'full_name': 'Alex',
      'email': 'alex@example.com',
      'introduction': 'Private test draft',
    };
    Backend.instance = backend;
    await tester.pumpWidget(const JobApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applications'));
    await tester.pumpAndSettle();
    expect(find.text('Product Design Intern'), findsOneWidget);
    backend.active = false;
    backend.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Product Design Intern'), findsNothing);
    expect(find.text('Your applications start here'), findsOneWidget);
  });

  testWidgets('Recovery submits email without requiring a password', (
    tester,
  ) async {
    final backend = AuthTestBackend();
    Backend.instance = backend;
    await tester.pumpWidget(const JobApp());
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .pushNamed('/login');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'alex@example.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(backend.resetRequests, 1);
    expect(find.textContaining('If an account exists'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Registration requires acknowledgement and waits for email confirmation',
    (tester) async {
      final backend = AuthTestBackend();
      Backend.instance = backend;
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const JobApp());
      Navigator.of(tester.element(find.byType(Scaffold).first))
          .pushNamed('/signup');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Alex',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'alex@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'sample-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(backend.registrations, 0);
      expect(
        find.text('Please accept the terms to create an account.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(backend.registrations, 1);
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.text('Resend available in 60s'), findsOneWidget);
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Small phone signup reflows with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const JobApp());
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .pushNamed('/signup');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Signing out closes an open private draft editor', (
    tester,
  ) async {
    final backend = AuthTestBackend()..active = true;
    Backend.instance = backend;
    await backend.rememberJob('Fieldwork-Product Design Intern');
    await tester.pumpWidget(const JobApp());
    await tester.pumpAndSettle();
    expect(find.text('Your next step'), findsOneWidget);
    backend.active = false;
    backend.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Your next step'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
