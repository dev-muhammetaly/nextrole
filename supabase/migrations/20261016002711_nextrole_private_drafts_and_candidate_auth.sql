create table public.nextrole_drafts (
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id text not null check (length(job_id) between 1 and 200),
  full_name text not null check (length(full_name) between 1 and 200),
  email text not null check (length(email) between 3 and 320),
  introduction text not null default '' check (length(introduction) <= 10000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, job_id)
);
alter table public.nextrole_drafts enable row level security;
revoke all on public.nextrole_drafts from public, anon, authenticated;
grant select, insert, update, delete on public.nextrole_drafts to authenticated;

create policy "Owners read drafts" on public.nextrole_drafts for select to authenticated
using ((select auth.uid()) = user_id and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true');
create policy "Owners create drafts" on public.nextrole_drafts for insert to authenticated
with check ((select auth.uid()) = user_id and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true');
create policy "Owners edit drafts" on public.nextrole_drafts for update to authenticated
using ((select auth.uid()) = user_id and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true')
with check ((select auth.uid()) = user_id and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true');
create policy "Owners delete drafts" on public.nextrole_drafts for delete to authenticated
using ((select auth.uid()) = user_id and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true');

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('nextrole-resumes', 'nextrole-resumes', false, 5242880, array['application/pdf']);
create policy "Nextrole owners read resumes" on storage.objects for select to authenticated
using (bucket_id = 'nextrole-resumes' and name = (select auth.uid())::text || '/resume.pdf'
and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true');
create policy "Nextrole owners upload resumes" on storage.objects for insert to authenticated
with check (bucket_id = 'nextrole-resumes' and name = (select auth.uid())::text || '/resume.pdf'
and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true');
create policy "Nextrole owners replace resumes" on storage.objects for update to authenticated
using (bucket_id = 'nextrole-resumes' and name = (select auth.uid())::text || '/resume.pdf'
and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true')
with check (bucket_id = 'nextrole-resumes' and name = (select auth.uid())::text || '/resume.pdf'
and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true');
create policy "Nextrole owners delete resumes" on storage.objects for delete to authenticated
using (bucket_id = 'nextrole-resumes' and name = (select auth.uid())::text || '/resume.pdf'
and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true');

-- Registration must not depend on, or authorize roles from, editable metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $function$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, left(new.raw_user_meta_data->>'full_name', 200), 'employee'::public.user_role);
  return new;
end;
$function$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
-- Role changes are administrative server operations, not profile edits.
revoke all on public.profiles from anon;
revoke insert, update, delete, truncate, references, trigger on public.profiles from authenticated;
grant update (full_name, company_name) on public.profiles to authenticated;
alter function public.is_admin() set search_path = '';
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated, service_role;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
