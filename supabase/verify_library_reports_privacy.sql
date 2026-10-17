-- All fixtures, role changes and synthetic Storage metadata are rolled back.
-- No passwords, identities, email sends or persistent test access are created.
begin;
select set_config('nr.candidate',gen_random_uuid()::text,true),set_config('nr.employer',gen_random_uuid()::text,true),
 set_config('nr.other',gen_random_uuid()::text,true),set_config('nr.admin',gen_random_uuid()::text,true),
 set_config('nr.file1',gen_random_uuid()::text,true),set_config('nr.file2',gen_random_uuid()::text,true),set_config('nr.file3',gen_random_uuid()::text,true),set_config('nr.app',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
 select current_setting('nr.'||x)::uuid,'authenticated','authenticated','rollback-'||x||'-'||current_setting('nr.'||x)||'@example.invalid',
 '{"provider":"email","providers":["email"]}'::jsonb,'{"full_name":"Rollback only"}'::jsonb from unnest(array['candidate','employer','other','admin']) x;
update public.nextrole_members set role='admin' where id=current_setting('nr.admin')::uuid;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.employer'),'role','authenticated')::text,true);
select set_config('nr.company',public.nextrole_action('company_request','{"name":"Rollback company","description":"Disposable transaction only"}')->>'id',true);
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.admin'),'role','authenticated')::text,true);
select public.nextrole_action('company_review',jsonb_build_object('id',current_setting('nr.company'),'status','approved','reason','Rollback only employer approval'));
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.employer'),'role','authenticated')::text,true);
select set_config('nr.job',public.nextrole_action('job_save',jsonb_build_object('title','Rollback job','location','Remote','salary','RM 2000 / month','description','A fictional rollback-only database verification role.','closes_at',(current_date+30)::text))->>'id',true);
select public.nextrole_action('job_status',jsonb_build_object('id',current_setting('nr.job'),'status','pending'));
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.admin'),'role','authenticated')::text,true);
select public.nextrole_action('job_status',jsonb_build_object('id',current_setting('nr.job'),'status','published','reason','Rollback only job approval'));
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.candidate'),'role','authenticated')::text,true);
insert into storage.objects(bucket_id,name,metadata) select 'nextrole-resume-library',auth.uid()::text||'/'||current_setting('nr.'||x)||'.pdf','{"mimetype":"application/pdf","size":100}'::jsonb from unnest(array['file1','file2','file3']) x;
select public.nextrole_action('resume_register',jsonb_build_object('id',current_setting('nr.file1'),'file_name','Design.pdf','display_name','Design CV'));
select public.nextrole_action('resume_register',jsonb_build_object('id',current_setting('nr.file2'),'file_name','Engineering.pdf','display_name','Engineering CV'));
select public.nextrole_action('resume_register',jsonb_build_object('id',current_setting('nr.file3'),'library_id',current_setting('nr.file1'),'file_name','Design revised.pdf','display_name','Design CV'));
do $$ begin
 if (select count(*) from public.nextrole_resume_files where user_id=auth.uid() and is_current)<>2 then raise exception 'Multiple files/current version count failed'; end if;
 if not exists(select 1 from public.nextrole_resume_files where id=current_setting('nr.file1')::uuid and version=1 and not is_current) then raise exception 'Original private version not preserved'; end if;
 if not exists(select 1 from public.nextrole_resume_files where id=current_setting('nr.file3')::uuid and version=2 and is_current) then raise exception 'New private version missing'; end if;
 begin update public.nextrole_resume_files set user_id=current_setting('nr.other')::uuid where id=current_setting('nr.file1')::uuid; raise exception 'Direct metadata mutation succeeded'; exception when insufficient_privilege then null; end;
end $$;
insert into storage.objects(bucket_id,name,metadata) values('nextrole-application-resumes',auth.uid()::text||'/'||current_setting('nr.app')||'.pdf','{"mimetype":"application/pdf","size":100}');
select public.nextrole_action('application_submit',jsonb_build_object('id',current_setting('nr.app'),'job_id',current_setting('nr.job'),'full_name','Rollback Candidate','email','rollback@example.invalid','introduction','Selected version test','resume_path',auth.uid()::text||'/'||current_setting('nr.app')||'.pdf','resume_version_id',current_setting('nr.file1')));
do $$ begin
 if not exists(select 1 from public.nextrole_applications where id=current_setting('nr.app')::uuid and snapshot->>'resume_file_name'='Design.pdf' and snapshot->>'resume_version'='1') then raise exception 'Selected version snapshot failed'; end if;
end $$;
delete from storage.objects where bucket_id='nextrole-resume-library' and name in(auth.uid()::text||'/'||current_setting('nr.file1')||'.pdf',auth.uid()::text||'/'||current_setting('nr.file3')||'.pdf');
select public.nextrole_action('resume_delete',jsonb_build_object('id',current_setting('nr.file1')));
do $$ begin
 if not exists(select 1 from public.nextrole_applications where id=current_setting('nr.app')::uuid and snapshot->>'resume_file_name'='Design.pdf') then raise exception 'Library deletion changed submission'; end if;
end $$;
select public.nextrole_action('report_job',jsonb_build_object('id',current_setting('nr.job'),'reason','Rollback report concerning fictional role wording.'));
select set_config('nr.report',(select id::text from public.nextrole_reports where reporter_id=auth.uid() and job_id=current_setting('nr.job')::uuid),true);
select set_config('nr.privacy',public.nextrole_action('privacy_request','{"kind":"access","message":"Rollback privacy request to verify the private contact channel."}')->>'id',true);
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.admin'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.nextrole_resume_files where user_id=current_setting('nr.candidate')::uuid) then raise exception 'Administrator can browse private library'; end if;
 if exists(select 1 from storage.objects where bucket_id='nextrole-resume-library' and name like current_setting('nr.candidate')||'/%') then raise exception 'Administrator can read private library objects'; end if;
end $$;
select public.nextrole_action('report_save_work',jsonb_build_object('id',current_setting('nr.report'),'expected_revision',1,'reviewer_id',current_setting('nr.admin'),'investigation_note','SECRET ADMIN INVESTIGATION'));
do $$ begin
 begin perform public.nextrole_action('report_save_work',jsonb_build_object('id',current_setting('nr.report'),'expected_revision',1,'investigation_note','Stale overwrite')); raise exception 'Stale report edit succeeded'; exception when serialization_failure then null; end;
 if not exists(select 1 from public.nextrole_report_work where report_id=current_setting('nr.report')::uuid and investigation_note='SECRET ADMIN INVESTIGATION') then raise exception 'Investigation notes missing'; end if;
end $$;
select public.nextrole_action('report_resolve',jsonb_build_object('id',current_setting('nr.report'),'expected_revision',2,'status','resolved','reason','SECRET ADMIN RESOLUTION','public_message','The fictional wording was reviewed.'));
select public.nextrole_action('privacy_respond',jsonb_build_object('id',current_setting('nr.privacy'),'expected_revision',1,'status','resolved','response','Your rollback-only privacy request was reviewed.'));
select public.nextrole_action('retention_review','{}');
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.candidate'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.nextrole_report_work where report_id=current_setting('nr.report')::uuid) then raise exception 'Candidate reads private investigation'; end if;
 if exists(select 1 from public.nextrole_reports where id=current_setting('nr.report')::uuid and (resolution like '%SECRET%' or public_message like '%SECRET%')) then raise exception 'Private report reason leaked'; end if;
 if exists(select 1 from public.nextrole_notifications where user_id=auth.uid() and body like '%SECRET ADMIN%') then raise exception 'Private note leaked via notification'; end if;
 if not exists(select 1 from public.nextrole_privacy_requests where id=current_setting('nr.privacy')::uuid and status='resolved') then raise exception 'Owner cannot read privacy reply'; end if;
 begin perform public.nextrole_action('retention_review','{}'); raise exception 'Candidate accessed operator retention'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.other'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.nextrole_resume_files where user_id=current_setting('nr.candidate')::uuid) then raise exception 'Cross-account library leak'; end if;
 if exists(select 1 from public.nextrole_privacy_requests where id=current_setting('nr.privacy')::uuid) then raise exception 'Cross-account privacy request leak'; end if;
 begin perform public.nextrole_action('report_save_work',jsonb_build_object('id',current_setting('nr.report'),'expected_revision',3,'investigation_note','Unauthorized')); raise exception 'Candidate changed report investigation'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.employer'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.nextrole_report_work where report_id=current_setting('nr.report')::uuid) then raise exception 'Employer reads private investigation'; end if;
 if exists(select 1 from public.nextrole_resume_files where user_id=current_setting('nr.candidate')::uuid) then raise exception 'Employer browses private library'; end if;
 if not exists(select 1 from public.nextrole_applications where id=current_setting('nr.app')::uuid and snapshot->>'resume_version'='1') then raise exception 'Employer selected snapshot unavailable'; end if;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.admin'),'role','authenticated')::text,true);
select public.nextrole_action('member_suspend',jsonb_build_object('id',current_setting('nr.other'),'suspended',true,'reason','Rollback privacy accessibility test'));
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.other'),'role','authenticated')::text,true);
select public.nextrole_action('privacy_request','{"kind":"other","message":"Suspended users retain this private contact channel."}');
set local role anon;
do $$ begin
 begin perform public.nextrole_action('privacy_request','{}'); raise exception 'Anonymous privacy write allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
select 'PASS: multiple private files, immutable versions and chosen snapshot metadata, owner-only library, protected investigations and public outcomes, stale-write rejection, private contact and replies, suspended-user contact, admin-only retention review; all fixtures and role changes rolled back.' as verification;
