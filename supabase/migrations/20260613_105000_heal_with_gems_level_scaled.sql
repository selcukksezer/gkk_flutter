-- ============================================================
-- Migration: heal_with_gems seviye bazlı fiyat
-- ============================================================
-- QA audit bulgusu: 2 free sonrası sabit 3 gem/dk → düşük seviye
-- oyuncu (0-35 gem) hardlock oluyor (fiyat uçurumu → churn).
-- Çözüm: gem/dk oranını seviyeye göre ölçekle.
--   level < 10  → 1 gem/dk
--   level 10-19 → 2 gem/dk
--   level >= 20 → 3 gem/dk (mevcut)
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.heal_with_gems()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id uuid;
    v_hospital_until timestamptz;
    v_gems int;
    v_hospital_count int;
    v_level int;
    v_rate int;
    v_minutes_left int;
    v_gem_cost int;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT hospital_until, gems, COALESCE(hospital_lifetime_count, 0), COALESCE(level, 1)
    INTO v_hospital_until, v_gems, v_hospital_count, v_level
    FROM public.users
    WHERE auth_id = v_user_id;

    IF v_hospital_until IS NULL OR v_hospital_until <= now() THEN
        UPDATE public.users SET hospital_until = NULL, hospital_reason = NULL WHERE auth_id = v_user_id;
        RETURN json_build_object('success', true);
    END IF;

    -- İlk 2 yatış ücretsiz
    IF v_hospital_count <= 2 THEN
        UPDATE public.users
        SET hospital_until = NULL, hospital_reason = NULL
        WHERE auth_id = v_user_id;
        RETURN json_build_object('success', true, 'was_free', true, 'cost', 0,
            'free_discharges_remaining', GREATEST(0, 2 - v_hospital_count));
    END IF;

    v_minutes_left := CEIL(EXTRACT(EPOCH FROM (v_hospital_until - now())) / 60.0);
    IF v_minutes_left < 1 THEN v_minutes_left := 1; END IF;

    -- Seviye bazlı oran: düşük seviye oyuncuyu fiyat uçurumundan korur
    v_rate := CASE WHEN v_level < 10 THEN 1 WHEN v_level < 20 THEN 2 ELSE 3 END;
    v_gem_cost := v_minutes_left * v_rate;

    IF v_gems < v_gem_cost THEN
        RETURN json_build_object('success', false, 'error', 'Yetersiz elmas. Gerekli: ' || v_gem_cost);
    END IF;

    UPDATE public.users
    SET gems = gems - v_gem_cost, hospital_until = NULL, hospital_reason = NULL
    WHERE auth_id = v_user_id;

    RETURN json_build_object('success', true, 'was_free', false, 'cost', v_gem_cost,
        'free_discharges_remaining', 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.heal_with_gems() TO authenticated;

COMMIT;
