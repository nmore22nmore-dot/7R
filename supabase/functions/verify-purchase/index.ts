import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') ?? 'com.n.n_app'
const serviceAccountRaw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON') ?? ''
const admin = createClient(supabaseUrl, serviceRoleKey)

const PRODUCTS: Record<string, number> = {
  n_coins_100: 100,
  n_coins_550: 550,
  n_coins_1200: 1200,
  n_coins_2600: 2600,
  n_coins_7000: 7000,
}

function b64url(data: Uint8Array) {
  let s = ''
  for (const b of data) s += String.fromCharCode(b)
  return btoa(s).replaceAll('+','-').replaceAll('/','_').replaceAll('=','')
}
function pemToBytes(pem: string) {
  const b64 = pem.replace(/-----[^-]+-----/g,'').replace(/\s+/g,'')
  const raw = atob(b64)
  return Uint8Array.from(raw, c => c.charCodeAt(0))
}
async function googleAccessToken() {
  if (!serviceAccountRaw) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON_MISSING')
  const sa = JSON.parse(serviceAccountRaw)
  const now = Math.floor(Date.now()/1000)
  const header = b64url(new TextEncoder().encode(JSON.stringify({alg:'RS256',typ:'JWT'})))
  const payload = b64url(new TextEncoder().encode(JSON.stringify({iss:sa.client_email,scope:'https://www.googleapis.com/auth/androidpublisher',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})))
  const key = await crypto.subtle.importKey('pkcs8', pemToBytes(sa.private_key), {name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'}, false, ['sign'])
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${payload}`))
  const assertion = `${header}.${payload}.${b64url(new Uint8Array(sig))}`
  const r = await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})})
  if (!r.ok) throw new Error(`GOOGLE_OAUTH_${r.status}`)
  const j = await r.json(); return j.access_token as string
}

Deno.serve(async req => {
  try {
    if (req.method !== 'POST') return new Response('Method not allowed',{status:405})
    const auth = req.headers.get('authorization') ?? ''
    if (!auth.startsWith('Bearer ')) return Response.json({error:'UNAUTHORIZED'},{status:401})
    const jwt = auth.substring(7)
    const {data:{user},error:userError} = await admin.auth.getUser(jwt)
    if (userError || !user) return Response.json({error:'UNAUTHORIZED'},{status:401})
    const body = await req.json()
    const productId = String(body.productId ?? '')
    const purchaseToken = String(body.purchaseToken ?? '')
    if (!PRODUCTS[productId] || !purchaseToken) return Response.json({error:'INVALID_PURCHASE_DATA'},{status:400})

    const token = await googleAccessToken()
    const endpoint = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`
    const verify = await fetch(endpoint,{headers:{authorization:`Bearer ${token}`}})
    if (!verify.ok) return Response.json({error:'GOOGLE_PURCHASE_NOT_VERIFIED'},{status:400})
    const purchase = await verify.json()
    if (Number(purchase.purchaseState) !== 0) return Response.json({error:'PURCHASE_NOT_COMPLETED'},{status:400})
    if (purchase.acknowledgementState !== 1) {
      await fetch(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,{method:'POST',headers:{authorization:`Bearer ${token}`,'content-type':'application/json'},body:'{}'})
    }

    const {data:credited,error:creditError} = await admin.rpc('credit_coins_from_purchase',{p_user:user.id,p_product:productId,p_token:purchaseToken,p_order:purchase.orderId ?? null,p_coins:PRODUCTS[productId]})
    if (creditError) throw creditError
    return Response.json(credited)
  } catch (e) {
    return Response.json({error:String(e)},{status:500})
  }
})
