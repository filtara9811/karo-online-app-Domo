-- =====================================================================
-- Karo Online — v3 SECURE backend (Step 0)
-- =====================================================================
-- Kya badla (v1/v2 ke muqable):
--  1. Asli login: Supabase Auth phone OTP. Har vendor RPC ab `auth.uid()` se
--     apni dukaan pehchanta hai — client se `p_vendor` (vendor id) nahi aata.
--     Isse koi doosre vendor ki jagah lead accept / coin add / data nahi dekh sakta.
--  2. Coins / plan / rent client se nahi badal sakte. Sirf server (Razorpay
--     webhook, service_role) ya "demo mode" (ko_config.demo_payments = true) me.
--  3. Har coin ka hisaab: ko_coin_txns ledger.
--  4. Customer ki request (lead) par secret `token` — status sirf wahi dekh
--     sakta hai jiske paas token ho (pehle lead id 1,2,3… se sabke vendor
--     phone nikal sakte the).
--  5. Distance se matching: vendor + lead ka lat/lng, vendor ka radius (km).
--  6. Service matching saaf: chhote shabd ("AC") ab har jagah match nahi hote.
--  7. Lead settings (timing, din, roz ki limit) server par check — v2 jaisa.
--  8. Customer lead par rate-limit (spam rokna).
--
-- Kahan chalayein: NAYA alag Supabase project (salah yahi hai). Purane
-- (Committee Manager) project par bhi chal jaati hai — tab purane khule v1/v2
-- functions (p_vendor wale) HAT jaate hain, yaani purana vendor APK (1.1.x)
-- usi pal band ho jaata hai. Isliye wahan naya APK release ke saath hi chalayein.
-- File dobara chalana safe hai (idempotent).
-- =====================================================================

-- Purane khule functions (v1/v2) — koi bhi kisi bhi vendor id se chala sakta tha
drop function if exists ko_vendor_get(text);
drop function if exists ko_set_online(uuid, boolean);
drop function if exists ko_coins_add(uuid, int);
drop function if exists ko_lead_status(bigint);
drop function if exists ko_inbox(uuid);
drop function if exists ko_lead_accept(uuid, bigint);
drop function if exists ko_lead_reject(uuid, bigint);
drop function if exists ko_my_leads(uuid);
drop function if exists ko_lead_step(uuid, bigint, text);
drop function if exists ko_vendor_add_lead(uuid, jsonb);

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Config (admin panel se badlega) — launch se pehle demo_payments = false
-- ---------------------------------------------------------------------
create table if not exists ko_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz default now()
);
alter table ko_config enable row level security;

insert into ko_config (key, value) values
  ('demo_payments', 'true'::jsonb),      -- true = bina payment ke trial/₹100 plan aur coin add (sirf testing)
  ('enforce_rent', 'false'::jsonb),      -- true = rent khatam to leads band
  ('signup_coins', '100'::jsonb),        -- nayi dukaan ko muft coins
  ('lead_ttl_minutes', '30'::jsonb),
  ('lead_slots', '5'::jsonb),
  ('lead_rate_per_phone_hour', '10'::jsonb),
  ('lead_rate_global_minute', '60'::jsonb)
on conflict (key) do nothing;

create or replace function ko_cfg(p_key text, p_default jsonb default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select value from ko_config where key = p_key), p_default)
$$;

-- ---------------------------------------------------------------------
-- Tables (naye project me ban jaayengi, purane me sirf nayi columns judengi)
-- ---------------------------------------------------------------------
create table if not exists ko_vendors (
  id uuid primary key default gen_random_uuid(),
  phone text unique not null,
  shop_name text not null,
  owner_name text,
  area text,
  ty text default 'svc',
  role text,
  biz text,
  radius text default '5',
  cats text[] default '{}',
  subs text[] default '{}',
  items jsonb default '{}'::jsonb,
  plan text,
  rent_until date,
  online boolean default true,
  coins int default 100,
  last_seen timestamptz default now(),
  created_at timestamptz default now()
);

