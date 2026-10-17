# Nextrole: complete Figma AI screen prompt pack

Use the foundation prompt first. Then paste prompts A–Z one at a time into the same Figma file. Finish with the prototype prompt. Each letter includes a complete screen or a closely related family of states.

This pack specifies a proposed redesign. It does not imply that every designed feature already exists in the Flutter app. Keep new features on a separate page named Future concepts. In particular, company pages, editable candidate profiles, onboarding, a separate dashboard, notification preferences, persistent bookmarks, account export/deletion, and real employer submissions need additional implementation.

## 0. Foundation prompt — paste this first

```text
Design Nextrole, a modern job discovery application and public website for an internship portfolio. Establish a coherent design system before creating individual screens. The interface should feel editorial, calm, confident, and easy to use for people exploring their next role.

Visual direction:
- Warm white #FAF9F6 background, navy #17243B primary text, cobalt #3563E9 primary actions, lavender #EEEAF8 secondary surfaces, and restrained apricot #FFE2CF accents.
- Use Manrope or Inter for interface text. A restrained editorial serif may appear in selected landing-page headlines only.
- Use whitespace, typographic hierarchy, and subtle borders to create structure. Avoid excessive gradients, glass effects, generic dashboard charts, heavy shadows, and decoration competing with jobs.
- Use consistent outline icons. Company marks must have a neutral fallback. Do not imply company endorsement or fabricate trust badges, reviews, hiring statistics, or employer verification.

Design-system deliverables:
- Semantic color variables, typography styles, an 8 px spacing system, 12-column desktop and 4-column mobile grids, reusable auto-layout components, and responsive constraints.
- Button, input, search, select, filter chip, checkbox, navigation item, job card, dialog, drawer, upload, toast, alert, skeleton, empty-state, and pagination components.
- Default, hover, pressed, focus, selected, disabled, loading, error, and success variants where relevant.
- Type hierarchy approximately: desktop hero 56–64 px, mobile hero 36–40 px, page title 28–36 px, section title 20–24 px, body 16 px, supporting text 14 px. Allow wrapping and resizing instead of clipping.
- Desktop frames 1440 px, tablet 768 px, mobile 390 px. Include a 320 px stress-test variant of critical forms and navigation. Frame heights should follow content and realistic scrolling.
- WCAG AA text contrast, visible keyboard focus, labeled inputs, logical reading order, minimum 44 px touch targets, no color-only status indicators, useful image-alt annotations, and text resizing to 200%.

Product rules:
- Guests can browse all sample jobs, search/filter, read details, and save session-only favorites.
- Sign-in is required to save application drafts and manage a private résumé. Preserve the selected job through registration and authentication.
- Use email/password plus Google and Apple sign-in. Design disabled-provider and unavailable-backend states honestly.
- This portfolio uses sample vacancies. Saving an application draft does not send anything to an employer. Use Save draft as the final application action, not Submit application.
- No analytics or advertising trackers are installed. Privacy controls must not pretend otherwise.
- Never create a false successful upload, successful login, or submitted application state before the corresponding operation succeeds.
- Keep employer/admin experiences out of the candidate workspace. Label unimplemented enhancements as Future concept.

File organization:
00 Foundations; 01 Public; 02 Authentication; 03 Candidate workspace; 04 Application drafts; 05 Trust and help; 06 System states; 07 Prototype; 08 Future concepts.

Navigation:
- Public website: logo, Explore jobs, FAQ, Sign in, Create account; footer with Privacy, Terms, Storage preferences, and sharing.
- Desktop app: Discover, Saved jobs, Applications, and an Account action. Account can contain résumé management and settings.
- Mobile app: Discover, Saved, and Applications in a bottom bar; accessible Account action in the header. Do not crowd the bar with every destination.

Create the foundation page and initial reusable components now. Follow the individual screen prompts next. Preserve the same variables and components throughout the file.
```

## A. Public landing page

