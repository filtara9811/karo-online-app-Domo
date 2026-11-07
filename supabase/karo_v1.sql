-- Karo Online — vendor + leads (v1)
-- Committee Manager project me alag "ko_" tables. Committee ka data nahi chhuta.
-- Apps sirf RPC functions se baat karti hain (tables par seedha access band — RLS on, koi policy nahi).

create table if not exists ko_vendors (
  id uuid primary key default gen_random_uuid(),
  phone text unique not null,
  shop_name text not null,
  owner_name text,
  area text,
  ty text default 'svc',            -- svc | prd | oth
  role text,                        -- home/centre/... ya retailer/wholesaler/...
  biz text,                         -- registration type
  radius text default '5',
  cats text[] default '{}',         -- chuni hui category
  subs text[] default '{}',         -- chuni hui sub-services
  items jsonb default '{}'::jsonb,  -- sub -> [item names]
  plan text,                        -- trial | p100
  rent_until date,
  online boolean default true,
  coins int default 100,
  last_seen timestamptz default now(),
  created_at timestamptz default now()
);

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
  status text default 'open',       -- open | closed | cancelled
  created_at timestamptz default now(),
  expires_at timestamptz default now() + interval '30 minutes'
);

create table if not exists ko_lead_vendors (
  lead_id bigint references ko_leads(id) on delete cascade,
  vendor_id uuid references ko_vendors(id) on delete cascade,
  status text not null,             -- accepted | rejected
  step text default 'accept',       -- accept | action | working | reached | done | review
  coins_cut int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (lead_id, vendor_id)
);

alter table ko_vendors enable row level security;
alter table ko_leads enable row level security;
alter table ko_lead_vendors enable row level security;

create index if not exists ko_leads_open_idx on ko_leads (status, expires_at);

-- ---------- helpers ----------
create or replace function ko_matches(v ko_vendors, l ko_leads) returns boolean
language sql immutable as $$
  select
    lower(coalesce(l.service,'')) in ('general request','general')
    or exists (select 1 from unnest(v.subs) s where
          lower(s) = lower(l.service)
       or lower(l.service) like '%' || lower(s) || '%'
       or lower(s) like '%' || lower(l.service) || '%')
    or exists (select 1 from unnest(v.cats) c where lower(c) = lower(coalesce(l.category,'')) or lower(c) = lower(l.service))
$$;

create or replace function ko_vendor_json(v ko_vendors) returns jsonb language sql stable as $$
  select to_jsonb(v) - 'last_seen'
$$;

-- ---------- vendor ----------
create or replace function ko_vendor_get(p_phone text) returns jsonb
language sql security definer set search_path = public as $$
  select ko_vendor_json(v) from ko_vendors v where v.phone = p_phone
$$;

create or replace function ko_vendor_save(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v ko_vendors;
begin
  if coalesce(p->>'phone','') !~ '^[6-9][0-9]{9}$' then raise exception 'mobile number galat hai'; end if;
  if length(coalesce(p->>'shop_name','')) < 2 then raise exception 'dukaan ka naam likhein'; end if;
  insert into ko_vendors as t (phone, shop_name, owner_name, area, ty, role, biz, radius, cats, subs, items, plan, rent_until)
  values (p->>'phone', p->>'shop_name', p->>'owner_name', p->>'area', coalesce(p->>'ty','svc'), p->>'role', p->>'biz',
          coalesce(p->>'radius','5'),
          coalesce(array(select jsonb_array_elements_text(p->'cats')), '{}'),
          coalesce(array(select jsonb_array_elements_text(p->'subs')), '{}'),
          coalesce(p->'items','{}'::jsonb), p->>'plan', nullif(p->>'rent_until','')::date)
  on conflict (phone) do update set
    shop_name = excluded.shop_name, owner_name = excluded.owner_name, area = excluded.area, ty = excluded.ty,
    role = excluded.role, biz = excluded.biz, radius = excluded.radius, cats = excluded.cats, subs = excluded.subs,
    items = excluded.items, plan = coalesce(excluded.plan, t.plan), rent_until = coalesce(excluded.rent_until, t.rent_until),
    last_seen = now()
  returning * into v;
  return ko_vendor_json(v);
end $$;

create or replace function ko_set_online(p_vendor uuid, p_online boolean) returns void
language sql security definer set search_path = public as $$
  update ko_vendors set online = p_online, last_seen = now() where id = p_vendor
$$;

create or replace function ko_coins_add(p_vendor uuid, p_n int) returns int
language sql security definer set search_path = public as $$
  update ko_vendors set coins = coins + greatest(0, least(p_n, 1000)) where id = p_vendor returning coins
$$;

-- ---------- customer: nayi request ----------
create or replace function ko_lead_create(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l ko_leads; n int;
begin
  if length(coalesce(p->>'service','')) < 2 then raise exception 'service chahiye'; end if;
  insert into ko_leads (customer_name, customer_phone, service, category, icon, need, budget, area, coins)
  values (left(p->>'customer_name',60), left(p->>'customer_phone',15), left(p->>'service',80), left(p->>'category',60),
          left(p->>'icon',8), left(p->>'need',300), nullif(p->>'budget','')::int, left(p->>'area',120), coalesce((p->>'coins')::int,1))
  returning * into l;
  select count(*) into n from ko_vendors v where v.online and ko_matches(v, l);
  return jsonb_build_object('id', l.id, 'vendors', n, 'expires_at', l.expires_at);
end $$;

-- customer: kin vendors ne accept kiya
create or replace function ko_lead_status(p_lead bigint) returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'lead', (select jsonb_build_object('id', l.id, 'service', l.service, 'status', l.status, 'expires_at', l.expires_at) from ko_leads l where l.id = p_lead),
    'vendors', coalesce((select jsonb_agg(jsonb_build_object('shop', v.shop_name, 'owner', v.owner_name, 'phone', v.phone, 'area', v.area, 'role', v.role, 'step', lv.step, 'at', lv.created_at) order by lv.created_at)
      from ko_lead_vendors lv join ko_vendors v on v.id = lv.vendor_id where lv.lead_id = p_lead and lv.status = 'accepted'), '[]'::jsonb))
$$;

-- ---------- vendor: inbox ----------
create or replace function ko_inbox(p_vendor uuid) returns jsonb
language sql security definer set search_path = public as $$
  with me as (update ko_vendors set last_seen = now() where id = p_vendor returning *)
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', l.id, 'name', coalesce(nullif(l.customer_name,''),'Customer'), 'service', l.service, 'category', l.category,
      'icon', l.icon, 'need', l.need, 'budget', l.budget, 'area', l.area, 'coins', l.coins, 'slots', l.slots,
      'taken', (select count(*) from ko_lead_vendors x where x.lead_id = l.id and x.status = 'accepted'),
      'created_at', l.created_at, 'expires_at', l.expires_at) order by l.created_at desc), '[]'::jsonb)
  from ko_leads l, me
  where l.status = 'open' and l.expires_at > now()
    and ko_matches(me, l)
    and not exists (select 1 from ko_lead_vendors x where x.lead_id = l.id and x.vendor_id = p_vendor)
    and (select count(*) from ko_lead_vendors x where x.lead_id = l.id and x.status = 'accepted') < l.slots
