-- Patch qa_live_play_run_bot: SKIP fixes + trade/PvP/GW/bank/craft + gold delta

CREATE OR REPLACE FUNCTION public.qa_live_play_economy_report()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bots int;
  v_gold_sum bigint;
  v_gems_sum bigint;
  v_gold_avg numeric;
  v_open int := 0;
  v_filled int := 0;
  v_cancelled int := 0;
  v_fill_rate numeric := 0;
  v_dungeon_runs int := 0;
  v_chat_dm int := 0;
  v_trades int := 0;
  v_seed_gold bigint := 25000000;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  SELECT count(*)::int, coalesce(sum(gold),0)::bigint, coalesce(sum(gems),0)::bigint, coalesce(avg(gold),0)
  INTO v_bots, v_gold_sum, v_gems_sum, v_gold_avg
  FROM public.users WHERE username LIKE 'qa_bot_%';

  SELECT
    count(*) FILTER (WHERE status = 'open')::int,
    count(*) FILTER (WHERE status NOT IN ('open', 'cancelled', 'canceled'))::int,
    count(*) FILTER (WHERE status IN ('cancelled', 'canceled'))::int
  INTO v_open, v_filled, v_cancelled
  FROM public.market_orders
  WHERE seller_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR COALESCE(buyer_id, '00000000-0000-0000-0000-000000000000'::uuid)
        IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  IF (v_open + v_filled) > 0 THEN
    v_fill_rate := round((v_filled::numeric / (v_open + v_filled)::numeric) * 100.0, 2);
  END IF;

  SELECT count(*)::int INTO v_dungeon_runs
  FROM public.dungeon_runs
  WHERE player_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  SELECT count(*)::int INTO v_chat_dm
  FROM public.chat_messages
  WHERE channel = 'dm'
    AND sender_user_id IN (SELECT id FROM public.users WHERE username LIKE 'qa_bot_%');

  SELECT count(*)::int INTO v_trades
  FROM public.trade_sessions
  WHERE initiator_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR partner_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  RETURN jsonb_build_object(
    'bots', v_bots,
    'gold_sum', v_gold_sum,
    'gems_sum', v_gems_sum,
    'gold_avg', round(v_gold_avg, 0),
    'seed_gold_per_bot', v_seed_gold,
    'seed_gold_total', v_bots * v_seed_gold,
    'gold_delta_vs_seed', v_gold_sum - (v_bots * v_seed_gold),
    'gold_delta_pct_vs_seed', CASE WHEN v_bots > 0 THEN round(((v_gold_sum - (v_bots * v_seed_gold))::numeric / (v_bots * v_seed_gold)::numeric) * 100, 2) ELSE 0 END,
    'market_open', v_open,
    'market_filled', v_filled,
    'market_cancelled', v_cancelled,
    'market_fill_rate_pct', v_fill_rate,
    'dungeon_runs', v_dungeon_runs,
    'chat_dm_count', v_chat_dm,
    'trade_sessions', v_trades
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_live_play_economy_report() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_live_play_economy_report() TO service_role;
