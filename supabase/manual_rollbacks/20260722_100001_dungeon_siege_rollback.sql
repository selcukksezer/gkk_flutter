-- ============================================================
-- Zindan Kuşatması — ROLLBACK (Faz A)
-- ÖNCE çalıştır: 20260722_130001_dungeon_siege_audit_fixes_rollback.sql (varsa)
-- SONRA: 20260722_120001_dungeon_siege_faz_b_rollback.sql (varsa)
-- SONRA: bu dosya
-- Not: _gkk_migration_backups tablosu kalır (diğer rollbackler için).
-- ============================================================

BEGIN;

-- Faz B kalıntıları (sıra atlanırsa güvenlik ağı)
DROP FUNCTION IF EXISTS public.mark_siege_notifications_read(uuid[]);
DROP FUNCTION IF EXISTS public.get_dungeon_siege_notifications(integer);
DROP FUNCTION IF EXISTS public.get_dungeon_siege_leaderboard(integer);
DROP FUNCTION IF EXISTS public.get_dungeon_siege_hub();
DROP FUNCTION IF EXISTS public.start_siege_guild_hold(text);
DROP TABLE IF EXISTS public.dungeon_siege_weekly_scores;
DROP TABLE IF EXISTS public.dungeon_siege_notifications;
DROP TABLE IF EXISTS public.dungeon_siege_holds;

-- ── enter_dungeon restore ───────────────────────────────────
DO $rollback$
DECLARE
  v_def text;
BEGIN
  SELECT definition INTO v_def
  FROM public._gkk_migration_backups
  WHERE backup_key = 'enter_dungeon_pre_siege';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'Backup enter_dungeon_pre_siege bulunamadı. Forward migration uygulandı mı?';
  END IF;

  EXECUTE v_def;
END;
$rollback$;

-- ── Drop RPCs ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.challenge_siege_slot(uuid);
DROP FUNCTION IF EXISTS public.release_siege_slot(uuid);
DROP FUNCTION IF EXISTS public.claim_siege_slot(text);
DROP FUNCTION IF EXISTS public.get_dungeon_siege_status(text);
DROP FUNCTION IF EXISTS public.set_dungeon_siege_config(boolean, integer, integer, integer, integer, bigint, integer, numeric, numeric, numeric, numeric, jsonb);
DROP FUNCTION IF EXISTS public.get_dungeon_siege_config();
DROP FUNCTION IF EXISTS public.dungeon_siege_reward_multipliers(uuid, text);
DROP FUNCTION IF EXISTS public.dungeon_siege_is_banned(uuid, text);
DROP FUNCTION IF EXISTS public.dungeon_siege_touch_slot_activity(uuid, text);
DROP FUNCTION IF EXISTS public.dungeon_siege_player_holds_any_slot(uuid);
DROP FUNCTION IF EXISTS public.dungeon_siege_player_has_slot(uuid, text);
DROP FUNCTION IF EXISTS public.dungeon_siege_can_fight(uuid);
DROP FUNCTION IF EXISTS public.dungeon_siege_ensure_session(text);
DROP FUNCTION IF EXISTS public.dungeon_siege_cleanup();
DROP FUNCTION IF EXISTS public.dungeon_siege_zone_for_dungeon(text);
DROP FUNCTION IF EXISTS public.dungeon_siege_is_active_for_dungeon(text);
DROP FUNCTION IF EXISTS public.dungeon_siege_in_prime_window();
DROP FUNCTION IF EXISTS public.dungeon_siege_is_target_dungeon(text);
DROP FUNCTION IF EXISTS public.dungeon_siege_is_enabled();
DROP FUNCTION IF EXISTS public.dungeon_siege_get_config();

-- ── Drop tables ─────────────────────────────────────────────
DROP TABLE IF EXISTS public.dungeon_siege_bans;
DROP TABLE IF EXISTS public.dungeon_siege_challenges;
DROP TABLE IF EXISTS public.dungeon_siege_slots;
DROP TABLE IF EXISTS public.dungeon_siege_sessions;
DROP TABLE IF EXISTS public.dungeon_siege_config;

ALTER TABLE IF EXISTS public.guild_war_territories
  DROP COLUMN IF EXISTS zone_number;

DELETE FROM public._gkk_migration_backups
WHERE backup_key = 'enter_dungeon_pre_siege';

COMMIT;
