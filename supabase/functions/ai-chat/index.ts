import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...cors, "Content-Type": "application/json" } });
  try {
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRole) return new Response(JSON.stringify({ error: "Server configuration is incomplete" }), { status: 503, headers: { ...cors, "Content-Type": "application/json" } });
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const admin = createClient(supabaseUrl, serviceRole);
    const { data: authData, error: authError } = await admin.auth.getUser(auth.slice(7));
    if (authError || !authData.user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });
    const body = await req.json();
    const message = String(body?.message ?? "").trim();
    if (!message || message.length > 4000) return new Response(JSON.stringify({ error: "Invalid message" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    const key = Deno.env.get("OPENAI_API_KEY");
    const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
    if (!key) return new Response(JSON.stringify({ error: "AI provider is not configured" }), { status: 503, headers: { ...cors, "Content-Type": "application/json" } });
    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model, messages: [{ role: "system", content: "أنت N AI. أجب بالعربية باختصار وبشكل مفيد وآمن." }, { role: "user", content: message }], temperature: 0.7 }),
    });
    const data = await r.json();
    if (!r.ok) return new Response(JSON.stringify({ error: data?.error?.message ?? "AI request failed" }), { status: 502, headers: { ...cors, "Content-Type": "application/json" } });
    const reply = data?.choices?.[0]?.message?.content ?? "لم تصل إجابة.";
    return new Response(JSON.stringify({ reply }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
