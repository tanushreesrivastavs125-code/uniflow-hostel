-- Generate ticket identifiers on the server, and allow a student to reopen a
-- resolved ticket even if the previously assigned staff member is now inactive.
create or replace function public.validate_complaint_change() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare actor uuid := auth.uid(); actor_role public.app_role;
begin
  if actor is null then raise exception 'Authentication is required'; end if;
  select role into actor_role from public.profiles where id=actor;
  if tg_op='INSERT' then
    if actor_role is distinct from 'student'::public.app_role or new.student_id is distinct from actor
       or new.status <> 'submitted' or new.assigned_staff_id is not null or new.resolution_notes is not null then
      raise exception 'Invalid student complaint';
    end if;
    new.id := gen_random_uuid();
    new.ticket_number := 'UF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    new.created_at := now(); new.updated_at := now();
  else
    if new.id is distinct from old.id or new.ticket_number is distinct from old.ticket_number
       or new.student_id is distinct from old.student_id or new.created_at is distinct from old.created_at then
      raise exception 'Complaint identity cannot be changed';
    end if;
    if actor_role='staff' and old.assigned_staff_id=actor then
      if new.assigned_staff_id is distinct from old.assigned_staff_id or new.title is distinct from old.title
         or new.description is distinct from old.description or new.category is distinct from old.category
         or new.room_number is distinct from old.room_number or new.priority is distinct from old.priority then
        raise exception 'Staff may only update status and work notes';
      end if;
    elsif actor_role='student' and old.student_id=actor then
      if old.status <> 'resolved' or new.status <> 'reopened'
         or new.assigned_staff_id is distinct from old.assigned_staff_id or new.title is distinct from old.title
         or new.description is distinct from old.description or new.category is distinct from old.category
         or new.room_number is distinct from old.room_number or new.priority is distinct from old.priority
         or new.resolution_notes is distinct from old.resolution_notes then
        raise exception 'Students may only reopen their resolved complaints';
      end if;
    elsif actor_role is distinct from 'admin'::public.app_role then
      raise exception 'Not authorized to update this complaint';
    end if;
    if new.assigned_staff_id is distinct from old.assigned_staff_id and new.assigned_staff_id is not null and not exists (
      select 1 from public.profiles p join public.staff s on s.id=p.id
      where p.id=new.assigned_staff_id and p.role='staff' and s.active
    ) then raise exception 'Assigned staff member must be active'; end if;
    new.updated_at := now();
  end if;
  return new;
end; $$;
