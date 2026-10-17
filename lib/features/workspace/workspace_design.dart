import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared responsive shell from the Nextrole v2 role designs.
class WorkspaceFrame extends StatelessWidget {
  const WorkspaceFrame({
    super.key,
    required this.role,
    required this.name,
    required this.page,
    required this.tabs,
    required this.onNavigate,
    required this.title,
    required this.subtitle,
    required this.child,
    this.company = '',
    this.onAccount,
    this.onRefresh,
    this.onSignOut,
    this.onBack,
    this.loading = false,
  });
  final String role, name, page, title, subtitle, company;
  final List<String> tabs;
  final void Function(String) onNavigate;
  final VoidCallback? onAccount, onRefresh, onSignOut, onBack;
  final bool loading;
  final Widget child;

  static String tabLabel(String tab, String role) => switch (tab) {
    'Overview' => role == 'admin' ? 'Overview' : 'Dashboard',
    'Jobs' => role == 'admin' ? 'Job moderation' : 'Manage jobs',
    'Employers' => 'Employer approvals',
    'Company' => 'Company profile',
    'Companies' => 'Companies',
    'Résumé' => 'Résumés',
    'Platform settings' => 'Settings',
    _ => tab,
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final employee = role == 'employee';
    final roleName = role == 'admin'
        ? 'Administrator'
        : role == 'guest'
        ? 'Visitor'
        : role == 'employer'
        ? 'Employer'
        : 'Candidate';
    final mainTabs = ['Discover', 'Saved', 'Applications', 'Profile'];
    final privacy = role == 'admin'
        ? 'No candidate draft or résumé browser. Consequential actions require a reason and an audit event.'
        : role == 'employer'
        ? 'Only submissions to your company’s jobs are accessible. Candidate drafts and private files stay private.'
        : 'Your drafts and files stay private until you review and submit to a specific company.';
    Widget navigation(bool drawer) => Material(
      color: Nextrole.paper,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            role == 'admin'
                ? 'ADMINISTRATOR'
                : employee
                ? 'YOUR WORKSPACE'
                : 'EMPLOYER WORKSPACE',
            style: const TextStyle(
              color: Nextrole.blue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          for (final tab in tabs) ...[
            if (tab == 'Résumé')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
            Semantics(
              selected: page == tab,
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  key: ValueKey('workspace-nav-$tab'),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    backgroundColor: page == tab
                        ? const Color(0xFFEDF1FF)
                        : null,
                    foregroundColor: page == tab ? Nextrole.blue : Nextrole.ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (drawer) Navigator.pop(context);
                    onNavigate(tab);
                  },
                  child: Text(tabLabel(tab, role)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 32),
          if (employee)
            const Align(
              alignment: Alignment.centerLeft,
              child: DesignIcon('lock-keyhole'),
            ),
          const SizedBox(height: 12),
          Text(
            privacy,
            style: const TextStyle(fontSize: 12, color: Nextrole.muted),
          ),
          const SizedBox(height: 24),
          if (onSignOut != null)
            OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
    );
    return Scaffold(
      extendBody: employee && !wide,
      appBar: AppBar(
        toolbarHeight: wide ? 80 : 64,
        automaticallyImplyLeading: false,
        shape: const Border(bottom: BorderSide(color: Nextrole.line)),
        titleSpacing: wide ? 32 : 16,
        title: Row(
          children: [
            if (!wide && role != 'guest')
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Open navigation',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            Flexible(
              child: TextButton(
                onPressed: () =>
                    onNavigate(role == 'guest' ? 'Discover' : 'Overview'),
                child: const Text(
                  'nextrole.',
                  style: TextStyle(
                    color: Nextrole.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (onRefresh != null)
            IconButton(
              tooltip: 'Refresh workspace',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: employee
                  ? OutlinedButton(
                      onPressed: onAccount,
                      child: Text('${name.isEmpty ? 'Your' : name} · Account'),
                    )
                  : SizedBox(
                      width: 240,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${name.isEmpty ? 'Your account' : name} · $roleName',
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            role == 'admin' ? 'Restricted workspace' : company,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Nextrole.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Account',
                onPressed: onAccount,
                icon: const Icon(Icons.person_outline),
              ),
            ),
        ],
      ),
      drawer: wide || role == 'guest'
          ? null
          : Drawer(child: SafeArea(child: navigation(true))),
      bottomNavigationBar: employee && !wide
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                heightFactor: 1,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Nextrole.line),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F17243B),
                        blurRadius: 28,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: NavigationBarTheme(
                      data: NavigationBarThemeData(
                        indicatorColor: const Color(0xFFEDF1FF),
                        labelTextStyle: WidgetStateProperty.resolveWith(
                          (states) => TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: states.contains(WidgetState.selected)
                                ? Nextrole.blue
                                : Nextrole.ink,
                          ),
                        ),
                      ),
                      child: NavigationBar(
                        height: 76,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        selectedIndex: page == 'Overview'
                            ? 0
                            : mainTabs.contains(page)
                            ? mainTabs.indexOf(page)
                            : 3,
                        onDestinationSelected: (i) => onNavigate(mainTabs[i]),
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.search),
                            label: 'Discover',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.bookmark_border),
                            label: 'Saved',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.assignment_outlined),
                            label: 'Applications',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.person_outline),
                            label: 'Profile',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Nextrole.lavender,
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 32 : 20,
              vertical: 10,
            ),
            child: Text(
              role == 'admin'
                  ? 'Restricted workspace · Review public content and account access with care.'
                  : 'Your next chapter · Prepare privately. Share only when you choose to submit.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide && role != 'guest')
                  Container(
                    width: 240,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Nextrole.line)),
                    ),
                    child: navigation(false),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 48 : 20,
                            32,
                            wide ? 48 : 20,
                            employee && !wide ? 140 : 48,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (onBack != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: TextButton.icon(
                                    onPressed: onBack,
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 18,
                                    ),
                                    label: const Text('Back'),
                                  ),
                                ),
                              Container(
                                width: double.infinity,
                                padding: role == 'employer'
                                    ? const EdgeInsets.all(24)
                                    : EdgeInsets.zero,
                                decoration: role == 'employer'
                                    ? BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Nextrole.line,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      )
                                    : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (role == 'employer') ...[
                                      Text(
                                        '${company.isEmpty ? 'YOUR COMPANY' : company.toUpperCase()} / EMPLOYER',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Nextrole.blue,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Text(
                                      '${role == 'admin' ? 'Administrator' : 'Home'} / ${tabLabel(page, role)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Nextrole.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ScreenTitle(title, size: wide ? 40 : 28),
                                    if (subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                          color: Nextrole.muted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              child,
                              const SizedBox(height: 40),
                              const Text(
                                'Nextrole · A thoughtful next step.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Nextrole.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    this.title,
    required this.child,
    this.tinted = false,
  });
  final String? title;
  final Widget child;
  final bool tinted;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: tinted ? Nextrole.lavender : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: tinted ? Nextrole.lavender : Nextrole.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
        ],
        child,
      ],
    ),
  );
}

class WorkspaceColumns extends StatelessWidget {
  const WorkspaceColumns({
    super.key,
    required this.main,
    required this.aside,
    this.asideFirstOnSmall = false,
  });
  final Widget main, aside;
  final bool asideFirstOnSmall;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth >= 780
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 32),
              SizedBox(width: 300, child: aside),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: asideFirstOnSmall ? [aside, main] : [main, aside],
          ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: ['rejected', 'suspended'].contains(value)
          ? const Color(0xFFFFECEE)
          : const Color(0xFFEDF1FF),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      value.isEmpty
          ? ''
          : value[0].toUpperCase() + value.substring(1).replaceAll('_', ' '),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ['rejected', 'suspended'].contains(value)
            ? Nextrole.error
            : Nextrole.blue,
      ),
    ),
  );
}

class LabeledValue extends StatelessWidget {
  const LabeledValue(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Nextrole.muted, fontSize: 12),
        ),
        const SizedBox(height: 5),
        SelectableText(value.isEmpty ? 'Not provided' : value),
      ],
    ),
  );
}