```text
Using the established Nextrole design system, create the complete public landing page from top to footer, in desktop, tablet, and mobile frames.

Include: navigation with logo, FAQ, Sign in, Create account; a confident hero headed “Find work that feels like you”; a concise explanation of the product; primary Explore jobs CTA; secondary Create account action; a useful editorial illustration; and the reassurance “Browse freely. Sign in when you’re ready to prepare an application.”

Below the hero, include three clear steps—Explore your options, Keep what clicks, Make your next move—followed by three sample opportunity cards, a short benefits section, FAQ preview, closing Explore jobs CTA, and complete legal/help footer. Mark company examples and jobs as sample content. Do not add fabricated user counts, testimonials, or partner logos.

On mobile, prioritize the headline and Explore jobs CTA, simplify the illustration, stack cards, and prevent navigation wrapping awkwardly. Annotate the intended document heading hierarchy, image alt text, decorative artwork, SEO title/description, and social preview. Link Explore jobs to screen B and account actions to H/I.
```

## B. Discover jobs — guest and signed-in variants

```text
Create the complete job exploration workspace using the existing Nextrole components. Design guest and signed-in variants without blocking guest access to listings.

Show a compact page heading, keyword search labeled “Job title, company, or keyword,” location and employment-type filters, category chips, active-filter summary, clear reset, result count, and sorting. Use a two- or three-column desktop card grid as space permits and one column on mobile.

Cards include company identity/fallback, role title, location, work arrangement, employment type, category, illustrative salary with currency/period, sample-listing label, bookmark control with accessible state, and View job CTA. Allow long titles and salaries to wrap. Avoid unsupported match scores and “new” labels without timestamps.

The guest header shows Sign in and Get started; the authenticated header shows Account. Include populated, loading-skeleton, fetch-failure with Retry, no-results, and all-filters-cleared variants. Keep the selected query and filters after viewing a job and returning. Use the desktop sidebar and mobile bottom navigation from the foundation.
```

## C. Search, filters, and sorting drawer

```text
Design the full filtering experience connected to Nextrole Discover. Desktop may use an anchored panel; mobile uses a full-height sheet with a clear title, Close action, scrollable options, and sticky footer.

Include keyword, location, work arrangement, category, and employment type. Present Any/All options clearly. Separate fields that are single-select from multi-select concepts. Only expose filters supported by the product; place salary, experience level, internship, and date-posted filters in a clearly marked Future concept variant.

Show selected options, counts only when backed by actual results, Reset filters, and Apply filters. For the sheet prototype, selections are provisional until Apply; closing discards provisional changes. Show applied filters as removable chips on Discover. Sorting offers Recommended and Company A–Z for the current sample dataset.

Include empty results after filtering, a disabled Apply state when nothing changes, keyboard-focus order, and long-option wrapping. Make Reset and Apply reachable above a mobile keyboard and safe-area inset. Annotate these behaviors for implementation.
```

## D. Job details

```text
Create a complete Nextrole job detail screen, plus an optional desktop detail-panel variant. Include back-to-results, company identity, role title, sample-listing badge, location/work arrangement, employment type, salary/currency/period, save and share controls, role overview, responsibilities, requirements, and company summary.

Provide one dominant application CTA. Guest variant: “Sign in to apply,” opening screen G while preserving this job. Signed-in variant: “Prepare application,” opening R. Existing-draft variant: “Edit application draft,” opening U. Include a visible note that this portfolio saves drafts and does not contact employers.

Use a desktop summary rail and a mobile sticky bottom CTA without covering content. Include a missing/unavailable-job state with Back to results. Add a share sheet and copied-link feedback; do not display job-specific public URLs as working unless routes exist. Label such deep-link behavior as an implementation annotation if proposed.

Use readable prose and real bullet lists rather than huge text blocks. Keep salary and work arrangement easy to find. Returning to results should preserve search state and scroll position.
```

## E. Company overview — future concept

```text
On the Future concepts page, design a company overview connected from a job detail. This screen is a proposed enhancement, not an existing backend feature.

Include company identity, short description, industry, location, team-size range only if supplied, official website link, an overview section, working-style information, and a list of its sample roles. Do not fabricate ratings, employee reviews, verification, funding, or headcount.

Offer View role CTAs and Back to results. A gallery is optional; use deliberately labeled placeholders with alt-text annotations rather than implying actual office photos. Show unknown/unprovided company information gracefully instead of inserting invented data.

Create desktop and mobile layouts, a company-with-no-open-roles state, loading skeleton, and unavailable-company state. Keep this screen visually consistent with Discover and Job details.
```

