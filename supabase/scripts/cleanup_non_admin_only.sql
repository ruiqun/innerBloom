-- ============================================================
-- 🧹 innerBloom 選擇性清除腳本（保留管理帳號資料）
-- ============================================================
--
-- 用途：只刪除非管理帳號及其資料，管理帳號的日記/標籤/檔案全部保留
-- 適用：正式環境清除測試帳號、保留真實資料
--
-- ⚠️ 使用方式：在 Supabase Dashboard → SQL Editor 中逐段執行
-- ============================================================


-- ============================================================
-- 🔧 管理帳號設定
-- ============================================================
-- 修改下方 Email 即可自動保留對應帳號及其所有資料

-- 確認管理帳號：
SELECT id AS admin_id, email, created_at
FROM auth.users
WHERE email = 'momicrazyy@gmail.com';


-- ============================================================
-- 📊 執行前報告
-- ============================================================

-- 各帳號擁有的資料量
SELECT
  u.email,
  u.id AS user_id,
  (SELECT count(*) FROM public.diaries    WHERE user_id = u.id) AS diaries,
  (SELECT count(*) FROM public.messages   WHERE user_id = u.id) AS messages,
  (SELECT count(*) FROM public.tags       WHERE user_id = u.id) AS tags,
  (SELECT count(*) FROM public.diary_tags WHERE user_id = u.id) AS diary_tags,
  (SELECT count(*) FROM storage.objects
   WHERE bucket_id IN ('diary-media','diary-thumbnails')
     AND (storage.foldername(name))[1] = u.id::text
  ) AS storage_files,
  CASE WHEN u.email = 'momicrazyy@gmail.com'
       THEN '✅ 保留全部'
       ELSE '❌ 全部刪除'
  END AS action
FROM auth.users u
ORDER BY u.created_at;

-- 無歸屬資料（user_id = NULL，B-019 前舊資料）
SELECT
  '(NULL)' AS user_id,
  count(*) FILTER (WHERE tbl = 'diaries')    AS diaries,
  count(*) FILTER (WHERE tbl = 'messages')   AS messages,
  count(*) FILTER (WHERE tbl = 'tags')       AS tags,
  count(*) FILTER (WHERE tbl = 'diary_tags') AS diary_tags,
  '❌ 全部刪除' AS action
FROM (
  SELECT 'diaries'    AS tbl FROM public.diaries    WHERE user_id IS NULL
  UNION ALL
  SELECT 'messages'          FROM public.messages   WHERE user_id IS NULL
  UNION ALL
  SELECT 'tags'              FROM public.tags       WHERE user_id IS NULL
  UNION ALL
  SELECT 'diary_tags'        FROM public.diary_tags WHERE user_id IS NULL
) sub;


-- ============================================================
-- 🗑️ 執行清除（只刪非管理帳號 + 無歸屬資料）
-- ============================================================

-- Step 1: 取得管理帳號 ID
DO $$
DECLARE
  v_admin_id UUID;
BEGIN
  SELECT id INTO v_admin_id
  FROM auth.users
  WHERE email = 'momicrazyy@gmail.com';

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION '❌ 管理帳號不存在，請檢查 Email';
  END IF;

  RAISE NOTICE '✅ 管理帳號 ID: %', v_admin_id;

  -- Step 2: 刪除非管理帳號的 public 資料 + 無歸屬資料
  DELETE FROM public.diary_tags WHERE user_id IS DISTINCT FROM v_admin_id;
  RAISE NOTICE '✅ diary_tags 清除完成';

  DELETE FROM public.messages   WHERE user_id IS DISTINCT FROM v_admin_id;
  RAISE NOTICE '✅ messages 清除完成';

  DELETE FROM public.diaries    WHERE user_id IS DISTINCT FROM v_admin_id;
  RAISE NOTICE '✅ diaries 清除完成';

  DELETE FROM public.tags       WHERE user_id IS DISTINCT FROM v_admin_id;
  RAISE NOTICE '✅ tags 清除完成';

  -- Step 3: 刪除非管理帳號的 auth 相關記錄
  DELETE FROM auth.identities
  WHERE user_id != v_admin_id;

  DELETE FROM auth.refresh_tokens
  WHERE session_id IN (
    SELECT id FROM auth.sessions WHERE user_id != v_admin_id
  );

  DELETE FROM auth.sessions
  WHERE user_id != v_admin_id;

  DELETE FROM auth.mfa_factors
  WHERE user_id != v_admin_id;

  DELETE FROM auth.users
  WHERE id != v_admin_id;
  RAISE NOTICE '✅ 非管理帳號已刪除';

END $$;


-- ============================================================
-- 🗑️ 清除非管理帳號的 Storage 檔案
-- ============================================================
-- Storage 只能透過 TRUNCATE 或 API 清除
-- 如果管理帳號有 Storage 檔案需要保留，需手動處理
--
-- 方案 A：全部清除（開發階段推薦）
-- TRUNCATE storage.objects CASCADE;
--
-- 方案 B：只刪除舊格式檔案（無 user_id 路徑前綴的）
-- 需透過 Supabase Dashboard → Storage 手動刪除
--
-- 下方預設使用方案 A，如需保留管理帳號的 Storage 檔案請註解掉

-- ⚠️ 取消下方註解以執行 Storage 清除：
-- TRUNCATE storage.objects CASCADE;


-- ============================================================
-- ✅ 驗證報告
-- ============================================================

-- 帳號驗證
SELECT '帳號' AS item, count(*) AS count,
       string_agg(email, ', ') AS detail
FROM auth.users;

-- 管理帳號資料保留情況
SELECT
  '管理帳號資料' AS item,
  (SELECT count(*) FROM public.diaries    WHERE user_id = (SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com')) AS diaries,
  (SELECT count(*) FROM public.messages   WHERE user_id = (SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com')) AS messages,
  (SELECT count(*) FROM public.tags       WHERE user_id = (SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com')) AS tags;

-- 殘留資料檢查（應全部為 0）
SELECT
  '非管理資料殘留' AS item,
  (SELECT count(*) FROM public.diaries    WHERE user_id IS DISTINCT FROM (SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com')) AS diaries,
  (SELECT count(*) FROM public.messages   WHERE user_id IS DISTINCT FROM (SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com')) AS messages,
  (SELECT count(*) FROM public.tags       WHERE user_id IS DISTINCT FROM (SELECT id FROM auth.users WHERE email = 'momicrazyy@gmail.com')) AS tags;

-- 📋 預期結果：
-- 帳號：1（momicrazyy@gmail.com）
-- 管理帳號資料：保持不變
-- 非管理資料殘留：全部為 0
--
-- 🎉 清除完成！
