-- ============================================================
-- 🧹 innerBloom 用戶帳號 / 資料庫清除腳本
-- ============================================================
--
-- 用途：清除所有非管理員帳號及其資料，將資料庫還原為乾淨狀態
-- 適用：開發測試後清理、上線前重置
--
-- ⚠️ 使用方式：
--    1. 在 Supabase Dashboard → SQL Editor 中逐段執行
--    2. 每段都有驗證查詢，確認結果再繼續下一段
--    3. 管理帳號 Email 在下方 Step 0 設定
--
-- ⚠️ 注意事項：
--    - 此腳本不可逆，執行前請確認
--    - Storage 檔案使用 TRUNCATE（跳過保護觸發器）
--    - 如需保留管理帳號資料，請參考 Step 2 中的條件
-- ============================================================


-- ============================================================
-- 🔧 Step 0：設定管理帳號（修改此處即可）
-- ============================================================
-- 請將下方 Email 改為你的管理帳號
-- 後續所有步驟會自動根據此 Email 保留對應帳號

-- 先查詢確認管理帳號存在：
SELECT id, email, created_at, last_sign_in_at
FROM auth.users
WHERE email = 'momicrazyy@gmail.com';

-- 📋 預期結果：應顯示 1 筆管理帳號記錄
-- 如果為空，請確認 Email 是否正確


-- ============================================================
-- 📊 Step 1：執行前現況報告（僅查詢，不修改）
-- ============================================================

-- 1.1 所有帳號列表
SELECT
  id,
  email,
  created_at,
  last_sign_in_at,
  CASE WHEN email = 'momicrazyy@gmail.com'
       THEN '✅ 管理帳號（保留）'
       ELSE '❌ 將被刪除'
  END AS action
FROM auth.users
ORDER BY created_at;

-- 1.2 各表資料量
SELECT '帳號 (auth.users)'  AS category, count(*)::text AS total FROM auth.users
UNION ALL
SELECT 'diaries',            count(*)::text FROM public.diaries
UNION ALL
SELECT 'messages',           count(*)::text FROM public.messages
UNION ALL
SELECT 'tags',               count(*)::text FROM public.tags
UNION ALL
SELECT 'diary_tags',         count(*)::text FROM public.diary_tags
UNION ALL
SELECT 'storage_files',      count(*)::text FROM storage.objects
                              WHERE bucket_id IN ('diary-media', 'diary-thumbnails');

-- 1.3 資料歸屬分佈（按 user_id 分組）
SELECT
  COALESCE(d.user_id::text, '(NULL - 無歸屬)') AS user_id,
  COALESCE(u.email, '(未綁定帳號)')             AS email,
  count(*)                                       AS diary_count,
  CASE WHEN u.email = 'momicrazyy@gmail.com'
       THEN '✅ 保留'
       ELSE '❌ 刪除'
  END AS action
FROM public.diaries d
LEFT JOIN auth.users u ON d.user_id::text = u.id::text
GROUP BY d.user_id, u.email
ORDER BY diary_count DESC;

-- 📋 確認上方結果無誤後，繼續執行 Step 2


-- ============================================================
-- 🗑️ Step 2：清除 Public 表資料
-- ============================================================
-- 執行順序依照外鍵依賴：diary_tags → messages → diaries → tags
--
-- 💡 如需保留管理帳號的資料，將每條 DELETE 改為：
--    DELETE FROM xxx WHERE user_id != '管理帳號UUID';
-- ============================================================

-- 2.1 清除日記標籤關聯
DELETE FROM public.diary_tags;

-- 2.2 清除聊天消息
DELETE FROM public.messages;

-- 2.3 清除日記
DELETE FROM public.diaries;

-- 2.4 清除標籤
DELETE FROM public.tags;

-- ✅ 驗證：所有表應為 0
SELECT 'diary_tags' AS tbl, count(*) AS remaining FROM public.diary_tags
UNION ALL
SELECT 'messages',          count(*) FROM public.messages
UNION ALL
SELECT 'diaries',           count(*) FROM public.diaries
UNION ALL
SELECT 'tags',              count(*) FROM public.tags;

