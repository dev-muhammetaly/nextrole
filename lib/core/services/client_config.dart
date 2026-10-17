import 'dart:convert';

import 'package:flutter/services.dart';

/// Public browser/mobile settings. Never put server keys in this asset.
class ClientConfig {
  const ClientConfig(this.url, this.key, this.siteUrl);

  final String url;
  final String key;
  final String siteUrl;

  static Future<ClientConfig> load({
    AssetBundle? bundle,
    String urlOverride = const String.fromEnvironment('SUPABASE_URL'),
    String keyOverride = const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    String siteOverride = const String.fromEnvironment('SITE_URL'),
  }) async {
    final values = jsonDecode(
      await (bundle ?? rootBundle).loadString('assets/client_config.json'),
    ) as Map<String, dynamic>;
    // Override the connection as a pair to avoid mixing two projects' settings.
    final overrideConnection = urlOverride.isNotEmpty || keyOverride.isNotEmpty;
    final url = overrideConnection
        ? urlOverride
        : values['SUPABASE_URL'] as String;
    final key = overrideConnection
        ? keyOverride
        : values['SUPABASE_PUBLISHABLE_KEY'] as String;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !key.startsWith('sb_publishable_')) {
      throw const FormatException(
        'A valid public Supabase connection is required.',
      );
    }
    return ClientConfig(
      url,
      key,
      siteOverride.isNotEmpty ? siteOverride : values['SITE_URL'] as String,
    );
  }
}
