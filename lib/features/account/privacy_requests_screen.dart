import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/backend.dart';
import '../../core/services/platform_store.dart';
import '../../core/theme/app_theme.dart';
import '../workspace/workspace_design.dart';
import 'account_screen.dart';

class PrivacyRequestsScreen extends StatefulWidget {
  const PrivacyRequestsScreen({super.key, this.initialKind = 'other'});
  final String initialKind;
  @override
  State<PrivacyRequestsScreen> createState() => _PrivacyRequestsScreenState();
}

class _PrivacyRequestsScreenState extends State<PrivacyRequestsScreen> {
  final backend = Backend.instance;
  final store = PlatformStore.instance;
  final form = GlobalKey<FormState>();
  final message = TextEditingController();
  final kinds = const {
    'access': 'Access my information',
    'correction': 'Correct information',
    'export': 'Request a data export',
    'deletion': 'Request deletion',
    'retention': 'Ask about retention',
    'other': 'Other privacy question',
  };
  late String kind = widget.initialKind;
  List<PlatformRow> requests = [];
  bool loading = false, sending = false;
  String? error, actor;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    actor = backend.userId;
    backend.addListener(sessionChanged);
    load();
  }

  void sessionChanged() {
    if (actor != backend.userId) {
      actor = backend.userId;
      revision++;
      message.clear();
      setState(() {
        requests = [];
        error = null;
        sending = false;
      });
      load();
    }
  }

  @override
  void dispose() {
    revision++;
    backend.removeListener(sessionChanged);
    message.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!backend.signedIn) return;
    final current = ++revision;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await store.privacyRequests();
      if (mounted && current == revision) setState(() => requests = result);
    } catch (_) {
      if (mounted && current == revision) {
        setState(() => error = 'Your requests could not load. Please retry.');
      }
    } finally {
      if (mounted && current == revision) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    if (sending || !form.currentState!.validate()) return;
    final owner = backend.userId;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await store.action('privacy_request', {
        'kind': kind,
        'message': message.text.trim(),
      });
      if (!mounted || owner != backend.userId) return;
      message.clear();
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Privacy request received. Replies appear on this page.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted && owner == backend.userId) {
        setState(
          () => error = e is PostgrestException
              ? e.message
              : 'Unable to send your request. Your text is kept; please retry.',
        );
      }
    } finally {
      if (mounted && owner == backend.userId) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & contact')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const ScreenTitle('A private way to get in touch.', size: 32),
            const SizedBox(height: 16),
            const Text(
              'Nextrole’s portfolio operator handles privacy questions here. Your request and reply are visible to you and authorized administrators. No personal contact email is published.',
            ),
            const SizedBox(height: 24),
            const Notice(
              'Use this channel for access, correction, export, deletion and retention questions. Include only the details needed to understand your request. No ID documents, passwords or résumé attachments.',
            ),
            const SizedBox(height: 24),
            if (!backend.signedIn)
              WorkspacePanel(
                title: 'Sign in to contact the operator',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Signing in identifies the account and protects your request history. If you cannot sign in, use Forgot password on the sign-in page.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const AccountScreen(returnToCaller: true),
                          ),
                        );
                        if (mounted) await load();
                      },
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              )
            else ...[
              if (loading || sending) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Notice(error!, error: true),
                ),
              WorkspacePanel(
                title: 'Send a privacy request',
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: kind,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Request type',
                        ),
                        items: kinds.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: sending
                            ? null
                            : (v) => setState(() => kind = v!),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: message,
                        enabled: !sending,
                        maxLength: 2000,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'How can we help?',
                        ),
                        validator: (value) => (value ?? '').trim().length < 10
                            ? 'Please use at least 10 characters.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: sending ? null : send,
                        child: Text(
                          sending ? 'Sending…' : 'Send privacy request',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'The operator reviews requests manually, with a target response within 30 days. A request or resolved reply does not itself erase data. No external email delivery is promised.',
                        style: TextStyle(fontSize: 12, color: Nextrole.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const ScreenTitle('Your request history', size: 24),
              const SizedBox(height: 20),
              if (requests.isEmpty && !loading) const Text('No requests yet.'),
              for (final r in requests)
                WorkspacePanel(
                  title: kinds[r['kind']] ?? 'Privacy request',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(r['status']),
                      const SizedBox(height: 16),
                      SelectableText(r['message']),
                      const SizedBox(height: 20),
                      LabeledValue(
                        'Submitted',
                        (r['created_at'] as String).split('T').first,
                      ),
                      if ((r['response'] as String? ?? '').isNotEmpty)
                        LabeledValue('Operator response', r['response']),
                    ],
                  ),
                ),
              TextButton(
                onPressed: loading ? null : load,
                child: const Text('Refresh request history'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
