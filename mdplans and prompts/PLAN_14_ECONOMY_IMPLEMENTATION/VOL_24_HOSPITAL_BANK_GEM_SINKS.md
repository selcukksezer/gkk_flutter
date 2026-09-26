# PLAN 14 — Cilt 24: Hastane, Hapishane, Banka Elmas Sink

> **Öncelik:** P1

---

## Hastane — `heal_with_gems`

- 1–3 elmas/dakika (level scale)
- İlk 2 ziyaret ücretsiz (lifetime count)
- `reduce_timer_with_ad` — 3/gün, para yok

---

## Hapishane

- Ad timer reduce — 3/gün
- Bail gold path — doğrula

---

## Banka — `expand_bank_slots`

- **Server: 5 elmas/slot** (`20260721_220000`)
- **UI bug: 50 elmas gösterir** — düzelt VOL_11 + VOL_25
- Max 200 slot → max 1000 gem sink/user

---

## Migration

`20260722_170000_bank_ui_server_cost_sync.sql` — yalnız Flutter; server doğru

---

## Kabul

- [ ] Bank UI 5 gem
- [ ] heal_with_gems level scale test
- [ ] Gem sink ledger'da hospital+bank
