import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';

typedef PlatformRow = Map<String, dynamic>;

class ResumeFile {
  const ResumeFile({
    required this.id,
    required this.libraryId,
    required this.name,
    required this.title,
    required this.version,
    required this.path,
    required this.bytes,
    this.current = true,
    this.legacy = false,
  });
  factory ResumeFile.fromRow(PlatformRow row) => ResumeFile(
    id: row['id'],
    libraryId: row['library_id'],
    name: row['file_name'],
    title: row['display_name'],
    version: row['version'],
    path: row['object_path'],
    bytes: row['byte_size'],
    current: row['is_current'],
  );
  final String id, libraryId, name, title, path;
  final int version, bytes;
  final bool current, legacy;
  String get bucket => legacy ? 'nextrole-resumes' : 'nextrole-resume-library';
  String get label =>
      '$name · ${legacy ? 'previous private file' : 'v$version${current ? '' : ' · previous version'}'}';
}

class PreparedResume {
  const PreparedResume(this.file, this.bytes);
  final ResumeFile file;
  final Uint8List bytes;
}

class PlatformData {
  PlatformData({required this.member, required this.tables});
  final PlatformRow member;
  final Map<String, List<PlatformRow>> tables;
  String get role => member['role'] as String;
  bool get suspended => member['suspended'] == true;
  List<PlatformRow> rows(String table) => tables[table] ?? [];
  PlatformRow? find(String table, Object? id) {
    for (final row in rows(table)) {
      if (row['id'] == id) return row;
    }
    return null;
  }
}

/// RLS limits every query; the RPC independently checks every mutation.
class PlatformStore {
  static PlatformStore instance = PlatformStore();
  Backend get backend => Backend.instance;
  SupabaseClient get client => backend.requireClient;

  Future<PlatformData> loadPublic() async {
    final tables = <String, List<PlatformRow>>{};
    for (final name in ['companies', 'jobs', 'settings']) {
      tables[name] = await client.from('nextrole_$name').select().limit(500);
    }
    return PlatformData(
      member: {'role': 'guest', 'full_name': '', 'profile': {}},
      tables: tables,
    );
  }

  Future<void> rememberJob(String id) async {
    await (await SharedPreferences.getInstance()).setString(
      'nextrole.pendingPlatformJob',
      id,
    );
  }

  Future<String?> pendingJob() async {
    final preferences = await SharedPreferences.getInstance();
    final id = preferences.getString('nextrole.pendingPlatformJob');
    await preferences.remove('nextrole.pendingPlatformJob');
    return id;
  }

  Future<PlatformData> load() async {
    final owner = backend.userId;
    if (!backend.signedIn) throw StateError('Please sign in.');
    final member = await client
        .from('nextrole_members')
        .select()
        .eq('id', owner!)
        .single();
    if (member['suspended'] == true) {
      return PlatformData(member: member, tables: {});
    }
    final role = member['role'];
    final names = [
      'companies',
      'jobs',
      'notifications',
      'settings',
      if (role != 'admin') ...['applications', 'application_events'],
      if (role == 'employee') ...['saved', 'drafts', 'resume_files'],
      if (role == 'employer') 'application_notes',
      if (role == 'admin') ...[
        'members',
        'reports',
        'audit',
        'account_requests',
        'report_work',
        'privacy_requests',
      ],
    ];
    final results = await Future.wait(
      names.map((name) async {
        final query = client.from('nextrole_$name').select();
        // Counts on dashboards describe loaded records, not tracking analytics.
        return name == 'settings'
            ? await query.limit(1)
            : await query
                  .order(
                    ['application_notes', 'report_work'].contains(name)
                        ? 'updated_at'
                        : 'created_at',
                    ascending: false,
                  )
                  .limit(500);
      }),
    );
    if (owner != backend.userId) throw StateError('Your session changed.');
    return PlatformData(
      member: member,
      tables: {for (var i = 0; i < names.length; i++) names[i]: results[i]},
    );
  }

