import { createClient } from 'jsr:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5.10.0';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

async function getAccessToken(service: any) {
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(service.private_key, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(service.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`Google OAuth failed: ${await res.text()}`);
  return (await res.json()).access_token as string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const serviceRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceRaw) return json({ error: 'FIREBASE_SERVICE_ACCOUNT_JSON is missing' }, 500);
    const service = JSON.parse(serviceRaw);

    const body = await req.json();
    const record = body.record ?? body;
    const userId = record.user_id;
    if (!userId) return json({ error: 'notification user_id is missing' }, 400);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('notifications_enabled')
      .eq('id', userId)
      .maybeSingle();
    if (profileError) throw profileError;
    if (profile?.notifications_enabled === false) return json({ sent: 0, reason: 'notifications_disabled' });

    const { data: tokens, error } = await supabase
      .from('push_tokens')
      .select('id,token')
      .eq('user_id', userId);
    if (error) throw error;

    if (!tokens?.length) return json({ sent: 0, reason: 'no_tokens' });

    const accessToken = await getAccessToken(service);
    const projectId = service.project_id;
    const title = 'N';
    const type = String(record.type ?? 'notification');
    const text = type === 'like' ? 'أعجب أحدهم بمحتواك' :
      type === 'comment' ? 'لديك تعليق جديد' :
      type === 'follow' ? 'بدأ شخص بمتابعتك' :
      type === 'gift' ? 'وصلتك هدية جديدة' :
      type === 'message' ? 'وصلتك رسالة جديدة' : 'لديك إشعار جديد';

    let sent = 0;
    const invalid: string[] = [];
    for (const row of tokens) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: row.token,
            notification: { title, body: text },
            data: { type, notification_id: String(record.id ?? ''), post_id: String(record.post_id ?? '') },
            android: { priority: 'high', notification: { channel_id: 'n_default' } },
          },
        }),
      });
      if (res.ok) sent++;
      else {
        const detail = await res.text();
        if (/UNREGISTERED|registration-token-not-registered|INVALID_ARGUMENT/i.test(detail)) invalid.push(row.id);
      }
    }
    if (invalid.length) await supabase.from('push_tokens').delete().in('id', invalid);
    return json({ sent, total: tokens.length });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
