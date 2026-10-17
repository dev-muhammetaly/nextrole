alter policy nr_snapshot_read on storage.objects using(
 bucket_id='nextrole-application-resumes' and nextrole_private.active() and (
 (name ~ ('^'||auth.uid()::text||'/[0-9a-f-]{36}\.pdf$'))
 or exists(select 1 from public.nextrole_applications a where a.resume_path=name and nextrole_private.read_application(a.id))));
create policy nr_unsubmitted_snapshot_cleanup on storage.objects for delete to authenticated using(
 bucket_id='nextrole-application-resumes' and nextrole_private.role()='employee'
 and name ~ ('^'||auth.uid()::text||'/[0-9a-f-]{36}\.pdf$')
 and not exists(select 1 from public.nextrole_applications a where a.resume_path=name));
