import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/platform_store.dart';
import '../../core/services/backend.dart';
import '../../core/theme/app_theme.dart';
import 'workspace_design.dart';

class ResumeSelector extends StatefulWidget {
  const ResumeSelector({
    super.key,
    required this.onChanged,
    required this.onManage,
  });
  final void Function(ResumeFile?) onChanged;
  final Future<void> Function() onManage;
  @override
  State<ResumeSelector> createState() => _ResumeSelectorState();
}

class _ResumeSelectorState extends State<ResumeSelector> {
  List<ResumeFile> files = [];
  String? selected, error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    widget.onChanged(null);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await PlatformStore.instance.resumeChoices();
      if (!mounted) return;
      final chosen =
          result.where((f) => f.id == selected).firstOrNull ??
          result.where((f) => f.current).firstOrNull;
      setState(() {
        files = result;
        selected = chosen?.id;
      });
      widget.onChanged(chosen);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Your private files could not load. Retry or save your draft.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspacePanel(
    title: 'Choose a résumé version',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null) Notice(error!, error: true),
        if (!loading && files.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey(selected),
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Selected private résumé',
            ),
            items: files
                .map(
                  (f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(
                      f.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) {
              setState(() => selected = id);
              widget.onChanged(files.where((f) => f.id == id).firstOrNull);
            },
          ),
        if (!loading && files.isEmpty && error == null)
          const Text(
            'No private résumé yet. Add a PDF before review; a private draft can still be saved.',
          ),
        const SizedBox(height: 16),
        const Text(
          'Only the selected version is shared after review and deliberate submission. Other files stay private.',
          style: TextStyle(fontSize: 12, color: Nextrole.muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: () async {
                await widget.onManage();
                if (mounted) await load();
              },
              child: const Text('Manage private résumés'),
            ),
            if (error != null)
              TextButton(onPressed: load, child: const Text('Retry files')),
          ],
        ),
      ],
    ),
  );
}

class PrivateResumeManager extends StatefulWidget {
  const PrivateResumeManager({super.key});
  @override
  State<PrivateResumeManager> createState() => _PrivateResumeManagerState();
}

class _PrivateResumeManagerState extends State<PrivateResumeManager> {
  final store = PlatformStore.instance;
  bool loading = true, working = false;
  List<ResumeFile> files = [];
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await store.resumeChoices();
      if (mounted) {
        setState(() {
          files = result;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Your private files could not load. Please retry.';
        });
      }
    }
  }

  Future<void> perform(Future<void> Function() task, String message) async {
    if (working) return;
    final actor = Backend.instance.userId;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await task();
      if (!mounted || actor != Backend.instance.userId) return;
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted && actor == Backend.instance.userId) {
        setState(
          () => error = e is PostgrestException
              ? e.message
              : e is StateError
              ? e.message.toString()
              : 'Unable to complete the file action. Your existing files are kept; please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> upload([ResumeFile? replace]) async {
    if (working) return;
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return;
    final length = await file.length();
    if (length == null || length > 5 * 1024 * 1024) {
      if (mounted) setState(() => error = 'Choose a PDF up to 5 MB.');
      return;
    }
    final bytes = await file.readAsBytes();
    await perform(
      () => store.uploadLibraryResume(bytes, file.name, replace: replace),
      replace == null
          ? 'Private résumé added.'
          : 'New private résumé version saved.',
    );
  }

  Future<void> open(ResumeFile file) => perform(() async {
    final uri = Uri.parse(await store.privateResumeUrl(file));
    if (uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Unable to open file.');
    }
  }, 'Private résumé opened.');
  Future<void> remove(ResumeFile file) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${file.title}?'),
        content: const Text(
          'This removes this private résumé and all its library versions. Submitted application copies stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete private versions'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await perform(
        () => store.deleteLibraryResume(file),
        'Private résumé versions removed.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = files.where((f) => f.current).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Notice(
            'Private until you choose to submit. Keep different résumés for different roles and choose the exact version on each application. Uploading alone shares nothing.',
          ),
        ),
        if (loading || working)
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: LinearProgressIndicator(),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Notice(error!, error: true),
          ),
        for (final file in current)
          WorkspacePanel(
            title: file.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DesignIcon('file-text'),
                const SizedBox(height: 16),
                Text(file.label),
                const SizedBox(height: 8),
                Text(
                  file.bytes == 0
                      ? 'Existing private PDF · Preserved from your account'
                      : 'PDF · ${(file.bytes / 1024).ceil()} KB',
                  style: const TextStyle(color: Nextrole.muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const StatusBadge('Private'),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: working ? null : () => open(file),
                      child: const Text('Open résumé'),
                    ),
                    if (!file.legacy)
                      OutlinedButton(
                        onPressed: working ? null : () => upload(file),
                        child: const Text('Upload new version'),
                      ),
                    OutlinedButton(
                      onPressed: working ? null : () => remove(file),
                      child: const Text('Delete private résumé'),
                    ),
                  ],
                ),
                if (!file.legacy &&
                    files.any(
                      (f) => f.libraryId == file.libraryId && !f.current,
                    )) ...[
                  const SizedBox(height: 20),
                  Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Previous private versions'),
                      children: [
                        for (final version in files.where(
                          (f) => f.libraryId == file.libraryId && !f.current,
                        ))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(version.label),
                            trailing: IconButton(
                              tooltip: 'Open version ${version.version}',
                              onPressed: working ? null : () => open(version),
                              icon: const Icon(Icons.open_in_new),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        WorkspacePanel(
          title: current.isEmpty
              ? 'Add your first private résumé'
              : 'Add another private résumé',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DesignIcon('upload'),
              const SizedBox(height: 16),
              const Text(
                'PDF only · Up to 5 MB each · Up to 10 library résumés and 50 private versions in total.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                    loading ||
                        working ||
                        current.where((f) => !f.legacy).length >= 10
                    ? null
                    : () => upload(),
                icon: const Icon(Icons.add),
                label: const Text('Choose PDF'),
              ),
              if (error != null)
                TextButton(
                  onPressed: working ? null : load,
                  child: const Text('Retry files'),
                ),
            ],
          ),
        ),
        const WorkspacePanel(
          title: 'Submitted versions stay unchanged',
          child: Text(
            'Every application receives a separate, fixed PDF copy. Replacing or deleting a file from this library does not replace that submitted copy. Employers cannot browse your private library.',
          ),
        ),
      ],
    );
  }
}