## F. Saved jobs

```text
Create the complete Saved jobs screen. Include the current app navigation, title, saved count, search within saved jobs, and saved cards using the same component as Discover. Each card has an active bookmark control, View job, and application-draft status only if a draft exists.

For guests, state “Favorites are saved for this session” and offer an optional account CTA without preventing access. Do not promise cross-device bookmark persistence; put an account-synced bookmarks variant on Future concepts.

Include: populated list, no saved jobs with Explore jobs CTA, no matches within saved jobs, and a sample removed/unavailable role state. Removing a favorite updates the count and offers lightweight feedback; do not use a confirmation dialog for every reversible bookmark toggle.

On mobile use a single-column list and bottom navigation. Preserve the user’s list position after visiting job details. Include accessible Save/Unsave labels rather than relying only on the icon’s fill.
```

## G. Contextual sign-in gate

```text
Design the contextual account gate shown only after a guest chooses to prepare an application. Use a centered desktop dialog and a mobile bottom sheet or focused full screen.

Title: “Keep your next step in one place.” Show the selected company and role, a concise explanation that an account is needed to save private drafts and manage a résumé, primary Create account, secondary Sign in, and Continue browsing/Close. Include Privacy and Terms links.

Preserve the selected job through email and social sign-in. Annotate the pending-job identifier and return destination; do not ask the user to search for the job again after login. Keep the job summary visible when choosing a sign-in method.

Include a backend-unavailable variant that honestly explains guest-preview mode and allows returning to the job. Avoid forced newsletter consent, countdowns, and claims that registration submits an application. Define focus entry, Escape/Close behavior, and focus return to the original Apply button.
```

## H. Sign in

```text
Create a polished Nextrole Sign in screen. Desktop can use a restrained editorial side panel and focused form; mobile shows the form first without a large decorative banner.

Include logo/back action, “Welcome back,” contextual selected-job summary if entering from Apply, Continue with Google and Continue with Apple, an email-method divider, labeled email and password fields, show/hide-password control, Forgot password, Sign in CTA, Create account link, and Back to exploring. Include concise Terms and Privacy links.

Design states for idle, keyboard focus, invalid email, missing password, incorrect credentials, unconfirmed email, request in progress, network failure, and success redirect. Keep entered email after a failure and never expose passwords in feedback. Disable duplicate submission while a request is running.

Also show disabled Google/Apple-provider states and unconfigured-backend guest mode with a plain explanation. Do not turn an unavailable provider into a working-looking CTA. Connect recovery to K, registration to I, and successful Apply sign-in to R for the preserved job.
```

## I. Create account

```text
Create the complete Nextrole registration screen using the existing authentication layout and components. Include a contextual role summary if the user came from a job.

Provide Google/Apple registration options, email-method divider, full name, email, password, password visibility, concise password guidance, a clearly labeled Terms agreement with separate readable Privacy link, Create account CTA, Already registered? Sign in, and Back to exploring. Do not preselect agreements or bundle marketing consent into account creation.

For email registration, show field-level validation, missing agreement, password requirement failure, loading, network failure, and generic account/confirmation feedback without needlessly exposing whether another person has an account. For social sign-in, show a concise terms/privacy acknowledgement before the provider action.

After success, route to J when email confirmation is required, otherwise return to the selected application draft. Include mobile keyboard-safe scrolling, autofill annotations, and a disabled-backend state. No forced onboarding or extra personal questions during registration.
```

## J. Email confirmation

```text
Create the email-confirmation family: confirmation required, awaiting confirmation, confirmation successful, and expired/invalid link.

The primary screen says “Check your inbox” and explains that the user must open the confirmation email before signing in. Show the destination email carefully, a Back to sign in action, Change email/start registration again, and return-to-browsing option. Keep the selected-job reminder if the flow began from Apply.

Design Resend email and its sending/success/error/cooldown states as a proposed enhancement with explicit implementation annotation if the backend action is not yet wired. Do not claim that an email definitely arrived or that clicking a decorative Open inbox button works everywhere.

Success returns users to their pending job. Expired-link state explains what happened and provides a safe path to request a new link or sign in. Include accessible status announcements and mobile layouts.
```

