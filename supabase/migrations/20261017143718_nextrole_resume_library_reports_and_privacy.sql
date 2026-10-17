-- Additive extension. Existing application snapshots and legacy résumé files stay intact.
create table public.nextrole_resume_files (
 id uuid primary key,
 library_id uuid not null,
 user_id uuid not null references public.nextrole_members(id),
 version integer not null check(version>0),
 display_name text not null check(length(trim(display_name)) between 1 and 120),
 file_name text not null check(length(file_name) between 1 and 200 and file_name !~ '[/\\]'),
 object_path text not null unique,
 byte_size integer not null check(byte_size between 5 and 5242880),
 is_current boolean not null default true,
 created_at timestamptz not null default now(),
 deleted_at timestamptz,
 unique(library_id,version)
);
create unique index nr_resume_current on public.nextrole_resume_files(library_id) where is_current and deleted_at is null;
create index nr_resume_owner on public.nextrole_resume_files(user_id,created_at desc);
alter table public.nextrole_resume_files enable row level security;
revoke all on public.nextrole_resume_files from public,anon,authenticated;
grant select on public.nextrole_resume_files to authenticated;
create policy nr_library_metadata_read on public.nextrole_resume_files for select to authenticated
 using(user_id=(select auth.uid()) and (select nextrole_private.active()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('nextrole-resume-library','nextrole-resume-library',false,5242880,array['application/pdf']);
create policy nr_library_read on storage.objects for select to authenticated using(
 bucket_id='nextrole-resume-library' and (select nextrole_private.active()) and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy nr_library_upload on storage.objects for insert to authenticated with check(
 bucket_id='nextrole-resume-library' and (select nextrole_private.role())='employee'
 and name ~ ('^'||(select auth.uid())::text||'/[0-9a-f-]{36}\.pdf$'));
create policy nr_library_delete on storage.objects for delete to authenticated using(
 bucket_id='nextrole-resume-library' and (select nextrole_private.active()) and (storage.foldername(name))[1]=(select auth.uid())::text);
-- No UPDATE policy: every private replacement gets a new object/version.

alter table public.nextrole_reports add column assigned_revision integer not null default 1;
alter table public.nextrole_reports add column updated_at timestamptz not null default now();
alter table public.nextrole_reports add column public_message text not null default '' check(length(public_message)<=2000);
create table public.nextrole_report_work (
 report_id uuid primary key references public.nextrole_reports(id) on delete cascade,
 reviewer_id uuid references public.nextrole_members(id),
 investigation_note text not null default '' check(length(investigation_note)<=10000),
 resolution_summary text not null default '' check(length(resolution_summary)<=2000),
 updated_at timestamptz not null default now()
);
create index nr_report_reviewer on public.nextrole_report_work(reviewer_id);
alter table public.nextrole_report_work enable row level security;
revoke all on public.nextrole_report_work from public,anon,authenticated;
grant select on public.nextrole_report_work to authenticated;
create policy nr_report_work_admin on public.nextrole_report_work for select to authenticated
 using((select nextrole_private.role())='admin');

create table public.nextrole_privacy_requests (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.nextrole_members(id),
 kind text not null check(kind in('access','correction','export','deletion','retention','other')),
 message text not null check(length(trim(message)) between 10 and 2000),
 status text not null default 'pending' check(status in('pending','in_progress','resolved')),
 response text not null default '' check(length(response)<=4000),
 revision integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index nr_privacy_owner on public.nextrole_privacy_requests(user_id,created_at desc);
create index nr_privacy_status on public.nextrole_privacy_requests(status,created_at);
alter table public.nextrole_privacy_requests enable row level security;
revoke all on public.nextrole_privacy_requests from public,anon,authenticated;
grant select on public.nextrole_privacy_requests to authenticated;
-- A suspended account must still be able to contact the operator about privacy.
create policy nr_privacy_read on public.nextrole_privacy_requests for select to authenticated
 using(user_id=(select auth.uid()) or (select nextrole_private.role())='admin');

-- Preserve the currently deployed core implementation, including prior validations.
do $$ begin
 execute replace(pg_get_functiondef('public.nextrole_action(text,jsonb)'::regprocedure),
 'FUNCTION public.nextrole_action(', 'FUNCTION nextrole_private.core_action_v2(');
end $$;
revoke all on function nextrole_private.core_action_v2(text,jsonb) from public,anon,authenticated;

create or replace function public.nextrole_action(action text,payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid(); member_role text:=nextrole_private.role(); target uuid:=nullif(payload->>'id','')::uuid;
 family uuid; prior public.nextrole_resume_files; selected public.nextrole_resume_files;
 report public.nextrole_reports; work public.nextrole_report_work; request public.nextrole_privacy_requests;
 actor uuid; recipient uuid; desired text; reason text:=trim(coalesce(payload->>'reason',''));
 path text; result jsonb:='{}'; metadata jsonb; v integer; count_active integer;
begin
 if uid is null or octet_length(payload::text)>40000 then raise exception 'A valid signed-in request is required.' using errcode='42501'; end if;

 if action='privacy_request' then
  if not exists(select 1 from public.nextrole_members where id=uid) then raise exception 'Account not found.'; end if;
  if (select count(*) from public.nextrole_privacy_requests where user_id=uid and status<>'resolved')>=5 then raise exception 'You already have five open requests. Follow up on an existing request.'; end if;
  insert into public.nextrole_privacy_requests(user_id,kind,message)
   values(uid,payload->>'kind',trim(payload->>'message')) returning id into target;
  return jsonb_build_object('id',target);
 end if;
 if member_role is null then raise exception 'An active account is required.' using errcode='42501'; end if;

 if action='resume_register' then
  if member_role<>'employee' or target is null then raise exception 'Candidate access required.' using errcode='42501'; end if;
  perform 1 from public.nextrole_members where id=uid for update;
  path:=uid::text||'/'||target::text||'.pdf';
  select * into selected from public.nextrole_resume_files where id=target;
  if found then
   if selected.user_id<>uid or selected.deleted_at is not null then raise exception 'File is unavailable.' using errcode='42501'; end if;
   return jsonb_build_object('id',selected.id,'version',selected.version);
  end if;
  select o.metadata into metadata from storage.objects o where bucket_id='nextrole-resume-library' and name=path;
  if metadata is null or (metadata->>'size')::bigint not between 5 and 5242880 or metadata->>'mimetype'<>'application/pdf' then raise exception 'Upload a PDF up to 5 MB before saving.'; end if;
  family:=coalesce(nullif(payload->>'library_id','')::uuid,target);
  select * into prior from public.nextrole_resume_files where library_id=family and is_current and deleted_at is null for update;
  if prior.id is not null and prior.user_id<>uid then raise exception 'You cannot replace this file.' using errcode='42501'; end if;
  if prior.id is null and family<>target then raise exception 'Résumé to replace was not found.'; end if;
  select count(*) into count_active from public.nextrole_resume_files where user_id=uid and is_current and deleted_at is null;
  if prior.id is null and count_active>=10 then raise exception 'Keep up to 10 private résumés. Delete one before adding another.'; end if;
  if (select count(*) from public.nextrole_resume_files where user_id=uid and deleted_at is null)>=50 then raise exception 'Private version limit reached. Delete a résumé and its versions before uploading again.'; end if;
  v:=coalesce(prior.version,0)+1;
  update public.nextrole_resume_files set is_current=false where id=prior.id;
  insert into public.nextrole_resume_files(id,library_id,user_id,version,display_name,file_name,object_path,byte_size)
   values(target,family,uid,v,trim(payload->>'display_name'),payload->>'file_name',path,(metadata->>'size')::integer);
  return jsonb_build_object('id',target,'version',v);
 elsif action='resume_delete' then
  select * into selected from public.nextrole_resume_files where id=target and user_id=uid and deleted_at is null for update;
  if selected.id is null then raise exception 'Résumé not found.' using errcode='42501'; end if;
  if exists(select 1 from storage.objects o join public.nextrole_resume_files f on f.object_path=o.name
   where o.bucket_id='nextrole-resume-library' and f.library_id=selected.library_id and f.deleted_at is null) then raise exception 'Remove the private file versions before confirming deletion.'; end if;
  update public.nextrole_resume_files set deleted_at=now(),is_current=false where library_id=selected.library_id and user_id=uid;
  return jsonb_build_object('id',target);
 elsif action='application_submit' and payload ? 'resume_version_id' then
  select * into selected from public.nextrole_resume_files where id=(payload->>'resume_version_id')::uuid and user_id=uid and deleted_at is null for share;
  if selected.id is null or not exists(select 1 from storage.objects where bucket_id='nextrole-resume-library' and name=selected.object_path) then raise exception 'Selected résumé version is unavailable.'; end if;
  result:=nextrole_private.core_action_v2(action,payload);
  update public.nextrole_applications set snapshot=snapshot||jsonb_build_object('resume_file_name',selected.file_name,'resume_display_name',selected.display_name,'resume_version',selected.version,'resume_version_id',selected.id)
   where id=(result->>'id')::uuid and candidate_id=uid;
  return result;
 elsif action in('report_save_work','report_resolve') then
  if member_role<>'admin' then raise exception 'Administrator access required.' using errcode='42501'; end if;
  select * into report from public.nextrole_reports where id=target for update;
  if report.id is null then raise exception 'Report not found.'; end if;
  if (payload->>'expected_revision')::integer is distinct from report.assigned_revision then raise exception 'This report changed. Reload it before saving; your input is kept.' using errcode='40001'; end if;
  select * into work from public.nextrole_report_work where report_id=target;
  if action='report_save_work' then
   actor:=nullif(payload->>'reviewer_id','')::uuid;
   if actor is not null and not exists(select 1 from public.nextrole_members where id=actor and role='admin' and not suspended) then raise exception 'Choose an active administrator.'; end if;
   insert into public.nextrole_report_work(report_id,reviewer_id,investigation_note) values(target,actor,coalesce(payload->>'investigation_note',''))
    on conflict(report_id) do update set reviewer_id=excluded.reviewer_id,investigation_note=excluded.investigation_note,updated_at=now();
   reason:='Updated report assignment/investigation notes. Private note content is excluded from the audit entry.';
  else
   desired:=payload->>'status';
   if desired not in('in_progress','resolved','dismissed') or length(reason) not between 5 and 2000 then raise exception 'A status and specific decision reason are required.'; end if;
   if report.status in('resolved','dismissed') then raise exception 'This report already has a final outcome.'; end if;
   insert into public.nextrole_report_work(report_id,resolution_summary) values(target,reason)
    on conflict(report_id) do update set resolution_summary=excluded.resolution_summary,updated_at=now();
   update public.nextrole_reports set status=desired,public_message=coalesce(payload->>'public_message',''),resolution=coalesce(payload->>'public_message','') where id=target;
   if length(trim(coalesce(payload->>'public_message','')))>0 then
    insert into public.nextrole_notifications(user_id,title,body) values(report.reporter_id,'Report update',payload->>'public_message');
    select owner_id into recipient from public.nextrole_jobs where id=report.job_id;
    if recipient is distinct from report.reporter_id then insert into public.nextrole_notifications(user_id,title,body) values(recipient,'Reported listing update',payload->>'public_message'); end if;
   end if;
  end if;
  update public.nextrole_reports set assigned_revision=assigned_revision+1,updated_at=now() where id=target;
  insert into public.nextrole_audit(actor_id,action,target,reason) values(uid,action,target::text,reason);
  return jsonb_build_object('id',target,'revision',report.assigned_revision+1);
 elsif action='privacy_respond' then
  if member_role<>'admin' then raise exception 'Administrator access required.' using errcode='42501'; end if;
  select * into request from public.nextrole_privacy_requests where id=target for update;
  if request.id is null or (payload->>'expected_revision')::integer is distinct from request.revision then raise exception 'This request changed. Reload before responding.' using errcode='40001'; end if;
  if payload->>'status' not in('in_progress','resolved') or length(trim(coalesce(payload->>'response','')))<5 then raise exception 'Status and a useful response are required.'; end if;
  update public.nextrole_privacy_requests set status=payload->>'status',response=payload->>'response',revision=revision+1,updated_at=now() where id=target;
  insert into public.nextrole_notifications(user_id,title,body) values(request.user_id,'Privacy request updated','Open Privacy requests to read the response.');
  insert into public.nextrole_audit(actor_id,action,target,reason) values(uid,action,target::text,'Updated privacy request status. Request content is excluded from the audit entry.');
  return jsonb_build_object('id',target);
 elsif action in('retention_review','retention_record_review') then
  if member_role<>'admin' then raise exception 'Administrator access required.' using errcode='42501'; end if;
  result:=jsonb_build_object(
   'private_drafts_due',(select count(*) from public.nextrole_drafts where updated_at<now()-interval '12 months'),
   'terminal_applications_due',(select count(*) from public.nextrole_applications where status in('withdrawn','rejected','hired') and updated_at<now()-interval '6 months'),
   'closed_reports_due',(select count(*) from public.nextrole_reports where status in('resolved','dismissed') and updated_at<now()-interval '12 months'),
   'read_notifications_due',(select count(*) from public.nextrole_notifications where read and created_at<now()-interval '90 days'),
   'closed_privacy_requests_due',(select count(*) from public.nextrole_privacy_requests where status='resolved' and updated_at<now()-interval '12 months'),
   'audit_events_due',(select count(*) from public.nextrole_audit where created_at<now()-interval '12 months'),
   'last_review',(select max(created_at) from public.nextrole_audit where public.nextrole_audit.action='retention_record_review'));
  if action='retention_record_review' then
   if length(reason) not between 5 and 1000 then raise exception 'Record the review outcome and any follow-up.'; end if;
   insert into public.nextrole_audit(actor_id,action,target,reason) values(uid,action,'retention',reason);
  end if;
  return result;
 end if;
 return nextrole_private.core_action_v2(action,payload);
end $$;
revoke all on function public.nextrole_action(text,jsonb) from public,anon;
grant execute on function public.nextrole_action(text,jsonb) to authenticated;
