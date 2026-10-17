# Portfolio readiness: all 20 requested items

This is an internship portfolio, not a production recruitment service. Sample listings never send applications to employers. No company identity, domain ownership, or support address is invented.

The final Figma design is implemented with the current role-workspace adaptations. See `FIGMA_V2_IMPLEMENTATION.md` and `PRIVACY_AND_LIBRARY_IMPLEMENTATION.md` for current scope and evidence. All 45 Flutter tests, analysis, public-page validation and the release web build pass. Live public auth/data checks pass; Google is configured and enabled by default in the app; Apple sign-in is removed. New library/report/privacy permission checks use rolled-back fixtures; enhanced actual-byte HTTP verification was not completed.

| # | Item | Implementation / remaining deployment work |
|---|---|---|
| 1 | Privacy policy | Shared content in assets/site_content.json, Flutter info screen, privacy.html, contact.html and retention.html. Portfolio contact uses authenticated in-app requests only, as chosen by the owner. Concrete periods require monthly manual review and verified deletion follow-through. Commercial operation requires a separate identity/jurisdiction review. |
| 2 | Terms of use | Public terms.html and in-app page; registration acknowledgement and social-login notice. |
| 3 | Cookie/storage choice | Persistent Essential only / Allow optional notice with equally prominent choices and reopen controls. No optional scripts are installed. |
| 4 | Clear CTA | Explore jobs on landing; Sign in to apply for guests; Save draft for authenticated demo flow. |
| 5 | Mobile layout | Responsive HTML landing, Flutter bottom navigation, wrapping cards, scrollable forms. |
| 6 | Working forms | Validation, loading, auth errors, confirmation email, password reset, draft save errors, PDF checks. Real provider flows require configured Supabase. |
| 7 | Broken links | tool/check_site.mjs validates local HTML links/assets. Live deployment links still need a hosted smoke test. |
| 8 | Speed | Public pages are static HTML/CSS with no Flutter bundle until Explore jobs is opened; system fonts, no trackers. Flutter release build verified; no measured Lighthouse score is claimed. |
| 9 | Accessibility | HTML landmarks, skip link, keyboard focus, semantic controls, live status, Flutter tooltips, labeled forms, stronger muted-text contrast. Not a formal accessibility certification. |
| 10 | Analytics | Disabled by request. No GA, pixels, or third-party tracking scripts. |
| 11 | Meta title/description | Unique static page metadata, plus the app title. |
| 12 | sitemap.xml | Generated from public pages. Regenerate with your actual deployed origin. |
| 13 | robots.txt | Local preview blocks crawling; deployment generation permits public pages and excludes app.html. This is not an access-control mechanism. |
| 14 | Canonical URLs | Absolute per-page URLs generated from the deployment origin. localhost values are preview-only. |
| 15 | Image alt text | Social card description; decorative hero art hidden from assistive technology. Future content images must include meaningful alt text. |
| 16 | FAQ | Shared in-app and static FAQ covering guest access, auth, storage, privacy, and demo limits. |
| 17 | Custom 404 | Static 404.html plus Flutter unknown-route screen. Netlify configuration preserves an actual HTTP 404 status. Other hosts need equivalent configuration. |
| 18 | Social sharing | Native web share where supported, clipboard fallback, Flutter copy-link action, Open Graph/Twitter metadata and PNG card. |
| 19 | Favicon | Original Nextrole arrow SVG/PNG and matching install icons; no stock Flutter icon on the web. |
| 20 | llms.txt | Standard lowercase llms.txt, plus Ilms.txt alias matching the requested spelling. This is informational, not an indexing or security guarantee. |

## Account and storage setup

1. The existing Job-portal Supabase project is connected. Migration 20261016002711_nextrole_private_drafts_and_candidate_auth was applied on 16 October 2026.
2. Database setup is complete: nextrole_drafts and the private nextrole-resumes bucket are created, with PDF-only/5 MB limits and owner-only policies. Do not rerun setup.sql against this project; it is now an applied reference copy. The original resumes bucket remains separate.
3. Copy config.example.json to config.local.json. Fill SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, and SITE_URL. Only a public publishable key belongs here. Never use service_role or secret keys in Flutter. config.local.json is ignored.
4. Enable email/password sign-in and email confirmation. Configure SMTP for dependable delivery. Leave anonymous sign-ins disabled. Set Site URL to your deployed origin and allow exact redirect URLs: https://YOUR-HOST/app.html and http://localhost:8080/app.html for local testing. Avoid unrestricted wildcard redirects.
5. After enabling the provider, set GOOGLE_AUTH_ENABLED to true in config.local.json. Enable Google in Supabase Auth. Configure its client ID and secret in the provider dashboard, with the Supabase callback URL shown there as an authorized redirect URI in Google Cloud. Credentials stay in Supabase, not Flutter.
6. After enabling the provider, set APPLE_AUTH_ENABLED to true in config.local.json. Enable Apple in Supabase Auth with your Apple Developer identifiers, service ID, key, and signing configuration. Configure the domain and callback in Apple Developer. Follow Apple's/Supabase's secret renewal requirements. The implementation uses browser OAuth; native Apple ID-token integration is a separate enhancement.
7. Android and iOS callback schemes are wired to com.nextrole.app://login-callback/. Add this exact redirect in Supabase. Replace the scheme with your own unique identifier before publishing. Verify deep links on physical devices; native OAuth has not been device-tested here. Windows/macOS/Linux callback registration is not configured.
8. Run `flutter run -d chrome --web-port 8080`. The bundled public connection enables email auth with no special launch flags. Guests can still explore without an account.
9. Run `node tool/build_site.mjs https://nextrolejob.netlify.app`, then `flutter build web`, and deploy build/web to the existing nextrolejob Netlify project. The publish folder includes caching headers and a genuine 404 fallback for manual uploads. tool/release.ps1 also builds a checked release archive.

