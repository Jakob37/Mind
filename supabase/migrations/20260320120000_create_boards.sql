create table public.boards (
  user_id uuid primary key references auth.users(id) on delete cascade,
  board jsonb not null,
  schema_version integer not null,
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.set_boards_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create trigger boards_set_updated_at
before update on public.boards
for each row execute function public.set_boards_updated_at();

alter table public.boards enable row level security;

create policy "users can read own board"
on public.boards
for select
to authenticated
using (auth.uid() = user_id);

create policy "users can insert own board"
on public.boards
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "users can update own board"
on public.boards
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
