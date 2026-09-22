# Battle Pass Quest Pacing — Status

**Tarih:** 2026-07-31  
**Workspace:** `/Users/selcuk/Documents/gkk-web/gkk_flutter`  
**Kanıt:** canlı Supabase MCP (`execute_sql` / `apply_migration`)  
**Kapsam:** `bp_quest_templates` BPP, `bp_ensure_player_initialized`, `bp_refresh_player_quests`  
**Dokunulmadı:** zone gates / power luck / horse race

---

## 1. Executive summary

| Soru | Cevap |
|------|--------|
| Migration dosyası var mı? | **Evet** — `supabase/migrations/20261015_130000_bp_season_quest_pacing.sql` |
| İçerik intended fix ile uyumlu mu? | **Evet** |
| Canlıya uygulanmış mıydı? | **Hayır** (önce) |
| Şimdi uygulandı mı? | **Evet** — `schema_migrations`: `20260731141214` / `bp_season_quest_pacing` |
| 1 weekly claim → 3–4 ödül? | **Düzeltildi** — max weekly **700 BPP** vs **1000 BPP/level** → **0.7 level** |

**Kök neden (eski):** weekly **3000 BPP**, level = `current_bpp / 1000` → 1 claim = **3 level**. Tiny pool + assign-once/season.

---

## 2. Before / after (live)

| Metrik | BEFORE (live) | AFTER (live) |
|--------|---------------:|-------------:|
| Daily BPP | 400 (hepsi) | **150 / 200 / 250** |
| Weekly BPP | 3000 (hepsi) | **500 / 600 / 700** |
| Daily pool `n` | 6 (dupeli 3) | **11** (dedupe + expand) |
| Weekly pool `n` | 8 (dupeli 4) | **10** |
| Max weekly → levels | 3000 / 1000 = **3.0** | 700 / 1000 = **0.7** |
| `bp_refresh_player_quests` | yok | **var** |
| `daily_quests_date` / `weekly_quests_week` | yok | **var** |
| `bp_ensure_player_initialized` | 3 daily + **tüm** weekly, bir kez | → `bp_refresh_player_quests` (5/day + 4/week) |
| Craft double-grant quest BPP | risk | rarity BPP only + progress; claim path ayrı |

Smoke math: `max_weekly (700) < 1000` → tek weekly claim **tam 1 level bile açmaz**, 3–4 ödül imkânsız.

---

## 3. Client UI

Client `bpp_reward` DB/API’den okuyor (`BpQuestTemplate.fromJson`, quest/season screens). Hardcoded 3000 yok → **client sync gerekmedi**.

---

## 4. Residual / follow-up

1. **Eski oyuncu slotları:** claim anında template BPP canlı okunur → eski weekly satırlar da artık 500–700 verir. Slot sayısı: bir sonraki `bp_ensure_player_initialized` / hafta roll ile refresh; hafta bitmeden fazla weekly slot kalabilir (BPP yine capped).
2. **CASE vs INSERT nuance:** örn. `potion` weekly count 40 INSERT 500 demiş → CASE `>30` → **700**. Band içi (500–700); retune istenirse ayrı migration.
3. **Local vs remote version adı:** repo file `20261015_130000_...`; remote `apply_migration` → `20260731141214_bp_season_quest_pacing`. CLI `db push` öncesi version drift kontrol et.
4. Store/QA: gerçek oyuncu ile 1 weekly claim → BPP +700 max, level jump ≤0 doğrula.

---

## 5. Applied migration ref

- Local: `supabase/migrations/20261015_130000_bp_season_quest_pacing.sql`
- Remote: `supabase_migrations.schema_migrations` → `version=20260731141214`, `name=bp_season_quest_pacing`
