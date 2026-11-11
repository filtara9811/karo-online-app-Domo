-- Karo v3 security + logic tests (local Postgres)
-- Chalane ka tareeka: supabase/tests/run.sh
\set ON_ERROR_STOP 1
\set QUIET 1
\o /dev/null

-- ---------- setup (postgres = admin) ----------
insert into auth.users (id, phone) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', '919876500001'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', '919876500002'),
  ('cccccccc-0000-0000-0000-00000000000c', '919876500003');

-- Purani (v1) dukaan jiska user_id nahi — pehli login par phone se judni chahiye
insert into ko_vendors (phone, shop_name, subs, coins) values ('9876500003', 'Purani Dukaan', '{Plumber}', 40);

-- helper: test fail ho to saaf message
create or replace function t_expect_error(p_sql text, p_like text) returns void language plpgsql as $$
begin
  execute p_sql;
  raise exception 'EXPECTED ERROR (%), but succeeded: %', p_like, p_sql;
exception when others then
  if sqlerrm like 'EXPECTED ERROR%' then raise; end if;
  if sqlerrm not ilike '%' || p_like || '%' then raise exception 'wrong error for %: % (wanted %)', p_sql, sqlerrm, p_like; end if;
end $$;
grant execute on function t_expect_error(text, text) to anon, authenticated, service_role;

-- =========================================================
\echo '1. anon: vendor functions + tables band'
set role anon;
select t_expect_error('select ko_me()', 'permission denied');
select t_expect_error('select ko_coins_add(1000)', 'permission denied');
select t_expect_error('select ko_inbox()', 'permission denied');
select t_expect_error('select ko_coins_credit(gen_random_uuid(), 10, ''x'')', 'permission denied');
select t_expect_error('select ko_plan_activate(gen_random_uuid(), ''p100'', 30, ''x'')', 'permission denied');
select t_expect_error('select ko_matches(null::ko_vendors, null::ko_leads)', 'permission denied');
do $$ begin assert (select count(*) from ko_vendors) = 0, 'anon ko_vendors padh paya (RLS)'; end $$;
do $$ begin assert (select count(*) from ko_leads) = 0, 'anon ko_leads padh paya (RLS)'; end $$;
reset role;

-- =========================================================
\echo '2. vendor A join: phone auth se, coins client se nahi badalte'
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', false);
do $$ begin assert ko_me() is null, 'naye user ki dukaan nahi honi chahiye'; end $$;
do $$ declare v jsonb; begin
  v := ko_vendor_save('{"phone":"9999999999","shop_name":"A Plumbing","subs":["Plumber","AC"],"cats":["Home Services"],
        "coins":99999,"plan":"p100","radius":"5","lat":28.6139,"lng":77.2090}'::jsonb);
  assert v->>'phone' = '9876500001', 'phone auth se aana chahiye, mila: ' || (v->>'phone');
  assert (v->>'coins')::int = 100, 'signup coins 100 hone chahiye, mila: ' || (v->>'coins');
  assert v->>'plan' = 'p100' and (v->>'rent_until')::date = current_date + 30, 'demo mode me p100 = 30 din';
  assert not (v ? 'user_id'), 'user_id bahar nahi jaana chahiye';
end $$;
do $$ begin assert (select count(*) from ko_vendors) = 0, 'authenticated tables seedha padh paya (RLS)'; end $$;

\echo '3. vendor B join'
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-00000000000b', false);
do $$ declare v jsonb; begin
  v := ko_vendor_save('{"shop_name":"B Cool Air","subs":["AC Repair"],"radius":"5","lat":28.62,"lng":77.21,"plan":"trial"}'::jsonb);
  assert (v->>'rent_until')::date = current_date + 7, 'trial = 7 din';
  -- trial dobara nahi
  v := ko_vendor_save('{"shop_name":"B Cool Air","plan":"trial"}'::jsonb);
  assert (v->>'rent_until')::date = current_date + 7, 'trial dobara nahi milna chahiye';
  assert (v->'subs')->>0 = 'AC Repair', 'subs na bheje to purane rahein';
end $$;

\echo '4. purani dukaan pehli login par phone se judti hai'
select set_config('request.jwt.claim.sub', 'cccccccc-0000-0000-0000-00000000000c', false);
do $$ declare v jsonb; begin
  v := ko_me();
  assert v->>'shop_name' = 'Purani Dukaan' and (v->>'coins')::int = 40, 'purani dukaan nahi judi';
