-- Administrators manage staff details; disabling a staff account immediately removes
-- access to assigned tickets. Authentication remains managed by Supabase Auth.
create policy "admin manages staff" on public.staff for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create or replace function public.is_staff() returns boolean language sql stable security definer
set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p join public.staff s on s.id=p.id
               where p.id=auth.uid() and p.role='staff' and s.active)
$$;
create function public.is_student() returns boolean language sql stable security definer
set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='student')
$$;
drop policy if exists "complaints select scoped" on public.complaints;
create policy "complaints select scoped" on public.complaints for select to authenticated
using((public.is_student() and student_id=auth.uid()) or (public.is_staff() and assigned_staff_id=auth.uid()) or public.is_admin());
drop policy if exists "history scoped" on public.complaint_history;
create policy "history scoped" on public.complaint_history for select to authenticated
using(exists(select 1 from public.complaints c where c.id=complaint_id and
 ((public.is_student() and c.student_id=auth.uid()) or (public.is_staff() and c.assigned_staff_id=auth.uid()) or public.is_admin())));
drop policy if exists "authorized complaint updates" on public.complaints;
create policy "authorized complaint updates" on public.complaints for update to authenticated
using (public.is_admin() or (public.is_staff() and assigned_staff_id=auth.uid()) or (public.is_student() and student_id=auth.uid() and status='resolved'))
with check (public.is_admin() or (public.is_staff() and assigned_staff_id=auth.uid()) or (public.is_student() and student_id=auth.uid() and status='reopened'));

create or replace function public.complaint_image_owned_path(path text) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select public.is_student() and exists(select 1 from public.complaints c where c.student_id=auth.uid()
   and split_part(path,'/',1)=c.student_id::text and split_part(path,'/',2)=c.id::text
   and split_part(path,'/',3)<>'' and split_part(path,'/',4)='')
$$;
create or replace function public.complaint_image_accessible_path(path text) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.complaints c where split_part(path,'/',1)=c.student_id::text
   and split_part(path,'/',2)=c.id::text and split_part(path,'/',3)<>'' and split_part(path,'/',4)=''
   and ((public.is_student() and c.student_id=auth.uid()) or public.is_admin() or
     (c.assigned_staff_id=auth.uid() and public.is_staff())))
$$;

create function public.admin_dashboard_stats(started_at timestamptz default null) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 if not public.is_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 with selected as (select * from public.complaints where started_at is null or created_at >= started_at),
 resolution as (select c.id, extract(epoch from (min(h.created_at)-c.created_at))/3600 as hours
  from selected c join public.complaint_history h on h.complaint_id=c.id and h.new_status='resolved'
  group by c.id,c.created_at),
 categories as (select category,count(*)::integer as count from selected group by category),
 feedback as (select * from public.food_feedback where started_at is null or created_at>=started_at),
 ratings as (select rating,count(*)::integer as count from feedback group by rating),
 recent as (select ticket_number,title,status,updated_at from selected order by updated_at desc limit 8)
 select jsonb_build_object(
   'students',(select count(*) from public.profiles where role='student'),
   'total',(select count(*) from selected),
   'pending',(select count(*) from selected where status in ('submitted','acknowledged','reopened')),
   'in_progress',(select count(*) from selected where status='in_progress'),
   'resolved',(select count(*) from selected where status='resolved'),
   'average_resolution_hours',(select round(avg(hours)::numeric,1) from resolution),
   'average_rating',(select round(avg(rating)::numeric,1) from feedback),
   'feedback_count',(select count(*) from feedback),
   'categories',coalesce((select jsonb_agg(to_jsonb(categories) order by count desc,category) from categories),'[]'::jsonb),
   'ratings',coalesce((select jsonb_agg(to_jsonb(ratings) order by rating desc) from ratings),'[]'::jsonb),
   'recent',coalesce((select jsonb_agg(to_jsonb(recent) order by updated_at desc) from recent),'[]'::jsonb)
 ) into result;
 return result;
end $$;
revoke all on function public.admin_dashboard_stats(timestamptz) from public;
grant execute on function public.admin_dashboard_stats(timestamptz) to authenticated;

create function public.admin_staff_workload() returns table(id uuid,full_name text,department text,active boolean,open_count bigint,resolved_count bigint)
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not public.is_admin() then raise exception 'Not authorized' using errcode='42501'; end if;
 return query select p.id,p.full_name,s.department,s.active,
 count(c.id) filter(where c.status <> 'resolved'),count(c.id) filter(where c.status='resolved')
 from public.staff s join public.profiles p on p.id=s.id and p.role='staff'
 left join public.complaints c on c.assigned_staff_id=s.id
 group by p.id,p.full_name,s.department,s.active order by p.full_name;
end $$;
revoke all on function public.admin_staff_workload() from public;
grant execute on function public.admin_staff_workload() to authenticated;
