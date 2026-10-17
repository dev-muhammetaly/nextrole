import 'package:flutter_test/flutter_test.dart';
import 'package:job_portal/core/services/client_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('plain builds load the bundled production public connection', () async {
    final config = await ClientConfig.load();
    expect(config.url, 'https://lybcnctwqgaykfyncqor.supabase.co');
    expect(config.key.startsWith('sb_publishable_'), isTrue);
    expect(config.siteUrl, 'https://nextrolejob.netlify.app');
  });

  test('explicit connection and site overrides take precedence', () async {
    final config = await ClientConfig.load(
      urlOverride: 'https://other.supabase.co',
      keyOverride: 'sb_publishable_test',
      siteOverride: 'https://example.com',
    );
    expect(config.url, 'https://other.supabase.co');
    expect(config.key, 'sb_publishable_test');
    expect(config.siteUrl, 'https://example.com');
  });

  test(
    'incomplete overrides cannot mix projects or expose server keys',
    () async {
      await expectLater(
        ClientConfig.load(urlOverride: 'https://other.supabase.co'),
        throwsFormatException,
      );
      await expectLater(
        ClientConfig.load(
          urlOverride: 'https://other.supabase.co',
          keyOverride: 'sb_secret_test',
        ),
        throwsFormatException,
      );
    },
  );
}