alter table ko_vendors add column if not exists user_id uuid unique references auth.users(id) on delete set null;
alter table ko_vendors add column if not exists settings jsonb default '{}'::jsonb;
alter table ko_vendors add column if not exists status text default 'active';   -- active | pending | suspended | rejected
alter table ko_vendors add column if not exists lat double precision;
alter table ko_vendors add column if not exists lng double precision;
alter table ko_vendors add column if not exists trial_used boolean default false;
alter table ko_vendors add column if not exists updated_at timestamptz default now();

create table if not exists ko_leads (
  id bigint generated always as identity primary key,
  customer_name text,
  customer_phone text,
  service text not null,
  category text,
  icon text,
  need text,
  budget int,
  area text,
  coins int default 1,
  slots int default 5,
  status text default 'open',
  created_at timestamptz default now(),
  expires_at timestamptz default now() + interval '30 minutes'
);

alter table ko_leads add column if not exists token uuid default gen_random_uuid();
alter table ko_leads add column if not exists customer_user_id uuid references auth.users(id) on delete set null;
alter table ko_leads add column if not exists lat double precision;
alter table ko_leads add column if not exists lng double precision;
alter table ko_leads add column if not exists source text default 'customer';    -- customer | manual
alter table ko_leads add column if not exists vendor_id uuid references ko_vendors(id) on delete cascade; -- manual lead kis vendor ki

create table if not exists ko_lead_vendors (
  lead_id bigint references ko_leads(id) on delete cascade,
  vendor_id uuid references ko_vendors(id) on delete cascade,
  status text not null,
  step text default 'accept',
  coins_cut int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (lead_id, vendor_id)
);

-- Har coin ka hisaab
create table if not exists ko_coin_txns (
  id bigint generated always as identity primary key,
  vendor_id uuid not null references ko_vendors(id) on delete cascade,
  delta int not null,
  balance int not null,
  reason text not null,          -- signup | lead_accept | recharge | demo_add | admin
  lead_id bigint references ko_leads(id) on delete set null,
  ref text,                      -- payment id (Razorpay) / admin note
  created_at timestamptz default now()
);

-- Admin / staff (Step 2 me admin panel isi se chalega)
create table if not exists ko_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin',   -- admin | manager | support | field_sales | kyc | finance
  name text,
  created_at timestamptz default now()
);

alter table ko_vendors enable row level security;
alter table ko_leads enable row level security;
alter table ko_lead_vendors enable row level security;
alter table ko_coin_txns enable row level security;
alter table ko_admins enable row level security;
-- Koi policy nahi = tables par seedha read/write BAND. Sab kuch neeche ke RPC se.

create index if not exists ko_leads_open_idx on ko_leads (status, expires_at);
create index if not exists ko_leads_phone_idx on ko_leads (customer_phone, created_at);
create index if not exists ko_lv_vendor_idx on ko_lead_vendors (vendor_id, created_at);
create index if not exists ko_coin_txns_vendor_idx on ko_coin_txns (vendor_id, created_at);

-- ---------------------------------------------------------------------
-- Helpers (clients ke liye band)
-- ---------------------------------------------------------------------

-- Login kiye user ka 10 ankon ka mobile (Auth "919876543210" rakhta hai)
create or replace function ko_auth_phone() returns text
language sql stable security definer set search_path = public as $$
  select right(regexp_replace(coalesce((select phone from auth.users where id = auth.uid()), ''), '\D', '', 'g'), 10)
$$;

