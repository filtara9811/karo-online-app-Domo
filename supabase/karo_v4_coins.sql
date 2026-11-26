-- ===== Karo Online v4: Coin engine (5 coin ka poll, barabar bantwara, jaldi-chhoot, wapsi) =====
-- 1 coin = ₹10 · har lead ka "vazan" category se · max 5 vendor · join window · ghost refund · reopen 1+1

alter table ko_vendors add column if not exists wallet numeric(10,2) not null default 0;
alter table ko_vendors add column if not exists held   numeric(10,2) not null default 0;
update ko_vendors set wallet = coins where wallet = 0 and coalesce(coins,0) > 0;

-- purana app `coins` (int) padhta/badhata hai — dono ko sath rakho
create or replace function ko_vendor_wallet_sync() returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    if coalesce(new.wallet,0) = 0 and coalesce(new.coins,0) > 0 then new.wallet := new.coins; end if;
    new.coins := floor(new.wallet)::int; return new;
  end if;
  if new.wallet is distinct from old.wallet then new.coins := floor(new.wallet)::int;
  elsif new.coins is distinct from old.coins then new.wallet := old.wallet + (new.coins - old.coins); end if;
  return new;
end $$;
drop trigger if exists ko_vendor_wallet_sync on ko_vendors;
create trigger ko_vendor_wallet_sync before insert or update on ko_vendors for each row execute function ko_vendor_wallet_sync();

alter table ko_customers add column if not exists wallet  numeric(10,2) not null default 0;
alter table ko_customers add column if not exists welcome boolean not null default false;

alter table ko_leads add column if not exists pool       numeric(6,2);
alter table ko_leads add column if not exists win_coin   numeric(6,2) default 0;
alter table ko_leads add column if not exists cat_key    text;
alter table ko_leads add column if not exists won_vendor uuid;
alter table ko_leads add column if not exists settled    boolean not null default false;
alter table ko_leads add column if not exists done       boolean not null default false;
alter table ko_leads add column if not exists switches   int not null default 0;
alter table ko_leads add column if not exists chat_until timestamptz;

alter table ko_lead_vendors add column if not exists share   numeric(6,2) default 0;
alter table ko_lead_vendors add column if not exists held    numeric(6,2) default 0;
alter table ko_lead_vendors add column if not exists charged numeric(6,2) default 0;
alter table ko_lead_vendors add column if not exists fast    boolean default false;
alter table ko_lead_vendors add column if not exists replied boolean default false;
alter table ko_lead_vendors add column if not exists st      text default 'in';   -- in | won | lost
alter table ko_lead_vendors add column if not exists req     text;                 -- reopen request: 'v' | 'c'

create table if not exists ko_coin_cats (
  key text primary key, label text not null, icon text default '🛠️',
  keys text default '',            -- comma keywords: service/category me ho to ye category
  pool numeric(6,2) not null default 5, win numeric(6,2) not null default 2,
  active boolean not null default true, sort int default 50, updated_at timestamptz default now());

create table if not exists ko_coin_tx (
  id bigserial primary key, created_at timestamptz default now(),
  who text not null default 'v', phone text, vendor_id uuid, lead_id bigint,
  kind text not null,                 -- hold | adj | charge | refund | win | reopen | buy | admin | welcome | penalty
  amount numeric(10,2) default 0,     -- wallet me badlaav (+ aaya / − gaya)
  held_delta numeric(10,2) default 0, -- roke gaye coin me badlaav
  earn numeric(10,2) default 0,       -- company ki kamai (coin)
  note text, test boolean default false);
create index if not exists ko_coin_tx_v on ko_coin_tx(vendor_id, created_at desc);
create index if not exists ko_coin_tx_p on ko_coin_tx(phone, created_at desc);

create table if not exists ko_coin_buys (
  id bigserial primary key, created_at timestamptz default now(), vendor_id uuid, phone text,
  coins numeric(10,2), amount int, utr text, status text default 'pending', done_at timestamptz);

alter table ko_coin_cats enable row level security;
alter table ko_coin_tx   enable row level security;
alter table ko_coin_buys enable row level security;

