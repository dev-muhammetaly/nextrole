import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/services/backend.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/browser_bridge.dart';
import '../../core/router/route_observer.dart';
import '../account/account_screen.dart';
import '../info/info_screen.dart';

const ink = Nextrole.ink;
const muted = Nextrole.muted;
const lime = Nextrole.lavender;

class JobListing {
  final String company, title, location, category, type, salary, letter;
  final Color color;
  const JobListing(
    this.company,
    this.title,
    this.location,
    this.category,
    this.type,
    this.salary,
    this.letter,
    this.color,
  );
  String get id => '$company-$title';
}

const legacyListings = [
  JobListing(
    'Linear',
    'Senior Product Designer',
    'Remote',
    'Design',
    'Full-time',
    '\$110k – \$150k',
    'L',
    Color(0xFFE7E4FA),
  ),
  JobListing(
    'Notion',
    'Frontend Engineer',
    'Singapore',
    'Engineering',
    'Full-time',
    '\$95k – \$140k',
    'N',
    Color(0xFFF0EEE9),
  ),
  JobListing(
    'Figma',
    'Brand Designer',
    'Remote',
    'Design',
    'Contract',
    '\$80k – \$110k',
    'F',
    Color(0xFFFCE4DB),
  ),
  JobListing(
    'Stripe',
    'Product Marketing Manager',
    'Singapore',
    'Marketing',
    'Full-time',
    '\$100k – \$135k',
    'S',
    Color(0xFFE8E4FD),
  ),
  JobListing(
    'Spotify',
    'Mobile Engineer',
    'London',
    'Engineering',
    'Full-time',
    '\$90k – \$130k',
    'S',
    Color(0xFFDFF2DE),
  ),
  JobListing(
    'Airbnb',
    'Associate Product Manager',
    'Remote',
    'Product',
    'Full-time',
    '\$85k – \$120k',
    'A',
    Color(0xFFFCE4E6),
  ),
];

const listings = [
  JobListing(
    'Fieldwork',
    'Product Design Intern',
    'Kuala Lumpur · Hybrid',
    'Design',
    'Internship',
    'RM 1,500–2,000 / month',
    'F',
    Nextrole.lavender,
  ),
  JobListing(
    'Kin Studio',
    'Junior Flutter Developer',
    'Petaling Jaya · Remote',
    'Engineering',
    'Full-time',
    'RM 3,500–4,500 / month',
    'K',
    Nextrole.apricot,
  ),
  JobListing(
    'Common Ground',
    'Marketing Assistant',
    'Kuala Lumpur · On-site',
    'Marketing',
    'Part-time',
    'RM 18–25 / hour',
    'C',
    Nextrole.lavender,
  ),
];

String jobSummary(JobListing job) => switch (job.company) {
  'Fieldwork' => 'Thoughtful products. Room to grow.',
  'Kin Studio' => 'Build useful things with a small team.',
  'Common Ground' => 'Bring good ideas into the everyday.',
  _ => 'An earlier sample role, kept for your saved draft.',
};

