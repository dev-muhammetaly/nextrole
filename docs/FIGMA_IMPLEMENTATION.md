# Figma implementation handoff

Update 17 October 2026: functional employee/employer/admin workspaces and the submitted-application lifecycle now use the new Figma v2 visual direction. See FIGMA_V2_IMPLEMENTATION.md for the latest interface scope, screenshots and adaptations. The older “Future concepts” statement below describes the 16 October design implementation; see ROLE_WORKSPACES.md for current behavior.

Implemented 16 October 2026 from file `bvsdr9H4xqAuOREcYSqKUv`.

## Working app

The public landing page and Flutter app now use the final paper, navy, blue, lavender and apricot palette. Inter and DM Serif Display are bundled locally with their licenses; Figma search, chevron, information and upload SVGs are stored under `assets/figma`.

| Design family | App behavior |
| --- | --- |
| A / Public landing | Responsive editorial hero, three steps, sample roles, benefits, expandable FAQ, legal and sharing controls. |
| B–C / Discovery and filters | Guest browsing, keyword/category/location/type filters, sorting, clear/cancel/apply filter actions, responsive navigation. |
| D / Job details | Full page, role details, salary and work style, private-draft CTA, role-specific share links. |
| F / Session favorites | Save/Unsave and a dedicated Saved view; no claim of account persistence. |
| G–M / Authentication | Registration acknowledgement, email sign-in, confirmation/resend cooldown, email-only recovery, new-password confirmation, provider availability states. Selected job survives authentication. |
| P–Q / Account and résumé | Signed-in identity, verified empty/existing/error storage states, PDF upload/replace/open/delete. Private signed links expire after 60 seconds. |
| R–U / Application drafts | Validated create/edit, real persistence, loading/error/success feedback, Applications view, confirmed deletion, legacy sample draft compatibility. Private editors close on sign-out. |
| V / Session | Working account sign-out and removal of private workspace state. |
| W–Y / Trust and sharing | Shared policy content, expandable FAQs, storage preference controls, copy/share links, favicon/install/social assets. No analytics. |
| Z / System feedback | Recoverable 404, empty search/saved/draft views, disabled provider explanations and operation feedback. |

The additional employer, company, onboarding, dashboard and advanced-settings frames marked **Future concepts** in Figma are not presented as implemented product features. State galleries are translated into live UI feedback; they are not separate app pages.

## Figma prototype

Existing original flows are preserved. The final designs have additional editable prototype frames and named starting points on the original Desktop and Mobile pages:

| Frame | Desktop | Mobile |
| --- | --- | --- |
| Final landing | `21:2080` | `22:2191` |
| Guest exploration | `26:1496` | `26:2405` |
| Signed-in discovery | `21:2169` | `22:2281` |
| Signed-in job detail | `21:2234` | `22:2348` |

Start **Nextrole final desktop** or **Nextrole final mobile** for guest browsing; **Final signed-in workspace** starts the authenticated example. The first sample listing is the representative detail/apply journey. Guest exploration opens the existing guest detail/auth gate; the signed-in detail opens the draft directly. Auth, drafts, saved jobs, account and legal destinations connect to the existing breakpoint-specific flows. Other sample roles and detailed filter/state galleries are still visual examples in Figma; all three roles and filters work in the real app. Prototype success screens simulate states and perform no backend operations.

Read-back verified component instances, editable text/vector layers, intended Inter/DM Serif Display fonts, and same-page destinations. No flattened UI screenshots were added. Native developer annotations remain unavailable under the current Figma permissions; this document provides the implementation notes.

## Verification

- Flutter analyzer: no issues.
- All 13 automated interaction tests passed: search/empty results, saved role, draft validation/save, guest gate, pending-job resume, sign-out isolation, recovery/password matching, registration acknowledgement/confirmation, 320px at 200% text, and 404 recovery.
- Release web build succeeded; public HTML links/assets and metadata checked.
- Live public Supabase checks: email auth reachable, email confirmation required, Google/Apple disabled, anonymous draft access denied, anonymous résumé listing empty/denied.
- Browser: 390px landing; app at 320px, 390px, 768px and 1440px without horizontal document overflow. Semantic labels visible; filter Escape dismissal returned focus to All filters. Saved previews: `app-desktop-figma.png`, `app-mobile-figma.png`.
- Earlier rollback-only database tests cover two-owner and anonymous policy separation. Actual email inbox delivery and PDF transfer still need an end-to-end account test; no real résumé was replaced during verification.

## Launch inputs still needed

1. A real HTTPS hosting origin. Run `tool/release.ps1 -SiteUrl https://YOUR-ACTUAL-HOST`, deploy `build/web`, and add that exact `/app.html` callback in Supabase. Local preview SEO intentionally stays noindex.
2. Google OAuth credentials and an Apple developer/service configuration if those optional sign-in methods are wanted. Set the respective feature flag only after the provider works.
3. A public owner/contact identity for published policy pages. No fictitious business or support mailbox was invented.
4. Hosted smoke tests, confirmation/recovery email checks, real PDF upload/replace/open/delete, and a full screen-reader/Lighthouse audit. Local checks are not a claim of complete production accessibility certification.

See `LAUNCH_CHECKLIST.md` for all 20 requested launch items. No analytics is installed, as requested.
