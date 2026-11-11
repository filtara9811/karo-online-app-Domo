# Vendor ऐप — Feature Parity Checklist (Prototype → Flutter)

Lakshya: HTML prototype (`docs/index.html`, V1–V324) ka **har** vendor feature Flutter app me —
UI + functionality + logic, ek bhi kami nahi. Har item tabhi ✅ jab:

1. Flutter me bana ho, 2. data **server par** ho (phone me nahi), 3. prototype ke screenshot se UI mila ho,
4. logic ka test ho (jahan hisaab-kitaab hai), 5. asli phone par chala ke dekha ho.

Nishaan: ✅ poora · 🟡 adhoora (UI hai par data phone me / demo / placeholder) · ⬜ shuru nahi
Kolam "Server" = data backend par hai? · "UI mila" = prototype screenshot se side-by-side mila?

> Ye list `docs/index.html` ke section headers (V-numbers) aur `vendor/lib` ke code ko mila kar banayi hai (11 Nov 2026).
> Har naye kaam ke baad yahi file update karein.

## A. Login, Join, Account

| # | Feature | Prototype | Flutter | Server | UI mila | Note |
|---|---|---|---|---|---|---|
| A1 | Login: poster + brand, Mobile / WhatsApp button | V28, V308 | ✅ | — | ⬜ | Prototype me poster ke peeche **video** (V308); Flutter me photo + zoom |
| A2 | **Asli OTP** (SMS) | — | ✅ | ✅ | — | Supabase Auth, 6 ank; Fast2SMS hook. WhatsApp OTP ⬜ |
| A3 | Join wizard: guide video, 1→2→✓, Service/Product/Other, category tiles | V206–V210, V309 | ✅ | ✅ | ⬜ | Har step ki apni video (V309) — jaanchna baaki |
| A4 | Sub-service picker (toggle → items → rate, apna jodein) | V212 | ✅ | ✅ | ⬜ | |
| A5 | "Aap kaun hain?" popup (type ke hisaab se) | V250 | ✅ | ✅ | ⬜ | Admin se aane wali list — abhi app me fixed (Step 2) |
| A6 | Shop details, radius, registration, photo | V210 | 🟡 | 🟡 | ⬜ | Photo server par nahi (Storage ⬜); **lat/lng nahi bhejte** → doori-match ⬜ |
| A7 | Smart auto-fill: photo se AI/OCR, logo crop, rate list, voice | V211 | ⬜ | ⬜ | ⬜ | |
| A8 | Shop rent: ₹1 trial (7 din) / ₹100 LIVE, UPI | V251 | 🟡 | ✅ | ⬜ | Server par plan; **payment demo** (Razorpay ⬜) |
| A9 | KYC / Bank / Business (Aadhaar, PAN, GST templates, upload, flip) | V26, V239, V314 | ⬜ | ⬜ | ⬜ | |
| A10 | Visiting / business card (flip, QR, share image, social) | V20, V58–V140, V323 | ⬜ | ⬜ | ⬜ | |
| A11 | Profile: dukaan jaankari, samay, support, logout | — | 🟡 | 🟡 | ⬜ | Shop rent / AutoPay, Support = "jald" screen |

## B. Leads (Lead Bazar)

| # | Feature | Prototype | Flutter | Server | UI mila | Note |
|---|---|---|---|---|---|---|
| B1 | Online toggle (foreground service) | V98 | ✅ | ✅ | ⬜ | |
| B2 | Nayi request = full-screen + ghanti, app band ho tab bhi | V200 | ✅ | ✅ | — | 7 sec polling; FCM ⬜ (battery). iOS par alag tareeka |
| B3 | Requests inbox: timer, x/5 vendor, budget, Accept · coin / Reject | V34, V99, V225 | ✅ | ✅ | ⬜ | Doori (km) server deta hai, UI me dikhana ⬜ |
| B4 | Lead card 5 kadam: Accept→Action→Working→Done→Review, skip | V100 | ✅ | ✅ | ⬜ | |
| B5 | Accept → Call / WhatsApp | V100, V111 | ✅ | ✅ | ⬜ | Call-back (V111) ⬜ |
| B6 | Din patti (₹ + lead + progress) + month calendar | V213, V215 | ✅ | 🟡 | ⬜ | ₹ kamai server par nahi (lead ka deal amount ⬜) |
| B7 | Search, All time, filter chips, lambi press = pin | — | ✅ | 🟡 | ⬜ | Pin phone me |
| B8 | + New lead (apni lead, coin nahi) | v2 | ✅ | ✅ | ⬜ | |
| B9 | Lead settings: category mapping, store profile, area, timing, auto/manual, limit | V318 | ✅ | ✅ | ⬜ | Timing / din / limit ab server bhi check karta hai |
| B10 | Lead wallet: coins, recharge | V101, v127 | 🟡 | ✅ | ⬜ | Recharge demo; Razorpay ⬜; **coin history (ledger) UI ⬜** — server ready (`ko_my_coin_txns`) |
| B11 | Lead chat (customer jaisa): quick replies, pipeline | V109, V226 | ⬜ | ⬜ | ⬜ | |
| B12 | Chat: Location / Quotation / Payment / Photo cards, edit/delete history | V227 | ⬜ | ⬜ | ⬜ | |
| B13 | Quotation → Invoice → Khata, reminders, templates, read ticks, voice notes | V228 | ⬜ | ⬜ | ⬜ | |
| B14 | Catalog → quote, PDF, partial payment, chat search & pin, voice → quotation | V229 | ⬜ | ⬜ | ⬜ | |
| B15 | Lead Bazar on map | V225, V30 | ⬜ | ⬜ | ⬜ | |
| B16 | Leads \| My Shop — Chrome-tab switch + swipe + ginti | V318, V319 | ✅ | — | ⬜ | |

