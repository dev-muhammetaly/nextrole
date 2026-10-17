create function nextrole_private.company_logo_access(path text, editing boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.nextrole_companies c where path=c.id::text||'/logo.png' and
 ((not editing and nextrole_private.company_visible(c.id))
 or (nextrole_private.active() and c.owner_id=auth.uid())
 or (not editing and nextrole_private.role()='admin')))
$$;
revoke all on function nextrole_private.company_logo_access(text,boolean) from public;
grant execute on function nextrole_private.company_logo_access(text,boolean) to anon,authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('nextrole-company-logos','nextrole-company-logos',false,2097152,array['image/png']);
create policy nr_logo_read on storage.objects for select to anon,authenticated
using(bucket_id='nextrole-company-logos' and nextrole_private.company_logo_access(name,false));
create policy nr_logo_insert on storage.objects for insert to authenticated
with check(bucket_id='nextrole-company-logos' and nextrole_private.company_logo_access(name,true));
create policy nr_logo_update on storage.objects for update to authenticated
using(bucket_id='nextrole-company-logos' and nextrole_private.company_logo_access(name,true))
with check(bucket_id='nextrole-company-logos' and nextrole_private.company_logo_access(name,true));
create policy nr_logo_delete on storage.objects for delete to authenticated
using(bucket_id='nextrole-company-logos' and nextrole_private.company_logo_access(name,true));
alter table public.nextrole_settings add constraint nr_valid_categories check(cardinality(categories) between 1 and 50 and array_position(categories,'') is null and array_position(categories,null) is null),
 add constraint nr_valid_locations check(cardinality(locations) between 1 and 100 and array_position(locations,'') is null and array_position(locations,null) is null);
