import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_portal/core/services/backend.dart';
import 'package:job_portal/core/services/platform_store.dart';
import 'package:job_portal/core/theme/app_theme.dart';
import 'package:job_portal/features/workspace/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_test.dart' as fixtures;

void main() {
  for (final role in ['employee', 'employer', 'admin']) {
    for (final width in [320.0, 768.0]) {
      testWidgets('$role workspace and record page reflow at $width pixels', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        Backend.instance = fixtures.WorkspaceBackend();
        PlatformStore.instance = fixtures.WorkspaceStore(role);
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        if (width == 320) {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
        }
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          Backend.instance = Backend();
          PlatformStore.instance = PlatformStore();
        });
        await tester.pumpWidget(
          MaterialApp(theme: Nextrole.theme, home: const WorkspaceScreen()),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Open navigation'));
        await tester.pumpAndSettle();
        final tab = role == 'employee'
            ? 'Applications'
            : role == 'employer'
            ? 'Jobs'
            : 'Companies';
        await tester.ensureVisible(find.byKey(ValueKey('workspace-nav-$tab')));
        await tester.tap(find.byKey(ValueKey('workspace-nav-$tab')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Drawer), findsNothing);
      });
    }
  }
}
