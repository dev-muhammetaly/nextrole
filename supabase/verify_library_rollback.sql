begin;
select set_config('nr.c',gen_random_uuid()::text,true),set_config('nr.o',gen_random_uuid()::text,true),set_config('nr.f',gen_random_uuid()::text,true),set_config('nr.f2',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,email,raw_user_meta_data)
select current_setting('nr.'||x)::uuid,'authenticated','authenticated','rollback-'||gen_random_uuid()||'@example.invalid','{}'::jsonb from unnest(array['c','o']) x;
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.c'),'role','authenticated')::text,true);
insert into storage.objects(bucket_id,name,metadata) select 'nextrole-resume-library',auth.uid()::text||'/'||current_setting('nr.'||x)||'.pdf','{"mimetype":"application/pdf","size":100}'::jsonb from unnest(array['f','f2']) x;
select public.nextrole_action('resume_register',jsonb_build_object('id',current_setting('nr.f'),'file_name','Design.pdf','display_name','Design CV'));
select public.nextrole_action('resume_register',jsonb_build_object('id',current_setting('nr.f2'),'library_id',current_setting('nr.f'),'file_name','Revised.pdf','display_name','Design CV'));
do $$ begin
 if (select count(*) from public.nextrole_resume_files where user_id=auth.uid())<>2 then raise exception 'Version rows missing'; end if;
 if not exists(select 1 from public.nextrole_resume_files where version=2 and is_current and user_id=auth.uid()) then raise exception 'Current version missing'; end if;
 begin update public.nextrole_resume_files set display_name='Bad'; raise exception 'Direct writes allowed'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.o'),'role','authenticated')::text,true);
do $$ begin
 if exists(select 1 from public.nextrole_resume_files where user_id=current_setting('nr.c')::uuid) then raise exception 'Library isolation failed'; end if;
 if exists(select 1 from storage.objects where bucket_id='nextrole-resume-library' and name like current_setting('nr.c')||'/%') then raise exception 'File isolation failed'; end if;
end $$;
reset role;
rollback;
select 'PASS: private version creation, current version, direct-write denial and cross-account metadata/storage isolation; all test rows rolled back.' as verification;
