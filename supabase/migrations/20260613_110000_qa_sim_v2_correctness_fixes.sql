-- ===========================================================================
-- Migration: QA simulation V2 correctness fixes
-- ===========================================================================
-- Bulgular (qa_sim_run_b12e67d4 raporu):
--   1) items_burned daima 0; gold_earned/items_minted gerçek aktivite
--      sayılarını yansıtmıyor. Sebep: qa_run_30_day_simulation içindeki TEK
--      UPDATE, türetilen kolonları (gold_earned, items_burned, ...) AYNI
--      ifadede set edilen aktivite kolonlarından (market_sells, dungeon_runs)
--      hesaplıyordu. Postgres'te tek UPDATE'in tüm SET sağ tarafları satırın
--      UPDATE ÖNCESİ değerini görür → aktivite sayıları 0 okunuyordu.
--      Çözüm: UPDATE'i 3'e böl (A=aktivite, B=ekonomi, C=churn).
--   2) premium_stack_abuse %23 "başarı" → aslında MEŞRU ilk VIP alımını
--      exploit sayıyordu. buy_vip_pass (locked) zaten 2. çağrıyı reddediyor.
--      Çözüm: sadece 2. çağrı (gerçek stack) başarılıysa success say.
--   3) multi_account_gold_funnel %88 → normal PvP gold çalmayı funnel sayıyordu.
--      Çözüm: aynı A→B çiftine tekrarlı saldırı (>=3) desenini ölç.
--   4) qa_active_probability: search_path yok + volatility işareti yok.
--   5) mekanlar fame sıralamasında seq scan (1000+ ölçek). Index ekle.
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Fix 4: qa_active_probability hardening (saf matematik → IMMUTABLE)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qa_active_probability(p_segment text, p_day int)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prob numeric;
BEGIN
  v_prob := CASE p_segment
    WHEN 'newbie' THEN 0.90 * exp(-0.11 * (p_day - 1))
    WHEN 'casual' THEN 0.88 * exp(-0.07 * (p_day - 1))
    WHEN 'normal' THEN 0.92 * exp(-0.045 * (p_day - 1))
    WHEN 'hardcore' THEN 0.97 * exp(-0.022 * (p_day - 1))
    WHEN 'whale' THEN 0.98 * exp(-0.018 * (p_day - 1))
    WHEN 'trader' THEN 0.91 * exp(-0.035 * (p_day - 1))
    WHEN 'pvp' THEN 0.93 * exp(-0.033 * (p_day - 1))
    WHEN 'guild' THEN 0.94 * exp(-0.030 * (p_day - 1))
    WHEN 'multi' THEN 0.95 * exp(-0.040 * (p_day - 1))
    WHEN 'exploit' THEN 0.96 * exp(-0.028 * (p_day - 1))
    ELSE 0.85 * exp(-0.050 * (p_day - 1))
  END;

  RETURN GREATEST(0.02, LEAST(0.99, v_prob));
END;
$$;

-- ---------------------------------------------------------------------------
-- Fix 5: mekan fame sıralaması için index (1000+ ölçekte seq scan giderme)
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_mekans_open_fame
  ON public.mekans (is_open, fame DESC);

