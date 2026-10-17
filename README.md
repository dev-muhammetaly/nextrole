# Nextrole

Employee, employer and administrator workspaces are implemented locally with the Figma v2 interface. Open `/app.html#/workspace` after signing in; the server-controlled role chooses the workspace. Guest employer listings are at `/app.html#/opportunities`. See [role workspace behavior and permissions](docs/ROLE_WORKSPACES.md) and [the v2 interface implementation notes](docs/FIGMA_V2_IMPLEMENTATION.md). No Netlify deployment has been performed for this update.

An internship portfolio demonstrating a responsive Flutter job discovery app, a fast public website, and configurable Supabase accounts and private storage.

The finished Figma design is implemented in the public landing page, discovery, details, account forms, private drafts and help screens. See [the implementation handoff](docs/FIGMA_IMPLEMENTATION.md) for the design mapping, prototype starting points, verification and remaining launch inputs.

## Preview

```sh
flutter pub get
node tool/build_site.mjs
flutter run -d chrome --web-port 8080
```

The public landing page opens first. Choose **Explore jobs** for the Flutter app. The app bundles `assets/client_config.json` with the public Supabase URL and publishable key. Plain IDE runs and release builds support email accounts without launch flags. Existing database and storage RLS protect private data. Never add server secrets to this asset. Optional `--dart-define-from-file=config.local.json` overrides the connection for another environment; override both URL and key together.

In VS Code, select **Nextrole web (Supabase)** from Run and Debug. This uses the bundled public settings and port 8080, matching the local authentication callbacks. Use either this debug session or `node tool/serve.mjs` for the built preview, one at a time, because both use port 8080.

Guests can browse, search, filter, view details, and keep session favorites without registering.

## Account setup

The bundled public connection is already configured. For another project, update `assets/client_config.json`, or use `config.example.json` as an optional local override. The existing project already has the private draft table and nextrole-resumes bucket configured. Follow docs/LAUNCH_CHECKLIST.md for remaining redirect, SMTP, Google, and Apple setup; do not rerun the applied setup SQL. Then run:

```sh
flutter run -d chrome --web-port 8080
```

Signed-in employees can maintain up to 10 private PDF résumés and 50 versions, up to 5 MB each. Applications explicitly review and submit a selected version as a separate fixed copy. Original sample listings remain draft-only with session favorites. Employer-listing workspaces support persistent saves, reviewed submissions and status tracking. Analytics is disabled.

## Deployment

```sh
node tool/build_site.mjs https://nextrolejob.netlify.app
flutter build web
```

Deploy build/web. A free hosting subdomain is suitable for this portfolio. The included Netlify configuration preserves real 404 responses. Other hosts need equivalent routing. Canonicals and the sitemap default to localhost with noindex until regenerated for a real origin. Do not publish localhost SEO values.

For a built local preview, run `node tool/serve.mjs` and open http://127.0.0.1:8080.

## Checks

```sh
flutter analyze
flutter test
node tool/check_site.mjs
flutter build web
```

Widget tests use a fake backend. Deployed RLS was also tested with two synthetic users in a rolled-back transaction, and public APIs were checked for anonymous denial. Provider OAuth, email delivery, actual file transfer, and device callbacks still require end-to-end verification.

## Key files

- lib/features/jobs/jobs_screen.dart — discovery, bookmarks, application gate and drafts
- lib/features/account/account_screen.dart — account flows and private résumé controls
- lib/core/services/backend.dart — Supabase integration and callback handling
- assets/site_content.json — shared privacy, terms, cookie/storage, and FAQ content
- tool/build_site.mjs — static public pages, SEO, sitemap, robots, llms.txt
- supabase/setup.sql — applied owner-only database/storage and candidate registration setup
- docs/LAUNCH_CHECKLIST.md — all 20 requested items and deployment prerequisites
- docs/FIGMA_AI_PROMPTS.md — full redesign prompt and two alternate directions

Legacy auth source remains in lib/features/auth for reference; the active account flow is under lib/features/account. The live backend migration and rolled-back policy checks are recorded under supabase/. Google provider configuration is enabled; Apple sign-in has been removed. The deployed origin is https://nextrolejob.netlify.app. Email confirmation and reset links use https://nextrolejob.netlify.app/app.html in Supabase Auth URL Configuration.


## Build a deployable release
Run "./tool/release.ps1 -SiteUrl https://YOUR-ACTUAL-HOST" after choosing your real HTTPS hosting address. This runs checks, generates matching SEO URLs, builds Flutter, and produces dist/nextrole-web.zip. Public hosting itself is not created automatically.

## Live backend verification
Run "node tool/verify_public_backend.mjs" for read-only public API checks. supabase/verify_policies.sql records the two-account, rollback-only database policy verification. It verifies database policy behavior, not email inbox delivery or actual file transfer.


## Disabled account buttons after deployment
Older builds omitted the Supabase dart-defines and entered guest mode. Bundled public client configuration fixes this. Fully stop and restart an old IDE debug session. Deploy the new `build/web` directory to the existing Netlify project (not the source `web` directory). The publish directory includes `_headers` and `_redirects`, so manual uploads revalidate JavaScript and preserve real 404s. The production release archive is `dist/nextrole-web.zip`; extract it and upload its contents on the existing project Deploys page. Google is enabled in the updated build; Apple sign-in has been removed.
# Interface update

Employee, employer and administrator workspaces now use the Figma v2 layouts. See [the implementation notes](docs/FIGMA_V2_IMPLEMENTATION.md) for screenshots, checks and supported-data adaptations. The separate `tool/design_preview.dart` target is for local visual QA only; release builds use `lib/main.dart`.

## Privacy, résumé library and advanced reports

Settings → Privacy & contact opens the authenticated in-app request channel. No personal contact email is published. Administrators have Privacy requests and Retention review sections, and report assignment, separate private/public notes, revision checks and deliberate outcome confirmation. Retention is a documented monthly operator review, not automatic erasure. See [the implementation and operator instructions](docs/PRIVACY_AND_LIBRARY_IMPLEMENTATION.md) for periods, permission boundaries, verification and deletion follow-through.

## Google sign-in update

Google is enabled in the existing Supabase project's public Auth settings and is enabled by default in normal IDE runs and release builds. An explicit `--dart-define=GOOGLE_AUTH_ENABLED=false` can disable it for another environment. Apple sign-in has been removed from the account interface and example configuration. Provider client secrets remain in Supabase. Older Netlify builds require uploading the updated release before their interface changes. Provider consent and return-to-app still need a real Google-account test by the owner.

