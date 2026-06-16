BEGIN;

-- Spin wheel removed from client; drop wheel economy tables and RPCs.
-- Loot box system (loot_box_configs, open_loot_box, etc.) is unchanged.
-- Idempotent: safe when wheel tables were never created or already dropped.

DROP FUNCTION IF EXISTS public.spin_wheel(TEXT);
DROP FUNCTION IF EXISTS public.get_spin_wheels_with_stats();
DROP FUNCTION IF EXISTS public.get_spin_wheel_rewards(TEXT);

DO $$
BEGIN
  IF to_regclass('public.player_spin_wheel_logs') IS NOT NULL THEN
    DROP POLICY IF EXISTS player_spin_wheel_logs_select_own
      ON public.player_spin_wheel_logs;
  END IF;

  IF to_regclass('public.spin_wheel_reward_entries') IS NOT NULL THEN
    DROP POLICY IF EXISTS spin_wheel_reward_entries_select_auth
      ON public.spin_wheel_reward_entries;
  END IF;

  IF to_regclass('public.spin_wheel_configs') IS NOT NULL THEN
    DROP POLICY IF EXISTS spin_wheel_configs_select_auth
      ON public.spin_wheel_configs;
  END IF;
END $$;

DROP TABLE IF EXISTS public.player_spin_wheel_logs;
DROP TABLE IF EXISTS public.spin_wheel_reward_entries;
DROP TABLE IF EXISTS public.spin_wheel_configs;

COMMIT;
