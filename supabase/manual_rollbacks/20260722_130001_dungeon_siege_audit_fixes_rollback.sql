-- ============================================================
-- Zindan Kuşatması — audit fix ROLLBACK
-- Sıra: bu dosya → Faz B rollback → Faz A rollback
-- Not: challenge/hub/cleanup Faz B gövdesine dönmek için
--       20260722_120000_dungeon_siege_faz_b.sql içindeki ilgili
--       CREATE OR REPLACE bloklarını tekrar çalıştırın.
-- ============================================================

BEGIN;

DROP FUNCTION IF EXISTS public.dungeon_siege_notify_hold_guild(uuid, uuid, text, text, text, jsonb);
DROP FUNCTION IF EXISTS public.dungeon_siege_apply_ban(uuid, text, integer, text);

DROP FUNCTION IF EXISTS public.set_dungeon_siege_config(
  boolean, integer, integer, integer, integer, bigint, integer,
  numeric, numeric, numeric, numeric, jsonb,
  integer, numeric, integer, integer, integer, integer, text, text[]
);

ALTER TABLE public.dungeon_siege_config
  DROP COLUMN IF EXISTS session_duration_minutes,
  DROP COLUMN IF EXISTS hold_rehold_cooldown_minutes;

DROP INDEX IF EXISTS idx_dungeon_siege_challenges_resolved;
DROP INDEX IF EXISTS idx_guild_war_territories_zone;
DROP INDEX IF EXISTS idx_dungeon_siege_sessions_active_ends;
DROP INDEX IF EXISTS idx_dungeon_siege_slots_session_num;

CREATE OR REPLACE FUNCTION public.dungeon_siege_week_key(p_at timestamptz DEFAULT now())
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT to_char(timezone('Europe/Istanbul', p_at), 'IYYY-"W"IW');
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_owner_for_zone(p_zone_number integer)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT t.owner_guild_id
  FROM public.guild_war_territories t
  WHERE t.zone_number = p_zone_number
  ORDER BY t.created_at NULLS LAST
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.set_dungeon_siege_config(
  boolean, integer, integer, integer, integer, bigint, integer,
  numeric, numeric, numeric, numeric, jsonb
) TO service_role;

COMMIT;