class ApplicationDraft {
  final String name, email, introduction;
  const ApplicationDraft(this.name, this.email, this.introduction);
}

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> with RouteAware {
  final backend = Backend.instance;
  String? currentUser;
  bool loadingDrafts = false,
      openingAccount = false,
      resumingApplication = false;

  @override
  void initState() {
    super.initState();
    backend.addListener(accountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await accountChanged();
      if (!mounted || !kIsWeb || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final role = Uri.base.queryParameters['role'];
      final bookmark = Uri.base.queryParameters['save'];
      for (final job in listings) {
        if (job.id == bookmark) {
          setState(() {
            saved.add(job.id);
            page = 1;
          });
        }
        if (job.id == role) _details(job);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() => accountChanged();

  Future<void> accountChanged() async {
    if (!mounted) return;
    if (currentUser != backend.userId) {
      currentUser = backend.userId;
      setState(() => applications.clear());
      if (backend.signedIn) await loadDrafts();
    }
    if (!mounted) return;
    setState(() {});
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (backend.recoveringPassword && !openingAccount) openAccount();
    if (backend.signedIn && !backend.recoveringPassword && !openingAccount) {
      resumeApplication();
    }
  }

  Future<void> loadDrafts() async {
    final owner = backend.userId;
    setState(() => loadingDrafts = true);
    try {
      final rows = await backend.drafts();
      if (!mounted || owner != backend.userId) return;
      setState(() {
        applications.clear();
        for (final row in rows) {
          applications[row['job_id'] as String] = ApplicationDraft(
            row['full_name'] as String,
            row['email'] as String,
            row['introduction'] as String,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load your drafts. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loadingDrafts = false);
    }
  }

  Future<void> resumeApplication() async {
    if (resumingApplication ||
        !mounted ||
        !backend.signedIn ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    resumingApplication = true;
    try {
      final pending = await backend.takePendingJob();
      if (!mounted || !backend.signedIn || pending == null) return;
      final matches = [
        ...listings,
        ...legacyListings,
      ].where((job) => job.id == pending);
      if (matches.isNotEmpty) await _apply(matches.first);
    } finally {
      resumingApplication = false;
    }
  }

  Future<void> openAccount({bool register = false}) async {
    if (openingAccount) return;
    openingAccount = true;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AccountScreen(register: register),
      ),
    );
    openingAccount = false;
    if (!mounted) return;
    if (backend.signedIn && !backend.recoveringPassword) {
      await resumeApplication();
    }
  }

  final search = TextEditingController();
  final saved = <String>{};
  final applications = <String, ApplicationDraft>{};
  String category = 'All jobs', location = 'Anywhere', type = 'Any type';
  int page = 0;
  bool alphabetical = false;

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    backend.removeListener(accountChanged);
    search.dispose();
    super.dispose();
  }

  void toggle(JobListing job) => setState(() {
    if (!saved.add(job.id)) saved.remove(job.id);
  });

  List<JobListing> get results {
    final query = search.text.toLowerCase().trim();
    final jobs = [...listings, if (page == 2) ...legacyListings]
        .where(
          (job) =>
              (page != 1 || saved.contains(job.id)) &&
              (page != 2 || applications.containsKey(job.id)) &&
              (category == 'All jobs' || category == job.category) &&
              (location == 'Anywhere' || job.location.contains(location)) &&
              (type == 'Any type' || type == job.type) &&
              '${job.title} ${job.company} ${job.category}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    if (alphabetical) jobs.sort((a, b) => a.company.compareTo(b.company));
    return jobs;
  }

  void navigate(int index) => setState(() => page = index);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      return Scaffold(
        extendBody: !wide,
        bottomNavigationBar: wide
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Nextrole.line.withValues(alpha: .6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ink.withValues(alpha: .12),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: ink.withValues(alpha: .04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: NavigationBar(
                          height: 76,
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          animationDuration:
                              MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          selectedIndex: page,
                          onDestinationSelected: navigate,
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.search),
                              selectedIcon: Icon(
                                Icons.search,
                                color: Nextrole.blue,
                              ),
                              label: 'Discover',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.bookmark_border),
                              selectedIcon: Icon(
                                Icons.bookmark,
                                color: Nextrole.blue,
                              ),
                              label: 'Saved',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.work_outline),
                              selectedIcon: Icon(
                                Icons.work,
                                color: Nextrole.blue,
                              ),
                              label: 'Applications',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        body: SafeArea(
          bottom: wide,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 80 : 24,
              24,
              wide ? 80 : 24,
              wide ? 24 : 140,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(wide),
                    const SizedBox(height: 48),
                    Text(
                      'YOUR NEXT CHAPTER',
                      style: const TextStyle(
                        color: Nextrole.blue,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ScreenTitle(
                      page == 0
                          ? 'Find your next possibility.'
                          : page == 1
                          ? 'Keep what catches your eye.'
                          : 'Your next steps, in one place.',
                      size: wide ? 40 : 32,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      page == 0
                          ? 'Explore a few possibilities. Follow your curiosity.'
                          : page == 1
                          ? 'Saved roles stay in this session. Private drafts live in your account.'
                          : 'Your private drafts are never sent to an employer.',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (wide) ...[_sidebar(), const SizedBox(width: 32)],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _searchBar(wide),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton(
                                    onPressed: _filters,
                                    child: const Text('All filters'),
                                  ),
                                  Text(
                                    '${results.length} sample roles',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (page == 2 && backend.signedIn)
                                    TextButton(
                                      onPressed: loadingDrafts
                                          ? null
                                          : loadDrafts,
                                      child: const Text('Refresh drafts'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              if (loadingDrafts)
                                const LinearProgressIndicator(),
                              if (results.isEmpty)
                                _empty()
                              else
                                for (final job in results) ...[
                                  _jobCard(job),
                                  const SizedBox(height: 24),
                                ],
                              const Notice(
                                'Save and Unsave keep interesting roles in this browsing session. Sign in to keep private application drafts in your account.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _logo() => const Text(
    'nextrole',
    style: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: ink,
      letterSpacing: -1,
    ),
  );

  Widget _header(bool wide) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        _logo(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/opportunities'),
              child: const Text('Employer listings'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/workspace'),
              child: Text(
                backend.signedIn ? 'My workspace' : 'Hiring / workspace',
              ),
            ),
            if (!backend.signedIn)
              TextButton(
                onPressed: () => openInfo(context, 'faq'),
                child: const Text('FAQ'),
              ),
            OutlinedButton(
              onPressed: () => openAccount(),
              child: Text(backend.signedIn ? 'Account' : 'Sign in'),
            ),
            if (!backend.signedIn)
              FilledButton(
                onPressed: () => openAccount(register: true),
                child: const Text('Create account'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _sidebar() => Container(
    width: 208,
    padding: const EdgeInsets.all(16),
    color: Nextrole.lavender,
    child: Column(
      children: [
        for (final entry in [
          'Discover jobs',
          'Saved jobs',
          'Applications',
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: page == entry.$1
                      ? Nextrole.lavender
                      : Nextrole.paper,
                  foregroundColor: page == entry.$1 ? Nextrole.blue : ink,
                  minimumSize: const Size(48, 64),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => navigate(entry.$1),
                child: Text(entry.$2),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _searchBar(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: search,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Job title, company, or keyword',
          hintText: 'Search sample roles',
          prefixIcon: Padding(
            padding: EdgeInsets.all(16),
            child: DesignIcon('search'),
          ),
        ),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, box) {
          final controls = [
            _select('Category', category, [
              'All jobs',
              'Design',
              'Engineering',
              'Marketing',
              'Product',
            ], (v) => setState(() => category = v)),
            _select('Sort', alphabetical ? 'Company A–Z' : 'Recommended', [
              'Recommended',
              'Company A–Z',
            ], (v) => setState(() => alphabetical = v == 'Company A–Z')),
          ];
          if (box.maxWidth < 450 ||
              MediaQuery.textScalerOf(context).scale(16) > 24) {
            return Column(
              children: [controls[0], const SizedBox(height: 16), controls[1]],
            );
          }
          return Row(
            children: [
              Expanded(child: controls[0]),
              const SizedBox(width: 16),
              Expanded(child: controls[1]),
            ],
          );
        },
      ),
    ],
  );

  Widget _select(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    key: ValueKey('$label-$value'),
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    icon: const DesignIcon('chevron-down'),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: (v) {
      if (v != null) change(v);
    },
  );

  Future<void> _filters() async {
    var nextLocation = location;
    var nextType = type;
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('A little more specific.'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _select('Location / working style', nextLocation, [
                    'Anywhere',
                    'Kuala Lumpur',
                    'Petaling Jaya',
                    'Remote',
                    'Hybrid',
                    'On-site',
                  ], (v) => update(() => nextLocation = v)),
                  const SizedBox(height: 24),
                  _select('Employment type', nextType, [
                    'Any type',
                    'Internship',
                    'Full-time',
                    'Part-time',
                  ], (v) => update(() => nextType = v)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => update(() {
                nextLocation = 'Anywhere';
                nextType = 'Any type';
              }),
              child: const Text('Clear filters'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        location = nextLocation;
        type = nextType;
      });
    }
  }

  Widget _jobCard(JobListing job) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        job.category,
        style: const TextStyle(
          color: Nextrole.blue,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Nextrole.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${job.company.toUpperCase()} / SAMPLE LISTING',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${job.location}\n${job.type} · ${job.salary}',
              style: const TextStyle(color: muted, height: 1.5, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(jobSummary(job), style: const TextStyle(fontSize: 16)),
            if (applications.containsKey(job.id)) ...[
              const SizedBox(height: 12),
              const Text('Draft saved', style: TextStyle(color: Nextrole.blue)),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, size) {
                final view = OutlinedButton(
                  onPressed: () => _details(job),
                  child: const Text('View job ↗'),
                );
                final save = Tooltip(
                  message: saved.contains(job.id) ? 'Unsave job' : 'Save job',
                  child: OutlinedButton(
                    onPressed: () => toggle(job),
                    child: Text(saved.contains(job.id) ? 'Unsave' : 'Save'),
                  ),
                );
                if (size.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [view, const SizedBox(height: 8), save],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: view),
                    const SizedBox(width: 8),
                    save,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ],
  );

  Widget _footer() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your next chapter starts with a little curiosity.',
          style: TextStyle(
            fontFamily: 'DM Serif Display',
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Portfolio demo · Sample jobs · No applications are sent to employers.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              'privacy': 'Privacy',
              'terms': 'Terms',
              'faq': 'FAQ',
            }.entries)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => openInfo(context, entry.key),
                child: Text(entry.value),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () {
                if (kIsWeb) {
                  showPrivacySettings();
                } else {
                  openInfo(context, 'cookies');
                }
              },
              child: const Text('Storage preferences'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => _share(),
              child: const Text('Share Nextrole'),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _share([JobListing? job]) async {
    final base = kIsWeb ? Uri.base.origin : Backend.siteUrl;
    if (base.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(
        text: job == null
            ? '$base/'
            : '$base/app.html?role=${Uri.encodeComponent(job.id)}',
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied. Ready to share.')),
      );
    }
  }

  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(30),
    child: Column(
      children: [
        const Icon(Icons.travel_explore, size: 45, color: muted),
        const SizedBox(height: 16),
        Text(
          page == 1
              ? 'Your next favorites belong here'
              : page == 2
              ? 'Your applications start here'
              : 'No matching opportunities',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, color: ink),
        ),
        const SizedBox(height: 10),
        const Text(
          'Explore jobs or try a different search and filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        TextButton(
          onPressed: () => setState(() {
            page = 0;
            search.clear();
            category = 'All jobs';
            location = 'Anywhere';
            type = 'Any type';
          }),
          child: const Text('Explore all jobs'),
        ),
      ],
    ),
  );

  void _details(JobListing job) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (sheetContext) => Scaffold(
        appBar: AppBar(title: const Text('Back to opportunities')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${job.company.toUpperCase()} / SAMPLE LISTING',
                    style: const TextStyle(
                      color: Nextrole.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScreenTitle(job.title, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    '${job.location} · ${job.type}',
                    style: const TextStyle(color: muted, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  LayoutBuilder(
                    builder: (context, box) {
                      final description = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section(
                            'About ${job.company}',
                            '${jobSummary(job)} ${job.company} is a fictional team created for this portfolio. This role illustrates the kind of clear, thoughtful opportunity Nextrole is built to help you explore.',
                          ),
                          _section(
                            'What you’ll work on',
                            '• Turn ideas into practical, thoughtful work.\n• Collaborate with a small team and share your progress.\n• Ask questions, experiment, and learn from feedback.\n• Contribute to projects in ${job.category.toLowerCase()}.',
                          ),
                          _section(
                            'What you’ll bring',
                            '• Curiosity and an interest in ${job.category.toLowerCase()}.\n• A few examples of work, studies, or personal projects.\n• Clear communication and a collaborative mindset.\n• Care for details and the people using your work.',
                          ),
                          _section(
                            'Work style',
                            '${job.location}. Discuss schedules and expectations with a real employer when exploring a verified vacancy. These sample details are illustrative.',
                          ),
                        ],
                      );
                      final summary = Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Nextrole.lavender,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const ScreenTitle('Your next step', size: 32),
                            const SizedBox(height: 24),
                            Text(job.location),
                            const SizedBox(height: 12),
                            Text(job.salary),
                            const SizedBox(height: 24),
                            const Text(
                              'Prepare a private application draft. Nothing is sent to an employer.',
                              style: TextStyle(height: 1.5),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _apply(job);
                              },
                              child: Text(
                                applications.containsKey(job.id)
                                    ? 'Edit application draft'
                                    : backend.signedIn
                                    ? 'Prepare application'
                                    : 'Sign in to apply',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => _share(job),
                              child: const Text('Share role'),
                            ),
                            if (applications.containsKey(job.id))
                              TextButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: sheetContext,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Delete this draft?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  try {
                                    await backend.deleteDraft(job.id);
                                    if (!mounted) return;
                                    setState(() => applications.remove(job.id));
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Draft could not be deleted. Try again.',
                                              ),
                                            ),
                                          );
                                    }
                                  }
                                },
                                child: const Text('Delete application draft'),
                              ),
                          ],
                        ),
                      );
                      if (box.maxWidth < 800) {
                        return Column(
                          children: [
                            description,
                            const SizedBox(height: 24),
                            summary,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: description),
                          const SizedBox(width: 48),
                          SizedBox(width: 360, child: summary),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(
          body,
          style: const TextStyle(color: muted, height: 1.8, fontSize: 16),
        ),
      ],
    ),
  );

  Future<void> _apply(JobListing job) async {
    if (!backend.signedIn) {
      await backend.rememberJob(job.id);
      if (!mounted) return;
      await openAccount(register: true);
      return;
    }
    final owner = backend.userId;
    final result = await showDialog<ApplicationDraft>(
      context: context,
      builder: (_) => ApplicationDialog(job: job, draft: applications[job.id]),
    );
    if (result != null &&
        mounted &&
        backend.signedIn &&
        backend.userId == owner) {
      setState(() => applications[job.id] = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Draft saved to your account. Find it in Applications.',
          ),
        ),
      );
    }
  }
}

class ApplicationDialog extends StatefulWidget {
  final JobListing job;
  final ApplicationDraft? draft;
  const ApplicationDialog({super.key, required this.job, this.draft});
  @override
  State<ApplicationDialog> createState() => _ApplicationDialogState();
}

class _ApplicationDialogState extends State<ApplicationDialog> {
  bool saving = false;
  String? error;
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.draft?.name ?? Backend.instance.fullName,
  );
  late final email = TextEditingController(
    text: widget.draft?.email ?? Backend.instance.email,
  );
  late final note = TextEditingController(text: widget.draft?.introduction);
  late final owner = Backend.instance.userId;

  @override
  void initState() {
    super.initState();
    Backend.instance.addListener(checkOwner);
  }

  void checkOwner() {
    if (!mounted ||
        (Backend.instance.signedIn && Backend.instance.userId == owner)) {
      return;
    }
    name.clear();
    email.clear();
    note.clear();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    Backend.instance.removeListener(checkOwner);
    name.dispose();
    email.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: ScreenTitle(
      widget.draft == null ? 'Your next step' : 'Edit application draft',
      size: 28,
    ),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.job.title} at ${widget.job.company}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: name,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: email,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (v) =>
                    v == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'Enter a valid email address'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: note,
                maxLength: 5000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'A short introduction (optional)',
                ),
              ),
              const SizedBox(height: 16),
              const Notice(
                'This draft is saved privately in your account. It is not sent to an employer.',
              ),
              if (saving) const LinearProgressIndicator(),
              if (error != null)
                Semantics(liveRegion: true, child: Text(error!)),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                if (form.currentState!.validate()) {
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    await Backend.instance.saveDraft(
                      widget.job.id,
                      name.text.trim(),
                      email.text.trim(),
                      note.text.trim(),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(
                      context,
                      ApplicationDraft(
                        name.text.trim(),
                        email.text.trim(),
                        note.text.trim(),
                      ),
                    );
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => error =
                            'Could not save your draft. Please try again.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                }
              },
        child: const Text('Save draft'),
      ),
    ],
  );
}
