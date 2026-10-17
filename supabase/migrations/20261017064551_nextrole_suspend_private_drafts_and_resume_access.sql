-- Suspension also applies to the previously implemented private draft/résumé flows.
alter policy "Owners read drafts" on public.nextrole_drafts using(user_id=(select auth.uid()) and nextrole_private.active());
alter policy "Owners create drafts" on public.nextrole_drafts with check(user_id=(select auth.uid()) and nextrole_private.active());
alter policy "Owners edit drafts" on public.nextrole_drafts using(user_id=(select auth.uid()) and nextrole_private.active())
 with check(user_id=(select auth.uid()) and nextrole_private.active());
alter policy "Owners delete drafts" on public.nextrole_drafts using(user_id=(select auth.uid()) and nextrole_private.active());
alter policy "Nextrole owners read resumes" on storage.objects using(bucket_id='nextrole-resumes' and name=(select auth.uid())::text||'/resume.pdf' and nextrole_private.active());
alter policy "Nextrole owners upload resumes" on storage.objects with check(bucket_id='nextrole-resumes' and name=(select auth.uid())::text||'/resume.pdf' and nextrole_private.active());
alter policy "Nextrole owners replace resumes" on storage.objects using(bucket_id='nextrole-resumes' and name=(select auth.uid())::text||'/resume.pdf' and nextrole_private.active())
 with check(bucket_id='nextrole-resumes' and name=(select auth.uid())::text||'/resume.pdf' and nextrole_private.active());
alter policy "Nextrole owners delete resumes" on storage.objects using(bucket_id='nextrole-resumes' and name=(select auth.uid())::text||'/resume.pdf' and nextrole_private.active());
