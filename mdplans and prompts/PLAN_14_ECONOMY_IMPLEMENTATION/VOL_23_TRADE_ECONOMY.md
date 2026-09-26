# PLAN 14 — Cilt 23: Oyuncu Ticareti (Trade) Ekonomisi

> **Öncelik:** P1 — P0 fraud algısı (audit)  
> **RPC:** `trade_sessions`, confirm flow

---

## 1. Ekonomi Modeli

- P2P gold transfer — **net-zero** (A −X, B +X)
- Market fee **yok** — wash trade riski
- Escrow: accept sonrası gold/inventory lock

---

## 2. Audit Bulguları

- Karşı teklif senkronu yok — dolandırılma algısı (P0 UX, ekonomi değil)
- Realtime sync spec gerekli

---

## 3. Anti-Abuse

| Kontrol | Öneri |
|---------|-------|
| Wash trade | A↔B repeated flag |
| Gold transfer cap | max 50M/trade |
| Rate limit | trade confirm 10/saat |
| Captcha | VOL_34 |

---

## 4. Opsiyonel Sink

Trade tax %1 gold destroy — PLAN_06 market %5 ile tutarlılık tartışması

---

## Kabul

- [ ] Trade sync spec (Flutter + Realtime)
- [ ] Wash detect log
- [ ] Rate limit on trade RPC
