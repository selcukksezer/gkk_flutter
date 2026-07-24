BEGIN;

-- ============================================================
-- Zindan Kuşatması — Faz A (forward)
-- Varsayılan: is_enabled = false (sistem kapalı)
-- Geri alma: supabase/manual_rollbacks/20260722_100001_dungeon_siege_rollback.sql
-- ============================================================

BEGIN;

-- ── Migration backup store ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public._gkk_migration_backups (
  backup_key text PRIMARY KEY,
  object_type text NOT NULL,
  object_name text NOT NULL,
  definition text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public._gkk_migration_backups (backup_key, object_type, object_name, definition)
SELECT
  'enter_dungeon_pre_siege',
  'function',
  'public.enter_dungeon(uuid,text)',
  pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'enter_dungeon'
  AND pg_get_function_identity_arguments(p.oid) = 'p_player_id uuid, p_dungeon_id text'
ON CONFLICT (backup_key) DO UPDATE
SET definition = EXCLUDED.definition,
    created_at = now();

-- ── Config (singleton) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.dungeon_siege_config (
  id uuid PRIMARY KEY DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  is_enabled boolean NOT NULL DEFAULT false,
  slot_count integer NOT NULL DEFAULT 5 CHECK (slot_count BETWEEN 1 AND 12),
  slot_duration_minutes integer NOT NULL DEFAULT 20 CHECK (slot_duration_minutes BETWEEN 5 AND 120),
  inactive_release_minutes integer NOT NULL DEFAULT 10 CHECK (inactive_release_minutes BETWEEN 3 AND 60),
  challenge_cooldown_minutes integer NOT NULL DEFAULT 10 CHECK (challenge_cooldown_minutes BETWEEN 1 AND 120),
  challenge_gold_cost bigint NOT NULL DEFAULT 500 CHECK (challenge_gold_cost >= 0),
  ban_duration_minutes integer NOT NULL DEFAULT 45 CHECK (ban_duration_minutes BETWEEN 5 AND 240),
  loot_bonus_pct numeric NOT NULL DEFAULT 0.40 CHECK (loot_bonus_pct >= 0 AND loot_bonus_pct <= 2),
  gold_bonus_pct numeric NOT NULL DEFAULT 0.25 CHECK (gold_bonus_pct >= 0 AND gold_bonus_pct <= 2),
  rep_bonus_pct numeric NOT NULL DEFAULT 0.15 CHECK (rep_bonus_pct >= 0 AND rep_bonus_pct <= 2),
  power_band_pct numeric NOT NULL DEFAULT 0.30 CHECK (power_band_pct >= 0 AND power_band_pct <= 1),
  timezone text NOT NULL DEFAULT 'Europe/Istanbul',
  prime_windows jsonb NOT NULL DEFAULT '[{"start":"19:00","end":"21:00"},{"start":"22:00","end":"00:00"}]'::jsonb,
  siege_dungeon_ids text[] NOT NULL DEFAULT ARRAY[
    'dng_010','dng_020','dng_030','dng_040','dng_050','dng_060','dng_065'
  ],
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.dungeon_siege_config (id)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.dungeon_siege_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read siege config" ON public.dungeon_siege_config;
CREATE POLICY "Anyone can read siege config"
  ON public.dungeon_siege_config FOR SELECT USING (true);

-- Faz B hazırlığı: territory ↔ zone
ALTER TABLE public.guild_war_territories
  ADD COLUMN IF NOT EXISTS zone_number integer;

-- ── Sessions / slots / challenges / bans ────────────────────
CREATE TABLE IF NOT EXISTS public.dungeon_siege_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_number integer NOT NULL,
  dungeon_id text NOT NULL REFERENCES public.dungeons(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_sessions_active
  ON public.dungeon_siege_sessions (dungeon_id, is_active, ends_at DESC);

CREATE TABLE IF NOT EXISTS public.dungeon_siege_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.dungeon_siege_sessions(id) ON DELETE CASCADE,
  slot_number integer NOT NULL CHECK (slot_number >= 1),
  holder_id uuid REFERENCES public.users(auth_id) ON DELETE SET NULL,
  guild_id uuid REFERENCES public.guilds(id) ON DELETE SET NULL,
  claimed_at timestamptz,
  expires_at timestamptz,
  last_active_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, slot_number)
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_slots_holder
  ON public.dungeon_siege_slots (holder_id)
  WHERE holder_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.dungeon_siege_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id uuid NOT NULL REFERENCES public.dungeon_siege_slots(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.dungeon_siege_sessions(id) ON DELETE CASCADE,
  dungeon_id text NOT NULL REFERENCES public.dungeons(id) ON DELETE CASCADE,
  challenger_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  defender_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'resolved'
    CHECK (status IN ('pending', 'resolved', 'expired', 'cancelled')),
  winner_id uuid REFERENCES public.users(auth_id) ON DELETE SET NULL,
  gold_spent bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_challenges_challenger
  ON public.dungeon_siege_challenges (challenger_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.dungeon_siege_bans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  dungeon_id text NOT NULL REFERENCES public.dungeons(id) ON DELETE CASCADE,
  banned_until timestamptz NOT NULL,
  reason text NOT NULL DEFAULT 'siege_challenge_loss',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_bans_player
  ON public.dungeon_siege_bans (player_id, dungeon_id, banned_until DESC);

ALTER TABLE public.dungeon_siege_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_siege_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_siege_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_siege_bans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view siege sessions" ON public.dungeon_siege_sessions;
CREATE POLICY "Anyone can view siege sessions"
  ON public.dungeon_siege_sessions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view siege slots" ON public.dungeon_siege_slots;
CREATE POLICY "Anyone can view siege slots"
  ON public.dungeon_siege_slots FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view siege challenges" ON public.dungeon_siege_challenges;
CREATE POLICY "Anyone can view siege challenges"
  ON public.dungeon_siege_challenges FOR SELECT USING (true);

DROP POLICY IF EXISTS "Players can view own siege bans" ON public.dungeon_siege_bans;
CREATE POLICY "Players can view own siege bans"
  ON public.dungeon_siege_bans FOR SELECT
  USING (player_id = auth.uid());

COMMIT;
