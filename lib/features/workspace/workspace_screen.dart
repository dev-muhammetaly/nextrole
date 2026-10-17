import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/backend.dart';
import '../../core/services/platform_store.dart';
import '../../core/theme/app_theme.dart';
import '../account/account_screen.dart';
import '../account/privacy_requests_screen.dart';
import 'resume_library.dart';
import 'workspace_design.dart';

String textOf(Object? value) => (value ?? '').toString();
String label(Object? value) => textOf(value).replaceAll('_', ' ');
String dateOf(Object? value) => textOf(value).split('T').first;
typedef Fields = List<FormFieldSpec>;

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    this.requiredRole,
    this.publicBrowse = false,
  });
  final String? requiredRole;
  final bool publicBrowse;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final backend = Backend.instance;
  final store = PlatformStore.instance;
  PlatformData? data;
  bool loading = true, busy = false;
  String? error, owner;
  String page = 'Overview', search = '', filter = 'All';
  String jobCategory = 'All categories',
      arrangement = 'Any arrangement',
      employment = 'Any type';
  bool openedSharedJob = false;
  final logoRequests = <String, Future<String?>>{};
  int start = 0, revision = 0, detailDepth = 0;
  @override
  void initState() {
    super.initState();
    owner = backend.userId;
    backend.addListener(sessionChanged);
    refresh();
  }

  @override
  void dispose() {
    revision++;
    backend.removeListener(sessionChanged);
    super.dispose();
  }

  void sessionChanged() {
    if (owner != backend.userId) {
      final previousOwner = owner;
      owner = backend.userId;
      revision++;
      if (previousOwner != null && mounted) {
        final workspaceRoute = ModalRoute.of(context);
        Navigator.of(context).popUntil((route) => route == workspaceRoute);
      }
      setState(() => data = null);
      refresh();
    }
  }

  Future<void> refresh() async {
    final request = ++revision;
    if (!backend.signedIn && !widget.publicBrowse) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
      logoRequests.clear();
    });
    try {
      final result = widget.publicBrowse && !backend.signedIn
          ? await store.loadPublic()
          : await store.load();
      if (mounted && request == revision) {
        setState(() => data = result);
        final pending = backend.signedIn ? await store.pendingJob() : null;
        final jobId =
            pending ??
            (widget.publicBrowse && !openedSharedJob
                ? Uri.base.queryParameters['job']
                : null);
        openedSharedJob = true;
        final job = result.find('jobs', jobId);
        if (job != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) jobDetails(job);
          });
        }
      }
    } catch (_) {
      if (mounted && request == revision) {
        setState(
          () => error =
              'Your workspace could not load. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted && request == revision) setState(() => loading = false);
    }
  }

  Future<bool> run(
    Future<void> Function() operation, {
    String message = 'Saved.',
  }) async {
    if (busy) return false;
    final actor = backend.userId;
    setState(() => busy = true);
    try {
      await operation();
      if (!mounted || actor != backend.userId) return false;
      await refresh();
      if (mounted) notice(message);
      return true;
    } on PostgrestException catch (e) {
      if (mounted && actor == backend.userId) {
        notice(
          e.code == '23505' ? 'You already applied for this role.' : e.message,
        );
      }
    } catch (_) {
      if (mounted && actor == backend.userId) {
        notice(
          'Unable to complete that action. Your input is kept; check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    return false;
  }

  Future<bool> act(
    String action,
    PlatformRow payload, {
    String message = 'Saved.',
  }) => run(() async {
    await store.action(action, payload);
  }, message: message);
  void notice(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  List<PlatformRow> rows(String key) => data!.rows(key);
  List<String> get tabs => switch (data?.role) {
    'guest' => ['Discover'],
    'employer' => [
      'Overview',
      'Jobs',
      'Applicants',
      'Company',
      'Notifications',
      'Settings',
    ],
    'admin' => [
      'Overview',
      'Employers',
      'Users',
      'Companies',
      'Jobs',
      'Reports',
      'Audit log',
      'Account requests',
      'Privacy requests',
      'Retention review',
      'Platform settings',
    ],
    _ => [
      'Overview',
      'Discover',
      'Saved',
      'Applications',
      'Profile',
      'Résumé',
      'Notifications',
      'Employer request',
      'Settings',
    ],
  };
  void go(String value) {
    setState(() {
      page = value;
      search = '';
      filter = 'All';
      start = 0;
    });
  }

  IconData icon(String value) => switch (value) {
    'Overview' => Icons.grid_view_outlined,
    'Discover' => Icons.search,
    'Saved' => Icons.bookmark_border,
    'Applications' || 'Applicants' => Icons.assignment_outlined,
    'Profile' || 'Users' => Icons.person_outline,
    'Résumé' => Icons.description_outlined,
    'Notifications' => Icons.notifications_none,
    'Company' || 'Employers' || 'Employer request' => Icons.business_outlined,
    'Jobs' => Icons.work_outline,
    'Reports' => Icons.flag_outlined,
    'Audit log' => Icons.history,
    _ => Icons.settings_outlined,
  };
  Widget card(String title, String body, [List<Widget> actions = const []]) =>
      WorkspacePanel(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty)
              SelectableText(body, style: const TextStyle(height: 1.5)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final action in actions)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth),
                        child: action,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
  Widget button(String title, VoidCallback? callback, {bool primary = false}) =>
      primary
      ? FilledButton(onPressed: busy ? null : callback, child: Text(title))
      : OutlinedButton(onPressed: busy ? null : callback, child: Text(title));
  Widget simple(String title, String body, List<Widget> actions) => Scaffold(
    appBar: AppBar(title: const Text('nextrole.')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: card(title, body, actions),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (!backend.signedIn && !widget.publicBrowse) {
      return simple('Your workspace awaits.', 'Sign in to continue.', [
        button('Sign in', () async {
          await Navigator.pushNamed(context, '/login');
          if (mounted) refresh();
        }, primary: true),
        button(
          'Explore sample jobs',
          () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
        ),
      ]);
    }
    if (loading && data == null) {
      return simple('Opening your workspace…', '', [
        const LinearProgressIndicator(),
      ]);
    }
    if (error != null) {
      return simple('A little interruption.', error!, [
        button('Try again', refresh),
      ]);
    }
    if (data == null) {
      return simple('Workspace unavailable', 'Please sign in again.', []);
    }
    if (data!.suspended) {
      return simple(
        'Account access paused',
        'Your account has been suspended. Ask the project owner for a review.',
        [
          button('Sign out', backend.signOut),
          button(
            'Privacy requests',
            () => Navigator.pushNamed(context, '/privacy-request'),
          ),
        ],
      );
    }
    if (widget.requiredRole != null && widget.requiredRole != data!.role) {
      return simple(
        'This workspace is restricted.',
        'Your account cannot access this area.',
        [
          button(
            'Open my workspace',
            () => Navigator.pushReplacementNamed(context, '/workspace'),
          ),
        ],
      );
    }
    if (!tabs.contains(page)) page = tabs.first;
    return frame(
      title: pageTitle,
      subtitle: pageDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (textOf(rows('settings').firstOrNull?['maintenance_notice'])
              .isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Notice(
                textOf(rows('settings').first['maintenance_notice']),
              ),
            ),
          ...content(),
        ],
      ),
    );
  }

  String get personName => textOf(data!.member['full_name']).isEmpty
      ? 'there'
      : textOf(data!.member['full_name']);
  String get ownCompany => textOf(
    rows('companies').where((c) => c['owner_id'] == owner).firstOrNull?['name'],
  );
  String get pageTitle => switch (page) {
    'Overview' =>
      data!.role == 'admin'
          ? 'Admin overview'
          : data!.role == 'employer'
          ? 'Employer dashboard'
          : 'Welcome back, ${personName.split(' ').first}',
    'Discover' => 'Find your next possibility',
    'Profile' => 'My profile',
    'Saved' => 'Saved jobs',
    'Résumé' => 'Private résumé manager',
    'Employers' => 'Employer approvals',
    'Companies' => 'Company management',
    'Company' => 'Company profile editor',
    'Jobs' => data!.role == 'admin' ? 'Job moderation' : 'Manage jobs',
    'Users' => 'User management',
    _ => page,
  };
  String get pageDescription => switch (page) {
    'Overview' =>
      data!.role == 'employee'
          ? 'Here’s where things stand. Take your next step at your own pace.'
          : 'Clear details. A deliberate next step.',
    'Discover' => 'Clear details, room to think and no pressure to rush.',
    'Profile' => 'Your story, in your own words.',
    'Saved' => 'A little space for the possibilities you want to revisit.',
    'Applications' =>
      'Your private work and submitted applications, clearly separated.',
    'Applicants' =>
      'Review only the applications submitted to your company’s jobs.',
    'Résumé' => 'Choose what to share for each application.',
    'Employers' =>
      'Review company-supplied information before enabling employer access.',
    'Companies' => 'Company access and public listing context.',
    'Users' =>
      'Account status and role context. Private files are not available here.',
    'Audit log' =>
      'Read-only moderation history: who acted, what changed, when and why.',
    'Reports' => 'Review reported public content with a purpose-limited view.',
    'Platform settings' =>
      'Manage public categories, locations and workspace notices.',
    'Notifications' => 'Updates that are relevant to you.',
    _ => '',
  };
  WorkspaceFrame frame({
    required String title,
    required Widget child,
    String subtitle = '',
    VoidCallback? back,
  }) => WorkspaceFrame(
    role: data!.role,
    name: personName,
    company: ownCompany,
    page: page,
    tabs: tabs,
    title: title,
    subtitle: subtitle,
    loading: loading || busy,
    onBack: back,
    onAccount: openAccount,
    onRefresh: refresh,
    onSignOut: backend.signedIn
        ? () async {
            if (await confirm(
              'Sign out of this workspace?',
              'You will need to sign in again to access your private records.',
              accept: 'Sign out',
            )) {
              await backend.signOut();
            }
          }
        : null,
    onNavigate: (tab) async {
      if (detailDepth > 0) {
        await Navigator.of(context).maybePop();
        if (!mounted || detailDepth > 0) return;
      }
      go(tab);
    },
    child: child,
  );

  Future<T?> detail<T>(
    String title,
    Widget Function(BuildContext) body, {
    String subtitle = '',
  }) async {
    detailDepth++;
    try {
      return await Navigator.push<T>(
        context,
        MaterialPageRoute<T>(
          builder: (ctx) => frame(
            title: title,
            subtitle: subtitle,
            back: () => Navigator.maybePop(ctx),
            child: body(ctx),
          ),
        ),
      );
    } finally {
      detailDepth--;
    }
  }

  List<Widget> content() => switch (page) {
    'Overview' => overview(),
    'Profile' => [
      card(
        'A good place to begin.',
        'Five short steps, at your own pace. Each completed profile step is saved privately.',
        [
          button(
            'Start guided setup',
            () => detail<void>(
              'Set up your profile',
              (_) => GuidedProfileSetup(
                embedded: true,
                onResume: openAccount,
                initial: {
                  ...Map<String, dynamic>.from(data!.member['profile'] as Map),
                  'full_name': data!.member['full_name'],
                },
                onSave: (values) =>
                    act('profile_save', values, message: 'Profile step saved.'),
              ),
            ),
            primary: true,
          ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Notice(
          'Private profile · Only the details you review and submit are shared with that company. Existing submissions keep their original snapshots.',
        ),
      ),
      WorkspacePanel(child: profileForm()),
    ],
    'Résumé' => [const PrivateResumeManager()],
    'Discover' => jobs(public: true),
    'Saved' => jobs(public: true, savedOnly: true),
    'Jobs' => jobs(),
    'Applications' || 'Applicants' => applications(),
    'Company' || 'Employer request' => company(),
    'Companies' => companies(),
    'Employers' => employers(),
    'Users' => users(),
    'Reports' => reports(),
    'Audit log' => audit(),
    'Notifications' => notifications(),
    'Account requests' => accountRequests(),
    'Privacy requests' => privacyQueue(),
    'Retention review' => [retentionReview()],
    'Platform settings' => [
      const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Notice(
          'Authorization is server-owned. This editor controls public categories, locations and notice text only.',
        ),
      ),
      WorkspacePanel(child: platformSettings()),
    ],
    _ => settings(),
  };
  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    ),
  );
  Widget actions(List<Widget> children) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 520
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: child,
                ),
            ],
          )
        : Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: children[i]),
              ],
            ],
          ),
  );
  Widget summary(Map<String, int> counts) => LayoutBuilder(
    builder: (context, c) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in counts.entries) ...[
              if (entry.key != counts.keys.first)
                SizedBox(width: c.maxWidth < 500 ? 8 : 24),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(c.maxWidth < 500 ? 14 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Nextrole.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Nextrole.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  int get profileComplete {
    final p = Map<String, dynamic>.from(data!.member['profile'] as Map);
    return [
      personName != 'there',
      textOf(data!.member['email'] ?? backend.email).isNotEmpty,
      textOf(p['location']).isNotEmpty,
      textOf(p['skills']).isNotEmpty,
      textOf(p['preferences']).isNotEmpty,
    ].where((v) => v).length;
  }

  List<Widget> overview() {
    final role = data!.role;
    if (role == 'employee') {
      final current = rows('applications')
          .where(
            (r) => !['withdrawn', 'rejected', 'hired'].contains(r['status']),
          )
          .firstOrNull;
      final snapshot = Map<String, dynamic>.from(
        current?['snapshot'] as Map? ?? {},
      );
      final unread = rows('notifications')
          .where((r) => r['read'] != true)
          .length;
      final savedJobs = rows('jobs').where(saved).take(2).toList();
      return [
        summary({
          'Saved roles': rows('saved').length,
          'Private drafts': rows('drafts').length,
          'Submitted': rows('applications').length,
        }),
        if (current != null)
          WorkspacePanel(
            title: 'Your application in progress',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textOf(snapshot['job_title']),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  textOf(snapshot['company_name']),
                  style: const TextStyle(color: Nextrole.muted),
                ),
                const SizedBox(height: 14),
                StatusBadge(textOf(current['status'])),
                const SizedBox(height: 12),
                LabeledValue('Submitted', dateOf(current['created_at'])),
                SizedBox(
                  width: double.infinity,
                  child: button(
                    'View application',
                    () => applicationDetails(current),
                  ),
                ),
              ],
            ),
          ),
        WorkspaceColumns(
          asideFirstOnSmall: true,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section('Saved for your next step'),
              if (savedJobs.isEmpty)
                card(
                  'Make room for possibilities.',
                  'Save a role while you explore and find it here whenever you return.',
                  [
                    button(
                      'Discover roles',
                      () => go('Discover'),
                      primary: true,
                    ),
                  ],
                ),
              for (final job in savedJobs) jobCard(job, public: true),
              if (savedJobs.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: button('View all saved jobs', () => go('Saved')),
                ),
            ],
          ),
          aside: Column(
            children: [
              WorkspacePanel(
                title: 'Your profile · ${profileComplete * 20}%',
                tinted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$profileComplete of 5 required items complete.'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: profileComplete / 5,
                      backgroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Name, email, location, skills and preferred roles. Résumé and portfolio are optional.',
                      style: TextStyle(fontSize: 12, color: Nextrole.muted),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: button(
                        'Complete profile',
                        () => go('Profile'),
                        primary: true,
                      ),
                    ),
                  ],
                ),
              ),
              card(
                'Notifications · $unread unread',
                rows('notifications').isEmpty
                    ? 'You’re all caught up. New application updates appear here.'
                    : textOf(rows('notifications').first['body']),
                [button('View notifications', () => go('Notifications'))],
              ),
              card(
                'A private place to prepare',
                'Saving a draft shares nothing. Review it whenever you’re ready.',
                [button('Open applications', () => go('Applications'))],
              ),
            ],
          ),
        ),
      ];
    }
    if (role == 'employer') {
      final company = rows('companies')
          .where((r) => r['owner_id'] == owner)
          .firstOrNull;
      final pending = rows('applications')
          .where((r) => r['status'] == 'submitted')
          .firstOrNull;
      final ownJobs = rows('jobs')
          .where((r) => r['owner_id'] == owner)
          .toList();
      final nextClosing =
          ownJobs.where((r) => r['status'] == 'published').toList()..sort(
            (a, b) => textOf(a['closes_at']).compareTo(textOf(b['closes_at'])),
          );
      return [
        if (company?['status'] != 'approved')
          WorkspacePanel(
            title:
                'Company access · ${label(company?['status'] ?? 'not requested')}',
            tinted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textOf(company?['review_reason']).isEmpty
                      ? 'Your company needs approved access before publishing jobs or reviewing applicants.'
                      : textOf(company?['review_reason']),
                ),
                const SizedBox(height: 16),
                button('Review company request', () => go('Company')),
              ],
            ),
          ),
        actions([
          Text(
            'Good to see you, ${personName.split(' ').first}.',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          button('Post a job', editJob, primary: true),
        ]),
        const SizedBox(height: 20),
        summary({
          'Active jobs': ownJobs
              .where((r) => r['status'] == 'published')
              .length,
          'Awaiting first review': rows('applications')
              .where((r) => r['status'] == 'submitted')
              .length,
          'Total applicants': rows('applications').length,
        }),
        WorkspacePanel(
          title: 'Your next review',
          tinted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pending == null
                    ? 'You’re up to date. New submissions will appear here.'
                    : '${textOf((pending['snapshot'] as Map)['full_name'])} is awaiting a first review. Read the submitted snapshot before choosing the next status.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: button(
                  pending == null ? 'View applicants' : 'Review application',
                  () => pending == null
                      ? go('Applicants')
                      : applicationDetails(pending),
                  primary: true,
                ),
              ),
            ],
          ),
        ),
        WorkspaceColumns(
          main: card(
            'Upcoming closing date',
            nextClosing.isEmpty
                ? 'No published jobs are closing.'
                : '${textOf(nextClosing.first['title'])}\nCloses ${dateOf(nextClosing.first['closes_at'])}',
            [button('Manage jobs', () => go('Jobs'))],
          ),
          aside: card(
            'Recent applicant activity',
            rows('applications').isEmpty
                ? 'No applications yet.'
                : rows('applications')
                      .take(3)
                      .map(
                        (a) =>
                            '${textOf((a['snapshot'] as Map)['full_name'])} · ${label(a['status'])}',
                      )
                      .join('\n'),
            [button('View all applicants', () => go('Applicants'))],
          ),
        ),
        section('Jobs in progress'),
        for (final job in ownJobs.take(3)) jobCard(job),
      ];
    }
    final pendingCompanies =
        rows('companies').where((r) => r['status'] == 'pending').toList()..sort(
          (a, b) => textOf(a['created_at']).compareTo(textOf(b['created_at'])),
        );
    return [
      summary({
        'Pending employers': pendingCompanies.length,
        'Pending jobs': rows('jobs')
            .where((r) => r['status'] == 'pending')
            .length,
        'Open reports': rows('reports')
            .where((r) => r['status'] == 'open')
            .length,
      }),
      WorkspacePanel(
        title: 'Start with the oldest access request',
        tinted: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pendingCompanies.isEmpty
                  ? 'No employer requests are waiting. Your queues are up to date.'
                  : '${textOf(pendingCompanies.first['name'])} has supplied company information for review.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: button(
                'Review employer requests',
                () => go('Employers'),
                primary: true,
              ),
            ),
          ],
        ),
      ),
      section('Your moderation queues'),
      ...rows('jobs')
          .where((r) => r['status'] == 'pending')
          .take(2)
          .map((job) => jobCard(job)),
      if (rows('jobs').where((r) => r['status'] == 'pending').isEmpty)
        card('No jobs awaiting review', 'Submitted listings will appear here.'),
      section('Recent moderation activity'),
      ...rows('audit')
          .take(3)
          .map(
            (r) => recordCard(
              label(r['action']),
              {
                'Target': textOf(r['target']),
                'Date': dateOf(r['created_at']),
                'Reason': textOf(r['reason']),
              },
              [button('View audit log', () => go('Audit log'))],
            ),
          ),
      const Notice(
        'Operational counts describe the latest 500 accessible records per section. No visitor analytics or hiring predictions.',
      ),
    ];
  }

  Widget filterBar(List<String> statuses) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      children: [
        TextField(
          key: ValueKey('search-$page'),
          onChanged: (v) => setState(() {
            search = v;
            start = 0;
          }),
          decoration: const InputDecoration(
            labelText: 'Search this section',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        if (statuses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in ['All', ...statuses])
                  ChoiceChip(
                    label: Text(label(status)),
                    selected: filter == status,
                    onSelected: (_) => setState(() {
                      filter = status;
                      start = 0;
                    }),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
  List<Widget> listing(
    List<PlatformRow> input,
    Widget Function(PlatformRow) tile,
  ) {
    final result =
        input
            .where(
              (r) =>
                  r.values
                      .join(' ')
                      .toLowerCase()
                      .contains(search.toLowerCase()) &&
                  (filter == 'All' || r['status'] == filter),
            )
            .toList()
          ..sort(
            (a, b) =>
                textOf(b['created_at']).compareTo(textOf(a['created_at'])),
          );
    if (result.isEmpty) {
      return [
        card(
          'Nothing here yet.',
          'Try another search or return after the next step in your journey.',
        ),
      ];
    }
    final offset = start >= result.length ? 0 : start;
    return [
      Text(
        '${result.length} matching records${input.length >= 500 ? ' (latest 500 loaded)' : ''}',
        style: const TextStyle(color: Nextrole.muted),
      ),
      const SizedBox(height: 12),
      ...result.skip(offset).take(20).map(tile),
      Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          button(
            'Previous',
            offset == 0 ? null : () => setState(() => start = offset - 20),
          ),
          Text(
            '${offset + 1}–${(offset + 20).clamp(0, result.length)} of ${result.length}',
          ),
          button(
            'Next',
            offset + 20 >= result.length
                ? null
                : () => setState(() => start = offset + 20),
          ),
        ],
      ),
    ];
  }

  String companyName(PlatformRow job) =>
      textOf(data!.find('companies', job['company_id'])?['name']).isEmpty
      ? 'Company unavailable'
      : textOf(data!.find('companies', job['company_id'])?['name']);
  bool saved(PlatformRow job) =>
      rows('saved').any((r) => r['job_id'] == job['id']);
  Widget recordCard(
    String title,
    Map<String, String> values,
    List<Widget> controls,
  ) => WorkspacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Nextrole.blue,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final entries = values.entries.toList();
            if (c.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in entries) LabeledValue(e.key, e.value),
                ],
              );
            }
            return Column(
              children: [
                Container(
                  color: Nextrole.lavender,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in entries)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in entries)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SelectableText(
                              e.value.isEmpty ? 'Not provided' : e.value,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        if (controls.isNotEmpty) ...[
          const SizedBox(height: 12),
          actions(controls),
        ],
      ],
    ),
  );

  Widget jobCard(PlatformRow job, {bool public = false}) {
    final controls = <Widget>[
      button(
        public
            ? 'View job'
            : data!.role == 'admin'
            ? 'Review job content'
            : 'Open job workspace',
        () => jobDetails(job),
      ),
      if (public && data!.role == 'employee')
        button(
          saved(job) ? 'Unsave' : 'Save job',
          () => act('save_job', {'id': job['id'], 'saved': !saved(job)}),
        ),
    ];
    if (!public) {
      return recordCard(textOf(job['title']), {
        'Company / location': '${companyName(job)}\n${textOf(job['location'])}',
        'Arrangement / type':
            '${textOf(job['arrangement'])}\n${textOf(job['employment_type'])}',
        'Closing date': dateOf(job['closes_at']),
        'Status': label(job['status']),
      }, controls);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companyName(job).toUpperCase(),
                style: const TextStyle(fontSize: 12, color: Nextrole.muted),
              ),
              const SizedBox(height: 12),
              Text(
                textOf(job['title']),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${textOf(job['location'])} · ${textOf(job['arrangement'])}\n${textOf(job['employment_type'])} · ${textOf(job['salary'])}',
                style: const TextStyle(color: Nextrole.muted),
              ),
              const SizedBox(height: 16),
              Text(
                textOf(job['description']),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (job['status'] != 'published') ...[
                const SizedBox(height: 12),
                StatusBadge(textOf(job['status'])),
              ],
              const SizedBox(height: 20),
              actions(controls),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            'Posted ${dateOf(job['created_at'])}${saved(job) ? ' · Saved to your account' : ''}',
            style: const TextStyle(fontSize: 12, color: Nextrole.muted),
          ),
        ),
      ],
    );
  }

  List<Widget> jobs({bool public = false, bool savedOnly = false}) {
    var list = rows('jobs');
    if (public) {
      list = list
          .where(
            (r) =>
                (savedOnly ? saved(r) : r['status'] == 'published') &&
                (jobCategory == 'All categories' ||
                    r['category'] == jobCategory) &&
                (arrangement == 'Any arrangement' ||
                    r['arrangement'] == arrangement) &&
                (employment == 'Any type' ||
                    r['employment_type'] == employment),
          )
          .toList();
    } else if (data!.role == 'employer') {
      list = list.where((r) => r['owner_id'] == owner).toList();
    }
    final results = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: listing(list, (job) => jobCard(job, public: public)),
    );
    final filters = WorkspacePanel(
      title: 'Refine your search',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          jobFilter('Category', jobCategory, [
            'All categories',
            ...?rows('settings').firstOrNull?['categories']?.cast<String>(),
          ], (v) => jobCategory = v),
          const SizedBox(height: 16),
          jobFilter('Work arrangement', arrangement, const [
            'Any arrangement',
            'Remote',
            'Hybrid',
            'On-site',
          ], (v) => arrangement = v),
          const SizedBox(height: 16),
          jobFilter('Employment type', employment, const [
            'Any type',
            'Full-time',
            'Part-time',
            'Internship',
            'Contract',
          ], (v) => employment = v),
          const SizedBox(height: 20),
          button(
            'Clear all filters',
            () => setState(() {
              jobCategory = 'All categories';
              arrangement = 'Any arrangement';
              employment = 'Any type';
              search = '';
              start = 0;
            }),
          ),
        ],
      ),
    );
    return [
      if (!public && data!.role == 'employer')
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: button('Post a job', editJob, primary: true),
        ),
      if (savedOnly)
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Notice(
            '${rows('saved').length} roles saved to your account. Removing a bookmark does not delete a draft or withdraw an application.',
          ),
        ),
      filterBar(
        public
            ? []
            : [
                'draft',
                'pending',
                'published',
                'paused',
                'closed',
                'rejected',
                'archived',
              ],
      ),
      if (public && !savedOnly)
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 820
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 250, child: filters),
                    const SizedBox(width: 32),
                    Expanded(child: results),
                  ],
                )
              : Column(children: [filters, results]),
        )
      else
        results,
    ];
  }

  Widget jobFilter(
    String title,
    String current,
    List<String> values,
    void Function(String) select,
  ) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      initialValue: values.contains(current) ? current : values.first,
      key: ValueKey('$title-$current'),
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      items: values
          .toSet()
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: (value) => setState(() {
        select(value!);
        start = 0;
      }),
    ),
  );

  Future<void> jobStatus(PlatformRow job, String status) async {
    if (await confirm(
      'Change job to ${label(status)}?',
      status == 'pending'
          ? 'An administrator must review the listing before it is public.'
          : 'This changes availability for candidates.',
    )) {
      await act('job_status', {
        'id': job['id'],
        'status': status,
      }, message: 'Job ${label(status)}.');
    }
  }

  Future<void> jobDetails(PlatformRow job) async {
    final company = data!.find('companies', job['company_id']);
    final employer = data!.role == 'employer' && job['owner_id'] == owner;
    final admin = data!.role == 'admin';
    final choice = await detail<String>(
      admin
          ? 'Job review detail'
          : employer
          ? 'Job workspace'
          : textOf(job['title']),
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspacePanel(
            tinted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(textOf(job['status'])),
                const SizedBox(height: 12),
                Text(
                  textOf(job['salary']),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Closes ${dateOf(job['closes_at'])} · ${textOf(job['arrangement'])} · ${textOf(job['employment_type'])}',
                ),
              ],
            ),
          ),
          WorkspaceColumns(
            main: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (company != null)
                  WorkspacePanel(
                    title: textOf(company['name']),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        companyLogo(
                          textOf(company['id']),
                          textOf(company['name']),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${textOf(company['location'])} · ${textOf(company['industry'])}',
                          style: const TextStyle(color: Nextrole.muted),
                        ),
                        const SizedBox(height: 16),
                        Text(textOf(company['description'])),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: button(
                            'View company profile',
                            () => companyDetails(company),
                          ),
                        ),
                      ],
                    ),
                  ),
                card('What you will work on', textOf(job['description'])),
                if (textOf(job['requirements']).isNotEmpty)
                  card('What you will bring', textOf(job['requirements'])),
                card(
                  'How you will work',
                  '${textOf(job['location'])} · ${textOf(job['arrangement'])}\n${textOf(job['employment_type'])}',
                ),
                if (textOf(job['benefits']).isNotEmpty)
                  card('Benefits', textOf(job['benefits'])),
                LabeledValue(
                  'Posted / closes',
                  '${dateOf(job['created_at'])} / ${dateOf(job['closes_at'])}',
                ),
                if (job['status'] == 'published' && backend.signedIn)
                  button('Report this job', () => Navigator.pop(ctx, 'report')),
              ],
            ),
            aside: Column(
              children: [
                WorkspacePanel(
                  title: admin
                      ? 'Publication decision'
                      : employer
                      ? 'Manage this role'
                      : 'Your next step',
                  tinted: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LabeledValue('Salary', textOf(job['salary'])),
                      LabeledValue(
                        'Arrangement / type',
                        '${textOf(job['arrangement'])} / ${textOf(job['employment_type'])}',
                      ),
                      if (data!.role == 'employee' &&
                          job['status'] == 'published') ...[
                        const Text(
                          'Prepare privately, then review exactly what you want to share.',
                        ),
                        const SizedBox(height: 16),
                        button(
                          'Prepare application',
                          () => Navigator.pop(ctx, 'apply'),
                          primary: true,
                        ),
                        const SizedBox(height: 12),
                        button(
                          saved(job) ? 'Unsave role' : 'Save role',
                          () => Navigator.pop(ctx, 'save'),
                        ),
                      ],
                      if (data!.role == 'guest' && job['status'] == 'published')
                        button(
                          'Sign in to apply',
                          () => Navigator.pop(ctx, 'signin'),
                          primary: true,
                        ),
                      if (employer) ...[
                        button('Edit job', () => Navigator.pop(ctx, 'edit')),
                        const SizedBox(height: 12),
                        if ([
                          'draft',
                          'rejected',
                          'paused',
                        ].contains(job['status']))
                          button(
                            'Request publication review',
                            () => Navigator.pop(ctx, 'pending'),
                            primary: true,
                          ),
                        if (job['status'] == 'published')
                          button(
                            'Pause job…',
                            () => Navigator.pop(ctx, 'paused'),
                          ),
                        if (!['closed', 'archived'].contains(job['status']))
                          button(
                            'Close job…',
                            () => Navigator.pop(ctx, 'closed'),
                          ),
                        if (job['status'] == 'closed')
                          button(
                            'Archive job…',
                            () => Navigator.pop(ctx, 'archived'),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          '${rows('applications').where((a) => a['job_id'] == job['id']).length} applicants',
                        ),
                        const SizedBox(height: 12),
                        button('Review applicants', () {
                          Navigator.pop(ctx);
                          go('Applicants');
                        }),
                      ],
                      if (admin) ...[
                        if (job['status'] == 'pending') ...[
                          button(
                            'Approve for publication…',
                            () => Navigator.pop(ctx, 'approve'),
                            primary: true,
                          ),
                          const SizedBox(height: 12),
                          button(
                            'Reject with reason…',
                            () => Navigator.pop(ctx, 'reject'),
                          ),
                        ],
                        if (job['status'] == 'published')
                          button(
                            'Remove listing…',
                            () => Navigator.pop(ctx, 'remove'),
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          'Company access approval and job publication are separate decisions. Every moderation decision records a reason.',
                          style: TextStyle(fontSize: 12, color: Nextrole.muted),
                        ),
                      ],
                      const SizedBox(height: 16),
                      button('Share public role', () async {
                        if (job['status'] != 'published') {
                          notice('This role is not publicly listed.');
                          return;
                        }
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '${Backend.siteUrl}/app.html?job=${textOf(job['id'])}#/opportunities',
                          ),
                        );
                        if (mounted) notice('Public job link copied.');
                      }),
                      const SizedBox(height: 12),
                      const Text(
                        'Only the public job is shareable. Private drafts and files are never included.',
                        style: TextStyle(fontSize: 12, color: Nextrole.muted),
                      ),
                    ],
                  ),
                ),
                if (textOf(job['review_reason']).isNotEmpty)
                  card('Moderation note', textOf(job['review_reason'])),
              ],
            ),
          ),
        ],
      ),
      subtitle: '${companyName(job)} · ${textOf(job['location'])}',
    );
    if (!mounted) return;
    if (choice == 'signin') {
      await store.rememberJob(textOf(job['id']));
      if (!mounted) return;
      await Navigator.pushNamed(context, '/login');
      if (mounted && backend.signedIn) refresh();
    }
    if (choice == 'apply') await apply(job);
    if (choice == 'save') {
      await act('save_job', {'id': job['id'], 'saved': !saved(job)});
    }
    if (choice == 'edit') await editJob(job);
    if (['pending', 'paused', 'closed', 'archived'].contains(choice)) {
      await jobStatus(job, choice!);
    }
    if (choice == 'approve') {
      await moderate('job_status', job['id'], 'published');
    }
    if (choice == 'reject') await moderate('job_status', job['id'], 'rejected');
    if (choice == 'remove') await moderate('job_status', job['id'], 'closed');
    if (choice == 'report') {
      await editor(
        'Report this job',
        const [
          FormFieldSpec(
            'reason',
            'What should we review?',
            min: 10,
            max: 2000,
            lines: 5,
          ),
        ],
        description: 'Describe the issue without sensitive personal information. Administrators can read reports.',
        submit: 'Send report',
        save: (values) => act('report_job', {
          'id': job['id'],
          ...values,
        }, message: 'Report received.'),
      );
    }
  }

  Future<void> companyDetails(PlatformRow company) async {
    await detail<void>(
      textOf(company['name']),
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspacePanel(
            title: textOf(company['industry']),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                companyLogo(textOf(company['id']), textOf(company['name'])),
                const SizedBox(height: 16),
                LabeledValue('Location', textOf(company['location'])),
                SelectableText(textOf(company['description'])),
                const SizedBox(height: 24),
                if (textOf(company['website']).startsWith('https://'))
                  button(
                    'Company website',
                    () => openUrl(textOf(company['website'])),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Notice(
              'Company information is supplied by the employer. Access approval is moderation approval, not identity verification.',
            ),
          ),
          section('Open roles'),
          ...rows('jobs')
              .where(
                (job) =>
                    job['company_id'] == company['id'] &&
                    job['status'] == 'published',
              )
              .map((job) => jobCard(job, public: true)),
        ],
      ),
      subtitle: 'Supplied company profile · ${textOf(company['location'])}',
    );
  }

  Future<void> editJob([PlatformRow? job]) async {
    await editor(
      job == null ? 'Create a job' : 'Edit job',
      [
        FormFieldSpec('title', 'Job title', min: 2, max: 150),
        FormFieldSpec('location', 'Location', min: 2, max: 200),
        FormFieldSpec(
          'category',
          'Category',
          choices: rows('settings').first['categories'].cast<String>(),
        ),
        FormFieldSpec(
          'employment_type',
          'Employment type',
          choices: ['Full-time', 'Part-time', 'Internship', 'Contract'],
        ),
        FormFieldSpec(
          'arrangement',
          'Work arrangement',
          choices: ['Remote', 'Hybrid', 'On-site'],
        ),
        FormFieldSpec(
          'salary',
          'Salary, currency and pay period',
          min: 2,
          max: 200,
        ),
        FormFieldSpec(
          'description',
          'Responsibilities',
          min: 20,
          max: 12000,
          lines: 6,
        ),
        FormFieldSpec(
          'requirements',
          'Requirements',
          max: 8000,
          lines: 4,
          required: false,
        ),
        FormFieldSpec(
          'benefits',
          'Benefits',
          max: 5000,
          lines: 3,
          required: false,
        ),
        FormFieldSpec('closes_at', 'Closing date (YYYY-MM-DD)', date: true),
      ],
      initial:
          job ??
          {
            'closes_at': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String()
                .split('T')
                .first,
          },
      description: 'Save a draft, preview it, then submit it for approval. Editing a published job returns it to draft.',
      submit: 'Save job draft',
      staged: true,
      save: (values) => act('job_save', {
        ...values,
        if (job != null) 'id': job['id'],
      }, message: 'Job draft saved.'),
    );
  }

  Widget profileForm() => RecordEditor(
    key: ValueKey(
      'profile-${textOf(data!.member['id'])}-${data!.member['profile'].toString().hashCode}',
    ),
    title: 'Make your profile yours.',
    fields: const [
      FormFieldSpec('full_name', 'Full name', min: 2, max: 200),
      FormFieldSpec(
        'headline',
        'Professional headline',
        max: 200,
        required: false,
      ),
      FormFieldSpec('location', 'Location', max: 200, required: false),
      FormFieldSpec('bio', 'About you', max: 2000, lines: 4, required: false),
      FormFieldSpec('skills', 'Skills', max: 1000, lines: 2, required: false),
      FormFieldSpec(
        'education',
        'Education',
        max: 3000,
        lines: 4,
        required: false,
      ),
      FormFieldSpec(
        'experience',
        'Experience',
        max: 4000,
        lines: 4,
        required: false,
      ),
      FormFieldSpec(
        'portfolio',
        'Portfolio URL',
        max: 500,
        required: false,
        url: true,
      ),
      FormFieldSpec(
        'preferences',
        'Preferred roles and work arrangements',
        max: 500,
        lines: 2,
        required: false,
      ),
    ],
    initial: {
      ...Map<String, dynamic>.from(data!.member['profile'] as Map),
      'full_name': data!.member['full_name'],
    },
    onSave: (values) => act('profile_save', values, message: 'Profile saved.'),
  );
  List<Widget> company() {
    final current = rows('companies')
        .where((r) => r['owner_id'] == owner)
        .firstOrNull;
    return [
      if (current != null)
        card(
          'Company logo',
          'PNG, up to 2 MB. The logo is visible with your approved company profile.',
          [
            companyLogo(textOf(current['id']), textOf(current['name'])),
            button('Upload / replace logo', () async {
              final file = await FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: ['png'],
              );
              if (file == null) return;
              final length = await file.length();
              if (length == null || length > 2 * 1024 * 1024) {
                if (mounted) notice('Choose a PNG image up to 2 MB.');
                return;
              }
              final bytes = await file.readAsBytes();
              await run(
                () => store.uploadLogo(textOf(current['id']), bytes),
                message: 'Company logo saved.',
              );
            }),
            button('Remove logo', () async {
              if (await confirm(
                'Remove company logo?',
                'Your company information stays unchanged.',
              )) {
                await run(() async {
                  await store.client.storage
                      .from('nextrole-company-logos')
                      .remove(['${current['id']}/logo.png']);
                }, message: 'Logo removed.');
              }
            }),
          ],
        ),
      if (current != null)
        card(
          'Employer request: ${label(current['status'])}',
          textOf(current['review_reason']),
        ),
      if (current?['status'] == 'approved')
        card(
          'Hiring access is enabled.',
          'Your company can create listings and submit them for review.',
          [
            button(
              'Open employer workspace',
              () => Navigator.pushReplacementNamed(context, '/employer'),
              primary: true,
            ),
          ],
        ),
      WorkspacePanel(
        child: RecordEditor(
          key: ValueKey('company-${textOf(current?['id'])}'),
          title: current == null
              ? 'Request employer access'
              : 'Company details',
          description: 'Use a fictional company for this portfolio. An administrator reviews requests. Approval enables posting; it is not identity verification.',
          fields: const [
            FormFieldSpec('name', 'Company name', min: 2, max: 120),
            FormFieldSpec(
              'website',
              'Company website (HTTPS)',
              required: false,
              url: true,
            ),
            FormFieldSpec(
              'location',
              'Company location',
              max: 200,
              required: false,
            ),
            FormFieldSpec('industry', 'Industry', max: 120, required: false),
            FormFieldSpec(
              'description',
              'About the company and hiring purpose',
              max: 5000,
              lines: 6,
              required: false,
            ),
          ],
          initial: current ?? {},
          submit: current?['status'] == 'approved'
              ? 'Save company'
              : 'Send for review',
          onSave: (values) => act(
            current == null ? 'company_request' : 'company_save',
            values,
            message: 'Company details saved.',
          ),
        ),
      ),
      if (current != null)
        SizedBox(
          width: double.infinity,
          child: button(
            'Preview saved company profile',
            () => companyDetails(current),
          ),
        ),
    ];
  }

  Widget companyLogo(String id, String name) => FutureBuilder<String?>(
    future: logoRequests.putIfAbsent(id, () => store.logoUrl(id)),
    builder: (context, snapshot) => SizedBox(
      width: 72,
      height: 72,
      child: snapshot.data == null
          ? const Icon(Icons.business_outlined, size: 40)
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                snapshot.data!,
                fit: BoxFit.contain,
                semanticLabel: '$name logo',
                errorBuilder: (_, error, stack) =>
                    const Icon(Icons.business_outlined, size: 40),
              ),
            ),
    ),
  );

  List<Widget> employers() => [
    filterBar(['pending', 'approved', 'rejected']),
    const Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Notice(
        'Approval is not identity verification. It enables company-scoped tools; each job still requires separate moderation.',
      ),
    ),
    ...listing(
      rows('companies'),
      (r) => recordCard(
        textOf(r['name']),
        {
          'Company': textOf(r['name']),
          'Location / industry':
              '${textOf(r['location'])}\n${textOf(r['industry'])}',
          'Requested': dateOf(r['created_at']),
          'Status': label(r['status']),
        },
        [button('Review employer request', () => employerReview(r))],
      ),
    ),
  ];

  Future<void> employerReview(PlatformRow company) async {
    final member = data!.find('members', company['owner_id']);
    final choice = await detail<String>(
      'Employer review',
      (ctx) => WorkspaceColumns(
        main: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Notice(
                'Review supplied company information. This decision grants platform access; it does not publish jobs or verify identity.',
              ),
            ),
            WorkspacePanel(
              title: textOf(company['name']),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  companyLogo(textOf(company['id']), textOf(company['name'])),
                  const SizedBox(height: 20),
                  LabeledValue(
                    'Supplied company name',
                    textOf(company['name']),
                  ),
                  LabeledValue('Website', textOf(company['website'])),
                  LabeledValue(
                    'Industry / location',
                    '${textOf(company['industry'])} · ${textOf(company['location'])}',
                  ),
                  LabeledValue(
                    'Hiring purpose',
                    textOf(company['description']),
                  ),
                  LabeledValue(
                    'Requesting employer',
                    textOf(member?['full_name']),
                  ),
                  LabeledValue('Work email', textOf(member?['email'])),
                ],
              ),
            ),
            if (textOf(company['review_reason']).isNotEmpty)
              card('Last decision reason', textOf(company['review_reason'])),
          ],
        ),
        aside: WorkspacePanel(
          title: 'Record your decision',
          tinted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBadge(textOf(company['status'])),
              const SizedBox(height: 20),
              const Text(
                'A specific reason is required before saving. The employer can see the decision reason.',
              ),
              const SizedBox(height: 20),
              if (company['status'] != 'approved')
                button(
                  'Approve employer',
                  () => Navigator.pop(ctx, 'approved'),
                  primary: true,
                ),
              const SizedBox(height: 12),
              if (company['status'] != 'rejected')
                button('Reject / revoke', () => Navigator.pop(ctx, 'rejected')),
            ],
          ),
        ),
      ),
      subtitle: '${textOf(company['name'])} · ${label(company['status'])}',
    );
    if (choice != null && mounted) {
      await moderate('company_review', company['id'], choice);
    }
  }

  List<Widget> companies() => [
    filterBar(['pending', 'approved', 'rejected']),
    ...listing(
      rows('companies'),
      (c) => recordCard(
        textOf(c['name']),
        {
          'Company': textOf(c['name']),
          'Owner': textOf(data!.find('members', c['owner_id'])?['full_name']),
          'Public jobs': rows('jobs')
              .where(
                (j) => j['company_id'] == c['id'] && j['status'] == 'published',
              )
              .length
              .toString(),
          'Access': label(c['status']),
        },
        [
          button('View company context', () => companyDetails(c)),
          button('Review access', () => employerReview(c)),
        ],
      ),
    ),
  ];

  List<Widget> applications() {
    final candidate = data!.role == 'employee';
    return [
      filterBar([
        'submitted',
        'under_review',
        'shortlisted',
        'interview',
        'offer',
        'hired',
        'rejected',
        'withdrawn',
      ]),
      if (!candidate)
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Notice(
            'Only submitted applications appear here. Candidate private drafts, file libraries and other companies’ applications are never available.',
          ),
        ),
      section(
        '${candidate ? 'Submitted' : 'Applicants'} · ${rows('applications').length}',
      ),
      ...listing(rows('applications'), (app) {
        final snapshot = Map<String, dynamic>.from(app['snapshot'] as Map);
        if (!candidate) {
          return recordCard(
            textOf(snapshot['full_name']),
            {
              'Applicant': textOf(snapshot['full_name']),
              'Job': textOf(snapshot['job_title']),
              'Received': dateOf(app['created_at']),
              'Status': label(app['status']),
            },
            [button('View application', () => applicationDetails(app))],
          );
        }
        return WorkspacePanel(
          title: textOf(snapshot['job_title']),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                textOf(snapshot['company_name']),
                style: const TextStyle(color: Nextrole.muted),
              ),
              const SizedBox(height: 16),
              StatusBadge(textOf(app['status'])),
              const SizedBox(height: 20),
              LabeledValue(
                'Submitted / last update',
                '${dateOf(app['created_at'])} / ${dateOf(app['updated_at'] ?? app['created_at'])}',
              ),
              const LabeledValue(
                'Submission snapshot',
                'Contact, cover note and a separate résumé copy',
              ),
              SizedBox(
                width: double.infinity,
                child: button(
                  'View application',
                  () => applicationDetails(app),
                ),
              ),
            ],
          ),
        );
      }),
      if (candidate) ...[
        const SizedBox(height: 32),
        section('Private drafts · ${rows('drafts').length}'),
        ...rows(
          'drafts',
        ).where((r) => data!.find('jobs', r['job_id']) != null).map((draft) {
          final job = data!.find('jobs', draft['job_id'])!;
          return WorkspacePanel(
            title: textOf(job['title']),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${companyName(job)} · ${textOf(job['location'])}'),
                const SizedBox(height: 16),
                const StatusBadge('Private draft · Not submitted'),
                const SizedBox(height: 16),
                const Text(
                  'No submitted date or hiring status exists for this draft.',
                  style: TextStyle(fontSize: 12, color: Nextrole.muted),
                ),
                const SizedBox(height: 20),
                actions([
                  button(
                    'Continue private draft',
                    () => apply(job),
                    primary: true,
                  ),
                  button('Delete draft', () async {
                    if (await confirm(
                      'Delete this draft?',
                      'Submitted applications are unaffected.',
                    )) {
                      await run(
                        () => backend.deleteDraft(textOf(job['id'])),
                        message: 'Draft deleted.',
                      );
                    }
                  }),
                ]),
              ],
            ),
          );
        }),
        card(
          'Private means private.',
          'Saving a draft shares nothing. Original sample-role drafts remain in the sample discovery area.',
          [
            button(
              'Open sample drafts',
              () => Navigator.pushNamed(context, '/'),
            ),
          ],
        ),
      ],
    ];
  }

  Future<void> apply(PlatformRow job) async {
    ResumeFile? selectedResume;
    if (rows('applications').any((r) => r['job_id'] == job['id'])) {
      notice(
        'You already applied to this role. Open Applications to track it.',
      );
      return;
    }
    final draft = rows('drafts')
        .where((r) => r['job_id'] == job['id'])
        .firstOrNull;
    await editor(
      'Prepare your application',
      const [
        FormFieldSpec('full_name', 'Full name', min: 2, max: 120),
        FormFieldSpec('email', 'Email address', email: true, max: 254),
        FormFieldSpec(
          'introduction',
          'Introduction / cover note',
          max: 5000,
          lines: 6,
          required: false,
        ),
      ],
      initial:
          draft ??
          {'full_name': data!.member['full_name'], 'email': backend.email},
      description:
          '${textOf(job['title'])} at ${companyName(job)}. Upload your private PDF from your account before submission.',
      submit: 'Continue to review',
      secondary: 'Save private draft',
      extra: ResumeSelector(
        onChanged: (file) => selectedResume = file,
        onManage: () => detail<void>(
          'Private résumé library',
          (_) => const PrivateResumeManager(),
        ),
      ),
      onSecondary: (values) => run(
        () => backend.saveDraft(
          textOf(job['id']),
          values['full_name'],
          values['email'],
          values['introduction'],
        ),
        message: 'Private draft saved.',
      ),
      save: (values) async {
        return await reviewApplication(job, values, selectedResume);
      },
    );
  }

  Widget timelinePanel(List<PlatformRow> events) => WorkspacePanel(
    title: 'Application status',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final event in events.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DesignIcon('event-marker'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label(event['status']),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateOf(event['created_at']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Nextrole.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(textOf(event['message'])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (events.isEmpty) const Text('No status events yet.'),
      ],
    ),
  );

  Future<bool> reviewApplication(
    PlatformRow job,
    PlatformRow values,
    ResumeFile? selected,
  ) async {
    if (selected == null) {
      notice(
        'Choose a private résumé version before review. You can still save a private draft.',
      );
      return false;
    }
    late PreparedResume prepared;
    try {
      prepared = await store.prepareResume(selected);
    } catch (_) {
      if (mounted) {
        notice(
          'Your private résumé could not be checked. Your input is kept; please retry.',
        );
      }
      return false;
    }
    if (!mounted) return false;
    var submitting = false;
    return await detail<bool>(
          'Review before you submit',
          (ctx) => StatefulBuilder(
            builder: (context, update) => PopScope(
              canPop: !submitting,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Notice(
                      'You decide when to share. Saving a private draft did not share anything. Submit application shares the details below with this company for this role.',
                    ),
                  ),
                  WorkspacePanel(
                    title: 'Recipient and role',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LabeledValue('Company', companyName(job)),
                        LabeledValue('Job', textOf(job['title'])),
                        LabeledValue(
                          'Location / arrangement',
                          '${textOf(job['location'])} / ${textOf(job['arrangement'])}',
                        ),
                        LabeledValue('Salary', textOf(job['salary'])),
                      ],
                    ),
                  ),
                  WorkspacePanel(
                    title: 'Your contact details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LabeledValue('Name', textOf(values['full_name'])),
                        LabeledValue('Email', textOf(values['email'])),
                      ],
                    ),
                  ),
                  WorkspacePanel(
                    title: 'Selected résumé snapshot',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DesignIcon('file-text'),
                        const SizedBox(height: 16),
                        const StatusBadge('Only this file will be shared'),
                        const SizedBox(height: 16),
                        Text(
                          '${prepared.file.label}\n${prepared.bytes.length} bytes · PDF. Only this selected version is copied to the submission.',
                        ),
                        const SizedBox(height: 20),
                        button(
                          'Open selected résumé',
                          submitting
                              ? null
                              : () async {
                                  try {
                                    await openUrl(
                                      await store.privateResumeUrl(
                                        prepared.file,
                                      ),
                                    );
                                  } catch (_) {
                                    if (mounted) {
                                      notice('Unable to open your résumé.');
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  card(
                    'Your cover note',
                    textOf(values['introduction']).isEmpty
                        ? 'No cover note supplied.'
                        : textOf(values['introduction']),
                  ),
                  WorkspacePanel(
                    title: 'Before you take the next step',
                    tinted: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submit application shares these contact details, this cover note and your current PDF with the company for this job. You cannot edit the submitted snapshot later. You can withdraw an existing submission; withdrawal does not permit a duplicate application.',
                        ),
                        const SizedBox(height: 24),
                        if (submitting)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: LinearProgressIndicator(),
                          ),
                        actions([
                          OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.pop(ctx, false),
                            child: const Text('Back to editing'),
                          ),
                          FilledButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    update(() => submitting = true);
                                    final ok = await run(
                                      () => store.submitApplication(
                                        job,
                                        values,
                                        resume: prepared,
                                      ),
                                      message: 'Application submitted. Track it in Applications.',
                                    );
                                    if (!ctx.mounted) return;
                                    if (ok) {
                                      Navigator.pop(ctx, true);
                                    } else {
                                      update(() => submitting = false);
                                    }
                                  },
                            child: Text(
                              submitting ? 'Submitting…' : 'Submit application',
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          subtitle:
              '${textOf(job['title'])} · ${companyName(job)} · Step 2 of 2 · Not yet submitted',
        ) ??
        false;
  }

  Future<void> applicationDetails(PlatformRow app) async {
    final snapshot = Map<String, dynamic>.from(app['snapshot'] as Map);
    final employer = data!.role == 'employer';
    final finalState = [
      'withdrawn',
      'rejected',
      'hired',
    ].contains(app['status']);
    final events =
        rows('application_events')
            .where((r) => r['application_id'] == app['id'])
            .toList()
          ..sort(
            (a, b) =>
                textOf(a['created_at']).compareTo(textOf(b['created_at'])),
          );
    final note = rows('application_notes')
        .where((r) => r['application_id'] == app['id'])
        .firstOrNull;
    final choice = await detail<String>(
      employer ? 'Application review' : 'Your application',
      (ctx) => WorkspaceColumns(
        main: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkspacePanel(
              title: employer ? 'Submitted contact' : 'Immutable submission',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledValue(
                    'Submitted to',
                    '${textOf(snapshot['company_name'])} · ${textOf(snapshot['job_title'])}',
                  ),
                  LabeledValue('Name', textOf(snapshot['full_name'])),
                  LabeledValue('Email', textOf(snapshot['email'])),
                  LabeledValue('Submitted', dateOf(app['created_at'])),
                ],
              ),
            ),
            WorkspacePanel(
              title: 'Submitted résumé snapshot',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DesignIcon('file-text'),
                  const SizedBox(height: 16),
                  const StatusBadge('Submission-scoped access only'),
                  const SizedBox(height: 16),
                  const Text(
                    'A separate, fixed PDF copy was shared with this application. Your current private file does not replace it.',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: button(
                      'Open submitted résumé',
                      () => Navigator.pop(ctx, 'resume'),
                    ),
                  ),
                ],
              ),
            ),
            card(
              'Submitted cover note',
              textOf(snapshot['introduction']).isEmpty
                  ? 'No cover note supplied.'
                  : textOf(snapshot['introduction']),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Notice(
                'This submission stays as it was. Profile edits and private résumé changes do not replace the submitted snapshot.',
              ),
            ),
            if (employer) timelinePanel(events),
          ],
        ),
        aside: Column(
          children: [
            if (!employer) timelinePanel(events),
            if (!finalState)
              WorkspacePanel(
                title: employer
                    ? 'Update application status'
                    : 'Need to step back?',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      employer
                          ? 'Confirming a status creates a candidate-visible event. Private notes are kept separate.'
                          : 'Withdrawal updates this submission and does not automatically delete the employer’s retained record.',
                    ),
                    const SizedBox(height: 20),
                    button(
                      employer ? 'Update status' : 'Withdraw application',
                      () =>
                          Navigator.pop(ctx, employer ? 'status' : 'withdraw'),
                      primary: employer,
                    ),
                  ],
                ),
              ),
            if (employer)
              WorkspacePanel(
                title: 'Private employer note',
                tinted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textOf(note?['note']).isEmpty
                          ? 'No note yet. Candidates cannot see employer notes.'
                          : textOf(note?['note']),
                    ),
                    const SizedBox(height: 20),
                    button(
                      'Edit private note',
                      () => Navigator.pop(ctx, 'note'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      subtitle:
          '${textOf(snapshot['job_title'])} · ${textOf(snapshot['company_name'])}',
    );
    if (!mounted) return;
    if (choice == 'resume') {
      await run(() async {
        await openUrl(await store.applicationResume(app));
      }, message: 'Résumé opened.');
    }
    if (choice == 'withdraw' &&
        await confirm(
          'Withdraw application?',
          'The employer will see the withdrawn status. This application cannot be resubmitted.',
        )) {
      await act('application_status', {
        'id': app['id'],
        'status': 'withdrawn',
      }, message: 'Application withdrawn.');
    }
    if (choice == 'status') {
      await editor(
        'Update application status',
        const [
          FormFieldSpec(
            'status',
            'New status',
            choices: [
              'under_review',
              'shortlisted',
              'interview',
              'offer',
              'hired',
              'rejected',
            ],
          ),
          FormFieldSpec(
            'message',
            'Candidate-visible message',
            max: 1000,
            lines: 4,
            required: false,
          ),
        ],
        description: 'The candidate sees this status and message. No external email or calendar invitation is sent.',
        submit: 'Update status',
        save: (v) => act('application_status', {
          'id': app['id'],
          ...v,
        }, message: 'Status updated.'),
      );
    }
    if (choice == 'note') {
      await editor(
        'Private employer note',
        const [
          FormFieldSpec('note', 'Note', max: 5000, lines: 6, required: false),
        ],
        initial: note ?? {},
        description:
            'Only the employer for this application can read this note.',
        save: (v) => act('application_note', {'id': app['id'], ...v}),
      );
    }
  }

  List<Widget> notifications() => [
    Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: actions([
        Text(
          '${rows('notifications').where((r) => r['read'] != true).length} unread',
          style: const TextStyle(color: Nextrole.muted),
        ),
        button(
          'Mark all read',
          () => act(
            'notification_read',
            {},
            message: 'Notifications marked read.',
          ),
        ),
      ]),
    ),
    ...listing(
      rows('notifications'),
      (r) => WorkspacePanel(
        title: textOf(r['title']),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusBadge(r['read'] == true ? 'Read' : 'Unread'),
            const SizedBox(height: 16),
            Text(textOf(r['body'])),
            const SizedBox(height: 12),
            Text(
              dateOf(r['created_at']),
              style: const TextStyle(fontSize: 12, color: Nextrole.muted),
            ),
            if (r['read'] != true) ...[
              const SizedBox(height: 20),
              button(
                'Mark read',
                () => act('notification_read', {'id': r['id']}),
              ),
            ],
          ],
        ),
      ),
    ),
    const Notice(
      'These are in-product updates. No external email or calendar delivery is connected.',
    ),
  ];
  List<Widget> users() => [
    filterBar([]),
    ...listing(
      rows('members'),
      (r) => recordCard(
        textOf(r['full_name']),
        {
          'Account': textOf(r['full_name']),
          'Email / role': '${textOf(r['email'])}\n${label(r['role'])}',
          'Registered': dateOf(r['created_at']),
          'Status': r['suspended'] == true ? 'Suspended' : 'Active',
        },
        [button('View account', () => memberDetails(r))],
      ),
    ),
    const Notice(
      'Roles are server-owned. There is no administrator promotion or self-upgrade action.',
    ),
  ];
  Future<void> memberDetails(PlatformRow member) async {
    final choice = await detail<String>(
      'Account detail',
      (ctx) => WorkspaceColumns(
        main: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkspacePanel(
              title: 'Account identity',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledValue('Name', textOf(member['full_name'])),
                  LabeledValue('Account email', textOf(member['email'])),
                  LabeledValue('Role', label(member['role'])),
                  StatusBadge(
                    member['suspended'] == true ? 'Suspended' : 'Active',
                  ),
                  const SizedBox(height: 20),
                  LabeledValue('Registered', dateOf(member['created_at'])),
                ],
              ),
            ),
            const Notice(
              'Private files are not available. This view does not expose candidate drafts, résumé libraries, submitted application payloads or employer notes.',
            ),
          ],
        ),
        aside: card(
          'Account permissions',
          'Role and company ownership are read-only. Suspension blocks private account actions and retains existing applications.',
          [
            if (member['id'] != owner && member['role'] != 'admin')
              button(
                member['suspended'] == true
                    ? 'Reinstate account…'
                    : 'Suspend account…',
                () => Navigator.pop(ctx, 'change'),
              ),
          ],
        ),
      ),
      subtitle: '${textOf(member['full_name'])} · ${label(member['role'])}',
    );
    if (choice == 'change' && mounted) {
      await moderate(
        'member_suspend',
        member['id'],
        null,
        extra: {'suspended': member['suspended'] != true},
      );
    }
  }

  List<Widget> reports() => [
    filterBar(['open', 'in_progress', 'resolved', 'dismissed']),
    ...listing(
      rows('reports'),
      (r) => recordCard(
        'Job report',
        {
          'Job': textOf(
            data!.find('jobs', r['job_id'])?['title'] ?? r['job_id'],
          ),
          'Reported': dateOf(r['created_at']),
          'Status': label(r['status']),
        },
        [button('Open report detail', () => reportDetails(r))],
      ),
    ),
  ];
  Future<void> reportDetails(PlatformRow report) async {
    final id = report['id'];
    await detail<void>(
      'Report detail',
      (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final current = data!.find('reports', id) ?? report;
          final work =
              rows('report_work')
                  .where((w) => w['report_id'] == id)
                  .firstOrNull ??
              <String, dynamic>{};
          final job = data!.find('jobs', current['job_id']);
          final admins = rows('members')
              .where((m) => m['role'] == 'admin' && m['suspended'] != true)
              .toList();
          Future<void> decision(String status) async {
            var expected = current['assigned_revision'] as int;
            await editor(
              'Review report outcome',
              [
                const FormFieldSpec(
                  'reason',
                  'Private resolution summary / decision reason',
                  min: 5,
                  max: 2000,
                  lines: 5,
                ),
                const FormFieldSpec(
                  'public_message',
                  'Message to share with reporter and employer',
                  required: false,
                  max: 2000,
                  lines: 4,
                ),
              ],
              description: 'The decision reason stays in the admin workspace and audit log. Only the optional public message is shared. This action does not remove the listing.',
              submit: 'Confirm ${label(status)}',
              extra: revisionControl(
                'reports',
                id,
                'assigned_revision',
                (version) => expected = version,
              ),
              save: (values) async {
                if (!await confirm(
                  'Record ${label(status)}?',
                  'The report status will change. ${textOf(values['public_message']).isEmpty ? 'No public message will be sent.' : 'The displayed public message will be sent to the reporter and employer.'}',
                  accept: 'Confirm outcome',
                )) {
                  return false;
                }
                return act('report_resolve', {
                  'id': id,
                  'expected_revision': expected,
                  'status': status,
                  ...values,
                }, message: 'Report outcome recorded.');
              },
            );
            if (ctx.mounted) update(() {});
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkspacePanel(
                title: 'Original report',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(textOf(current['status'])),
                    const SizedBox(height: 20),
                    LabeledValue('Reported', dateOf(current['created_at'])),
                    SelectableText(textOf(current['reason'])),
                    const SizedBox(height: 20),
                    const Text(
                      'Reporter contact details and private application history are withheld from this investigation.',
                      style: TextStyle(fontSize: 12, color: Nextrole.muted),
                    ),
                  ],
                ),
              ),
              if (job != null)
                card(
                  'Current listing context',
                  '${textOf(job['title'])} · ${companyName(job)}\n${textOf(job['salary'])}\n${textOf(job['description'])}',
                  [button('Review listing', () => jobDetails(job))],
                ),
              WorkspacePanel(
                title: 'Investigation workspace · administrators only',
                tinted: true,
                child: RecordEditor(
                  key: ValueKey('investigation-$id'),
                  title: 'Assignment and private notes',
                  description: 'These notes are stored separately from public outcomes. Save confirms an authorized database write; it does not notify the reporter.',
                  initial: work,
                  fields: [
                    FormFieldSpec(
                      'reviewer_id',
                      'Assigned reviewer',
                      required: false,
                      choices: ['', ...admins.map((m) => textOf(m['id']))],
                      choiceLabels: {
                        '': 'Unassigned',
                        for (final admin in admins)
                          textOf(admin['id']): textOf(admin['full_name']),
                      },
                    ),
                    const FormFieldSpec(
                      'investigation_note',
                      'Private investigation notes',
                      required: false,
                      max: 10000,
                      lines: 7,
                    ),
                  ],
                  submit: 'Save investigation',
                  onCancel: () => Navigator.pop(ctx),
                  onSave: (values) async {
                    final ok = await act('report_save_work', {
                      'id': id,
                      'expected_revision': current['assigned_revision'],
                      ...values,
                    }, message: 'Private investigation saved.');
                    if (ctx.mounted && ok) update(() {});
                    return ok;
                  },
                ),
              ),
              if (textOf(work['resolution_summary']).isNotEmpty)
                card(
                  'Private resolution summary',
                  textOf(work['resolution_summary']),
                ),
              if (textOf(current['public_message']).isNotEmpty)
                card(
                  'Shared public outcome',
                  textOf(current['public_message']),
                ),
              WorkspacePanel(
                title: 'Resolution controls',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A resolution is separate from private investigation notes. Listing removal requires a separate job moderation decision.',
                    ),
                    const SizedBox(height: 20),
                    if (!['resolved', 'dismissed'].contains(current['status']))
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          button(
                            'Start investigation…',
                            () => decision('in_progress'),
                          ),
                          button(
                            'Resolve report…',
                            () => decision('resolved'),
                            primary: true,
                          ),
                          button(
                            'Dismiss with reason…',
                            () => decision('dismissed'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Record revision ${current['assigned_revision']}. Stale writes are rejected. If another administrator changes this report, reload and compare before saving.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Nextrole.muted,
                      ),
                    ),
                    button('Reload saved report', () async {
                      await refresh();
                      if (ctx.mounted) update(() {});
                    }),
                    if (textOf(work['investigation_note']).isNotEmpty)
                      LabeledValue(
                        'Current saved investigation note',
                        textOf(work['investigation_note']),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget revisionControl(
    String table,
    Object? id,
    String key,
    void Function(int) onReload,
  ) {
    PlatformRow? latest;
    return StatefulBuilder(
      builder: (ctx, update) => WorkspacePanel(
        title: 'Concurrent changes',
        tinted: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If a save reports that another administrator changed this record, reload the saved version here. Your entered fields remain in place. Compare before confirming.',
            ),
            const SizedBox(height: 16),
            button('Reload latest saved record and keep my draft', () async {
              await refresh();
              if (!ctx.mounted) return;
              if (error != null) {
                notice(error!);
                return;
              }
              final current = data!.find(table, id);
              if (current == null) {
                notice('The record is no longer available.');
                return;
              }
              onReload(current[key] as int);
              update(() => latest = current);
            }),
            if (latest != null) ...[
              const SizedBox(height: 16),
              LabeledValue(
                'Saved revision / status',
                '${latest![key]} · ${label(latest!['status'])}',
              ),
              if (table == 'privacy_requests')
                LabeledValue(
                  'Latest saved response',
                  textOf(latest!['response']),
                ),
              if (table == 'reports')
                LabeledValue(
                  'Latest saved public message',
                  textOf(latest!['public_message']),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> privacyQueue() => [
    const Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Notice(
        'In-app contact is the published privacy channel. Review access, correction, export, deletion and retention requests. A response does not automatically delete data.',
      ),
    ),
    filterBar(['pending', 'in_progress', 'resolved']),
    ...listing(
      rows('privacy_requests'),
      (r) => card(
        '${label(r['kind'])} request',
        '${textOf(r['message'])}\n${label(r['status'])} · ${dateOf(r['created_at'])}\n${textOf(r['response'])}',
        [button('Write in-app response', () => respondPrivacy(r))],
      ),
    ),
  ];
  Future<void> respondPrivacy(PlatformRow request) async {
    var expected = request['revision'] as int;
    await editor(
      'Respond to privacy request',
      const [
        FormFieldSpec(
          'status',
          'Request status',
          choices: ['in_progress', 'resolved'],
        ),
        FormFieldSpec(
          'response',
          'Response visible to this account',
          min: 5,
          max: 4000,
          lines: 6,
        ),
      ],
      initial: request,
      description: 'Do not include other people’s information. Mark resolved only after the requested work or a reasoned explanation is complete.',
      extra: revisionControl(
        'privacy_requests',
        request['id'],
        'revision',
        (version) => expected = version,
      ),
      submit: 'Send in-app response',
      save: (values) => act('privacy_respond', {
        'id': request['id'],
        'expected_revision': expected,
        ...values,
      }, message: 'Privacy response saved.'),
    );
  }

  Widget retentionReview() => FutureBuilder<PlatformRow>(
    future: store.action('retention_review', {}),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (!snapshot.hasData) {
        return card('Review unavailable', 'Refresh the workspace and retry.');
      }
      final result = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Notice(
              'Monthly operator review · These are records due for review, not records deleted automatically. Storage cleanup and verified account deletion require the operator’s server workflow. No private file contents are shown.',
            ),
          ),
          WorkspacePanel(
            title: 'Records due for retention review',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in result.entries.where(
                  (e) => e.key != 'last_review',
                ))
                  LabeledValue(label(entry.key), textOf(entry.value)),
                LabeledValue(
                  'Last recorded review',
                  textOf(result['last_review']),
                ),
              ],
            ),
          ),
          WorkspacePanel(
            child: RecordEditor(
              title: 'Record the review outcome',
              fields: const [
                FormFieldSpec(
                  'reason',
                  'What was reviewed and what follow-up remains?',
                  min: 5,
                  max: 1000,
                  lines: 5,
                ),
              ],
              description: 'This records an audit event. It does not claim that any records were erased.',
              submit: 'Record review',
              onSave: (values) => act(
                'retention_record_review',
                values,
                message: 'Review outcome recorded.',
              ),
            ),
          ),
        ],
      );
    },
  );

  List<Widget> audit() => [
    const Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Notice(
        'Read-only by design. No edit, delete or clear-log controls. Passwords, tokens and private résumé contents are excluded.',
      ),
    ),
    filterBar([]),
    ...listing(
      rows('audit'),
      (r) => recordCard(
        label(r['action']),
        {
          'Actor': textOf(
            data!.find('members', r['actor_id'])?['full_name'] ?? r['actor_id'],
          ),
          'Target': textOf(r['target']),
          'Date': dateOf(r['created_at']),
          'Reason': textOf(r['reason']),
        },
        [
          button(
            'Expand read-only event',
            () => detail<void>(
              'Audit event',
              (_) => WorkspacePanel(
                title: label(r['action']),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabeledValue(
                      'Actor',
                      textOf(
                        data!.find('members', r['actor_id'])?['full_name'] ??
                            r['actor_id'],
                      ),
                    ),
                    LabeledValue('Target', textOf(r['target'])),
                    LabeledValue('Timestamp', textOf(r['created_at'])),
                    LabeledValue('Reason', textOf(r['reason'])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> accountRequests() => [
    filterBar(['pending', 'resolved']),
    ...listing(
      rows('account_requests'),
      (r) => card(
        'Account deletion request',
        '${textOf(data!.find('members', r['user_id'])?['email'] ?? r['user_id'])}\n${textOf(r['reason'])}\n${textOf(r['status'])}',
        [
          if (r['status'] == 'pending')
            button(
              'Record resolution',
              () => moderate('account_request_resolve', r['user_id'], null),
            ),
        ],
      ),
    ),
    card(
      'Owner follow-through required.',
      'Recording a resolution does not delete the account or its data. Verified deletion must be completed through server administration.',
    ),
  ];
  Widget platformSettings() {
    final setting = rows('settings').first;
    return RecordEditor(
      title: 'Platform settings',
      fields: const [
        FormFieldSpec(
          'categories',
          'Categories (one per line)',
          lines: 4,
          max: 2000,
        ),
        FormFieldSpec(
          'locations',
          'Locations (one per line)',
          lines: 4,
          max: 2000,
        ),
        FormFieldSpec(
          'maintenance_notice',
          'Workspace notice',
          lines: 3,
          max: 1000,
          required: false,
        ),
        FormFieldSpec('reason', 'Reason for this change', min: 5, max: 1000),
      ],
      initial: {
        ...setting,
        'categories': (setting['categories'] as List).join('\n'),
        'locations': (setting['locations'] as List).join('\n'),
      },
      onSave: (v) => act('settings_save', {
        ...v,
        'categories': textOf(v['categories'])
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .toList(),
        'locations': textOf(v['locations'])
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .toList(),
      }, message: 'Platform settings updated.'),
    );
  }

  List<Widget> settings() => [
    card(
      'Privacy & contact',
      'Ask about access, correction, export, deletion or retention. Replies stay in your account; no personal contact email is published.',
      [
        button(
          'Open privacy requests',
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const PrivacyRequestsScreen(),
            ),
          ),
        ),
      ],
    ),
    card('Your account', backend.email ?? '', [
      button('Account and résumé', openAccount),
      button('Change password', () async {
        if (await confirm(
          'Send password reset link?',
          'A recovery link will be sent to your account email.',
          accept: 'Send reset link',
        )) {
          await run(
            () => backend.resetPassword(backend.email!),
            message: 'If the account exists, a reset link will arrive shortly.',
          );
        }
      }),
    ]),
    card(
      'Notifications',
      'Application and moderation updates appear in your workspace. External email alerts are not connected. Analytics remains off.',
    ),
    card(
      'Account deletion request',
      'Ask the project owner to review deletion. This submits a request and does not immediately delete anything.',
      [
        button(
          'Request account deletion',
          () => editor(
            'Request account deletion',
            const [
              FormFieldSpec(
                'reason',
                'Optional details',
                required: false,
                max: 2000,
                lines: 4,
              ),
            ],
            description: 'Administrators can read this request.',
            submit: 'Send deletion request',
            save: (v) =>
                act('account_request', v, message: 'Request received.'),
          ),
        ),
      ],
    ),
  ];
  Future<void> moderate(
    String operation,
    Object? id,
    String? status, {
    PlatformRow extra = const {},
  }) async {
    await editor(
      'Record administrator decision',
      const [
        FormFieldSpec('reason', 'Decision reason', min: 5, max: 1000, lines: 4),
      ],
      description:
          '${label(status ?? operation)}. The decision is audited. Relevant users can see moderation reasons.',
      submit: 'Confirm decision',
      save: (v) => act(operation, {
        'id': id,
        'status': ?status,
        ...v,
        ...extra,
      }, message: 'Decision recorded.'),
    );
  }

  Future<void> editor(
    String title,
    Fields fields, {
    PlatformRow initial = const {},
    String description = '',
    String submit = 'Save',
    bool staged = false,
    Widget? extra,
    String? secondary,
    Future<bool> Function(PlatformRow)? onSecondary,
    required Future<bool> Function(PlatformRow) save,
  }) async {
    await detail<void>(
      title,
      (ctx) => staged
          ? StagedJobEditor(fields: fields, initial: initial, onSave: save)
          : WorkspacePanel(
              child: RecordEditor(
                title: title == 'Prepare your application'
                    ? 'Contact and introduction'
                    : title,
                fields: fields,
                initial: initial,
                description: description,
                submit: submit,
                secondary: secondary,
                onSecondary: onSecondary,
                extra: extra,
                onCancel: () => Navigator.pop(ctx),
                onSave: (v) async {
                  final ok = await save(v);
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                  return ok;
                },
              ),
            ),
    );
  }

  Future<bool> confirm(
    String title,
    String body, {
    String accept = 'Confirm',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(accept),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> openAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
    );
    if (mounted && backend.signedIn) refresh();
  }

  Future<void> openUrl(String value) async {
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Unable to open link.');
    }
  }
}

class GuidedProfileSetup extends StatefulWidget {
  const GuidedProfileSetup({
    super.key,
    required this.initial,
    required this.onSave,
    this.embedded = false,
    this.onResume,
  });
  final PlatformRow initial;
  final Future<bool> Function(PlatformRow) onSave;
  final bool embedded;
  final VoidCallback? onResume;
  @override
  State<GuidedProfileSetup> createState() => _GuidedProfileSetupState();
}

class _GuidedProfileSetupState extends State<GuidedProfileSetup> {
  int step = 0;
  late PlatformRow values = {...widget.initial};
  static const titles = [
    'Your introduction',
    'Location and work',
    'Skills and experience',
    'Preferred roles',
    'Private résumé',
  ];
  static const groups = [
    [
      FormFieldSpec('full_name', 'Full name', min: 2, max: 200),
      FormFieldSpec(
        'headline',
        'Professional headline',
        max: 200,
        required: false,
      ),
      FormFieldSpec('bio', 'About you', max: 2000, lines: 4, required: false),
    ],
    [FormFieldSpec('location', 'Location', max: 200, required: false)],
    [
      FormFieldSpec('skills', 'Skills', max: 1000, lines: 2, required: false),
      FormFieldSpec(
        'education',
        'Education',
        max: 3000,
        lines: 4,
        required: false,
      ),
      FormFieldSpec(
        'experience',
        'Experience',
        max: 4000,
        lines: 4,
        required: false,
      ),
    ],
    [
      FormFieldSpec(
        'preferences',
        'Preferred roles and work arrangements',
        max: 500,
        lines: 2,
        required: false,
      ),
      FormFieldSpec(
        'portfolio',
        'Portfolio URL',
        max: 500,
        required: false,
        url: true,
      ),
    ],
    <FormFieldSpec>[],
  ];
  @override
  Widget build(BuildContext context) {
    final child = WorkspacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepProgress(step: step, titles: titles),
          const SizedBox(height: 24),
          if (step == 4) ...[
            const Notice(
              'Your résumé stays private. Adding a PDF is optional for profile setup; it is required before submitting an application.',
            ),
            const SizedBox(height: 20),
            if (widget.onResume != null)
              OutlinedButton.icon(
                onPressed: widget.onResume,
                icon: const DesignIcon('upload'),
                label: const Text('Manage private PDF'),
              ),
            const SizedBox(height: 20),
          ],
          RecordEditor(
            key: ValueKey(step),
            title: titles[step],
            fields: groups[step],
            initial: values,
            description: 'Each completed profile step is saved privately. Optional fields can be skipped.',
            submit: step == 4 ? 'Finish profile' : 'Save and continue',
            onCancel: () => Navigator.pop(context),
            onSave: (next) async {
              final merged = {...values, ...next};
              if (!await widget.onSave(merged)) return false;
              if (!mounted || !context.mounted) return true;
              values = merged;
              if (step == 4) {
                Navigator.pop(context);
              } else {
                setState(() => step++);
              }
              return true;
            },
          ),
        ],
      ),
    );
    return widget.embedded
        ? child
        : Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          );
  }
}

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.titles});
  final int step;
  final List<String> titles;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${step + 1} of ${titles.length} · ${titles[step]}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (var i = 0; i < titles.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  color: i <= step ? Nextrole.blue : Nextrole.line,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          titles
              .asMap()
              .entries
              .map((e) => '${e.key + 1}. ${e.value}')
              .join(' / '),
          style: const TextStyle(fontSize: 12, color: Nextrole.muted),
        ),
      ],
    ),
  );
}

