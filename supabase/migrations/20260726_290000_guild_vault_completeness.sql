-- Lonca kasası tamamlama: territory loot, siege/tournament geliri, officer görünürlük.

BEGIN;

ALTER TABLE public.guild_war_tournaments
  ADD COLUMN IF NOT EXISTS prize_gold BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS winner_guild_id UUID REFERENCES public.guilds(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS prize_paid_at TIMESTAMPTZ;

UPDATE public.guild_war_tournaments
SET prize_gold = CASE
  WHEN name ILIKE '%final%' THEN 250000
  WHEN name ILIKE '%arena%' THEN 50000
  ELSE 25000
END
WHERE prize_gold = 0;

CREATE TABLE IF NOT EXISTS public.guild_vault_territory_loot_state (
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  territory_id UUID NOT NULL REFERENCES public.guild_war_territories(id) ON DELETE CASCADE,
  last_loot_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (guild_id, territory_id)
);

-- Territory loot seed (yüksek tier bölgeler)
UPDATE public.guild_war_territories t
SET
  loot_item_id = COALESCE(t.loot_item_id, 'rune_legendary'),
  loot_item_chance = COALESCE(NULLIF(t.loot_item_chance, 0), 0.12)
WHERE COALESCE(t.zone_number, 0) >= 5;

UPDATE public.guild_war_territories t
SET
  loot_item_id = COALESCE(t.loot_item_id, 'scroll_upgrade_high'),
  loot_item_chance = COALESCE(NULLIF(t.loot_item_chance, 0), 0.08)
WHERE COALESCE(t.zone_number, 0) IN (3, 4)
  AND t.loot_item_id IS NULL;

CREATE OR REPLACE FUNCTION public.credit_guild_vault_pending(
  p_guild_id UUID,
  p_amount BIGINT,
  p_source_type TEXT,
  p_ref TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_amount BIGINT := GREATEST(COALESCE(p_amount, 0), 0);
BEGIN
  IF p_guild_id IS NULL OR v_amount <= 0 THEN
    RETURN 0;
  END IF;

  UPDATE public.guilds
  SET vault_gold_pending = vault_gold_pending + v_amount
  WHERE id = p_guild_id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    p_guild_id,
    auth.uid(),
    COALESCE(p_source_type, 'credit'),
    jsonb_build_object('amount', v_amount, 'ref', p_ref)
  );

  RETURN v_amount;
END;
$$;

CREATE OR REPLACE FUNCTION public._accrue_guild_vault_territory_loot(p_guild_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row RECORD;
  v_state RECORD;
  v_added INTEGER := 0;
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  FOR v_row IN
    SELECT t.id AS territory_id, t.loot_item_id, COALESCE(t.loot_item_chance, 0) AS loot_chance
    FROM public.guild_war_territories t
    WHERE t.owner_guild_id = p_guild_id
      AND t.loot_item_id IS NOT NULL
      AND COALESCE(t.loot_item_chance, 0) > 0
  LOOP
    SELECT * INTO v_state
    FROM public.guild_vault_territory_loot_state
    WHERE guild_id = p_guild_id AND territory_id = v_row.territory_id;

    IF FOUND AND v_state.last_loot_at > now() - interval '7 days' THEN
      CONTINUE;
    END IF;

    IF random() <= v_row.loot_chance THEN
      INSERT INTO public.guild_vault_items (guild_id, item_id, quantity, source_type, source_ref)
      VALUES (p_guild_id, v_row.loot_item_id, 1, 'territory_loot', v_row.territory_id::text);

      INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
      VALUES (
        p_guild_id,
        auth.uid(),
        'territory_loot',
        jsonb_build_object(
          'territory_id', v_row.territory_id,
          'item_id', v_row.loot_item_id
        )
      );

      v_added := v_added + 1;
    END IF;

    INSERT INTO public.guild_vault_territory_loot_state (guild_id, territory_id, last_loot_at)
    VALUES (p_guild_id, v_row.territory_id, now())
    ON CONFLICT (guild_id, territory_id) DO UPDATE
      SET last_loot_at = EXCLUDED.last_loot_at;
  END LOOP;

  RETURN v_added;
END;
$$;

CREATE OR REPLACE FUNCTION public._accrue_guild_vault(p_guild_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_guild RECORD;
  v_now TIMESTAMPTZ := now();
  v_from TIMESTAMPTZ;
  v_hours NUMERIC;
  v_cap_hours NUMERIC := 168;
  v_delta BIGINT := 0;
  v_row RECORD;
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT id, vault_last_accrual_at, vault_gold_pending
  INTO v_guild
  FROM public.guilds
  WHERE id = p_guild_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  v_from := COALESCE(v_guild.vault_last_accrual_at, v_now - interval '1 hour');
  v_hours := EXTRACT(EPOCH FROM (v_now - v_from)) / 3600.0;
  IF v_hours <= 0 THEN
    PERFORM public._accrue_guild_vault_territory_loot(p_guild_id);
    SELECT vault_gold_pending INTO v_delta FROM public.guilds WHERE id = p_guild_id;
    RETURN COALESCE(v_delta, 0);
  END IF;
  v_hours := LEAST(v_hours, v_cap_hours);

  FOR v_row IN
    SELECT COALESCE(trade_income, 0) AS trade_income
    FROM public.guild_war_territories
    WHERE owner_guild_id = p_guild_id
  LOOP
    v_delta := v_delta + (v_row.trade_income * v_hours / 24.0)::BIGINT;
  END LOOP;

  IF v_delta > 0 THEN
    UPDATE public.guilds
    SET vault_gold_pending = vault_gold_pending + v_delta,
        vault_last_accrual_at = v_now
    WHERE id = p_guild_id;

    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      p_guild_id,
      auth.uid(),
      'accrue',
      jsonb_build_object('amount', v_delta, 'hours', v_hours)
    );
  ELSE
    UPDATE public.guilds
    SET vault_last_accrual_at = v_now
    WHERE id = p_guild_id;
  END IF;

  PERFORM public._accrue_guild_vault_territory_loot(p_guild_id);

  SELECT vault_gold_pending INTO v_delta FROM public.guilds WHERE id = p_guild_id;
  RETURN COALESCE(v_delta, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.grant_guild_war_tournament_prize(
  p_tournament_id UUID,
  p_winner_guild_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tournament RECORD;
  v_winner UUID;
  v_final RECORD;
  v_amount BIGINT;
BEGIN
  SELECT * INTO v_tournament
  FROM public.guild_war_tournaments
  WHERE id = p_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Turnuva bulunamadı.');
  END IF;

  IF v_tournament.prize_paid_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'already_paid', true);
  END IF;

  v_winner := COALESCE(p_winner_guild_id, v_tournament.winner_guild_id);

  IF v_winner IS NULL THEN
    SELECT m.winner_guild_id INTO v_winner
    FROM public.guild_war_tournament_matches m
    WHERE m.tournament_id = p_tournament_id
      AND m.winner_guild_id IS NOT NULL
    ORDER BY m.round_number DESC, m.match_order DESC
    LIMIT 1;
  END IF;

  IF v_winner IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Turnuva kazananı yok.');
  END IF;

  v_amount := GREATEST(COALESCE(v_tournament.prize_gold, 0), 0);
  IF v_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül miktarı tanımlı değil.');
  END IF;

  PERFORM public.credit_guild_vault_pending(
    v_winner,
    v_amount,
    'tournament',
    p_tournament_id::text
  );

  UPDATE public.guild_war_tournaments
  SET winner_guild_id = v_winner,
      prize_paid_at = now(),
      status = CASE WHEN status = 'active' THEN 'completed' ELSE status END
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true,
    'winner_guild_id', v_winner,
    'prize_gold', v_amount
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_guild_vault()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_guild RECORD;
  v_role TEXT;
  v_items JSONB;
  v_ledger JSONB;
  v_territories JSONB;
  v_is_leader BOOLEAN;
  v_is_officer BOOLEAN;
  v_tournament RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT u.guild_id, COALESCE(u.guild_role, 'member')
  INTO v_guild_id, v_role
  FROM public.users u
  WHERE u.auth_id = v_user;

  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  PERFORM public._accrue_guild_vault(v_guild_id);

  -- Bitmiş turnuva ödülü (idempotent, global)
  FOR v_tournament IN
    SELECT t.id
    FROM public.guild_war_tournaments t
    WHERE t.status IN ('active', 'completed')
      AND t.end_at <= now()
      AND t.prize_paid_at IS NULL
      AND COALESCE(t.prize_gold, 0) > 0
    LIMIT 5
  LOOP
    PERFORM public.grant_guild_war_tournament_prize(v_tournament.id, NULL);
  END LOOP;

  SELECT g.* INTO v_guild FROM public.guilds g WHERE g.id = v_guild_id;

  v_is_leader := v_guild.leader_id = v_user;
  v_is_officer := v_role IN ('officer', 'commander') AND NOT v_is_leader;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', vi.id,
    'item_id', vi.item_id,
    'item_name', COALESCE(i.name, vi.item_id),
    'rarity', i.rarity,
    'quantity', vi.quantity,
    'source_type', vi.source_type,
    'created_at', vi.created_at
  ) ORDER BY vi.created_at DESC), '[]'::jsonb)
  INTO v_items
  FROM public.guild_vault_items vi
  LEFT JOIN public.items i ON i.id = vi.item_id
  WHERE vi.guild_id = v_guild_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', l.id,
    'action', l.action,
    'payload', l.payload,
    'actor_id', l.actor_id,
    'created_at', l.created_at
  ) ORDER BY l.created_at DESC), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT * FROM public.guild_vault_ledger
    WHERE guild_id = v_guild_id
    ORDER BY created_at DESC
    LIMIT 50
  ) l;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'name', t.name,
    'trade_income', COALESCE(t.trade_income, 0),
    'zone_number', t.zone_number,
    'loot_item_id', t.loot_item_id,
    'loot_item_chance', t.loot_item_chance
  ) ORDER BY t.zone_number NULLS LAST), '[]'::jsonb)
  INTO v_territories
  FROM public.guild_war_territories t
  WHERE t.owner_guild_id = v_guild_id;

  RETURN jsonb_build_object(
    'success', true,
    'guild_id', v_guild_id,
    'is_leader', v_is_leader,
    'is_officer', v_is_officer,
    'can_manage', v_is_leader,
    'vault_gold', COALESCE(v_guild.vault_gold, 0),
    'vault_gold_pending', COALESCE(v_guild.vault_gold_pending, 0),
    'monument_gold_pool', COALESCE(v_guild.monument_gold_pool, 0),
    'items', v_items,
    'ledger', v_ledger,
    'territories', v_territories
  );
