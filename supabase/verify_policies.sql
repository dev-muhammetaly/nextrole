-- Executed on the configured remote project and rolled back successfully.
-- Uses temporary synthetic users within a single transaction; sends no email.
begin;
select set_config('nextrole.test_a', gen_random_uuid()::text, true);
select set_config('nextrole.test_b', gen_random_uuid()::text, true);
insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
values
(current_setting('nextrole.test_a')::uuid, 'authenticated', 'authenticated', 'nextrole-a-' || current_setting('nextrole.test_a') || '@example.invalid', '{"provider":"email","providers":["email"]}', '{"full_name":"Policy test A","role":"admin"}'),
(current_setting('nextrole.test_b')::uuid, 'authenticated', 'authenticated', 'nextrole-b-' || current_setting('nextrole.test_b') || '@example.invalid', '{"provider":"email","providers":["email"]}', '{"full_name":"Policy test B"}');
do $test$ begin
  if exists(select 1 from public.profiles where id in (current_setting('nextrole.test_a')::uuid,current_setting('nextrole.test_b')::uuid) and role <> 'employee') then
    raise exception 'Signup assigned a metadata-controlled role';
  end if;
  if (select count(*) from public.profiles where id in (current_setting('nextrole.test_a')::uuid,current_setting('nextrole.test_b')::uuid)) <> 2 then
    raise exception 'Missing candidate profiles';
  end if;
end $test$;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', current_setting('nextrole.test_a'), 'role','authenticated','is_anonymous',false)::text, true);
insert into public.nextrole_drafts(user_id,job_id,full_name,email)
values(current_setting('nextrole.test_a')::uuid,'policy-test-a','Test A','test@example.invalid');
insert into storage.objects(bucket_id,name,metadata)
values('nextrole-resumes',current_setting('nextrole.test_a') || '/resume.pdf','{"mimetype":"application/pdf","size":100}');
do $test$ begin
  if (select count(*) from public.nextrole_drafts where job_id='policy-test-a') <> 1 then raise exception 'Owner cannot read draft'; end if;
  if (select count(*) from storage.objects where bucket_id='nextrole-resumes') <> 1 then raise exception 'Owner cannot read resume metadata'; end if;
  update public.nextrole_drafts set introduction='Updated' where job_id='policy-test-a';
  if not found then raise exception 'Owner cannot update draft'; end if;
  update storage.objects set metadata='{"mimetype":"application/pdf","size":200}' where bucket_id='nextrole-resumes';
  if not found then raise exception 'Owner cannot replace resume metadata'; end if;
  begin
    update public.nextrole_drafts set user_id=current_setting('nextrole.test_b')::uuid where job_id='policy-test-a';
    raise exception 'Draft ownership reassignment succeeded';
  exception when insufficient_privilege then null; end;
  begin
    update public.profiles set role='admin' where id=current_setting('nextrole.test_a')::uuid;
    raise exception 'Candidate role escalation succeeded';
  exception when insufficient_privilege then null; end;
end $test$;
select set_config('request.jwt.claims', json_build_object('sub', current_setting('nextrole.test_b'), 'role','authenticated','is_anonymous',false)::text, true);
do $test$ begin
  if exists(select 1 from public.nextrole_drafts where job_id='policy-test-a') then raise exception 'Other account can read draft'; end if;
  if exists(select 1 from storage.objects where bucket_id='nextrole-resumes') then raise exception 'Other account can read resume'; end if;
  update public.nextrole_drafts set introduction='Unauthorized' where job_id='policy-test-a';
  if found then raise exception 'Other account can update draft'; end if;
  delete from public.nextrole_drafts where job_id='policy-test-a';
  if found then raise exception 'Other account can delete draft'; end if;
  update storage.objects set metadata='{}' where bucket_id='nextrole-resumes';
  if found then raise exception 'Other account can replace resume'; end if;
  begin
    insert into public.nextrole_drafts(user_id,job_id,full_name,email)
    values(current_setting('nextrole.test_a')::uuid,'forged','Test','test@example.invalid');
    raise exception 'Other account can forge draft owner';
  exception when insufficient_privilege then null; end;
  begin
    insert into storage.objects(bucket_id,name) values('nextrole-resumes',current_setting('nextrole.test_a') || '/other.pdf');
    raise exception 'Other account can forge resume owner';
  exception when insufficient_privilege then null; end;
end $test$;
select set_config('request.jwt.claims', json_build_object('sub', current_setting('nextrole.test_a'), 'role','authenticated','is_anonymous',true)::text, true);
do $test$ begin
  if exists(select 1 from public.nextrole_drafts where job_id='policy-test-a') then raise exception 'Anonymous session can read draft'; end if;
  if exists(select 1 from storage.objects where bucket_id='nextrole-resumes') then raise exception 'Anonymous session can read resume'; end if;
  begin
    insert into public.nextrole_drafts(user_id,job_id,full_name,email)
    values(current_setting('nextrole.test_a')::uuid,'anonymous','Test','test@example.invalid');
    raise exception 'Anonymous session can create draft';
  exception when insufficient_privilege then null; end;
end $test$;
select set_config('request.jwt.claims', json_build_object('sub', current_setting('nextrole.test_a'), 'role','authenticated','is_anonymous',false)::text, true);
do $test$ begin
  delete from public.nextrole_drafts where job_id='policy-test-a';
  if not found then raise exception 'Owner cannot delete draft'; end if;
end $test$;
set local role anon;
do $test$ begin
  begin
    perform 1 from public.nextrole_drafts;
    raise exception 'Unauthenticated role can access drafts';
  exception when insufficient_privilege then null; end;
  if exists(select 1 from storage.objects where bucket_id='nextrole-resumes') then raise exception 'Unauthenticated role can read resume'; end if;
end $test$;
reset role;
rollback;
select 'PASS: signup defaults, draft ownership, resume metadata isolation, update checks, role protection, anonymous denial; all temporary rows rolled back' as verification;
