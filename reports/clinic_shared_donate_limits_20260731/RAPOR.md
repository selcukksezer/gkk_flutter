# Klinik + Anıt ortak bağış limiti & kasa

**Tarih:** 2026-07-31  
**Workspace:** `/Users/selcuk/Documents/gkk-web/gkk_flutter`  
**Live:** Supabase MCP `clinic_shared_donate_limits` (`version=20260731191957`)  
**Commit:** yok

---

## 1. Önce (ayrı)

| Parça | Anıt | Klinik |
|-------|------|--------|
| Günlük bağış limiti | `guild_daily_donations` + `_monument_daily_limits()` | **Yok** (sınırsız) |
| Altın hedefi | `vault_gold` (+ ledger) | Zaten `vault_gold` |
| Kaynak hedefi | `monument_*` pool | `clinic_*` pool (upgrade meter) |
| Doktor/avukat hak | — | `guild_clinic_daily_uses` (ayrı; dokunulmadı) |

UI bug: klinik `dailyLimits = wallet` → limit yokmuş gibi davranıyordu.

---

## 2. Sonra (ortak)

| Parça | Durum |
|-------|--------|
| Günlük bağış limiti | **Tek pool** — anıt veya klinik bağışı aynı `guild_daily_donations` satırını tüketir |
| Kasa | **Tek** `guilds.vault_gold` + `guild_vault_ledger` (`clinic_donate_gold` / monument ledger) |
| Upgrade pool | Ayrı kalır (`monument_*` vs `clinic_*`) — seviye progress meter, kasa değil |
| Doktor/avukat | Değişmedi — 1 shared use / Istanbul day |

### Limit kuralları (`_monument_daily_limits`)

| Kaynak | Günlük max |
|--------|-----------:|
| structural | 500 |
| mystical | 200 |
| critical | 50 |
| gold | 10_000_000 |

Tarih: `CURRENT_DATE` (anıt ile aynı). Aşım → `'Günlük bağış sınırını aştınız'`.

Klinik bağış ayrıca `guild_contributions` skorunu günceller (anıt ile aynı formül).

---

## 3. Dosyalar

| Dosya | Ne |
|-------|----|
| `supabase/migrations/20261017_120000_clinic_shared_donate_limits.sql` | `donate_to_clinic` + `get_clinic_dashboard` |
| `lib/screens/guild/widgets/guild_clinic_card.dart` | ortak limit UI (`my_today` / `daily_limits`) |
| `lib/l10n/app_tr.arb` / `app_en.arb` (+ gen) | flavor + shared hint + `owned_left` |

RPC dokunuş: `donate_to_clinic`, `get_clinic_dashboard`.  
Dokunulmadı: `use_guild_doctor`, `use_guild_lawyer`, hospital/prison escape.

---

## 4. Live doğrulama

- `donate_to_clinic` → `guild_daily_donations` + `_monument_daily_limits` + limit error + `vault_gold`
- `get_clinic_dashboard` → `daily_limits` + `my_today`
- `schema_migrations`: `20260731191957` / `clinic_shared_donate_limits`
