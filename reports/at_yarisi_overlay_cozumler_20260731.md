# At Yarışı — Banner / Sıralama Overlay Çözümleri

**Tarih:** 2026-07-31 (rev: screenshot-grounded)  
**Kapsam:** Canlı yarış UI (`HorseRaceLiveView`) — sıralama + üst banner pist/atları kapatıyor.  
**Durum:** ★ Kombo uygulandı (B slim HUD + D peek SIRALAMA + A üst inset + bahis chip) — `horse_race_live_view.dart` / `horse_race_track_painter.dart`.  
**Screenshot:** `~/.cursor/projects/Users-selcuk-Documents-gkk-web-gkk-flutter/assets/image-8dc7ddb7-bc38-4092-9d78-7bdbd2e0f05a.png`  
**Frame doğrulama:** `KRALİYET HİPODROMU` · CANLI · ~%91 · lider Altıntoz — `HorseRaceLiveView` Stack overlay ekranı.

---

## 0. Screenshot — ne örtüyor?

Bu frame (~%91, son düzlük) kod + görüntü eşleşmesi:

| Overlay | Kod (`horse_race_live_view.dart`) | Screenshot’ta örtülen |
|---------|-----------------------------------|------------------------|
| `_BroadcastHud` | `Positioned(top: safe.top+6, left/right)` — CANLI, 1200m, timer, %bar, Lider | Üst ~band: finiş bölgesi + lider at (Altıntoz) HUD altında kayıp |
| `_MyBetLiveStrip` | `Positioned(top: safe.top+118, left:10, right:148)` — BAHİS KUPONU | Sol-üst şerit: sol lane’ler / lider yakını |
| `_LiveStandingsBoard` | `Positioned(top: safe.top+118, right:8, width:132)` — SIRALAMA 6 satır | Sağ dikey şerit (~ekran genişliğinin ~¼–⅓): sağ lane atları tam gizli |
| Close `X` | `Positioned(top: safe.top+6, right:8)` w/h 38 | Sağ-üst kalabalık; HUD sağ kenarı + SIRALAMA üstü ile görsel çakışma / hit-target sıkışması |
| Track + horses | full-bleed `CustomPaint` + sprites | Ortada sadece ~3 at net görünür (Efsane Tay, Fırtına, Şimşek); görünür “pencere” dar |
| Commentary | `Positioned(bottom)` | Bu frame’de ikincil; ana şikayet üst+sağ+sol kartlar |

**Görünür pist penceresi:** Banner altı ↔ sıralama/bahis kartlarının altı arası, yatayda sol kart ile sağ SIRALAMA arası. Kabaca ekranın **yarısından azı** temiz.

**C “sağ rail” notu (moot):** SIRALAMA **zaten sağda**. Ama bu **layout rail değil** — tam genişlik pist üstüne `Positioned` opaque overlay. C’yi “sıralamayı sağa koy” diye okumak **redundant**. C yalnızca şu anlamda ayrı: `Row(track | standings)` ile pist **altına çizilmez**. Aynı görsel sonuç A’nın **sağ inset**’i ile daha ucuz gelir → C öncelik düşürülür.

---

## 1. Mevcut yapı

### Dosyalar

| Rol | Path |
|-----|------|
| Screen shell (live ↔ bet) | `lib/screens/horse_race/horse_race_screen.dart` |
| Canlı yarış Stack + HUD | `lib/screens/horse_race/horse_race_live_view.dart` |
| Pist geometrisi / painter | `lib/screens/horse_race/horse_race_track_painter.dart` |
| Neon panel / glass stil | `lib/screens/horse_race/widgets/horse_race_design.dart` |

### Widget ağacı (live) — screenshot ile birebir

```
HorseRaceLiveView
└─ Stack(fit: expand)
   ├─ CustomPaint(HorseRaceTrackPainter)          // full-bleed
   ├─ LayoutBuilder → _TrackHorseSprite×N         // under overlays
   ├─ Positioned(top: safe+6)      _BroadcastHud  // büyük banner
   ├─ Positioned(top: safe+6, right) close X
   ├─ Positioned(top: safe+118, left)  _MyBetLiveStrip
   ├─ Positioned(top: safe+118, right, w:132) _LiveStandingsBoard
   └─ Positioned(bottom) _CommentaryTicker
```

### Pist geometrisi

`HorseRaceTrackLayout`:

- `trackStartY = 0.90` · `trackEndY = finishLineY = 0.14`
- %91 progress → atlar üst %14 bandına yakın → **HUD + kartlarla çarpışma kaçınılmaz**

---

## 2. Kök neden (screenshot sonrası net)

1. Full-bleed track + opaque Stack chrome → z-order örtüsü.  
2. Sabit `safe.top+118` — banner gerçek yüksekliği ölçülmüyor; 3 satırlı HUD (badge/title + progress + lider) kartlarla üst-orta bandı paylaşıyor.  
3. `trackEndY = 0.14` finişi bilinçli olarak banner altına koyuyor.  
4. SIRALAMA width 132 + 6 satır = sağ lane’ler sürekli kapalı (screenshot’ta en ağır occlusion).  
5. Close X ile sağ-üst HUD/SIRALAMA aynı köşeyi paylaşıyor → clutter.

---

## 3. Çözüm seçenekleri (revize skor)

