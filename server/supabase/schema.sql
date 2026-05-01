-- gongju Supabase schema
-- Apply to a fresh Supabase project via SQL editor.
-- Order: extensions -> tables -> indexes -> RLS policies -> views -> seed.

------------------------------------------------------------------
-- Extensions
------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

------------------------------------------------------------------
-- profiles: link Supabase auth.users to a role
------------------------------------------------------------------
create table if not exists public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null default 'user' check (role in ('user','admin')),
  display_name text,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin() returns boolean
language sql stable as $$
  select exists(
    select 1 from public.profiles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

------------------------------------------------------------------
-- creators: influencers / partners
------------------------------------------------------------------
create table if not exists public.creators (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  platform    text not null,            -- youtube|twitter|instagram|tiktok|blog|...
  contact     text,
  notes       text,
  short_code_prefix text,                -- e.g. KO-YT
  disabled    boolean not null default false,
  created_at  timestamptz not null default now()
);

------------------------------------------------------------------
-- utm_links: each row is one short code -> full UTM destination
------------------------------------------------------------------
create table if not exists public.utm_links (
  id          uuid primary key default uuid_generate_v4(),
  short_code  text not null unique,      -- e.g. KO-YT-001
  source      text not null,
  medium      text not null,
  campaign    text not null,
  content     text,
  term        text,
  path        text not null default '/',
  creator_id  uuid references public.creators(id) on delete set null,
  disabled    boolean not null default false,
  created_by  uuid references auth.users(id),
  created_at  timestamptz not null default now()
);
create index if not exists idx_utm_links_creator on public.utm_links(creator_id);

------------------------------------------------------------------
-- visits: every landing page hit
------------------------------------------------------------------
create table if not exists public.visits (
  id           bigserial primary key,
  session_id   uuid not null,
  user_id      uuid,
  utm_source   text,
  utm_medium   text,
  utm_campaign text,
  utm_content  text,
  utm_term     text,
  ref_code     text,
  path         text,
  referrer     text,
  ua           text,
  lang         text,
  country      text,
  created_at   timestamptz not null default now()
);
create index if not exists idx_visits_created on public.visits(created_at desc);
create index if not exists idx_visits_ref on public.visits(ref_code);
create index if not exists idx_visits_session on public.visits(session_id);

------------------------------------------------------------------
-- downloads: download button clicks
------------------------------------------------------------------
create table if not exists public.downloads (
  id          bigserial primary key,
  session_id  uuid not null,
  user_id     uuid,
  os          text not null check (os in ('windows','macos','linux','android','ios','web')),
  lang        text,
  ref_code    text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_downloads_created on public.downloads(created_at desc);
create index if not exists idx_downloads_ref on public.downloads(ref_code);

------------------------------------------------------------------
-- events: in-game telemetry (batched from client)
------------------------------------------------------------------
create table if not exists public.events (
  id         bigserial primary key,
  user_id    uuid not null,
  type       text not null,
  payload    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_events_user on public.events(user_id);
create index if not exists idx_events_type_created on public.events(type, created_at desc);

------------------------------------------------------------------
-- game_config: remote balance (key/value JSON, versioned)
------------------------------------------------------------------
create table if not exists public.game_config (
  key        text primary key,
  value      jsonb not null,
  version    integer not null default 1,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.config_history (
  id         bigserial primary key,
  key        text not null,
  value      jsonb not null,
  version    integer not null,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create or replace function public.tg_config_history()
returns trigger language plpgsql as $$
begin
  insert into public.config_history(key, value, version, updated_by, updated_at)
  values (new.key, new.value, new.version, new.updated_by, new.updated_at);
  return new;
end $$;

drop trigger if exists trg_config_history on public.game_config;
create trigger trg_config_history
after insert or update on public.game_config
for each row execute function public.tg_config_history();

------------------------------------------------------------------
-- announcements: in-game / landing toasts
------------------------------------------------------------------
create table if not exists public.announcements (
  id          uuid primary key default uuid_generate_v4(),
  title_i18n  jsonb not null,            -- { "ko": "...", "en": "...", ... }
  body_i18n   jsonb not null,
  audience    jsonb not null default '{}'::jsonb, -- {lang:[], os:[], utm_source:[]}
  starts_at   timestamptz not null default now(),
  ends_at     timestamptz,
  location    text not null default 'in_game' check (location in ('in_game','main_menu','landing')),
  created_by  uuid references auth.users(id),
  created_at  timestamptz not null default now()
);
create index if not exists idx_announcements_active on public.announcements(starts_at, ends_at);

------------------------------------------------------------------
-- feedback: in-game bug/idea submissions
------------------------------------------------------------------
create table if not exists public.feedback (
  id             bigserial primary key,
  user_id        uuid not null,
  category       text not null check (category in ('bug','idea','question','other')),
  body           text not null,
  screenshot_url text,
  status         text not null default 'new' check (status in ('new','in_progress','done','wont_fix')),
  reply          text,
  created_at     timestamptz not null default now(),
  replied_at     timestamptz
);
create index if not exists idx_feedback_status on public.feedback(status, created_at desc);

------------------------------------------------------------------
-- newsletter
------------------------------------------------------------------
create table if not exists public.newsletter (
  email       text primary key,
  lang        text,
  ref_code    text,
  utm_source  text,
  created_at  timestamptz not null default now()
);

------------------------------------------------------------------
-- Row Level Security
------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.creators      enable row level security;
alter table public.utm_links     enable row level security;
alter table public.visits        enable row level security;
alter table public.downloads     enable row level security;
alter table public.events        enable row level security;
alter table public.game_config   enable row level security;
alter table public.config_history enable row level security;
alter table public.announcements enable row level security;
alter table public.feedback      enable row level security;
alter table public.newsletter    enable row level security;

-- profiles: user reads own, admin reads all
create policy "profiles self read"
  on public.profiles for select
  using (auth.uid() = user_id or public.is_admin());

create policy "profiles admin all"
  on public.profiles for all
  using (public.is_admin()) with check (public.is_admin());

-- creators: anon may not access; admin full
create policy "creators admin"
  on public.creators for all
  using (public.is_admin()) with check (public.is_admin());

-- utm_links: anon read enabled rows; admin full
create policy "utm_links public read"
  on public.utm_links for select
  using (disabled = false);

create policy "utm_links admin write"
  on public.utm_links for all
  using (public.is_admin()) with check (public.is_admin());

-- visits: anyone may insert; only admin selects
create policy "visits anon insert"
  on public.visits for insert
  with check (true);

create policy "visits admin select"
  on public.visits for select
  using (public.is_admin());

-- downloads: anyone may insert; only admin selects
create policy "downloads anon insert"
  on public.downloads for insert
  with check (true);

create policy "downloads admin select"
  on public.downloads for select
  using (public.is_admin());

-- events: authenticated users insert their own; admin selects
create policy "events self insert"
  on public.events for insert
  with check (auth.uid() = user_id);

create policy "events admin select"
  on public.events for select
  using (public.is_admin());

-- game_config: everyone reads; admin writes
create policy "game_config public read"
  on public.game_config for select
  using (true);

create policy "game_config admin write"
  on public.game_config for all
  using (public.is_admin()) with check (public.is_admin());

-- config_history: admin only
create policy "config_history admin"
  on public.config_history for all
  using (public.is_admin()) with check (public.is_admin());

-- announcements: public reads only currently-active rows; admin all
create policy "announcements public read"
  on public.announcements for select
  using (
    starts_at <= now()
    and (ends_at is null or ends_at >= now())
  );

create policy "announcements admin"
  on public.announcements for all
  using (public.is_admin()) with check (public.is_admin());

-- feedback: user inserts own, reads own; admin all
create policy "feedback self insert"
  on public.feedback for insert
  with check (auth.uid() = user_id);

create policy "feedback self select"
  on public.feedback for select
  using (auth.uid() = user_id or public.is_admin());

create policy "feedback admin write"
  on public.feedback for update
  using (public.is_admin()) with check (public.is_admin());

-- newsletter: public inserts; admin reads
create policy "newsletter anon insert"
  on public.newsletter for insert
  with check (true);

create policy "newsletter admin select"
  on public.newsletter for select
  using (public.is_admin());

------------------------------------------------------------------
-- Helpful views (admin only, via RLS on underlying tables)
------------------------------------------------------------------
create or replace view public.v_utm_funnel as
select
  v.utm_source,
  v.utm_medium,
  v.utm_campaign,
  v.utm_content,
  count(distinct v.session_id) as visits,
  count(distinct d.session_id) as downloads,
  case when count(distinct v.session_id) > 0
       then round(100.0 * count(distinct d.session_id) / count(distinct v.session_id), 2)
       else 0 end as conversion_pct
from public.visits v
left join public.downloads d on d.session_id = v.session_id
group by 1,2,3,4;

create or replace view public.v_creator_stats as
select
  c.id, c.name, c.platform, c.short_code_prefix,
  count(distinct vi.session_id) as visits,
  count(distinct dl.session_id) as downloads
from public.creators c
left join public.utm_links ul on ul.creator_id = c.id
left join public.visits vi on vi.ref_code = ul.short_code
left join public.downloads dl on dl.ref_code = ul.short_code
group by c.id;

------------------------------------------------------------------
-- Seed: initial balance config
------------------------------------------------------------------
insert into public.game_config (key, value, version)
values
  ('faith_regen_per_sec',      '0.2'::jsonb, 1),
  ('max_faith_base',           '100'::jsonb, 1),
  ('max_faith_per_level',      '50'::jsonb,  1),
  ('fear_decay_per_sec',       '0.1'::jsonb, 1),
  ('day_length_sec',           '600'::jsonb, 1),
  ('npc_birth_rate',           '0.001'::jsonb, 1),
  ('npc_death_rate_base',      '0.0005'::jsonb, 1),
  ('save_autosave_interval_sec','60'::jsonb, 1)
on conflict (key) do nothing;