-- Login kiye user ki dukaan (purani dukaan pehli login par phone se jud jaati hai)
create or replace function ko_me_row() returns ko_vendors
language plpgsql security definer set search_path = public as $$
declare v ko_vendors; ph text;
begin
  if auth.uid() is null then raise exception 'login zaroori hai' using errcode = '28000'; end if;
  select * into v from ko_vendors where user_id = auth.uid();
  if v.id is not null then return v; end if;
  ph := ko_auth_phone();
  if ph !~ '^[6-9][0-9]{9}$' then return null; end if;
  update ko_vendors set user_id = auth.uid() where phone = ph and user_id is null returning * into v;
  return v;
end $$;

create or replace function ko_vendor_json(v ko_vendors) returns jsonb language sql stable as $$
  select to_jsonb(v) - 'last_seen' - 'user_id' - 'trial_used'
$$;

-- Do jagah ki doori (km) — haversine
create or replace function ko_km(lat1 double precision, lng1 double precision, lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$;

-- Service match: barabar; ya lamba shabd (4+ akshar) doosre me shaamil;
-- ya chhota shabd (jaise "AC") doosre me POORA shabd ho ("AC Repair" ✓, "Coaching" ✗)
create or replace function ko_term_match(a text, b text) returns boolean language sql immutable as $$
  select a <> '' and b <> '' and (
    a = b
    or (length(a) >= 4 and position(a in b) > 0)
    or (length(b) >= 4 and position(b in a) > 0)
    or b ~ ('(^|[^[:alnum:]])' || regexp_replace(a, '([.^$*+?()\[\]{}|\\])', '\\\1', 'g') || '($|[^[:alnum:]])')
    or a ~ ('(^|[^[:alnum:]])' || regexp_replace(b, '([.^$*+?()\[\]{}|\\])', '\\\1', 'g') || '($|[^[:alnum:]])'))
$$;

create or replace function ko_matches(v ko_vendors, l ko_leads) returns boolean
language sql stable as $$
  select
    -- 1) service / category
    (
      lower(trim(coalesce(l.service, ''))) in ('general request', 'general')
      or exists (select 1 from unnest(v.subs) s where ko_term_match(lower(trim(s)), lower(trim(l.service))))
      or exists (select 1 from unnest(v.cats) c where lower(trim(c)) in (lower(trim(coalesce(l.category, ''))), lower(trim(l.service))))
    )
    -- 2) doori: dono ke paas location ho to radius ke andar
    and (
      v.lat is null or v.lng is null or l.lat is null or l.lng is null
      or ko_km(v.lat, v.lng, l.lat, l.lng) <= greatest(1, coalesce(nullif(regexp_replace(coalesce(v.radius, ''), '[^0-9.]', '', 'g'), '')::numeric, 5))
    )
$$;

-- Vendor abhi lead le sakta hai? (status, online, rent, timing, din, roz ki limit)
create or replace function ko_vendor_open(v ko_vendors) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  s jsonb := coalesce(v.settings, '{}'::jsonb);
  now_ist timestamp := (now() at time zone 'Asia/Kolkata');
  t time := now_ist::time;
  f time; e time; lim int; today int;
begin
  if coalesce(v.status, 'active') <> 'active' or not coalesce(v.online, false) then return false; end if;
  if ko_cfg('enforce_rent', 'false') = 'true'::jsonb and (v.rent_until is null or v.rent_until < now_ist::date) then
    return false;
  end if;
  if jsonb_typeof(s->'days') = 'array' and jsonb_array_length(s->'days') > 0
     and not (s->'days') @> to_jsonb(extract(isodow from now_ist)::int) then
    return false;
  end if;
  if coalesce((s->>'h24')::boolean, true) = false then
    begin
      f := coalesce(nullif(s->>'from', ''), '09:00')::time;
      e := coalesce(nullif(s->>'to', ''), '21:00')::time;
    exception when others then f := '00:00'; e := '23:59:59';
    end;
    if f <= e then
      if t < f or t > e then return false; end if;
    else  -- raat bhar (jaise 20:00 → 02:00)
      if t < f and t > e then return false; end if;
    end if;
  end if;
  lim := coalesce(nullif(s->>'limit', '')::int, 0);
  if lim > 0 then
    select count(*) into today from ko_lead_vendors x
      where x.vendor_id = v.id and x.status = 'accepted' and x.coins_cut > 0
        and (x.created_at at time zone 'Asia/Kolkata')::date = now_ist::date;
    if today >= lim then return false; end if;
  end if;
  return true;