### A) İnset pist (chrome altı viewport) — hâlâ yapısal #1

Track+atlar sadece ölçülmüş dikdörtgende; finiş HUD’un **altında** biter. Opsiyonel sağ/sol padding = kart ayak izi kadar.

| Pros | Cons |
|------|------|
| Screenshot’taki lider kaybını çözer | TrackLayout Y kalibrasyonu |
| Sağ inset ile SIRALAMA altında at çizilmez | Effort M |

- **Effort:** M · **Skor:** ★★★★★

---

### B) Alt dock sıralama + ince üst banner — bu frame için kritik

Screenshot HUD 3 blok (title/timer + bar + lider) → tek satıra indir. SIRALAMA’yı alta yatay chip / compact liste taşı → sağ lane açılır. Bahis kuponunu HUD chip veya alt-sol.

| Pros | Cons |
|------|------|
| Sağ occlusion (ana şikayet) gider | Alt kalabalık riski |
| Lider satırı zaten SIRALAMA’da → HUD’dan çıkarılabilir | |

- **Effort:** S–M · **Skor:** ★★★★★ (screenshot sonrası yükseltildi)

---

### C) Sağ rail / Column split — **öncelik düşürüldü (moot-ish)**

Görsel olarak sağda zaten var. Asıl değer: overlay → gerçek kolon (pist daralır, altına çizilmez). Aynı etki A sağ-inset veya D/B ile overlay’i küçültüp taşıyınca gelir; **ayrı “sıralamayı sağa koy” işi değil**.

| Pros | Cons |
|------|------|
| Gerçek non-overlap kolon | Portrait’te 6 lane daha sıkışır |
| | Screenshot’a göre “yeni pozisyon” hissi yok |

- **Effort:** M–L · **Skor:** ★★☆☆☆ (yalnız A/B/D yetmezse)

---

### D) Kompakt / açılır sıralama (peek) — sağ şerit için en ucuz kazanç

Full 6’lı board → top-3 pill veya dar strip; tap→expand. Screenshot’taki sağ ~¼ örtüyü büyük ölçüde keser.

| Pros | Cons |
|------|------|
| Bu frame’e direkt ilaç | Full liste tap ister |
| C’ye gerek kalmadan sağ lane açılır | |

- **Effort:** M · **Skor:** ★★★★★

---

### E) Auto-hide HUD — ikincil

| Pros | Cons |
|------|------|
| Max pist | Broadcast + sıralama kaybı (kullanıcı şikayeti bilgiyi de istiyor) |

- **Effort:** S–M · **Skor:** ★★☆☆☆

---

### F) Ghost glass — yetersiz

Alpha düşürmek screenshot’taki opaque kartları “biraz daha az kötü” yapar; lider hâlâ %91’de üstte kayıp kalır.

- **Effort:** S · **Skor:** ★☆☆☆☆

---

## 4. Bu frame için önerilen kombo (tek pick)

### ★ ÖNERİ: **B slim HUD + D peek SIRALAMA + A üst inset** (bahis → HUD chip)

Bu screenshot’a özel sıra:

1. **`_BroadcastHud` slim (~1 satır):** CANLI · saat · %bar; “Lider: …” satırını kaldır (SIRALAMA / peek zaten #1 gösteriyor). Close X HUD satırına hizala, SIRALAMA’dan ayır.  
2. **`_LiveStandingsBoard` → peek (D):** varsayılan top-3 / dar pill sağda veya altta; full liste tap. → sağ lane açılır (**C’ye gerek yok**).  
3. **`_MyBetLiveStrip`:** ayrı kartı kaldır → slim HUD içinde küçük chip (“⭐ Altıntoz · 1. sıra”) veya alt-sol mini.  
4. **`trackEndY` / horse clamp (A, hafif):** finiş ve at Y’si slim HUD altından başlasın → %91’de lider görünür kalsın.

**Neden C değil:** Sıralama zaten sağ overlay; kullanıcı “sağa koy” değil “pist üstünü kapatma” diyor. Peek/alt dock + inset = aynı hedef, daha az layout riski.

**İkinci tercih (daha hızlı, A’sız):** sadece **B + D + bahis chip** — TrackLayout’a dokunmadan çoğu occlusion biter; finiş çizgisi hâlâ biraz sıkışık kalabilir.

**Yapma:** F tek başına · E tek başına · C’yi ilk sprint’e alma.

---

## 5. Karar matrisi (screenshot sonrası)

| Seçenek | Bu frame’e etki | Effort | Not |
|---------|-----------------|--------|-----|
| A İnset | Lider/finiş görünür | M | Üst band şart |
| B Slim + alt/dock | Üst+sağ rahatlar | S–M | HUD şişkinliği screenshot’ta net |
| C Sağ rail | Düşük ek değer | M–L | Zaten sağda; overlay→kolon farkı |
| D Peek | Sağ lane açılır | M | En doğrudan sağ fix |
| E Auto-hide | Pist açılır, info kayıp | S–M | İkincil |
| F Ghost | Zayıf | S | Yetersiz |

---

## 6. Notlar

- Betting UI / result overlay dışı; sadece live Stack.  
- Parallel season-quest / store-release audit’e dokunulmadı.  
- Implementasyon: kullanıcı bu kombo’yu onaylasın → sonra kod.
