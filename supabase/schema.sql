
create extension if not exists pgcrypto;

create table public.relationship_spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Our shared space',
  invite_code text not null unique
    default upper(encode(gen_random_bytes(6), 'hex')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.space_members (
  space_id uuid not null references public.relationship_spaces(id)
    on delete cascade,
  user_id uuid not null references auth.users(id)
    on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.relationship_spaces(id)
    on delete cascade,
  user_id uuid not null references auth.users(id),
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index chat_messages_space_created_idx
on public.chat_messages(space_id, created_at);

create table public.paper_pages (
  space_id uuid primary key references public.relationship_spaces(id)
    on delete cascade,
  content text not null default '',
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table public.canvas_strokes (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.relationship_spaces(id)
    on delete cascade,
  user_id uuid not null references auth.users(id),
  stroke jsonb not null,
  created_at timestamptz not null default now()
);

create index canvas_strokes_space_created_idx
on public.canvas_strokes(space_id, created_at);

-- Membership checks run as a trusted database function.
-- This avoids recursive membership policies.
create or replace function public.is_space_member(p_space_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.space_members m
    where m.space_id = p_space_id
      and m.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_space_member(uuid) from public;
grant execute on function public.is_space_member(uuid)
to authenticated;

-- Create a private space and add its owner atomically.
create or replace function public.create_space()
returns table(space_id uuid, invite_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_code text;
begin
  if v_user is null then
    raise exception 'You must sign in first';
  end if;

  if exists (
    select 1 from public.space_members m
    where m.user_id = v_user
  ) then
    raise exception 'You already belong to a space';
  end if;

  insert into public.relationship_spaces(created_by)
  values (v_user)
  returning id, relationship_spaces.invite_code
  into v_space, v_code;

  insert into public.space_members(space_id, user_id)
  values (v_space, v_user);

  insert into public.paper_pages(space_id)
  values (v_space);

  return query select v_space, v_code;
end;
$$;

-- Join using a private invite code.
-- Each space allows at most two members.
create or replace function public.join_space(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_space uuid;
  v_count integer;
begin
  if v_user is null then
    raise exception 'You must sign in first';
  end if;

  if exists (
    select 1 from public.space_members m
    where m.user_id = v_user
  ) then
    raise exception 'You already belong to a space';
  end if;

  select s.id into v_space
  from public.relationship_spaces s
  where s.invite_code = upper(trim(p_code))
  for update;

  if v_space is null then
    raise exception 'Invalid invitation code';
  end if;

  select count(*) into v_count
  from public.space_members m
  where m.space_id = v_space;

  if v_count >= 2 then
    raise exception 'This space is already full';
  end if;

  insert into public.space_members(space_id, user_id)
  values (v_space, v_user);

  return v_space;
end;
$$;

revoke all on function public.create_space() from public;
revoke all on function public.join_space(text) from public;

grant execute on function public.create_space() to authenticated;
grant execute on function public.join_space(text) to authenticated;

alter table public.relationship_spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.paper_pages enable row level security;
alter table public.canvas_strokes enable row level security;

grant select on public.relationship_spaces to authenticated;
grant select on public.space_members to authenticated;

grant select, insert on public.chat_messages to authenticated;
grant select, insert, update on public.paper_pages to authenticated;
grant select, insert on public.canvas_strokes to authenticated;

create policy "Members read their spaces"
on public.relationship_spaces for select
to authenticated
using (public.is_space_member(id));

create policy "Users read own membership"
on public.space_members for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Members read chat"
on public.chat_messages for select
to authenticated
using (public.is_space_member(space_id));

create policy "Members send chat"
on public.chat_messages for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and public.is_space_member(space_id)
);

create policy "Members read paper"
on public.paper_pages for select
to authenticated
using (public.is_space_member(space_id));

create policy "Members insert paper"
on public.paper_pages for insert
to authenticated
with check (public.is_space_member(space_id));

create policy "Members update paper"
on public.paper_pages for update
to authenticated
using (public.is_space_member(space_id))
with check (public.is_space_member(space_id));

create policy "Members read strokes"
on public.canvas_strokes for select
to authenticated
using (public.is_space_member(space_id));

create policy "Members insert strokes"
on public.canvas_strokes for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and public.is_space_member(space_id)
);

-- Enable database change events for the shared content.
alter publication supabase_realtime
add table public.chat_messages;

alter publication supabase_realtime
add table public.paper_pages;

alter publication supabase_realtime
add table public.canvas_strokes;

