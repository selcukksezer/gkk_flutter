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

### Zindan Eğrisi (VOL_05)
- [ ] dng_001 tutorial muafiyeti aktif
- [ ] Bölge 2–4 çarpanları uygulandı
- [ ] dng_030 günlük projeksiyon PLAN bandına ±30%

### Simülasyon (VOL_07)
- [ ] `gold_inflation_pct` ≤ **12%**
- [ ] `item_inflation_pct` ≤ **15%**
- [ ] exploit success **0%**
- [ ] Sonuç JSON arşivlendi

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

## Program Kapanış

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
