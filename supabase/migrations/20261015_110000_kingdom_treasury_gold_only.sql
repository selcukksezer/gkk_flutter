-- Krallık kasası yalnızca altın: elmas birikmez, kral elmas dağıtamaz.

CREATE OR REPLACE FUNCTION public._kingdom_treasury_credit(
  p_currency TEXT,
  p_amount NUMERIC,
  p_kind TEXT,
  p_actor_auth_id UUID DEFAULT NULL,
  p_target_auth_id UUID DEFAULT NULL,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id TEXT DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_amt NUMERIC := GREATEST(COALESCE(p_amount, 0), 0);
  v_after NUMERIC;
  v_cur TEXT := lower(btrim(COALESCE(p_currency, 'gold')));
BEGIN
  IF v_amt <= 0 THEN
    RETURN;
  END IF;

  -- Elmas kasaya girmez (pazar/mağaza elmas vergisi yakılır).
  IF v_cur = 'gems' THEN
    RETURN;
  END IF;

  IF v_cur <> 'gold' THEN
    RETURN;
  END IF;

  UPDATE public.kingdom_treasury
  SET gold_balance = gold_balance + v_amt::bigint, updated_at = now()
  WHERE id = 1
  RETURNING gold_balance::numeric INTO v_after;

  INSERT INTO public.kingdom_treasury_ledger (
    kind, currency, amount, balance_after, actor_auth_id, target_auth_id,
    reference_type, reference_id, note
  ) VALUES (
    p_kind, 'gold', v_amt, v_after, p_actor_auth_id, p_target_auth_id,
    p_reference_type, p_reference_id, NULLIF(left(btrim(COALESCE(p_note, '')), 300), '')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_treasury_debit(
  p_currency TEXT,
  p_amount NUMERIC,
  p_kind TEXT,
  p_actor_auth_id UUID,
  p_target_auth_id UUID DEFAULT NULL,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id TEXT DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_amt NUMERIC := GREATEST(COALESCE(p_amount, 0), 0);
  v_after NUMERIC;
  v_updated INT;
  v_cur TEXT := lower(btrim(COALESCE(p_currency, 'gold')));
BEGIN
  IF v_amt <= 0 THEN
    RETURN false;
  END IF;

  -- Elmas çıkışı yok.
  IF v_cur <> 'gold' THEN
    RETURN false;
  END IF;

  UPDATE public.kingdom_treasury
  SET gold_balance = gold_balance - v_amt::bigint, updated_at = now()
  WHERE id = 1 AND gold_balance >= v_amt::bigint;
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN false;
  END IF;

  SELECT gold_balance::numeric INTO v_after FROM public.kingdom_treasury WHERE id = 1;

  INSERT INTO public.kingdom_treasury_ledger (
    kind, currency, amount, balance_after, actor_auth_id, target_auth_id,
    reference_type, reference_id, note
  ) VALUES (
    p_kind, 'gold', -v_amt, v_after, p_actor_auth_id, p_target_auth_id,
    p_reference_type, p_reference_id, NULLIF(left(btrim(COALESCE(p_note, '')), 300), '')
  );

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.king_gift_to_player(
  p_recipient_username TEXT,
  p_currency TEXT,
  p_amount BIGINT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_king UUID := auth.uid();
  v_king_username TEXT;
  v_recipient RECORD;
  v_amt BIGINT := COALESCE(p_amount, 0);
  v_cur TEXT := lower(btrim(COALESCE(p_currency, 'gold')));
  v_week date := public._kingdom_gift_week();
  v_gift_id UUID;
  v_chat TEXT;
BEGIN
  IF v_king IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF NOT public.is_current_king(v_king) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yalnızca krallık lideri hediye verebilir.');
  END IF;

  IF v_cur = 'gems' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',
      'Krallık kasasından elmas hediye edilemez.'
    );
  END IF;

  IF v_cur <> 'gold' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz para birimi.');
  END IF;

  IF v_amt < 1 OR v_amt > 1000000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hediye 1–1.000.000 arası olmalı.');
  END IF;

  SELECT u.auth_id, u.username, u.display_name
  INTO v_recipient
  FROM public.users u
  WHERE lower(u.username) = lower(btrim(COALESCE(p_recipient_username, '')))
  LIMIT 1;

  IF v_recipient.auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  IF v_recipient.auth_id = v_king THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize hediye veremezsiniz.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.kingdom_king_gifts g
    WHERE g.recipient_auth_id = v_recipient.auth_id
      AND g.gift_week = v_week
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',
      'Bu oyuncu bu hafta zaten kral hediyesi aldı.'
    );
  END IF;

  IF NOT public._kingdom_treasury_debit(
    'gold', v_amt, 'king_gift', v_king, v_recipient.auth_id,
    'king_gift', NULL, p_note
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Krallık kasasında yeterli altın yok.');
  END IF;

  UPDATE public.users
  SET gold = COALESCE(gold, 0) + v_amt::int
  WHERE auth_id = v_recipient.auth_id;

  INSERT INTO public.kingdom_king_gifts (
    king_auth_id, recipient_auth_id, currency, amount, gift_week, note
  ) VALUES (
    v_king, v_recipient.auth_id, 'gold', v_amt, v_week,
    NULLIF(left(btrim(COALESCE(p_note, '')), 300), '')
  )
  RETURNING id INTO v_gift_id;

  SELECT u.username INTO v_king_username FROM public.users u WHERE u.auth_id = v_king;

  v_chat := format(
    '👑 Kral @%s → @%s hediye: +%s 🪙',
    COALESCE(v_king_username, 'kral'),
    v_recipient.username,
    v_amt
  );

  PERFORM public._post_global_announcement_chat(
    v_king,
    left(v_chat, 200),
    'king_gift',
    jsonb_build_object(
      'gift_id', v_gift_id,
      'recipient_auth_id', v_recipient.auth_id,
      'currency', 'gold',
      'amount', v_amt
    )
  );

  PERFORM public._push_live_ticker_manual_event(
    'king_gift',
    v_chat,
    v_king,
    v_gift_id::text
  );

  PERFORM public._notify_player_inbox(
    v_recipient.auth_id,
    'king_gift',
    'Krallık hediyesi',
    format('Kraldan +%s altın aldınız.', v_amt),
    jsonb_build_object('amount', v_amt, 'currency', 'gold')
  );

  RETURN jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'amount', v_amt,
    'currency', 'gold',
    'recipient_username', v_recipient.username
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_king_powers_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_is_king boolean := false;
  v_active record;
  v_used_today boolean := false;
  v_day date := public._kingdom_blessing_day();
  v_treasury public.kingdom_treasury%ROWTYPE;
BEGIN
  IF v_user IS NOT NULL THEN
    v_is_king := public.is_current_king(v_user);
  END IF;

  SELECT * INTO v_treasury FROM public.kingdom_treasury WHERE id = 1;

  SELECT
    b.gold_discount_pct,
    b.gem_discount_pct,
    b.started_at,
    b.expires_at,
    u.username AS activated_by_username,
    g.name AS activated_by_guild_name
  INTO v_active
  FROM public.kingdom_market_blessings b
  LEFT JOIN public.users u ON u.auth_id = b.activated_by
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE b.expires_at > now()
  ORDER BY b.started_at DESC
  LIMIT 1;

  SELECT EXISTS (
    SELECT 1 FROM public.kingdom_market_blessings b WHERE b.blessing_day = v_day
  ) INTO v_used_today;

  RETURN jsonb_build_object(
    'is_king', v_is_king,
    'blessing_active', v_active.expires_at IS NOT NULL,
    'blessing_expires_at', v_active.expires_at,
    'blessing_started_at', v_active.started_at,
    'active_gold_pct', COALESCE(v_active.gold_discount_pct, 0),
    'active_gem_pct', COALESCE(v_active.gem_discount_pct, 0),
    'blessing_used_today', v_used_today,
    'blessing_activated_by_username', v_active.activated_by_username,
    'blessing_activated_by_guild_name', v_active.activated_by_guild_name,
    'max_gold_pct', 20,
    'max_gem_pct', 10,
    'duration_minutes', 30,
    'treasury_gold', COALESCE(v_treasury.gold_balance, 0),
    'treasury_gems', 0,
    'max_gift_amount', 1000000
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_kingdom_treasury_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_row public.kingdom_treasury%ROWTYPE;
  v_is_king BOOLEAN := false;
BEGIN
  SELECT * INTO v_row FROM public.kingdom_treasury WHERE id = 1;
  IF v_actor IS NOT NULL THEN
    v_is_king := public.is_current_king(v_actor);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'gold_balance', COALESCE(v_row.gold_balance, 0),
    'gems_balance', 0,
    'max_gift_amount', 1000000,
    'is_king', v_is_king,
    'recent_gifts', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', g.id,
          'king_username', ku.username,
          'recipient_username', ru.username,
          'currency', g.currency,
          'amount', g.amount,
          'created_at', g.created_at
        ) AS row
        FROM public.kingdom_king_gifts g
        JOIN public.users ku ON ku.auth_id = g.king_auth_id
        JOIN public.users ru ON ru.auth_id = g.recipient_auth_id
        WHERE g.currency = 'gold'
        ORDER BY g.created_at DESC
        LIMIT 12
      ) sub
    ), '[]'::jsonb),
    'recent_ledger', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'kind', l.kind,
          'currency', l.currency,
          'amount', l.amount,
          'created_at', l.created_at,
          'note', l.note
        ) AS row
        FROM public.kingdom_treasury_ledger l
        WHERE l.currency = 'gold'
        ORDER BY l.created_at DESC
        LIMIT 10
      ) sub2
    ), '[]'::jsonb)
  );
END;
$$;

-- Mevcut elmas bakiyesini sıfırla (dağıtılamaz / birikmez).
UPDATE public.kingdom_treasury
SET gems_balance = 0, updated_at = now()
WHERE id = 1 AND gems_balance <> 0;

GRANT EXECUTE ON FUNCTION public.get_kingdom_treasury_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.king_gift_to_player(text, text, bigint, text) TO authenticated;