## K. Forgot password

```text
Create a focused Forgot password screen with a back link, “Let’s get you back in,” labeled email field, Send reset link CTA, and Back to sign in.

Explain that reset instructions are sent if the address belongs to an account. Design invalid-email validation, loading, network error, rate-limit feedback, and a neutral confirmation state: “If an account exists, a reset link will arrive shortly.” Avoid confirming account existence to strangers.

Preserve the email entered on the Sign in screen. Provide a return-to-browsing action and concise privacy/help links. A resend cooldown may be designed as a future interaction, clearly annotated. Keep the form small and easy to complete with autofill and the mobile email keyboard.

Connect the valid email link to L. Do not place a new-password input on this screen before a recovery session has been verified.
```

## L. Reset password

```text
Create the password-recovery screen reached from a verified reset link. Include “Choose a new password,” new password, confirm-password design, show/hide controls, useful requirement guidance, Update password CTA, and clear back/help actions.

Show password-too-short, mismatch, expired/missing recovery session, loading, connection failure, and successful update states. Confirm-password is a proposed UX refinement if the existing form only has one password field; annotate the implementation requirement rather than implying it already exists.

After a successful update, offer Continue to your job when a pending application exists, otherwise Explore jobs. Never show success until the backend confirms the update. Invalid links should route back to K to request a new link.

Include mobile keyboard-safe scrolling, autofill annotations for a new password, and a concise security note. Do not ask for the old password in a recovery-link flow.
```

## M. Google/Apple redirect and callback states

```text
Design the Nextrole-owned states around Google and Apple OAuth. Do not recreate, modify, or imitate the provider’s actual credential-entry screens.

Include: opening provider with an explanation; returning to Nextrole; verified success with return-to-job; user cancellation with Try again and Use email instead; provider disabled; popup/launch failure; invalid/expired callback; and network failure. Include a retry path that preserves the chosen job.

Keep provider branding appropriately recognizable and use official assets only when available. Do not expose tokens, callback query strings, debug errors, or secrets to users. Provider success must come from the auth state, not a timer.

Create a mobile return-to-app state and annotate the configured deep link. If callback handling fails, provide a clear Sign in again/Back to browsing action rather than leaving a permanent spinner. Mark provider-configuration requirements in developer annotations, not in the normal successful user journey.
```

## N. Optional first-run welcome — future concept

```text
On Future concepts, design a short optional welcome flow for new Nextrole candidates. It must never interrupt returning to a job the user was already applying for.

Use at most two steps: a welcome with name and a choice to Explore jobs; optional preferences for role categories, preferred location, and work arrangement. Explain how preferences would affect results. Include Skip for now on every optional step.

Do not collect date of birth, identity documents, sensitive demographic data, or a résumé before the user chooses to provide one. Do not imply personalized recommendations exist in the current implementation.

Provide progress, back navigation, save/loading/error states, and completion returning to the pending job or Discover. Make the mobile experience a simple vertical form with generous targets and no swipe-only interactions.
```

## O. Candidate home/dashboard — future concept

```text
On Future concepts, create a useful signed-in candidate home. Keep the same workspace navigation; this must not become a decorative analytics dashboard.

Include a greeting, Continue exploring CTA, resume-pending-job card if applicable, recent saved jobs, recent application drafts, and a small résumé-management summary. Derive counts from actual account data; show no invented interviews, match percentages, unread messages, or hiring outcomes.

The primary emphasis is “Your next step,” with one relevant action rather than several competing banners. Include a first-time empty state, returning-user populated state, loading, and partial-service-failure state with Retry.

Use modular cards on desktop and a clear prioritized list on mobile. Avoid mandatory profile-completion progress unless specific profile fields and their purpose are implemented. Annotate the additional data integration needed for this proposed screen.
```

## P. Account identity and profile

