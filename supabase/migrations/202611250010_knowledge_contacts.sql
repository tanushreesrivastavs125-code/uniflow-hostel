-- Official documents remain private; only administrators can upload them.
alter table public.knowledge_articles add column document_path text unique;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('hostel-documents','hostel-documents',false,10485760,array['application/pdf'])
on conflict (id) do update set public=false,file_size_limit=10485760,allowed_mime_types=array['application/pdf'];
create policy "admins upload hostel documents" on storage.objects for insert to authenticated
  with check(bucket_id='hostel-documents' and public.is_admin());
create policy "admins delete hostel documents" on storage.objects for delete to authenticated
  using(bucket_id='hostel-documents' and public.is_admin());
create policy "published hostel documents readable" on storage.objects for select to authenticated
  using(bucket_id='hostel-documents' and (public.is_admin() or exists
    (select 1 from public.knowledge_articles k where k.document_path=name and k.verified and k.published)));

create table public.hostel_contacts(
  id uuid primary key default gen_random_uuid(),
  title text not null check(char_length(title) between 2 and 120),
  department text not null check(char_length(department) between 2 and 120),
  phone text not null check(char_length(phone) between 3 and 40),
  details text not null default '' check(char_length(details)<=1000),
  verified boolean not null default false,
  published boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.hostel_contacts enable row level security;
create policy "verified contacts readable" on public.hostel_contacts for select to authenticated
  using((verified and published) or public.is_admin());
create policy "admins manage contacts" on public.hostel_contacts for all to authenticated
  using(public.is_admin()) with check(public.is_admin());
