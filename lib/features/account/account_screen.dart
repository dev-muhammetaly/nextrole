import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/backend.dart';
import '../../core/theme/app_theme.dart';
import '../info/info_screen.dart';

class AccountScreen extends StatefulWidget {
  final bool register;
  final bool returnToCaller;
  const AccountScreen({
    super.key,
    this.register = false,
    this.returnToCaller = false,
  });
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final backend = Backend.instance;
  late bool register = widget.register;
  bool busy = false, obscure = true, accepted = false;
  bool confirmationPending = false, forgot = false;
  bool? resumeExists;
  String? selectedRole;
  String? resumeError;
  int resendSeconds = 0;
  Timer? resendTimer;
  String? message;

  @override
  void initState() {
    super.initState();
    backend.addListener(changed);
    backend.pendingJob().then((value) {
      if (mounted) setState(() => selectedRole = value);
    });
    if (backend.signedIn) refreshResume();
  }

  Future<void> refreshResume() async {
    final owner = backend.userId;
    try {
      final exists = await backend.hasResume();
      if (mounted && owner == backend.userId) {
        setState(() {
          resumeExists = exists;
          resumeError = null;
        });
      }
    } catch (_) {
      if (mounted && owner == backend.userId) {
        setState(
          () => resumeError = 'We could not check your résumé. Try again.',
        );
      }
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    backend.removeListener(changed);
    name.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action, {String? success}) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (mounted && success != null) setState(() => message = success);
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'We could not complete that action. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final navigator = Navigator.of(context);
    if (!form.currentState!.validate()) return;
    if (forgot) {
      await run(
        () => backend.resetPassword(email.text),
        success:
            'If an account exists, a password reset link will arrive shortly.',
      );
      return;
    }
    if (register && !backend.recoveringPassword && !accepted) {
      setState(() => message = 'Please accept the terms to create an account.');
      return;
    }
    await run(() async {
      if (backend.recoveringPassword) {
        await backend.updatePassword(password.text);
        if (mounted) {
          setState(
            () => message = 'Password updated. You can return to your job.',
          );
        }
      } else if (register) {
        final active = await backend.signUp(
          name.text,
          email.text,
          password.text,
        );
        if (!active && mounted) {
          setState(() {
            confirmationPending = true;
            message = 'Check your email to confirm your account, then sign in.';
          });
          startResendCooldown();
        }
        if (active && mounted) await finishAuthentication(navigator);
      } else {
        await backend.signIn(email.text, password.text);
        if (mounted) await finishAuthentication(navigator);
      }
    });
  }

  Future<void> finishAuthentication(NavigatorState navigator) async {
    if (widget.returnToCaller) {
      navigator.pop();
      return;
    }
    // Keep the original sample-job return flow; all other sign-ins open the
    // workspace selected by the trusted database role.
    final pendingSample = await backend.pendingJob();
    if (!mounted) return;
    if (pendingSample == null) {
      navigator.pushReplacementNamed('/workspace');
    } else {
      navigator.pop();
    }
  }

