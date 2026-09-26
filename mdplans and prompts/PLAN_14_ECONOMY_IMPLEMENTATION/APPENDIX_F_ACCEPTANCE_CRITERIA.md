# PLAN 14 — Ek F: Kabul Kriterleri Özeti

---

## Faz 0 — Hazırlık

- [ ] PLAN_12 full backup alındı ve restore test edildi
- [ ] `plan14_baseline_*.json` arşivlendi
- [ ] Roller ve onay kapıları atandı (VOL_01)

---

## Faz 1 — Musluk Düzeltmeleri

### Vendor Satış (VOL_03)
- [ ] RPC %35 uygulandı
- [ ] Envanter UI doğru preview
- [ ] Unit test V-01–V-04 geçti

### Loot RTP (VOL_04)
- [ ] Script 2: 0 hedef dışı kutu
- [ ] Script 3: 0 sıfır vendor item
- [ ] Audit CSV arşivlendi

### Zindan Eğrisi (VOL_05 + VOL_05B)
- [ ] dng_001 tutorial muafiyeti aktif
- [ ] Bölge 2–4 çarpanları uygulandı
- [ ] **Bölge 5–7 çarpanları uygulandı**
- [ ] dng_030 / dng_065 projeksiyon PLAN bandına ±30%

### Crafting (VOL_15) — KRİTİK
- [ ] `craft_item_async` gold deduct staging
- [ ] CR-01–CR-04 testler geçti

### Sink Sim (VOL_13, 14, 17)
- [ ] Tam sim side insert ON
- [ ] enhancement gold_out > 0
- [ ] craft gold_out > 0
- [ ] facility gold_out > 0

### Simülasyon (VOL_07 + VOL_13)
- [ ] **Tam sim** `gold_inflation_pct` ≤ **12%**
- [ ] `item_inflation_pct` ≤ **15%**
- [ ] exploit success **0%**
- [ ] Segment economy JSON arşivlendi

---

## Faz 2 — Monetizasyon

### IAP (VOL_06)
- [ ] 4 paket sandbox iOS + Android
- [ ] Çift receipt reddediliyor
- [ ] iap_transactions log doluyor
- [ ] Production canary 48 saat stabil

---

## Faz 3 — Orta Vadeli

### Sezon Reset (VOL_08)
- [ ] Staging dry-run başarılı
- [ ] Ödül dağıtımı doğru
- [ ] Kozmetik korunuyor

### Pazar (VOL_09)
- [ ] Fiyat band enforce
- [ ] 7 gün expiry cron

### Referral (VOL_10)
- [ ] Aylık cap aktif

### UI (VOL_11)
- [ ] CurrencyFormat tüm ekranlar
- [ ] Loot odds görünür
- [ ] Nav highlight düzeltildi

---

## Faz 4 — Canlı Operasyon

### Monitoring (VOL_12)
- [ ] Dashboard canlı
- [ ] Haftalık rapor şablonu
- [ ] Runbook paylaşıldı

---

## Registry & Cross-System

- [ ] VOL_19 gold sink registry doğrulandı
- [ ] VOL_20 gold faucet registry doğrulandı
- [ ] VOL_21 gem ledger canlı
- [ ] VOL_25 cross-system 5 sim PASS
- [ ] APPENDIX_G tüm satırlar ✓ veya bilinçli gap

## Program Kapanış

- [ ] **APPENDIX_H tüm maddeler (A–H)**
- [ ] MASTER_GAMEPLAN kanonik değerler güncellendi
- [ ] PLAN_06 impl notları eklendi
- [ ] Tüm migration APPENDIX_A'da işaretlendi
- [ ] Post-mortem raporu yazıldı

---

## Başarı Metrikleri (Canlı — 30 Gün Sonra)

| Metrik | Hedef |
|--------|-------|
| Gold enflasyon (canlı hesap) | < 15% aylık |
| IAP conversion (shop visit → buy) | > 2% (hedef) |
| Loot şikayet ticket | < 5/hafta |
| Ekonomi exploit ticket | 0 |
| D30 retention | ≥ 25% (overall) |

---

## İmza Bloğu (Onay)

| Rol | İsim | Tarih | İmza |
|-----|------|-------|------|
| Ekonomi tasarımcısı | | | |
| Backend lideri | | | |
| QA lideri | | | |
| Canlı operasyon | | | |
