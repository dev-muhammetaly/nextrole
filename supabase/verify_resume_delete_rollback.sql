begin;
select set_config('nr.c',gen_random_uuid()::text,true),set_config('nr.f',gen_random_uuid()::text,true),set_config('nr.f2',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,email,raw_user_meta_data) values(current_setting('nr.c')::uuid,'authenticated','authenticated','rollback-'||gen_random_uuid()||'@example.invalid','{}');
-- Synthetic metadata representing versions whose Storage API removal completed.
insert into public.nextrole_resume_files(id,library_id,user_id,version,display_name,file_name,object_path,byte_size,is_current)
values(current_setting('nr.f')::uuid,current_setting('nr.f')::uuid,current_setting('nr.c')::uuid,1,'CV','Original.pdf',current_setting('nr.c')||'/'||current_setting('nr.f')||'.pdf',100,false),
(current_setting('nr.f2')::uuid,current_setting('nr.f')::uuid,current_setting('nr.c')::uuid,2,'CV','Revised.pdf',current_setting('nr.c')||'/'||current_setting('nr.f2')||'.pdf',120,true);
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('nr.c'),'role','authenticated')::text,true);
select public.nextrole_action('resume_delete',jsonb_build_object('id',current_setting('nr.f2')));
do $$ begin
 if exists(select 1 from public.nextrole_resume_files where library_id=current_setting('nr.f')::uuid and (deleted_at is null or is_current)) then raise exception 'Deletion did not close all private versions'; end if;
end $$;
reset role;
rollback;
select 'PASS: confirmed private-file deletion tombstones every version in its family; no real objects or records changed. Storage-byte deletion is outside this database assertion.' as verification;