$$;

create or replace function ko_lead_accept(p_vendor uuid, p_lead bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l ko_leads; v ko_vendors; taken int;
begin
  select * into l from ko_leads where id = p_lead for update;
  if l.id is null or l.status <> 'open' or l.expires_at < now() then
    return jsonb_build_object('ok', false, 'msg', 'Lead band ho chuki hai');
  end if;
  select count(*) into taken from ko_lead_vendors where lead_id = p_lead and status = 'accepted';
  if taken >= l.slots then return jsonb_build_object('ok', false, 'msg', 'Saari jagah bhar gayi'); end if;
  select * into v from ko_vendors where id = p_vendor for update;
  if v.id is null then return jsonb_build_object('ok', false, 'msg', 'Vendor nahi mila'); end if;
  if v.coins < l.coins then return jsonb_build_object('ok', false, 'msg', 'Coins kam hain — recharge karein', 'coins', v.coins); end if;
  insert into ko_lead_vendors (lead_id, vendor_id, status, step, coins_cut) values (p_lead, p_vendor, 'accepted', 'accept', l.coins)
  on conflict (lead_id, vendor_id) do nothing;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Pehle hi le chuke hain'); end if;
  update ko_vendors set coins = coins - l.coins where id = p_vendor returning coins into v.coins;
  return jsonb_build_object('ok', true, 'coins', v.coins, 'phone', l.customer_phone, 'name', l.customer_name);
end $$;

create or replace function ko_lead_reject(p_vendor uuid, p_lead bigint) returns void
language sql security definer set search_path = public as $$
  insert into ko_lead_vendors (lead_id, vendor_id, status) values (p_lead, p_vendor, 'rejected')
  on conflict (lead_id, vendor_id) do nothing
$$;

create or replace function ko_my_leads(p_vendor uuid) returns jsonb
language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', l.id, 'name', coalesce(nullif(l.customer_name,''),'Customer'), 'phone', l.customer_phone, 'service', l.service,
      'category', l.category, 'icon', l.icon, 'need', l.need, 'budget', l.budget, 'area', l.area, 'coins', lv.coins_cut,
      'step', lv.step, 'created_at', lv.created_at, 'updated_at', lv.updated_at) order by lv.created_at desc), '[]'::jsonb)
  from ko_lead_vendors lv join ko_leads l on l.id = lv.lead_id
  where lv.vendor_id = p_vendor and lv.status = 'accepted'
$$;

create or replace function ko_lead_step(p_vendor uuid, p_lead bigint, p_step text) returns void
language sql security definer set search_path = public as $$
  update ko_lead_vendors set step = p_step, updated_at = now()
  where vendor_id = p_vendor and lead_id = p_lead and status = 'accepted'
    and p_step in ('accept','action','working','reached','done','review')
$$;

revoke execute on function ko_matches(ko_vendors, ko_leads), ko_vendor_json(ko_vendors) from public, anon, authenticated;
grant execute on function ko_vendor_get(text), ko_vendor_save(jsonb), ko_set_online(uuid, boolean), ko_coins_add(uuid, int),
  ko_lead_create(jsonb), ko_lead_status(bigint), ko_inbox(uuid), ko_lead_accept(uuid, bigint), ko_lead_reject(uuid, bigint),
  ko_my_leads(uuid), ko_lead_step(uuid, bigint, text) to anon, authenticated;
