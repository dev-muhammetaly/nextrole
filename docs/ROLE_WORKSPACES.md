# Nextrole role workspaces — 17 October 2026

## Current implementation

The functional workspaces now use the completed Figma v2 visual direction. See FIGMA_V2_IMPLEMENTATION.md for full-page role flows, responsive verification and explicit adaptations to the current data model.

- /app.html#/workspace resolves the signed-in account's server-controlled role.
- /app.html#/employee is restricted to candidates.
- /app.html#/employer is restricted to approved employers.
- /app.html#/admin is restricted to administrators.
- /app.html#/opportunities allows guest discovery of published employer listings.

The original home screen remains the sample-job demonstration. Its sample favorites remain session-only and its drafts never submit to an employer. The new employer listings have persistent saved jobs and real application submission inside this portfolio.

## Features

Employee: overview and profile completion, guided setup, editable profile, discover/search/category/arrangement/type filters, company information, saved jobs, private drafts, reviewed application submission, fixed résumé versions, application timeline, withdrawal, notifications, résumé/account links and account deletion requests.

Employer: access request and company onboarding, approval/rejection state, company editor, PNG logo upload/replace/remove, dashboard, create/edit/preview job, submit for moderation, pause/close/archive, applicant review, submitted résumé access, private hiring notes, candidate-visible status updates and notifications.

Administrator: separate gate, dashboard, employer approval/revocation, job moderation, user suspension/reinstatement, reports and resolution, read-only audit log, account deletion request tracking, category/location configuration and workspace notices.

Account deletion is a request workflow: it does not claim to delete data automatically. The owner must perform verified deletion through server administration. External email notifications, calendar invitations, chat, payments and AI ranking are not implemented.

## Role authority

public.nextrole_members is authoritative for the new workspaces. roles in editable auth metadata never authorize access. Every signup starts as employee. Only an authenticated active administrator can approve a company, which changes its owner's role to employer. There is no public administrator role assignment operation.

The project owner explicitly designated muhammetaly.77a@gmail.com. Its registration and email confirmation were verified before assigning the first admin role; the assignment is in nextrole_audit. No other account was promoted.

The legacy profiles.role column remains for the older scaffold; the new platform does not use it for authorization. No admin powers were granted over unrelated legacy application records.

## Permission boundaries

| Record | Candidate | Employer | Admin | Guest |
| --- | --- | --- | --- | --- |
| Published job / approved company | Read | Read | Read | Read |
| Private draft/current résumé | Own only | Own legacy files only | Own files only | None |
| Submitted application/résumé | Own only | Their jobs only | No default access | None |
| Application status history | Own application | Their jobs | No default access | None |
| Employer note | None | Their applications only | None | None |
| Employer/job moderation | None | Request review | Approve/reject with reason | None |
| User suspension | None | None | Non-admin users; no self-suspension | None |
| Audit | None | None | Read only | None |

All new tables use RLS and select-only grants to clients. Mutations go through nextrole_action with authentication, active-membership, ownership, role and state checks. SECURITY DEFINER is intentional for this narrowly checked operation, not a general SQL runner. Helper functions live outside the exposed public schema with explicit grants and fixed search paths.

Suspension blocks ordinary platform mutations and private reads, including drafts and résumé libraries. The authenticated privacy-request channel remains available to suspended members so they can contact the operator and read their own replies. Public information remains public. Already issued signed file links expire within 60 seconds.

## Submission and storage

The candidate explicitly reviews the recipient, fields and selected résumé version before submission. The selected private PDF is downloaded for review and those same bytes are uploaded to a unique application UUID path in nextrole-application-resumes. The database checks ownership and existence. Legacy current résumés remain selectable.

The submitted snapshot contains name, email, introduction, job title and company name. Subsequent profile/résumé changes do not alter it. Unique job/candidate constraints prevent duplicate applications. Final withdrawn/rejected/hired applications cannot be changed through the status operation.

Application résumé UPDATE is never allowed. DELETE permits only owner uploads not attached to a committed application. A failed submission attempts to clean up its unused upload; RLS prevents deletion if the server committed but its response was lost. Interrupted cleanup may leave an orphan requiring owner-managed maintenance.

Withdrawal preserves the record and résumé. There is no automatic retention scheduler. Use fictional data.

## Validation

- Flutter analyzer: no issues.
- 45 Flutter tests, including role gates, employer note privacy, moderator validation, guest gate, sign-out clearing private content, retry, unsaved input, explicit review-before-submit, selected résumé versions, privacy request/login handling, report confirmation, five-step forms and all three roles at 320px/200% text and 768px.
- supabase/verify_platform.sql: rollback-only synthetic account test of approval, job moderation, public visibility, persistent save, submission, immutable résumé metadata, cross-account denial, employer note isolation, admin least privilege, suspension, timeline and withdrawal.
- Real HTTP verification now passes 27 workflow checks, including byte-for-byte PDF/PNG transfer. An isolated real-session browser callback reaches the new-password form. All disposable accounts/files were removed. See LIVE_VERIFICATION.md and verification/*.json.
- Public static link/metadata checks: 170 local references resolve, including contact and retention pages.
- Plain flutter build web succeeds without private configuration flags.

Lists load up to the latest 500 accessible records, display the limit and paginate locally in groups of 20. Large production datasets require server-side search/pagination and aggregate dashboard queries.

## Remaining design and launch work

- Figma's four prototype starting points and ten native journey connections remain uncreated. Flutter navigation is implemented independently. Additional design proposals beyond the existing schema are documented in FIGMA_V2_IMPLEMENTATION.md.
- The owner confirmed reset-email delivery. A fresh desktop email-link replay is pending Supabase email quota; the phone cannot reach the local 127.0.0.1 callback. The callback itself is browser-verified with an isolated disposable session.
- Configure Google/Apple providers if required.
- Portfolio contact now uses private in-app requests only, as chosen by the owner. Retention periods and a manual review workflow are documented in PRIVACY_AND_LIBRARY_IMPLEMENTATION.md. An actual commercial launch still requires operator identity/jurisdiction review and ongoing retention/deletion follow-through.
- The Supabase advisor flags two intentionally authenticated definer functions and disabled leaked-password protection. Review the latter before a production launch: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- No Netlify upload or deployment was performed in this work.


Startup routing repair: direct /app.html entry is normalized before initial routes are generated; /admin deep links still enforce the role gate. Regression coverage includes both entry points and unknown paths.
