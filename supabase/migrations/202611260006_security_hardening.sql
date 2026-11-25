-- Keep identity and event timestamps server-controlled, even for direct API calls.
-- Defaults still populate these fields when a student submits feedback.
revoke insert on public.food_feedback from public, anon, authenticated;
grant insert (rating, category, comment) on public.food_feedback to authenticated;
revoke update on public.profiles from public, anon, authenticated;
grant update (full_name, room_number) on public.profiles to authenticated;
revoke update on public.notifications from public, anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

-- Client-side limits are not a substitute for database validation. NOT VALID
-- preserves existing rows while enforcing these checks on subsequent writes.
alter table public.profiles add constraint profiles_nonblank_name
  check (char_length(btrim(full_name)) between 2 and 120) not valid;
alter table public.profiles add constraint profiles_room_length
  check (room_number is null or char_length(room_number) <= 20) not valid;
