-- RAHOSETU initial schema foundation
-- Review before running. This migration creates core tables and baseline RLS.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  category_group text not null check (category_group in ('accommodation','food')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  phone text,
  whatsapp text,
  address text,
  area text,
  city text not null default 'Deoghar',
  state text not null default 'Jharkhand',
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_confirmed_at timestamptz
);

create table if not exists public.business_categories (
  business_id uuid not null references public.businesses(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  primary key (business_id, category_id)
);

create table if not exists public.listings (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  price_min numeric(10,2),
  price_max numeric(10,2),
  price_note text,
  facilities text[] not null default '{}',
  availability_status text not null default 'unknown'
    check (availability_status in ('available','unavailable','limited','unknown')),
  updated_at timestamptz not null default now(),
  check (price_min is null or price_min >= 0),
  check (price_max is null or price_max >= 0),
  check (price_min is null or price_max is null or price_max >= price_min)
);

create table if not exists public.listing_images (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  image_path text not null,
  alt_text text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.business_submissions (
  id uuid primary key default gen_random_uuid(),
  submitted_data jsonb not null,
  submitter_name text,
  submitter_contact text,
  consent_to_publish boolean not null default false,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_name text not null,
  customer_phone text not null,
  message text,
  status text not null default 'new'
    check (status in ('new','contacted','closed','spam')),
  created_at timestamptz not null default now()
);

create table if not exists public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_name text not null,
  customer_phone text not null,
  requested_date date,
  details text,
  status text not null default 'pending'
    check (status in ('pending','contacted','accepted','declined','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  duration_days integer,
  price_paise integer not null default 0 check (price_paise >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  plan_id uuid not null references public.plans(id),
  starts_at timestamptz not null,
  expires_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending','active','expired','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.website_orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete set null,
  contact_name text not null,
  contact_phone text not null,
  package_name text not null check (package_name in ('starter_presence','booking_starter','custom')),
  requirements text,
  status text not null default 'new'
    check (status in ('new','reviewing','in_progress','delivered','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.admin_activity_logs (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id),
  action text not null,
  target_type text,
  target_id text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- Helper: check active admin membership. SECURITY DEFINER avoids recursive RLS
-- on admin_memberships; search_path is fixed for safety.
create or replace function public.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_memberships m
    where m.user_id = (select auth.uid())
      and m.is_active = true
  );
$$;

create or replace function public.is_active_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_memberships m
    where m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = 'owner'
  );
$$;

-- Enable RLS on every exposed table.
alter table public.profiles enable row level security;
alter table public.admin_memberships enable row level security;
alter table public.categories enable row level security;
alter table public.businesses enable row level security;
alter table public.business_categories enable row level security;
alter table public.listings enable row level security;
alter table public.listing_images enable row level security;
alter table public.business_submissions enable row level security;
alter table public.enquiries enable row level security;
alter table public.booking_requests enable row level security;
alter table public.plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.website_orders enable row level security;
alter table public.admin_activity_logs enable row level security;

-- Public read: active categories and approved business information only.
create policy "Public can read active categories"
on public.categories for select
to anon, authenticated
using (is_active = true);

create policy "Public can read approved businesses"
on public.businesses for select
to anon, authenticated
using (status = 'approved');

create policy "Admins can manage businesses"
on public.businesses for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

create policy "Public can read categories linked to approved businesses"
on public.business_categories for select
to anon, authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = business_id and b.status = 'approved'
  )
);

create policy "Admins can manage business categories"
on public.business_categories for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

create policy "Public can read listing details for approved businesses"
on public.listings for select
to anon, authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = business_id and b.status = 'approved'
  )
);

create policy "Admins can manage listings"
on public.listings for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

create policy "Public can read images for approved businesses"
on public.listing_images for select
to anon, authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = business_id and b.status = 'approved'
  )
);

create policy "Admins can manage listing images"
on public.listing_images for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- Public forms: insert only. No public select/update/delete policies.
create policy "Public can submit business applications"
on public.business_submissions for insert
to anon, authenticated
with check (consent_to_publish = true);

create policy "Admins can manage business submissions"
on public.business_submissions for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

create policy "Public can submit enquiries"
on public.enquiries for insert
to anon, authenticated
with check (
  exists (
    select 1 from public.businesses b
    where b.id = business_id and b.status = 'approved'
  )
);

create policy "Admins can manage enquiries"
on public.enquiries for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

create policy "Public can submit booking requests"
on public.booking_requests for insert
to anon, authenticated
with check (
  exists (
    select 1 from public.businesses b
    where b.id = business_id and b.status = 'approved'
  )
);

create policy "Admins can manage booking requests"
on public.booking_requests for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

create policy "Public can read active plans"
on public.plans for select
to anon, authenticated
using (is_active = true);

create policy "Owners can manage plans"
on public.plans for all
to authenticated
using (public.is_active_owner())
with check (public.is_active_owner());

create policy "Admins can read subscriptions"
on public.subscriptions for select
to authenticated
using (public.is_active_admin());

create policy "Owners can manage subscriptions"
on public.subscriptions for all
to authenticated
using (public.is_active_owner())
with check (public.is_active_owner());

create policy "Public can submit website orders"
on public.website_orders for insert
to anon, authenticated
with check (true);

create policy "Admins can manage website orders"
on public.website_orders for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

create policy "Admins can read activity logs"
on public.admin_activity_logs for select
to authenticated
using (public.is_active_admin());

create policy "Admins can insert activity logs"
on public.admin_activity_logs for insert
to authenticated
with check (public.is_active_admin());

create policy "Users can read own profile"
on public.profiles for select
to authenticated
using (id = (select auth.uid()) or public.is_active_admin());

create policy "Users can update own profile"
on public.profiles for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy "Owners can manage admin memberships"
on public.admin_memberships for all
to authenticated
using (public.is_active_owner())
with check (public.is_active_owner());

create policy "Admins can read own membership"
on public.admin_memberships for select
to authenticated
using (user_id = (select auth.uid()) and is_active = true);

-- Seed initial categories.
insert into public.categories (name, slug, category_group) values
  ('PG & Hostels', 'pg-hostels', 'accommodation'),
  ('Rooms', 'rooms', 'accommodation'),
  ('Tiffin Services', 'tiffin-services', 'food'),
  ('Mess & Meal Plans', 'mess-meal-plans', 'food')
on conflict (slug) do nothing;
