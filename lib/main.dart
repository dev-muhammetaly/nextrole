import 'package:flutter/material.dart';

import 'features/jobs/jobs_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/services/backend.dart';
import 'features/account/account_screen.dart';
import 'features/info/info_screen.dart';
import 'core/router/route_observer.dart';
import 'features/workspace/workspace_screen.dart';
import 'features/account/privacy_requests_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.instance.initialize();
  runApp(const JobApp());
}

// The static host serves Flutter from app.html. Flutter's web route provider
// can report that document path when no hash route is present.
String normalizeInitialRoute(String route) {
  final path = Uri.tryParse(route)?.path ?? route;
  return switch (path) {
    '' || '/app.html' || '/index.html' => '/',
    _ => path,
  };
}

class JobApp extends StatelessWidget {
  const JobApp({super.key});
  static final Map<String, WidgetBuilder> _routes = {
    '/': (_) => const JobsScreen(),
    '/login': (_) => const AccountScreen(),
    '/signup': (_) => const AccountScreen(register: true),
    '/account': (_) => const AccountScreen(),
    '/privacy-request': (_) => const PrivacyRequestsScreen(),
    '/workspace': (_) => const WorkspaceScreen(),
    '/opportunities': (_) => const WorkspaceScreen(publicBrowse: true),
    '/employee': (_) => const WorkspaceScreen(requiredRole: 'employee'),
    '/employer': (_) => const WorkspaceScreen(requiredRole: 'employer'),
    '/admin': (_) => const WorkspaceScreen(requiredRole: 'admin'),
    for (final page in [
      'privacy',
      'terms',
      'cookies',
      'faq',
      'contact',
      'retention',
    ])
      '/$page': (_) => InfoScreen(page: page),
  };
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Nextrole — Find your next chapter',
    theme: Nextrole.theme,
    navigatorObservers: [appRouteObserver],
    routes: _routes,
    onGenerateInitialRoutes: (requested) {
      // Auth initialization consumes callbacks before runApp. Flutter can still
      // retain the original token-bearing route, so use the resolved screen.
      final route =
          Backend.instance.initialAuthRoute ?? normalizeInitialRoute(requested);
      return [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => const JobsScreen(),
        ),
        if (route != '/')
          MaterialPageRoute<void>(
            settings: RouteSettings(name: route),
            builder: _routes[route] ?? (_) => const NotFoundScreen(),
          ),
      ];
    },
    onUnknownRoute: (_) =>
        MaterialPageRoute<void>(builder: (_) => const NotFoundScreen()),
  );
}
