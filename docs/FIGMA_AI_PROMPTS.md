# Nextrole — Figma AI prompts

Copy the complete prompt below into Figma AI. These are design directions, not a request to change the implemented UI automatically.

## Main prompt: editorial blue and warm white

Design a complete, modern job discovery product called Nextrole for an internship portfolio. Make it feel like a carefully crafted product from a small, ambitious design team: confident typography, generous whitespace, helpful microcopy, and clear interactions. Explore a visually different direction from a typical green job board.

Use an editorial visual language: warm white #FAF9F6, deep navy #17243B, electric blue #3563E9, muted lavender surfaces, and restrained apricot highlights. Use a contemporary sans serif such as Manrope or Inter for the interface and a distinctive editorial serif only for selected hero words. Avoid generic gradients, glass panels, oversized pill buttons everywhere, and decorative charts with no purpose. Use real text and consistent iconography.

Create desktop frames at 1440 px, tablet at 768 px, and mobile at 390 px. Use an 8 px spacing system, 12-column desktop grid, reusable auto-layout components, semantic color variables, typography styles, and variants for hover, focus, selected, disabled, loading, and error states. Ensure text contrast meets WCAG AA, keyboard focus is visible, touch targets are at least 44 px, long text wraps, and content works at 200% text size. Decorative art should be marked decorative; meaningful images need useful alternative descriptions.

Create these connected screens and flows:

1. Public landing: navigation, Sign in, Create account, a strong “Find work that feels like you” hero, primary Explore jobs CTA, concise three-step explanation, featured sample roles, honest portfolio-demo label, FAQ preview, and a complete footer with privacy, terms, storage preferences, FAQ, and sharing. No invented statistics, reviews, or hiring guarantees.
2. Guest exploration: prominent keyword search, location, role category, employment-type filters, result count, sorting, active-filter chips, clear reset, and useful no-results state. Job cards show company, role, location, work arrangement, salary range, sample-listing indicator, save button, and View details. Browsing and viewing details never require login.
3. Job detail: company summary, role responsibilities, requirements, salary, work arrangement, save and share actions, and a sticky Apply CTA. A guest clicking Apply sees a contextual account gate explaining why sign-in is needed, preserving the chosen job.
4. Authentication: Sign in, Create account, Google and Apple buttons, email/password inputs, password visibility, terms acknowledgement, forgot password, reset password, confirmation email sent, invalid link, incorrect credentials, loading, and successful return to the original job. Users can always return to browsing. Show a clear unavailable-service state when the portfolio backend is not configured.
5. Candidate account: identity, private résumé upload with PDF/5 MB guidance, uploading progress, upload error, replace, preview, delete confirmation, privacy controls, and sign out. Do not show employer/admin controls to a candidate.
6. Application draft: role summary, full name, email, short introduction, validation errors, saving state, success, and edit/delete flow. This portfolio version saves a draft and does not send it to an employer; label the final action Save draft rather than claiming a real submission.
7. Saved jobs: empty and populated states, remove saved job, browse recommendations.
8. Applications: saved drafts, date, role, company, edit/delete controls, loading/error/retry/empty states. Do not invent interview statuses.
9. Informational pages: readable privacy policy, terms, FAQ accordion, and storage preference panel with equally prominent Essential only and Allow optional actions. Explain that no analytics is installed in this demo.
10. A custom 404 with a helpful return-to-explore CTA, plus offline/service-unavailable states.

Use a compact bottom navigation on mobile and a clean navigation rail or sidebar for the signed-in desktop workspace. Keep the public landing navigation distinct from the application workspace. Prototype the core journey: landing → explore as guest → job details → Apply → register/sign in → return to the selected job → save draft → Applications. Also connect résumé upload, saved jobs, privacy controls, and sign-out paths. Use short 150–200 ms transitions and provide reduced-motion alternatives.

Deliver a design-system page, component variants, finished screens, and a clickable prototype. Include interaction annotations and a short explanation of major UX choices. Prioritize a buildable Flutter interface, not an unstructured presentation image.

## Alternative direction A: monochrome studio

Use the full product scope and flows above, but redesign the visual identity as a premium editorial studio: off-white #F5F3EF, charcoal #181818, thin graphite rules, a single vivid orange #F2643D accent, oversized but disciplined typography, asymmetric landing sections, and compact structured job cards. Use clean rectangular controls with subtle corner rounding. The product should feel mature, precise, and suitable for a design/engineering audience. Preserve accessibility and mobile clarity.

## Alternative direction B: approachable early-career platform

Use the full product scope and flows above, with an optimistic identity for students and early-career candidates: cream #FFF9EF, deep plum #392B48, lilac #DCD1F4, peach #FFD6BB, and small cobalt action accents. Use friendly rounded typography, warm illustrations only where they support the message, and helpful onboarding microcopy. Add clearly labeled internship and entry-level filter designs as future concepts, without implying they already work in the implementation. Keep forms focused, salary/location transparent, and guest browsing open. Avoid making the interface childish.
