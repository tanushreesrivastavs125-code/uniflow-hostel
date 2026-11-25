-- Reserve an AI request before paying for it. The lock serializes concurrent requests
-- from the same account, including requests that fail before a conversation is saved.
create table public.ai_request_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp()
);
create index ai_request_attempts_user_time on public.ai_request_attempts(user_id,created_at);
alter table public.ai_request_attempts enable row level security;
revoke all on public.ai_request_attempts from public, anon, authenticated;
create function public.reserve_ai_request() returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
declare requesting_user uuid := auth.uid();
begin
  if requesting_user is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(requesting_user::text,0));
  delete from public.ai_request_attempts where user_id=requesting_user and created_at<clock_timestamp()-interval '1 hour';
  if (select count(*) from public.ai_request_attempts where user_id=requesting_user and created_at>clock_timestamp()-interval '1 minute') >= 10 then
    return false;
  end if;
  insert into public.ai_request_attempts(user_id) values(requesting_user);
  return true;
end; $$;
revoke all on function public.reserve_ai_request() from public,anon;
grant execute on function public.reserve_ai_request() to authenticated;
