# PLAN 14 — Cilt 1: Yönetişim ve Proje Çerçevesi

> **Öncelik:** P0 — Tüm fazlar öncesi okunmalı  
> **Sahip:** Proje lideri + Ekonomi tasarımcısı

---

## 1. Amaç

Bu cilt, PLAN_14 ekonomi düzeltme programının nasıl yönetileceğini, kimlerin neyi onaylayacağını, hangi ortamlarda neyin uygulanacağını ve risklerin nasıl kaydedileceğini tanımlar. Ekonomi değişiklikleri geri alınamaz oyuncu etkisi yaratabilir; bu nedenle disiplinli yönetişim zorunludur.

---

## 2. Kapsam Sınırları

### 2.1 Bu plan kapsamında

- Altın musluk ve sink dengesi
- Elmas musluk ve sink dengesi
- Vendor satış oranı düzeltmesi
- Loot kutusu Geri Ödeme Oranı doğrulama ve ayar
- Zindan altın eğrisi (Bölge 1–4, genişletilebilir)
- Uygulama içi satın alma entegrasyonu
- 365 günlük sezon sıfırlama sistemi (PLAN_06 §6.4)
- Simülasyon kapıları ve canlı metrikler
- Ekonomi arayüzü güven ve şeffaflık düzeltmeleri

### 2.2 Bu plan kapsam dışında

- Lonca savaşı sezon mantığı (ayrı modül)
- Battle Pass 14 günlük rotasyon (mevcut, dokunulmaz)
- Mekan sistemi gelirleri (PLAN_07 — ayrı faz)
- Yeni oyun içeriği (zindan, eşya) tasarımı — yalnızca mevcut seed tune

---

## 3. Roller ve Yetkiler

| Rol | Yetki | Sorumluluk |
|-----|-------|------------|
| **Ekonomi tasarımcısı** | RTP, zindan band, paket fiyat onayı | Hedef değerleri tanımlar |
| **Backend lideri** | Migration merge onayı | SQL güvenliği, trigger uyumu |
| **Flutter lideri** | İstemci PR onayı | IAP, UI, RPC çağrıları |
| **Kalite güvencesi lideri** | Sim kapısı geçiş/red | Test matrisi yürütme |
| **Canlı operasyon** | Production deploy onayı | Yedek, canary, rollback |
| **Güvenlik** | IAP ve referral değişiklik onayı | Anti-fraud inceleme |

**Kural:** Production migration için en az **2 onay** gerekir (Backend + Ekonomi veya Canlı operasyon).

---

## 4. Ortam Stratejisi

| Ortam | Amaç | `app.qa_mode` | Veri |
|-------|------|---------------|------|
| Local | Geliştirici test | true | Seed |
| Staging | Sim + entegrasyon | true | Anonim kopya |
| Production canary | %5–10 kullanıcı | false | Canlı |

**Kural:** Ekonomi migration staging'de sim kapısı geçmeden production'a gitmez.

---

## 5. Değişiklik Sınıflandırması

| Sınıf | Örnek | Onay | Geri alma |
|-------|-------|------|-----------|
| **S1 Kritik** | Vendor %35, IAP grant | 2 kişi + yedek | Migration rollback |
| **S2 Yüksek** | Zindan gold çarpanı | Ekonomi + Backend | Migration rollback |
| **S3 Orta** | UI format fix | Flutter lider | Hotfix |
| **S4 Düşük** | Metin/lokalizasyon | Tek reviewer | Hotfix |

---

## 6. Risk Kaydı Şablonu

Her S1/S2 değişiklik için `risks/PLAN14_RISK_XXX.md`:

```markdown
## Risk ID: PLAN14-R-001
- **Açıklama:** Vendor %35 geçişinde mevcut envanter değeri düşer
- **Olasılık:** Kesin (tasarım)
- **Etki:** Oyuncu şikayeti, negatif yorum
- **Azaltma:** Önceden duyuru, geçiş bonusu (opsiyonel)
- **Sahip:** Canlı operasyon
- **Durum:** Açık / Kapalı
```

---

## 7. İletişim Planı

| Olay | Kanal | Süre |
|------|-------|------|
| Staging sim FAIL | Anında — backend + QA | Aynı gün düzeltme |
| Production deploy | Duyuru taslağı hazır | Deploy öncesi 24 saat |
| Rollback | Acil — tüm ekip | 1 saat içinde karar |

**Oyuncu duyurusu (vendor %35):**  
"Satıcı satış değerleri oyun ekonomisi dengesi için güncellendi. Eşya değerleri kasa ve zindan ödülleriyle uyumlu hale getirildi."

---

## 8. Versiyon ve Dal Yönetimi

- Feature branch: `cursor/plan14-economy-a382`
- Migration prefix: `20260722_*`
- Flutter değişiklikleri aynı branch veya alt branch (`cursor/plan14-iap-a382`)
- Her cilt tamamlandığında ayrı commit (Conventional Commits)

---

## 9. Dokümantasyon Güncelleme Yükümlülüğü

Her migration merge sonrası:

1. `APPENDIX_A_MIGRATION_REGISTRY.md` güncelle
2. `PLAN_06_ECONOMY_BALANCE.md` impl notu ekle (uygulanan değerler)
3. `MASTER_GAMEPLAN.md` kanonik değerler bölümüne vendor %35 ekle

---

## 10. Çıkış Kriterleri (Cilt 1)

- [ ] Roller atandı
- [ ] Risk kaydı açıldı (en az 5 madde)
- [ ] Staging ortamı hazır
- [ ] PLAN_12 yedek prosedürü okundu ve test edildi
