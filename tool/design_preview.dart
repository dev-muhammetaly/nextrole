// Local visual QA only. Build this separate entry point into tmp/, never deploy it.
import 'package:flutter/material.dart';

import 'package:job_portal/core/services/backend.dart';
import 'package:job_portal/core/services/platform_store.dart';
import 'package:job_portal/core/theme/app_theme.dart';
import 'package:job_portal/features/workspace/workspace_screen.dart';

void main() {
  final requested = Uri.base.queryParameters['role'];
  final role = ['employee', 'employer', 'admin'].contains(requested)
      ? requested!
      : 'employee';
  Backend.instance = PreviewBackend();
  PlatformStore.instance = PreviewStore(role);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Nextrole.theme,
      home: const WorkspaceScreen(),
      builder: (context, child) => Column(
        children: [
          Material(
            color: Nextrole.ink,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    'LOCAL DESIGN PREVIEW · Fictional records · Read-only · ${role.toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: child!),
        ],
      ),
    ),
  );
}

class PreviewBackend extends Backend {
  @override
  bool get configured => true;
  @override
  bool get signedIn => true;
  @override
  String get userId => 'preview-owner';
  @override
  String get email => 'alex@example.invalid';
  @override
  Future<bool> hasResume() async => false;
  @override
  Future<void> signOut() async => throw StateError('Read-only preview');
}

class PreviewStore extends PlatformStore {
  PreviewStore(this.role);
  final String role;
  @override
  Future<String?> logoUrl(String id) async => null;
  @override
  Future<String?> pendingJob() async => null;
  @override
  Future<List<ResumeFile>> resumeChoices() async => const [
    ResumeFile(
      id: 'design-v2',
      libraryId: 'design-cv',
      name: 'Alex-Design-CV.pdf',
      title: 'Design résumé',
      version: 2,
      path: 'preview/design-v2.pdf',
      bytes: 122880,
    ),
    ResumeFile(
      id: 'design-v1',
      libraryId: 'design-cv',
      name: 'Alex-Design-CV-original.pdf',
      title: 'Design résumé',
      version: 1,
      path: 'preview/design-v1.pdf',
      bytes: 112640,
      current: false,
    ),
    ResumeFile(
      id: 'engineering-v1',
      libraryId: 'engineering-cv',
      name: 'Alex-Engineering-CV.pdf',
      title: 'Engineering résumé',
      version: 1,
      path: 'preview/engineering.pdf',
      bytes: 163840,
    ),
  ];
  @override
  Future<List<PlatformRow>> privacyRequests({bool admin = false}) async => [
    {
      'id': 'request',
      'kind': 'retention',
      'message': 'How long is a withdrawn application retained?',
      'status': 'resolved',
      'response': 'Terminal applications become due for operator retention review after six months.',
      'created_at': '2026-10-17',
    },
  ];
  @override
  Future<PlatformRow> action(String name, PlatformRow payload) async =>
      throw StateError('Read-only preview');
  @override
  Future<PlatformData> load() async => previewData(role);
}

