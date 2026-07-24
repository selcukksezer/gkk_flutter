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
