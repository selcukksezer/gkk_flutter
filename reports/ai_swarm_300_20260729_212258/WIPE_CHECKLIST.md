# Launch Wipe Checklist — AI Live-Play Bots

Pre-launch: QA DB kirli (bilerek). Oyun çıkmadan önce bot verisi **silinmeli**.

## 1) Rapor arşivle

```bash
mkdir -p reports/archive
cp -R reports/ai_swarm_300_* reports/archive/ 2>/dev/null || true
```

## 2) Bot wipe

```bash
./scripts/qa_wipe_bots.sh
# veya:
# SELECT set_config('app.qa_mode','true',true);
# SELECT public.qa_wipe_live_play_bots();
```

Bu çağrı `qa_cleanup_bots()` çalıştırır:

- `qa_bot_%` auth + public users
- `QA Lonca %` guilds + contributions
- inventory / pvp / market / dungeon_runs / mekans bot satırları

## 3) Doğrula

```sql
SELECT count(*) FROM public.users WHERE username LIKE 'qa_bot_%';  -- expect 0
SELECT count(*) FROM public.guilds WHERE name LIKE 'QA Lonca %'; -- expect 0
SELECT count(*) FROM public.qa_bot_profiles;                     -- expect 0
```

## 4) Full DB reset (opsiyonel)

Staging’de full dump restore / fresh migrate. Production’a bot seed **asla** taşıma.

## 5) Credentials

Bot password (seed): `QaLivePlay300!`  
Email: `qa_bot_NNN@sim.local`

Launch sonrası bu şifreleri rotate etme — hesaplar silinmiş olmalı.
