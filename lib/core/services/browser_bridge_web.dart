import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('nextroleShowPrivacy')
external void _showPrivacy();
void showPrivacySettings() => _showPrivacy();
void clearAuthCallback() =>
    web.window.history.replaceState(null, '', web.window.location.pathname);
