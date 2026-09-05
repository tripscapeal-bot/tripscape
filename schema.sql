create extension if not exists pgcrypto;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text, role text not null default 'user' check(role in('user','editor','admin')),
 created_at timestamptz default now()
);
create table if not exists public.destinations(
 id uuid primary key default gen_random_uuid(),name text not null,slug text unique not null,region text,
 description text,image_url text,latitude double precision,longitude double precision,
 published boolean default true,created_at timestamptz default now(),updated_at timestamptz default now()
);
create table if not exists public.villages(
 id uuid primary key default gen_random_uuid(),name text not null,slug text unique not null,region text,
 description text,image_url text,latitude double precision,longitude double precision,
 published boolean default true,created_at timestamptz default now(),updated_at timestamptz default now()
);
create table if not exists public.businesses(
 id uuid primary key default gen_random_uuid(),name text not null,slug text unique not null,category text not null,
 description text,phone text,email text,website text,address text,city text,image_url text,
 latitude double precision,longitude double precision,published boolean default false,
 created_at timestamptz default now(),updated_at timestamptz default now()
);
create table if not exists public.news(
 id uuid primary key default gen_random_uuid(),title text not null,slug text unique not null,excerpt text,content text,
 image_url text,source_name text,source_url text,published boolean default true,
 published_at timestamptz default now(),created_at timestamptz default now(),updated_at timestamptz default now()
);
create table if not exists public.videos(
 id uuid primary key default gen_random_uuid(),title text not null,description text,youtube_url text not null,
 thumbnail_url text,published boolean default true,created_at timestamptz default now()
);
create table if not exists public.gallery(
 id uuid primary key default gen_random_uuid(),title text,image_url text not null,alt_text text,
 published boolean default true,created_at timestamptz default now()
);
create table if not exists public.reviews(
 id uuid primary key default gen_random_uuid(),business_id uuid references public.businesses(id) on delete cascade,
 user_id uuid references auth.users(id) on delete set null,rating int check(rating between 1 and 5),
 comment text,approved boolean default false,created_at timestamptz default now()
);
create table if not exists public.business_requests(
 id uuid primary key default gen_random_uuid(),business_name text not null,category text,contact_name text,
 email text,phone text,message text,status text default 'pending' check(status in('pending','approved','rejected')),
 created_at timestamptz default now()
);
create table if not exists public.site_settings(key text primary key,value text,updated_at timestamptz default now());

create or replace function public.is_staff() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role in('admin','editor'));
$$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')); return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

do $$ declare t text; begin
 foreach t in array array['profiles','destinations','villages','businesses','news','videos','gallery','reviews','business_requests','site_settings'] loop
   execute format('alter table public.%I enable row level security',t);
 end loop;
end $$;

drop policy if exists public_destinations on public.destinations;
create policy public_destinations on public.destinations for select using(published or public.is_staff());
drop policy if exists staff_destinations on public.destinations;
create policy staff_destinations on public.destinations for all to authenticated using(public.is_staff()) with check(public.is_staff());

drop policy if exists public_villages on public.villages;
create policy public_villages on public.villages for select using(published or public.is_staff());
drop policy if exists staff_villages on public.villages;
create policy staff_villages on public.villages for all to authenticated using(public.is_staff()) with check(public.is_staff());

drop policy if exists public_businesses on public.businesses;
create policy public_businesses on public.businesses for select using(published or public.is_staff());
drop policy if exists staff_businesses on public.businesses;
create policy staff_businesses on public.businesses for all to authenticated using(public.is_staff()) with check(public.is_staff());

drop policy if exists public_news on public.news;
create policy public_news on public.news for select using(published or public.is_staff());
drop policy if exists staff_news on public.news;
create policy staff_news on public.news for all to authenticated using(public.is_staff()) with check(public.is_staff());

drop policy if exists public_videos on public.videos;
create policy public_videos on public.videos for select using(published or public.is_staff());
drop policy if exists staff_videos on public.videos;
create policy staff_videos on public.videos for all to authenticated using(public.is_staff()) with check(public.is_staff());

drop policy if exists public_gallery on public.gallery;
create policy public_gallery on public.gallery for select using(published or public.is_staff());
drop policy if exists staff_gallery on public.gallery;
create policy staff_gallery on public.gallery for all to authenticated using(public.is_staff()) with check(public.is_staff());

drop policy if exists public_reviews on public.reviews;
create policy public_reviews on public.reviews for select using(approved or user_id=auth.uid() or public.is_staff());
drop policy if exists user_reviews on public.reviews;
create policy user_reviews on public.reviews for insert to authenticated with check(user_id=auth.uid());
drop policy if exists staff_reviews on public.reviews;
create policy staff_reviews on public.reviews for all to authenticated using(public.is_staff()) with check(public.is_staff());

drop policy if exists public_requests on public.business_requests;
create policy public_requests on public.business_requests for insert with check(true);
drop policy if exists staff_requests on public.business_requests;
create policy staff_requests on public.business_requests for all to authenticated using(public.is_staff()) with check(public.is_staff());

drop policy if exists staff_settings on public.site_settings;
create policy staff_settings on public.site_settings for all to authenticated using(public.is_staff()) with check(public.is_staff());

insert into storage.buckets(id,name,public) values('tripscape-media','tripscape-media',true) on conflict(id) do nothing;
drop policy if exists media_read on storage.objects;
create policy media_read on storage.objects for select using(bucket_id='tripscape-media');
drop policy if exists media_write on storage.objects;
create policy media_write on storage.objects for all to authenticated using(bucket_id='tripscape-media' and public.is_staff()) with check(bucket_id='tripscape-media' and public.is_staff());

-- After creating the admin in Authentication > Users:
-- update public.profiles set role='admin' where id='ADMIN-UUID';