end $$;

create or replace function ko_coin_log(p_vendor uuid, p_delta int, p_balance int, p_reason text, p_lead bigint default null, p_ref text default null)
returns void language sql security definer set search_path = public as $$
  insert into ko_coin_txns (vendor_id, delta, balance, reason, lead_id, ref) values (p_vendor, p_delta, p_balance, p_reason, p_lead, p_ref)
$$;

-- =====================================================================
-- VENDOR RPC — sab `authenticated` (login) ke liye, dukaan auth.uid() se
-- =====================================================================

-- Meri dukaan (null = abhi join nahi kiya)
create or replace function ko_me() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v ko_vendors;
begin
  v := ko_me_row();
  if v.id is null then return null; end if;
  update ko_vendors set last_seen = now() where id = v.id;
  return ko_vendor_json(v);
end $$;

-- Join / profile / settings save. phone, coins, status, user_id client se nahi badalte.
-- plan (trial | p100): sirf demo mode me yahan se; asli me ko_plan_activate (server).
create or replace function ko_vendor_save(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v ko_vendors; cur ko_vendors; ph text; pl text := nullif(p->>'plan', ''); demo boolean;
  new_until date; is_new boolean := false;
begin
  if auth.uid() is null then raise exception 'login zaroori hai' using errcode = '28000'; end if;
  ph := ko_auth_phone();
  if ph !~ '^[6-9][0-9]{9}$' then raise exception 'mobile number galat hai'; end if;
  if length(trim(coalesce(p->>'shop_name', ''))) < 2 then raise exception 'dukaan ka naam likhein'; end if;
  if pl is not null and pl not in ('trial', 'p100') then raise exception 'plan galat hai'; end if;

  cur := ko_me_row();
  if cur.id is not null and cur.status in ('suspended', 'rejected') then raise exception 'dukaan band hai — support se baat karein'; end if;
  demo := ko_cfg('demo_payments', 'false') = 'true'::jsonb;

  if cur.id is null then
    is_new := true;
    insert into ko_vendors (phone, user_id, shop_name, coins)
    values (ph, auth.uid(), left(trim(p->>'shop_name'), 80), coalesce((ko_cfg('signup_coins', '100'))::text::int, 100))
    returning * into cur;
    perform ko_coin_log(cur.id, cur.coins, cur.coins, 'signup');
  end if;

  -- plan sirf demo me client se (asli payment = ko_plan_activate)
  if pl is not null and demo then
    if pl = 'trial' and not coalesce(cur.trial_used, false) then
      new_until := greatest(coalesce(cur.rent_until, current_date), current_date) + 7;
    elsif pl = 'p100' then
      new_until := greatest(coalesce(cur.rent_until, current_date), current_date) + 30;
    end if;
  end if;

  update ko_vendors set
    shop_name  = left(trim(p->>'shop_name'), 80),
    owner_name = coalesce(left(p->>'owner_name', 80), owner_name),
    area       = coalesce(left(p->>'area', 160), area),
    ty         = coalesce(nullif(p->>'ty', ''), ty, 'svc'),
    role       = coalesce(left(p->>'role', 40), role),
    biz        = coalesce(left(p->>'biz', 40), biz),
    radius     = coalesce(left(p->>'radius', 6), radius, '5'),
    cats       = case when p ? 'cats' then coalesce(array(select left(jsonb_array_elements_text(p->'cats'), 80) limit 100), '{}') else cats end,
    subs       = case when p ? 'subs' then coalesce(array(select left(jsonb_array_elements_text(p->'subs'), 80) limit 300), '{}') else subs end,
    items      = case when p ? 'items' then coalesce(p->'items', '{}'::jsonb) else items end,
    settings   = case when p ? 'settings' then coalesce(p->'settings', '{}'::jsonb) else settings end,
    lat        = case when p ? 'lat' then nullif(p->>'lat', '')::double precision else lat end,
    lng        = case when p ? 'lng' then nullif(p->>'lng', '')::double precision else lng end,
    plan       = case when new_until is not null then pl else plan end,
    rent_until = coalesce(new_until, rent_until),
    trial_used = trial_used or (new_until is not null and pl = 'trial'),
    last_seen  = now(),
    updated_at = now()
  where id = cur.id
  returning * into v;
  return ko_vendor_json(v);
end $$;

create or replace function ko_set_online(p_online boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v ko_vendors;
begin
  v := ko_me_row();
  if v.id is null then raise exception 'dukaan nahi mili'; end if;
  update ko_vendors set online = p_online, last_seen = now() where id = v.id;
end $$;

-- Testing ke liye coin (sirf demo mode). Asli recharge = ko_coins_credit (Razorpay webhook).
create or replace function ko_coins_add(p_n int) returns int
language plpgsql security definer set search_path = public as $$
declare v ko_vendors; n int := greatest(0, least(coalesce(p_n, 0), 500)); bal int;
begin
  if ko_cfg('demo_payments', 'false') <> 'true'::jsonb then
    raise exception 'Recharge payment se hoga (abhi uplabdh nahi)';
  end if;
  v := ko_me_row();
  if v.id is null then raise exception 'dukaan nahi mili'; end if;
  update ko_vendors set coins = coins + n where id = v.id returning coins into bal;
  perform ko_coin_log(v.id, n, bal, 'demo_add');
  return bal;
end $$;

-- Khuli leads jo mujhse match karti hain
create or replace function ko_inbox() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v ko_vendors;
begin
  v := ko_me_row();
  if v.id is null then return '[]'::jsonb; end if;
  update ko_vendors set last_seen = now() where id = v.id;
  if not ko_vendor_open(v) then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', l.id, 'name', coalesce(nullif(l.customer_name, ''), 'Customer'), 'service', l.service, 'category', l.category,
      'icon', l.icon, 'need', l.need, 'budget', l.budget, 'area', l.area, 'coins', l.coins, 'slots', l.slots,
      'km', case when v.lat is not null and l.lat is not null then round(ko_km(v.lat, v.lng, l.lat, l.lng)::numeric, 1) end,
      'taken', (select count(*) from ko_lead_vendors x where x.lead_id = l.id and x.status = 'accepted'),
      'created_at', l.created_at, 'expires_at', l.expires_at) order by l.created_at desc)
    from ko_leads l
    where l.status = 'open' and l.source = 'customer' and l.expires_at > now()
      and ko_matches(v, l)
      and not exists (select 1 from ko_lead_vendors x where x.lead_id = l.id and x.vendor_id = v.id)
      and (select count(*) from ko_lead_vendors x where x.lead_id = l.id and x.status = 'accepted') < l.slots
  ), '[]'::jsonb);