-- 📋 預期結果：全部為 0。確認後繼續 Step 3


-- ============================================================
-- 🗑️ Step 3：清除 Storage 檔案
-- ============================================================
-- Supabase 不允許對 storage.objects 直接 DELETE（有保護觸發器）
-- 使用 TRUNCATE 跳過觸發器（會清除所有 bucket 的檔案）
--
-- ⚠️ 這會清除 diary-media 和 diary-thumbnails 中的所有檔案
-- ============================================================

TRUNCATE storage.objects CASCADE;

-- ✅ 驗證：Storage 應為 0
SELECT
  bucket_id,
  count(*) AS remaining
FROM storage.objects
WHERE bucket_id IN ('diary-media', 'diary-thumbnails')
GROUP BY bucket_id;

-- 📋 預期結果：無記錄（空結果集）。確認後繼續 Step 4


-- ============================================================
-- 🗑️ Step 4：清除非管理帳號
-- ============================================================
-- 需要按照依賴順序刪除：
--   identities → sessions/refresh_tokens → mfa → users
--
-- ⚠️ 將 email 條件改為你的管理帳號
-- ============================================================

-- 4.1 取得管理帳號 ID（用於後續過濾）
-- 記下此 ID，下方用到
SELECT id, email FROM auth.users
WHERE email = 'momicrazyy@gmail.com';

-- 4.2 刪除非管理帳號的身份記錄
DELETE FROM auth.identities
WHERE user_id NOT IN (
  SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com'
);

-- 4.3 刪除非管理帳號的 refresh tokens
DELETE FROM auth.refresh_tokens
WHERE session_id IN (
  SELECT id FROM auth.sessions
  WHERE user_id NOT IN (
    SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com'
  )
);

-- 4.4 刪除非管理帳號的 sessions
DELETE FROM auth.sessions
WHERE user_id NOT IN (
  SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com'
);

-- 4.5 刪除非管理帳號的 MFA 因素（如有）
DELETE FROM auth.mfa_factors
WHERE user_id NOT IN (
  SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com'
);

-- 4.6 刪除非管理帳號
DELETE FROM auth.users
WHERE email != 'momicrazyy@gmail.com';

-- ✅ 驗證：只剩管理帳號
SELECT id, email, created_at, last_sign_in_at
FROM auth.users;

-- 📋 預期結果：僅顯示 momicrazyy@gmail.com


-- ============================================================
-- ✅ Step 5：最終驗證報告
-- ============================================================

SELECT '✅ 帳號'       AS item, count(*)::text AS count,
       string_agg(email, ', ') AS detail
FROM auth.users

UNION ALL
SELECT '✅ diaries',    count(*)::text, NULL FROM public.diaries

UNION ALL
SELECT '✅ messages',   count(*)::text, NULL FROM public.messages

UNION ALL
SELECT '✅ tags',       count(*)::text, NULL FROM public.tags

UNION ALL
SELECT '✅ diary_tags', count(*)::text, NULL FROM public.diary_tags

UNION ALL
SELECT '✅ storage',    count(*)::text, NULL
FROM storage.objects
WHERE bucket_id IN ('diary-media', 'diary-thumbnails');

-- 📋 預期最終結果：
-- ┌─────────────────┬───────┬──────────────────────┐
-- │ item            │ count │ detail               │
-- ├─────────────────┼───────┼──────────────────────┤
-- │ ✅ 帳號         │ 1     │ momicrazyy@gmail.com │
-- │ ✅ diaries      │ 0     │                      │
-- │ ✅ messages     │ 0     │                      │
-- │ ✅ tags         │ 0     │                      │
-- │ ✅ diary_tags   │ 0     │                      │
-- │ ✅ storage      │ 0     │                      │
-- └─────────────────┴───────┴──────────────────────┘
--
-- 🎉 清除完成！可用管理帳號重新登入，新資料自動帶 user_id + RLS 保護
