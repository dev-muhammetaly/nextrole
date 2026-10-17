# Privacy, résumé library and report management

Implemented 17 October 2026 for the Nextrole internship portfolio. The owner chose **in-app privacy requests only**. No personal email, invented legal entity or jurisdiction has been published. These are portfolio policies and operational targets, not a representation of commercial legal compliance.

## Where to use the features

- Employee workspace → Résumés: upload separate PDFs, open files, add new versions, view previous versions and delete a private résumé family. Limits: 10 active families, 50 retained private versions, 5 MB per PDF.
- Application editor → résumé selector → review: choose the exact file/version; review prepares its bytes before deliberate submission. A submitted PDF is an independent immutable copy. Library replacement/deletion does not change existing submissions. Employers cannot browse the private library; administrators have no general candidate-file browser.
- Settings → Privacy & contact, or `/app.html#/privacy-request`: signed-in members submit access, correction, export, deletion, retention or other privacy questions and read operator replies. Suspended members retain this channel. Guests are asked to sign in. There is no anonymous support inbox or external email delivery.
- Admin → Reports: assign an active admin, save private investigation notes, start investigation, resolve or dismiss with a private decision summary. Only the separately entered public message is shared with the reporter and listing owner. Outcome confirmation is required. This does not remove a job; job moderation is a separate action.
- Admin → Privacy requests: review and respond, marking requests in progress or resolved. Marking resolved does not erase data. Response target: 30 days, manually handled.
- Admin → Retention review: inspect aggregate due-for-review counts and record a completed review with a reason. The action does not delete data or reveal candidate documents.

Report and privacy responses require the revision originally reviewed. A stale write is rejected. Reload controls keep entered text while loading the saved version so an operator can compare before resubmitting.

## Published retention targets

Review monthly; the screens count records reaching these ages. Age makes a record due for a decision, not automatically erased.

| Data | Review target |
| --- | --- |
| Private drafts | 12 months after last edit |
| Withdrawn, rejected or hired applications | 6 months after the final status update; review snapshot PDF, contact/cover note, timeline and employer notes together |
| Resolved/dismissed reports and investigation work | 12 months after closure |
| Resolved privacy requests and replies | 12 months after closure |
| Read notifications | 90 days |
| Moderation audit | 12 months |
| Accounts, profiles, companies and private library files | While needed/in use; annual necessity review and verified deletion requests |

Record a specific reason for continued retention. Do not treat an audit entry saying a review occurred as evidence of byte erasure. Open applications/investigations need an individual necessity review. Provider logs, backups and operator exports have separate controls; the policy does not invent a fixed provider-wide erasure period.

## Operator procedure

1. Open Retention review monthly and check Privacy requests. Confirm that the request belongs to the signed-in member; do not ask for passwords, emailed tokens or identity-document uploads through this form. If clarification is needed, reply in the same request history.
2. For access/export/correction, inspect only the necessary account records through trusted server administration. Separate employer-only notes, admin investigation records and other people's information from any response. The application does not currently generate downloadable data exports automatically.
3. For deletion, identify the complete dependency set: private drafts/library files and legacy résumé, submitted snapshots and application events/employer notes, reports/investigation work, notifications, account/privacy requests, relevant audit records and any owned company/job/logo records. Decide and record any justified continued retention, considering other people's records. A withdrawal is not deletion.
4. Execute approved erasure through trusted server administration, not browser credentials or a client-side service key. Delete actual file objects through the Supabase Storage API, including separate submitted copies when approved. Never delete only `storage.objects` rows: that does not remove the underlying bytes. Delete dependent application records in a controlled transaction using their foreign keys. Revoke affected sessions and complete Auth-account removal only after the necessary data/file work. Check any separately retained operator exports and provider backup controls.
5. Verify the objects cannot be opened and the intended database records are gone, or record the reason/period for retained records. Existing signed URLs have a short 60-second lifetime. Reply accurately to the member; do not mark a request resolved merely because it was received. Complete the response before removing access to its in-app history, or otherwise agree an available channel with the member.
6. Record the review/result using minimal operational detail. Avoid copying private request text or investigation content into general audit reasons. The current app provides tracking and replies; these operator steps are not an automated deletion job or one-click administrator erasure tool.

The main database region was verified as Tokyo (`ap-northeast-1`). This does not imply all provider processing remains in that region. References: [Supabase privacy](https://supabase.com/privacy), [Netlify privacy](https://www.netlify.com/privacy/), [Supabase backup limitations](https://supabase.com/docs/guides/platform/backups).

## Implementation

- Shared policy source: `assets/site_content.json`; generator: `tool/update_privacy_content.mjs`; public contact/retention/privacy pages are generated by `tool/build_site.mjs` and also available in the Flutter information screens.
- Applied migrations: `20261017143718_nextrole_resume_library_reports_and_privacy.sql` and `20261017151829_nextrole_serialize_resume_library_deletion.sql`. Both canonical files are under `supabase/migrations/`. Library registration and deletion use the same member lock to serialize family changes.
- `nextrole_resume_files` tracks immutable private object versions. `nextrole_report_work` has administrator-only read access. `nextrole_privacy_requests` has owner/admin reads, including the suspended-owner exception. Narrow checked RPC actions perform writes; clients have no direct write grants.
- Legacy résumé files remain selectable. No existing member, application or résumé was migrated or deleted to introduce the library. New storage has no object UPDATE policy; replacements use new paths.
- Retention is manual. Analytics remains disabled. No Netlify deployment or build trigger was made.

## Verification and limits

- Flutter analyzer clean; 45 tests passed, including specific version selection, private contact failure/retry/session clearing, login return and private/public report confirmation.
- Five focused database scripts passed with all fixtures rolled back: `verify_library_rollback.sql`, `verify_reports_rollback.sql`, `verify_privacy_rollback.sql`, `verify_selected_resume_rollback.sql`, and `verify_resume_delete_rollback.sql`. These scripts use synthetic Storage metadata, not uploaded file bytes; each covers several assertions.
- Cross-account reads/writes, admin-only actions, suspended privacy contact, stale revision rejection, selected-version snapshot metadata and whole-family deletion metadata were checked. Zero rollback fixture users remained.
- Local browser checks cover desktop/phone résumé layouts, version history, privacy form/history and admin report decision fields. Screenshots use fictional, read-only data in the separate preview target.
- The earlier real HTTP lifecycle report with 27 successful checks remains historical evidence. The enhanced HTTP harness was not completed: automatic approval review rejected creation of persistent test accounts with an administrator role. No privileged fixture accounts were created. The safe rollback tests above were used instead. New actual-byte upload/download/delete behavior has not been separately verified over HTTP in this update.
- Existing advisor notices remain: intentional authenticated SECURITY DEFINER entry points, and disabled leaked-password protection. [Definer notice](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable); [password-protection settings](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

New evidence: `docs/verification/library-reports-privacy-2026-10-17.json`. Release builds use `lib/main.dart`; `tool/design_preview.dart` is local visual QA only.
