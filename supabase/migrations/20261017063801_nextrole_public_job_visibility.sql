create function nextrole_private.applied_to_job(job uuid) returns boolean language sql stable security definer set search_path='' as $$
 select nextrole_private.active() and exists(select 1 from public.nextrole_applications a where a.job_id=job and a.candidate_id=auth.uid())
$$;
revoke all on function nextrole_private.applied_to_job(uuid) from public;
grant execute on function nextrole_private.applied_to_job(uuid) to anon,authenticated;
alter policy nr_job_read on public.nextrole_jobs using(
 (status='published' and nextrole_private.company_visible(company_id))
 or(nextrole_private.active() and(owner_id=auth.uid() or nextrole_private.role()='admin'))
 or nextrole_private.applied_to_job(id));
