-- Permit users to update only non-privileged profile fields.
create policy "profile owner updates" on public.profiles for update to authenticated
using (id=auth.uid()) with check (id=auth.uid());
revoke update on public.profiles from authenticated;
grant update(full_name,room_number) on public.profiles to authenticated;
