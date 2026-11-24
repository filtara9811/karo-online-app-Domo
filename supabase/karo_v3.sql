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
