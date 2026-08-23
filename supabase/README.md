# Dan Baiwa Textiles — Supabase setup

Render, MongoDB Atlas and Cloudinary are no longer part of the target architecture.

## Target stack

- **Vercel:** customer website + admin UI
- **Supabase:** PostgreSQL database + Auth + Storage + Data API
- **Cloudflare R2:** optional later if fabric storage outgrows Supabase Storage

For the current launch, Supabase Storage is the simplest option, so R2 is not required yet.

## Setup

1. Create a Supabase project named `Dan Baiwa Textiles`.
2. Open **SQL Editor**.
3. Run `supabase/schema.sql`.
4. In **Authentication → Users**, create the owner account.
5. Insert/update that user's row in `public.profiles` so `role = 'admin'`.
6. Copy the project URL and publishable key into the frontend's production environment/configuration.
7. Never put a Supabase service-role/secret key in browser code.

The schema enables Row Level Security and uses a public read path only for active fabric listings. Admin mutations require an authenticated user whose profile role is `admin`.

## Why this replaces the old stack

The browser can use `supabase-js` directly against the Supabase Data API when RLS and least-privilege grants are configured correctly. Supabase Auth provides the admin session and JWT; PostgreSQL stores fabrics, customers, enquiries and orders; Supabase Storage holds fabric photographs.

## Production checklist

- [ ] Create Supabase project
- [ ] Run `schema.sql`
- [ ] Create owner auth user
- [ ] Set profile role to `admin`
- [ ] Add production Supabase URL + publishable key
- [ ] Replace demo catalogue images with real fabric photos
- [ ] Connect the UI to Supabase queries/auth/storage
- [ ] Deploy to Vercel
- [ ] Add custom domain
- [ ] Run RLS/security and mobile tests
