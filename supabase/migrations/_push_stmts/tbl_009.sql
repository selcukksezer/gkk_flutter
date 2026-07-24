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
