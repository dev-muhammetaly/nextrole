import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'browser_bridge.dart';
import 'client_config.dart';

/// Loads public connection settings for both plain IDE runs and release builds.
class Backend extends ChangeNotifier {
  static Backend instance = Backend();
  SupabaseClient? client;
  StreamSubscription<AuthState>? _subscription;
  String? startupError;
  bool recoveringPassword = false;
  String? initialAuthRoute;
  static ClientConfig? _config;
  static String get siteUrl => _config?.siteUrl ?? '';
  static const googleEnabled = bool.fromEnvironment(
    'GOOGLE_AUTH_ENABLED',
    defaultValue: true,
  );
  String? get userId => client?.auth.currentUser?.id;
  String? get email => client?.auth.currentUser?.email;
  String? get fullName =>
      client?.auth.currentUser?.userMetadata?['full_name'] as String?;
  bool get signedIn =>
      userId != null && client?.auth.currentUser?.isAnonymous != true;
  bool get configured => client != null;
  String get redirectUrl => kIsWeb
      ? '${Uri.base.origin}/app.html'
      : 'com.nextrole.app://login-callback/';

  Future<void> initialize() async {
    try {
      _config = await ClientConfig.load();
      // Attach our listener before consuming the web callback so recovery
      // events are not lost during Supabase.initialize().
      await Supabase.initialize(
        url: _config!.url,
        publishableKey: _config!.key,
        authOptions: FlutterAuthClientOptions(detectSessionInUri: !kIsWeb),
      );
      client = Supabase.instance.client;
      _subscription = client!.auth.onAuthStateChange.listen(
        (event) {
          if (event.event == AuthChangeEvent.passwordRecovery) {
            recoveringPassword = true;
          }
          if (event.event == AuthChangeEvent.signedOut) {
            recoveringPassword = false;
          }
          notifyListeners();
        },
        onError: (Object error) {
          startupError = 'Your sign-in link could not be completed. Please request a new link.';
          notifyListeners();
        },
      );
      if (kIsWeb) {
        final uri = Uri.base;
        final fragment = Uri.splitQueryString(uri.fragment);
        if (['code', 'access_token', 'error', 'error_code'].any(
          (name) =>
              uri.queryParameters.containsKey(name) ||
              fragment.containsKey(name),
        )) {
          initialAuthRoute = '/login';
          try {
            final callback = await client!.auth.getSessionFromUrl(uri);
            // The auth event stream can deliver after this Future completes.
            // Resolve recovery routing from the callback result as well.
            if (callback.redirectType == 'recovery' ||
                callback.redirectType ==
                    AuthChangeEvent.passwordRecovery.name) {
              recoveringPassword = true;
            }
            initialAuthRoute = recoveringPassword
                ? '/account'
                : await pendingJob() != null
                ? '/'
                : '/workspace';
          } catch (_) {
            startupError = 'Your sign-in link could not be completed. Please request a new link.';
          } finally {
            clearAuthCallback();
          }
        }
      }
    } catch (_) {
      startupError = 'Account services are temporarily unavailable. You can still browse jobs.';
    }
  }

  SupabaseClient get requireClient =>
      client ??
      (throw StateError(
        'Account services are not configured for this portfolio preview.',
      ));
  Future<void> signIn(String email, String password) async {
    await requireClient.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<bool> signUp(String name, String email, String password) async {
    final response = await requireClient.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectUrl,
      data: {'full_name': name.trim()},
    );
    return response.session != null;
  }

  Future<void> oauth(OAuthProvider provider) async {
    final opened = await requireClient.auth.signInWithOAuth(
      provider,
      redirectTo: redirectUrl,
    );
    if (!opened) {
      throw StateError(
        'Unable to open the sign-in provider. Please try again.',
      );
    }
  }

  Future<void> resetPassword(String email) => requireClient.auth
      .resetPasswordForEmail(email.trim(), redirectTo: redirectUrl);
  Future<void> resendConfirmation(String email) async {
    await requireClient.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: redirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    await requireClient.auth.updateUser(UserAttributes(password: password));
    recoveringPassword = false;
    notifyListeners();
  }

  void cancelPasswordRecovery() {
    if (!recoveringPassword) return;
    recoveringPassword = false;
    initialAuthRoute = null;
    notifyListeners();
  }

  Future<void> signOut() => requireClient.auth.signOut();

  Future<void> rememberJob(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nextrole.pendingJob', id);
  }

  Future<String?> takePendingJob() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('nextrole.pendingJob');
    await prefs.remove('nextrole.pendingJob');
    return value;
  }

  Future<String?> pendingJob() async =>
      (await SharedPreferences.getInstance()).getString('nextrole.pendingJob');

  Future<bool> hasResume() async {
    if (!signedIn) return false;
    final files = await requireClient.storage
        .from('nextrole-resumes')
        .list(path: userId!);
    return files.any((file) => file.name == 'resume.pdf');
  }

  Future<List<Map<String, dynamic>>> drafts() async {
    if (!signedIn) return [];
    return await requireClient
        .from('nextrole_drafts')
        .select()
        .eq('user_id', userId!);
  }

  Future<void> saveDraft(
    String jobId,
    String name,
    String email,
    String note,
  ) async {
    if (!signedIn) throw StateError('Please sign in to continue.');
    await requireClient.from('nextrole_drafts').upsert({
      'user_id': userId,
      'job_id': jobId,
      'full_name': name,
      'email': email,
      'introduction': note,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,job_id');
  }

  Future<void> deleteDraft(String jobId) async {
    if (!signedIn) return;
    await requireClient
        .from('nextrole_drafts')
        .delete()
        .eq('user_id', userId!)
        .eq('job_id', jobId);
  }

  Future<void> uploadResume(Uint8List bytes) async {
    if (!signedIn) throw StateError('Please sign in first.');
    if (bytes.length > 5 * 1024 * 1024 ||
        bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw StateError('Choose a PDF résumé smaller than 5 MB.');
    }
    await requireClient.storage
        .from('nextrole-resumes')
        .uploadBinary(
          '$userId/resume.pdf',
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  Future<String> resumeUrl() => requireClient.storage
      .from('nextrole-resumes')
      .createSignedUrl('$userId/resume.pdf', 60);
  Future<void> deleteResume() async {
    await requireClient.storage.from('nextrole-resumes').remove([
      '$userId/resume.pdf',
    ]);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
