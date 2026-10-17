create or replace function nextrole_private.applied_to_job(job uuid) returns boolean language sql stable security definer set search_path='' as $$
 select nextrole_private.active() and (
 exists(select 1 from public.nextrole_applications a where a.job_id=job and a.candidate_id=auth.uid())
 or exists(select 1 from public.nextrole_saved s where s.job_id=job and s.user_id=auth.uid()))
$$;