## Required live verification after configuration

- Register test accounts A and B. Confirm email, sign in/out, recover password, and check expired links and wrong credentials.
- Start Apply as a guest, complete email or OAuth login, and verify return to the chosen job. Test cancellation and reload.
- Save a draft as A; reopen the app and verify persistence. Verify B cannot read, update, delete, or reassign A's draft through the API.
- Upload a sample PDF as A; replace, view, and delete it. Verify anonymous users and B cannot list/read/update/delete A's object or mint its signed URL. Test files over 5 MB and non-PDF content. Bucket MIME restrictions are not antivirus scanning.
- Run Supabase security advisors, review all RLS policies and grants, and verify auth/data/storage logs. Widget tests use a fake backend. The deployed RLS policies were additionally exercised with two synthetic users in a rolled-back transaction; actual browser sign-in and file transfer still need end-to-end verification.
- Verify the configured domain's canonicals, sitemap, social image preview, HTTP 404 status, HTTPS, keyboard/screen-reader paths, mobile overflow, and Lighthouse performance.
- A project owner must handle account deletion/export until a verified server-side account-management endpoint is added. Deleting auth users may require removing their storage objects first. Never embed an admin API key to implement client-side deletion.

## Documentation used

- https://supabase.com/docs/reference/dart/auth-signinwithoauth
- https://supabase.com/docs/guides/auth/social-login/auth-google
- https://supabase.com/docs/guides/auth/social-login/auth-apple
- https://supabase.com/docs/reference/dart/storage-from-upload
- https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics
- https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guide-to-pecr/cookies-and-similar-technologies/

The privacy text describes the portfolio implementation; it is not a claim of compliance with every jurisdiction.

## Existing project observation
On 16 October 2026, a read-only call to the existing project's public Auth settings confirmed email sign-up and email confirmation are enabled; Google, Apple, and anonymous sign-in are disabled. Its previously supplied public configuration is saved in ignored config.local.json. Database and storage are now configured through the Supabase connector. Provider credentials remain dashboard tasks. Local web and mobile callback URLs are now configured. The database policy test created synthetic users only inside a transaction and rolled them back; no email was sent and no real user data was accessed.


## Completed backend verification
- Live migration applied and recorded under supabase/migrations.
- Registration trigger assigns employee regardless of editable role metadata; missing role no longer breaks sign-up.
- Client profile edits cannot change the role column.
- Owner draft read/write/delete and resume metadata read/update passed.
- Cross-account and anonymous access checks passed; all test rows rolled back.
- Public HTTP checks confirmed anonymous draft access is denied and resume listing is empty/denied.
- Auth callback handling now attaches listeners before consuming web recovery callbacks; named sign-in routes resume the chosen job once.
- Supabase advisors retain one documented warning for the legacy is_admin() helper, which is intentionally callable by authenticated policies and evaluates only the current user's server-controlled role. Its search_path is fixed, anonymous execution is revoked, and candidates cannot alter roles. See https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable


## Authentication URL configuration completed
On 16 October 2026, the Opera dashboard confirmed Site URL http://localhost:8080/app.html and exactly three allowed redirects: http://localhost:8080/app.html, http://127.0.0.1:8080/app.html, and com.nextrole.app://login-callback/. No wildcard redirects were added. Replace/add the actual production HTTPS origin when deploying. Confirmation-email delivery and browser account creation still require an end-to-end test with a user-controlled inbox.


## Netlify authentication repair — 17 October 2026
The deployed older build lacked Dart environment settings and disabled email account actions. The app now loads the bundled public Supabase connection from assets/client_config.json; no launch flags are required. Plain flutter build web passed, with 16 tests and a clean analyzer. Supabase Site URL is now https://nextrolejob.netlify.app/app.html; the same exact production callback was added alongside all three existing local/mobile callbacks. Public API checks confirm email enabled, confirmation required, anonymous private access denied. A replacement archive is dist/nextrole-web.zip. Netlify browser control refused attachment, so uploading this corrected release is still required. Real inbox confirmation/reset delivery and provider OAuth are not end-to-end verified.
