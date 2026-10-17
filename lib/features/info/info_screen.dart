import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

void openInfo(BuildContext context, String page) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => InfoScreen(page: page)),
);

class InfoScreen extends StatelessWidget {
  final String page;
  const InfoScreen({super.key, required this.page});
  static final Future<Map<String, dynamic>> content = rootBundle
      .loadString('assets/site_content.json')
      .then((text) => jsonDecode(text) as Map<String, dynamic>);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nextrole')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: content,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final document = snapshot.data![page] as Map<String, dynamic>?;
        if (document == null) return const NotFoundScreen();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                EditorialTitle(document['title'] as String),
                const SizedBox(height: 16),
                Text(
                  document['description'] as String,
                  style: const TextStyle(color: Nextrole.muted, height: 1.6),
                ),
                const SizedBox(height: 24),
                if (['privacy', 'contact', 'retention'].contains(page)) ...[
                  FilledButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/privacy-request'),
                    child: const Text('Open private privacy requests'),
                  ),
                  const SizedBox(height: 24),
                ],
                for (final section in document['sections'] as List)
                  if (page == 'faq')
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(section[0] as String),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            section[1] as String,
                            style: const TextStyle(height: 1.7),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    Semantics(
                      header: true,
                      child: Text(
                        section[0] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      section[1] as String,
                      style: const TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 26),
                  ],
                for (final link in (document['links'] as List? ?? []))
                  TextButton(
                    onPressed: () async {
                      final target = link[1] as String;
                      if (target == '/contact.html' ||
                          target == '/retention.html') {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => InfoScreen(
                              page: target == '/contact.html'
                                  ? 'contact'
                                  : 'retention',
                            ),
                          ),
                        );
                      } else {
                        final uri = Uri.tryParse(target);
                        if (uri?.scheme == 'https') {
                          await launchUrl(
                            uri!,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    },
                    child: Text(link[0] as String),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_outlined, size: 64),
            const SizedBox(height: 20),
            Text(
              '404 — This path took a detour.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'The page may have moved. Your next opportunity is still out there.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (_) => false),
              child: const Text('Explore jobs'),
            ),
          ],
        ),
      ),
    ),
  );
}