  void startResendCooldown() {
    resendTimer?.cancel();
    setState(() => resendSeconds = 60);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => resendSeconds--);
      if (resendSeconds <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) backend.cancelPasswordRecovery();
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('nextrole')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              ScreenTitle(
                backend.recoveringPassword
                    ? 'A fresh start, securely.'
                    : forgot
                    ? 'Let’s get you back in.'
                    : backend.signedIn
                    ? 'Make yourself at home.'
                    : register
                    ? 'A good place to begin.'
                    : 'Welcome back.',
              ),
              const SizedBox(height: 12),
              Text(
                backend.signedIn ? backend.email ?? 'Signed in' : 'Explore freely. Sign in to save application drafts and manage your résumé.',
              ),
              const SizedBox(height: 24),
              if (selectedRole != null) ...[
                Notice(
                  'Your selected role: ${selectedRole!.replaceFirst('-', ' · ')}. We’ll keep it ready while you sign in.',
                ),
                const SizedBox(height: 24),
              ],
              if (!backend.configured)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Account services could not start. Please reload the app or try again later. You can still explore sample jobs.',
                    ),
                  ),
                ),
              if (backend.startupError != null) Text(backend.startupError!),
              if (message != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Notice(message!, key: const Key('account-message')),
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
              if (confirmationPending && !backend.signedIn) ...[
                const Text(
                  'Check your inbox',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open your confirmation link in this browser to return to your selected job. You can keep browsing in the meantime.',
                ),
                TextButton(
                  onPressed: busy || resendSeconds > 0
                      ? null
                      : () => run(
                          () async {
                            await backend.resendConfirmation(email.text);
                            if (mounted) startResendCooldown();
                          },
                          success: 'If confirmation is needed, a fresh link will arrive shortly.',
                        ),
                  child: Text(
                    resendSeconds > 0
                        ? 'Resend available in ${resendSeconds}s'
                        : 'Resend confirmation email',
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          register = false;
                          confirmationPending = false;
                        }),
                  child: const Text('Back to sign in'),
                ),
              ],
              if ((!backend.signedIn || backend.recoveringPassword) &&
                  !confirmationPending)
                Form(
                  key: form,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Nextrole.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          if (register &&
                              !forgot &&
                              !backend.recoveringPassword) ...[
                            TextFormField(
                              controller: name,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter your name'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (!backend.recoveringPassword) ...[
                            TextFormField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                              ),
                              validator: validateEmail,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (!forgot)
                            TextFormField(
                              controller: password,
                              obscureText: obscure,
                              autofillHints: [
                                register || backend.recoveringPassword
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  tooltip: obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () =>
                                      setState(() => obscure = !obscure),
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                                  v == null ||
                                      v.length <
                                          (register ||
                                                  backend.recoveringPassword
                                              ? 8
                                              : 1)
                                  ? 'Enter ${register || backend.recoveringPassword ? 'at least 8 characters' : 'your password'}'
                                  : null,
                            ),
                          if (backend.recoveringPassword) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: confirmPassword,
                              obscureText: obscure,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                labelText: 'Confirm new password',
                              ),
                              validator: (value) => value == password.text
                                  ? null
                                  : 'Your passwords do not match',
                            ),
                          ],
                          if (register &&
                              !forgot &&
                              !backend.recoveringPassword)
                            Material(
                              child: CheckboxListTile(
                                value: accepted,
                                onChanged: (v) =>
                                    setState(() => accepted = v ?? false),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  'I agree to the Terms of Use and have read the Privacy Policy.',
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: busy || !backend.configured
                                  ? null
                                  : submit,
                              child: Text(
                                backend.recoveringPassword
                                    ? 'Update password'
                                    : forgot
                                    ? 'Send reset link'
                                    : register
                                    ? 'Create account'
                                    : 'Sign in',
                              ),
                            ),
                          ),
                          if (!backend.recoveringPassword) ...[
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      if (forgot) {
                                        forgot = false;
                                        register = false;
                                      } else {
                                        register = !register;
                                      }
                                      message = null;
                                    }),
                              child: Text(
                                forgot
                                    ? 'Back to sign in'
                                    : register
                                    ? 'Already registered? Sign in'
                                    : 'New here? Create an account',
                              ),
                            ),
                            if (!forgot)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                        forgot = true;
                                        register = false;
                                        message = null;
                                      }),
                                child: const Text('Forgot password?'),
                              ),
                            const Divider(),
                            const Text(
                              'By continuing with Google, you agree to the Terms of Use and acknowledge the Privacy Policy.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            if (!forgot)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed:
                                        busy ||
                                            !backend.configured ||
                                            (register && !accepted) ||
                                            !Backend.googleEnabled
                                        ? null
                                        : () => run(
                                            () => backend.oauth(
                                              OAuthProvider.google,
                                            ),
                                          ),
                                    child: const Text('Continue with Google'),
                                  ),
                                ),
                              ),
                            if (!Backend.googleEnabled)
                              const Text(
                                'Google sign-in has not been enabled for this portfolio yet.',
                                style: TextStyle(fontSize: 12),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              if (backend.signedIn && !backend.recoveringPassword) ...[
                const Text(
                  'Private résumé',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PDF only, up to 5 MB. Stored privately in your account. For this portfolio, use a sample résumé without sensitive information.',
                ),
                const SizedBox(height: 16),
                if (resumeError != null) ...[
                  Notice(resumeError!, error: true),
                  TextButton(
                    onPressed: refreshResume,
                    child: const Text('Check résumé again'),
                  ),
                ] else if (resumeExists == null)
                  const LinearProgressIndicator()
                else
                  Notice(
                    resumeExists!
                        ? 'Your private PDF is ready. You can open, replace, or delete it below.'
                        : 'No résumé yet. Choose a PDF when you’re ready.',
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          final file = await FilePicker.pickFile(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                          );
                          if (file == null) return;
                          final length = await file.length();
                          if (length == null || length > 5 * 1024 * 1024) {
                            throw StateError('Choose a PDF smaller than 5 MB.');
                          }
                          final bytes = await file.readAsBytes();

                          await backend.uploadResume(bytes);
                          if (mounted) setState(() => resumeExists = true);
                          if (mounted) {
                            setState(
                              () => message =
                                  'Your private résumé has been uploaded.',
                            );
                          }
                        }),
                  icon: const DesignIcon('upload', color: Colors.white),
                  label: const Text('Upload or replace résumé'),
                ),
                OutlinedButton(
                  onPressed: busy || resumeExists != true
                      ? null
                      : () => run(() async {
                          final url = await backend.resumeUrl();
                          if (!await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          )) {
                            throw StateError('Unable to open résumé.');
                          }
                        }),
                  child: const Text('Open my résumé'),
                ),
                TextButton(
                  onPressed: busy || resumeExists != true
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete your résumé?'),
                              content: const Text(
                                'This removes the uploaded PDF from your account.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await run(() async {
                              await backend.deleteResume();
                              if (mounted) setState(() => resumeExists = false);
                            }, success: 'Résumé deleted.');
                          }
                        },
                  child: const Text('Delete résumé'),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await backend.signOut();
                          if (context.mounted) Navigator.pop(context);
                        }),
                  child: const Text('Sign out'),
                ),
              ],
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => openInfo(context, 'terms'),
                    child: const Text('Terms of Use'),
                  ),
                  TextButton(
                    onPressed: () => openInfo(context, 'privacy'),
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Back to exploring'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String? validateEmail(String? value) =>
    value == null ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Enter a valid email address'
    : null;
