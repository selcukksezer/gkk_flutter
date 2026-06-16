-- ============================================================
-- Migration: QA fonksiyonları kilitleme
-- ============================================================
-- QA audit bulgusu: qa_cleanup_bots ve diğer QA RPC'leri
-- authenticated rolüne EXECUTE açıktı + qa_cleanup_bots'ta
-- qa_mode guard yoktu → herhangi giriş yapmış kullanıcı
-- destructive cleanup / bot impersonation çağırabiliyordu.
-- Bu migration: tüm qa_* fonksiyonlarından authenticated+anon
-- EXECUTE'u geri alır, qa_cleanup_bots'a qa_mode guard ekler.
-- (service_role hâlâ çağırabilir; QA işlemleri service_role ile yapılır.)
-- ============================================================

BEGIN;

-- 1) qa_cleanup_bots'a qa_mode guard ekle
CREATE OR REPLACE FUNCTION public.qa_cleanup_bots()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_deleted_users integer;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.market_orders WHERE seller_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');
  DELETE FROM public.pvp_matches WHERE attacker_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%') OR defender_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');
  DELETE FROM public.dungeon_runs WHERE player_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');
  DELETE FROM auth.users au USING public.users u WHERE au.id = u.auth_id AND u.username LIKE 'qa_bot_%';
  GET DIAGNOSTICS v_deleted_users = ROW_COUNT;
  DELETE FROM public.users WHERE username LIKE 'qa_bot_%';
  DELETE FROM public.qa_bot_profiles;
  DELETE FROM public.mekans m USING public.users u WHERE m.name LIKE 'QA Mekan %' AND u.auth_id = m.owner_id AND u.username LIKE 'qa_bot_%';
  RETURN json_build_object('success', true, 'deleted_auth_users', v_deleted_users);
END;
$$;

-- 2) Tüm qa_* fonksiyonlarından authenticated + anon EXECUTE geri al
REVOKE EXECUTE ON FUNCTION public.qa_cleanup_bots()                              FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_seed_bots(integer)                          FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_seed_mekans(integer)                        FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_run_30_day_simulation(integer, uuid)        FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_run_exploit_battery(uuid)                   FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_call_as_bot(uuid, text)                     FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_export_run_summary(uuid)                    FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_create_full_snapshot_backup(text)           FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_restore_snapshot_backup(text)              FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_active_probability(text, integer)           FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_segment_for_bot(integer, integer)           FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.qa_assert_qa_mode()                            FROM authenticated, anon, PUBLIC;

COMMIT;