insert into ko_settings(k,v) values ('coin_cfg', jsonb_build_object(
  'coin_rs',10,'max_vendors',5,'join_hours',2,'fast_min',5,'fast_pct',20,
  'ghost_refund_pct',100,'festival_plus',0,'solo_cap',0,
  'reopen_vendor',1,'reopen_customer',1,'reopen_free_first',true,'max_switch',2,'chat_days',30,
  'welcome_coins',3,'noshow_penalty',3,'noshow_coupon',50,
  'packs',jsonb_build_array(jsonb_build_object('c',10,'rs',100),jsonb_build_object('c',50,'rs',450),jsonb_build_object('c',200,'rs',1600)),
  'commission',jsonb_build_object('upto',500,'flat',5,'pct',2),'delivery_margin',9,'return_fee',10,
  'boost_day',49,'badge_fee',99,'qr_fee',99,
  'dukaan_plans',jsonb_build_array(
     jsonb_build_object('k','free','n','Free','rs',0,'f','20 saamaan · Karo Online ka naam'),
     jsonb_build_object('k','plus','n','Dukaan Plus','rs',199,'f','Unlimited saamaan · 5 video · QR · hisaab'),
     jsonb_build_object('k','pro','n','Dukaan Pro','rs',499,'f','Apna naam link · WhatsApp catalog · Google · Rani AI')),
  'vendor_plans',jsonb_build_array(
     jsonb_build_object('k','start','n','Shuruaat','rs',0,'coins',10,'f','Pehle 30 din 10 coin free'),
     jsonb_build_object('k','silver','n','Silver','rs',299,'coins',40,'f','40 coin + Verified badge'),
     jsonb_build_object('k','gold','n','Gold','rs',999,'coins',150,'f','150 coin + lead sabse pehle + upar dikho'))
)) on conflict (k) do nothing;

insert into ko_coin_cats(key,label,icon,keys,pool,win,sort) values
 ('small','Chhota kaam','🧵','silai,stitch,tailor,darzi,alter,press,iron,ironing,taala,lock,puncture,haircut,tiffin,cake,mehndi',3,1,10),
 ('repair','Repair & Fix','🛠️','repair,plumber,carpenter,electric,bijli,ac,tv,fridge,washing,purifier,geyser,inverter,battery,bike,car wash,car service,mechanic',5,2,20),
 ('clean','Safai','🧹','clean,safai,sofa,bathroom,window,pest,tank',5,2,30),
 ('beauty','Salon & Beauty','💇','salon,beauty,parlour,massage,spa,facial,makeup',4,1.5,40),
 ('pro','Legal / Finance','⚖️','legal,lawyer,vakil,notary,court,tax,gst,loan,bank,finance,chartered',10,3,8),
 ('big','Bada kaam','🏗️','shifting,packers,movers,interior,catering,wedding,shaadi,bridal,construction,renovation,event,decor',15,5,5),
 ('default','Baaki sab','📌','',5,2,99)
on conflict (key) do nothing;

-- ---------- madadgaar ----------
create or replace function ko_coin_conf() returns jsonb language sql stable security definer set search_path=public as $$
  select coalesce((select v from ko_settings where k='coin_cfg'),'{}'::jsonb) $$;

create or replace function ko_coin_cat_for(p_cat text, p_svc text) returns ko_coin_cats language sql stable security definer set search_path=public as $$
  select c.* from ko_coin_cats c
  where c.active and (c.key='default' or exists (select 1 from unnest(string_to_array(c.keys,',')) k
        where trim(k)<>'' and (coalesce(p_svc,'')||' '||coalesce(p_cat,'')) ~* ('\m'||regexp_replace(trim(k),'([^a-zA-Z0-9 ])','\\\1','g'))))
  order by (c.key='default'), c.sort limit 1 $$;

create or replace function ko_tx(p_who text, p_phone text, p_vendor uuid, p_lead bigint, p_kind text, p_amt numeric, p_held numeric, p_earn numeric, p_note text, p_test boolean default false)
returns void language sql security definer set search_path=public as $$
  insert into ko_coin_tx(who,phone,vendor_id,lead_id,kind,amount,held_delta,earn,note,test)
  values (p_who,p_phone,p_vendor,p_lead,p_kind,round(coalesce(p_amt,0),2),round(coalesce(p_held,0),2),round(coalesce(p_earn,0),2),left(p_note,140),coalesce(p_test,false)) $$;

-- ---------- bantwara: jitne jude, utne me pool baraabar; jaldi aane wale ko chhoot ----------
create or replace function ko_lead_resplit(p_lead bigint) returns void language plpgsql security definer set search_path=public as $$
declare l ko_leads; c jsonb := ko_coin_conf(); n int; m record; base numeric; sh numeric; d numeric; cap numeric; t boolean;
begin
  select * into l from ko_leads where id=p_lead for update;
  if l.settled then return; end if;
  t := coalesce(l.kind,'')='test';
  select count(*) into n from ko_lead_vendors where lead_id=p_lead and status='accepted';
  if n=0 then return; end if;
  base := l.pool / n; cap := coalesce((c->>'solo_cap')::numeric,0);
  for m in select * from ko_lead_vendors where lead_id=p_lead and status='accepted' for update loop
    sh := base * case when m.fast then (1 - coalesce((c->>'fast_pct')::numeric,0)/100) else 1 end;
    if n=1 and cap>0 then sh := least(sh,cap); end if;
    sh := round(sh,2); d := round(m.held - sh,2);
    if d<>0 then
      update ko_vendors set wallet=wallet+d, held=held-d where id=m.vendor_id;
      perform ko_tx('v',null,m.vendor_id,p_lead,'adj',d,-d,0, case when d>0 then n||' vendor jude — '||d||' coin wapas' else 'hissa badla' end, t);
    end if;
    update ko_lead_vendors set share=sh, held=sh, coins_cut=ceil(sh)::int where lead_id=p_lead and vendor_id=m.vendor_id;
  end loop;
