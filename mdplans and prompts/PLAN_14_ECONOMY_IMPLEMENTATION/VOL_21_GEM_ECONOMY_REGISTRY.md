# PLAN 14 — Cilt 21: Elmas Musluk ve Sink Kayıt Defteri

> **Öncelik:** P1 — IAP öncesi/sonrası denge

---

## Elmas IN (Mint)

| Kaynak | Yıllık ~ (F2P) |
|--------|----------------|
| Günlük ödül (perfect) | 1.570 |
| Quest | ~3.400 |
| Referral (5 kişi) | 250 |
| Battle Pass | 0 (cost −500/sezon) |
| At yarışı kazanç | değişken |
| **IAP** | **0 (canlı değil)** |

**F2P net:** ~4.700/yıl − BP 500×26 ≈ deficit

---

## Elmas OUT (Sink)

| Sink | Maliyet | RPC |
|------|---------|-----|
| Gem loot box | 50–300 | `open_loot_box` |
| BP VIP | 500/sezon | `buy_vip_pass` |
| Hastane | 1–3/dk | `heal_with_gems` |
| Banka slot | 5/slot | `expand_bank_slots` |
| Stat scroll | 199 | shop |
| Rüşvet | ~5 | `bribe_officials` |
| At yarışı bahis | 1–50 | horse race |
| Enerji refill | 50×2/gün | PLAN_06 |

---

## Denge Kuralı

```
yıllık_gem_mint (F2P + IAP) ≈ yıllık_gem_sink × 1.1–1.3
```

IAP olmadan sink > mint → elmas açığı → kasa/VIP erişilemez.

---

## UI Bug

- Bank UI 50 gem gösterir, server **5 gem** — VOL_25

---

## Kabul

- [ ] Gem ledger tablo (canlı)
- [ ] IAP sonrası mint/sink dashboard
- [ ] Bank UI = server fiyat
