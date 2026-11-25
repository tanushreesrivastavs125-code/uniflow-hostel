-- Reject forged categories and non-student feedback even when the API is called directly.
alter table public.complaints add constraint complaint_category_valid
  check (category in ('electrical','plumbing','water_supply','wifi','cleaning','ac','furniture','food','security','other'));
alter table public.complaints add constraint complaint_room_valid
  check (char_length(trim(room_number)) between 1 and 20);
alter table public.food_feedback add constraint feedback_category_valid
  check (category in ('taste','quality','quantity','hygiene','variety','other'));
drop policy if exists "students add own feedback" on public.food_feedback;
create policy "students add own feedback" on public.food_feedback for insert to authenticated
  with check (student_id=auth.uid() and public.is_student());