end $$;

-- ---------- hisaab pakka: jisse grahak ne baat ki uska kata, baaki wapas ----------
create or replace function ko_lead_settle(p_lead bigint) returns void language plpgsql security definer set search_path=public as $$
declare l ko_leads; c jsonb := ko_coin_conf(); m record; pct numeric; back numeric; t boolean;
begin
  select * into l from ko_leads where id=p_lead for update;
  if l.id is null or l.settled then return; end if;
  t := coalesce(l.kind,'')='test'; pct := coalesce((c->>'ghost_refund_pct')::numeric,100);
  for m in select * from ko_lead_vendors where lead_id=p_lead and status='accepted' and held>0 for update loop
    if m.replied then
      update ko_vendors set held=held-m.held where id=m.vendor_id;
      update ko_lead_vendors set charged=charged+m.held, held=0 where lead_id=p_lead and vendor_id=m.vendor_id;
      perform ko_tx('v',null,m.vendor_id,p_lead,'charge',0,-m.held,m.held,'Lead ka hissa kata',t);
    else
      back := round(m.held*pct/100,2);
      update ko_vendors set held=held-m.held, wallet=wallet+back where id=m.vendor_id;
      update ko_lead_vendors set charged=charged+(m.held-back), held=0 where lead_id=p_lead and vendor_id=m.vendor_id;
      perform ko_tx('v',null,m.vendor_id,p_lead,'refund',back,-m.held,m.held-back,'Grahak ne baat nahi ki — coin wapas',t);
    end if;
  end loop;
  update ko_leads set settled=true, status=case when status='open' then 'closed' else status end where id=p_lead;
end $$;

