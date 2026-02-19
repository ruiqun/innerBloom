// Supabase Edge Function: Subscription Sync
// B-031 + B-032: 帳號級別 Premium 訂閱上報與狀態查詢
//
// POST /subscription-sync — App 購買/恢復後上報 transaction（寫入 user_subscriptions）
// GET  /subscription-sync — App 查詢帳號級別 Premium 狀態
//
// 部署命令：
// supabase functions deploy subscription-sync

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function getUserIdFromJWT(req: Request): string | null {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) return null
  try {
    const token = authHeader.replace('Bearer ', '')
    const payload = JSON.parse(atob(token.split('.')[1]))
    return payload.sub || null
  } catch {
    return null
  }
}

// POST: App 購買/恢復成功後上報 transaction
async function handleReport(req: Request): Promise<Response> {
  const userId = getUserIdFromJWT(req)
  if (!userId) {
    return new Response(JSON.stringify({ error: '未登入' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const body = await req.json()
  const {
    original_transaction_id,
    transaction_id,
    product_id,
    purchase_date,
    expires_at,
    is_in_trial,
    environment,
  } = body

  if (!original_transaction_id || !transaction_id || !product_id || !purchase_date) {
    return new Response(JSON.stringify({ error: '缺少必要欄位' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const isActive = expires_at ? new Date(expires_at) > new Date() : true

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  // 一個 Apple 訂閱（original_transaction_id）全局只能綁定一個 app 帳號
  const { data: existing } = await supabase
    .from('user_subscriptions')
    .select('user_id')
    .eq('original_transaction_id', original_transaction_id)
    .limit(1)
    .maybeSingle()

  if (existing) {
    if (existing.user_id !== userId) {
      console.log(`[SubscriptionSync] ⛔ Rejected: original_tx=${original_transaction_id} already bound to another user`)
      return new Response(
        JSON.stringify({ error: '此訂閱已與其他帳號綁定', code: 'SUBSCRIPTION_ALREADY_LINKED' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    // 同一帳號刷新訂閱資料
  }

  const { error } = await supabase
    .from('user_subscriptions')
    .upsert(
      {
        user_id: userId,
        original_transaction_id,
        transaction_id,
        product_id,
        purchase_date,
        expires_at: expires_at || null,
        is_in_trial: is_in_trial || false,
        is_active: isActive,
        environment: environment || 'Production',
        last_verified_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,original_transaction_id' }
    )

  if (error) {
    // 若因 original_transaction_id 唯一約束衝突（已屬其他用戶），回傳友善錯誤
    if (error.code === '23505') {
      return new Response(
        JSON.stringify({ error: '此訂閱已與其他帳號綁定', code: 'SUBSCRIPTION_ALREADY_LINKED' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    console.error('[SubscriptionSync] UPSERT error:', error)
    return new Response(JSON.stringify({ error: '寫入失敗', detail: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  console.log(`[SubscriptionSync] ✅ Reported: user=${userId}, product=${product_id}, active=${isActive}`)

  return new Response(
    JSON.stringify({ success: true, is_premium: isActive, expires_at: expires_at || null }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

// GET: 查詢帳號級別 Premium 狀態
async function handleQuery(req: Request): Promise<Response> {
  const userId = getUserIdFromJWT(req)
  if (!userId) {
    return new Response(JSON.stringify({ error: '未登入' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const now = new Date().toISOString()

  // 先把過期的記錄標為 inactive
  await supabase
    .from('user_subscriptions')
    .update({ is_active: false, updated_at: now })
    .eq('user_id', userId)
    .eq('is_active', true)
    .lt('expires_at', now)

  // 查詢仍有效的訂閱
  const { data, error } = await supabase
    .from('user_subscriptions')
    .select('product_id, expires_at, is_in_trial')
    .eq('user_id', userId)
    .eq('is_active', true)
    .order('expires_at', { ascending: false })
    .limit(1)

  if (error) {
    console.error('[SubscriptionSync] Query error:', error)
    return new Response(JSON.stringify({ is_premium: false }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  if (data && data.length > 0) {
    const sub = data[0]
    console.log(`[SubscriptionSync] ✅ Query: user=${userId}, premium=true, product=${sub.product_id}`)
    return new Response(
      JSON.stringify({
        is_premium: true,
        is_in_trial: sub.is_in_trial || false,
        expires_at: sub.expires_at,
        product_id: sub.product_id,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  console.log(`[SubscriptionSync] Query: user=${userId}, premium=false`)
  return new Response(
    JSON.stringify({ is_premium: false }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

// B-034 輔助：供 ai-chat 內部呼叫的 Premium 查詢函式（直接 DB 查詢）
// 匯出給其他 function 使用時，可直接 import
export async function checkPremiumStatus(userId: string): Promise<boolean> {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const now = new Date().toISOString()

  const { data } = await supabase
    .from('user_subscriptions')
    .select('id')
    .eq('user_id', userId)
    .eq('is_active', true)
    .gt('expires_at', now)
    .limit(1)

  return (data && data.length > 0) || false
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method === 'POST') {
      return await handleReport(req)
    } else if (req.method === 'GET') {
      return await handleQuery(req)
    } else {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
  } catch (error) {
    console.error('[SubscriptionSync] Error:', error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
