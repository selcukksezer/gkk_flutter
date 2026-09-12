# GKK Flutter Oyunu Güvenlik Taraması, Açık Analizi ve Sertleştirme Önerileri

## 1. Yönetici Özeti (Executive Summary)

Bu rapor, **gkk_flutter** uygulamasının istemci (Flutter/Dart) ve veritabanı (Supabase PostgreSQL / RPC) katmanlarında gerçekleştirilen güvenlik taraması ve analiz sonuçlarını içermektedir.

Yapılan incelemede, uygulamanın kritik ekonomi ve envanter işlemlerinde **Sunucu Tarafı RPC Doğrulaması (Server-Side Validation)** kullandığı ve yetkisiz istemci müdahalelerine karşı önemli savunma katmanlarına sahip olduğu görülmüştür. Ancak canlı prodüksiyon ortamında dikkat edilmesi gereken potansiyel risk alanları ve sertleştirme adımları belirlenmiştir.

---

## 2. İstemci Katmanı Güvenlik İncelemesi (Client-Side Audit)

### A. Supabase Anonim Anahtar Yapılandırması (Anon Key)
- **Bulgu**: `lib/core/constants/app_constants.dart` içerisinde Supabase URL ve `supabaseAnonKey` sabit olarak tanımlıdır.
- **Risk Seviyesi**: **DÜŞÜK / BİLGİ** (Beklenen Mimari)
- **Açıklama**: Supabase mimarisinde `anonKey` istemci tarafında yayınlanmak üzere tasarlanmıştır. Güvenlik `anonKey`'in gizliliğiyle değil, veritabanındaki **RLS (Row Level Security)** politikaları ve RPC yetkilendirmeleri (`GRANT EXECUTE`) ile sağlanır.
- **Öneri**: `service_role` anahtarının hiçbir zaman Flutter koduna dahil edilmediği doğrulanmıştır. `service_role` anahtarı yalnızca güvenli sunucu (Edge Functions/Backend) tarafında kalmalıdır.

### B. İstemci Tarafı Eşya / Altın Minting Kısıtlaması
- **Bulgu**: `lib/repositories/inventory_repository.dart` içerisinde `addItemToServer` metodu istemciden doğrudan çağrıldığında `INVENTORY_CLIENT_MINT_DISABLED` hatası fırlatmaktadır.
- **Risk Seviyesi**: **GÜVENLİ (İyi Uygulama)**
- **Açıklama**: Oyuncunun kendi cihazından istemci kodunu değiştirip (reverse engineering) envanterine doğrudan item eklemesi önlenmiştir. Tüm eşya ve altın kazanımları yalnızca güvenli sunucu RPC'leri (`shop`, `loot`, `dungeon_battle`) üzerinden gerçekleşir.

### C. Yerel Veri Depolama (Device Identity & Preferences)
- **Bulgu**: `lib/core/services/device_identity_service.dart` cihaz kimliğini (UUID) `SharedPreferences` üzerinde saklamaktadır.
- **Risk Seviyesi**: **DÜŞÜK**
- **Açıklama**: Android/iOS platformlarında `SharedPreferences` düz metin (unencrypted) olarak saklanır. Cihaz ID veya ayarlar gibi hassas olmayan veriler için uygundur; ancak oturum token'ları veya özel anahtarlar için `flutter_secure_storage` tercih edilmelidir.

---

## 3. Veritabanı ve RPC Katmanı Güvenlik İncelemesi (Backend / Supabase Audit)

### A. İptal Edilmiş ve Sertleştirilmiş Eski RPC Grant'leri
- **Bulgu**: Geçmiş SQL migrasyonlarında (`20260224_170000_fix_identity_and_rls.sql` vb.) `add_inventory_item_v2` ve `buy_shop_item` gibi fonksiyonlara `anon` rolüne `GRANT EXECUTE` verilmişti.
- **Mevcut Durum**: `20260613_100000_security_rls_hardening.sql`, `20261013_000000_secure_shop_currency_inventory.sql` ve `20260729_282000_anticheat_hardening.sql` migrasyonları ile bu izinler `anon` rolünden tamamen REVOKE edilmiş ve yetkiler yalnızca `authenticated` ve `service_role` rollerine kısıtlanmıştır.
- **Risk Seviyesi**: **KONTROL ALTINDA**

### B. QA ve Test Fonksiyonlarının Kilitlenmesi (QA Functions Lockdown)
- **Bulgu**: Projede `qa_smoke_bugfix_batch()`, `qa_badge_season_smoke()`, `qa_player_journey_f2p()` gibi simülasyon ve smoke test fonksiyonları bulunmaktadır.
- **Risk Seviyesi**: **ORTA (Prodüksiyon Riski)**
- **Açıklama**: Bu fonksiyonlar `20260613_102000_qa_functions_lockdown.sql` migrasyonu ile kilitlenmiş ve `app.qa_mode = true` kontrolüne bağlanmıştır.
- **Öneri**: Canlı (Production) veritabanı ortamında `app.qa_mode` parametresinin `false` olduğu ve bu test RPC'lerinin normal oyunculara kapalı olduğu canlı deployment öncesinde doğrulanmalıdır.

---

## 4. Güvenlik Sertleştirme ve Düzenleme Önerileri (Remediation Checklist)

1. **Hassas Veriler İçin Secure Storage Kullanımı**:
   - İleride eklenecek olan biometrik doğrulama veya özel oyuncu gizli anahtarları için `SharedPreferences` yerine `flutter_secure_storage` kütüphanesine geçilmelidir.

2. **Rate Limiting (İstek Sınırlama)**:
   - İstemciden veritabanına atılan RPC çağrılarına (örneğin pazar teklifleri, PvP düello istekleri, sohbet mesajları) Supabase / PostgreSQL katmanında IP ve Kullanıcı ID bazlı zaman sınırlaması (rate limit) uygulanmalıdır.

3. **Input Sanitization (Girdi Temizleme)**:
   - Sohbet mesajları (`lib/screens/chat/`), oyuncu görünen isimleri ve lonca açıklamaları için XSS veya SQL injection benzeri zararlı karakterlerin sunucu tarafında temizlendiğinden emin olunmalıdır (PostgreSQL `quote_literal` veya HTML escape).

4. **SSL Pinning (Opsiyonel Mobil Sertleştirme)**:
   - Mobil uygulamadan Supabase sunucularına yapılan HTTPS isteklerinde Man-In-The-Middle (MITM) saldırılarını engellemek adına Flutter `http`/`dio` istemcisine SSL Pinning eklenebilir.

5. **Prodüksiyon DB QA Temizliği**:
   - Canlı yayına çıkılmadan önce `qa_` öneki taşıyan tüm test ve simülasyon RPC'lerinin canlı DB şemasında pasifleştirilmesi veya yalnızca isolated staging ortamında çalıştırılması sağlanmalıdır.
