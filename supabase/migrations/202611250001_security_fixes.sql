-- Correct ticket defaults and enforce mutation permissions independently of the UI.
alter table public.complaints alter column student_id set default auth.uid();
drop trigger if exists complaint_history_trigger on public.complaints;
drop function if exists public.log_complaint_update();

create function public.validate_complaint_change() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare actor uuid := auth.uid(); actor_role public.app_role;
begin
  if actor is null then
    raise exception 'Authentication is required';
  end if;
  select role into actor_role from public.profiles where id=actor;
  if tg_op='INSERT' then
    if actor_role is distinct from 'student'::public.app_role or new.student_id is distinct from actor
       or new.status <> 'submitted' or new.assigned_staff_id is not null or new.resolution_notes is not null then
      raise exception 'Invalid student complaint';
    end if;
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
    new.updated_at := now();
  end if;
  if new.assigned_staff_id is not null and not exists (
    select 1 from public.profiles p join public.staff s on s.id=p.id
    where p.id=new.assigned_staff_id and p.role='staff' and s.active
  ) then raise exception 'Assigned staff member must be active'; end if;
  return new;
end; $$;
create trigger validate_complaint before insert or update on public.complaints
for each row execute function public.validate_complaint_change();

-- AFTER INSERT is required: complaint_history references the newly inserted row.
create function public.record_complaint_change() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op='INSERT' then
    insert into public.complaint_history(complaint_id,actor_id,new_status,note)
      values(new.id,auth.uid(),new.status,'Complaint submitted');
    insert into public.notifications(recipient_id,title,body,link)
      values(new.student_id,'Complaint submitted','Your ticket '||new.ticket_number||' was created.','/complaints');
  elsif new.status is distinct from old.status or new.resolution_notes is distinct from old.resolution_notes
     or new.assigned_staff_id is distinct from old.assigned_staff_id then
    insert into public.complaint_history(complaint_id,actor_id,old_status,new_status,note)
      values(new.id,auth.uid(),old.status,new.status,new.resolution_notes);
    insert into public.notifications(recipient_id,title,body,link)
      values(new.student_id,'Complaint updated','Your ticket '||new.ticket_number||' is now '||replace(new.status::text,'_',' ')||'.','/complaints');
    if new.assigned_staff_id is distinct from old.assigned_staff_id and new.assigned_staff_id is not null then
      insert into public.notifications(recipient_id,title,body,link)
        values(new.assigned_staff_id,'Complaint assigned','Ticket '||new.ticket_number||' has been assigned to you.','/complaints');
    end if;
  end if;
  return null;
end; $$;
create trigger record_complaint after insert or update on public.complaints
for each row execute function public.record_complaint_change();

drop policy if exists "staff admin update scoped" on public.complaints;
create policy "authorized complaint updates" on public.complaints for update to authenticated
using (public.is_admin() or (public.is_staff() and assigned_staff_id=auth.uid()) or (student_id=auth.uid() and status='resolved'))
with check (public.is_admin() or (public.is_staff() and assigned_staff_id=auth.uid()) or (student_id=auth.uid() and status='reopened'));

-- Notifications may only be marked read by their recipient.
create policy "own notifications update" on public.notifications for update to authenticated
using (recipient_id=auth.uid()) with check (recipient_id=auth.uid());
revoke update on public.notifications from authenticated;
grant update(read_at) on public.notifications to authenticated;

-- Only the Edge Function's server credential writes conversation entries.
-- Users can read their own history but cannot forge assistant messages.