```text
Create the candidate Account screen around the currently supported identity and résumé controls. Show name when available, email, authentication provider if known, private résumé section, privacy/help links, and Sign out.

Separately, on Future concepts, design editable profile fields: display name, professional headline, location, portfolio URL, and short introduction. Do not expose employer/admin role selectors or let a candidate self-assign privileges. Clearly distinguish private account data from any proposed public profile.

The editable concept needs view/edit mode, Save changes, Cancel, validation, saving/error/success, and unsaved-change confirmation. Include long names and unavailable profile data. Do not add fictional experience history.

On mobile, use one column and keep the user’s identity compact. Put account deletion/export concepts under Settings, not beside the ordinary Save profile action. Annotate that profile editing needs backend implementation.
```

## Q. Private résumé management

```text
Create the complete private résumé-management experience within Account, plus a dedicated expanded screen if needed.

Empty state: explain PDF only, maximum 5 MB, private account storage, and recommend a sample résumé for this portfolio. Provide Choose PDF. Populated state: file name, file type, size/date only when known, Open résumé, Replace PDF, and Delete résumé.

Design desktop drag-and-drop as a future enhancement unless implemented; mobile uses the native file picker. Include file selected, uploading with genuine progress or indeterminate state, successful upload, file too large, invalid PDF, permission/session expired, connection error, replace success, and missing-file states.

Deletion requires a focused confirmation with Cancel and Delete. Opening a résumé uses a short-lived private link; communicate failure gracefully and never show a public-share toggle. Avoid claiming antivirus scanning or encryption features that the app does not verify. Preserve file-selection information after recoverable errors when possible.
```

## R. Prepare an application draft

```text
Create the signed-in application-draft form for a selected sample job. Show back navigation, company/role/location summary, a plain “Application draft” label, full name, email, and optional short introduction. Prefill only verified account/draft information.

Provide a concise privacy note and the explicit message “This portfolio saves a private draft. It does not send an application to an employer.” Primary action: Save draft. Secondary: Cancel/Back to job. Do not require extra fields such as phone, address, salary history, identity documents, or résumé upload to save the current draft.

Include invalid/missing field states, saving, duplicate-click prevention, session expiration with a safe reauthentication path, network failure retaining entered data, and success linking to S. On desktop use a focused form with a small role summary rail; on mobile use one column and keyboard-safe actions.

A résumé attachment selector and review/real-submission step may be shown only as separate Future concepts requiring employer-submission infrastructure.
```

## S. Draft saved confirmation

```text
Create the successful application-draft confirmation for Nextrole. Use a restrained check illustration or icon, heading “Your draft is saved,” the role and company, and a clear statement that nothing has been sent to an employer.

Offer View my drafts as primary CTA, Edit this draft as secondary, and Continue exploring as a low-emphasis action. Do not display “Application submitted,” an employer response timer, a tracking number, or a fake recruiter avatar.

Design a full-screen mobile confirmation and a compact desktop inline panel or dialog. Keep focus and status announcement behavior clear. Add a returning-user variant after updating a draft: “Changes saved.”

Only enter this state after persistence succeeds. Show a distinct save-failed state preserving the form rather than using the success design for every outcome. Connect View my drafts to T and Edit to U.
```

## T. Applications / draft library

```text
Create the Applications screen for this portfolio, with clear supporting text “Your private application drafts.” The tab may remain Applications, but all displayed records must identify themselves as drafts.

Include role, company, location, Draft status, and last-saved date only when available. Actions: View job, Edit draft, Delete draft. Provide a refresh control and meaningful counts. Use a readable desktop list/table and mobile cards; avoid horizontal scrolling for essential actions.

Include populated, first-draft empty, filtered-empty concept, loading, fetch error with Retry, session-expired, and deleted-draft feedback states. Do not invent Submitted, Under review, Interview, or Offer stages for drafts that never reach an employer.

If search/filter inside Applications is proposed, annotate it as an enhancement. A guest arriving at this tab sees an explanation and Sign in/Create account options with a route back to Discover, rather than a misleading blank private-data screen.
```

## U. Edit and delete an application draft

