-- Nextrole platform: additive tables; legacy samples and private drafts are retained.
create schema if not exists nextrole_private;
revoke all on schema nextrole_private from public;
grant usage on schema nextrole_private to anon, authenticated;

create table public.nextrole_members (
 id uuid primary key references auth.users(id) on delete cascade,
 role text not null default 'employee' check(role in ('employee','employer','admin')),
 suspended boolean not null default false,
 full_name text not null default '' check(length(full_name)<=200),
 email text not null default '',
 profile jsonb not null default '{}' check(octet_length(profile::text)<=20000),
 created_at timestamptz not null default now()
);
insert into public.nextrole_members(id,role,full_name,email)
 select p.id,p.role::text,coalesce(p.full_name,''),coalesce(u.email,'')
 from public.profiles p join auth.users u on u.id=p.id;
create function nextrole_private.new_member() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.nextrole_members(id,full_name,email)
 values(new.id,left(coalesce(new.raw_user_meta_data->>'full_name',''),200),coalesce(new.email,''));
 return new;
end $$;
create trigger nextrole_member_created after insert on auth.users for each row execute function nextrole_private.new_member();
revoke all on function nextrole_private.new_member() from public,anon,authenticated;

create function nextrole_private.role() returns text language sql stable security definer set search_path='' as $$
 select role from public.nextrole_members where id=auth.uid() and not suspended
 and coalesce(auth.jwt()->>'is_anonymous','false')<>'true'
$$;
create function nextrole_private.active() returns boolean language sql stable security definer set search_path='' as $$
 select nextrole_private.role() is not null
$$;
revoke all on function nextrole_private.role(),nextrole_private.active() from public;
grant execute on function nextrole_private.role(),nextrole_private.active() to anon,authenticated;

create table public.nextrole_companies(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null unique references public.nextrole_members(id),
 name text not null check(length(trim(name)) between 2 and 120),
 website text not null default '' check(website='' or website ~ '^https://'),
 location text not null default '' check(length(location)<=200),
 industry text not null default '' check(length(industry)<=120),
 description text not null default '' check(length(description)<=5000),
 status text not null default 'pending' check(status in('pending','approved','rejected')),
 review_reason text not null default '' check(length(review_reason)<=1000),
 created_at timestamptz not null default now()
);
create function nextrole_private.company_visible(company uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.nextrole_companies c join public.nextrole_members m on m.id=c.owner_id
 where c.id=company and c.status='approved' and not m.suspended)
$$;
revoke all on function nextrole_private.company_visible(uuid) from public;
grant execute on function nextrole_private.company_visible(uuid) to anon,authenticated;

