-- Monument donate: inventory CHECK requires quantity > 0 — delete row when stack empties.

CREATE OR REPLACE FUNCTION public._consume_inventory_item(
  p_user_id UUID,
  p_item_id TEXT,
  p_qty INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_remaining INT := p_qty;
  v_row RECORD;
  v_take INT;
BEGIN
  IF p_qty IS NULL OR p_qty <= 0 THEN
    RETURN true;
  END IF;

  IF (
    SELECT COALESCE(SUM(quantity), 0)::INT
    FROM public.inventory
    WHERE user_id = p_user_id AND item_id = p_item_id
  ) < p_qty THEN
    RETURN false;
  END IF;

  FOR v_row IN
    SELECT row_id, quantity
    FROM public.inventory
    WHERE user_id = p_user_id AND item_id = p_item_id AND quantity > 0
    ORDER BY created_at ASC
    FOR UPDATE
  LOOP
    EXIT WHEN v_remaining <= 0;
    v_take := LEAST(v_row.quantity, v_remaining);
    IF v_row.quantity > v_take THEN
      UPDATE public.inventory
      SET quantity = quantity - v_take, updated_at = now()
      WHERE row_id = v_row.row_id;
    ELSE
      DELETE FROM public.inventory WHERE row_id = v_row.row_id;
    END IF;
    v_remaining := v_remaining - v_take;
  END LOOP;

  RETURN v_remaining <= 0;
END;
$$;

REVOKE ALL ON FUNCTION public._consume_inventory_item(UUID, TEXT, INT) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.donate_to_monument(
  p_user_id UUID,
  p_structural INT DEFAULT 0,
  p_mystical INT DEFAULT 0,
  p_critical INT DEFAULT 0,
  p_gold BIGINT DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
  v_guild_id UUID;
  v_daily RECORD;
  v_contribution_score BIGINT;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz');
  END IF;
  v_guild_id := v_user.guild_id;

  SELECT * INTO v_daily
  FROM public.guild_daily_donations
  WHERE guild_id = v_guild_id AND user_id = p_user_id AND donation_date = CURRENT_DATE
  FOR UPDATE;

  IF FOUND THEN
    IF v_daily.structural_today + p_structural > 500 OR
       v_daily.mystical_today + p_mystical > 200 OR
       v_daily.critical_today + p_critical > 50 OR
       v_daily.gold_today + p_gold > 10000000 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Günlük bağış sınırını aştınız');
    END IF;
  ELSE
    IF p_structural > 500 OR p_mystical > 200 OR p_critical > 50 OR p_gold > 10000000 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Günlük bağış sınırını aştınız');
    END IF;
  END IF;

  IF p_gold > 0 AND v_user.gold < p_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli altınınız yok');
  END IF;

  IF p_structural > 0 AND NOT public._consume_inventory_item(p_user_id, 'resource_structural', p_structural) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli yapısal kaynağınız yok');
  END IF;

  IF p_mystical > 0 AND NOT public._consume_inventory_item(p_user_id, 'resource_mystical', p_mystical) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli mistik kaynağınız yok');
  END IF;

  IF p_critical > 0 AND NOT public._consume_inventory_item(p_user_id, 'resource_critical', p_critical) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli kritik kaynağınız yok');
  END IF;

  IF p_gold > 0 THEN
    UPDATE public.users SET gold = gold - p_gold WHERE auth_id = p_user_id AND gold >= p_gold;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yeterli altınınız yok');
    END IF;
  END IF;

  v_contribution_score := p_structural * 10 + p_mystical * 25 + p_critical * 100 + p_gold / 1000;

  UPDATE public.guilds SET
    monument_structural = monument_structural + p_structural,
    monument_mystical = monument_mystical + p_mystical,
    monument_critical = monument_critical + p_critical,
    monument_gold_pool = monument_gold_pool + p_gold
  WHERE id = v_guild_id;

  INSERT INTO public.guild_contributions (
    guild_id, user_id, structural_donated, mystical_donated, critical_donated,
    gold_donated, contribution_score, last_donated_at
  )
  VALUES (v_guild_id, p_user_id, p_structural, p_mystical, p_critical, p_gold, v_contribution_score, now())
  ON CONFLICT (guild_id, user_id) DO UPDATE SET
    structural_donated = public.guild_contributions.structural_donated + EXCLUDED.structural_donated,
    mystical_donated = public.guild_contributions.mystical_donated + EXCLUDED.mystical_donated,
    critical_donated = public.guild_contributions.critical_donated + EXCLUDED.critical_donated,
    gold_donated = public.guild_contributions.gold_donated + EXCLUDED.gold_donated,
    contribution_score = public.guild_contributions.contribution_score + EXCLUDED.contribution_score,
    last_donated_at = now();

  INSERT INTO public.guild_daily_donations (
    guild_id, user_id, donation_date, structural_today, mystical_today, critical_today, gold_today
  )
  VALUES (v_guild_id, p_user_id, CURRENT_DATE, p_structural, p_mystical, p_critical, p_gold)
  ON CONFLICT (guild_id, user_id, donation_date) DO UPDATE SET
    structural_today = public.guild_daily_donations.structural_today + EXCLUDED.structural_today,
    mystical_today = public.guild_daily_donations.mystical_today + EXCLUDED.mystical_today,
    critical_today = public.guild_daily_donations.critical_today + EXCLUDED.critical_today,
    gold_today = public.guild_daily_donations.gold_today + EXCLUDED.gold_today;

  RETURN jsonb_build_object('success', true, 'score_added', v_contribution_score);
END;
$$;

GRANT EXECUTE ON FUNCTION public.donate_to_monument(UUID, INT, INT, INT, BIGINT) TO authenticated;