```text
Create the complete edit flow for an existing Nextrole application draft. Reuse screen R’s fields, populated from the stored draft, and show the selected role/company. Primary action: Save changes. Secondary: Cancel. Include the note that edits remain private and are not employer submissions.

Provide unchanged, dirty/unsaved, validation error, saving, save-failed preserving content, saved, and missing/deleted-draft variants. Design an unsaved-changes dialog with Keep editing and Discard changes as a proposed refinement if not implemented.

Create a separate deletion confirmation naming the company and role. Explain that the draft will be removed from the account. Offer Cancel and Delete draft, plus deleting/failure/success states. Do not promise Undo unless a real recovery mechanism exists.

Return to Applications after deletion and update its count. Ensure mobile actions stay reachable and destructive controls cannot be confused with Save changes.
```

## V. Settings, security, and sign-out

```text
Design Settings as a clear account-related screen. Separate currently supported Sign out and privacy/help links from future account-management features.

Current flow: identity summary, Privacy Policy, Terms, Storage preferences, FAQ, and Sign out. Signing out returns to guest browsing and removes private draft data from the visible workspace. Include sign-out loading and failure feedback; do not show signed-out success when the request fails.

On Future concepts, add change-password for password accounts, export-my-data request, and account-deletion request. For Google/Apple-only users, explain that their provider manages its password. Do not request a provider password inside Nextrole.

Account deletion must explain affected data and require deliberate confirmation. Label it as requiring a secure server-side implementation; do not design it as already operational. Never place deletion near routine navigation or imply automatic résumé cleanup without an implemented process. Keep notification/theme settings out unless their functionality is explicitly designed as future work.
```

## W. FAQ and help

```text
Create Nextrole’s public and in-app FAQ/help page. Public variant uses the website navigation/footer; app variant uses a Back action and the workspace style.

Organize questions around guest browsing, registration/confirmation, Google/Apple availability, draft saving, sample vacancies, private résumé uploads, data deletion, and privacy. State clearly that no application is delivered to an employer and no analytics is installed.

Use readable accordion components or a clear article layout. Accordions need keyboard operation, visible focus, expand/collapse semantics, and comfortable mobile targets. Do not hide essential legal disclosures only in accordions. FAQ search may be shown as a Future concept unless implemented.

Include a contextual “Still need help?” section directing users to the portfolio/repository where the demo was shared. Do not invent a support email, response-time promise, or working contact form. Link relevant questions to Account, Privacy, Terms, and Explore jobs.
```

## X. Privacy Policy and Terms of Use

```text
Create two complete, distinct legal reading screens: Privacy Policy and Terms of Use. Use public-site and in-app variants with consistent branding, readable maximum text width, page title, last-updated date, section hierarchy, and useful back/footer navigation.

Privacy covers the internship-demo identity, optional registration, account data, draft text, private résumé files, Supabase processing, essential local storage, no analytics, deletion options, and contact through the project’s actual portfolio/repository. Do not invent an operator address, jurisdiction, legal certification, or retention promise.

Terms explain sample vacancies, no affiliation/endorsement, no employer delivery, account responsibilities, acceptable uploads, demo availability, and remaining production details. Use supplied project policy content rather than pretending AI-generated text is universally legally approved.

For long desktop pages, include a modest section navigation; mobile can use a jump-to-section menu. Support text selection, zoom, screen-reader heading order, and obvious links. Annotate unique page titles, descriptions, and canonical URLs as deployment-dependent metadata.
```

## Y. Privacy/storage consent and social sharing

```text
Create two utility families consistent with Nextrole: privacy preferences and sharing.

Privacy: non-blocking initial notice with heading “Your privacy, your choice,” a concise explanation of essential account/preference storage, and an explicit statement that no analytics or advertising trackers are installed. Provide equally prominent Essential only and Allow optional actions, a Storage policy link, persisted-choice feedback, and a footer Privacy settings action to reopen it. Optional storage is currently unused; do not show fictional active tracking toggles. Include keyboard/focus annotations and small-mobile layouts without covering the entire viewport unnecessarily.

Sharing: a desktop popover/mobile sheet containing a usable public page link, Copy link, copied feedback, and native device sharing where available. Include permission/clipboard failure with manual-copy guidance. Do not expose private résumé URLs, account pages, or draft details as public share targets.

Also design a 1200×630 social preview card with Nextrole branding, a concise headline, and a portfolio-demo label, plus favicon/install-icon concepts derived from the same mark.
```