  Future<PlatformRow> action(String name, PlatformRow payload) async {
    final result = await client.rpc(
      'nextrole_action',
      params: {'action': name, 'payload': payload},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> submitApplication(
    PlatformRow job,
    PlatformRow fields, {
    PreparedResume? resume,
  }) async {
    final owner = backend.userId;
    if (owner == null) throw StateError('Please sign in.');
    // An immutable object name keeps later résumé replacements separate.
    final id = const Uuid().v4();
    final path = '$owner/$id.pdf';
    final bytes =
        resume?.bytes ??
        await client.storage
            .from('nextrole-resumes')
            .download('$owner/resume.pdf');
    if (owner != backend.userId) throw StateError('Your session changed.');
    await client.storage
        .from('nextrole-application-resumes')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );
    try {
      await action('application_submit', {
        ...fields,
        'id': id,
        'job_id': job['id'],
        'resume_path': path,
        if (resume != null && !resume.file.legacy)
          'resume_version_id': resume.file.id,
      });
    } catch (_) {
      // RLS refuses removal if the server committed the submission even when
      // its response was lost. Only an unsubmitted upload can be cleaned up.
      try {
        if (owner == backend.userId) {
          await client.storage.from('nextrole-application-resumes').remove([
            path,
          ]);
        }
      } catch (_) {
        /* An interrupted cleanup can be retried by server maintenance. */
      }
      rethrow;
    }
  }

  Future<List<ResumeFile>> resumeChoices() async {
    final owner = backend.userId;
    if (owner == null) return [];
    final rows = await client
        .from('nextrole_resume_files')
        .select()
        .eq('user_id', owner)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(50);
    final result = rows.map(ResumeFile.fromRow).toList();
    if (await backend.hasResume()) {
      result.add(
        ResumeFile(
          id: 'legacy',
          libraryId: 'legacy',
          name: 'resume.pdf',
          title: 'Previous private résumé',
          version: 1,
          path: '$owner/resume.pdf',
          bytes: 0,
          legacy: true,
        ),
      );
    }
    if (owner != backend.userId) throw StateError('Your session changed.');
    return result;
  }

  static void validatePdf(Uint8List bytes) {
    if (bytes.length > 5 * 1024 * 1024 ||
        bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw StateError('Choose a PDF up to 5 MB.');
    }
  }

  Future<PreparedResume> prepareResume(ResumeFile file) async {
    final owner = backend.userId;
    final bytes = await client.storage.from(file.bucket).download(file.path);
    if (owner == null || owner != backend.userId) {
      throw StateError('Your session changed.');
    }
    validatePdf(bytes);
    return PreparedResume(file, bytes);
  }

  Future<String> privateResumeUrl(ResumeFile file) =>
      client.storage.from(file.bucket).createSignedUrl(file.path, 60);

  Future<void> uploadLibraryResume(
    Uint8List bytes,
    String fileName, {
    ResumeFile? replace,
  }) async {
    validatePdf(bytes);
    final owner = backend.userId;
    if (owner == null) throw StateError('Please sign in.');
    final id = const Uuid().v4();
    final path = '$owner/$id.pdf';
    final safeName = fileName.split(RegExp(r'[/\\]')).last;
    if (safeName.isEmpty || safeName.length > 200) {
      throw StateError('Use a filename up to 200 characters.');
    }
    await client.storage
        .from('nextrole-resume-library')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );
    try {
      if (owner != backend.userId) throw StateError('Your session changed.');
      await action('resume_register', {
        'id': id,
        'file_name': safeName,
        'display_name':
            replace?.title ??
            safeName.substring(0, safeName.length.clamp(0, 120)),
        if (replace != null && !replace.legacy) 'library_id': replace.libraryId,
      });
    } catch (_) {
      // A lost response may follow a committed write. Never remove a registered file.
      if (owner == backend.userId) {
        final committed = await client
            .from('nextrole_resume_files')
            .select('id')
            .eq('id', id);
        if (committed.isNotEmpty) return;
        await client.storage.from('nextrole-resume-library').remove([path]);
      }
      rethrow;
    }
  }

  Future<void> deleteLibraryResume(ResumeFile file) async {
    if (file.legacy) {
      await backend.deleteResume();
      return;
    }
    final owner = backend.userId;
    final versions = await client
        .from('nextrole_resume_files')
        .select('object_path')
        .eq('library_id', file.libraryId)
        .eq('user_id', owner!)
        .isFilter('deleted_at', null);
    if (owner != backend.userId) throw StateError('Your session changed.');
    await client.storage
        .from('nextrole-resume-library')
        .remove(versions.map((v) => v['object_path'] as String).toList());
    await action('resume_delete', {'id': file.id});
  }

  Future<List<PlatformRow>> privacyRequests({bool admin = false}) async {
    final query = client.from('nextrole_privacy_requests').select();
    return await (admin ? query : query.eq('user_id', backend.userId!))
        .order('created_at', ascending: false)
        .limit(100);
  }

  Future<String> applicationResume(PlatformRow application) => client.storage
      .from('nextrole-application-resumes')
      .createSignedUrl(application['resume_path'] as String, 60);

  Future<String?> logoUrl(String companyId) async {
    try {
      return await client.storage
          .from('nextrole-company-logos')
          .createSignedUrl('$companyId/logo.png', 60);
    } on StorageException {
      return null;
    }
  }

  Future<void> uploadLogo(String companyId, Uint8List bytes) async {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length > 2 * 1024 * 1024 ||
        bytes.length < 8 ||
        List.generate(8, (i) => bytes[i] == signature[i]).contains(false)) {
      throw StateError('Choose a PNG image up to 2 MB.');
    }
    await client.storage
        .from('nextrole-company-logos')
        .uploadBinary(
          '$companyId/logo.png',
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
  }
}
