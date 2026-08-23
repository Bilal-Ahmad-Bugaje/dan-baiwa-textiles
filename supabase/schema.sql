-- Dan Baiwa Textiles production schema
-- Run this once in Supabase SQL Editor.
-- Security model: public can read active fabrics; public can submit enquiries/orders;
-- only authenticated admins can manage catalogue, enquiries, orders and customers.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'staff' check (role in ('admin','staff')),
  created_at timestamptz not null default now()
);

create table if not exists public.fabrics (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  description text,
  stock_status text not null default 'In Stock' check (stock_status in ('In Stock','Low Stock','Out of Stock')),
  image_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers(id) on delete set null,
  fabric_id uuid references public.fabrics(id) on delete set null,
  customer_name text not null,
  phone text,
  email text,
  fabric_name text,
  quantity text,
  colour_note text,
  source text not null default 'website',
  status text not null default 'New' check (status in ('New','Contacted','Converted','Closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers(id) on delete set null,
  order_number text unique not null,
  customer_name text not null,
  phone text,
  items jsonb not null default '[]'::jsonb,
  notes text,
  status text not null default 'New' check (status in ('New','Confirmed','Processing','Ready','Completed','Cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fabrics_category_idx on public.fabrics(category);
create index if not exists fabrics_active_idx on public.fabrics(active);
create index if not exists enquiries_status_idx on public.enquiries(status);
create index if not exists enquiries_created_idx on public.enquiries(created_at desc);
create index if not exists orders_status_idx on public.orders(status);
create index if not exists orders_created_idx on public.orders(created_at desc);

-- updated_at helper
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists fabrics_updated_at on public.fabrics;
create trigger fabrics_updated_at before update on public.fabrics for each row execute function public.set_updated_at();
drop trigger if exists customers_updated_at on public.customers;
create trigger customers_updated_at before update on public.customers for each row execute function public.set_updated_at();
drop trigger if exists enquiries_updated_at on public.enquiries;
create trigger enquiries_updated_at before update on public.enquiries for each row execute function public.set_updated_at();
drop trigger if exists orders_updated_at on public.orders;
create trigger orders_updated_at before update on public.orders for each row execute function public.set_updated_at();

-- Admin helper. Service role is used only for provisioning; browser clients use this function through auth.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- RLS
alter table public.profiles enable row level security;
alter table public.fabrics enable row level security;
alter table public.customers enable row level security;
alter table public.enquiries enable row level security;
alter table public.orders enable row level security;

-- Remove broad client privileges before adding least-privilege grants.
revoke all on public.profiles, public.fabrics, public.customers, public.enquiries, public.orders from anon, authenticated;
grant select on public.fabrics to anon, authenticated;
grant insert on public.enquiries to anon, authenticated;
grant insert on public.customers to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.fabrics, public.customers, public.enquiries, public.orders to authenticated;

drop policy if exists fabrics_public_read on public.fabrics;
create policy fabrics_public_read on public.fabrics for select to anon, authenticated using (active = true);

drop policy if exists enquiries_public_insert on public.enquiries;
create policy enquiries_public_insert on public.enquiries for insert to anon, authenticated with check (true);

drop policy if exists customers_public_insert on public.customers;
create policy customers_public_insert on public.customers for insert to anon, authenticated with check (true);

-- Admin/staff policies. Customer-facing authenticated users do not get these rights unless their profile says staff/admin.
create policy fabrics_admin_manage on public.fabrics for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy customers_admin_manage on public.customers for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy enquiries_admin_manage on public.enquiries for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy orders_admin_manage on public.orders for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy profiles_self_read on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy profiles_admin_manage on public.profiles for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Storage bucket for fabric photos. Keep the bucket public for CDN-style product image delivery;
-- only admins may upload/update/delete objects.
insert into storage.buckets (id, name, public) values ('fabric-images','fabric-images',true)
on conflict (id) do update set public = excluded.public;

drop policy if exists fabric_images_public_read on storage.objects;
create policy fabric_images_public_read on storage.objects for select to anon, authenticated using (bucket_id = 'fabric-images');
drop policy if exists fabric_images_admin_insert on storage.objects;
create policy fabric_images_admin_insert on storage.objects for insert to authenticated with check (bucket_id = 'fabric-images' and public.is_admin());
drop policy if exists fabric_images_admin_update on storage.objects;
create policy fabric_images_admin_update on storage.objects for update to authenticated using (bucket_id = 'fabric-images' and public.is_admin()) with check (bucket_id = 'fabric-images' and public.is_admin());
drop policy if exists fabric_images_admin_delete on storage.objects;
create policy fabric_images_admin_delete on storage.objects for delete to authenticated using (bucket_id = 'fabric-images' and public.is_admin());

-- Seed a small initial catalogue. Replace image URLs after the admin uploads the real fabric photographs.
insert into public.fabrics (name, category, description, stock_status, image_url)
select * from (values
 ('Luxury Lace','Lace & Brocade','Premium statement fabrics for elevated occasion wear.','In Stock',''),
 ('Royal Brocade','Lace & Brocade','Rich textures for kaftans, agbada, gowns and premium menswear.','Low Stock',''),
 ('Atiku & Cashmere Plain','Atiku & Plain','Versatile plain textiles for timeless tailoring.','In Stock',''),
 ('Aso-Ebi Materials','Aso-Ebi','High-grade fabrics for weddings and celebrations.','In Stock',''),
 ('Uniform Fabrics','Uniforms','Durable textile rolls for schools and corporate wear.','In Stock','')
) as seed(name,category,description,stock_status,image_url)
where not exists (select 1 from public.fabrics);