end $$;

create or replace function ko_lead_accept(p_lead bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l ko_leads; v ko_vendors; taken int; bal int;
begin
  v := ko_me_row();
  if v.id is null then return jsonb_build_object('ok', false, 'msg', 'Dukaan nahi mili'); end if;
  select * into l from ko_leads where id = p_lead for update;
  if l.id is null or l.status <> 'open' or l.source <> 'customer' or l.expires_at < now() then
    return jsonb_build_object('ok', false, 'msg', 'Lead band ho chuki hai');
  end if;
  if not ko_vendor_open(v) then return jsonb_build_object('ok', false, 'msg', 'Aap abhi offline / samay ke bahar / limit poori'); end if;
  if not ko_matches(v, l) then return jsonb_build_object('ok', false, 'msg', 'Ye lead aapki service ki nahi'); end if;
  select count(*) into taken from ko_lead_vendors where lead_id = p_lead and status = 'accepted';
  if taken >= l.slots then return jsonb_build_object('ok', false, 'msg', 'Saari jagah bhar gayi'); end if;
  select * into v from ko_vendors where id = v.id for update;
  if v.coins < l.coins then return jsonb_build_object('ok', false, 'msg', 'Coins kam hain — recharge karein', 'coins', v.coins); end if;
  insert into ko_lead_vendors (lead_id, vendor_id, status, step, coins_cut) values (p_lead, v.id, 'accepted', 'accept', l.coins)
  on conflict (lead_id, vendor_id) do nothing;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Pehle hi le chuke hain'); end if;
  update ko_vendors set coins = coins - l.coins where id = v.id returning coins into bal;
  perform ko_coin_log(v.id, -l.coins, bal, 'lead_accept', l.id);
  return jsonb_build_object('ok', true, 'coins', bal, 'phone', l.customer_phone, 'name', l.customer_name);
end $$;

create or replace function ko_lead_reject(p_lead bigint) returns void
language plpgsql security definer set search_path = public as $$
declare v ko_vendors;
begin
  v := ko_me_row();
  if v.id is null then return; end if;
  insert into ko_lead_vendors (lead_id, vendor_id, status) values (p_lead, v.id, 'rejected')
  on conflict (lead_id, vendor_id) do nothing;
end $$;

create or replace function ko_my_leads() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v ko_vendors;
begin
  v := ko_me_row();
  if v.id is null then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', l.id, 'name', coalesce(nullif(l.customer_name, ''), 'Customer'), 'phone', l.customer_phone, 'service', l.service,
      'category', l.category, 'icon', l.icon, 'need', l.need, 'budget', l.budget, 'area', l.area, 'coins', lv.coins_cut,
      'source', l.source, 'step', lv.step, 'created_at', lv.created_at, 'updated_at', lv.updated_at) order by lv.created_at desc)
    from ko_lead_vendors lv join ko_leads l on l.id = lv.lead_id
    where lv.vendor_id = v.id and lv.status = 'accepted'
  ), '[]'::jsonb);
