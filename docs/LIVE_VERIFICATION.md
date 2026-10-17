# Live workflow verification — 17 October 2026

## Verified against the configured Supabase project

The real HTTP workflow passed all 27 checks recorded in verification/platform-http-2026-10-17.json. It used disposable fictional candidate, employer, unrelated-user and administrator accounts. No real user's résumé, application, password or role was changed.

The test exercised employer requests and approval, job draft and moderation, guest discovery, saved jobs, private drafts, actual PDF upload/download, submission, employer review, company-logo PNG transfer, status timeline and notification, duplicate rejection, withdrawal and job closing. PDF/PNG bytes matched after download. Replacing the current résumé did not change the submitted PDF. Unrelated users and administrators could not access candidate application content or submitted résumés. Candidate access to private employer notes was denied.

Test application records were detached before storage cleanup. All test file bytes were removed through the Storage API. Test auth users were then deleted, and their credentials were checked to confirm they no longer authenticate. No test passwords, access tokens, refresh tokens or callback URLs remain in the workspace test manifest.

## Recovery callback

The owner confirmed receipt of the admin account's reset email. Opening the local callback on a phone failed because 127.0.0.1 refers to that device, not the Windows development computer.

A second request was rejected by Supabase with HTTP 429 / over_email_send_rate_limit. Requests were not repeatedly retried. A fresh complete email-link replay on the same Windows computer remains pending the email quota or custom SMTP configuration.

A separate disposable candidate session tested the callback itself in the browser on isolated port 8081. It used a valid Supabase session with a synthetic recovery callback, not a newly delivered recovery email. This verified callback parsing, session acceptance and the real new-password/confirmation form without touching the user's normal session or changing any password.

The browser test found a startup route issue and delayed auth-event dependency. The app now uses the resolved callback destination and the callback result's recovery type, covering both implicit recovery and PKCE passwordRecovery values. Callback tokens are removed from the address bar. Leaving recovery clears its UI state without a password update.

Proof: recovery-callback-verified.png and verification/recovery-callback-2026-10-17.json.

## Automated and build checks

31 Flutter tests pass, including direct static-document/admin entry, role gates, private-note visibility, moderation validation, post-sign-in role routing, recovery startup, recovery cancellation, selected-job return, retry, unsaved-input protection and small-screen/enlarged-text cases.

Flutter analyzer passes. The production web build is generated locally; no Netlify build/deployment is triggered.

## Repeating the disposable HTTP test

Use tool/verify_platform_http.mjs only against this portfolio's configured test backend. It requires privileged connector SQL for fixture creation and cleanup; it never embeds a service key in the app.

1. prepare writes an ignored manifest with random test credentials and emits scoped seed SQL.
2. Execute that SQL through the Supabase connector.
3. verify signs in temporary users and runs real HTTP requests.
4. detach-sql emits SQL to remove only disposable application records.
5. Execute detach SQL successfully before proceeding.
6. cleanup-files removes uploaded test bytes through their owners' Storage API access.
7. cleanup-users-sql emits scoped cleanup SQL for temporary records/auth users.
8. Execute cleanup SQL successfully.
9. finalize checks that test accounts no longer authenticate, removes the ignored credential manifest and saves a sanitized report.

Stop on failures and complete cleanup before preparing another fixture. Cleanup errors are recorded separately and do not overwrite successful verification results.

For the isolated recovery UI fixture, prepare-recovery creates one disposable candidate. recovery-session writes its temporary callback to ignored tmp/, for browser navigation on port 8081 only. recovery-ui-passed records the observed result; then cleanup-files, cleanup-users-sql, connector SQL and finalize remove the fixture. Never mark the browser phase passed without observing the actual recovery form.

The isolated preview accepts NEXTROLE_PORT=8081; ordinary preview remains on port 8080.

