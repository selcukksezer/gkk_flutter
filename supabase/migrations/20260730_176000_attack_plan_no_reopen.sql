-- Block reopen/cancel of open attack plan (gems must not be wiped).

BEGIN;

CREATE OR REPLACE FUNCTION public.guild_war_open_attack_plan(p_territory_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_leader UUID;
  v_terr RECORD;
  v_plan_id UUID;
  v_existing RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  SELECT leader_id INTO v_leader FROM public.guilds WHERE id = v_guild_id;
  IF v_leader IS DISTINCT FROM v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lonca başkanı saldırı planı açabilir.');
  END IF;

  SELECT * INTO v_terr FROM public.guild_war_territories WHERE id = p_territory_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;
  IF v_terr.owner_guild_id = v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  IF v_terr.owner_guild_id IS NOT NULL
     AND v_terr.updated_at > now() - interval '2 hours' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yeni fetih koruması aktif.',
      'grace_until', v_terr.updated_at + interval '2 hours'
    );
  END IF;

  -- Already open for this territory → keep gems/support, do not recreate
  SELECT * INTO v_existing
  FROM public.guild_war_attack_plan
  WHERE attacker_guild_id = v_guild_id
    AND territory_id = p_territory_id
    AND status = 'open'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_open', true,
      'plan_id', v_existing.id,
      'gem_attack_boost', COALESCE(v_existing.gem_attack_boost, 0),
      'message', 'Bu bölgede zaten açık plan var. Yeniden açılmaz — elmaslar korunur.'
    );
  END IF;

  -- Cancel other open plans on DIFFERENT territories only (same guild one plan at a time?)
  -- User complaint: reopen wastes gems. Keep other-territory cancel OR not?
  -- Safer: only one open plan per guild total was old behavior.
  -- Don't cancel if it has gem boost — return error instead.
  IF EXISTS (
    SELECT 1 FROM public.guild_war_attack_plan
    WHERE attacker_guild_id = v_guild_id
      AND status = 'open'
      AND territory_id IS DISTINCT FROM p_territory_id
      AND COALESCE(gem_attack_boost, 0) > 0
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Başka bölgede elmaslı açık plan var. Önce o saldırıyı bitir; elmas boşa gitmesin.'
    );
  END IF;

  UPDATE public.guild_war_attack_plan
  SET status = 'cancelled'
  WHERE attacker_guild_id = v_guild_id
    AND status = 'open'
    AND territory_id IS DISTINCT FROM p_territory_id
    AND COALESCE(gem_attack_boost, 0) = 0;

  INSERT INTO public.guild_war_attack_plan (
    territory_id, attacker_guild_id, leader_id, closes_at, status
  ) VALUES (
    p_territory_id, v_guild_id, v_user, NULL, 'open'
  ) RETURNING id INTO v_plan_id;

  INSERT INTO public.guild_war_attack_support (plan_id, user_id, power_snapshot)
  SELECT v_plan_id, v_user, COALESCE(power, 0)
  FROM public.users WHERE auth_id = v_user;

  RETURN jsonb_build_object(
    'success', true,
    'already_open', false,
    'plan_id', v_plan_id,
    'message', 'Saldırı planı açıldı. Üyeler güç + elmas destekleyebilir.'
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.guild_war_open_attack_plan(uuid) TO authenticated;

COMMIT;
