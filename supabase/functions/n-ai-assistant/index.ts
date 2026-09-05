import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import OpenAI from "https://esm.sh/openai@4.56.0";

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  const auth = req.headers.get("Authorization");
  if (!auth) return new Response("Unauthorized", { status: 401 });
  const body = await req.json().catch(() => ({}));
  const message = String(body.message ?? "").trim();
  if (!message) return Response.json({ error: "message_required" }, { status: 400 });
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) return Response.json({ error: "OPENAI_API_KEY_missing" }, { status: 503 });
  const client = new OpenAI({ apiKey: key });
  const completion = await client.chat.completions.create({
    model: Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini",
    messages: [
      { role: "system", content: "أنت مساعد الذكاء الاصطناعي الرسمي داخل تطبيق N. أجب بالعربية بوضوح واختصار، وساعد المستخدم في الكتابة والأفكار واستخدام التطبيق. لا تدّعي تنفيذ إجراءات لم تنفذها." },
      { role: "user", content: message },
    ],
    temperature: 0.6,
    max_tokens: 700,
  });
  return Response.json({ answer: completion.choices[0]?.message?.content ?? "" });
});