end $$;

create or replace function ko_lead_step(p_lead bigint, p_step text) returns void
language plpgsql security definer set search_path = public as $$
declare v ko_vendors;
begin
  if p_step not in ('accept', 'action', 'working', 'reached', 'done', 'review', 'skip') then raise exception 'step galat hai'; end if;
  v := ko_me_row();
  if v.id is null then return; end if;
  update ko_lead_vendors set step = p_step, updated_at = now()
  where vendor_id = v.id and lead_id = p_lead and status = 'accepted';
end $$;

-- "+ New lead": vendor ki apni lead (dukaan par aaya / phone aaya) — coin nahi, kisi aur ko nahi dikhti
create or replace function ko_vendor_add_lead(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v ko_vendors; l ko_leads;
begin
  v := ko_me_row();
  if v.id is null then raise exception 'dukaan nahi mili'; end if;
  if length(trim(coalesce(p->>'service', ''))) < 2 then raise exception 'service chahiye'; end if;
  insert into ko_leads (customer_name, customer_phone, service, category, icon, need, budget, area, coins, status, source, vendor_id, expires_at)
  values (left(p->>'name', 60), left(regexp_replace(coalesce(p->>'phone', ''), '\D', '', 'g'), 15), left(p->>'service', 80),
          left(p->>'category', 60), left(p->>'icon', 8), left(p->>'need', 300),
          nullif(regexp_replace(coalesce(p->>'budget', ''), '\D', '', 'g'), '')::int, left(coalesce(p->>'area', v.area), 160),
          0, 'manual', 'manual', v.id, now())
  returning * into l;
  insert into ko_lead_vendors (lead_id, vendor_id, status, step, coins_cut) values (l.id, v.id, 'accepted', 'accept', 0);
  return jsonb_build_object('id', l.id);
end $$;

-- Coins ka hisaab (wallet history)
create or replace function ko_my_coin_txns(p_limit int default 50) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v ko_vendors;
begin
  v := ko_me_row();
  if v.id is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(to_jsonb(t) - 'vendor_id' order by t.id desc)
    from (select * from ko_coin_txns where vendor_id = v.id order by id desc limit least(greatest(p_limit, 1), 200)) t), '[]'::jsonb);