## Z. 404, offline, service unavailable, and system states

```text
Create a complete system-state page with distinct desktop and mobile frames for each situation below. Reuse typography, buttons, and illustrations consistently, but give each state an accurate explanation and useful recovery action.

1. 404: “This path took a detour,” Back to Nextrole/Explore jobs, and optional FAQ. Annotate actual HTTP 404 for unknown public URLs.
2. Offline/network loss: explain that the app cannot reach its services, provide Retry, preserve entered draft data when feasible, and do not claim offline submission or offline persistence exists.
3. Account services unavailable: browsing remains available, account actions are disabled with a reason, and users can return to jobs.
4. Expired session: sign in again while preserving the selected job and unsaved work where supported; never display another user’s cached private drafts.
5. Data-load failure: compact error inside the affected section with Retry rather than replacing the whole application.
6. No results: show active filters, Clear filters, and Explore all jobs. Keep this separate from a network error.
7. General startup failure: refresh/back-to-home/help links instead of an infinite spinner.
8. Global UI feedback: success/error toast, loading skeleton, indeterminate progress, destructive confirmation, and unavailable-action tooltip.

Avoid technical stack traces or tokens in user-facing copy. Include live-announcement and keyboard-focus annotations. Make recovery buttons functional in the prototype.
```

## Final prompt — assemble the prototype and check completeness

```text
Review the Nextrole frames created from prompts A–Z. Preserve the established design system and consolidate duplicated components. Do not silently change the visual direction between screens.

Build and connect these prototype journeys:
1. Landing → Discover as guest → filter/search → Job details → account gate → register → confirm email → sign in → return to the selected job → prepare draft → saved confirmation → Applications → edit/delete draft.
2. Landing → Sign in with email → incorrect credentials → recovery → reset password → return to exploring.
3. Job account gate → Google/Apple redirect → success/cancel/provider-unavailable variants → return to the selected job or email sign-in.
4. Discover → save job → Saved jobs → unsave → empty state → Explore jobs.
5. Signed-in Account → choose sample PDF → uploading → success → replace → open → delete confirmation → empty state.
6. Landing → Privacy preferences → Essential only → browse → reopen preferences → Storage policy.
7. FAQ → Privacy → Terms → back to app; unknown URL → 404 → home.
8. Signed-in workspace → Sign out → guest browsing, with private drafts removed from view.

Label simulated backend/provider steps in the prototype annotations; do not pretend the prototype authenticates real users. Keep Future concepts separate from implemented-scope screens.

Audit every frame for: correct CTA, reachable back/cancel path, consistent components, mobile navigation, long-text wrapping, readable contrast, keyboard focus, 44 px targets, loading/empty/error/success states, clear demo labels, and honest privacy/storage behavior. Check forms with the keyboard visible, reduced-motion alternatives, and 200% text resizing. Confirm that no essential content is hidden behind sticky bars.

Deliver: a clean foundations page, reusable component library, finished desktop/tablet/mobile screens, connected core prototype, a screen inventory, and developer annotations identifying any new routes/data/features needed for implementation. Add a short handoff note explaining major UX choices.
```

## Optional: change the visual direction once, before generating screens

Use one of these instead of the foundation's visual-direction paragraph. Keep all product rules and screen prompts unchanged.

**Monochrome studio:** Off-white #F5F3EF, charcoal #181818, thin graphite borders, and orange #F2643D for primary accents. Editorial typography, precise rectangular controls with subtle rounding, asymmetric public landing layout, and structured workspace cards.

**Approachable early career:** Cream #FFF9EF, deep plum #392B48, lavender #DCD1F4, peach #FFD6BB, and restrained cobalt actions. Friendly typography and useful illustrations, with a professional rather than childish tone. Keep touch targets, contrast, and form clarity intact.

**Existing app direction:** Preserve the implemented forest green #203B32, cream #F8F9F5, lime #D8EF96, and muted text #5F6B63. Improve hierarchy, components, and screen completeness while maintaining recognizable Nextrole branding.