end $$;
reset role;

-- =========================================================
\echo '5. customer (anon) lead banata hai — token milta hai'
set role anon;
select set_config('request.jwt.claim.sub', '', false);
create temp table t_lead as select ko_lead_create('{"customer_name":"Ravi","customer_phone":"+91 98111 22334","service":"AC Repair",
  "need":"AC thanda nahi","budget":"₹500","lat":28.615,"lng":77.205}'::jsonb) j;
do $$ declare j jsonb := (select j from t_lead); begin
  assert j ? 'token', 'token nahi mila';
  assert (j->>'vendors')::int = 2, 'A (AC) + B (AC Repair) = 2 vendor, mila: ' || (j->>'vendors');
end $$;
-- Mumbai ki lead — Delhi wale vendors (5 km) ko nahi
create temp table t_far as select ko_lead_create('{"service":"AC Repair","lat":19.07,"lng":72.87}'::jsonb) j;
do $$ begin assert ((select j from t_far)->>'vendors')::int = 0, 'door ki lead match nahi honi chahiye'; end $$;
-- "Coaching" me "ac" match nahi
create temp table t_coach as select ko_lead_create('{"service":"Coaching","lat":28.615,"lng":77.205}'::jsonb) j;
do $$ begin assert ((select j from t_coach)->>'vendors')::int = 0, '"AC" ko "Coaching" se match nahi hona chahiye'; end $$;
-- token ke bina status nahi
select t_expect_error(format('select ko_lead_status(%s)', (select j->>'id' from t_lead)), 'nahi mili');
select t_expect_error(format('select ko_lead_status(%s, gen_random_uuid())', (select j->>'id' from t_lead)), 'nahi mili');
grant select on t_lead, t_far, t_coach to authenticated;
reset role;

-- =========================================================
\echo '6. inbox + accept: coin katta hai, ledger banta hai'
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', false);
do $$ declare ib jsonb := ko_inbox(); id bigint := ((select j from t_lead)->>'id')::bigint; r jsonb; begin
  assert jsonb_array_length(ib) = 1 and (ib->0->>'id')::bigint = id, 'A ke inbox me 1 lead: ' || ib::text;
  assert not (ib->0 ? 'phone'), 'inbox me customer phone nahi dikhna chahiye';
  assert (ib->0->>'km')::numeric < 2, 'km dikhna chahiye';
  r := ko_lead_accept(id);
  assert (r->>'ok')::boolean and (r->>'coins')::int = 99 and r->>'phone' = '9811122334', 'accept: ' || r::text;
  r := ko_lead_accept(id);
  assert not (r->>'ok')::boolean, 'dobara accept nahi';
  assert jsonb_array_length(ko_inbox()) = 0, 'accept ke baad inbox khali';
  assert jsonb_array_length(ko_my_coin_txns()) = 2, 'ledger: signup + lead_accept';
  assert (ko_my_leads()->0->>'phone') = '9811122334', 'my leads me phone';
end $$;
-- A, Mumbai wali lead accept nahi kar sakta (match nahi)
do $$ declare r jsonb; begin
  r := ko_lead_accept(((select j from t_far)->>'id')::bigint);
  assert not (r->>'ok')::boolean, 'non-matching lead accept nahi honi chahiye';
end $$;

\echo '7. B accept; customer token se dono vendor dekhta hai'
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-00000000000b', false);
do $$ declare r jsonb; begin
  r := ko_lead_accept(((select j from t_lead)->>'id')::bigint);
  assert (r->>'ok')::boolean, 'B accept: ' || r::text;
  -- B, A ki lead ka step nahi badal sakta (sirf apna)
  perform ko_lead_step(((select j from t_lead)->>'id')::bigint, 'done');
  assert (ko_my_leads()->0->>'step') = 'done', 'apna step';
end $$;
select t_expect_error('select ko_lead_step(1, ''hacked'')', 'step galat');
reset role;
do $$ begin
  assert (select step from ko_lead_vendors lv join ko_vendors v on v.id = lv.vendor_id where v.shop_name = 'A Plumbing') = 'accept',
    'A ka step B ne badal diya!';
