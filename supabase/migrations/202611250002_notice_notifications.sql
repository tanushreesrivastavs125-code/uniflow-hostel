-- Notify students of important notices published immediately. Scheduled notices need a worker.
create function public.notify_important_notice() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if new.priority in ('important','urgent') and new.published_at <= now()
     and (new.expires_at is null or new.expires_at > now()) then
    insert into public.notifications(recipient_id,title,body,link)
      select id,'Important hostel notice',new.title,'/notices'
      from public.profiles where role='student';
  end if;
  return new;
end; $$;
create trigger notify_new_important_notice after insert on public.notices
for each row execute function public.notify_important_notice();