class StagedJobEditor extends StatefulWidget {
  const StagedJobEditor({
    super.key,
    required this.fields,
    required this.initial,
    required this.onSave,
  });
  final Fields fields;
  final PlatformRow initial;
  final Future<bool> Function(PlatformRow) onSave;
  @override
  State<StagedJobEditor> createState() => _StagedJobEditorState();
}

class _StagedJobEditorState extends State<StagedJobEditor> {
  int step = 0;
  bool changed = false;
  late PlatformRow values = {...widget.initial};
  static const titles = [
    'Role basics',
    'Location and arrangement',
    'Salary and benefits',
    'Requirements',
    'Deadline and review',
  ];
  static const keys = [
    ['title', 'category', 'description'],
    ['location', 'employment_type', 'arrangement'],
    ['salary', 'benefits'],
    ['requirements'],
    ['closes_at'],
  ];
  Future<void> cancel() async {
    if (changed) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard this job’s unsaved progress?'),
          content: const Text(
            'Your completed steps have not been saved to the company yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !changed,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) cancel();
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspacePanel(
          child: StepProgress(step: step, titles: titles),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Notice(
            'A job draft is private. Complete these steps, then save the draft. Publication requires a separate review request. Progress stays in this form until the final save.',
          ),
        ),
        if (step == 4)
          WorkspacePanel(
            title: 'Review your role',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in widget.fields.where(
                  (f) => f.key != 'closes_at',
                ))
                  LabeledValue(field.label, textOf(values[field.key])),
              ],
            ),
          ),
        WorkspacePanel(
          child: RecordEditor(
            key: ValueKey(step),
            title: titles[step],
            fields: widget.fields
                .where((f) => keys[step].contains(f.key))
                .toList(),
            initial: values,
            submit: step == 4 ? 'Save job draft' : 'Continue',
            onCancel: cancel,
            secondary: step > 0 ? 'Previous step' : null,
            validateSecondary: false,
            onSecondary: step > 0
                ? (next) async {
                    values = {...values, ...next};
                    setState(() => step--);
                    return true;
                  }
                : null,
            onSave: (next) async {
              final merged = {...values, ...next};
              if (step < 4) {
                values = merged;
                setState(() {
                  changed = true;
                  step++;
                });
                return true;
              }
              final ok = await widget.onSave(merged);
              if (ok && mounted && context.mounted) {
                setState(() => changed = false);
                Navigator.pop(context);
              }
              return ok;
            },
          ),
        ),
      ],
    ),
  );
}

