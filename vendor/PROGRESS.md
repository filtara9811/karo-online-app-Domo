# Karo Online Business — Vendor ऐप (Flutter native)

Design ka aadhaar: 1QR prototype ka vendor panel (Lead Bazar, ink + gold theme, Plus Jakarta Sans).
Package: `com.filipra.karoonline.business` · Naam: Karo Online Business
APK: GitHub → Releases → "Karo Online Business 1.0.N" → `karo-business.apk`
Har nayi chat me Claude pehle ye file padhe. Poori feature list (prototype se milaan): `vendor/PARITY.md`.

## Chaaran 1 — Neenv + Ghanti ✅ (pehla build)
- ✅ Theme (rang, font, card) — `lib/theme.dart`
- ✅ Login (mobile + OTP, demo OTP 1234) — `screens/login.dart`
- ✅ Lead Bazar home: wallet + Online toggle, Lead settings row, 4 stat, chart, search, filter, lead list, lead popup (Call/WhatsApp/status) — `screens/home.dart`
- ✅ Bottom nav: Khata | Requests (gold, red/green badge) | My Profile
- ✅ Requests inbox: Leads | Orders, timer, Reject / Accept (coin katna) — `screens/requests.dart`
- ✅ Nayi request full-screen + ghanti (FLAG_INSISTENT, alarm sound, lock screen) — `screens/incoming.dart`, `ring.dart`
- ✅ Online = foreground service (specialUse)
- ✅ Ghanti test (10 sec, app band karke) + permissions (notification, full screen, battery, autostart) — `screens/profile.dart`
- ⬜ Phone par test: app band → ghanti (Xiaomi/Oppo/Vivo/Samsung)

## Chaaran 2 — Login + Join + My Leads ✅ (v1.1)
- ✅ Login prototype jaisa (poster, Mobile/WhatsApp, OTP 4 dabbe, success) — demo OTP koi bhi 4 ank
- ✅ Join: guide video, 1→2→✓, Service/Product/Other, category tiles, sub-service picker (toggle + items + rate + apna jodein), shop details, radius, "Service kaise / Aap kaun", registration, photo
- ✅ Shop rent sheet (₹1 trial / ₹100 aaj LIVE, UPI app, demo payment) → success → server par dukaan save
- ✅ Asli leads: customer page (docs/index.html radar) → Supabase ko_lead_create → vendor inbox (ko_inbox)
- ✅ Background service (online) har 7 sec → ghanti + full-screen, app band ho tab bhi
- ✅ Lead Bazar strip (timer, x/5 vendor, budget, Accept · coin), lead card 6 kadam (Accept→Action→Working→Pahunch gaye→Done→Review)
- ✅ v1.2: Chrome jaisi Leads | My Shop tab patti (swipe), Lead settings sheet — Categories mapping (toggle, chips, services/rate badlein, nayi category), Store profile, Service area, Timing, Accept (manual/auto), Lead limit — sab server par, ko_inbox inhi se filter
- ✅ Din patti (₹ + lead + progress) + MONTH calendar, search + All time, filter chips, naye lead card (5 kadam: Accept→Action→Working→Done→Review, status pill), lambi press = pin, + New lead
- ⬜ Coins recharge (Razorpay), chat

## Chaaran 3 — My Shop ✅ (v1.1, data abhi phone me)
- ✅ Shop card 5 slide (shop, QR, stock, invoices, khata), aaj ke orders patti, POS grid (join ke items se), Add product
- ✅ Bill: grahak, Cash/UPI/Card/Udhaar, invoice 3"/4"/A4 + UPI QR, WhatsApp / Print / PDF
- ✅ Orders sheet (Sab/Online/POS, 7 kadam patti)
- ⬜ Bills/products server par, online orders (digital dukaan se)

## Chaaran 4 — Khata + Profile ⬜
- ⬜ Khata Book
- ⬜ Profile: dukaan jaankari, samay, Shop rent + AutoPay, support

## Step 0 — Secure backend + saanjha core ✅ (code) · ⬜ (Supabase par lagana)
- ✅ `supabase/migrations/20261111000000_karo_v3_secure.sql`: login (auth.uid) se dukaan, purane khule RPC hataye,
  coins/plan client se nahi, coin ledger, lead token, doori se match, settings server par, spam limit — 13 SQL tests
- ✅ `supabase/functions/send-sms`: asli OTP SMS (Fast2SMS, DLT ready)
- ✅ `packages/karo_core`: OTP login, session (dono isolate), API — 11 tests
- ⬜ Supabase project chunna + migration chalana + Phone auth + SMS hook (dekhein `supabase/README.md`)

## Step 1 — Vendor ऐप ⏳
- ✅ 1a: asli OTP login (6 ank), saare RPC token se (p_vendor hata), join me number login wala, session khatam → login
- ⬜ 1b: PARITY.md ke ⬜ / 🟡 items, ek-ek karke (pehle: shop location, coin history, Khata, chat)

## Chaaran 5 — Launch ⬜
- ✅ Backend: Committee Manager Supabase me ko_ tables + RPC (supabase/karo_v1.sql)
- ✅ Asli OTP + login token (Step 0/1a) — Supabase par lagana baaki
- ⬜ demo_payments = false (launch se pehle)
- ⬜ Razorpay AutoPay, FCM (extra pakki ghanti)
- ⬜ Play Console nayi listing + AAB