-- ---------- request banna: category se coin ----------
create or replace function ko_lead_create(p jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare l ko_leads; n int; k text := case when p->>'kind'='order' then 'order' when p->>'kind'='test' then 'test' else 'lead' end;
        c jsonb := ko_coin_conf(); cc ko_coin_cats; pool numeric;
begin
  if length(coalesce(p->>'service','')) < 2 then raise exception 'service chahiye'; end if;
  cc := ko_coin_cat_for(p->>'category', p->>'service');
  pool := greatest(0.5, coalesce(cc.pool,5) + coalesce((c->>'festival_plus')::numeric,0) + coalesce((p->>'area_adj')::numeric,0));
  insert into ko_leads (customer_name, customer_phone, service, category, icon, need, budget, area, coins, kind, slots, expires_at, pool, win_coin, cat_key)
  values (left(p->>'customer_name',60), right(regexp_replace(coalesce(p->>'customer_phone',''),'\D','','g'),10), left(p->>'service',80), left(p->>'category',60),
          left(p->>'icon',8), left(p->>'need',300), nullif(p->>'budget','')::int, left(p->>'area',120),
          case when k='order' then 0 else ceil(pool)::int end, k,
          coalesce((c->>'max_vendors')::int,5), now() + make_interval(mins => (coalesce((c->>'join_hours')::numeric,2)*60)::int),
          case when k='order' then 0 else pool end, case when k='order' then 0 else coalesce(cc.win,2) end, cc.key)
  returning * into l;
  select count(*) into n from ko_vendors v where v.online and ko_matches(v, l);
  return jsonb_build_object('id', l.id, 'vendors', n, 'expires_at', l.expires_at, 'pool', l.pool, 'cat', cc.label, 'win', l.win_coin);
end $$;

-- ---------- vendor judta hai: apna hissa roko, phir sab ka baraabar karo ----------
create or replace function ko_lead_accept(p_vendor uuid, p_lead bigint) returns jsonb language plpgsql security definer set search_path=public as $$
declare l ko_leads; v ko_vendors; taken int; c jsonb := ko_coin_conf(); fast boolean; need numeric; t boolean; mv ko_lead_vendors;
begin
  select * into l from ko_leads where id = p_lead for update;
  if l.id is null or l.status <> 'open' or l.expires_at < now() or l.settled then
    return jsonb_build_object('ok', false, 'msg', 'Lead band ho chuki hai'); end if;
  if l.pool is null then update ko_leads set pool=coalesce(nullif(coins,0),5), win_coin=2 where id=p_lead returning * into l; end if;
  select count(*) into taken from ko_lead_vendors where lead_id = p_lead and status = 'accepted';
  if taken >= least(l.slots, coalesce((c->>'max_vendors')::int,5)) then return jsonb_build_object('ok', false, 'msg', 'Saari jagah bhar gayi (max '||l.slots||')'); end if;
  select * into v from ko_vendors where id = p_vendor for update;
  if v.id is null then return jsonb_build_object('ok', false, 'msg', 'Vendor nahi mila'); end if;
  t := coalesce(l.kind,'')='test';
  fast := now() <= l.created_at + make_interval(mins => coalesce((c->>'fast_min')::int,5));
  need := round(l.pool/(taken+1) * case when fast then (1-coalesce((c->>'fast_pct')::numeric,0)/100) else 1 end, 2);
  if taken=0 and coalesce((c->>'solo_cap')::numeric,0)>0 then need := least(need,(c->>'solo_cap')::numeric); end if;
  if v.wallet < need then return jsonb_build_object('ok', false, 'msg', 'Coin kam hain — '||need||' chahiye, aapke paas '||v.wallet, 'coins', v.coins, 'need', need); end if;
  insert into ko_lead_vendors (lead_id, vendor_id, status, step, coins_cut, share, held, fast, st)
  values (p_lead, p_vendor, 'accepted', 'accept', ceil(need)::int, need, need, fast, 'in')
  on conflict (lead_id, vendor_id) do nothing;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Pehle hi le chuke hain'); end if;
  update ko_vendors set wallet = wallet - need, held = held + need where id = p_vendor;
  perform ko_tx('v',v.phone,p_vendor,p_lead,'hold',-need,need,0,'Lead li — '||need||' coin roke'||case when fast then ' (jaldi chhoot)' else '' end,t);
  perform ko_lead_resplit(p_lead);
  select * into v from ko_vendors where id = p_vendor;
  select * into mv from ko_lead_vendors where lead_id=p_lead and vendor_id=p_vendor;
  return jsonb_build_object('ok', true, 'coins', v.coins, 'wallet', v.wallet, 'held', mv.held, 'fast', fast, 'vendors', taken+1,
                            'phone', l.customer_phone, 'name', l.customer_name);
end $$;

-- ---------- grahak ne jawab diya (p_vendor null = sabko) ----------
create or replace function ko_lead_reply(p_lead bigint, p_phone text, p_vendor uuid default null) returns jsonb language plpgsql security definer set search_path=public as $$
declare l ko_leads;
begin
  select * into l from ko_leads where id=p_lead;
  if l.id is null or l.customer_phone <> right(regexp_replace(coalesce(p_phone,''),'\D','','g'),10) then raise exception 'ye request aapki nahi'; end if;
  update ko_lead_vendors set replied=true where lead_id=p_lead and status='accepted' and st in ('in','won') and (p_vendor is null or vendor_id=p_vendor);
  return jsonb_build_object('ok',true);
end $$;

-- ---------- grahak ne ek ko chuna: baaki band, hisaab pakka ----------
create or replace function ko_lead_pick(p_lead bigint, p_phone text, p_vendor uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare l ko_leads; c jsonb := ko_coin_conf();
begin
  select * into l from ko_leads where id=p_lead for update;
  if l.id is null or l.customer_phone <> right(regexp_replace(coalesce(p_phone,''),'\D','','g'),10) then raise exception 'ye request aapki nahi'; end if;
  if l.won_vendor is not null then raise exception 'pehle hi chun liya — dobara baat ke liye reopen karein'; end if;
  if not exists (select 1 from ko_lead_vendors where lead_id=p_lead and vendor_id=p_vendor and status='accepted') then raise exception 'ye vendor is request me nahi'; end if;
  update ko_lead_vendors set replied=true where lead_id=p_lead and vendor_id=p_vendor;
  update ko_lead_vendors set st = case when vendor_id=p_vendor then 'won' else 'lost' end, req=null where lead_id=p_lead and status='accepted';
  update ko_leads set won_vendor=p_vendor, status='won', chat_until=now()+make_interval(days => coalesce((c->>'chat_days')::int,30)) where id=p_lead;
  perform ko_lead_settle(p_lead);
  return jsonb_build_object('ok',true);
end $$;

-- ---------- kaam poora: jeetne wale se jeet ka coin ----------
create or replace function ko_lead_done(p_lead bigint, p_phone text) returns jsonb language plpgsql security definer set search_path=public as $$
declare l ko_leads; v ko_vendors;
begin
  select * into l from ko_leads where id=p_lead for update;
  if l.id is null or l.customer_phone <> right(regexp_replace(coalesce(p_phone,''),'\D','','g'),10) then raise exception 'ye request aapki nahi'; end if;
  if l.won_vendor is null then raise exception 'pehle vendor chunein'; end if;
  if l.done then return jsonb_build_object('ok',true,'already',true); end if;
  select * into v from ko_vendors where id=l.won_vendor for update;
  update ko_vendors set wallet=wallet-l.win_coin where id=v.id;
  perform ko_tx('v',v.phone,v.id,p_lead,'win',-l.win_coin,0,l.win_coin,'Kaam poora — jeet ka coin',coalesce(l.kind,'')='test');
  update ko_leads set done=true, status='done' where id=p_lead;
  return jsonb_build_object('ok',true,'win',l.win_coin);
end $$;

-- ---------- dobara baat: ek taraf request, doosri taraf haan → 1+1 coin ----------
create or replace function ko_lead_reopen_req(p_lead bigint, p_by text, p_phone text, p_vendor uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare l ko_leads; m ko_lead_vendors;
begin
  select * into l from ko_leads where id=p_lead;
  if l.id is null then raise exception 'request nahi mili'; end if;
  if p_by='c' and l.customer_phone <> right(regexp_replace(coalesce(p_phone,''),'\D','','g'),10) then raise exception 'ye request aapki nahi'; end if;
  select * into m from ko_lead_vendors where lead_id=p_lead and vendor_id=p_vendor and status='accepted';
  if m.lead_id is null or m.st<>'lost' then raise exception 'ye vendor band nahi hai'; end if;
  update ko_lead_vendors set req=case when p_by='v' then 'v' else 'c' end where lead_id=p_lead and vendor_id=p_vendor;
  return jsonb_build_object('ok',true);
end $$;

create or replace function ko_lead_reopen_ok(p_lead bigint, p_by text, p_phone text, p_vendor uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare l ko_leads; m ko_lead_vendors; c jsonb := ko_coin_conf(); v ko_vendors; cu ko_customers; vc numeric; cc numeric; t boolean; ph text;
begin
  select * into l from ko_leads where id=p_lead for update;
  if l.id is null then raise exception 'request nahi mili'; end if;
  ph := l.customer_phone; t := coalesce(l.kind,'')='test';
  if p_by='c' and ph <> right(regexp_replace(coalesce(p_phone,''),'\D','','g'),10) then raise exception 'ye request aapki nahi'; end if;
  select * into m from ko_lead_vendors where lead_id=p_lead and vendor_id=p_vendor and status='accepted' for update;
  if m.lead_id is null or m.st<>'lost' then raise exception 'ye vendor band nahi hai'; end if;
  if m.req is null or m.req=p_by then raise exception 'pehle doosri taraf se request chahiye'; end if;
  if l.switches >= coalesce((c->>'max_switch')::int,2) then raise exception 'is request me ab aur badlaav nahi (max %)', (c->>'max_switch'); end if;
  vc := coalesce((c->>'reopen_vendor')::numeric,1);
  cc := case when coalesce((c->>'reopen_free_first')::boolean,true) and l.switches=0 then 0 else coalesce((c->>'reopen_customer')::numeric,1) end;
  select * into v from ko_vendors where id=p_vendor for update;
  if v.wallet < vc then raise exception 'vendor ke paas coin kam hain'; end if;
  if cc>0 then
    select * into cu from ko_customers where phone=ph for update;
    if cu.phone is null or cu.wallet < cc then raise exception 'aapke paas coin kam hain (% chahiye)', cc; end if;
    update ko_customers set wallet=wallet-cc where phone=ph;
    perform ko_tx('c',ph,null,p_lead,'reopen',-cc,0,cc,'Dobara baat — grahak ka coin',t);
  end if;
  update ko_vendors set wallet=wallet-vc where id=p_vendor;
  perform ko_tx('v',v.phone,p_vendor,p_lead,'reopen',-vc,0,vc,'Dobara baat — vendor ka coin',t);
  update ko_lead_vendors set st='lost' where lead_id=p_lead and st='won';
  update ko_lead_vendors set st='won', req=null, replied=true where lead_id=p_lead and vendor_id=p_vendor;
  update ko_leads set won_vendor=p_vendor, switches=switches+1, done=false, chat_until=now()+make_interval(days => coalesce((c->>'chat_days')::int,30)) where id=p_lead;
  return jsonb_build_object('ok',true,'vendor_coin',vc,'customer_coin',cc);
end $$;

-- ---------- samay khatam: band karo, ghost lead ka coin wapas ----------
create or replace function ko_lead_tick() returns int language plpgsql security definer set search_path=public as $$
declare r record; n int := 0;
begin
  for r in select id from ko_leads where not settled and coalesce(kind,'')<>'order' and expires_at + interval '24 hours' < now() limit 200 loop
    perform ko_lead_settle(r.id); n := n+1; end loop;
  return n;
end $$;

-- ---------- grahak ka wallet (pehli baar welcome coin) ----------
create or replace function ko_cust_wallet(p_phone text) returns jsonb language plpgsql security definer set search_path=public as $$
declare ph text := right(regexp_replace(coalesce(p_phone,''),'\D','','g'),10); cu ko_customers; w numeric := coalesce((ko_coin_conf()->>'welcome_coins')::numeric,0);
begin
  if length(ph)<10 then raise exception 'mobile number sahi nahi'; end if;
  insert into ko_customers(phone) values (ph) on conflict (phone) do nothing;
  select * into cu from ko_customers where phone=ph for update;
  if not cu.welcome and w>0 then
    update ko_customers set wallet=wallet+w, welcome=true where phone=ph returning * into cu;
    perform ko_tx('c',ph,null,null,'welcome',w,0,0,'Swagat coin');
  end if;
  return jsonb_build_object('phone',ph,'wallet',cu.wallet,
    'tx',coalesce((select jsonb_agg(jsonb_build_object('k',kind,'a',amount,'n',note,'t',created_at) order by created_at desc) from (select * from ko_coin_tx where who='c' and phone=ph order by created_at desc limit 30) x),'[]'::jsonb));
end $$;

-- ---------- vendor wallet (Digital Dukaan ke phone+PIN se) ----------
create or replace function ko_vendor_for_shop(p_phone text, p_pin text) returns ko_vendors language plpgsql security definer set search_path=public as $$
declare ph text := right(regexp_replace(coalesce(p_phone,''),'\D','','g'),10); s ko_shops; v ko_vendors;
begin
  s := ko_shop_pin_check(ph, p_pin);
  if s.phone is null then raise exception 'galat PIN'; end if;
  select * into v from ko_vendors where phone=ph limit 1;
  if v.id is null then
    insert into ko_vendors(phone, shop_name) values (ph, coalesce(s.data->>'name','Dukaan')) returning * into v;
  end if;
  return v;
end $$;

create or replace function ko_wallet_json(v ko_vendors) returns jsonb language sql stable security definer set search_path=public as $$
  select jsonb_build_object('vendor',v.id,'phone',v.phone,'wallet',v.wallet,'held',v.held,
    'tx',coalesce((select jsonb_agg(jsonb_build_object('k',kind,'a',amount,'h',held_delta,'n',note,'l',lead_id,'t',created_at) order by created_at desc) from (select * from ko_coin_tx where vendor_id=v.id order by created_at desc limit 40) x),'[]'::jsonb),
    'buys',coalesce((select jsonb_agg(jsonb_build_object('id',id,'c',coins,'rs',amount,'s',status,'t',created_at) order by created_at desc) from (select * from ko_coin_buys where vendor_id=v.id order by created_at desc limit 10) y),'[]'::jsonb),
    'spent30',coalesce((select sum(earn) from ko_coin_tx where vendor_id=v.id and created_at>now()-interval '30 days'),0),
    'back30',coalesce((select sum(amount) from ko_coin_tx where vendor_id=v.id and kind in ('adj','refund') and created_at>now()-interval '30 days'),0)) $$;

create or replace function ko_wallet_shop(p_phone text, p_pin text) returns jsonb language plpgsql security definer set search_path=public as $$
begin return ko_wallet_json(ko_vendor_for_shop(p_phone,p_pin)); end $$;

create or replace function ko_wallet_vendor(p_vendor uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare v ko_vendors; begin select * into v from ko_vendors where id=p_vendor; if v.id is null then raise exception 'vendor nahi mila'; end if; return ko_wallet_json(v); end $$;

create or replace function ko_coin_buy(p_phone text, p_pin text, p_pack int, p_utr text) returns jsonb language plpgsql security definer set search_path=public as $$
declare v ko_vendors := ko_vendor_for_shop(p_phone,p_pin); pk jsonb;
begin
  pk := (ko_coin_conf()->'packs')->p_pack;
  if pk is null then raise exception 'pack nahi mila'; end if;
  if length(coalesce(trim(p_utr),''))<6 then raise exception 'UTR / transaction number daalein'; end if;
  if (select count(*) from ko_coin_buys where vendor_id=v.id and status='pending')>=3 then raise exception 'pehle wali request ki jaanch chal rahi hai'; end if;
  insert into ko_coin_buys(vendor_id,phone,coins,amount,utr) values (v.id,v.phone,(pk->>'c')::numeric,(pk->>'rs')::int,left(trim(p_utr),40));
  return ko_wallet_json(v);
end $$;

-- ---------- public: niyam padho ----------
create or replace function ko_coin_cfg() returns jsonb language sql stable security definer set search_path=public as $$
  select jsonb_build_object('cfg',ko_coin_conf(),'cats',coalesce((select jsonb_agg(to_jsonb(c) order by c.sort) from ko_coin_cats c),'[]'::jsonb)) $$;

-- ---------- admin ----------
create or replace function ko_coin_cfg_set(p_pin text, p_cfg jsonb, p_cats jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare x jsonb;
begin
  if not ko_pin_ok(p_pin) then raise exception 'galat admin PIN'; end if;
  if p_cfg is not null then update ko_settings set v = ko_coin_conf() || p_cfg, updated_at=now() where k='coin_cfg'; end if;
  if p_cats is not null then
    for x in select * from jsonb_array_elements(p_cats) loop
      if coalesce(x->>'del','')='1' and x->>'key'<>'default' then delete from ko_coin_cats where key=x->>'key'; continue; end if;
      insert into ko_coin_cats(key,label,icon,keys,pool,win,active,sort,updated_at)
      values (lower(regexp_replace(x->>'key','[^a-zA-Z0-9_]','','g')), left(x->>'label',40), left(coalesce(x->>'icon','🛠️'),8), left(coalesce(x->>'keys',''),400),
              greatest(0.5,least(100,(x->>'pool')::numeric)), greatest(0,least(100,coalesce((x->>'win')::numeric,0))), coalesce((x->>'active')::boolean,true), coalesce((x->>'sort')::int,50), now())
      on conflict (key) do update set label=excluded.label, icon=excluded.icon, keys=excluded.keys, pool=excluded.pool, win=excluded.win, active=excluded.active, sort=excluded.sort, updated_at=now();
    end loop;
  end if;
  return ko_coin_cfg();
end $$;

create or replace function ko_admin_coin(p_pin text) returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if not ko_pin_ok(p_pin) then raise exception 'galat admin PIN'; end if;
  perform ko_lead_tick();
  return ko_coin_cfg() || jsonb_build_object(
    'earn', coalesce((select jsonb_object_agg(kind, s) from (select kind, sum(earn) s from ko_coin_tx where not test and earn<>0 group by kind) a),'{}'::jsonb),
    'earn30', coalesce((select sum(earn) from ko_coin_tx where not test and created_at>now()-interval '30 days'),0),
    'earn_today', coalesce((select sum(earn) from ko_coin_tx where not test and created_at>date_trunc('day',now())),0),
    'held', coalesce((select sum(held) from ko_vendors),0), 'wallets', coalesce((select sum(wallet) from ko_vendors),0),
    'cust_wallets', coalesce((select sum(wallet) from ko_customers),0),
    'vendors', coalesce((select jsonb_agg(jsonb_build_object('id',id,'phone',phone,'name',shop_name,'w',wallet,'h',held,'on',online) order by wallet desc) from (select * from ko_vendors where phone not like 'TEST%' order by wallet desc limit 100) v),'[]'::jsonb),
    'buys', coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'phone',b.phone,'c',b.coins,'rs',b.amount,'utr',b.utr,'s',b.status,'t',b.created_at) order by b.created_at desc) from (select * from ko_coin_buys order by created_at desc limit 40) b),'[]'::jsonb),
    'leads', coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'svc',l.service,'cat',l.cat_key,'pool',l.pool,'win',l.win_coin,'st',l.status,'settled',l.settled,'done',l.done,'sw',l.switches,'test',coalesce(l.kind,'')='test','t',l.created_at,
        'm',coalesce((select jsonb_agg(jsonb_build_object('v',coalesce(v.shop_name,v.phone),'sh',m.share,'h',m.held,'ch',m.charged,'f',m.fast,'r',m.replied,'st',m.st) order by m.created_at) from ko_lead_vendors m join ko_vendors v on v.id=m.vendor_id where m.lead_id=l.id and m.status='accepted'),'[]'::jsonb))
        order by l.created_at desc) from (select * from ko_leads where coalesce(kind,'')<>'order' order by created_at desc limit 25) l),'[]'::jsonb));
