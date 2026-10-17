begin;
select set_config('nr.c',gen_random_uuid()::text,true),set_config('nr.a',gen_random_uuid()::text,true),set_config('nr.co',gen_random_uuid()::text,true),set_config('nr.j',gen_random_uuid()::text,true),set_config('nr.r',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,email,raw_user_meta_data) select current_setting('nr.'||x)::uuid,'authenticated','authenticated','rollback-'||gen_random_uuid()||'@example.invalid','{}'::jsonb from unnest(array['c','a']) x;
update public.nextrole_members set role='admin' where id=current_setting('nr.a')::uuid;
insert into public.nextrole_companies(id,owner_id,name,status) values(current_setting('nr.co')::uuid,current_setting('nr.c')::uuid,'Rollback company','approved');
insert into public.nextrole_jobs(id,owner_id,company_id,title,location,salary,description,closes_at,status) values(current_setting('nr.j')::uuid,current_setting('nr.c')::uuid,current_setting('nr.co')::uuid,'Rollback role','Remote','RM 2000 / month','Rollback-only test role description.',current_date+30,'published');
insert into public.nextrole_reports(id,reporter_id,job_id,reason) values(current_setting('nr.r')::uuid,current_setting('nr.c')::uuid,current_setting('nr.j')::uuid,'Rollback fictional wording concern.');
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.a'),'role','authenticated')::text,true);
select public.nextrole_action('report_save_work',jsonb_build_object('id',current_setting('nr.r'),'expected_revision',1,'reviewer_id',current_setting('nr.a'),'investigation_note','SECRET INVESTIGATION'));
do $$ begin
 if not exists(select 1 from public.nextrole_report_work where report_id=current_setting('nr.r')::uuid and investigation_note='SECRET INVESTIGATION') then raise exception 'Private note missing'; end if;
 begin perform public.nextrole_action('report_save_work',jsonb_build_object('id',current_setting('nr.r'),'expected_revision',1)); raise exception 'Stale write accepted'; exception when serialization_failure then null; end;
end $$;
select public.nextrole_action('report_resolve',jsonb_build_object('id',current_setting('nr.r'),'expected_revision',2,'status','resolved','reason','SECRET RESOLUTION','public_message','Wording reviewed.'));
select public.nextrole_action('retention_review','{}');
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.c'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.nextrole_report_work where report_id=current_setting('nr.r')::uuid) then raise exception 'Private investigation leaked'; end if;
 if exists(select 1 from public.nextrole_reports where id=current_setting('nr.r')::uuid and (resolution like '%SECRET%' or public_message like '%SECRET%')) then raise exception 'Resolution summary leaked'; end if;
 if exists(select 1 from public.nextrole_notifications where user_id=auth.uid() and body like '%SECRET%') then raise exception 'Notification leaked private summary'; end if;
 begin perform public.nextrole_action('retention_review','{}'); raise exception 'Candidate accessed retention review'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
select 'PASS: assigned reviewer, private investigation, stale-write rejection, separate public outcome, notification privacy and admin-only retention; all fixtures rolled back.' as verification;
