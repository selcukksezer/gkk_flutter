CREATE TABLE IF NOT EXISTS public.dungeon_siege_bans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  dungeon_id text NOT NULL REFERENCES public.dungeons(id) ON DELETE CASCADE,
  banned_until timestamptz NOT NULL,
  reason text NOT NULL DEFAULT 'siege_challenge_loss',
  created_at timestamptz NOT NULL DEFAULT now()
);
