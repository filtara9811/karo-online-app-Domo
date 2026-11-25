-- v3: customer ke order bhi vendor app me ghanti ke saath (kind='order', koi coin nahi)
alter table ko_leads add column if not exists kind text not null default 'lead';
create or replace function ko_matches(v ko_vendors, l ko_leads) returns boolean
language sql immutable as $$
  select l.kind = 'order'
    or lower(coalesce(l.service,'')) in ('general request','general')
    or exists (select 1 from unnest(v.subs) s where lower(s) = lower(l.service) or lower(l.service) like '%' || lower(s) || '%' or lower(s) like '%' || lower(l.service) || '%')
    or exists (select 1 from unnest(v.cats) c where lower(c) = lower(coalesce(l.category,'')) or lower(c) = lower(l.service))
$$;
-- ko_lead_create: p.kind='order' -> coins 0 (dekhein migration ko_order_kind)

-- v277: dukaan par visit (link / QR) → dukaandar ko suchna
create table if not exists public.ko_visits (id bigserial primary key, shop text not null, shop_idx int, visitor_name text, visitor_phone text, src text, created_at timestamptz not null default now());
alter table public.ko_visits enable row level security;
-- functions: ko_visit(p jsonb), ko_visits_new(p_vendor uuid, p_after bigint) — dekhein migration "ko_visits"

-- v279: grahak (bina OTP) — pehli baar naam+mobile, doosri baar pehchaan
create table if not exists public.ko_customers (phone text primary key, name text, visits int not null default 0, created_at timestamptz not null default now(), last_seen timestamptz not null default now());
alter table public.ko_customers enable row level security;
-- functions: ko_customer_get(p_phone), ko_customer_save(p jsonb); ko_visit ab phone se naam bharta hai; ko_visits_new phone bhi deta hai (migration "ko_customers")

-- v281: ilaka (area) + web dukaan-panel ke liye visit feed (number aadha chhupa)
alter table public.ko_visits add column if not exists area text;
alter table public.ko_customers add column if not exists area text;
-- functions: ko_visits_feed(p_shop, p_limit) — migration "ko_visits_area_feed"

-- v282: ek grahak = ek line (phone ya device se pehchaan), dobara aane par count nahi badhta, history
alter table public.ko_visits add column if not exists dev text;
create index if not exists ko_visits_shop_idx on public.ko_visits(shop, id desc);
-- ko_visits_new ab 'n' (kitni baar aaya) deta hai; ko_visits_feed 'key' deta hai — migration "ko_visits_dedupe"

-- v283: ko_settings (app ke niyam: home All Shops / Quick Service, plan ki keemat, coin ke niyam) — admin PIN se hi badle
create table if not exists public.ko_settings (k text primary key, v jsonb not null, updated_at timestamptz not null default now());
alter table public.ko_settings enable row level security;
-- functions: ko_settings_get(), ko_settings_set(p_pin, p_v), ko_admin_pin_change(p_old, p_new) — migration "ko_settings"

-- v284: dukaandar ka plan / trial phone se Supabase me; kamai ka hisaab (admin PIN se)
create table if not exists public.ko_vendor_plan (phone text primary key, t0 timestamptz not null default now(), pos_until timestamptz, khata_until timestamptz, updated_at timestamptz not null default now());
create table if not exists public.ko_bill_log (id bigserial primary key, phone text, kind text not null, what text, amount int not null default 0, coins int not null default 0, created_at timestamptz not null default now());
-- functions: ko_plan_get, ko_plan_activate, ko_coin_log, ko_bill_summary(p_pin) — migration "ko_vendor_plans"

-- v285: delivery — ko_riders, ko_shipments, ko_secrets (keys sirf server par, masked list)
-- functions: ko_pin_ok, ko_ship_create, ko_ship_track (address nahi), ko_ship_by_shop, ko_ship_courier_set (service_role),
--   ko_rider_join/online/feed/accept/step, ko_ship_vendor_step, ko_secret_set/list, ko_admin_delivery
-- edge function: supabase/functions/ko-courier (status/test/rates/book via Shiprocket; bina keys demo)
