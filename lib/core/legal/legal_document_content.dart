import '../../models/policy_model.dart';

/// TR canonical legal bodies — always shown for known doc types.
abstract final class LegalDocumentContent {
  static LegalDocument resolve(LegalDocument doc) {
    final String? canonical = _bodies[doc.type];
    if (canonical != null) {
      return LegalDocument(
        type: doc.type,
        version: doc.version,
        title: doc.title.isNotEmpty ? doc.title : _titles[doc.type] ?? doc.title,
        bodyMd: canonical,
        publishedAt: doc.publishedAt,
      );
    }
    return doc;
  }

  static String bodyFor(String type) => _bodies[type] ?? '';

  static const Map<String, String> _titles = <String, String>{
    'terms': 'Kullanım Koşulları',
    'privacy': 'Gizlilik Politikası',
    'community': 'Topluluk Kuralları',
  };

  static const Map<String, String> _bodies = <String, String>{
    'terms': _termsTr,
    'privacy': _privacyTr,
    'community': _communityTr,
  };

  static const String _termsTr = '''
# Kullanım Koşulları

**Son güncelleme:** Temmuz 2026  
**Yürürlük:** Kabul ettiğiniz anda

Gölge Krallığı Klansı mobil oyununu ("GKK", "oyun", "hizmet", "biz") indirerek, hesap açarak veya oynayarak bu Kullanım Koşullarını okuduğunuzu, anladığınızı ve kabul ettiğinizi beyan edersiniz. Kabul etmiyorsanız oyunu kullanmayın.

---

## 1. Taraflar ve tanımlar

**Hizmet sağlayıcı:** GKK operasyon ekibi  
**Kullanıcı / Oyuncu:** Hesap açan veya hizmeti kullanan gerçek kişi  
**Hesap:** E-posta veya desteklenen giriş yöntemiyle oluşturulan oyuncu profili  
**Sanal varlık:** Altın, elmas, eşya, BPP, rozet, unvan ve benzeri oyun içi içerikler  
**IAP:** App Store veya Google Play üzerinden yapılan uygulama içi satın alma

---

## 2. Hizmetin kapsamı

GKK; zindan, PvP düellosu, lonca savaşları, pazar, craft, sezon pass, sohbet ve benzeri sosyal/ekonomik oyun sistemlerini sunan ücretsiz oynanabilir (free-to-play) bir mobil oyundur.

- İnternet bağlantısı gerektirir.
- Özellikler bakım, denge veya teknik nedenlerle geçici/kalıcı değiştirilebilir.
- Beta veya test sürümlerinde veri sıfırlama, geri alınamayan değişiklikler olabilir.
- Bazı içerikler IAP, reklam izleme veya oyun içi görevlerle açılır.

---

## 3. Yaş sınırı ve hesap sorumluluğu

- Hizmet **13 yaş ve üzeri** kullanıcılar içindir. 13–18 arası ebeveyn/vasi onayı önerilir.
- Hesap bilgilerinizin doğruluğundan siz sorumlusunuz.
- Şifre ve oturum güvenliğinden siz sorumlusunuz; hesabınızı üçüncü kişilerle paylaşmayın.
- Hesap satışı, devri, kiralama veya paylaşımı **yasaktır**.
- Şüpheli giriş, hırsızlık veya yetkisiz kullanım fark ederseniz derhal şifre değiştirin ve destek ticket açın.
- Bir kişi yalnızca makul sayıda hesap açabilir; çoklu hesap istismarı ban sebebidir (staff izni hariç).

---

## 4. Kabul edilebilir kullanım

Aşağıdaki davranışlar **kesinlikle yasaktır**:

### 4.1 Hile ve istismar
- Üçüncü taraf hile, mod, bot, macro, otomatik savaş scriptleri
- Sunucu/API manipülasyonu, paket enjeksiyonu, reverse engineering ile haksız avantaj
- Bilinen bug/exploit'i bildirmek yerine kasıtlı kullanmak
- QA/staff hesaplarını veya test ortamlarını kötüye kullanmak

### 4.2 Ekonomik suistimal
- Gerçek para ile oyun içi varlık alım-satımı (RMT)
- Dolandırıcılık, sahte trade, phishing, "bedava elmas" tuzakları
- Pazar manipülasyonu, bot spam, fiyat istismarı

### 4.3 Hesap ve kimlik
- Başkasının hesabını kullanmak veya çalmaya teşebbüs
- Staff/mod/dev kimliğine bürünmek
- Sahte isim, taklit veya yanıltıcı profil kullanımı (moderasyon kurallarına aykırı)

### 4.4 Teknik saldırı
- DDoS, aşırı otomatik istek, scraping, servis kesintisine yol açacak yük

**Yaptırım:** Uyarı → geçici kısıtlama → envanter/altın/elmas düzeltmesi → trade/chat ban → geçici ban → **kalıcı ban**. Ağırlık ihlale göre belirlenir; karar nihai olabilir.

---

## 5. Sanal varlıklar ve satın almalar

- Altın, elmas, eşya ve diğer sanal içerikler size **sınırlı lisans** ile sunulur; mülkiyet devri yoktur.
- Bakım, denge güncellemesi, anti-cheat düzeltmesi veya hata giderme nedeniyle değerler değişebilir; telafi zorunlu değildir.
- IAP işlemleri ilgili mağazanın (Apple/Google) şartlarına tabidir.
- Oyun içi iade garantisi verilmez; iade talepleri mağaza prosedürüne göre değerlendirilir.
- Promosyon/bedava elmaslar (bug bildirimi, etkinlik, staff hediyesi vb.) **ticari satın alma sayılmaz** ve devredilemez.
- Hile veya exploit yoluyla elde edilen varlıklar sıfırlanabilir.

---

## 6. Bug bildirimi ve ödüller

- Oyun hatalarını uygulama içi ticket veya resmi destek kanallarından bildirebilirsiniz.
- **Mağaza yorumu, puan, sosyal medya paylaşımı veya dış platform karşılığı ödül talep edilemez.**
- Doğrulanan ve tekrarlanabilir raporlara oyun içi elmas verilebilir; miktar ve uygunluk tamamen GKK takdirindedir, garanti yoktur.
- Aynı bug için çoklu raporlarda yalnızca ilk geçerli rapor ödüllendirilebilir.

---

## 7. Fikri mülkiyet

- Oyun görselleri, sesler, metinler, kod, marka ve tasarımlar GKK'ya veya lisans verenlerine aittir.
- İzinsiz kopyalama, dağıtım, türev eser, reverse engineering veya ticari kullanım yasaktır.
- Kullanıcı tarafından oluşturulan içerik (sohbet, lonca adı vb.) hizmetin işletilmesi için gerekli lisansı bize verirsiniz; kamuya açık paylaşım moderasyon kurallarına tabidir.

---

## 8. Hizmetin değiştirilmesi ve sonlandırılması

- Özellikler güncellenebilir, geçici bakıma alınabilir veya kaldırılabilir.
- Hesabınızı silme talebinde bulunabilirsiniz; kişisel veriler Gizlilik Politikası'na göre işlenir.
- Uzun süreli inaktif hesaplar, kötüye kullanım veya yasal zorunluluk halinde kısıtlanabilir veya kapatılabilir.
- Hizmetin tamamen sonlandırılması halinde makul süre önceden duyuru yapılmaya çalışılır.

---

## 9. Sorumluluk sınırı

- Hizmet **"olduğu gibi"** ve **"mevcut olduğu şekilde"** sunulur.
- Kesinti, lag, veri kaybı, üçüncü taraf mağaza/ödeme sorunlarından doğan dolaylı zararlardan sorumlu değiliz.
- Yasaların izin verdiği azami ölçüde toplam sorumluluğumuz, son 12 ayda ödediğiniz IAP tutarı ile sınırlı olabilir.

---

## 10. Uyuşmazlık ve geçerli hukuk

- Bu koşullar Türkiye Cumhuriyeti kanunlarına tabidir.
- Uyuşmazlıklarda **İstanbul (Merkez) Mahkemeleri ve İcra Daireleri** yetkilidir.
- Tüketici hakları saklıdır; zorunlu yerel mevzuat hükümleri geçerlidir.

---

## 11. Değişiklikler

- Koşullar güncellenebilir. Önemli değişikliklerde uygulama içi onay ekranı gösterilir.
- Yeni sürümü kabul etmeden oyun devam edemeyebilir.
- Güncel metin uygulama içi "Oku" bağlantısından erişilebilir.

---

## 12. İletişim

**E-posta:** support@gkk.game  
**Uygulama içi:** Ayarlar → Destek → Ticket aç
''';

