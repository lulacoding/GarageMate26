-- GarageMate initial schema
-- Source: garagemate-technical-architecture.md §3 (data model), §5 (query patterns),
-- §6 (auth flow trigger), §7 (RLS)

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists postgis;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- Users are managed by Supabase Auth (auth.users). Extend with a profile table.
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now()
);

create table listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  description text not null,
  address text not null,
  location geography(Point, 4326) not null,
  date_start date not null,
  time_start time not null,
  time_end time not null,
  date_end date,               -- optional second day
  time_start_2 time,
  time_end_2 time,
  -- Computed client-side at creation: whichever is later of (date_end, time_end_2)
  -- if a second day exists, else (date_start, time_end). Device-local time at creation.
  -- Drives both "is this still active" queries and the auto-delete sweep.
  end_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index listings_location_idx on listings using gist (location);
create index listings_end_at_idx on listings (end_at);

create table listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  storage_path text not null,
  position smallint not null check (position between 0 and 2)
);

create table saved_listings (
  user_id uuid not null references profiles(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

-- Note: there's no `is_active` boolean. "Active" is simply `end_at >= now()`, and
-- expired rows are physically deleted by the cleanup job rather than flagged.

-- ---------------------------------------------------------------------------
-- Auth trigger: populate profiles on signup (technical-architecture.md §6)
--
-- Email/password signup collects first_name/last_name (from the Register form,
-- passed through as auth.users raw_user_meta_data). Google OAuth populates
-- full_name/name instead. Not written out as SQL in the doc's prose — filled in
-- here to cover both signup paths.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
begin
  v_display_name := coalesce(
    nullif(trim(concat_ws(' ',
      new.raw_user_meta_data ->> 'first_name',
      new.raw_user_meta_data ->> 'last_name'
    )), ''),
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name',
    split_part(new.email, '@', 1)
  );

  insert into public.profiles (id, display_name)
  values (new.id, v_display_name);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row-Level Security (technical-architecture.md §7)
-- ---------------------------------------------------------------------------
alter table listings enable row level security;
alter table saved_listings enable row level security;

-- Anyone can read non-expired listings; owners can also see their own (covers the brief
-- window between expiry and the next hourly cleanup run)
create policy "public read active listings" on listings
  for select using (end_at >= now() or owner_id = auth.uid());

-- Only owner can insert/update/delete their own listings
create policy "owner writes own listings" on listings
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Users manage only their own saved listings
create policy "user manages own saves" on saved_listings
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- The doc's §7 RLS section only covers listings/saved_listings. profiles and
-- listing_images have no policies at all in the doc, which (once RLS is enabled
-- project-wide) would leave them either wide open or wide closed by omission.
-- Added here to close that gap, following the same "owner writes own" shape.

alter table profiles enable row level security;

create policy "user reads own profile" on profiles
  for select using (id = auth.uid());

create policy "user updates own profile" on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- No insert policy: rows are created by the on_auth_user_created trigger, which
-- runs as security definer and bypasses RLS.

alter table listing_images enable row level security;

create policy "public read images of visible listings" on listing_images
  for select using (
    exists (
      select 1 from listings l
      where l.id = listing_images.listing_id
        and (l.end_at >= now() or l.owner_id = auth.uid())
    )
  );

create policy "owner writes own listing images" on listing_images
  for all using (
    exists (
      select 1 from listings l
      where l.id = listing_images.listing_id and l.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from listings l
      where l.id = listing_images.listing_id and l.owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- RPCs (technical-architecture.md §5)
--
-- The doc gives these as raw SQL/query shapes, not callable functions. Wrapped
-- as RPCs here since that's the only way the client (supabase-js) can run
-- PostGIS geography operators server-side.
-- ---------------------------------------------------------------------------

-- §5.1 / §5.2 — radius search, shared by GPS search and suburb-search fallback.
create or replace function public.nearby_listings(
  lat double precision,
  lng double precision,
  radius_m double precision,
  date_from date default null,
  date_to date default null
)
returns table (
  id uuid,
  title text,
  description text,
  address text,
  date_start date,
  time_start time,
  time_end time,
  date_end date,
  time_start_2 time,
  time_end_2 time,
  end_at timestamptz,
  lat double precision,
  lng double precision,
  distance_m double precision
)
language sql
stable
as $$
  select
    l.id, l.title, l.description, l.address,
    l.date_start, l.time_start, l.time_end,
    l.date_end, l.time_start_2, l.time_end_2,
    l.end_at,
    st_y(l.location::geometry) as lat,
    st_x(l.location::geometry) as lng,
    st_distance(l.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography) as distance_m
  from listings l
  where l.end_at >= now()
    and st_dwithin(l.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography, radius_m)
    and (date_from is null or l.date_start >= date_from)
    and (date_to is null or l.date_start <= date_to)
  order by distance_m asc;
$$;

grant execute on function public.nearby_listings(double precision, double precision, double precision, date, date)
  to anon, authenticated;

-- §5.3 — map viewport load/unload.
create or replace function public.listings_in_view(
  min_lng double precision,
  min_lat double precision,
  max_lng double precision,
  max_lat double precision
)
returns table (
  id uuid,
  title text,
  lat double precision,
  lng double precision
)
language sql
stable
as $$
  select
    l.id,
    l.title,
    st_y(l.location::geometry) as lat,
    st_x(l.location::geometry) as lng
  from listings l
  where l.end_at >= now()
    and l.location && st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography;
$$;

grant execute on function public.listings_in_view(double precision, double precision, double precision, double precision)
  to anon, authenticated;
