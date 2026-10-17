-- Rollback-only end-to-end permission/lifecycle test; no emails or real accounts changed.
begin;
select set_config('nr.candidate',gen_random_uuid()::text,true),
set_config('nr.employer',gen_random_uuid()::text,true),
set_config('nr.other',gen_random_uuid()::text,true),
set_config('nr.admin',gen_random_uuid()::text,true),
set_config('nr.app',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
select current_setting('nr.'||x)::uuid,'authenticated','authenticated',x||'-'||current_setting('nr.'||x)||'@example.invalid',
'{"provider":"email","providers":["email"]}'::jsonb,'{"full_name":"Lifecycle test","role":"admin"}'::jsonb
from unnest(array['candidate','employer','other','admin']) x;
do $$ begin
if exists(select 1 from public.nextrole_members where id in(current_setting('nr.candidate')::uuid,current_setting('nr.employer')::uuid) and role<>'employee')
then raise exception 'Metadata role escalation';end if;end $$;
update public.nextrole_members set role='admin' where id=current_setting('nr.admin')::uuid;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.employer'),'role','authenticated')::text,true);
select set_config('nr.company',(public.nextrole_action('company_request','{"name":"Lifecycle Company","description":"Fictional policy test"}')->>'id'),true);
do $$ begin
begin perform public.nextrole_action('company_review',jsonb_build_object('id',current_setting('nr.company'),'status','approved','reason','Self approve'));
raise exception 'Self approval succeeded';exception when insufficient_privilege then null;end;
begin update public.nextrole_members set role='admin' where id=auth.uid();
raise exception 'Direct escalation succeeded';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.admin'),'role','authenticated')::text,true);
select public.nextrole_action('company_review',jsonb_build_object('id',current_setting('nr.company'),'status','approved','reason','Approved synthetic employer'));
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.employer'),'role','authenticated')::text,true);
select set_config('nr.job',public.nextrole_action('job_save',jsonb_build_object(
'title','Lifecycle role','location','Remote','salary','RM 2000 per month','description','A fictional role used for a rollback-only policy verification.','closes_at',(current_date+30)::text))->>'id',true);
select public.nextrole_action('job_status',jsonb_build_object('id',current_setting('nr.job'),'status','pending'));
do $$ begin
begin perform public.nextrole_action('job_status',jsonb_build_object('id',current_setting('nr.job'),'status','published'));
raise exception 'Employer published without moderation';exception when raise_exception then if SQLERRM<>'Invalid employer action.' then raise;end if;end;end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.admin'),'role','authenticated')::text,true);
select public.nextrole_action('job_status',jsonb_build_object('id',current_setting('nr.job'),'status','published','reason','Approved synthetic job'));
set local role anon;
do $$ begin
if not exists(select 1 from public.nextrole_jobs where id=current_setting('nr.job')::uuid)then raise exception 'Guest cannot read published job';end if;
begin perform public.nextrole_action('profile_save','{}');raise exception 'Guest mutation allowed';exception when insufficient_privilege then null;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.candidate'),'role','authenticated')::text,true);
select public.nextrole_action('save_job',jsonb_build_object('id',current_setting('nr.job'),'saved',true));
insert into public.nextrole_drafts(user_id,job_id,full_name,email,introduction)
values(auth.uid(),current_setting('nr.job'),'Candidate','candidate@example.invalid','Private draft');
insert into storage.objects(bucket_id,name,metadata)
values('nextrole-application-resumes',current_setting('nr.candidate')||'/'||current_setting('nr.app')||'.pdf','{"mimetype":"application/pdf","size":100}');
select public.nextrole_action('application_submit',jsonb_build_object('id',current_setting('nr.app'),'job_id',current_setting('nr.job'),
'full_name','Candidate','email','candidate@example.invalid','introduction','A submitted introduction',
'resume_path',current_setting('nr.candidate')||'/'||current_setting('nr.app')||'.pdf'));
do $$ begin
if not exists(select 1 from public.nextrole_applications where id=current_setting('nr.app')::uuid)then raise exception 'Candidate cannot read submission';end if;
if not exists(select 1 from storage.objects where bucket_id='nextrole-application-resumes')then raise exception 'Candidate cannot read snapshot';end if;
update storage.objects set metadata='{}' where bucket_id='nextrole-application-resumes';
if found then raise exception 'Submitted résumé modified';end if;
begin perform public.nextrole_action('member_suspend',jsonb_build_object('id',current_setting('nr.employer'),'suspended',true,'reason','Candidate attack'));
raise exception 'Candidate suspended employer';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.employer'),'role','authenticated')::text,true);
do $$ begin
if (select count(*) from public.nextrole_applications where id=current_setting('nr.app')::uuid)<>1 then raise exception 'Employer missing submitted application';end if;
if exists(select 1 from public.nextrole_drafts where user_id=current_setting('nr.candidate')::uuid)then raise exception 'Employer can read private draft';end if;
if not exists(select 1 from storage.objects where bucket_id='nextrole-application-resumes')then raise exception 'Employer missing submitted résumé';end if;
end $$;
select public.nextrole_action('application_status',jsonb_build_object('id',current_setting('nr.app'),'status','interview','message','Synthetic interview status'));
select public.nextrole_action('application_note',jsonb_build_object('id',current_setting('nr.app'),'note','Private hiring note'));
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.other'),'role','authenticated')::text,true);
do $$ begin
if exists(select 1 from public.nextrole_applications where id=current_setting('nr.app')::uuid)then raise exception 'Cross-account application leak';end if;
if exists(select 1 from storage.objects where bucket_id='nextrole-application-resumes')then raise exception 'Cross-account résumé leak';end if;
begin perform public.nextrole_action('application_status',jsonb_build_object('id',current_setting('nr.app'),'status','offer'));
raise exception 'Cross-account status write';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.admin'),'role','authenticated')::text,true);
do $$ begin
if exists(select 1 from public.nextrole_applications where id=current_setting('nr.app')::uuid)then raise exception 'Admin has candidate content access';end if;
if exists(select 1 from storage.objects where bucket_id='nextrole-application-resumes')then raise exception 'Admin has résumé access';end if;
if not exists(select 1 from public.nextrole_audit where actor_id=auth.uid())then raise exception 'Missing moderation audit';end if;
end $$;
select public.nextrole_action('member_suspend',jsonb_build_object('id',current_setting('nr.other'),'suspended',true,'reason','Synthetic suspension test'));
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.other'),'role','authenticated')::text,true);
do $$ begin
begin perform public.nextrole_action('company_request','{"name":"Suspended company"}');
raise exception 'Suspended member mutation';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.candidate'),'role','authenticated')::text,true);
do $$ begin
if exists(select 1 from public.nextrole_application_notes where application_id=current_setting('nr.app')::uuid)then raise exception 'Candidate read private hiring note';end if;
if not exists(select 1 from public.nextrole_application_events where application_id=current_setting('nr.app')::uuid and status='interview')then raise exception 'Missing candidate-visible status';end if;
end $$;
select public.nextrole_action('application_status',jsonb_build_object('id',current_setting('nr.app'),'status','withdrawn'));
reset role;
rollback;
select 'PASS: metadata role protection, employer approval, job moderation, guest discovery, persistent saves, submission, immutable résumé metadata, owner isolation, private notes, candidate timeline, admin least privilege, suspension and withdrawal; all synthetic rows rolled back.' as verification;

