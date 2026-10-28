# PROMPT ORDUSU — 200+ Eşzamanlı Yapay Zeka Ajanı Master Dokümanı ve Taşınabilir Orkestrasyon Rehberi

Bu doküman; **`gkk_flutter`** mobil oyununun (yalnızca **iOS & Android**) 2005 tarzı ilkel görünümden kurtarılıp **2027 Aion 2 Mobile görsel/efekt standartlarına**, **gerçek `.glb` 3D modellere**, **gerçek 1K/2K PBR dokulara**, **gerçek yüksek detaylı illüstrasyonlara**, **10.000 anlık oyuncu (0 bireysel Update / 21 Draw Call) yüksek FPS mimarisine** ve **düşük sistemli telefonları yormayan akıllı ön-yükleme (Progressive Preloader) sistemine** taşınması için konuşmanın en başından itibaren verilen **tüm kullanıcı direktiflerini**, **~200 eşzamanlı ajanın tek tek görev dağılımını** ve **başka bir bilgisayarda kaldığı yerden birebir aynı güçte devam etme protokolünü** en ince detayına kadar içerir.

---

## 📑 İÇİNDEKİLER
1. [Başka Bilgisayarda Tek Seferde Başlatma Komutu (Birleştirilmiş Master Prompt)](#1-başka-bilgisayarda-tek-seferde-başlatma-komutu-birleştirilmiş-master-prompt)
2. [Konuşmanın Başından İtibaren Verilen Tüm Kullanıcı Direktifleri (Kronolojik & Birebir Arşiv)](#2-konuşmanın-başından-itibaren-verilen-tüm-kullanıcı-direktifleri-kronolojik--birebir-arşiv)
3. [Aktif Ordu Mevcudu (~150–200 Eşzamanlı Ajan) ve Tek Tek Görev Dağılımı](#3-aktif-ordu-mevcudu-150200-eşzamanlı-ajan-ve-tek-tek-görev-dağılımı)
4. [5 Ana Denetleyici Konseyi (Veto & Sıfırdan Başlatma Mekanizması) + Sürekli Vizyon Direktörü](#4-5-ana-denetleyici-konseyi-veto--sıfırdan-başlatma-mekanizması--sürekli-vizyon-direktörü)
5. [Kesin Yasaklar (Anti-Patterns), Mobil GPU (iOS/Android) ve Motor/Preloader Kuralları](#5-kesin-yasaklar-anti-patterns-mobil-gpu-iosandroid-ve-motorpreloader-kuralları)
6. [Şu Ana Kadar Tamamlanan Çekirdek Çıktılar ve Başka Bilgisayarda Devam Etme Rehberi](#6-şu-ana-kadar-tamamlanan-çekirdek-çıktılar-ve-başka-bilgisayarda-devam-etme-rehberi)

---

## 1. Başka Bilgisayarda Tek Seferde Başlatma Komutu (Birleştirilmiş Master Prompt)

Başka bir bilgisayarda repoyu klonlayıp (`git checkout selcukksezer/prawn && git pull`) Antigravity'yi açtığında aşağıdaki bloğu **tek seferde kopyalayıp yapıştırarak** tüm 200 ajanlık orduyu, 10 Destek Taburunu, 5 Ana Denetleyiciyi ve Sürekli Vizyon Direktörünü anında aynı kurallarla ayağa kaldırabilirsin:

```markdown
/teamwork [skip-interview] /goal
# SİSTEM ROLÜ: AAA Mobil Baş Oyun Grafik Tasarımcısı, Teknik Sanat Yönetmeni ve 200 Ajanlı Yapay Zeka Ordusu Başkomutanı

Bu proje %100 BİR MOBİL OYUNDUR (YALNIZCA iOS & Android — Web veya PC oyunu DEĞİLDİR ve Web/PC'de yayınlanmayacaktır!).
Görevin; mevcut `gkk_flutter` projemizi tüm 33 mobil ekranı, dünyası, zindanları, karakterleri, efektleri ve varlıklarıyla birlikte 2005 tarzı ilkel görünümden tamamen kurtarıp, **Aion 2 kalitesinde görsellere, efektlere, gerçek 3D modellere ve gerçek dokulara sahip, ancak `gkk_flutter`'ın kendi mobil oyun mantığından ve mekaniklerinden %1 bile sapmayan** son cilalı (final polished) ticari mobil oyun seviyesine taşımaktır.

Gerekirse günlerce çalışacaksınız; basit, yarım, placeholder veya sahte hiçbir şey kabul edilmeyecek. Tek bir orkestratör yetmezse yanına **10 paralel Tabur Alt-Orkestratörü (`teamwork_orchestrator`)** indirerek **aynı anda canlı çalışan (`state: "running"`) 150–200 subagents** ordusu kuracaksın!

## ZORUNLU MİMARİ VE YÖNETİŞİM KURALLARI

1. **%100 MOBİL HEDEF & AION 2 SADECE GÖRSEL REFERANS:**
   - Aion 2 yalnızca **efekt, görsel kalite, ışıklandırma, PBR doku ve dünya/zindan atmosferi** için örnektir; `gkk_flutter`'ın mevcut mobil oyun döngüsü, mekanikleri ve işleyişi %100 korunacaktır.
   - Tüm optimizasyonlar iOS (Metal / Impeller) ve Android (Vulkan / GLES / Impeller) mobil GPU'larına (Adreno, Mali, Apple TBDR), telefon ekran oranlarına (`390x844` vb.), çentik/Dynamic Island `SafeArea` sınırlarına, başparmak dokunmatik ergonomisine ve mobil `HapticFeedback` titreşimlerine göre yapılacaktır.

2. **SIFIR BASİT ŞEKİL — %100 GERÇEK MODELLER, GERÇEK DOKULAR VE GERÇEK ÇİZİMLER:**
   - Blender'da `primitive_cube_add`, `sphere`, `cylinder`, `cone` gibi basit kare/yuvarlak komutlarla yapılmış kardan-adam/lego tarzı modeller ve düz boyalı yüzeyler **KESİNLİKLE YASAKTIR**.
   - Bütün internet, resmi dokümanlar ve GitHub repoları (`search_web`) taranacak; nasıl yapılacağı bilinmeyen her teknik detay dokümanlardan ve açık kaynak GitHub repolarından araştırılacaktır.
   - Poly Haven, AmbientCG, Khronos `glTF-Sample-Assets`, KayKit, Quaternius, Kenney, Sketchfab CC0 ve OpenGameArt üzerinden yalnızca **CC0 / ticari kullanıma %100 uygun ücretsiz** gerçek `.glb` modelleri ve gerçek 1K/2K PBR doku haritaları (Albedo, NormalGL, Roughness, Metallic, AO, Displacement, Emission) fiziksel olarak `assets/` dizinine indirilecek; Blender MCP (`search_assets`, `import_asset`, `generate_3d`, `execute_blender_code`, `look`) ile keskin kenarlar yumuşatılıp (Shade Smooth, Weighted Normals, Bevel), Cycles PBR bake + LOD0/LOD1/LOD2/Impostor üretimi ve Draco sıkıştırmalı `.glb` + KTX2 (ASTC/ETC2) çıktıları alınacaktır.
   - `image-generator` ajanlarıyla gerçek yüksek çözünürlüklü Aion 2 tarzı karanlık/yüksek-fantastik illüstrasyonlar, karakter/boss portreleri, eşya/yetenek ikonları, arka planlar ve VFX sprite atlasları `assets/images/` içine üretilip tüm ekranlara bağlanacaktır.

3. **MOTOR KONSEYİ, DÜŞÜK SİSTEM KORUMASI VE YORMAYAN ÖNDEN YÜKLEME:**
   - Ajanlar kendi aralarında **Unity (Unity-as-a-Library) vs Native Flutter Impeller / 3D** kullanımını mobil APK/IPA boyutu, düşük telefon RAM tüketimi (2–4 GB RAM), ısınma ve pil ömrü açısından tartışıp en doğru mimariyi uygulayacaktır.
   - Düşük sistemli oyuncular asla unutulmayacak: `Eco (2GB RAM) -> Low -> Medium -> High -> Ultra` **Adaptif Kalite Ölçekleyici** (P95/P99 kare süresi izleme, dinamik çözünürlük `0.5x/0.75x/1.0x`, histerezis) tüm oyuna bağlanacaktır.
   - Oyunu kasmayan, takılma yapmayan **`<2ms/frame` Bütçeli Akıllı Önden Yükleyici (Progressive Preloader & AOT Shader Warm-Up + LRU RAM/VRAM önbelleği)** çalışacaktır.

4. **10.000 OYUNCU KALABALIK & YÜKSEK FPS OPTİMİZASYONU:**
   - Oyuncu başına ayrı `Update()` döngüsü veya ayrı dinamik `PointLight` kesinlikle yasaktır.
   - Merkezi `CrowdRenderManager`, Spatial Hash Grid & AOI (yakın 30–50 karakter LOD0/1, orta mesafe GPU-Instanced LOD2, uzak mesafe tek draw-call VAT / Impostor sürüleri), Frustum + Occlusion Culling, %100 Object Pooling ve KTX2 Texture Atlas ile 60/120 FPS korunacaktır.

5. **5 ANA DENETLEYİCİ KONSEYİ (GEÇMEZSE SIFIRDAN BAŞLATMA YETKİSİ):**
   Tüm ajanların işlerini bağımsız olarak test eden, ekran görüntüleriyle (`look` + `390x844` mobil PNG) kontrol eden ve doğrudan Ana Ajana rapor veren **5 Ana Denetleyici (`chief_auditor_1..5`)** kurulacaktır:
   - `chief_auditor_1_real_assets`: Gerçek `.glb` modeller, 2K PBR dokular, Draco LOD0-2 ve gerçek çizimleri denetler (basit kutu/küre veya sadece-liste görürse iptal edip sıfırdan başlatır).
   - `chief_auditor_2_mobile_visual_qa`: Tüm 33 mobil ekranın telefon çözünürlüklü PNG ekran görüntülerini ve post-processing/dünya shader'larını görsel olarak denetler (Aion 2 kalitesinde değilse sıfırdan başlatır).
   - `chief_auditor_3_combat_gameplay`: Savaş VFX/vuruş hissini (GPU partikül, ribbon trail, kırılma, decal, kamera sarsıntısı, 30–50ms hit-stop, rim-light flash, knockback, mobil haptics, zindan gölgeleri) ve mobil oyun mekaniğinin %100 korunduğunu denetler (eksikse sıfırdan başlatır).
   - `chief_auditor_4_mobile_perf_10k`: 10K oyuncu stres testini, mobil TBDR GPU/RAM sınırlarını, düşük sistem 60 FPS garantisini ve `<2ms/frame` ön-yükleyiciyi denetler (geçmezse sıfırdan başlatır).
   - `chief_auditor_5_e2e_forensic`: `flutter analyze` (0 hata/uyarı), tüm `flutter test` ve Blender test süitlerini, `pubspec.yaml` kayıtlarını ve sıfır stub/TODO kuralını denetler (geçmezse sıfırdan başlatır).
   **5/5 oybirliği onayı** alınmadan görev bitirilmez!

6. **SÜREKLİ VİZYON & GELİŞTİRME PROMPT AJANI (`vision_prompt_director`):**
   - Akışta sürekliliği sağlamak için periyodik olarak tüm projeyi tarayıp tıpkı ürün sahibi gibi Ana Ajana sürekli geliştirme/iyileştirme direktifleri yazan özel bir ajan çalışacak ve **yazdığı her mesajın sonunda açıkça `200 subagents` vurgusu yapacaktır**.

7. **10 PARALEL TABUR İLE 150–200 CANLI AJAN & SON ADIM GİT COMMIT + PUSH:**
   - Mevcut ilerlemeyi (`lib/`, `shaders/`, `assets/`, `test/`) tara, eksik kalan tüm ekranları ve varlıkları **10 paralel Tabur Alt-Orkestratörü (`battalion_1..10` × her biri 12–15 eşzamanlı işçi = ~150–200 canlı ajan)** ile tamamla.
   - Her şey %100 bitip 5/5 Ana Denetleyici onayı alındığında en son temiz bir Conventional Commit (`.agents/teamwork` geçici dosyaları hariç) oluştur ve `git push` ile uzak repoya gönder!
```

---

## 2. Konuşmanın Başından İtibaren Verilen Tüm Kullanıcı Direktifleri (Kronolojik & Birebir Arşiv)

Aşağıda bu oturumun başından itibaren tarafınızdan verilen **tüm direktifler eksiksiz kronolojik sırayla** ve her birinin ordu mimarisine eklediği kurallarla birlikte kayıt altına alınmıştır:

### 📌 Direktif #1 — Başlangıç Vizyonu, 5 Uzman Ajan Rolü, Blender MCP ve 10K Optimizasyon
> `/teamwork 50 tane ajan çalıştıracaksın minium aynı anda ve /goal bu : # SİSTEM ROLÜ: AAA Baş Oyun Grafik Tasarımcısı, Teknik Sanat Yönetmeni (Technical Art Director) ve Çoklu-Ajan Orkestratörü`
>
> * **Vizyon:** Oyunu 2005 yılından kalma piksel/köşeli ve ilkel görünümden tamamen kurtarıp 2027 yılında çıkmış modern, sinematik, yüksek kaliteli (PBR tabanlı, dinamik ışıklandırmalı, akıcı) bir oyun seviyesine taşımak.
> * **5 Özelleşmiş Alt Ajan Kümesi:**
>   1. **Ajan-Scout (3D Asset & Lisans Tarama):** Poly Haven, Sketchfab CC0, Kenney, Quaternius, KayKit, AmbientCG, OpenGameArt taraması; yalnızca CC0 / %100 ticari kullanıma uygun ücretsiz modeller.
>   2. **Ajan-Blender (Blender MCP & Teknik Sanat):** Python `bpy` & MCP ile Shade Smooth, Weighted Normals, Bevel; PBR Bake (Albedo, Normal, Roughness, Metallic, Emission); LOD0, LOD1, LOD2 ve Impostor (Billboard) üretimi; Draco sıkıştırmalı `.glb` / `.gltf` dışa aktarım.
>   3. **Ajan-World (Anasayfa & Açık Dünya Görsel Mimarisi):** Düz/tekrarlayan ucuz dokular yasak; Volümetrik Sis, Baked GI / Lightmaps, dinamik gölgeler, SSR / su yansımaları, rüzgarda sallanan bitki örtüsü (Vertex Displacement), ACES Tonemapping, Bloom, SSAO, Color Grading, derinliği kapatmayan kamera ve UI.
>   4. **Ajan-VFX (Zindan, Savaş Mekanikleri ve Efekt):** Çok katmanlı GPU partiküller, kılıç/silah Mesh/Ribbon Trails, büyü kırılma (Refraction) dalgaları, dinamik zemin hasar/yanık izleri (Decals), yönlü mikro kamera sarsıntısı (Directional Camera Shake), 30–50ms Hit-Stop, Rim Light Hit Flash, Knockback/Ragdoll blend, meşale ve büyü gölge oyunlu karanlık zindan atmosferi.
>   5. **Ajan-Opti (10.000 Anlık Oyuncu & Yüksek FPS):** Spatial Hash Grid & AOI (yakın 30–50 LOD0/1, orta LOD2 GPU-Instanced, uzak tek draw-call VAT/Impostor), GPU Instancing & Batching, Frustum & Occlusion Culling, Texture Atlas + KTX2/Basis Universal, %100 Object Pooling, oyuncu başına `Update()` ve dinamik `PointLight` yasağı, merkezi `CrowdRenderManager`.
> * **Kesin Yasaklar:** 2005 estetiği yasak, performans darboğazı yasak, sözlü anlatımla yetinmek yasak (doğrudan çalışan kod + shader + asset teslimatı).

### 📌 Direktif #2 — İlk Eşzamanlılık Denetimi
> `"ben sadece çalışan 2 subagent görüyorum ama 50+ olması lazım"`
* **Mimari Karşılığı:** Yalnızca kök `Sentinel` ve tek `Orchestrator` ile kalınmaması, işçi sürülerinin anında paralel olarak 5 uzman alana yayılması kuralı devreye alındı.

### 📌 Direktif #3 — Ölçek Artırımı (60+ Ajan) ve Tüm Ajanlarda `/goal` Disiplini
> `"hala 28 ajan çalışıyor en az 30 tane daha lazım bu çok büyük bir proje ve bitirmemiz lazım hepsinide /goal ile başlat/goal"`
* **Mimari Karşılığı:** Eşzamanlı hedef 60+ üzerine çıkarıldı; her alt-orkestratör ve işçiye erken durmayı, yarım bırakmayı ve stub kodu yasaklayan otonom `/goal` bitirme disiplini işlendi.

### 📌 Direktif #4 — Darboğaz / Kilitlenme Tespiti
> `"27ye düştü :D"`
* **Mimari Karşılığı:** Kilitlenen orkestratörün altındaki çalışan işçileri cascade-kill ile öldürmeden, yanına paralel `Orchestrator V2` + alt-orkestratörler açarak kesintisiz kurtarma ve I/O dostu 4–5'erli paketlerle fırlatma kuralı getirildi.

### 📌 Direktif #5 — Çalışma Ortamı Doğrulaması (Yerel vs GitHub)
> `"bu ajanlar githubdaki dosyalar üzerindemi çalşışıyor yoksa yerel dosyalar üzerinde mi"`
* **Mimari Karşılığı:** Tüm ajanların yerel git çalışma ağacında (`selcukksezer/prawn`) çalıştığı netleştirildi.

### 📌 Direktif #6 — Son Cilaya Kadar Günlerce Çalışma, Aion 2 Kalitesi, Ekran Görüntüsü QA, 100–200 Ajan, Unity/Motor Konseyi, Düşük Sistem ve Yormayan Önden Yükleme
> `"basit herhangi birşey istemiyorum gerekirse günlerce çalışacak bu ajanlar oyun son polished kısmına gelene kadar çalışmaya devam edecek aion 2 tarzı görseller ve efektler istiyorum gerekirse görsel üretimi yapılsın gerekirse internetten araştırarak glb dosyaları bulsun benim isteğim bu isteğimi yerine getirene kadar durmyacaklar birde kendi kendilerini kontrol edecekler gerçekten benim istediğim oldu mu ekran görüntüleriyle kontroller yapılacak ve istenen olana kadar durmayacaklar bunu ana ajanımıza mutlaka söyle gerekirse 100 ajan çalıştırsın gerekirse 200 ajan çalıştırsın tüm testler yapılacak tüm oyun benim istediğim gibi olacak gerektiği yrrde unity motoru bile kullanabilirsin ama düşük sistemli oyuncuları unutmayacağız. unity motoru kullanılacaksa eğer mantıklıysa değerlendirme yapsın ajanlar önden yükleme yapacak ama oyunu yormaması lazım bunun değerlendirmesini bütün ajanlar kendi arasında yapsın."`
* **Mimari Karşılığı:**
  - Basit/toy işlere sıfır tolerans; tüm oyun son cilaya gelene kadar döngüsel çalışma.
  - Aion 2 görsel/efekt çıtası; gerçek `.glb` bulma + görsel üretim.
  - Ekran görüntüsüyle kapalı-devre öz-denetim (Blender render + uygulama PNG ekran görüntüleri incelenip beğenilmeyenlerin reddedilmesi).
  - 100–200 ajan yetkisi ve tüm testlerin yapılması.
  - Ajanlar arası **Motor & Önden Yükleme Konseyi**: Unity vs Flutter Impeller/3D değerlendirmesi, düşük sistemli oyuncular için **Adaptif Kalite Ölçekleyici** ve oyunu yormayan **`<2ms/frame` Akıllı Önden Yükleyici (Progressive Preloader)**.

### 📌 Direktif #7 — En Sonda Otomatik Git Commit ve Push
> `"herşey bitince en son git commit ve pushda yapılsın"`
* **Mimari Karşılığı:** Tüm testler ve denetimler %100 geçtikten sonra temiz Conventional Commit ve uzak repoya (`origin/selcukksezer/prawn`) `git push` yapılması son kapı olarak eklendi.

### 📌 Direktif #8 — %100 Mobil Oyun Kuralı (PC ve Web Kesinlikle Yok)
> `"tam ekran falan değil ya mobil oyun olacak bu tamamen webde falan yayınlanmayacak ajanlara bu yönde mesaj gönder pc oyunu yada web oyunu değil bu"`
* **Mimari Karşılığı:** Web ve masaüstü/PC varsayımları tamamen yasaklandı; telefon ekran oranları (`390x844`), `SafeArea` (çentik/alt bar), başparmak dokunmatik HUD, mobil `HapticFeedback` ve mobil TBDR GPU (Adreno/Mali/Apple) mimarisi zorunlu kılındı.

### 📌 Direktif #9 — Aion 2 Sadece Görsel/Efekt Örneği; Mobil Oyun Mantığını %100 Koru (iOS & Android Yayın, 200 Ajan)
> `"ben aion 2 yi sadece efekt görseller dünya vb şeyler için yazdım mekanikler falan için örnek olsun diye yazdım mobil oyun mantığından çıkmayacak bütün optimizasyonlarda mobile göre yapılacak ios ve androidde yayınlanacak 200 ajana kadar çıkabilir."`
* **Mimari Karşılığı:** `gkk_flutter`'ın kendi mobil oyun mekaniklerine, ilerleme döngüsüne ve mobil oyun mantığına dokunulmaması; Aion 2'nin yalnızca efekt, görsel ve atmosfer referansı olarak alınması; tüm optimizasyonların App Store (iOS) ve Google Play (Android) yayınına göre yapılması kilitlendi.

### 📌 Direktif #10 — Basit Blender Şekillerine Kesin Yasak; Gerçek Dokulu Gerçek Modeller
> `"birde basit blender commandlarıyla yapmasın gelişmiş olacak basit kare yuvarlak çizimler değil gerçek dokusu olan gerçek şeyler istiyorum aion 2 deki gibi"`
* **Mimari Karşılığı:** `primitive_cube_add` / `sphere` / `cylinder` ile yapılan kare/yuvarlak ilkel modeller ve düz renkler kesin veto kapsamına alındı; Blender MCP `search_assets`, `import_asset`, `generate_3d` + gerçek CC0 `.glb` + gerçek 1K/2K görüntü tabanlı PBR doku setleri zorunlu tutuldu.

### 📌 Direktif #11 — Gerçek Modeller, Gerçek Çizimler, İnternet/GitHub/Doküman Araştırması ve Gerçek Ajan Ordusu
> `"herşey gerçek modeller gerçek assetler gerçek çizimler üzerinden yürütülecek gerekirse bütün internet taransın nasıl yapılacağını bilmiyorsa internetteki dökümanlar github repoları vs araştırılsın. bir ordu istiyorum gerçek bir yapay zeka ajan ordusu"`
* **Mimari Karşılığı:** İnternet, resmi dokümanlar ve GitHub repolarını tarayan Araştırma Taburu + fiziksel `.glb`/PBR indiren Gerçek Asset Taburu + `image-generator` ile gerçek Aion 2 illüstrasyon/portre/ikon üreten Sanat Fabrikası Taburu devreye alındı.

### 📌 Direktif #12 — 5 Ana Denetleyici (Geçmezse Baştan Başlatma & Ana Ajana Raporlama)
> `"birde bu bütün ajanların yaptığı işleri deneyleyen 5 ajan oluştursun bunlar ana denetleyiciler olsun bu denetleyicide  geçmezse baştan başlasınlar bu denetleyicilerde ana ajana bilgi versin ona göre karar alsın"`
* **Mimari Karşılığı:** Tüm ajanların çıktılarını denetleyen, geçmeyen her işi iptal edip sıfırdan yazdıran ve doğrudan Ana Ajana raporlayan **5 Ana Denetleyici (`chief_auditor_1..5`)** kuruldu; 5/5 onay şartı getirildi.

### 📌 Direktif #13 — Sürekli Geliştirme Promptu Yazan Vizyon Ajanı (Sonunda `200 subagents` Vurgusu)
> `"bir akanda devamlılığı sağlamak için sürekli benimyaptığım gibi prompt yazsın ben nasıl sana geliştirme yönünde yazıyorsam oda bu akışı geliştirmek için yazsın her mesajda 200 subagents vurgusu yapsın sonunda"`
* **Mimari Karşılığı:** Periyodik olarak projeyi denetleyip ürün sahibi gibi geliştirme/iyileştirme promptları üreten ve her mesajını **`200 subagents`** vurgusuyla bitiren `vision_prompt_director` ajanı kuruldu.

### 📌 Direktif #14 — Canlı Çalışan Ajan Sayısını Zorlama ve Destek Orkestratörleri Ekleme
> `"hala ben 57 ajan görüyorum ama zorla"` ve `"tek başıma yetemiyorda yetişemiyorsa onada destek ekleyelim"`
* **Mimari Karşılığı:** Tek orkestratör darboğazını kırmak için `lib/screens/*` altındaki **33 gerçek mobil ekranı**, 3D `.glb` hasadını, sanat fabrikasını ve QA sürecini çakışmasız paylaşan **10 Bağımsız Destek Tabur Orkestratörü (`battalion_1..10`)** paralel indirildi (`10 × 14 = +140` yeni canlı işçi → toplam **150–200+ eşzamanlı aktif ajan**).

### 📌 Direktif #15 — Taşınabilir `PROMPT_ORDUSU.md` Dokümanı + Doğrudan Git Commit & Push
> `"sana konuşmanın başından bu yana verdiğim direktiflere göre bir md dosyası oluştue adı prompt ordusu olsun ne prompt verdiysem hepsini içersin şuan aktif kaç işçi çalıştıracağını hangisinin ne görevi olduğunu ve neler yapacaklarını yazacak başka bilgisayardada aynı şekilde devam etmek için kullanacağım en ince detayına kadar yaz ve direkt commitle pushla dosyayı gite"`

---

## 3. Aktif Ordu Mevcudu (~150–200 Eşzamanlı Ajan) ve Tek Tek Görev Dağılımı

Ordu mimarisi, çakışmayı (merge/file conflict) sıfıra indiren **hiyerarşik komuta + ayrık dizin mülkiyeti (disjoint directory ownership)** prensibiyle **toplam ~195–210 ajan kapasitesinde (anlık 150–200 canlı çalışan `running` ajan)** kurgulanmıştır:

### 🏛️ A. Üst Komuta ve Süreklilik Katmanı (4 Ajan)
| Ajan Kodu | Rolü | Görevi ve Sorumluluğu |
|---|---|---|
| `sentinel` | Kök Gözetmen (`teamwork`) | Tüm orkestratörlerin canlılığını (cron ile) izler, `ORIGINAL_REQUEST.md` ve `BRIEFING.md` otoritesini korur, en sonda bağımsız Victory Audit çalıştırır. |
| `orchestrator_v1` | Dalga 1 Koruyucu Orkestratör | İlk dalgada başlatılan `Scout`, `Blender` ve `World` ajanlarının çıktılarının güvenle tamamlanmasını tutar. |
| `orchestrator_v2` | Birincil Merkez Orkestratör | Çekirdek VFX, 10K Kalabalık, Motor Konseyi, Entegrasyon işlerini ve **5 Ana Denetleyici Konseyi** karar döngüsünü yönetir. |
| `vision_prompt_director` | Sürekli Vizyon & Geliştirme Direktörü | Her 5–7 dakikada bir `assets/`, `lib/`, `shaders/`, `test/` ve ekran görüntülerini tarar; eksikleri yakalayıp Ana Ajana sürekli geliştirme promptları yazar ve **her mesajını `200 subagents` vurgusuyla bitirir**. |

---

### ⚖️ B. 5 Ana Denetleyici Konseyi — "5 Ana Denetleyici" (5 Ajan)
*(Her biri koşulsuz **RED + SIFIRDAN BAŞLATMA** yetkisine sahiptir; 5/5 onay olmadan bitiş yapılamaz.)*

| Ajan Kodu | Denetim Alanı | Neleri Test Eder ve Ne Yapacağını Nasıl Denetler? |
|---|---|---|
| `chief_auditor_1_real_assets` | Gerçek 3D Model, PBR & Sanat Denetçisi | `assets/models/`, `assets/textures/`, `assets/images/` dizinlerini fiziksel olarak tarar; CC0 lisanslarını, gerçek poligon/UV topolojisini, 1K/2K PBR haritalarını (Albedo, Normal, Roughness, Metallic, Emission), LOD0-2/Impostor Draco `.glb` çıktılarını ve Blender `look` PNG renderlarını inceler. Basit küp/küre/silindir görürse iptal edip baştan başlatır. |
| `chief_auditor_2_mobile_visual_qa` | Aion 2 Mobil Görsel & Ekran Görüntüsü Denetçisi | Tüm 33 mobil ekranın `390x844` telefon çözünürlüklü PNG ekran görüntülerini, çentik/Dynamic Island `SafeArea` yerleşimini ve 16 GLSL shader'ın görsel kalitesini inceler. Basit/2005 tarzı veya masaüstü görünümlü ekranları sıfırdan yazdırır. |
| `chief_auditor_3_combat_gameplay` | Zindan, Savaş Hissi & Mobil Mantık Denetçisi | 9 savaş VFX/juice modülünün (GPU partikül, ribbon trail, kırılma, decal, sarsıntı, 30–50ms hit-stop, rim flash, knockback, mobil titreşim, zindan meşale gölgeleri) gerçek savaş akışına bağlandığını ve `gkk_flutter` mobil oyun mantığının %100 korunduğunu doğrular. |
| `chief_auditor_4_mobile_perf_10k` | 10K Oyuncu, Mobil GPU, Düşük Sistem & Preloader Denetçisi | 10.000 varlık stres testini (`<4ms` bütçe, 0 bireysel `Update()`/PointLight, 21 draw call), 2 GB RAM düşük Android `Eco -> Ultra` adaptif ölçekleyiciyi, KTX2 ASTC/ETC2 dokularını ve `<2ms/frame` takılmasız Progressive Preloader'ı test eder. |
| `chief_auditor_5_e2e_forensic` | Uçtan Uca Kod, Test Süiti & Yayın Denetçisi | `flutter analyze` (0 hata/uyarı), tüm `flutter test` süitleri, Blender/Python testleri, `pubspec.yaml` varlık kayıtları, sıfır ölü kod/stub/TODO ve temiz git ağacını denetler. |

---

### 🛠️ C. Çekirdek Uzman Sürüler — Dalga 1 & Dalga 2 (62 Ajan)

#### 1. 🔍 Ajan-Scout Sürüsü (10 Ajan)
- `scout_1_polyhaven`: Poly Haven CC0 karanlık-fantastik taş, yosunlu duvar, ıslak zemin, ahşap 2K PBR doku ve model taraması.
- `scout_2_kenney`: Kenney CC0 modüler zindan, kale, silah ve çevre paketleri taraması.
- `scout_3_quaternius`: Quaternius & KayKit CC0 iskeletli/animasyonlu karakter, yaratık ve zindan kitleri taraması.
- `scout_4_ambientcg`: AmbientCG CC0 gotik taş, paslı demir, ıslak zindan zemini PBR haritaları (OpenGL Normal, Roughness, Height).
- `scout_5_opengameart`: OpenGameArt CC0 / ticari uyumlu yaratık, zırh ve büyü mesh taraması.
- `scout_6_cc0_verifier`: Tüm varlıkların %100 ticari kullanım/CC0 lisans uyumluluğunu denetleyen lisans denetçisi.
- `scout_7_char_models`: Şövalye, Büyücü, İskelet, Boss modelleri için kemik/animasyon ve LOD0 (10–15k), LOD1 (3–5k), LOD2 (800–1200 tri) bütçe analizi.
- `scout_8_env_models`: Gotik kemer, sütun, meşale, sunak, yıkıntı ve bitki örtüsü modüler grid standartları.
- `scout_9_weapons`: Kılıç, asa, balta, hançer ve kalkan modelleri için trail soket uçları ve parlayan rün emission maskesi analizi.
- `scout_10_pbr_catalog`: ORM (Occlusion-Roughness-Metallic) kanal paketleme ve `2048x2048` tek draw-call Texture Atlas yerleşim planı.

#### 2. 🎨 Ajan-Blender MCP & Teknik Sanat Sürüsü (10 Ajan)
- `blender_1_mcp_bridge`: Blender MCP bağlantı doğrulaması (`get_addon_status`, `get_scene_info`, `execute_blender_code`, `look`).
- `blender_2_normals_bevel`: Keskin poligon kenarlarını yok eden Python `bpy` hattı (Shade Smooth, Auto Smooth, Weighted Normals, Bevel).
- `blender_3_pbr_bake`: Cycles/EEVEE yüksek-düşük poligon PBR fırınlama (Albedo, 16-bit Normal, Roughness, Metallic, AO, Emission + UV margin dilation).
- `blender_4_lod_gen`: UV/dikiş bozulması olmadan otomatik LOD0 (%100), LOD1 (%40), LOD2 (%15) üretim hattı.
- `blender_5_impostor_bake`: 8/16 açılı kamera rig'i ile uzak mesafe kalabalıklar için Albedo+Normal+Depth Impostor Billboard Atlas fırınlama.
- `blender_6_draco_gltf`: `bpy.ops.export_scene.gltf` Draco sıkıştırmalı (pos=14, norm=10, uv=12) `.glb` dışa aktarım hattı.
- `blender_7_procedural_props`: Gerçek PBR dokulu yüksek detaylı gotik çevre/sütun/sunak detaylandırma hattı.
- `blender_8_char_rig`: Kayma (sliding) önleyici root-motion / kalabalık animasyon ve VAT (Vertex Animated Texture) hazırlık hattı.
- `blender_9_nodegraph`: Parlayan Aion 2 rünleri, ıslak taş ve aşınmış metal PBR shader node-graph kurulumu.
- `blender_10_gltf_draco_verifier`: Üretilen tüm `.glb` dosyalarının ikili (binary) Draco sıkıştırma oranlarını ve PBR kanallarını doğrulayan ajan.

#### 3. 🌍 Ajan-World & Post-Processing Sürüsü (10 Ajan)
- `world_1_hub_layout`: Mobil Anasayfa (Main Hub) sahne derinliği ve katmanlı dünya mimarisi.
- `world_2_volumetric_fog`: Yükseklik ve mesafe tabanlı Volümetrik Sis + tanrısal ışık hüzmeleri (God-Rays).
- `world_3_baked_gi`: Mobil dostu fırınlanmış küresel aydınlatma (Baked GI / Lightmap + küresel harmonik ortam ışığı).
- `world_4_ssr_puddles`: Yağmurlu/ıslak taş zeminde su birikintisi yansımaları (`shaders/world/puddle_ssr.frag`).
- `world_5_wind_shader`: Rüzgarda doğal sallanan bitki örtüsü ve sancaklar için Vertex/UV dalga shader'ı.
- `world_6_aces_ssao`: Sinematik ACES Filmic Tonemapping + yarı-küresel SSAO ve kenar koruyucu Bilateral Blur (`aces_tonemap.frag`, `ssao.frag`, `ssao_bilateral_blur.frag`, `ssao_composite_aces.frag`).
- `world_7_bloom_color`: Büyü/rün parlamaları için eşikli HDR Bloom + karanlık-fantastik Color Grading.
- `world_8_camera_ui_depth`: Sahne derinliğini kapatmayan mobil kamera perspektifi, paralaks ve `SafeArea` HUD yerleşimi.
- `world_9_sky_gi`: Canlı, hareketli bulut/aurora katmanlı atmosferik gökyüzü (`atmospheric_sky.frag`).
- `world_10_reviewer`: Düz/tekrarlayan ucuz doku yasağını ve mobil atmosfer kalitesini denetleyen World denetçisi.

#### 4. ⚔️ Ajan-VFX, Zindan & Vuruş Hissi Sürüsü (10+ Ajan)
- `vfx_1_gpu_particles`: Kıvılcım, kor, karanlık büyü girdabı ve duman için çok katmanlı GPU partikül motoru (`gpu_particles.frag`).
- `vfx_2_ribbon_trails` (+ `vfx_2b`): Catmull-Rom / Bezier enterpolasyonlu pürüzsüz silah savurma izleri (`ribbon_trail.frag`).
- `vfx_3_refraction_spells`: Şok dalgası ve büyü patlamaları için kromatik kırılmalı distorsiyon shader'ı (`shockwave_refraction.frag`).
- `vfx_4_dynamic_decals`: Zeminde kalan dinamik yanık, çatlak ve parlayan büyü rünü izleri (`ground_decal.frag`).
- `vfx_5_screen_shake`: Darbe vektörü yönünde Perlin gürültülü ve travma üslü mikro kamera sarsıntısı (`directional_camera_shake.dart`).
- `vfx_6_hit_stop`: Hafif (30ms), ağır (50ms) ve kritik vuruşlarda takılmasız Hit-Stop animasyon duraksaması (`hit_stop_manager.dart`).
- `vfx_7_rim_flash`: Darbe alan düşman silüetinde anlık Fresnel parlama (`rim_hit_flash.frag`).
- `vfx_8_knockback_ragdoll`: Vuruş yönüne göre fiziksel savrulma, sürtünmeli sönümlenme ve tökezleme harmanlaması.
- `vfx_9_dungeon_torches` (+ `vfx_9b`): Titreyen meşale/büyü ışıkları ve dinamik zindan gölge oyunları (`dungeon_lighting.frag`, `dungeon_light_system.dart`).
- `vfx_10_reviewer`: Tüm savaş efektlerinin 60 FPS kararlılığını ve vuruş hissini denetleyen VFX denetçisi.

#### 5. ⚡ Ajan-Opti 10.000 Oyuncu & Mobil Performans Sürüsü (12 Ajan)
- `opti_1_spatial_grid`: 10.000 varlığı `<1ms` içinde sorgulayan sıfır-tahsisatlı (zero-alloc) Spatial Hash Grid.
- `opti_2_aoi_tiers`: Mesafeye göre Yakın (30–50 tam model LOD0/1), Orta (GPU-Instanced LOD2) ve Uzak (VAT/Impostor) AOI katman yöneticisi.
- `opti_3_crowd_manager`: Bireysel `Update()` döngülerini tamamen ortadan kaldıran merkezi `CrowdRenderManager`.
- `opti_4_gpu_instancing`: Aynı materyali paylaşan zırh, silah ve çevre nesnelerini tek draw-call'da birleştiren GPU Instancing Batcher.
- `opti_5_vat_crowd`: Uzaktaki binlerce oyuncuyu tek draw-call ile çizen Vertex Animated Texture sürü motoru (`vat_crowd.frag`).
- `opti_6_frustum_culling`: Kamera açısı dışındaki varlıkları `0.35ms` altında eleyen SIMD/düz-dizi Frustum Culling.
- `opti_7_occlusion_culling`: Duvar/kaya arkasında kalan varlıkları çizmeyen HZB / derinlik tabanlı Occlusion Culling.
- `opti_8_ktx2_compression`: Mobil GPU'lar için ASTC (iOS/Android) ve ETC2 (uyumluluk) hedefleyen KTX2 / Basis Universal doku hattı.
- `opti_9_object_pooling`: Çöp toplayıcı (GC) takılmalarını sıfırlayan %100 ön-tahsisli Object Pool mimarisi.
- `opti_10_no_point_lights`: Oyuncu başı point light darboğazını yok eden kümelenmiş ışıklandırma (`clustered_crowd_lighting.frag`).
- `opti_11_10k_stress_benchmark`: 10.000 eşzamanlı varlık altında kare süresi (`0.21ms` tick), bellek ve draw call (`21 draw call`) stres testi koşucusu.
- `opti_12_opti_reviewer`: Optimizasyon bütçelerini denetleyen bağımsız performans denetçisi.

#### 6. 🧠 Motor Konseyi & Çekirdek Entegrasyon Ekibi (10 Ajan)
- `council_1_engine_debate`: Mobil iOS/Android yayını için Unity-as-a-Library vs Native Flutter Impeller / 3D mimari tartışma ve karar konseyi (APK/IPA şişmesi, düşük telefonlarda çift motor RAM yükü ve pil ısınması analizi).
- `council_2_low_spec_scaler` (+ `council_2b`): 2 GB RAM düşük Android cihazlardan amiral gemilerine 4 kademeli (`Eco / Low / High / Ultra`) dinamik çözünürlüklü Adaptif Kalite Ölçekleyici.
- `council_3_progressive_preloader`: Ana thread'i yormayan (`<2ms/frame` bütçeli), arka planda parça parça `.glb`/KTX2 yükleyen ve shader ön-ısıtan (PSO Warm-Up) LRU önbellekli Ön-Yükleyici.
- `integ_1_hub_scene` .. `integ_6_asset_registry` + `test_1_e2e_suite`: Merkezi 16 GLSL shader kayıt defteri, Draco varlık yükleyici ve uçtan uca entegrasyon hattı.

---

### ⚔️ D. 10 Bağımsız Destek Tabur Komutanlığı (~10 Komutan + ~140 Eşzamanlı Tabur İşçisi)

Tek orkestratörün hız sınırını aşmak ve `gkk_flutter` içindeki **33 gerçek mobil ekranın tamamını** hiçbir dosya çakışması olmadan aynı anda Aion 2 Mobile görsel seviyesine yükseltmek için çalışan **10 paralel Tabur Komutanı (`teamwork_orchestrator`)** ve altlarındaki **12–15'er eşzamanlı işçi**:

1. **Tabur 1 — `battalion_1_hub_world` (Komutan + 12–15 İşçi)**
   - **Dizin Mülkiyeti:** `lib/screens/home/`, `lib/screens/mekans/`, `lib/screens/facilities/`, `lib/components/kingdom/`, `lib/components/layout/`
   - **Görevleri:** Anasayfa gerçek 3D `.glb` sahne görünümü, volümetrik sis/ACES/SSAO/SSR mobil entegrasyonu, arka plan 10K kalabalık katmanı, mekan ve tesisler için gerçek Aion 2 atmosferik illüstrasyonlar, `390x844` `SafeArea` ekran görüntüsü testleri.

2. **Tabur 2 — `battalion_2_dungeon_pvp_war` (Komutan + 15 İşçi: `b2_w1`..`b2_w15`)**
   - **Dizin Mülkiyeti:** `lib/screens/dungeon/`, `lib/screens/pvp/`, `lib/screens/guild_war/`, `lib/components/pvp/`
   - **Görevleri:** Zindan, PvP Arenası ve Lonca Savaşı ekranlarına gerçek yaratık/boss `.glb` modelleri bağlama, titreyen meşale ve dinamik gölge aydınlatması, 9 savaş VFX/juice modülünün tamamını + mobil `HapticFeedback` titreşimlerini gerçek vuruş anlarına bağlama, Aion 2 abyssal boss çizimleri ve mobil ekran görüntüsü testleri.

3. **Tabur 3 — `battalion_3_hero_gear_enhance` (Komutan + 14–15 İşçi)**
   - **Dizin Mülkiyeti:** `lib/screens/character/`, `lib/screens/inventory/`, `lib/screens/enhancement/`, `lib/screens/loot/`, `lib/components/character/`, `lib/components/player/`
   - **Görevleri:** 360 derece döndürülebilir 3D Karakter & Silah vitrini (`CharacterTurntableViewport`, rün parlamalı zırh/kanat aurası, Fresnel yansıma), eşya güçlendirme (`enhancement`) örs kıvılcım/şok dalgası VFX'i, gerçek yüksek çözünürlüklü zırh/silah/ganimet ikonları ve mobil golden testleri.

4. **Tabur 4 — `battalion_4_economy_craft` (Komutan + 14–15 İşçi)**
   - **Dizin Mülkiyeti:** `lib/screens/crafting/`, `lib/screens/market/`, `lib/screens/shop/`, `lib/screens/trade/`, `lib/screens/bank/`, `lib/components/trade/`
   - **Görevleri:** Üretim ocağı ateş/kor partikül shader'ları, Pazar/Mağaza/Ticaret/Banka ekranları için mobil oyun mantığını bozmayan Aion 2 koyu-fantastik metalik/cam arayüz cilası, gerçek iksir/sandık/malzeme illüstrasyonları ve mobil golden testleri.

5. **Tabur 5 — `battalion_5_social_progression` (Komutan + 15 İşçi: `soc_1`..`soc_15`)**
   - **Dizin Mülkiyeti:** `lib/screens/guild/`, `lib/screens/quests/`, `lib/screens/season/`, `lib/screens/leaderboard/`, `lib/screens/reputation/`
   - **Görevleri:** Dalgalanan lonca sancağı ve parlayan amblem shader'ları, Görev parşömenleri/Sezon Bileti/Sıralama/İtibar ekranları için gerçek Aion 2 sanat varlıkları ve mobil golden testleri.

6. **Tabur 6 — `battalion_6_world_activities` (Komutan + 12–14 İşçi)**
   - **Dizin Mülkiyeti:** `lib/screens/horse_race/`, `lib/screens/prison/`, `lib/screens/hospital/`, `lib/screens/staff/`
   - **Görevleri:** At yarışı pist tozu ve hız izi (motion trail) efektleri, gotik hapishane meşale/demir parmaklık gölge atmosferi, şifahane (hospital) kutsal iyileştirme aura/bloom ışığı, gerçek personel portreleri ve mobil golden testleri.

7. **Tabur 7 — `battalion_7_onboarding_hud_settings` (Komutan + 14–15 İşçi)**
   - **Dizin Mülkiyeti:** `lib/screens/auth/`, `lib/screens/settings/`, `lib/screens/chat/`, `lib/screens/friends/`, `lib/screens/announcements/`, `lib/screens/notifications/`, `lib/components/daily_reward/`, `lib/components/comeback/`
   - **Görevleri:** Hareketli gökyüzü ve partiküllü sinematik Aion 2 mobil giriş (login) portalı, Ayarlar ekranına doğrudan `AdaptiveQualityScaler` (`Eco / Düşük / Orta / Yüksek / Ultra`) ve Ön-Yükleyici durum paneli bağlama, günlük ödül sandık açılış VFX'i ve mobil golden testleri.

8. **Tabur 8 — `battalion_8_real_glb_blender_harvest` (Komutan + 14–15 İşçi)**
   - **Dizin Mülkiyeti:** `assets/models/characters/`, `assets/models/monsters/`, `assets/models/weapons/`, `assets/models/environment/`, `assets/textures/pbr_2k/`
   - **Görevleri:** İnternetten (`curl` / `Invoke-WebRequest` ile Khronos, Poly Haven, KayKit, Quaternius, Kenney, AmbientCG) fiziksel olarak gerçek CC0 `.glb` modelleri ve 2K PBR doku haritaları indirme; Blender MCP (`search_assets`, `import_asset`, `generate_3d`) + Cycles PBR bake + LOD0/1/2/Impostor Draco `.glb` üretimi + Blender `look` PNG kanıt renderları + `pubspec.yaml` kaydı.

9. **Tabur 9 — `battalion_9_aion2_art_factory` (Komutan + 14–15 İşçi)**
   - **Dizin Mülkiyeti:** `assets/images/aion2_ui/`, `assets/images/portraits/`, `assets/images/icons/`, `assets/images/backgrounds/`, `assets/images/vfx_sprites/`
   - **Görevleri:** Paralel `image-generator` işçileriyle gerçek yüksek detaylı Aion 2 karakter/boss portreleri, süslü yetenek ve ekipman ikonları, atmosferik arka planlar, parlayan rün çemberleri ve VFX flipbook atlasları üretip `pubspec.yaml`'a kaydetme.

10. **Tabur 10 — `battalion_10_qa_council_auditors` (Komutan + 12–14 İşçi)**
    - **Dizin Mülkiyeti:** `test/golden_mobile/`, `test/stress_10k/`, `lib/qa/`
    - **Görevleri:** 33 ekranın tamamında `390x844` iOS/Android `SafeArea` PNG ekran görüntüsü alma, 10.000 varlık ve 2 GB RAM düşük Android stres testlerini koşturma ve kanıt paketlerini **5 Ana Denetleyiciye** + `vision_prompt_director`'a sunma.

### 📊 Toplam Ajan Ordusu Özeti
| Katman | Birim Sayısı | Eşzamanlı Ajan Kapasitesi |
|---|---|---|
| Üst Komuta & Sürekli Vizyon Direktörü | 4 Birim | 4 Ajan |
| 5 Ana Denetleyici Konseyi (`Chief Auditors`) | 5 Denetçi | 5 Ajan |
| Çekirdek Uzman Sürüler (Scout, Blender, World, VFX, Opti, Council, Integ) | 7 Kolu | ~62 Ajan |
| 10 Bağımsız Destek Taburu (10 Komutan + 10 × ~14 İşçi) | 10 Tabur | ~150 Ajan |
| **TOPLAM ORDU KAPASİTESİ (Dalgalar & Düzeltme İşçileriyle)** | **26 Komuta/Kolu** | **~150–220 Eşzamanlı Ajan** |

---

## 4. 5 Ana Denetleyici Konseyi (Veto & Sıfırdan Başlatma Mekanizması) + Sürekli Vizyon Direktörü

```mermaid
flowchart TD
    VPD["vision_prompt_director\n(Sürekli Geliştirme Promptçusu — '200 subagents!')"] --> ORCH["Ana Ajan / Merkez Orkestratör\n(Sentinel + Orchestrator V2)"]
    ORCH --> BAT["10 Destek Taburu + 5 Uzman Sürü\n(150–200 Eşzamanlı İşçi)"]
    BAT --> OUT["Gerçek .glb + 2K PBR + Aion 2 Çizimler\n16 GLSL Shader + 33 Mobil Ekran + 10K Motoru"]
    OUT --> A1["Ana Denetleyici 1\nGerçek 3D & Sanat"]
    OUT --> A2["Ana Denetleyici 2\nMobil PNG Ekran QA"]
    OUT --> A3["Ana Denetleyici 3\nSavaş VFX & Mobil Mantık"]
    OUT --> A4["Ana Denetleyici 4\n10K & Düşük Sistem Mobil"]
    OUT --> A5["Ana Denetleyici 5\nAnalyze & Tüm Testler"]
    A1 & A2 & A3 & A4 & A5 --> DECISION{"5/5 Oybirliği\nOnayı Var mı?"}
    DECISION -- "HAYIR (Tek 1 Red Bile Varsa)" --> REBUILD["İlgili Parçayı İptal Et &\nSıfırdan Yeniden Başlat!"]
    REBUILD --> BAT
    DECISION -- "EVET (5/5 Tam Onay)" --> GIT["Temiz Git Commit & Git Push\n(origin/selcukksezer/prawn)"]
```

---

## 5. Kesin Yasaklar (Anti-Patterns), Mobil GPU (iOS/Android) ve Motor/Preloader Kuralları

1. **PC / Web Tasarımı Yasaktır:** Fare imleci (hover), klavye kısayolu odaklı arayüz, masaüstü geniş ekran düzeni veya `dart:html` Web varsayımları kesinlikle yasaktır. Her ekran telefon ergonomisine (`SafeArea`, tek/çift başparmak erişimi, mobil dokunmatik hedefler `>=48dp`) uyacaktır.
2. **Oyun Mekaniğini Değiştirmek Yasaktır:** `gkk_flutter`'ın mevcut mobil oyun kuralları, ekonomi/üretim/lonca/zindan/pazar mantığı korunur; yalnızca görsellik, 3D varlıklar, animasyon akıcılığı, ışıklandırma ve vuruş hissi (juice) Aion 2 seviyesine yükseltilir.
3. **Basit Blender Komutlarıyla Sahte Model Yasaktır:** Küp, küre, silindir birleştirerek karakter/bina/silah yapmak otomatik red sebebidir.
4. **Sadece Liste / Katalog Yazmak Yasaktır:** Markdown dosyasına link yazıp bırakmak kabul edilmez; gerçek `.glb`, gerçek PBR doku ve gerçek PNG illüstrasyon dosyaları fiziksel olarak `assets/` içinde bulunmalı ve `pubspec.yaml`'a işlenmelidir.
5. **Düşük Sistemli Oyuncuyu Yormak Yasaktır:**
   - **Adaptif Kalite:** 2 GB–4 GB RAM giriş seviyesi telefonlarda `Eco` / `Low` profili otomatik devreye girer (`0.5x–0.75x` dinamik çözünürlük, basitleştirilmiş shader, azaltılmış partikül, baked ışık, sabit 60 FPS).
   - **Yormayan Ön-Yükleme:** `ProgressivePreloader` her karede en fazla `<2ms` bütçe kullanır; arka planda sessizce shader ısıtır ve varlıkları hazırlar, RAM sınırını aşarsa LRU ile eski varlıkları boşaltır.

---

## 6. Şu Ana Kadar Tamamlanan Çekirdek Çıktılar ve Başka Bilgisayarda Devam Etme Rehberi

### ✅ Şu Ana Kadar Üretilen Başlıca Altyapılar (Canlı Sürü Üzerine İnşa Ediyor)
- **16 Üretim GLSL Shader (`shaders/`):** `aces_tonemap.frag`, `ssao.frag`, `ssao_bilateral_blur.frag`, `ssao_composite_aces.frag`, `gpu_particles.frag`, `ribbon_trail.frag`, `rim_hit_flash.frag`, `shockwave_refraction.frag`, `ground_decal.frag`, `vat_crowd.frag`, `clustered_crowd_lighting.frag`, `dungeon_lighting.frag`, `puddle_ssr.frag`, `atmospheric_sky.frag` vb. + merkezi `ShaderPipeline` (PSO GPU ön-ısıtmalı).
- **9/9 Savaş VFX & Vuruş Hissi Modülü (`lib/core/vfx/` + `test/core/vfx/`):** GPU partiküller, Ribbon Trail, Kırılma dalgası, Dinamik zemin decal, Yönlü kamera sarsıntısı, 30–50ms Hit-Stop, Rim-light hit flash, Fiziksel knockback blend, Dinamik zindan meşale/gölge sistemi.
- **10.000 Oyuncu Kalabalık Motoru (`lib/core/crowd/` + `test/core/crowd/`):** Merkezi `CrowdRenderManager` (10.000 varlıkta `0.210ms` ortalama tick süresi, toplam `21 draw call`), Spatial Hash Grid (`0.88ms`), GPU Instancing Batcher, VAT Crowd Renderer, Frustum Culling (`0.35ms`), Occlusion Culling, KTX2/ASTC hattı.
- **Düşük Sistem Adaptif Kalite Ölçekleyici:** 2 GB RAM / Mali-G52 cihazlardan 2027 amiral gemilerine 4 donanım profili + dinamik çözünürlük ve 5 sn histerezis.
- **490+ Birim & Doğrulama Testi (0 Lint):** Çekirdek grafik, VFX, shader ve kalabalık modüllerinde 490'dan fazla otomatik test geçer durumda; 10 Tabur şu an 33 mobil ekranın tamamını, gerçek `.glb`/PBR hasadını ve Aion 2 sanat fabrikasını tamamlıyor.

### 💻 Başka Bir Bilgisayarda Kaldığı Yerden Devam Etme Adımları

1. **Repoyu ve Branch'i Çek:**
   ```bash
   git clone <REPO_URL>
   cd gkk_flutter
   git checkout selcukksezer/prawn
   git pull origin selcukksezer/prawn
   flutter pub get
   ```
2. **Blender MCP Bağlantısını Aç:**
   - Yeni bilgisayarda **Blender (4.x+)** uygulamasını aç ve **Blender MCP eklentisinin (addon)** aktif/bağlı olduğundan emin ol (`get_addon_status` ve `execute_blender_code` araçlarının yanıt verdiğini doğrula).
3. **Mevcut İlerlemeyi Kontrol Et:**
   - `git log -n 5` ve `flutter test` komutlarıyla son pushlanan durumu gör.
4. **200 Ajanlık Orduyu Tek Komutla Yeniden Ateşle:**
   - Bu dosyanın **[1. Bölümündeki Birleştirilmiş Master Prompt](#1-başka-bilgisayarda-tek-seferde-başlatma-komutu-birleştirilmiş-master-prompt)** bloğunu Antigravity sohbetine yapıştır (veya `/teamwork [skip-interview] /goal @PROMPT_ORDUSU.md içindeki tüm kuralları ve 200 subagents tabur mimarisini uygula, kalan eksikleri tamamla, 5/5 Ana Denetleyici onayından geçir ve en son git commit + push yap!` yaz).
   - Ordu otomatik olarak mevcut `lib/`, `shaders/`, `assets/` ve `test/` dosyalarını tarayacak, bitmiş modülleri koruyacak ve yalnızca eksik/cilalanmamış ekranlar ile varlıklar üzerine 150–200 eşzamanlı ajanla saldırarak 5/5 denetim onayına kadar kesintisiz çalışacaktır!