end $$;

-- =====================================================================
-- CUSTOMER RPC — customer ऐप abhi bina login (anon) chalti hai
-- =====================================================================
create or replace function ko_lead_create(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l ko_leads; n int; ph text; per_phone int; recent int;
begin
  if length(trim(coalesce(p->>'service', ''))) < 2 then raise exception 'service chahiye'; end if;
  ph := right(regexp_replace(coalesce(p->>'customer_phone', ''), '\D', '', 'g'), 10);
  if ph <> '' and ph !~ '^[6-9][0-9]{9}$' then raise exception 'mobile number galat hai'; end if;

  -- spam rokna
  select count(*) into recent from ko_leads where source = 'customer' and created_at > now() - interval '1 minute';
  if recent >= coalesce((ko_cfg('lead_rate_global_minute', '60'))::text::int, 60) then
    raise exception 'Abhi bahut requests aa rahi hain — 1 minute baad try karein';
  end if;
  if ph <> '' then
    select count(*) into per_phone from ko_leads where customer_phone = ph and created_at > now() - interval '1 hour';
    if per_phone >= coalesce((ko_cfg('lead_rate_per_phone_hour', '10'))::text::int, 10) then
      raise exception 'Is number se bahut requests — thodi der baad try karein';
    end if;
  end if;

  insert into ko_leads (customer_name, customer_phone, customer_user_id, service, category, icon, need, budget, area, lat, lng,
                        coins, slots, expires_at)
  values (left(p->>'customer_name', 60), nullif(ph, ''), auth.uid(), left(trim(p->>'service'), 80), left(p->>'category', 60),
          left(p->>'icon', 8), left(p->>'need', 300), nullif(regexp_replace(coalesce(p->>'budget', ''), '\D', '', 'g'), '')::int,
          left(p->>'area', 160),
          case when (p->>'lat') ~ '^-?[0-9.]+$' then (p->>'lat')::double precision end,
          case when (p->>'lng') ~ '^-?[0-9.]+$' then (p->>'lng')::double precision end,
          greatest(1, least(coalesce(nullif(p->>'coins', '')::int, 1), 50)),   -- TODO Step 2: lead ka daam admin ke category rules se
          coalesce((ko_cfg('lead_slots', '5'))::text::int, 5),
          now() + make_interval(mins => coalesce((ko_cfg('lead_ttl_minutes', '30'))::text::int, 30)))
  returning * into l;
  select count(*) into n from ko_vendors v where ko_vendor_open(v) and ko_matches(v, l);
  return jsonb_build_object('id', l.id, 'token', l.token, 'vendors', n, 'expires_at', l.expires_at);
end $$;

-- Kin vendors ne accept kiya — sirf token wala (ya login kiya customer jiski lead hai)
create or replace function ko_lead_status(p_lead bigint, p_token uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l ko_leads;
begin
  select * into l from ko_leads where id = p_lead and source = 'customer';
  if l.id is null or not (
       (p_token is not null and l.token = p_token)
    or (auth.uid() is not null and l.customer_user_id = auth.uid())) then
    raise exception 'request nahi mili' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'lead', jsonb_build_object('id', l.id, 'service', l.service, 'status', l.status, 'expires_at', l.expires_at),
    'vendors', coalesce((select jsonb_agg(jsonb_build_object('shop', v.shop_name, 'owner', v.owner_name, 'phone', v.phone,
        'area', v.area, 'role', v.role, 'step', lv.step, 'at', lv.created_at) order by lv.created_at)
      from ko_lead_vendors lv join ko_vendors v on v.id = lv.vendor_id where lv.lead_id = l.id and lv.status = 'accepted'), '[]'::jsonb));
end $$;

create or replace function ko_lead_cancel(p_lead bigint, p_token uuid) returns void
language sql security definer set search_path = public as $$
  update ko_leads set status = 'cancelled' where id = p_lead and token = p_token and status = 'open'
$$;

-- =====================================================================
-- SERVER-ONLY (service_role) — Razorpay webhook / admin
-- =====================================================================
create or replace function ko_coins_credit(p_vendor uuid, p_n int, p_ref text) returns int
language plpgsql security definer set search_path = public as $$
declare bal int;
begin
  if p_n <= 0 then raise exception 'galat amount'; end if;
  if exists (select 1 from ko_coin_txns where ref = p_ref and reason = 'recharge') then
    select coins into bal from ko_vendors where id = p_vendor; return bal;   -- ek payment do baar nahi
  end if;
  update ko_vendors set coins = coins + p_n where id = p_vendor returning coins into bal;
  perform ko_coin_log(p_vendor, p_n, bal, 'recharge', null, p_ref);
  return bal;
end $$;

create or replace function ko_plan_activate(p_vendor uuid, p_plan text, p_days int, p_ref text) returns date
language plpgsql security definer set search_path = public as $$
declare d date;
begin
  update ko_vendors set plan = p_plan,
    rent_until = greatest(coalesce(rent_until, current_date), current_date) + p_days,
    trial_used = trial_used or p_plan = 'trial', updated_at = now()
  where id = p_vendor returning rent_until into d;
  return d;
end $$;

-- =====================================================================
-- Permissions — Postgres default me har function PUBLIC ke liye khula hota hai.
-- Pehle sab band, phir sirf zaroori khole.
-- =====================================================================
revoke execute on function
  ko_cfg(text, jsonb), ko_auth_phone(), ko_me_row(), ko_vendor_json(ko_vendors),
  ko_km(double precision, double precision, double precision, double precision), ko_term_match(text, text),
  ko_matches(ko_vendors, ko_leads), ko_vendor_open(ko_vendors),
  ko_coin_log(uuid, int, int, text, bigint, text),
  ko_me(), ko_vendor_save(jsonb), ko_set_online(boolean), ko_coins_add(int), ko_inbox(), ko_lead_accept(bigint),
  ko_lead_reject(bigint), ko_my_leads(), ko_lead_step(bigint, text), ko_vendor_add_lead(jsonb), ko_my_coin_txns(int),
  ko_lead_create(jsonb), ko_lead_status(bigint, uuid), ko_lead_cancel(bigint, uuid),
  ko_coins_credit(uuid, int, text), ko_plan_activate(uuid, text, int, text)
from public, anon, authenticated;

-- Vendor (login zaroori)
grant execute on function
  ko_me(), ko_vendor_save(jsonb), ko_set_online(boolean), ko_coins_add(int), ko_inbox(), ko_lead_accept(bigint),
  ko_lead_reject(bigint), ko_my_leads(), ko_lead_step(bigint, text), ko_vendor_add_lead(jsonb), ko_my_coin_txns(int)
to authenticated;

-- Customer (bina login bhi)
grant execute on function ko_lead_create(jsonb), ko_lead_status(bigint, uuid), ko_lead_cancel(bigint, uuid) to anon, authenticated;

-- ko_coins_credit, ko_plan_activate: sirf service_role (Edge Function / admin)
grant execute on function ko_coins_credit(uuid, int, text), ko_plan_activate(uuid, text, int, text) to service_role;