end $$;

create or replace function ko_admin_coin_add(p_pin text, p_phone text, p_coins numeric, p_note text) returns jsonb language plpgsql security definer set search_path=public as $$
declare ph text := right(regexp_replace(coalesce(p_phone,''),'\D','','g'),10); v ko_vendors;
begin
  if not ko_pin_ok(p_pin) then raise exception 'galat admin PIN'; end if;
  if p_coins is null or p_coins=0 or abs(p_coins)>10000 then raise exception 'coin sahi nahi'; end if;
  select * into v from ko_vendors where phone=ph limit 1;
  if v.id is null then insert into ko_vendors(phone,shop_name) values (ph,'Dukaan '||right(ph,4)) returning * into v; end if;
  update ko_vendors set wallet=wallet+p_coins where id=v.id;
  perform ko_tx('v',ph,v.id,null,'admin',p_coins,0,0,coalesce(nullif(p_note,''),'Admin ne diye'));
  return jsonb_build_object('ok',true);
end $$;

create or replace function ko_admin_buy_set(p_pin text, p_id bigint, p_ok boolean) returns jsonb language plpgsql security definer set search_path=public as $$
declare b ko_coin_buys;
begin
  if not ko_pin_ok(p_pin) then raise exception 'galat admin PIN'; end if;
  select * into b from ko_coin_buys where id=p_id for update;
  if b.id is null or b.status<>'pending' then raise exception 'request nahi mili'; end if;
  update ko_coin_buys set status=case when p_ok then 'ok' else 'no' end, done_at=now() where id=p_id;
  if p_ok then
    update ko_vendors set wallet=wallet+b.coins where id=b.vendor_id;
    perform ko_tx('v',b.phone,b.vendor_id,null,'buy',b.coins,0,0,b.coins||' coin kharide · ₹'||b.amount);
  end if;
  return jsonb_build_object('ok',true);
