BEGIN;
SET LOCAL app.qa_mode = 'true';

DELETE FROM public.market_orders WHERE seller_id IN (SELECT id FROM auth.users WHERE email LIKE 'qa_bot_%');
DELETE FROM public.pvp_matches WHERE attacker_id IN (SELECT id FROM auth.users WHERE email LIKE 'qa_bot_%') OR defender_id IN (SELECT id FROM auth.users WHERE email LIKE 'qa_bot_%');
DELETE FROM public.inventory WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE 'qa_bot_%');
DELETE FROM public.dungeon_runs WHERE player_id IN (SELECT id FROM auth.users WHERE email LIKE 'qa_bot_%');
DELETE FROM public.qa_bot_profiles;
DELETE FROM public.users WHERE username LIKE 'qa_bot_%';
DELETE FROM auth.users WHERE email LIKE 'qa_bot_%';

COMMIT;