create table public.nextrole_jobs(
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.nextrole_companies(id),
 owner_id uuid not null references public.nextrole_members(id),
 title text not null check(length(trim(title)) between 2 and 150),
 location text not null check(length(trim(location)) between 2 and 200),
 category text not null default 'Other',
 employment_type text not null default 'Full-time',
 arrangement text not null default 'On-site' check(arrangement in('Remote','Hybrid','On-site')),
 salary text not null check(length(trim(salary)) between 2 and 200),
 description text not null check(length(trim(description)) between 20 and 12000),
 requirements text not null default '' check(length(requirements)<=8000),
 benefits text not null default '' check(length(benefits)<=5000),
 closes_at date not null,
 status text not null default 'draft' check(status in('draft','pending','published','paused','closed','rejected','archived')),
 review_reason text not null default '' check(length(review_reason)<=1000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index nextrole_jobs_company on public.nextrole_jobs(company_id);
create index nextrole_jobs_owner on public.nextrole_jobs(owner_id);
create index nextrole_jobs_status on public.nextrole_jobs(status,created_at desc);

create table public.nextrole_applications(
 id uuid primary key,
 job_id uuid not null references public.nextrole_jobs(id),
 candidate_id uuid not null references public.nextrole_members(id),
 snapshot jsonb not null check(octet_length(snapshot::text)<=20000),
 resume_path text not null unique,
 status text not null default 'submitted' check(status in('submitted','under_review','shortlisted','interview','offer','hired','rejected','withdrawn')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(job_id,candidate_id)
);
create index nextrole_applications_candidate on public.nextrole_applications(candidate_id);
create table public.nextrole_application_events(
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.nextrole_applications(id),
 status text not null,
 message text not null default '',
 created_at timestamptz not null default now()
);
create index nextrole_events_application on public.nextrole_application_events(application_id);
create table public.nextrole_application_notes(
 application_id uuid primary key references public.nextrole_applications(id),
 note text not null check(length(note)<=5000),
 updated_at timestamptz not null default now()
);
create table public.nextrole_saved(
 user_id uuid not null references public.nextrole_members(id),
 job_id uuid not null references public.nextrole_jobs(id),
 created_at timestamptz not null default now(),
 primary key(user_id,job_id)
);
create index nextrole_saved_job on public.nextrole_saved(job_id);
create table public.nextrole_notifications(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.nextrole_members(id),
 title text not null,
 body text not null default '',
 read boolean not null default false,
 created_at timestamptz not null default now()
);
create index nextrole_notifications_user on public.nextrole_notifications(user_id,created_at desc);
create table public.nextrole_reports(
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references public.nextrole_members(id),
 job_id uuid not null references public.nextrole_jobs(id),
 reason text not null check(length(trim(reason)) between 10 and 2000),
 status text not null default 'open' check(status in('open','in_progress','resolved','dismissed')),
 resolution text not null default '' check(length(resolution)<=2000),
 created_at timestamptz not null default now()
);
create index nextrole_reports_user on public.nextrole_reports(reporter_id);
create index nextrole_reports_job on public.nextrole_reports(job_id);
create table public.nextrole_audit(
 id uuid primary key default gen_random_uuid(),
 actor_id uuid not null references public.nextrole_members(id),
 action text not null,
 target text not null,
 reason text not null default '',
 created_at timestamptz not null default now()
);
create index nextrole_audit_actor on public.nextrole_audit(actor_id);
create table public.nextrole_settings(
 id boolean primary key default true check(id),
 categories text[] not null default array['Design','Engineering','Marketing','Operations','Other'],
 locations text[] not null default array['Kuala Lumpur','Petaling Jaya','Remote'],
 maintenance_notice text not null default '' check(length(maintenance_notice)<=1000)
);
insert into public.nextrole_settings(id) values(true);
create table public.nextrole_account_requests(
 user_id uuid primary key references public.nextrole_members(id),
 reason text not null check(length(reason)<=2000),
 status text not null default 'pending' check(status in('pending','resolved')),
 created_at timestamptz not null default now()
);

create function nextrole_private.owns_application(app uuid) returns boolean language sql stable security definer set search_path='' as $$
 select nextrole_private.role()='employer' and exists(
 select 1 from public.nextrole_applications a join public.nextrole_jobs j on j.id=a.job_id
 where a.id=app and j.owner_id=auth.uid())
$$;
create function nextrole_private.read_application(app uuid) returns boolean language sql stable security definer set search_path='' as $$
 select nextrole_private.active() and exists(select 1 from public.nextrole_applications a
 where a.id=app and (a.candidate_id=auth.uid() or nextrole_private.owns_application(app)))
$$;
revoke all on function nextrole_private.owns_application(uuid),nextrole_private.read_application(uuid) from public;
grant execute on function nextrole_private.owns_application(uuid),nextrole_private.read_application(uuid) to authenticated;

-- All writes go through checked transactional operations. RLS also protects every read.
do $$ declare t text; begin
 foreach t in array array['members','companies','jobs','applications','application_events','application_notes','saved','notifications','reports','audit','settings','account_requests'] loop
 execute format('alter table public.nextrole_%I enable row level security',t);
 execute format('revoke all on public.nextrole_%I from public,anon,authenticated',t);
 execute format('grant select on public.nextrole_%I to authenticated',t);
 end loop;
end $$;
grant select on public.nextrole_companies,public.nextrole_jobs,public.nextrole_settings to anon;
create policy nr_member_read on public.nextrole_members for select to authenticated
 using(id=auth.uid() or nextrole_private.role()='admin');
create policy nr_company_read on public.nextrole_companies for select to anon,authenticated
 using(nextrole_private.company_visible(id) or (nextrole_private.active() and (owner_id=auth.uid() or nextrole_private.role()='admin')));
create policy nr_job_read on public.nextrole_jobs for select to anon,authenticated
 using((status='published' and nextrole_private.company_visible(company_id))
 or(nextrole_private.active() and(owner_id=auth.uid() or nextrole_private.role()='admin'))
 or(nextrole_private.active() and exists(select 1 from public.nextrole_applications a where a.job_id=nextrole_jobs.id and a.candidate_id=auth.uid())));
create policy nr_application_read on public.nextrole_applications for select to authenticated
 using(nextrole_private.read_application(id));
create policy nr_event_read on public.nextrole_application_events for select to authenticated
 using(nextrole_private.read_application(application_id));
create policy nr_note_read on public.nextrole_application_notes for select to authenticated
 using(nextrole_private.owns_application(application_id));
create policy nr_saved_read on public.nextrole_saved for select to authenticated
 using(user_id=auth.uid() and nextrole_private.active());
create policy nr_notification_read on public.nextrole_notifications for select to authenticated
 using(user_id=auth.uid() and nextrole_private.active());
create policy nr_report_read on public.nextrole_reports for select to authenticated
 using(nextrole_private.active() and(reporter_id=auth.uid() or nextrole_private.role()='admin'));
create policy nr_audit_read on public.nextrole_audit for select to authenticated using(nextrole_private.role()='admin');
create policy nr_settings_read on public.nextrole_settings for select to anon,authenticated using(true);
create policy nr_account_request_read on public.nextrole_account_requests for select to authenticated
 using(nextrole_private.active() and(user_id=auth.uid() or nextrole_private.role()='admin'));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('nextrole-application-resumes','nextrole-application-resumes',false,5242880,array['application/pdf']);
create policy nr_snapshot_insert on storage.objects for insert to authenticated with check(
 bucket_id='nextrole-application-resumes' and nextrole_private.role()='employee'
 and name ~ ('^'||auth.uid()::text||'/[0-9a-f-]{36}\.pdf$')
 and not exists(select 1 from public.nextrole_applications a where a.resume_path=name));
create policy nr_snapshot_read on storage.objects for select to authenticated using(
 bucket_id='nextrole-application-resumes' and nextrole_private.active()
 and exists(select 1 from public.nextrole_applications a where a.resume_path=name and nextrole_private.read_application(a.id)));
-- No client UPDATE/DELETE policies: submitted résumé versions are immutable.

create function public.nextrole_action(action text, payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 uid uuid := auth.uid();
 member_role text := nextrole_private.role();
 target uuid;
 company uuid;
 owner uuid;
 app public.nextrole_applications;
 job public.nextrole_jobs;
 desired text;
 reason text := left(coalesce(payload->>'reason',''),2000);
 result jsonb := '{}';
begin
 if uid is null or member_role is null then raise exception 'An active account is required.' using errcode='42501'; end if;
 if octet_length(payload::text)>40000 then raise exception 'Request is too large.'; end if;
 target := nullif(payload->>'id','')::uuid;

 if action='profile_save' then
  update public.nextrole_members set full_name=left(trim(payload->>'full_name'),200),
   profile=jsonb_build_object('headline',left(coalesce(payload->>'headline',''),200),
   'location',left(coalesce(payload->>'location',''),200),'bio',left(coalesce(payload->>'bio',''),2000),
   'skills',left(coalesce(payload->>'skills',''),1000),'education',left(coalesce(payload->>'education',''),3000),
   'experience',left(coalesce(payload->>'experience',''),4000),'portfolio',left(coalesce(payload->>'portfolio',''),500),
   'preferences',left(coalesce(payload->>'preferences',''),500),
   'email_notifications',coalesce((payload->>'email_notifications')::boolean,false))
   where id=uid;
 elsif action in('company_request','company_save') then
  if member_role='admin' then raise exception 'Use an employer account.'; end if;
  select id into company from public.nextrole_companies where owner_id=uid for update;
  if company is null then
   if action<>'company_request' then raise exception 'Request employer access first.'; end if;
   insert into public.nextrole_companies(owner_id,name,website,location,industry,description)
   values(uid,trim(payload->>'name'),coalesce(payload->>'website',''),coalesce(payload->>'location',''),coalesce(payload->>'industry',''),coalesce(payload->>'description',''))
   returning id into company;
  else
   update public.nextrole_companies set name=trim(payload->>'name'),website=coalesce(payload->>'website',''),
    location=coalesce(payload->>'location',''),industry=coalesce(payload->>'industry',''),description=coalesce(payload->>'description',''),
    status=case when status='approved' then status else 'pending' end,
    review_reason=case when status='approved' then review_reason else '' end where id=company;
  end if;
  result=jsonb_build_object('id',company);
 elsif action='company_review' then
  if member_role<>'admin' then raise exception 'Administrator access required.' using errcode='42501'; end if;
  desired=payload->>'status';
  if desired not in('approved','rejected') or length(trim(reason))<5 then raise exception 'Choose a decision and supply a reason.'; end if;
  select owner_id into owner from public.nextrole_companies where id=target for update;
  if owner is null then raise exception 'Company not found.'; end if;
  update public.nextrole_companies set status=desired,review_reason=left(reason,1000) where id=target;
  update public.nextrole_members set role=case when desired='approved' then 'employer' else 'employee' end where id=owner and role<>'admin';
  if desired='rejected' then update public.nextrole_jobs set status='paused' where owner_id=owner and status='published'; end if;
  insert into public.nextrole_notifications(user_id,title,body) values(owner,'Employer request '||desired,reason);
 elsif action='job_save' then
  if member_role<>'employer' then raise exception 'Approved employer access required.' using errcode='42501'; end if;
  select id into company from public.nextrole_companies where owner_id=uid and status='approved';
  if company is null then raise exception 'Company approval required.'; end if;
  if (payload->>'closes_at')::date<current_date then raise exception 'Choose a future closing date.'; end if;
  if target is null then
   insert into public.nextrole_jobs(company_id,owner_id,title,location,category,employment_type,arrangement,salary,description,requirements,benefits,closes_at)
   values(company,uid,trim(payload->>'title'),trim(payload->>'location'),coalesce(payload->>'category','Other'),
    coalesce(payload->>'employment_type','Full-time'),coalesce(payload->>'arrangement','On-site'),trim(payload->>'salary'),
    trim(payload->>'description'),coalesce(payload->>'requirements',''),coalesce(payload->>'benefits',''),(payload->>'closes_at')::date)
   returning id into target;
  else
   update public.nextrole_jobs set title=trim(payload->>'title'),location=trim(payload->>'location'),
    category=coalesce(payload->>'category','Other'),employment_type=coalesce(payload->>'employment_type','Full-time'),
    arrangement=coalesce(payload->>'arrangement','On-site'),salary=trim(payload->>'salary'),description=trim(payload->>'description'),
    requirements=coalesce(payload->>'requirements',''),benefits=coalesce(payload->>'benefits',''),closes_at=(payload->>'closes_at')::date,
    status='draft',review_reason='',updated_at=now() where id=target and owner_id=uid;
   if not found then raise exception 'Job not found.' using errcode='42501'; end if;
  end if;
  result=jsonb_build_object('id',target);
 elsif action='job_status' then
  desired=payload->>'status';
  select * into job from public.nextrole_jobs where id=target for update;
  if job.id is null then raise exception 'Job not found.'; end if;
  if member_role='admin' then
   if desired not in('published','rejected','closed') or length(trim(reason))<5 then raise exception 'A moderation reason is required.'; end if;
   if desired='published' and (job.status<>'pending' or not nextrole_private.company_visible(job.company_id) or job.closes_at<current_date)
   then raise exception 'Only a pending, open job from an approved employer can be published.'; end if;
   update public.nextrole_jobs set status=desired,review_reason=left(reason,1000),updated_at=now() where id=target;
   insert into public.nextrole_notifications(user_id,title,body) values(job.owner_id,'Job '||desired||': '||job.title,reason);
  elsif member_role='employer' and job.owner_id=uid and nextrole_private.company_visible(job.company_id) then
   if desired not in('pending','paused','closed','archived') then raise exception 'Invalid employer action.'; end if;
   if desired='pending' and (job.status not in('draft','rejected','paused') or job.closes_at<current_date) then raise exception 'This job cannot be submitted for review.'; end if;
   if desired='paused' and job.status<>'published' then raise exception 'Only published jobs can be paused.'; end if;
   update public.nextrole_jobs set status=desired,updated_at=now() where id=target;
  else raise exception 'You cannot manage this job.' using errcode='42501'; end if;
 elsif action='save_job' then
  if member_role<>'employee' then raise exception 'Use a candidate account.'; end if;
  if not exists(select 1 from public.nextrole_jobs where id=target and status='published' and nextrole_private.company_visible(company_id)) then raise exception 'Job is unavailable.'; end if;
  if coalesce((payload->>'saved')::boolean,true) then
   insert into public.nextrole_saved(user_id,job_id) values(uid,target) on conflict do nothing;
  else delete from public.nextrole_saved where user_id=uid and job_id=target; end if;
 elsif action='application_submit' then
  if member_role<>'employee' then raise exception 'Use a candidate account.' using errcode='42501'; end if;
  select * into job from public.nextrole_jobs where id=(payload->>'job_id')::uuid for share;
  if job.id is null or job.status<>'published' or job.closes_at<current_date or not nextrole_private.company_visible(job.company_id) then raise exception 'This role is no longer accepting applications.'; end if;
  if target is null or payload->>'resume_path'<>uid::text||'/'||target::text||'.pdf'
   or not exists(select 1 from storage.objects where bucket_id='nextrole-application-resumes' and name=payload->>'resume_path')
  then raise exception 'Upload the application résumé before submitting.'; end if;
  if length(trim(coalesce(payload->>'full_name','')))<2 or coalesce(payload->>'email','') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
   or length(coalesce(payload->>'introduction',''))>5000 then raise exception 'Check your application details.'; end if;
  insert into public.nextrole_applications(id,job_id,candidate_id,snapshot,resume_path)
   values(target,job.id,uid,jsonb_build_object('full_name',left(payload->>'full_name',200),'email',left(payload->>'email',254),
   'introduction',payload->>'introduction','job_title',job.title,'company_name',(select name from public.nextrole_companies where id=job.company_id)),payload->>'resume_path');
  insert into public.nextrole_application_events(application_id,status,message) values(target,'submitted','Application submitted to the employer.');
  insert into public.nextrole_notifications(user_id,title,body) values(job.owner_id,'New application',job.title);
  result=jsonb_build_object('id',target);
 elsif action='application_status' then
  select * into app from public.nextrole_applications where id=target for update;
  if app.id is null then raise exception 'Application not found.'; end if;
  desired=payload->>'status';
  if app.status in('withdrawn','rejected','hired') then raise exception 'This application is already final.'; end if;
  if desired='withdrawn' then
   if app.candidate_id<>uid then raise exception 'Only the candidate can withdraw.' using errcode='42501'; end if;
  elsif not nextrole_private.owns_application(target) then raise exception 'You cannot review this application.' using errcode='42501';
  elsif desired not in('under_review','shortlisted','interview','offer','hired','rejected') then raise exception 'Invalid application status.';
  end if;
  update public.nextrole_applications set status=desired,updated_at=now() where id=target;
  insert into public.nextrole_application_events(application_id,status,message) values(target,desired,left(coalesce(payload->>'message',''),1000));
  select owner_id into owner from public.nextrole_jobs where id=app.job_id;
  insert into public.nextrole_notifications(user_id,title,body)
   values(case when desired='withdrawn' then owner else app.candidate_id end,'Application '||replace(desired,'_',' '),coalesce(payload->>'message',''));
 elsif action='application_note' then
  if not nextrole_private.owns_application(target) then raise exception 'Employer access required.' using errcode='42501'; end if;
  insert into public.nextrole_application_notes(application_id,note) values(target,payload->>'note')
   on conflict(application_id) do update set note=excluded.note,updated_at=now();
 elsif action='notification_read' then
  update public.nextrole_notifications set read=true where user_id=uid and (target is null or id=target);
 elsif action='report_job' then
  if not exists(select 1 from public.nextrole_jobs where id=target and status='published' and nextrole_private.company_visible(company_id)) then raise exception 'Job not found.'; end if;
  insert into public.nextrole_reports(reporter_id,job_id,reason) values(uid,target,reason);
 elsif action='report_resolve' then
  if member_role<>'admin' then raise exception 'Administrator access required.' using errcode='42501'; end if;
  desired=payload->>'status';
  if desired not in('in_progress','resolved','dismissed') or length(trim(reason))<5 then raise exception 'Status and resolution are required.'; end if;
  update public.nextrole_reports set status=desired,resolution=reason where id=target returning reporter_id into owner;
  if owner is null then raise exception 'Report not found.'; end if;
  insert into public.nextrole_notifications(user_id,title,body) values(owner,'Report updated',reason);
 elsif action='member_suspend' then
  if member_role<>'admin' or target=uid then raise exception 'Administrator access required; you cannot suspend yourself.' using errcode='42501'; end if;
  if length(trim(reason))<5 then raise exception 'A reason is required.'; end if;
  update public.nextrole_members set suspended=(payload->>'suspended')::boolean where id=target and role<>'admin';
  if not found then raise exception 'Member cannot be changed.'; end if;
 elsif action='settings_save' then
  if member_role<>'admin' then raise exception 'Administrator access required.' using errcode='42501'; end if;
  if length(trim(reason))<5 then raise exception 'A reason is required.'; end if;
  update public.nextrole_settings set maintenance_notice=coalesce(payload->>'maintenance_notice',''),
   categories=array(select jsonb_array_elements_text(payload->'categories')),
   locations=array(select jsonb_array_elements_text(payload->'locations')) where id=true;
 elsif action='account_request' then
  insert into public.nextrole_account_requests(user_id,reason) values(uid,reason)
   on conflict(user_id) do update set reason=excluded.reason,status='pending',created_at=now();
 elsif action='account_request_resolve' then
  if member_role<>'admin' or length(trim(reason))<5 then raise exception 'Administrator decision and reason required.'; end if;
  update public.nextrole_account_requests set status='resolved' where user_id=target;
 else raise exception 'Unknown operation.';
 end if;
 if member_role='admin' and action in('company_review','job_status','member_suspend','report_resolve','settings_save','account_request_resolve') then
  insert into public.nextrole_audit(actor_id,action,target,reason) values(uid,action,coalesce(target::text,'platform'),reason);
 end if;
 return result;
end $$;
revoke all on function public.nextrole_action(text,jsonb) from public,anon;
grant execute on function public.nextrole_action(text,jsonb) to authenticated;