class FormFieldSpec {
  const FormFieldSpec(
    this.key,
    this.label, {
    this.required = true,
    this.min = 0,
    this.max = 500,
    this.lines = 1,
    this.choices,
    this.email = false,
    this.url = false,
    this.date = false,
    this.choiceLabels,
  });
  final String key, label;
  final bool required, email, url, date;
  final int min, max, lines;
  final List<String>? choices;
  final Map<String, String>? choiceLabels;
}

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.initial = const {},
    this.description = '',
    this.submit = 'Save',
    this.secondary,
    this.onSecondary,
    this.onCancel,
    this.validateSecondary = true,
    this.extra,
  });
  final String title, description, submit;
  final Fields fields;
  final PlatformRow initial;
  final Future<bool> Function(PlatformRow) onSave;
  final String? secondary;
  final Future<bool> Function(PlatformRow)? onSecondary;
  final VoidCallback? onCancel;
  final bool validateSecondary;
  final Widget? extra;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final form = GlobalKey<FormState>();
  final controls = <String, TextEditingController>{};
  bool saving = false, dirty = false;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final initial = textOf(widget.initial[f.key] ?? f.choices?.first);
      controls[f.key] = TextEditingController(
        text: f.choices != null && !f.choices!.contains(initial)
            ? f.choices!.first
            : initial,
      );
    }
  }

  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save({bool secondary = false}) async {
    if (saving ||
        (!(secondary && !widget.validateSecondary) &&
            !form.currentState!.validate())) {
      return;
    }
    setState(() => saving = true);
    try {
      final values = {
        for (final f in widget.fields) f.key: controls[f.key]!.text.trim(),
      };
      final ok = await (secondary
          ? widget.onSecondary!(values)
          : widget.onSave(values));
      if (mounted && ok) setState(() => dirty = false);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> cancel() async {
    if (saving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text('Your changes have not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && widget.onCancel != null) cancel();
    },
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (widget.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.description,
              style: const TextStyle(color: Nextrole.muted),
            ),
          ],
          const SizedBox(height: 24),
          for (final f in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: f.choices != null
                  ? DropdownButtonFormField<String>(
                      initialValue: f.choices!.contains(controls[f.key]!.text)
                          ? controls[f.key]!.text
                          : f.choices!.first,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: f.label),
                      items: [
                        for (final v in f.choices!)
                          DropdownMenuItem(
                            value: v,
                            child: Text(f.choiceLabels?[v] ?? label(v)),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (v) {
                              controls[f.key]!.text = v!;
                              setState(() => dirty = true);
                            },
                    )
                  : TextFormField(
                      controller: controls[f.key],
                      enabled: !saving,
                      maxLines: f.lines,
                      maxLength: f.max,
                      keyboardType: f.email
                          ? TextInputType.emailAddress
                          : f.url
                          ? TextInputType.url
                          : f.date
                          ? TextInputType.datetime
                          : TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: f.label + (f.required ? '' : ' (optional)'),
                        alignLabelWithHint: true,
                        counterText: '',
                      ),
                      onChanged: (_) {
                        if (!dirty) setState(() => dirty = true);
                      },
                      validator: (raw) {
                        final value = (raw ?? '').trim();
                        if (f.required && value.isEmpty) {
                          return 'Please enter ${f.label.toLowerCase()}.';
                        }
                        if (value.isEmpty) return null;
                        if (value.length < f.min) {
                          return 'Use at least ${f.min} characters.';
                        }
                        if (f.email &&
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value)) {
                          return 'Enter a valid email address.';
                        }
                        if (f.url) {
                          final uri = Uri.tryParse(value);
                          if (uri == null ||
                              uri.scheme != 'https' ||
                              uri.host.isEmpty) {
                            return 'Use a full HTTPS address.';
                          }
                        }
                        if (f.date) {
                          final d = DateTime.tryParse(value);
                          if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
                              d == null ||
                              dateOf(d.toIso8601String()) != value ||
                              d.isBefore(DateUtils.dateOnly(DateTime.now()))) {
                            return 'Enter today or a future date as YYYY-MM-DD.';
                          }
                        }
                        return null;
                      },
                    ),
            ),
          if (widget.extra != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ExcludeFocus(
                excluding: saving,
                child: IgnorePointer(ignoring: saving, child: widget.extra!),
              ),
            ),
          if (saving)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : widget.submit),
              ),
              if (widget.secondary != null)
                OutlinedButton(
                  onPressed: saving ? null : () => save(secondary: true),
                  child: Text(widget.secondary!),
                ),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: saving ? null : cancel,
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
