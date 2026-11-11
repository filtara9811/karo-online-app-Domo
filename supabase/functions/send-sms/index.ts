// Supabase Auth "Send SMS" hook → Fast2SMS (India)
// Supabase Auth OTP banata hai, ye function use SMS se bhejta hai.
//
// Setup (Supabase Dashboard):
//   1. Edge Functions → deploy "send-sms" (Verify JWT = OFF, hook khud signature check karta hai)
//   2. Authentication → Hooks → "Send SMS hook" → HTTPS → is function ka URL → secret generate
//   3. Edge Function secrets:
//        SEND_SMS_HOOK_SECRET = (step 2 wala secret, "v1,whsec_..." poora)
//        FAST2SMS_KEY         = Fast2SMS API key
//      DLT (launch ke liye zaroori — TRAI):
//        FAST2SMS_SENDER      = DLT sender id (jaise KAROON)
//        FAST2SMS_TEMPLATE    = DLT message template id (message me {#var#} = OTP)
//      Ye do na hon to Fast2SMS ka "otp" route (testing) chalta hai.
//   4. Authentication → Providers → Phone: ON, OTP length 6, expiry 300 sec.
//      Testing ke liye "Test phone numbers" me apna number + fixed OTP daal sakte hain (SMS nahi jaata).

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

type HookPayload = { user: { phone?: string }; sms: { otp: string } };

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  const raw = await req.text();
  const secret = (Deno.env.get("SEND_SMS_HOOK_SECRET") ?? "").replace("v1,whsec_", "");
  let payload: HookPayload;
  try {
    payload = new Webhook(secret).verify(raw, Object.fromEntries(req.headers)) as HookPayload;
  } catch (_) {
    return json(401, { error: { http_code: 401, message: "invalid signature" } });
  }

  const phone = (payload.user?.phone ?? "").replace(/\D/g, "").slice(-10);
  const otp = payload.sms?.otp ?? "";
  if (!/^[6-9]\d{9}$/.test(phone) || !/^\d{4,10}$/.test(otp)) {
    return json(400, { error: { http_code: 400, message: "Sirf Bharat ke mobile number" } });
  }

  const key = Deno.env.get("FAST2SMS_KEY") ?? "";
  const sender = Deno.env.get("FAST2SMS_SENDER");
  const template = Deno.env.get("FAST2SMS_TEMPLATE");
  const body = sender && template
    ? { route: "dlt", sender_id: sender, message: template, variables_values: otp, numbers: phone, flash: "0" }
    : { route: "otp", variables_values: otp, numbers: phone, flash: "0" };

  try {
    const r = await fetch("https://www.fast2sms.com/dev/bulkV2", {
      method: "POST",
      headers: { authorization: key, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const res = await r.json().catch(() => ({}));
    if (!r.ok || res.return !== true) {
      console.error("fast2sms failed", r.status, JSON.stringify(res));
      return json(502, { error: { http_code: 502, message: "SMS nahi gaya — thodi der baad try karein" } });
    }
  } catch (e) {
    console.error("fast2sms error", e);
    return json(502, { error: { http_code: 502, message: "SMS nahi gaya — thodi der baad try karein" } });
  }
  return json(200, {});
});
