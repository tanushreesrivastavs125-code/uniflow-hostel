-- Complaint image objects are private; access follows the parent ticket.
alter table public.complaints add constraint valid_complaint_category
 check(category in ('electrical','plumbing','water_supply','wifi','cleaning','ac','furniture','food','security','other')) not valid;
alter table public.complaints add constraint valid_complaint_room
 check(char_length(trim(room_number)) between 1 and 20) not valid;
alter table public.complaints add constraint valid_complaint_note
 check(resolution_notes is null or char_length(resolution_notes)<=2000) not valid;
update storage.buckets set public=false, file_size_limit=5242880,
 allowed_mime_types=array['image/jpeg','image/png','image/webp'] where id='complaint-images';
drop policy if exists "own complaint images upload" on storage.objects;
drop policy if exists "scoped complaint images read" on storage.objects;
create function public.complaint_image_owned_path(path text) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.complaints c where c.student_id=auth.uid()
   and split_part(path,'/',1)=c.student_id::text and split_part(path,'/',2)=c.id::text
   and split_part(path,'/',3)<>'' and split_part(path,'/',4)='')
$$;
create function public.complaint_image_accessible_path(path text) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.complaints c where split_part(path,'/',1)=c.student_id::text
   and split_part(path,'/',2)=c.id::text and split_part(path,'/',3)<>'' and split_part(path,'/',4)=''
   and (c.student_id=auth.uid() or public.is_admin() or
     (c.assigned_staff_id=auth.uid() and public.is_staff() and
      exists(select 1 from public.staff s where s.id=auth.uid() and s.active))))
$$;
create policy "complaint owners upload images" on storage.objects for insert to authenticated
 with check(bucket_id='complaint-images' and public.complaint_image_owned_path(name));
create policy "ticket participants view images" on storage.objects for select to authenticated
 using(bucket_id='complaint-images' and public.complaint_image_accessible_path(name));
create policy "complaint owners remove images" on storage.objects for delete to authenticated
 using(bucket_id='complaint-images' and public.complaint_image_owned_path(name));
create policy "ticket participants view image records" on public.complaint_images for select to authenticated
 using(public.complaint_image_accessible_path(storage_path));
create policy "complaint owners add image records" on public.complaint_images for insert to authenticated
 with check(public.complaint_image_owned_path(storage_path) and exists(select 1 from public.complaints c where c.id=complaint_id and c.student_id=auth.uid() and split_part(storage_path,'/',2)=c.id::text));
