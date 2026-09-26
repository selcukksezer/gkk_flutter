# PLAN 14 — Cilt 8: 365 Günlük Sezon Sıfırlama Sistemi

> **Öncelik:** P1 — IAP ve Faz 1 denge sonrası  
> **Migration:** `20260722_090000`, `20260722_100000`  
> **Tasarım kaynağı:** PLAN_06 §6.4 – §6.6

---

## 1. Durum

PLAN_06 ana sezon reset tanımlı; **kodda `perform_season_reset` yok**.

Mevcut "sezon" sistemleri:
- **Battle Pass:** 14 gün — yalnızca BPP/VIP sıfırlar
- **Lonca savaşı:** Ayrı sıralama sezonu
- **Ana oyun:** Reset yok → altın birikimi sınırsız

---

## 2. Sıfırlanan ve Korunan

### Sıfırlanan (PLAN_06)

| Veri | Hedef değer |
|------|-------------|
| gold | 1000 (başlangıç) |
| inventory | Sil (kozmetik/badge hariç) |
| level | 1 |
| xp | 0 |
| stat_points | 0 |
| facilities | Sil veya level 0 |
| enhancement | Envanter silindiği için sıfır |
| addiction, tolerance | 0 |
| reputation, pvp_rating | Sıfır/baz |

### Korunan

| Veri | Not |
|------|-----|
| gems | Premium para |
| cosmetics, titles, badges | Kalıcı |
| achievements | Kalıcı |
| season statistics | Arşiv tablosu |
| referral_code | Kalıcı |

---

## 3. Sezon Ödülleri (PLAN_06 §6.5)

| Sıralama | Elmas |
|----------|-------|
| 1 | 10.000 |
| 2–10 | 5.000 |
| 11–50 | 2.500 |
| 51–100 | 1.000 |
| 101–500 | 500 |
| 501–1000 | 200 |

Top 1000 toplam: ~500.000 elmas dağıtımı — aktif oyuncu sayısına göre tune edilmeli.

---

## 4. Sezon Puanı Formülü

```
season_score = (max_dungeon_cleared × 1000)
             + (total_power × 1)
             + (pvp_rating × 2)
             + (guild_monument_level × 500)
             + (total_gold_earned / 1_000_000)
             + (crafting_count × 10)
```

**Yeni tablo:** `season_leaderboard_archive (season_number, user_id, score, rank, rewards_granted)`

---

## 5. RPC Tasarımı

### 5.1 `calculate_season_rankings(p_season_number)`

- Tüm kullanıcılar için season_score hesapla
- Sıralama oluştur
- `season_leaderboard_archive` doldur

### 5.2 `distribute_season_rewards(p_season_number)`

- Sıralamaya göre gems ekle
- title/kozmetik ata
- Log: `season_reward_grants`

### 5.3 `perform_season_reset(p_season_number)`

Sıra:
1. `calculate_season_rankings`
2. `distribute_season_rewards`
3. gold → 1000
4. inventory delete (filter)
5. level/xp/stats reset
6. facilities delete
7. tolerance/reputation/pvp reset
8. **gems dokunulmaz**
9. Yeni sezon kaydı `game_seasons` tablosu

**Cron:** Yılda bir veya manuel LiveOps tetikleme

---

## 6. Ekonomi Etkisi

| Etki | Açıklama |
|------|----------|
| Enflasyon sıfırlama | Her sezon altın stoku reset |
| Elmas değeri artış | Tek kalıcı para birimi |
| Whale avantajı | Elmas + kozmetik kalır — PLAN_06 P2W sınırı |
| Yeni oyuncu | Eşit başlangıç her sezon |
| Enhancement sink | 26.7B–1.14T yeniden oynanır |

---

## 7. Oyuncu İletişimi

Sezon bitiminden 14 gün önce duyuru:
- Sıfırlanacaklar listesi
- Kalıcılar listesi
- Sezon ödül tablosu
- Sıralama ekranı

---

## 8. Test Senaryoları

| # | Test |
|---|------|
| S1 | Reset sonrası gold=1000 tüm kullanıcılar |
| S2 | Badge envanterde kalır |
| S3 | gems değişmez |
| S4 | Top 1 → 10000 gems |
| S5 | Rollback — arşivden restore (DR plan) |

---

## 9. Kabul Kriterleri

- [ ] Staging'de tam reset dry-run (QA botları)
- [ ] Ödül dağıtımı doğru
- [ ] Kozmetik koruma filtresi çalışıyor
- [ ] LiveOps runbook yazıldı

---

## 10. Battle Pass ile Koordinasyon

Battle Pass 14 günlük mini-sezon — ana 365 günlük resetten bağımsız kalır.  
Ana reset gününde BP sezonu da hizalanabilir (opsiyonel).

---

## 11. Genişletme Alt Görevleri

- 8.1 game_seasons schema
- 8.2 season_score materialized view
- 8.3 Reset transaction (atomic)
- 8.4 Oyuncu profil arşiv UI
- 8.5 Sezon 1 → 2 geçiş canlı operasyon runbook
