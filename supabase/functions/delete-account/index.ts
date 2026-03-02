// Supabase Edge Function: Delete Account
// 刪除帳號：清除該用戶所有資料（DB + Storage）並刪除 Auth 用戶
//
// POST /delete-account — 需 Authorization: Bearer <user access token>
// 部署：supabase functions deploy delete-account

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const MEDIA_BUCKET = 'diary-media'
const THUMB_BUCKET = 'diary-thumbnails'

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

async function deleteStorageFolder(
  supabase: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string
): Promise<number> {
  let deleted = 0
  const { data: list, error: listErr } = await supabase.storage.from(bucket).list(prefix)
  if (listErr) {
    console.warn(`[DeleteAccount] list ${bucket}/${prefix} error:`, listErr.message)
    return 0
  }
  if (!list || list.length === 0) return 0

  const toDelete: string[] = []
  for (const item of list) {
    const path = prefix ? `${prefix}/${item.name}` : item.name
    if (item.id == null) {
      deleted += await deleteStorageFolder(supabase, bucket, path)
    } else {
      toDelete.push(path)
    }
  }
  if (toDelete.length > 0) {
    const { error: rmErr } = await supabase.storage.from(bucket).remove(toDelete)
    if (rmErr) {
      console.warn(`[DeleteAccount] remove ${bucket}/${prefix} error:`, rmErr.message)
    } else {
      deleted += toDelete.length
    }
  }
  return deleted
}

async function deleteFromTable(
  supabase: ReturnType<typeof createClient>,
  table: string,
  userId: string
): Promise<void> {
  const { error } = await supabase.from(table).delete().eq('user_id', userId)
  if (error) {
    console.warn(`[DeleteAccount] delete ${table} error:`, error.message, error.code)
    // FK / RLS errors on non-critical tables are non-fatal — continue cleanup
    if (error.code === '23503') {
      console.warn(`[DeleteAccount] FK constraint on ${table}, skipping`)
    }
  } else {
    console.log(`[DeleteAccount] ✓ ${table} cleaned`)
  }
}

async function handleDeleteAccount(req: Request): Promise<Response> {
  const userId = getUserIdFromJWT(req)
  if (!userId) {
    return new Response(JSON.stringify({ error: '未登入' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  console.log(`[DeleteAccount] Starting deletion for user=${userId}`)
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    // DB cleanup: child tables first (FK order)
    await deleteFromTable(supabase, 'messages', userId)
    await deleteFromTable(supabase, 'diary_tags', userId)
    await deleteFromTable(supabase, 'diaries', userId)
    await deleteFromTable(supabase, 'tags', userId)
    await deleteFromTable(supabase, 'user_subscriptions', userId)

    // Storage cleanup (best-effort)
    const mediaDeleted = await deleteStorageFolder(supabase, MEDIA_BUCKET, userId)
    const thumbDeleted = await deleteStorageFolder(supabase, THUMB_BUCKET, userId)
    console.log(`[DeleteAccount] Storage cleaned: ${mediaDeleted} media, ${thumbDeleted} thumbnails`)

    // Delete Auth user (must be last — after storage objects removed)
    const { error: authErr } = await supabase.auth.admin.deleteUser(userId)
    if (authErr) {
      console.error('[DeleteAccount] auth.admin.deleteUser error:', authErr)
      return new Response(
        JSON.stringify({ error: '刪除帳號失敗', detail: authErr.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[DeleteAccount] ✅ Deleted account and data for user=${userId}`)
    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('[DeleteAccount] Unhandled error:', err)
    return new Response(
      JSON.stringify({ error: '刪除失敗', detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
  return handleDeleteAccount(req)
})