end $$;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$ declare s jsonb; j jsonb := (select j from t_lead); begin
  s := ko_lead_status((j->>'id')::bigint, (j->>'token')::uuid);
  assert jsonb_array_length(s->'vendors') = 2, 'status: ' || s::text;
end $$;
reset role;

-- =========================================================
\echo '8. demo band: coin add / plan client se nahi'
update ko_config set value = 'false' where key = 'demo_payments';
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', false);
select t_expect_error('select ko_coins_add(100)', 'payment');
do $$ declare v jsonb; begin
  v := ko_vendor_save('{"shop_name":"A Plumbing","plan":"p100"}'::jsonb);
  assert (v->>'rent_until')::date = current_date + 30, 'demo band me plan nahi badhna chahiye';
end $$;
reset role;
update ko_config set value = 'true' where key = 'demo_payments';

-- =========================================================
\echo '9. service_role: recharge ek payment = ek baar'
set role service_role;
do $$ declare vid uuid := (select id from ko_vendors where shop_name = 'A Plumbing'); b1 int; b2 int; begin
  b1 := ko_coins_credit(vid, 50, 'pay_123');
  b2 := ko_coins_credit(vid, 50, 'pay_123');
  assert b1 = 149 and b2 = 149, format('recharge %s %s', b1, b2);
end $$;
reset role;

-- =========================================================
\echo '10. lead settings: din / samay / roz ki limit / offline'
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', false);
set role anon;
create temp table t_l2 as select ko_lead_create('{"service":"Plumber","lat":28.614,"lng":77.209}'::jsonb) j;
grant select on t_l2 to authenticated;
set role authenticated;
do $$ declare today int := extract(isodow from now() at time zone 'Asia/Kolkata')::int; begin
  assert jsonb_array_length(ko_inbox()) = 1, 'plumber lead dikhni chahiye';
  perform ko_vendor_save(jsonb_build_object('shop_name', 'A Plumbing', 'settings', jsonb_build_object('days', jsonb_build_array(case when today = 1 then 2 else 1 end))));
  assert jsonb_array_length(ko_inbox()) = 0, 'aaj chhutti — lead nahi';
  perform ko_vendor_save('{"shop_name":"A Plumbing","settings":{"limit":1}}'::jsonb);
  assert jsonb_array_length(ko_inbox()) = 0, 'roz ki limit 1 (aaj 1 accept ho chuki)';
  perform ko_vendor_save('{"shop_name":"A Plumbing","settings":{}}'::jsonb);
  perform ko_set_online(false);
  assert jsonb_array_length(ko_inbox()) = 0, 'offline — lead nahi';
  perform ko_set_online(true);
  assert jsonb_array_length(ko_inbox()) = 1, 'wapas online';
end $$;

\echo '11. manual lead sirf apni, kisi ke inbox me nahi'
do $$ begin
  perform ko_vendor_add_lead('{"name":"Walk-in","phone":"98765 11111","service":"Plumber","budget":"300"}'::jsonb);
  assert (ko_my_leads()->0->>'source') = 'manual' and (ko_my_leads()->0->>'coins')::int = 0, 'manual lead';
  assert jsonb_array_length(ko_inbox()) = 1, 'manual lead inbox me nahi aani chahiye';
end $$;
reset role;

-- =========================================================
\echo '12. spam: ek phone se ghante me 10 se zyada nahi'
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$ begin
  for i in 1..10 loop perform ko_lead_create('{"service":"Plumber","customer_phone":"9000000001"}'::jsonb); end loop;
end $$;
select t_expect_error('select ko_lead_create(''{"service":"Plumber","customer_phone":"9000000001"}''::jsonb)', 'bahut requests');
select t_expect_error('select ko_lead_create(''{"service":"Plumber","customer_phone":"12345"}''::jsonb)', 'galat');
reset role;

\echo '13. suspended vendor: na leads, na save'
update ko_vendors set status = 'suspended' where shop_name = 'A Plumbing';
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', false);
do $$ begin assert jsonb_array_length(ko_inbox()) = 0, 'suspended ko leads nahi'; end $$;
select t_expect_error('select ko_vendor_save(''{"shop_name":"XY Shop"}''::jsonb)', 'band hai');
reset role;

\echo '✅ SAB TESTS PASS'