  static const String _privacyTr = '''
# Gizlilik Politikası

**Son güncelleme:** Temmuz 2026  
**Kapsam:** GKK mobil uygulaması ve bağlı sunucu hizmetleri

6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") ve ilgili mevzuata uygun olarak kişisel verilerinizi işleriz. Bu metin hangi verileri topladığımızı, neden topladığımızı ve haklarınızı açıklar.

---

## 1. Veri sorumlusu

**Veri sorumlusu:** GKK operasyon ekibi  
**İletişim:** support@gkk.game  
**Başvuru:** Uygulama içi destek ticket veya e-posta

---

## 2. Toplanan veri kategorileri

| Kategori | Örnek veriler | Toplama yöntemi | Amaç |
|----------|---------------|-----------------|------|
| Kimlik / Hesap | E-posta, kullanıcı adı, görünen ad, auth_id | Kayıt, giriş | Hesap oluşturma, oturum, kurtarma |
| Oyun profili | Seviye, XP, envanter, güç, itibar, lonca | Oyun oynarken | İlerleme, denge, kayıt senkronu |
| Sosyal | Sohbet mesajları, raporlar, engel listesi | Sohbet/PvP | Moderasyon, güvenlik, destek |
| İşlem | IAP referansı, satın alma geçmişi (kart **toplanmaz**) | Mağaza callback | Ödeme doğrulama, fraud önleme |
| Teknik | Uygulama sürümü, platform (iOS/Android), dil | Otomatik | Hata ayıklama, uyumluluk |
| Destek | Ticket metni, ekran görüntüsü (siz yüklerseniz) | Ticket formu | Sorun çözümü |
| Güvenlik | Ban/susturma logları, şüpheli aktivite kayıtları | Sistem | Anti-cheat, kötüye kullanım |

**Toplamadığımız (bug bildirimi dahil):** IMEI, reklam kimliği (IDFA/GAID), hassas konum, rehber erişimi.

---

## 3. Verilerin işlenme amaçları

- Oyun hizmetini sunmak, kaydetmek ve senkronize etmek
- Kimlik doğrulama ve oturum yönetimi
- Hile, dolandırıcılık ve spam tespiti
- Topluluk kuralları ve yasal yükümlülükler (moderasyon)
- Müşteri desteği ve şikâyet yönetimi
- Hizmet kalitesi, performans ve hata analizi
- Önemli güvenlik/hizmet bildirimleri (pazarlama spam değil)

---

## 4. Hukuki dayanak (KVKK md. 5)

- **Sözleşmenin kurulması/ifası:** Hesap, oyun ilerlemesi, IAP doğrulama
- **Meşru menfaat:** Güvenlik, anti-cheat, kötüye kullanım önleme (haklarınıza zarar vermeyecek şekilde)
- **Hukuki yükümlülük:** Resmi makam talepleri, kayıt saklama
- **Açık rıza:** Zorunlu olmayan bildirim tercihleri (ayarlardan yönetilebilir)

---

## 5. Verilerin paylaşımı

Verilerinizi **reklam amacıyla satmayız veya kiralamayız.**

Paylaşım yalnızca şu durumlarda sınırlıdır:

- **Altyapı:** Barındırma, veritabanı (Supabase vb.), CDN — hizmet sağlayıcı sözleşmeleri ile
- **Mağazalar:** Apple App Store / Google Play — IAP doğrulama
- **Yasal zorunluluk:** Mahkeme kararı, savcılık, yetkili kamu kurumu talebi
- **Acil güvenlik:** Can veya mal güvenliği tehdidi (yasaların izin verdiği ölçüde)

Yurt dışına aktarım: Altyapı sağlayıcıları AB/UK uyumlu bölgelerde barındırma yapabilir; gerekli sözleşmesel güvenceler uygulanır.

---

## 6. Saklama süreleri

| Veri | Süre |
|------|------|
| Aktif hesap verileri | Hesap açık kaldığı sürece |
| Silinen hesap | 30 gün içinde kalıcı silme (yedekten temizleme dahil) |
| Moderasyon / güvenlik logları | En fazla 24 ay |
| Destek ticket | Kapatıldıktan sonra 12 ay |
| Yasal zorunlu muhasebe/IAP kayıtları | İlgili mevzuat süresi |

Süre dolunca veriler silinir, anonimleştirilir veya arşivlenir.

---

## 7. KVKK kapsamındaki haklarınız

- **Bilgi talep etme** — verileriniz işleniyor mu?
- **Erişim** — hangi verileriniz var?
- **Düzeltme** — hatalı/eksik verilerin güncellenmesi
- **Silme** — koşullar oluştuğunda (hesap silme talebi)
- **İşlemeyi kısıtlama** — belirli durumlarda
- **İtiraz** — meşru menfaat işlemelerine
- **Veri taşınabilirliği** — teknik olarak mümkün olduğu ölçüde

**Başvuru:** support@gkk.game — kimlik doğrulama için kullanıcı adınızı belirtin.  
**Yanıt süresi:** En geç 30 gün (KVKK md. 13).

---

## 8. Çocukların gizliliği

13 yaş altı bilerek kayıt kabul edilmez. Tespit halinde hesap kapatılır ve veriler silinir. Ebeveyn/vasi şüphesi halinde bize yazın.

---

## 9. Çerez ve yerel depolama

- Oturum token'ı (Supabase auth)
- Tutorial ilerlemesi, dil tercihi, bildirim ayarları
- SharedPreferences / secure storage

Bu veriler cihazınızda ve/veya hesabınıza bağlı sunucuda tutulur; üçüncü taraf reklam çerezi kullanılmaz.

---

## 10. Güvenlik önlemleri

- TLS ile şifreli iletişim
- Row Level Security (RLS) ile veritabanı erişim kontrolü
- Sunucu tarafı oyun mantığı (client-side güvenilmez kabul edilir)
- Yetkisiz erişim şüphesinde inceleme ve hesap kilitleme

Mutlak güvenlik garanti edilemez; şifrenizi güçlü tutun ve paylaşmayın.

---

## 11. Politika değişiklikleri

Önemli değişikliklerde uygulama içi onay ekranı gösterilir. Kabul etmeden devam edemezsiniz. Güncel metin her zaman "Oku" ile erişilebilir.

---

## 12. İletişim

**support@gkk.game**
''';

