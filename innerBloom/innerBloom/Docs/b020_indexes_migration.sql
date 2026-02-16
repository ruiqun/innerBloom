-- ============================================================
-- B-020: 10 万用户基本稳定性加强 — 数据库索引优化
-- ============================================================
-- 说明：
-- 此迁移为 B-019 已建立的表添加性能索引，
-- 支撑 10 万用户级别的快速查询。
--
-- 执行方式：
-- 在 Supabase Dashboard → SQL Editor 中执行，
-- 或通过 supabase db push / apply_migration 执行。
-- ============================================================

-- 1. diaries 表索引
-- ----------------------------------------------------------

-- 主查询索引：按用户+创建时间倒序（列表页核心查询）
CREATE INDEX IF NOT EXISTS idx_diaries_user_created
  ON diaries (user_id, created_at DESC);

-- 已保存日记筛选（列表页 is_saved = true）
CREATE INDEX IF NOT EXISTS idx_diaries_user_saved_created
  ON diaries (user_id, is_saved, created_at DESC)
  WHERE is_saved = true;

-- 同步状态筛选（查找同步失败的日记）
CREATE INDEX IF NOT EXISTS idx_diaries_user_sync_status
  ON diaries (user_id, sync_status)
  WHERE sync_status = 'failed';

-- 搜索优化：diary_summary 文本搜索（使用 trigram 需要先启用扩展）
-- 注意：如果要启用全文搜索，需要先执行：
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- CREATE INDEX IF NOT EXISTS idx_diaries_summary_trgm
--   ON diaries USING gin (diary_summary gin_trgm_ops);

-- 2. messages 表索引
-- ----------------------------------------------------------

-- 按日记获取消息（详情页核心查询）
CREATE INDEX IF NOT EXISTS idx_messages_diary_timestamp
  ON messages (diary_id, timestamp ASC);

-- 按用户查询消息
CREATE INDEX IF NOT EXISTS idx_messages_user_id
  ON messages (user_id);

-- 3. tags 表索引
-- ----------------------------------------------------------

-- 按用户获取标签列表
CREATE INDEX IF NOT EXISTS idx_tags_user_sort
  ON tags (user_id, sort_order ASC);

-- 标签名称查找（findOrCreateTag 用）
CREATE INDEX IF NOT EXISTS idx_tags_user_name
  ON tags (user_id, name);

-- 4. diary_tags 关联表索引
-- ----------------------------------------------------------

-- 按日记查询关联标签
CREATE INDEX IF NOT EXISTS idx_diary_tags_diary
  ON diary_tags (diary_id);

-- 按标签查询关联日记
CREATE INDEX IF NOT EXISTS idx_diary_tags_tag
  ON diary_tags (tag_id);

-- 按用户查询（RLS 过滤用）
CREATE INDEX IF NOT EXISTS idx_diary_tags_user
  ON diary_tags (user_id);

-- ============================================================
-- 验证索引（执行后可查看已建立的索引）
-- ============================================================

-- SELECT indexname, tablename, indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
-- ORDER BY tablename, indexname;
