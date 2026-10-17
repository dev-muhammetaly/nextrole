# Nextrole v2 role interface — 17 October 2026

The employee, employer and administrator workspaces now use the completed Figma v2 visual direction. This is a Flutter implementation of the existing supported product, using real account data and existing authorization rules. It does not insert the fictional Figma users or counts into Supabase.

## Implemented

- Shared paper/navy/cobalt/lavender styling; Inter headings; 16 px bordered panels; 48 px form/button targets; role-specific headers and sidebars.
- Responsive employee floating capsule navigation; employer/admin drawers below 1000 px; desktop record columns become labeled cards below 640 px. Two-column detail layouts stack below 780 px of content width.
- Employee dashboard with actual saved/draft/submission counts, profile completion, application progress and notifications. Discovery has a desktop filter sidebar, job cards and persistent-save actions. Saved jobs explain their scope.
- Five-step profile setup preserves and saves completed profile steps; profile editing and private PDF management use the new panels. Company profiles have their own page.
- Full-page job details/workspace/publication review. Employer job creation uses five steps, preserves input when navigating backward and saves the final reviewed job draft. Approval remains a separate action.
- Full-page application editor, explicit review page and deliberate submission. Returning to editing retains entered details. No submission occurs merely by opening review. Submitted details show immutable contact/cover-note/file context and candidate-visible timeline. Employer-only notes remain separate.
- Employer overview, jobs, applicants, company information, notifications and settings retain working backend actions under the shared design.
- Administrator overview, employer queue/review, account list/detail, companies, job review/moderation, reports/detail, read-only audit/event detail, platform settings and deletion-request tracking. Decisions still require reasons and existing server authorization.
- Dirty-editor back navigation retains the discard confirmation. Session changes still close private detail/editor routes. Navigation highlights expose selection to assistive technology.

## Deliberate adaptations to supported data

The Figma file includes product proposals beyond the current schema. The UI does not pretend those are connected:

- Updated after the v2 handoff: multiple private résumé files and immutable version history are implemented. Applicants select an exact version during review; each submission keeps its own PDF copy. The previous single-file upload remains available without data migration or loss.
- Profile work preferences remain one existing field; job salary remains explicit text including currency and pay period. There is no numeric salary conversion/filter or extra company-size field.
- Employer form steps retain progress in the form. A draft is persisted at the final Save job draft action, because the existing server validates the complete required record. Intermediate steps do not claim persistence.
- Updated after the v2 handoff: reports support reviewer assignment, private investigation notes, private decision summaries and a separately entered public outcome. Revision checks reject stale saves, and reload controls preserve entered text for comparison.
- Platform taxonomy editing retains the current categories/locations schema. It does not invent category deactivation, separate notice draft/publish storage or an infrastructure maintenance toggle.
- Account deletion is a tracked request requiring owner follow-through. External email alerts, calendars, configured Google/Apple providers and automated deletion are not implied.
- Shared authentication retains the existing working account screens and recovery handling. This change does not configure social providers or change credentials.
- The four uncreated Figma prototype starting points and ten unconnected Figma journeys remain a design-file deliverable; actual Flutter navigation works independently.

## Validation

- Flutter analyzer: clean.
- 45 Flutter tests: existing routing/auth/role/moderation coverage, explicit review-before-submit, five-step forms, all three role layouts at 320/768 px and new library/version-selection, private-contact and report-confirmation coverage. Small-phone workspace tests use 200% text.
- Browser visual checks use the separate `tool/design_preview.dart` entry point with fictional, read-only records on isolated port 8082. It does not sign into Supabase, edit real data or become a public app route.
- Desktop employee/employer/admin, employee application detail and phone layouts were checked. Screenshots are `v2-employee-desktop.png`, `v2-employer-desktop.png`, `v2-admin-desktop.png`, `v2-application-desktop.png` and corresponding mobile captures in this directory.
- The earlier live backend lifecycle verification remains documented in LIVE_VERIFICATION.md. The visual fixture is not new live backend verification.

No Netlify deployment or build trigger was performed. The local release uses `lib/main.dart`, not the visual QA entry point.
