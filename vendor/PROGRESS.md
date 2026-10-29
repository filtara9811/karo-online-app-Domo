# Karo Online Business — Vendor ऐप (Flutter native)

Design ka aadhaar: 1QR prototype ka vendor panel (Lead Bazar, ink + gold theme, Plus Jakarta Sans).
Package: `com.filipra.karoonline.business` · Naam: Karo Online Business
APK: GitHub → Releases → "Karo Online Business 1.0.N" → `karo-business.apk`
Har nayi chat me Claude pehle ye file padhe.

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

## Chaaran 2 — My Leads ⬜
- ⬜ Aaj ki leads date strip, lead detail poori, chat
- ⬜ Lead settings (category, doori, samay)
- ⬜ Coins recharge + history

## Chaaran 3 — My Shop ⬜
- ⬜ Shop card (Sales/Invoice/Visitors/Stock/P&L, Open/Close)
- ⬜ Aaj ke orders + order detail
- ⬜ POS / Naya bill + invoice 3"/4"/A4 + UPI QR + WhatsApp/Print/PDF
- ⬜ Products add/edit, stock
- ⬜ Dukaan QR

## Chaaran 4 — Khata + Profile ⬜
- ⬜ Khata Book
- ⬜ Profile: dukaan jaankari, samay, Shop rent + AutoPay, support

## Chaaran 5 — Asli backend + launch ⬜
- ⬜ Supabase project (free plan me 2 active ki limit — faisla baaki)
- ⬜ Firebase (FCM) — asli ghanti server se
- ⬜ Customer ऐप ka "request bhejein" Supabase se jodna
- ⬜ Fast2SMS OTP, Razorpay
- ⬜ Play Console nayi listing + AAB