END;
$$;

-- Kuşatma slot alımı → lonca kasasına küçük gold
CREATE OR REPLACE FUNCTION public.claim_siege_slot(p_dungeon_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_player record;
  v_cfg public.dungeon_siege_config;
  v_session_id uuid;
  v_slot record;
  v_zone integer;
  v_territory_owner uuid;
  v_siege_gold BIGINT;
  v_result jsonb;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  IF public.dungeon_siege_is_banned(v_me, p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindandan banlısın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastane/cezaevinde slot alamazsın.');
  END IF;

  IF public.dungeon_siege_player_holds_any_slot(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir kuşatma slotu tutuyorsun.');
  END IF;

  IF public.dungeon_siege_player_has_slot(v_me, p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindanda zaten slot tutuyorsun.');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = v_me;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu profili bulunamadı.');
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_session_id := public.dungeon_siege_ensure_session(p_dungeon_id);
  IF v_session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma oturumu başlatılamadı.');
  END IF;

  v_zone := public.dungeon_siege_zone_for_dungeon(p_dungeon_id);
  v_territory_owner := public.dungeon_siege_territory_owner_for_zone(v_zone);

  SELECT * INTO v_slot
  FROM public.dungeon_siege_slots s
  WHERE s.session_id = v_session_id
    AND s.holder_id IS NULL
    AND (
      v_cfg.territory_reserve_slot_count <= 0
      OR v_territory_owner IS NULL
      OR s.slot_number > v_cfg.territory_reserve_slot_count
      OR v_player.guild_id IS NOT DISTINCT FROM v_territory_owner
    )
  ORDER BY s.slot_number
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN v_territory_owner IS NOT NULL
             AND v_player.guild_id IS DISTINCT FROM v_territory_owner
        THEN 'Bölge sahibi lonca rezerv slotları dolu. Meydan oku.'
        ELSE 'Boş slot yok. Meydan oku.'
      END
    );
  END IF;

  UPDATE public.dungeon_siege_slots
  SET holder_id = v_me,
      guild_id = v_player.guild_id,
      claimed_at = now(),
      expires_at = now() + make_interval(mins => v_cfg.slot_duration_minutes),
      last_active_at = now()
  WHERE id = v_slot.id;

  PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 5, p_slot_minutes => 0);

  IF v_player.guild_id IS NOT NULL THEN
    SELECT GREATEST(250, COALESCE(t.trade_income, 0) / 20)::BIGINT
    INTO v_siege_gold
    FROM public.guild_war_territories t
    WHERE t.zone_number = v_zone
    LIMIT 1;

    v_siege_gold := COALESCE(v_siege_gold, 250);
    PERFORM public.credit_guild_vault_pending(
      v_player.guild_id,
      v_siege_gold,
      'siege_reward',
      p_dungeon_id
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'slot_id', v_slot.id,
    'slot_number', v_slot.slot_number,
    'expires_at', now() + make_interval(mins => v_cfg.slot_duration_minutes),
    'territory_reserved', v_territory_owner IS NOT NULL
      AND v_slot.slot_number <= v_cfg.territory_reserve_slot_count,
    'message', 'Slot alındı! Bonus farm başladı.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.credit_guild_vault_pending(uuid, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_guild_war_tournament_prize(uuid, uuid) TO authenticated;

COMMIT;
