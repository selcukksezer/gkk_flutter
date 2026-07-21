-- QA 10k: bulk sim (300k events in one pass, no per-day side inserts)

CREATE OR REPLACE FUNCTION public.qa_run_30_day_simulation(
  p_days integer DEFAULT 30,
  p_run_id uuid DEFAULT gen_random_uuid()
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_day integer;
  v_day_ts timestamptz;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.qa_sim_daily_events WHERE run_id = p_run_id;
  DELETE FROM public.qa_sim_checkpoints WHERE run_id = p_run_id;
  DELETE FROM public.qa_sim_exploit_findings WHERE run_id = p_run_id;
  DELETE FROM public.qa_sim_exploit_attempts WHERE run_id = p_run_id;

  INSERT INTO public.qa_sim_daily_events (
    run_id, sim_day, bot_auth_id, segment, is_active, session_minutes,
    quests_done, dungeon_runs, pvp_attacks, market_buys, market_sells,
    craft_actions, guild_actions, mekan_actions,
    hospital_minutes, prison_minutes, hospital_escape_auto, prison_escape_auto,
    gold_earned, gold_spent, gems_earned, gems_spent, xp_earned,
    items_minted, items_burned, churn_risk, created_at
  )
  SELECT
    p_run_id,
    d.sim_day,
    b.bot_auth_id,
    b.segment,
    (random() < public.qa_active_probability(b.segment, d.sim_day)),
    CASE WHEN random() >= public.qa_active_probability(b.segment, d.sim_day) THEN 0
         WHEN b.segment = 'newbie' THEN 3 + floor(random() * 14)::int
         WHEN b.segment = 'casual' THEN 8 + floor(random() * 20)::int
         WHEN b.segment = 'normal' THEN 45 + floor(random() * 75)::int
         WHEN b.segment = 'hardcore' THEN 110 + floor(random() * 130)::int
         WHEN b.segment = 'whale' THEN 70 + floor(random() * 160)::int
         ELSE 20 + floor(random() * 60)::int END,
    floor(random() * 3)::int,
    floor(random() * 4)::int,
    floor(random() * 3)::int,
    floor(random() * 2)::int,
    floor(random() * 3)::int,
    floor(random() * 4)::int,
    floor(random() * 2)::int,
    floor(random() * 2)::int,
    CASE WHEN random() < 0.06 THEN 15 + floor(random() * 120)::int ELSE 0 END,
    CASE WHEN random() < 0.03 THEN 20 + floor(random() * 90)::int ELSE 0 END,
    random() < 0.02,
    random() < 0.015,
    CASE WHEN b.segment IN ('whale', 'hardcore') THEN (800 + floor(random() * 500)::int)
         ELSE (300 + floor(random() * 500)::int) END,
    (120 + floor(random() * 350)::int),
    0,
    CASE WHEN b.segment = 'whale' AND random() < 0.25 THEN 1 + floor(random() * 8)::int
         WHEN random() < 0.04 THEN 1 ELSE 0 END,
    (40 + floor(random() * 200)::int),
    floor(random() * 5)::int,
    floor(random() * 3)::int,
    CASE WHEN b.segment = 'newbie' THEN 0.35 + random() * 0.35 ELSE 0.10 + random() * 0.55 END,
    now() - ((p_days - d.sim_day) || ' days')::interval
  FROM generate_series(1, p_days) AS d(sim_day)
  CROSS JOIN public.qa_bot_profiles b;

  FOR v_day IN SELECT x FROM unnest(ARRAY[1, 3, 7, 14, 30]) AS t(x) WHERE x <= p_days LOOP
    v_day_ts := now() - ((p_days - v_day) || ' days')::interval;
    INSERT INTO public.qa_sim_checkpoints (
      run_id, checkpoint_day, active_users, retained_users, avg_session_minutes,
      total_gold_earned, total_gold_spent, total_gems_spent,
      total_items_minted, total_items_burned,
      daily_gold_earned, daily_gold_spent,
      cumulative_gold_earned, cumulative_gold_spent,
      cumulative_gems_spent, cumulative_items_minted, cumulative_items_burned,
      created_at
    )
    SELECT
      p_run_id, v_day,
      count(*) FILTER (WHERE e.is_active),
      count(*) FILTER (WHERE e.sim_day = 1 OR (e.is_active AND e.churn_risk < 0.80)),
      coalesce(avg(e.session_minutes), 0),
      coalesce(sum(e.gold_earned), 0), coalesce(sum(e.gold_spent), 0),
      coalesce(sum(e.gems_spent), 0), coalesce(sum(e.items_minted), 0),
      coalesce(sum(e.items_burned), 0),
      coalesce(sum(e.gold_earned), 0), coalesce(sum(e.gold_spent), 0),
      coalesce((SELECT sum(gold_earned) FROM public.qa_sim_daily_events x WHERE x.run_id = p_run_id AND x.sim_day <= v_day), 0),
      coalesce((SELECT sum(gold_spent) FROM public.qa_sim_daily_events x WHERE x.run_id = p_run_id AND x.sim_day <= v_day), 0),
      coalesce((SELECT sum(gems_spent) FROM public.qa_sim_daily_events x WHERE x.run_id = p_run_id AND x.sim_day <= v_day), 0),
      coalesce((SELECT sum(items_minted) FROM public.qa_sim_daily_events x WHERE x.run_id = p_run_id AND x.sim_day <= v_day), 0),
      coalesce((SELECT sum(items_burned) FROM public.qa_sim_daily_events x WHERE x.run_id = p_run_id AND x.sim_day <= v_day), 0),
      v_day_ts
    FROM public.qa_sim_daily_events e
    WHERE e.run_id = p_run_id AND e.sim_day = v_day
    ON CONFLICT (run_id, checkpoint_day) DO UPDATE SET
      active_users = EXCLUDED.active_users,
      retained_users = EXCLUDED.retained_users,
      avg_session_minutes = EXCLUDED.avg_session_minutes,
      total_gold_earned = EXCLUDED.total_gold_earned,
      total_gold_spent = EXCLUDED.total_gold_spent,
      total_gems_spent = EXCLUDED.total_gems_spent,
      total_items_minted = EXCLUDED.total_items_minted,
      total_items_burned = EXCLUDED.total_items_burned,
      daily_gold_earned = EXCLUDED.daily_gold_earned,
      daily_gold_spent = EXCLUDED.daily_gold_spent,
      cumulative_gold_earned = EXCLUDED.cumulative_gold_earned,
      cumulative_gold_spent = EXCLUDED.cumulative_gold_spent,
      cumulative_gems_spent = EXCLUDED.cumulative_gems_spent,
      cumulative_items_minted = EXCLUDED.cumulative_items_minted,
      cumulative_items_burned = EXCLUDED.cumulative_items_burned,
      created_at = EXCLUDED.created_at;
  END LOOP;

  PERFORM public.qa_run_exploit_battery(p_run_id);

  RETURN json_build_object(
    'success', true,
    'run_id', p_run_id,
    'days', p_days,
    'bots', (SELECT count(*) FROM public.qa_bot_profiles),
    'events', (SELECT count(*) FROM public.qa_sim_daily_events WHERE run_id = p_run_id),
    'summary', public.qa_export_run_summary(p_run_id),
    'bulk_sim', true
  );
END;
$$;