-- ---------------------------------------------------------------------------
-- Fix 1: qa_run_30_day_simulation — UPDATE'i böl (aktivite / ekonomi / churn)
-- ---------------------------------------------------------------------------
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

  FOR v_day IN 1..p_days LOOP
    v_day_ts := now() - ((p_days - v_day) || ' days')::interval;

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
      v_day,
      b.bot_auth_id,
      b.segment,
      (random() < public.qa_active_probability(b.segment, v_day)) AS is_active,
      0,0,0,0,0,0,0,0,0,0,0,false,false,0,0,0,0,0,0,0,0,
      v_day_ts
    FROM public.qa_bot_profiles b;

    -- UPDATE A: ham aktivite sayıları (yalnızca is_active/segment/random'a bağlı)
    UPDATE public.qa_sim_daily_events e
    SET
      session_minutes = CASE
        WHEN NOT e.is_active THEN 0
        WHEN e.segment = 'newbie' THEN 3 + floor(random() * 14)::int
        WHEN e.segment = 'casual' THEN 8 + floor(random() * 20)::int
        WHEN e.segment = 'normal' THEN 45 + floor(random() * 75)::int
        WHEN e.segment = 'hardcore' THEN 110 + floor(random() * 130)::int
        WHEN e.segment = 'whale' THEN 70 + floor(random() * 160)::int
        WHEN e.segment = 'trader' THEN 35 + floor(random() * 80)::int
        WHEN e.segment = 'pvp' THEN 40 + floor(random() * 110)::int
        WHEN e.segment = 'guild' THEN 30 + floor(random() * 90)::int
        WHEN e.segment = 'multi' THEN 30 + floor(random() * 100)::int
        ELSE 25 + floor(random() * 110)::int
      END,
      quests_done = CASE WHEN e.is_active THEN floor(random() * 5)::int ELSE 0 END,
      dungeon_runs = CASE WHEN e.is_active THEN floor(random() * 4)::int ELSE 0 END,
      pvp_attacks = CASE
        WHEN NOT e.is_active THEN 0
        WHEN e.segment IN ('pvp','hardcore','exploit') THEN 2 + floor(random() * 8)::int
        ELSE floor(random() * 4)::int
      END,
      market_buys = CASE WHEN e.is_active THEN floor(random() * 4)::int ELSE 0 END,
      market_sells = CASE WHEN e.is_active THEN floor(random() * 5)::int ELSE 0 END,
      craft_actions = CASE WHEN e.is_active THEN floor(random() * 4)::int ELSE 0 END,
      guild_actions = CASE WHEN e.is_active AND e.segment IN ('guild','hardcore','whale') THEN 1 + floor(random() * 4)::int ELSE floor(random() * 2)::int END,
      mekan_actions = CASE WHEN e.is_active THEN floor(random() * 3)::int ELSE 0 END,
      hospital_minutes = CASE
        WHEN NOT e.is_active THEN 0
        WHEN random() < 0.11 THEN 20 + floor(random() * 140)::int
        ELSE 0
      END,
      prison_minutes = CASE
        WHEN NOT e.is_active THEN 0
        WHEN random() < 0.07 THEN 30 + floor(random() * 180)::int
        ELSE 0
      END,
      hospital_escape_auto = CASE
        WHEN NOT e.is_active THEN false
        WHEN e.segment IN ('whale','hardcore') THEN random() < 0.78
        WHEN e.segment IN ('normal','pvp') THEN random() < 0.45
        ELSE random() < 0.20
      END,
      prison_escape_auto = CASE
        WHEN NOT e.is_active THEN false
        WHEN e.segment IN ('whale','hardcore') THEN random() < 0.66
        WHEN e.segment IN ('normal','pvp') THEN random() < 0.38
        ELSE random() < 0.16
      END
    WHERE e.run_id = p_run_id AND e.sim_day = v_day;

    -- UPDATE B: türetilen ekonomi (artık KALICI aktivite sayılarını okur)
    UPDATE public.qa_sim_daily_events e
    SET
      gold_earned = CASE
        WHEN NOT e.is_active THEN 0
        ELSE (300 + e.quests_done * 220 + e.dungeon_runs * 650 + e.market_sells * 380 + e.mekan_actions * 300 + floor(random() * 500)::int)
      END,
      gold_spent = CASE
        WHEN NOT e.is_active THEN 0
        ELSE (120 + e.market_buys * 350 + e.craft_actions * 180 + e.guild_actions * 120 + floor(random() * 350)::int)
      END,
      gems_earned = CASE WHEN e.is_active THEN floor(random() * 5)::int ELSE 0 END,
      gems_spent = CASE
        WHEN NOT e.is_active THEN 0
        ELSE
          (CASE WHEN e.hospital_minutes > 0 AND e.hospital_escape_auto THEN GREATEST(2, ceil(e.hospital_minutes / 25.0)::int) ELSE 0 END)
          +
          (CASE WHEN e.prison_minutes > 0 AND e.prison_escape_auto THEN GREATEST(3, ceil(e.prison_minutes / 30.0)::int) ELSE 0 END)
          + (CASE WHEN e.segment = 'whale' THEN floor(random() * 20)::int ELSE floor(random() * 4)::int END)
      END,
      xp_earned = CASE WHEN e.is_active THEN (40 + e.quests_done * 55 + e.dungeon_runs * 120 + e.pvp_attacks * 35) ELSE 0 END,
      items_minted = CASE WHEN e.is_active THEN (e.dungeon_runs + e.craft_actions + floor(random() * 3)::int) ELSE 0 END,
      items_burned = CASE WHEN e.is_active THEN floor((e.market_sells + e.craft_actions) * 0.55)::int ELSE 0 END
    WHERE e.run_id = p_run_id AND e.sim_day = v_day;

    -- UPDATE C: churn riski (artık KALICI gold_earned/gold_spent'i okur)
    UPDATE public.qa_sim_daily_events e
    SET
      churn_risk = CASE
        WHEN NOT e.is_active THEN LEAST(1.0, 0.35 + v_day * 0.015)
        WHEN e.session_minutes < 10 THEN LEAST(1.0, 0.30 + v_day * 0.010)
        WHEN e.gold_earned < e.gold_spent THEN LEAST(1.0, 0.25 + v_day * 0.008)
        ELSE GREATEST(0.02, 0.18 - v_day * 0.002)
      END
    WHERE e.run_id = p_run_id AND e.sim_day = v_day;

    UPDATE public.users u
    SET
      gold = GREATEST(0, u.gold + agg.gold_in - agg.gold_out),
      gems = GREATEST(0, u.gems + agg.gems_in - agg.gems_out),
      xp = u.xp + agg.xp_in,
      experience = u.experience + agg.xp_in,
      level = LEAST(120, u.level + floor((u.xp + agg.xp_in) / 5000)::int - floor(u.xp / 5000)::int),
      total_playtime_seconds = u.total_playtime_seconds + agg.play_sec,
      updated_at = v_day_ts,
      last_login_at = CASE WHEN agg.active_cnt > 0 THEN v_day_ts ELSE u.last_login_at END,
      hospital_until = CASE
        WHEN agg.hospital_left_minutes > 0 THEN v_day_ts + make_interval(mins => agg.hospital_left_minutes::int)
        ELSE NULL
      END,
      prison_until = CASE
        WHEN agg.prison_left_minutes > 0 THEN v_day_ts + make_interval(mins => agg.prison_left_minutes::int)
        ELSE NULL
      END,
      in_hospital = (agg.hospital_left_minutes > 0),
      in_prison = (agg.prison_left_minutes > 0),
      pvp_wins = u.pvp_wins + agg.pvp_wins_add,
      pvp_losses = u.pvp_losses + agg.pvp_losses_add
    FROM (
      SELECT
        e.bot_auth_id,
        sum(e.gold_earned) AS gold_in,
        sum(e.gold_spent) AS gold_out,
        sum(e.gems_earned) AS gems_in,
        sum(e.gems_spent) AS gems_out,
        sum(e.xp_earned) AS xp_in,
        sum(e.session_minutes * 60) AS play_sec,
        sum(CASE WHEN e.is_active THEN 1 ELSE 0 END) AS active_cnt,
        sum(CASE WHEN e.hospital_minutes > 0 AND NOT e.hospital_escape_auto THEN e.hospital_minutes ELSE 0 END) AS hospital_left_minutes,
        sum(CASE WHEN e.prison_minutes > 0 AND NOT e.prison_escape_auto THEN e.prison_minutes ELSE 0 END) AS prison_left_minutes,
        sum(CASE WHEN e.pvp_attacks > 0 THEN floor(e.pvp_attacks * 0.52)::int ELSE 0 END) AS pvp_wins_add,
        sum(CASE WHEN e.pvp_attacks > 0 THEN floor(e.pvp_attacks * 0.48)::int ELSE 0 END) AS pvp_losses_add
      FROM public.qa_sim_daily_events e
      WHERE e.run_id = p_run_id
        AND e.sim_day = v_day
      GROUP BY e.bot_auth_id
    ) agg
    WHERE u.auth_id = agg.bot_auth_id;

    INSERT INTO public.dungeon_runs (
      id, player_id, dungeon_id, success, is_critical,
      gold_earned, xp_earned, items_dropped, hospitalized,
      hospital_until, player_power, success_rate_at_run, is_first_clear, created_at
    )
    SELECT
      gen_random_uuid(),
      e.bot_auth_id,
      d.id,
      (random() < LEAST(0.92, 0.45 + (u.level * 0.01))) AS success,
      (random() < 0.08),
      (220 + floor(random() * 900)::int),
      (50 + floor(random() * 220)::int),
      '[]'::jsonb,
      (e.hospital_minutes > 0),
      CASE WHEN e.hospital_minutes > 0 AND NOT e.hospital_escape_auto THEN v_day_ts + make_interval(mins => e.hospital_minutes) ELSE NULL END,
      u.power,
      LEAST(0.95, 0.40 + (u.level * 0.008)),
      false,
      v_day_ts
    FROM public.qa_sim_daily_events e
    JOIN public.users u ON u.auth_id = e.bot_auth_id
    JOIN LATERAL (
      SELECT id FROM public.dungeons ORDER BY random() LIMIT 1
    ) d ON true
    WHERE e.run_id = p_run_id
      AND e.sim_day = v_day
      AND e.is_active
      AND e.dungeon_runs > 0;

    INSERT INTO public.pvp_matches (
      id, attacker_id, defender_id,
      winner_id, attacker_power, defender_power,
      attacker_hp_remaining, defender_hp_remaining,
      gold_stolen, rep_change_winner, rep_change_loser,
      attacker_rating_before, attacker_rating_after,
      defender_rating_before, defender_rating_after,
      is_critical_success, hospital_triggered, rounds, created_at
    )
    SELECT
      gen_random_uuid(),
      e.bot_auth_id,
      target.bot_auth_id,
      CASE WHEN random() < 0.55 THEN e.bot_auth_id ELSE target.bot_auth_id END,
      ua.power,
      ud.power,
      floor(20 + random() * 80)::int,
      floor(10 + random() * 75)::int,
      floor(150 + random() * 1200)::int,
      2,
      -2,
      ua.pvp_rating,
      ua.pvp_rating + floor(random() * 20)::int,
      ud.pvp_rating,
      GREATEST(100, ud.pvp_rating - floor(random() * 20)::int),
      (random() < 0.10),
      (random() < 0.09),
      2 + floor(random() * 5)::int,
      v_day_ts
    FROM public.qa_sim_daily_events e
    JOIN public.users ua ON ua.auth_id = e.bot_auth_id
    JOIN LATERAL (
      SELECT b.bot_auth_id
      FROM public.qa_bot_profiles b
      WHERE b.bot_auth_id <> e.bot_auth_id
      ORDER BY random()
      LIMIT 1
    ) target ON true
    JOIN public.users ud ON ud.auth_id = target.bot_auth_id
    WHERE e.run_id = p_run_id
      AND e.sim_day = v_day
      AND e.is_active
      AND e.pvp_attacks > 0;

    INSERT INTO public.market_orders (
      id, seller_id, item_id, quantity, price,
      region_id, listed_at, item_data, status, total_price,
      currency, player_id, item_name, item_type, rarity,
      is_stackable, max_stack, enhancement_level, side, fee, region,
      created_at
    )
    SELECT
      gen_random_uuid(),
      e.bot_auth_id,
      i.id,
      GREATEST(1, floor(random() * 5)::int),
      GREATEST(50, i.base_price + floor(random() * i.base_price * 0.45)::int),
      1,
      floor(extract(epoch from v_day_ts) * 1000)::bigint,
      jsonb_build_object('name', i.name, 'rarity', i.rarity),
      CASE WHEN random() < 0.72 THEN 'filled' ELSE 'open' END,
      GREATEST(50, i.base_price + floor(random() * i.base_price * 0.45)::int),
      'gold',
      e.bot_auth_id,
      i.name,
      i.type,
      i.rarity,
      i.is_stackable,
      i.max_stack,
      0,
      'sell',
      floor((i.base_price * 0.05))::int,
      'global',
      v_day_ts
    FROM public.qa_sim_daily_events e
    JOIN LATERAL (
      SELECT id, name, rarity, type, base_price, is_stackable, max_stack
      FROM public.items
      WHERE coalesce(is_market_tradeable, true) = true
      ORDER BY random()
      LIMIT 1
    ) i ON true
    WHERE e.run_id = p_run_id
      AND e.sim_day = v_day
      AND e.is_active
      AND e.market_sells > 0;

    IF v_day IN (1, 3, 7, 14, 30) THEN
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
        p_run_id,
        v_day,
        count(*) FILTER (WHERE e.is_active),
        count(*) FILTER (WHERE e.sim_day = 1 OR (e.is_active AND e.churn_risk < 0.80)),
        coalesce(avg(e.session_minutes), 0),
        coalesce(sum(e.gold_earned), 0),
        coalesce(sum(e.gold_spent), 0),
        coalesce(sum(e.gems_spent), 0),
        coalesce(sum(e.items_minted), 0),
        coalesce(sum(e.items_burned), 0),
        coalesce(sum(e.gold_earned), 0),
        coalesce(sum(e.gold_spent), 0),
        coalesce((
          SELECT sum(gold_earned)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        coalesce((
          SELECT sum(gold_spent)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        coalesce((
          SELECT sum(gems_spent)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        coalesce((
          SELECT sum(items_minted)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        coalesce((
          SELECT sum(items_burned)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        v_day_ts
      FROM public.qa_sim_daily_events e
      WHERE e.run_id = p_run_id
        AND e.sim_day = v_day
      ON CONFLICT (run_id, checkpoint_day)
      DO UPDATE SET
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
    END IF;
  END LOOP;

  PERFORM public.qa_run_exploit_battery(p_run_id);

  RETURN json_build_object(
    'success', true,
    'run_id', p_run_id,
    'days', p_days,
    'bots', (SELECT count(*) FROM public.qa_bot_profiles),
    'events', (SELECT count(*) FROM public.qa_sim_daily_events WHERE run_id = p_run_id),
    'summary', public.qa_export_run_summary(p_run_id)
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Fix 2 + 3: qa_run_exploit_battery — gerçek exploit desenini ölç
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qa_run_exploit_battery(p_run_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_run_start timestamptz;
  v_run_end timestamptz;
  v_bot uuid;
  v_resp jsonb;
  v_attempt integer;
  v_out json;
BEGIN
  DELETE FROM public.qa_sim_exploit_attempts WHERE run_id = p_run_id;
  DELETE FROM public.qa_sim_exploit_findings WHERE run_id = p_run_id;

  SELECT min(created_at), max(created_at)
  INTO v_run_start, v_run_end
  FROM public.qa_sim_daily_events
  WHERE run_id = p_run_id;

  IF v_run_start IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'run_not_found');
  END IF;

  -- E01 multi_account_gold_funnel — GERÇEK desen: aynı A→B çiftine tekrarlı
  -- saldırı (gold'u tek alt'a yönlendirme). Normal tek seferlik PvP çalma
  -- artık exploit SAYILMAZ; sadece >=3 tekrarlı huni başarılı kabul edilir.
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'multi_account_gold_funnel',
    pair.attacker_id,
    pair.hits,
    pair.hits >= 3,
    jsonb_build_object('defender', pair.defender_id, 'hits', pair.hits, 'gold_funneled', pair.total_gold),
    CASE WHEN pair.hits >= 3 THEN pair.total_gold ELSE 0 END,
    0
  FROM (
    SELECT pm.attacker_id, pm.defender_id, count(*) AS hits, sum(pm.gold_stolen) AS total_gold
    FROM public.pvp_matches pm
    JOIN public.qa_bot_profiles b ON b.bot_auth_id = pm.attacker_id AND b.segment = 'multi'
    WHERE pm.created_at BETWEEN v_run_start AND v_run_end + interval '1 hour'
    GROUP BY pm.attacker_id, pm.defender_id
  ) pair
  LIMIT 400;

  -- E02 market_price_manipulation (median-üstü aşırı fiyat listeleme)
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'market_price_manipulation',
    mo.seller_id,
    row_number() OVER (PARTITION BY mo.seller_id ORDER BY mo.created_at),
    mo.price > GREATEST(100, i.base_price * 2),
    jsonb_build_object('price', mo.price, 'base_price', i.base_price, 'item', i.name),
    mo.price,
    0
  FROM public.market_orders mo
  JOIN public.items i ON i.id = mo.item_id
  JOIN public.qa_bot_profiles b ON b.bot_auth_id = mo.seller_id
  WHERE mo.created_at BETWEEN v_run_start AND v_run_end + interval '1 hour'
  LIMIT 400;

  -- E03 hospital_escape_abuse
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'hospital_escape_abuse',
    e.bot_auth_id,
    e.sim_day,
    e.hospital_escape_auto AND e.hospital_minutes > 0 AND e.gems_spent > 0
      AND (e.gems_spent::numeric / GREATEST(e.hospital_minutes, 1)) > 0.5,
    jsonb_build_object('minutes', e.hospital_minutes, 'gems_spent', e.gems_spent, 'segment', e.segment),
    0,
    e.gems_spent
  FROM public.qa_sim_daily_events e
  WHERE e.run_id = p_run_id
    AND e.hospital_minutes > 0
    AND e.hospital_escape_auto
  LIMIT 400;

  -- E04 prison_escape_abuse
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'prison_escape_abuse',
    e.bot_auth_id,
    e.sim_day,
    e.prison_escape_auto AND e.prison_minutes > 0 AND e.gems_spent > 0
      AND (e.gems_spent::numeric / GREATEST(e.prison_minutes, 1)) > 0.4,
    jsonb_build_object('minutes', e.prison_minutes, 'gems_spent', e.gems_spent, 'segment', e.segment),
    0,
    e.gems_spent
  FROM public.qa_sim_daily_events e
  WHERE e.run_id = p_run_id
    AND e.prison_minutes > 0
    AND e.prison_escape_auto
  LIMIT 400;

  -- E05 cooldown_bypass (bir sim gününde aşırı zindan koşusu)
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'cooldown_bypass',
    e.bot_auth_id,
    e.sim_day,
    e.dungeon_runs >= 4,
    jsonb_build_object('dungeon_runs', e.dungeon_runs, 'segment', e.segment),
    e.gold_earned,
    0
  FROM public.qa_sim_daily_events e
  WHERE e.run_id = p_run_id
    AND e.is_active
    AND e.dungeon_runs >= 3
  LIMIT 300;

  -- E06 premium_stack_abuse — canlı RPC replay.
  -- attempt 1 = MEŞRU ilk alım (exploit DEĞİL, succeeded=false baseline).
  -- attempt 2 = gerçek STACK denemesi; sadece bu başarılıysa exploit sayılır.
  v_attempt := 0;
  FOR v_bot IN
    SELECT bot_auth_id
    FROM public.qa_bot_profiles
    WHERE segment = 'whale'
    ORDER BY random()
    LIMIT 15
  LOOP
    -- 1) meşru ilk alım (baseline, exploit success olarak sayılmaz)
    v_resp := public.qa_call_as_bot(v_bot, 'buy_vip_pass');
    v_attempt := v_attempt + 1;
    INSERT INTO public.qa_sim_exploit_attempts (
      run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
    )
    VALUES (
      p_run_id, 'premium_stack_abuse', v_bot, 1,
      false,
      jsonb_build_object('phase', 'baseline_first_purchase', 'rpc', v_resp),
      0, 0
    );

    -- 2) gerçek stack denemesi: VIP zaten aktifken ikinci kez al
    v_resp := public.qa_call_as_bot(v_bot, 'buy_vip_pass');
    v_attempt := v_attempt + 1;
    INSERT INTO public.qa_sim_exploit_attempts (
      run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
    )
    VALUES (
      p_run_id, 'premium_stack_abuse', v_bot, 2,
      coalesce(v_resp->>'success', 'false') = 'true',
      jsonb_build_object('phase', 'duplicate_stack_attempt', 'rpc', v_resp),
      0,
      -coalesce((v_resp->>'cost')::bigint, 0)
    );
  END LOOP;

  -- Bulguları ölçülen denemelerden topla
  INSERT INTO public.qa_sim_exploit_findings (
    run_id, exploit_key, attempted_count, success_count,
    estimated_impact_gold, estimated_impact_gems, severity, mitigation
  )
  SELECT
    p_run_id,
    a.exploit_key,
    count(*)::integer,
    count(*) FILTER (WHERE a.succeeded)::integer,
    coalesce(sum(a.gold_delta) FILTER (WHERE a.succeeded), 0),
    coalesce(sum(a.gems_delta) FILTER (WHERE a.succeeded), 0),
    CASE a.exploit_key
      WHEN 'multi_account_gold_funnel' THEN 'critical'
      WHEN 'premium_stack_abuse' THEN 'critical'
      WHEN 'market_price_manipulation' THEN 'high'
      WHEN 'cooldown_bypass' THEN 'high'
      WHEN 'prison_escape_abuse' THEN 'high'
      ELSE 'medium'
    END,
    CASE a.exploit_key
      WHEN 'multi_account_gold_funnel' THEN 'Device fingerprint + transfer graph + delayed escrow'
      WHEN 'market_price_manipulation' THEN 'Median band guardrails + listing caps'
      WHEN 'cooldown_bypass' THEN 'Server-side cooldown nonce enforcement'
      WHEN 'hospital_escape_abuse' THEN 'Escalating gem cost + daily cap'
      WHEN 'prison_escape_abuse' THEN 'Progressive bail cost + alt linkage penalties'
      WHEN 'premium_stack_abuse' THEN 'Idempotent VIP grant + single entitlement source'
      ELSE 'Review exploit attempt logs'
    END
  FROM public.qa_sim_exploit_attempts a
  WHERE a.run_id = p_run_id
  GROUP BY a.exploit_key
  ON CONFLICT (run_id, exploit_key)
  DO UPDATE SET
    attempted_count = EXCLUDED.attempted_count,
    success_count = EXCLUDED.success_count,
    estimated_impact_gold = EXCLUDED.estimated_impact_gold,
    estimated_impact_gems = EXCLUDED.estimated_impact_gems,
    severity = EXCLUDED.severity,
    mitigation = EXCLUDED.mitigation,
    created_at = now();

  SELECT json_build_object(
    'success', true,
    'run_id', p_run_id,
    'exploit_types', (SELECT count(DISTINCT exploit_key) FROM public.qa_sim_exploit_findings WHERE run_id = p_run_id),
    'total_attempts', (SELECT count(*) FROM public.qa_sim_exploit_attempts WHERE run_id = p_run_id)
  ) INTO v_out;

  RETURN v_out;
END;
$$;

COMMIT;
