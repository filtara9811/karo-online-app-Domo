// Karo Online — courier (Shiprocket) bridge.
// Keys admin panel se ko_secrets me save hoti hain; ye function unhe server par hi padhta hai (app me kabhi nahi jaati).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SB = Deno.env.get("SUPABASE_URL")!;
const SR = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SRK = "https://apiv2.shiprocket.in/v1/external";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

async function db(path: string, init: RequestInit = {}) {
  const r = await fetch(`${SB}/rest/v1/${path}`, { ...init, headers: { apikey: SR, Authorization: `Bearer ${SR}`, "Content-Type": "application/json", ...(init.headers || {}) } });
  const t = await r.text();
  if (!r.ok) throw new Error(t);
  return t ? JSON.parse(t) : null;
}
async function secrets(): Promise<Record<string, string>> {
  const rows = await db("ko_secrets?select=k,v");
  const o: Record<string, string> = {};
  for (const x of rows || []) o[x.k] = x.v;
  return o;
}
async function srToken(s: Record<string, string>) {
  if (!s.shiprocket_email || !s.shiprocket_password) return null;
  const r = await fetch(`${SRK}/auth/login`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email: s.shiprocket_email, password: s.shiprocket_password }) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.token) throw new Error("Shiprocket login fail: " + (j.message || r.status));
  return j.token as string;
}
const demoRates = (w: number, cod: boolean) => {
  const kg = Math.max(0.5, w / 1000);
  return [
    { courier: "Delhivery Surface", days: "3-5 din", rate: Math.round(45 + kg * 28 + (cod ? 30 : 0)) },
    { courier: "Xpressbees", days: "2-4 din", rate: Math.round(52 + kg * 30 + (cod ? 30 : 0)) },
    { courier: "Ekart", days: "3-6 din", rate: Math.round(41 + kg * 26 + (cod ? 32 : 0)) },
    { courier: "Blue Dart Air", days: "1-2 din", rate: Math.round(95 + kg * 55 + (cod ? 40 : 0)) },
  ];
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const b = await req.json().catch(() => ({}));
    const act = String(b.action || "");
    const s = await secrets();
    const live = !!(s.shiprocket_email && s.shiprocket_password);

    if (act === "status") return json({ live, pickup: s.shiprocket_pickup || "Primary" });

    if (act === "test") {
      if (!live) return json({ ok: false, msg: "Shiprocket ka email / password abhi nahi daala" });
      await srToken(s);
      return json({ ok: true, msg: "✅ Shiprocket se jud gaya" });
    }

    if (act === "rates") {
      const w = Number(b.weight_g || 500), cod = !!b.cod;
      if (!live) return json({ demo: true, rates: demoRates(w, cod) });
      const tk = await srToken(s);
      const q = new URLSearchParams({ pickup_postcode: String(b.pickup_pin || s.pickup_pincode || "110006"), delivery_postcode: String(b.drop_pin || ""), weight: String(w / 1000), cod: cod ? "1" : "0" });
      const r = await fetch(`${SRK}/courier/serviceability/?${q}`, { headers: { Authorization: `Bearer ${tk}` } });
      const j = await r.json();
      const list = (j?.data?.available_courier_companies || []).map((c: any) => ({ courier: c.courier_name, days: (c.estimated_delivery_days || "?") + " din", rate: Math.round(c.rate), id: c.courier_company_id }))
        .sort((a: any, c: any) => a.rate - c.rate).slice(0, 6);
      return json({ demo: false, rates: list });
    }

    if (act === "book") {
      // b.awb = hamara KO AWB (ko_ship_create se bana)
      const rows = await db(`ko_shipments?awb=eq.${encodeURIComponent(b.awb)}&select=*`);
      const sh = rows && rows[0];
      if (!sh) return json({ ok: false, msg: "shipment nahi mila" }, 404);
      if (!live) {
        await db("rpc/ko_ship_courier_set", { method: "POST", body: JSON.stringify({ p_awb: sh.awb, p_ext: "DEMO" + sh.id, p_label: null, p_courier: b.courier || "Courier (demo)", p_status: "courier_booked" }) });
        return json({ ok: true, demo: true, ext_awb: "DEMO" + sh.id });
      }
      const tk = await srToken(s);
      const H = { Authorization: `Bearer ${tk}`, "Content-Type": "application/json" };
      const o = {
        order_id: sh.awb, order_date: new Date().toISOString().slice(0, 16).replace("T", " "), pickup_location: s.shiprocket_pickup || "Primary",
        billing_customer_name: sh.cust_name || "Customer", billing_last_name: "", billing_address: sh.cust_addr, billing_city: b.city || "Delhi", billing_pincode: b.drop_pin || "110006",
        billing_state: b.state || "Delhi", billing_country: "India", billing_phone: sh.cust_phone || "9999999999", shipping_is_billing: true,
        order_items: [{ name: (sh.items || "Saaman").slice(0, 100), sku: sh.awb, units: 1, selling_price: sh.cod || 1 }],
        payment_method: sh.cod > 0 ? "COD" : "Prepaid", sub_total: sh.cod || 1, length: 20, breadth: 15, height: 8, weight: (sh.weight_g || 500) / 1000,
      };
      const c1 = await (await fetch(`${SRK}/orders/create/adhoc`, { method: "POST", headers: H, body: JSON.stringify(o) })).json();
      if (!c1.shipment_id) return json({ ok: false, msg: "Shiprocket order nahi bana: " + JSON.stringify(c1).slice(0, 200) }, 400);
      const c2 = await (await fetch(`${SRK}/courier/assign/awb`, { method: "POST", headers: H, body: JSON.stringify({ shipment_id: c1.shipment_id, courier_id: b.courier_id }) })).json();
      const ext = c2?.response?.data?.awb_code || null;
      const c3 = await (await fetch(`${SRK}/courier/generate/label`, { method: "POST", headers: H, body: JSON.stringify({ shipment_id: [c1.shipment_id] }) })).json();
      await fetch(`${SRK}/courier/generate/pickup`, { method: "POST", headers: H, body: JSON.stringify({ shipment_id: [c1.shipment_id] }) });
      await db("rpc/ko_ship_courier_set", { method: "POST", body: JSON.stringify({ p_awb: sh.awb, p_ext: ext, p_label: c3?.label_url || null, p_courier: c2?.response?.data?.courier_name || b.courier || "Courier", p_status: "courier_booked" }) });
      return json({ ok: true, ext_awb: ext, label_url: c3?.label_url || null });
    }
    if (act === "return") {
      // reverse pickup: courier grahak se uthaye, dukaan (pickup location) par laaye
      const rows = await db(`ko_shipments?awb=eq.${encodeURIComponent(b.awb)}&select=*`);
      const sh = rows && rows[0];
      if (!sh) return json({ ok: false, msg: "shipment nahi mila" }, 404);
      if (!live) {
        await db("rpc/ko_ship_courier_set", { method: "POST", body: JSON.stringify({ p_awb: sh.awb, p_ext: "DEMO-R" + sh.id, p_label: null, p_courier: b.courier || "Courier return (demo)", p_status: "courier_booked" }) });
        return json({ ok: true, demo: true, ext_awb: "DEMO-R" + sh.id });
      }
      const tk = await srToken(s);
      const H = { Authorization: `Bearer ${tk}`, "Content-Type": "application/json" };
      const o = {
        order_id: sh.awb, order_date: new Date().toISOString().slice(0, 10),
        pickup_customer_name: sh.cust_name || "Customer", pickup_address: sh.cust_addr, pickup_city: b.city || "Delhi", pickup_state: b.state || "Delhi",
        pickup_country: "India", pickup_pincode: b.cust_pin || "110006", pickup_phone: sh.cust_phone || "9999999999",
        shipping_customer_name: sh.shop, shipping_address: sh.shop_addr || sh.shop, shipping_city: "Delhi", shipping_state: "Delhi", shipping_country: "India",
        shipping_pincode: s.pickup_pincode || "110006", shipping_phone: sh.shop_phone || "9999999999",
        order_items: [{ name: (sh.items || "Saaman").slice(0, 100), sku: sh.awb, units: 1, selling_price: b.amount || 1 }],
        payment_method: "Prepaid", sub_total: b.amount || 1, length: 20, breadth: 15, height: 8, weight: (sh.weight_g || 500) / 1000,
      };
      const c1 = await (await fetch(`${SRK}/orders/create/return`, { method: "POST", headers: H, body: JSON.stringify(o) })).json();
      if (!c1.shipment_id) return json({ ok: false, msg: "Shiprocket return nahi bana: " + JSON.stringify(c1).slice(0, 200) }, 400);
      const c2 = await (await fetch(`${SRK}/courier/assign/awb`, { method: "POST", headers: H, body: JSON.stringify({ shipment_id: c1.shipment_id, is_return: 1 }) })).json();
      const ext = c2?.response?.data?.awb_code || null;
      await db("rpc/ko_ship_courier_set", { method: "POST", body: JSON.stringify({ p_awb: sh.awb, p_ext: ext, p_label: null, p_courier: c2?.response?.data?.courier_name || "Courier return", p_status: "courier_booked" }) });
      return json({ ok: true, ext_awb: ext });
    }
    return json({ ok: false, msg: "action galat" }, 400);
  } catch (e) {
    return json({ ok: false, msg: String((e as Error).message || e).slice(0, 300) }, 500);
  }
});
