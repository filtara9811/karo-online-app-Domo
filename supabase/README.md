# Karo Online — Backend (Supabase)

| File | Kya hai |
|---|---|
| `karo_v1.sql`, `karo_v2.sql` | Purana (khula, demo) backend — sirf itihaas ke liye |
| `migrations/20261111000000_karo_v3_secure.sql` | **Naya secure backend (Step 0)** |
| `functions/send-sms/` | Asli OTP SMS (Supabase Auth hook → Fast2SMS) |
| `tests/` | Security + logic tests (local Postgres) — `tests/run.sh` |

## Naya project chalu karne ke kadam (ek baar)

1. Supabase project (salah: alag project "karo-online", region **Mumbai ap-south-1**).
2. SQL Editor me `migrations/20261111000000_karo_v3_secure.sql` chalayein.
3. Authentication → Providers → **Phone: ON**, SMS OTP length **6**, expiry 300 sec.
   Testing: "Test phone numbers" me apna number + fixed OTP (SMS nahi jaata, paisa nahi lagta).
4. Edge Functions → `send-sms` deploy (Verify JWT **OFF**).
   Authentication → Hooks → **Send SMS hook** → HTTPS → function ka URL → secret banayein.
   Function secrets: `SEND_SMS_HOOK_SECRET`, `FAST2SMS_KEY` (+ launch se pehle DLT: `FAST2SMS_SENDER`, `FAST2SMS_TEMPLATE`).
5. Apps me URL + publishable key: `packages/karo_core/lib/src/config.dart` (ya build par `--dart-define`).
   Customer page: `docs/index.html` ke KO-LEAD block me `U` / `K`.

## Launch se pehle (zaroori)

- `update ko_config set value='false' where key='demo_payments';` — warna koi bhi muft coins / plan le sakta hai.
- Razorpay webhook (Edge Function) → `ko_coins_credit` / `ko_plan_activate` (sirf service_role).
- `enforce_rent = true` jab shop rent ka payment chalu ho.

## Purane (Committee Manager) project par chalana ho to

Migration purane khule functions **hata deti hai** — purana vendor APK (1.1.x) usi pal band.
Isliye naye APK ke release ke saath hi chalayein. Purani dukaanein pehli OTP login par phone se apne-aap jud jaati hain.