## C. My Shop (Digital dukaan + POS)

| # | Feature | Prototype | Flutter | Server | UI mila | Note |
|---|---|---|---|---|---|---|
| C1 | Shop hero card (slides: shop, QR, stock, invoices, khata) | V151, V216, V219 | ✅ | ⬜ | ⬜ | QR + visitors, P&L button, supplier/expense stats (V219) 🟡 |
| C2 | Aaj ke orders patti, day orders sheet | V215 | ✅ | ⬜ | ⬜ | |
| C3 | POS grid (join ke items se), categories, tick-add, cart sheet, long-press edit | V132 | 🟡 | ⬜ | ⬜ | |
| C4 | Add product / inventory form (→ POS + online shop), colour variants | V220, V222 | 🟡 | ⬜ | ⬜ | Variants ⬜ |
| C5 | Bill: grahak, Cash/UPI/Card/Udhaar | V237 | ✅ | ⬜ | ⬜ | |
| C6 | Multiple parallel bills (hold) — Customer 1, 2, 3 | V136, V139 | ⬜ | ⬜ | ⬜ | |
| C7 | GST / discount / extra charges, recommended items, customer picker + history | V138 | ⬜ | ⬜ | ⬜ | |
| C8 | Invoice 3"/4"/A4 + UPI QR, WhatsApp / Print / PDF | V237 | ✅ | ⬜ | ⬜ | Bill photos (V237) ⬜ |
| C9 | Invoice carousel, UPI payment history | V324 | ⬜ | ⬜ | ⬜ | |
| C10 | Barcode / QR scan (camera, torch, gallery) | V138, V316, V320, V323 | ⬜ | — | ⬜ | Button hai, "agle update me" |
| C11 | Orders: accept popup, Online + POS, 7 kadam, tracker, expand tabs (Invoice/Customer/Progress/Raasta) | V182–V184 | 🟡 | ⬜ | ⬜ | Online orders server se nahi aate |
| C12 | Inventory: image, size stock, ON/OFF, out of stock → advance booking | V134, V231 | ⬜ | ⬜ | ⬜ | |
| C13 | Labels: template, QR, size price, pinch-zoom, direct BT print | V134, V135, V221, V222 | ⬜ | ⬜ | ⬜ | |
| C14 | Devices hub: Bluetooth scanner / label / bill / laser printer | V222 | ⬜ | — | ⬜ | |
| C15 | Kharcha (expense): quick amounts, multi/back dates, bill photo read, audit, tile edit, budget | V223, V224 | ⬜ | ⬜ | ⬜ | |
| C16 | Advance orders, baaki vasooli, aaj ki report, bill settings, stock ghata | V230 | ⬜ | ⬜ | ⬜ | |
| C17 | Purchase / supplier | V133, V219 | ⬜ | ⬜ | ⬜ | |
| C18 | Product editor (tabs, gallery, inline edit) | V96, V315–V317 | ⬜ | ⬜ | ⬜ | |
| C19 | Dukaan ke saanche (6 templates: food/retail/doctor/service/property/membership) | V232, V233 | ⬜ | ⬜ | ⬜ | |
| C20 | Video commerce (reels + product tags), video shop | V234, V247 | ⬜ | ⬜ | ⬜ | |
| C21 | Shutter wali dukaan (subah/raat auto, awaaz) | V303 | ⬜ | — | ⬜ | |
| C22 | QR Studio: standee / poster / sticker / tag / status | V201 | ⬜ | ⬜ | ⬜ | "jald" screen |

## D. Khata Book

| # | Feature | Prototype | Flutter | Server | UI mila | Note |
|---|---|---|---|---|---|---|
| D1 | Khata Book: per-type swipe cards, tabs, search | V152, V153 | ⬜ | ⬜ | ⬜ | "jald" screen |
| D2 | Udhaar → khata, WhatsApp reminder | V228, V230 | ⬜ | ⬜ | ⬜ | |

## E. Platform

| # | Feature | Prototype | Flutter | Server | UI mila | Note |
|---|---|---|---|---|---|---|
| E1 | Suraksha: har vendor sirf apna data | — | ✅ | ✅ | — | Step 0 — 13 SQL tests |
| E2 | Session khatam → login | — | ✅ | ✅ | — | |
| E3 | FCM push (pakki ghanti, battery bachat) | — | ⬜ | ⬜ | — | |
| E4 | Razorpay: coins + shop rent + AutoPay | V251 | ⬜ | 🟡 | — | Server functions ready (`ko_coins_credit`, `ko_plan_activate`) — webhook ⬜ |
| E5 | Photos / KYC files → Supabase Storage | — | ⬜ | ⬜ | — | |
| E6 | Admin se: banners, categories, "aap kaun" list | v127, V242 | ⬜ | ⬜ | — | Step 2 (Admin core) |
| E7 | iOS build | — | ⬜ | — | — | Mac / cloud Mac chahiye |
| E8 | Screenshot test (golden) har screen | — | ⬜ | — | — | |

## Ginti (Flutter kolam, abhi)

- Kul 59 features · ✅ 21 · 🟡 7 · ⬜ 31
- "UI mila" (screenshot se side-by-side) abhi kisi ka nahi hua — ye agla kaam hai.