  static const String _communityTr = '''
# Topluluk Kuralları

**Son güncelleme:** Temmuz 2026  
**Kapsam:** Sohbet, lonca, PvP, pazar, trade, profil ve tüm oyuncu etkileşimleri

GKK'da herkes güvenli, saygılı ve adil bir ortam hak eder. Bu kurallar ihlal edildiğinde moderasyon uygulanır. Kuralları bilmek sorumluluğunuzu kaldırmaz.

---

## 1. Temel ilke

**Saygılı ol. Adil oyna. Scam'e kanma. Bug'ı bildir.**

---

## 2. Saygı ve iletişim

### Yasak
- Hakaret, küfür, aşağılama, alay, taciz, stalking
- Nefret söylemi: ırk, etnik köken, din, cinsiyet, cinsel yönelim, engellilik vb. hedef alan içerik
- Tehdit, şantaj, şiddet çağrısı
- Doxxing: gerçek ad, adres, telefon, okul/iş yeri ifşası
- Cinsel içerik, NSFW, reşit olmayanlara yönelik veya ima eden içerik
- Aşırı küfür/spam ile sohbeti boğmak

### Teşvik edilen
- Yeni oyunculara yardım
- Yapıcı eleştiri
- Sportmenlik (PvP sonrası toxic davranış yok)
- Sorunları ticket veya rapor ile bildirmek

---

## 3. Dolandırıcılık, trade ve ekonomi

### Kesinlikle yasak
- Sahte trade: eşya/altın vaadi ile aldatma
- "Bedava elmas", "hack", "generator" phishing linkleri
- Discord/Telegram/WhatsApp dış platformda güvensiz anlaşma tuzağı
- Gerçek para ile oyun içi varlık alım-satımı (RMT)
- Pazar manipülasyonu: bot fiyat spam, koordineli sahte alım-satım
- Lonca kasası / ortak kaynak hırsızlığı (yetki kötüye kullanımı)

### Trade güvenliği
- Resmi trade ekranını kullanın; dış anlaşmaya güvenmeyin
- Onaylamadan önce karşı tarafın koyduklarını **iki kez** kontrol edin
- Şüpheli oyuncuları engelleyin ve raporlayın

**Yaptırım:** Trade ban → envanter düzeltme → geçici/kalıcı ban

---

## 4. Spam, reklam ve bot

- Aynı mesajı tekrar tekrar göndermek (flood)
- Reklam: Discord sunucusu, kanal, ürün (staff onayı olmadan)
- Bot, macro, otomatik mesaj veya davet spam
- Sahte "duyuru" ile oyuncu yönlendirme

**Yaptırım:** Susturma → ban

---

## 5. Hile, exploit ve adil oyun

- Üçüncü taraf hile, mod APK/IPA, memory editor, speed hack
- Otomatik savaş, otomatik loot, unattended farming
- Bilinen bug'ı bildirmek yerine kasıtlı kullanmak (duplicate item, negatif fiyat vb.)
- Çoklu hesap ile avantaj (alt farm, oy verme istismarı) — staff izni hariç
- Matchmaking veya turnuva sistemini manipüle etmek

**Yaptırım:** Anında ban, varlık sıfırlama, geri alınamaz

---

## 6. Lonca, kuşatma ve PvP davranışı

- Lonca içi zorbalık, ayrımcılık, haksız kick
- Kuşatma/savaş saatlerinde kasıtlı sabotaj (afk slot, spy alt)
- Koordineli hedef gösterme / brigading
- PvP sonrası sohbette sürekli taciz
- Yeni oyunculara (düşük level) kasıtlı zorbalık

Lonca liderleri üyelerin kurallara uymasından kısmen sorumludur.

---

## 7. Profil, isim ve içerik

- Küfür, cinsel ima, nefret içeren kullanıcı adı veya görünen ad
- Staff/dev/mod taklit isimleri
- Yanıltıcı "resmi" unvan kullanımı
- Uygunsuz profil/avatar (varsa)

**Yaptırım:** Zorunlu rename → susturma → ban

---

## 8. Raporlama ve engelleme

### Nasıl raporlanır?
- Sohbet: mesaja uzun bas → **Raporla**
- Oyuncu profili / trade: engelle + ticket
- Ciddi ihlal: support@gkk.game + ekran görüntüsü

### Kötüye kullanım
- Asılsız toplu rapor spam cezalandırılır
- Rapor gizliliği korunur; intikam raporu tespit edilirse raporlayana da ceza uygulanabilir

---

## 9. Moderasyon yaptırım skalası

| Seviye | Örnek ihlal | Olası sonuç |
|--------|-------------|-------------|
| 1 — Uyarı | İlk hafif küfür, yanlışlıkla spam | Yazılı uyarı |
| 2 — Susturma | Tekrarlayan toxic, flood | 1–72 saat chat kapalı |
| 3 — Trade ban | Scam girişimi, sahte trade | Ticaret kilit |
| 4 — Geçici ban | Ciddi taciz, tekrarlayan hile şüphesi | 1–30 gün |
| 5 — Kalıcı ban | Onaylı hile, RMT, tehdit, CSAM, ciddi dolandırıcılık | Hesap kapatma |

Süre ve ağırlık staff takdirindedir. Geçmiş ihlaller cezayı artırır.

---

## 10. İtiraz süreci

Ban veya susturma itirazı:

1. support@gkk.game veya uygulama içi ticket
2. Kullanıcı adı, tarih, kısa açıklama
3. Varsa kanıt (ekran görüntüsü)

**Yanıt:** Genelde 3–7 iş günü. Acil güvenlik banlarında itiraz reddedilebilir.

---

## 11. Staff ve resmi iletişim

- Staff kimliği taklit etmek **yasaktır**
- Staff talimatlarına uymak zorunludur
- Resmi duyurular uygulama içi kanallardan yapılır; DM ile "bedava elmas" vaadi **dolandırıcılıktır**

---

## 12. Özet — hatırla

1. İnsanlara saygılı davran  
2. Trade'de dikkatli ol, dış linklere kanma  
3. Hile/exploit kullanma — bildir  
4. Spam yapma, reklam atma  
5. Sorun olursa raporla veya ticket aç  

**İyi oyunlar, Gölge Savaşçısı.**
''';
}