PlatformData previewData(String role) {
  final member = <String, dynamic>{
    'id': 'preview-owner',
    'role': role,
    'full_name': role == 'admin'
        ? 'Samira Noor'
        : role == 'employer'
        ? 'Maya Chen'
        : 'Alex Morgan',
    'email': 'alex@example.invalid',
    'profile': {
      'headline': 'Early-career product designer',
      'location': 'Kuala Lumpur, Malaysia',
      'skills': 'Figma · User research · Responsive layout',
      'bio':
          'I enjoy turning complex problems into clear, accessible interfaces.',
      'preferences': '',
    },
  };
  final companies = <PlatformRow>[
    {
      'id': 'fieldwork',
      'owner_id': 'preview-owner',
      'name': 'Fieldwork',
      'status': 'approved',
      'location': 'Kuala Lumpur',
      'industry': 'Design and technology',
      'description': 'A fictional independent product studio creating clear, useful digital experiences.',
      'website': '',
      'created_at': '2026-10-10',
    },
    {
      'id': 'kin',
      'owner_id': 'other-owner',
      'name': 'Kin Studio',
      'status': 'approved',
      'location': 'Petaling Jaya',
      'industry': 'Technology',
      'description': 'A fictional studio building useful digital products.',
      'website': '',
      'created_at': '2026-10-12',
    },
    if (role == 'admin')
      {
        'id': 'northstar',
        'owner_id': 'requester',
        'name': 'Northstar Studio',
        'status': 'pending',
        'location': 'Kuala Lumpur',
        'industry': 'Design services',
        'description': 'We plan to hire a junior visual designer and a studio operations intern.',
        'website': '',
        'created_at': '2026-10-16',
      },
  ];
  final jobs = <PlatformRow>[
    {
      'id': 'design',
      'owner_id': 'preview-owner',
      'company_id': 'fieldwork',
      'title': 'Product Design Intern',
      'location': 'Kuala Lumpur',
      'salary': 'RM 1,500–2,000 / month',
      'employment_type': 'Internship',
      'arrangement': 'Hybrid',
      'category': 'Design',
      'status': 'published',
      'description': 'Turn research into clear user journeys. Explore accessible interfaces with a thoughtful product team.',
      'requirements':
          'Curiosity, a small portfolio and familiarity with Figma.',
      'benefits': 'Weekly mentoring and supported learning time.',
      'created_at': '2026-10-12',
      'closes_at': '2026-10-31',
    },
    {
      'id': 'research',
      'owner_id': 'preview-owner',
      'company_id': 'fieldwork',
      'title': 'UX Research Intern',
      'location': 'Kuala Lumpur',
      'salary': 'RM 1,500–2,000 / month',
      'employment_type': 'Internship',
      'arrangement': 'Hybrid',
      'category': 'Design',
      'status': 'pending',
      'description': 'Support thoughtful research and help turn observations into useful recommendations.',
      'requirements': 'Clear communication and careful note-taking.',
      'benefits': 'Research mentoring.',
      'created_at': '2026-10-17',
      'closes_at': '2026-11-14',
    },
    {
      'id': 'flutter',
      'owner_id': 'other-owner',
      'company_id': 'kin',
      'title': 'Junior Flutter Developer',
      'location': 'Petaling Jaya',
      'salary': 'RM 3,500–4,500 / month',
      'employment_type': 'Full-time',
      'arrangement': 'Remote',
      'category': 'Engineering',
      'status': 'published',
      'description': 'Build useful things with a small team, using Flutter and thoughtful engineering.',
      'created_at': '2026-10-10',
      'closes_at': '2026-11-15',
    },
  ];
  PlatformRow application(String id, String name, String status) => {
    'id': id,
    'job_id': role == 'employer' ? 'design' : 'flutter',
    'candidate_id': 'candidate',
    'status': status,
    'created_at': '2026-10-15',
    'updated_at': '2026-10-16',
    'resume_path': 'preview/fictional.pdf',
    'snapshot': {
      'full_name': name,
      'email': 'candidate@example.invalid',
      'job_title': role == 'employer'
          ? 'Product Design Intern'
          : 'Junior Flutter Developer',
      'company_name': role == 'employer' ? 'Fieldwork' : 'Kin Studio',
      'introduction': 'I enjoy building useful, accessible digital experiences and learning through thoughtful feedback.',
    },
  };
  return PlatformData(
    member: member,
    tables: {
      'settings': [
        {
          'categories': ['Design', 'Engineering', 'Marketing'],
          'locations': ['Kuala Lumpur', 'Penang'],
          'maintenance_notice': '',
        },
      ],
      'companies': companies,
      'jobs': role == 'employer'
          ? jobs.where((j) => j['owner_id'] == 'preview-owner').toList()
          : jobs,
      'applications': role == 'admin'
          ? []
          : role == 'employer'
          ? [
              application('casey', 'Casey Tan', 'submitted'),
              application('jamie', 'Jamie Lee', 'under_review'),
            ]
          : [application('alex', 'Alex Morgan', 'under_review')],
      'application_events': [
        {
          'application_id': role == 'employer' ? 'casey' : 'alex',
          'status': 'submitted',
          'message': 'The selected application snapshot was received.',
          'created_at': '2026-10-15',
        },
        {
          'application_id': 'alex',
          'status': 'under_review',
          'message': 'Kin Studio is reviewing your application.',
          'created_at': '2026-10-16',
        },
      ],
      'application_notes': role == 'employer'
          ? [
              {
                'application_id': 'casey',
                'note':
                    'Review portfolio examples for accessibility decisions.',
              },
            ]
          : [],
      'saved': role == 'employee'
          ? [
              {'job_id': 'design'},
              {'job_id': 'flutter'},
            ]
          : [],
      'drafts': role == 'employee'
          ? [
              {
                'job_id': 'design',
                'full_name': 'Alex Morgan',
                'email': 'alex@example.invalid',
                'introduction': 'I would love to contribute my research and prototyping skills.',
              },
            ]
          : [],
      'notifications': role == 'admin'
          ? []
          : [
              {
                'id': 'notice',
                'title': role == 'employer'
                    ? 'A new application is ready to review'
                    : 'Kin Studio is reviewing your application',
                'body': role == 'employer'
                    ? 'Casey Tan applied to Product Design Intern.'
                    : 'Junior Flutter Developer · Your application is now under review.',
                'read': false,
                'created_at': '2026-10-16',
              },
            ],
      'members': role == 'admin'
          ? [
              member,
              {
                'id': 'requester',
                'full_name': 'Avery Lim',
                'email': 'avery@example.invalid',
                'role': 'employee',
                'created_at': '2026-10-16',
                'suspended': false,
              },
            ]
          : [],
      'audit': role == 'admin'
          ? [
              {
                'id': 'audit',
                'actor_id': 'preview-owner',
                'action': 'company_review',
                'target': 'Kin Studio',
                'reason': 'Supplied work contact and hiring purpose reviewed.',
                'created_at': '2026-10-16',
              },
            ]
          : [],
      'reports': role == 'admin'
          ? [
              {
                'id': 'report',
                'job_id': 'design',
                'reason': 'Please clarify the working pattern in the role description.',
                'status': 'open',
                'assigned_revision': 1,
                'created_at': '2026-10-17',
              },
            ]
          : [],
      'account_requests': [],
      'report_work': role == 'admin'
          ? [
              {
                'report_id': 'report',
                'reviewer_id': 'preview-owner',
                'investigation_note': 'Compare the supplied work pattern with the public description. Keep internal investigation details private.',
                'resolution_summary': '',
              },
            ]
          : [],
      'privacy_requests': role == 'admin'
          ? [
              {
                'id': 'privacy',
                'user_id': 'requester',
                'kind': 'retention',
                'message':
                    'How long does a withdrawn application stay available?',
                'status': 'pending',
                'response': '',
                'revision': 1,
                'created_at': '2026-10-17',
              },
            ]
          : [],
    },
  );
}
