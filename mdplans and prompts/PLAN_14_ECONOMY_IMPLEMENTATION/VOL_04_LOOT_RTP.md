# PLAN 14 — Cilt 4: Loot Kutusu Geri Ödeme Oranı (RTP)

> **Öncelik:** P0  
> **Migration:** `20260722_040000_loot_rtp_prod_tune.sql`  
> **Bağımlılık:** VOL_03 (vendor %35) tamamlandıktan sonra

---

## 1. Arka Plan

Loot ekonomisi eco3 → eco4 → eco4b migration zinciri ile yeniden inşa edildi. Hedef:

- Elmas kutuları: vendor Geri Ödeme Oranı **%48 – %58**
- Altın kutuları: vendor Geri Ödeme Oranı **%38 – %45**
- Referans: 600 altın = 1 elmas (yalnızca math anchor; exchange disabled)

**Kritik fonksiyonlar:**
- `qa_loot_box_ev(p_box_id)` — beklenen değer hesabı
- `open_loot_box(p_box_id)` — canlı açılış (soft pity dahil)

---

## 2. Üretim Doğrulama Prosedürü

### Adım 1 — Tam RTP tablosu

APPENDIX_B Script 1 çalıştır. Çıktıyı `reports/plan14_loot_rtp_audit.csv` kaydet.

### Adım 2 — Hedef dışı kutular

APPENDIX_B Script 2 — her satır için düzeltme task aç.

### Adım 3 — Sıfır vendor fiyatlı eşyalar

APPENDIX_B Script 3 — pool'dan çıkar veya vendor fiyat ata.

### Adım 4 — Tema bazında özet

APPENDIX_B Script 4 — prestige, weapon, craft vb. ortalama RTP.

---

## 3. Düzeltme Stratejileri (Öncelik Sırası)

| Strateji | Ne zaman | Etki |
|----------|----------|------|
| A. vendor_sell_price seed düzelt | Sıfır/düşük fiyat | RTP yükselir |
| B. eco4b weight tune | Tema RTP sapması | İnce ayar |
| C. price adjustment | RTP çok yüksek | Fiyat artır |
| D. reward_multiplier | Miktar boost | Dikkatli — RTP artırır |
| E. Pool item değiştir | Prestige chase | Envanter etkisi |

**Prestige kutuları:** Tarihsel %4300+ RTP — weight cap ≤0.12 ve fiyat 100/200/300 elmas korunmalı.

---

## 4. Aktif Kasa Envanteri (Referans)

36 aktif kutu:

**Elmas (box_01–24):** 8 tema × 3 kademe  
- Normal: 50 / 100 / 200 elmas  
- Prestige: 100 / 200 / 300 elmas  
- multiplier: 1.12 / 1.08 / 1.04  

**Altın (box_26–37):** 4 tema × 3 kademe  
- 80.000 / 140.000 / 200.000 altın  
- multiplier: 1.0  

---

## 5. Migration Tune İskeleti

```sql
-- 20260722_040000_loot_rtp_prod_tune.sql
-- SADECE prod audit sonrası doldurulacak — şablon:

BEGIN;

-- Örnek: craft gold box RTP düşükse weight artır
UPDATE public.loot_box_drop_entries e
SET weight = weight * 1.15
FROM public.loot_box_configs b
WHERE e.box_id = b.id
  AND b.theme_id = 'craft'
  AND b.currency_type = 'gold'
  AND (public.qa_loot_box_ev(b.id)->>'vendor_rtp_pct')::numeric < 38;

-- Örnek: vendor_sell_price = 0 itemları pool'dan kaldır
DELETE FROM public.loot_box_drop_entries e
USING public.items i
WHERE e.item_id = i.id
  AND COALESCE(i.vendor_sell_price, 0) = 0;

COMMIT;
```

**Kural:** Her UPDATE öncesi `qa_loot_box_ev` before/after kaydet.

---

## 6. Soft Pity ve QA Farkı

Canlı `open_loot_box`:
- 8 ardışık common/uncommon → rare+ zorla
- Miktar: `FLOOR(random() × range + min) × multiplier`

`qa_loot_box_ev`:
- Ortalama miktar kullanır
- Pity yok

**Öneri:** `qa_loot_box_ev_with_pity` fonksiyonu ekle (Monte Carlo 10.000 iterasyon) — APPENDIX_B Script 6.

---

## 7. Flutter — Loot Şeffaflığı (VOL_11 ile overlap)

| Dosya | Değişiklik |
|-------|------------|
| `lib/screens/loot/loot_hub_screen.dart` | Drop preview varsayılan açık |
| `lib/screens/loot/loot_chest_widgets.dart` | Çarpan chip kesilmesin — Wrap |
| Route bug | `currentRoute: AppRoutes.loot` (shop değil) |

---

## 8. Regülasyon ve Mağaza Uyumu

- Apple/Google loot box şeffaflık gereksinimleri
- Drop odds görünür olmalı
- "Göster" gizli preview kaldırılmalı
- RTP/yüzde dağılımı ekranda (`get_loot_box_drops` RPC)

---

## 9. Test Matrisi (Özet)

| ID | Test | Kriter |
|----|------|--------|
| L1 | 36 kutu RTP band | Script 2 = 0 row |
| L2 | Prestige RTP | 48–58% elmas |
| L3 | Gold starter RTP | 38–45% |
| L4 | open 1000× box_01 | Ortalama vendor değer ≈ qa_loot_box_ev ±10% |
| L5 | Pity 8 common | 9. açılış rare+ |
| L6 | vendor %35 sonrası | Satış değeri RTP ile uyumlu |

---

## 10. Kabul Kriterleri

- [ ] Prod/staging Script 2 sıfır hedef dışı kutu
- [ ] Sıfır vendor item pool'da yok
- [ ] Audit CSV arşivlendi
- [ ] UI odds görünür (VOL_11)

---

## 11. Alt Görev Kataloğu (Genişletme)

Her kutu teması için ayrı belge (8 elmas + 4 altın = 12 belge × ~25 sayfa):

- `tasks/VOL_04_weapon_gem_tier1.md`
- `tasks/VOL_04_prestige_gem_tier3.md`
- ...

Her belge: mevcut pool SQL, weight tablosu, hedef RTP, tune adımları, before/after CSV.