end $$;

-- ---------- admin: niyam ki jaanch (test lead, test vendor — kamai me nahi gini jaati) ----------
create or replace function ko_admin_coin_sim(p_pin text, p_svc text, p_n int, p_pick int, p_reply int[]) returns jsonb language plpgsql security definer set search_path=public as $$
declare lid bigint; ids uuid[] := '{}'; i int; v ko_vendors; r jsonb; out jsonb := '[]'::jsonb; ph text := '9999900000';
begin
  if not ko_pin_ok(p_pin) then raise exception 'galat admin PIN'; end if;
  p_n := greatest(1,least(coalesce(p_n,3),6));
  insert into ko_customers(phone,name) values (ph,'Test grahak') on conflict (phone) do nothing;
  r := ko_lead_create(jsonb_build_object('service',coalesce(nullif(p_svc,''),'Pant silai'),'customer_phone',ph,'customer_name','Test grahak','kind','test'));
  lid := (r->>'id')::bigint;
  out := out || jsonb_build_array(jsonb_build_object('s','Request bani: '||(r->>'cat')||' · pool '||(r->>'pool')||' coin · jeet '||(r->>'win')));
  for i in 1..p_n loop
    select * into v from ko_vendors where phone='TEST'||i;
    if v.id is null then insert into ko_vendors(phone,shop_name,wallet) values ('TEST'||i,'Test Vendor '||i,50) returning * into v;
    else update ko_vendors set wallet=greatest(wallet,50) where id=v.id; end if;
    if i>1 then update ko_leads set created_at=created_at-interval '10 minutes' where id=lid and i=2; end if; -- pehla "jaldi", baaki normal
    r := ko_lead_accept(v.id, lid); ids := ids || v.id;
    out := out || jsonb_build_array(jsonb_build_object('s','Vendor '||i||' juda'||case when (r->>'fast')::boolean then ' ⚡ jaldi' else '' end||' → '||(r->>'vendors')||' vendor',
      'm',(select jsonb_agg(jsonb_build_object('v','V'||right(vv.phone,1),'h',m.held) order by m.created_at) from ko_lead_vendors m join ko_vendors vv on vv.id=m.vendor_id where m.lead_id=lid)));
  end loop;
  if p_reply is not null then foreach i in array p_reply loop if i between 1 and p_n then perform ko_lead_reply(lid,ph,ids[i]); end if; end loop; end if;
  if p_pick between 1 and p_n then
    perform ko_lead_pick(lid,ph,ids[p_pick]);
    out := out || jsonb_build_array(jsonb_build_object('s','Grahak ne Vendor '||p_pick||' chuna → hisaab pakka',
      'm',(select jsonb_agg(jsonb_build_object('v','V'||right(vv.phone,1),'ch',m.charged,'r',m.replied,'st',m.st) order by m.created_at) from ko_lead_vendors m join ko_vendors vv on vv.id=m.vendor_id where m.lead_id=lid)));
    perform ko_lead_done(lid,ph);
    out := out || jsonb_build_array(jsonb_build_object('s','Kaam poora → Vendor '||p_pick||' se jeet ka coin'));
  else
    perform ko_lead_settle(lid);
    out := out || jsonb_build_array(jsonb_build_object('s','Kisi ko nahi chuna → samay khatam, hisaab pakka',
      'm',(select jsonb_agg(jsonb_build_object('v','V'||right(vv.phone,1),'ch',m.charged,'r',m.replied) order by m.created_at) from ko_lead_vendors m join ko_vendors vv on vv.id=m.vendor_id where m.lead_id=lid)));
  end if;
  return jsonb_build_object('lead',lid,'steps',out,'company',(select coalesce(sum(earn),0) from ko_coin_tx where lead_id=lid));
end $$;

revoke all on function ko_tx(text,text,uuid,bigint,text,numeric,numeric,numeric,text,boolean) from anon, authenticated, public;
revoke all on function ko_lead_resplit(bigint) from anon, authenticated, public;
revoke all on function ko_lead_settle(bigint) from anon, authenticated, public;
revoke all on function ko_vendor_for_shop(text,text) from anon, authenticated, public;
revoke all on function ko_wallet_json(ko_vendors) from anon, authenticated, public;
