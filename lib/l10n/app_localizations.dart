import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @zeka.
  ///
  /// In en, this message translates to:
  /// **'Zeka'**
  String get zeka;

  /// No description provided for @sald_r.
  ///
  /// In en, this message translates to:
  /// **'Saldırı'**
  String get sald_r;

  /// No description provided for @savunma.
  ///
  /// In en, this message translates to:
  /// **'Savunma'**
  String get savunma;

  /// No description provided for @ans.
  ///
  /// In en, this message translates to:
  /// **'Şans'**
  String get ans;

  /// No description provided for @pvp_kazanma.
  ///
  /// In en, this message translates to:
  /// **'PvP Kazanma'**
  String get pvp_kazanma;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @geli_im_sava_i_statistikleri.
  ///
  /// In en, this message translates to:
  /// **'Gelişim & Savaş İstatistikleri'**
  String get geli_im_sava_i_statistikleri;

  /// No description provided for @zindan.
  ///
  /// In en, this message translates to:
  /// **'Zindan'**
  String get zindan;

  /// No description provided for @aktif_g_revler.
  ///
  /// In en, this message translates to:
  /// **'Aktif Görevler'**
  String get aktif_g_revler;

  /// No description provided for @t_m_n_g_r.
  ///
  /// In en, this message translates to:
  /// **'Tümünü Gör'**
  String get t_m_n_g_r;

  /// No description provided for @gold.
  ///
  /// In en, this message translates to:
  /// **'GOLD'**
  String get gold;

  /// No description provided for @g_nl_k_d_l.
  ///
  /// In en, this message translates to:
  /// **'Günlük Ödül'**
  String get g_nl_k_d_l;

  /// No description provided for @kapat.
  ///
  /// In en, this message translates to:
  /// **'Kapat'**
  String get kapat;

  /// No description provided for @g_n_s_f_rlanmas_utc_00_00_1_g_n_ka_r_rsan_g_n_1.
  ///
  /// In en, this message translates to:
  /// **'Gün sıfırlanması: UTC 00:00 • 1 gün kaçırırsan Gün 1'**
  String get g_n_s_f_rlanmas_utc_00_00_1_g_n_ka_r_rsan_g_n_1;

  /// No description provided for @s_20_g_nl_k_d_l_yolu.
  ///
  /// In en, this message translates to:
  /// **'20 Günlük Ödül Yolu'**
  String get s_20_g_nl_k_d_l_yolu;

  /// No description provided for @bug_n_n_d_l.
  ///
  /// In en, this message translates to:
  /// **'Bugünün Ödülü'**
  String get bug_n_n_d_l;

  /// No description provided for @ana_sayfa.
  ///
  /// In en, this message translates to:
  /// **'Ana Sayfa'**
  String get ana_sayfa;

  /// No description provided for @envanter.
  ///
  /// In en, this message translates to:
  /// **'Envanter'**
  String get envanter;

  /// No description provided for @karakter.
  ///
  /// In en, this message translates to:
  /// **'Karakter'**
  String get karakter;

  /// No description provided for @men.
  ///
  /// In en, this message translates to:
  /// **'Menü'**
  String get men;

  /// No description provided for @sohbet.
  ///
  /// In en, this message translates to:
  /// **'Sohbet'**
  String get sohbet;

  /// No description provided for @s_ralama.
  ///
  /// In en, this message translates to:
  /// **'Sıralama'**
  String get s_ralama;

  /// No description provided for @battle_pass.
  ///
  /// In en, this message translates to:
  /// **'Battle Pass'**
  String get battle_pass;

  /// No description provided for @lonca.
  ///
  /// In en, this message translates to:
  /// **'Lonca'**
  String get lonca;

  /// No description provided for @lonca_sava.
  ///
  /// In en, this message translates to:
  /// **'Lonca Savaşı'**
  String get lonca_sava;

  /// No description provided for @kasa_acma.
  ///
  /// In en, this message translates to:
  /// **'Kasa Acma'**
  String get kasa_acma;

  /// No description provided for @pazar.
  ///
  /// In en, this message translates to:
  /// **'Pazar'**
  String get pazar;

  /// No description provided for @ma_aza.
  ///
  /// In en, this message translates to:
  /// **'Mağaza'**
  String get ma_aza;

  /// No description provided for @banka.
  ///
  /// In en, this message translates to:
  /// **'Banka'**
  String get banka;

  /// No description provided for @ticaret.
  ///
  /// In en, this message translates to:
  /// **'Ticaret'**
  String get ticaret;

  /// No description provided for @zanaat.
  ///
  /// In en, this message translates to:
  /// **'Zanaat'**
  String get zanaat;

  /// No description provided for @item_upgrade.
  ///
  /// In en, this message translates to:
  /// **'Item Upgrade'**
  String get item_upgrade;

  /// No description provided for @tesisler.
  ///
  /// In en, this message translates to:
  /// **'Tesisler'**
  String get tesisler;

  /// No description provided for @mekanlar.
  ///
  /// In en, this message translates to:
  /// **'Mekanlar'**
  String get mekanlar;

  /// No description provided for @g_revler.
  ///
  /// In en, this message translates to:
  /// **'Görevler'**
  String get g_revler;

  /// No description provided for @hastane.
  ///
  /// In en, this message translates to:
  /// **'Hastane'**
  String get hastane;

  /// No description provided for @hapishane.
  ///
  /// In en, this message translates to:
  /// **'Hapishane'**
  String get hapishane;

  /// No description provided for @ayarlar.
  ///
  /// In en, this message translates to:
  /// **'Ayarlar'**
  String get ayarlar;

  /// No description provided for @k_yap.
  ///
  /// In en, this message translates to:
  /// **'Çıkış Yap'**
  String get k_yap;

  /// No description provided for @at_yarisi.
  ///
  /// In en, this message translates to:
  /// **'At Yarisi'**
  String get at_yarisi;

  /// No description provided for @ticaret_i_ste_i.
  ///
  /// In en, this message translates to:
  /// **'🤝 Ticaret İsteği'**
  String get ticaret_i_ste_i;

  /// No description provided for @reddet.
  ///
  /// In en, this message translates to:
  /// **'Reddet'**
  String get reddet;

  /// No description provided for @kabul_et.
  ///
  /// In en, this message translates to:
  /// **'Kabul Et'**
  String get kabul_et;

  /// No description provided for @bu_ki_iden_gelen_ticaret_isteklerini_4_saat_engell.
  ///
  /// In en, this message translates to:
  /// **'Bu kişiden gelen ticaret isteklerini 4 saat engelle'**
  String get bu_ki_iden_gelen_ticaret_isteklerini_4_saat_engell;

  /// No description provided for @gkk_mobile.
  ///
  /// In en, this message translates to:
  /// **'GKK Mobile'**
  String get gkk_mobile;

  /// No description provided for @haftal_k_pvp_turnuvas.
  ///
  /// In en, this message translates to:
  /// **'Haftalık PvP Turnuvası'**
  String get haftal_k_pvp_turnuvas;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @gozat.
  ///
  /// In en, this message translates to:
  /// **'Gozat'**
  String get gozat;

  /// No description provided for @pazarim.
  ///
  /// In en, this message translates to:
  /// **'Pazarim'**
  String get pazarim;

  /// No description provided for @t_m.
  ///
  /// In en, this message translates to:
  /// **'Tümü'**
  String get t_m;

  /// No description provided for @g_nl_k.
  ///
  /// In en, this message translates to:
  /// **'Günlük'**
  String get g_nl_k;

  /// No description provided for @haftal_k.
  ///
  /// In en, this message translates to:
  /// **'Haftalık'**
  String get haftal_k;

  /// No description provided for @auth_home.
  ///
  /// In en, this message translates to:
  /// **'Auth → Home'**
  String get auth_home;

  /// No description provided for @open_inventory.
  ///
  /// In en, this message translates to:
  /// **'Open inventory'**
  String get open_inventory;

  /// No description provided for @dungeon_navigation.
  ///
  /// In en, this message translates to:
  /// **'Dungeon navigation'**
  String get dungeon_navigation;

  /// No description provided for @character_screen.
  ///
  /// In en, this message translates to:
  /// **'Character screen'**
  String get character_screen;

  /// No description provided for @quick_menu_grid.
  ///
  /// In en, this message translates to:
  /// **'Quick menu grid'**
  String get quick_menu_grid;

  /// No description provided for @shop_via_quick_menu.
  ///
  /// In en, this message translates to:
  /// **'Shop via quick menu'**
  String get shop_via_quick_menu;

  /// No description provided for @bank_via_quick_menu.
  ///
  /// In en, this message translates to:
  /// **'Bank via quick menu'**
  String get bank_via_quick_menu;

  /// No description provided for @quests_via_quick_menu.
  ///
  /// In en, this message translates to:
  /// **'Quests via quick menu'**
  String get quests_via_quick_menu;

  /// No description provided for @guild_via_quick_menu.
  ///
  /// In en, this message translates to:
  /// **'Guild via quick menu'**
  String get guild_via_quick_menu;

  /// No description provided for @settings_via_quick_menu.
  ///
  /// In en, this message translates to:
  /// **'Settings via quick menu'**
  String get settings_via_quick_menu;

  /// No description provided for @i_tibar.
  ///
  /// In en, this message translates to:
  /// **'İtibar'**
  String get i_tibar;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @dungeon.
  ///
  /// In en, this message translates to:
  /// **'Dungeon'**
  String get dungeon;

  /// No description provided for @character.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get character;

  /// No description provided for @splash.
  ///
  /// In en, this message translates to:
  /// **'Splash'**
  String get splash;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @character_select.
  ///
  /// In en, this message translates to:
  /// **'Character Select'**
  String get character_select;

  /// No description provided for @dungeon_battle.
  ///
  /// In en, this message translates to:
  /// **'Dungeon Battle'**
  String get dungeon_battle;

  /// No description provided for @gkk_character_select.
  ///
  /// In en, this message translates to:
  /// **'GKK // CHARACTER SELECT'**
  String get gkk_character_select;

  /// No description provided for @s_n_f_n_se_ve_maceraya_at_l.
  ///
  /// In en, this message translates to:
  /// **'Sınıfını seç ve maceraya atıl.'**
  String get s_n_f_n_se_ve_maceraya_at_l;

  /// No description provided for @operasyon_zeti.
  ///
  /// In en, this message translates to:
  /// **'Operasyon Özeti'**
  String get operasyon_zeti;

  /// No description provided for @maceraya_ba_la.
  ///
  /// In en, this message translates to:
  /// **'Maceraya Başla'**
  String get maceraya_ba_la;

  /// No description provided for @krallik_kapisi.
  ///
  /// In en, this message translates to:
  /// **'Krallik Kapisi'**
  String get krallik_kapisi;

  /// No description provided for @hesabina_giris_yap_ve_lonca_gelismelerini_canli_ta.
  ///
  /// In en, this message translates to:
  /// **'Hesabina giris yap ve lonca gelismelerini canli takip et.'**
  String get hesabina_giris_yap_ve_lonca_gelismelerini_canli_ta;

  /// No description provided for @hesabin_yok_mu_kayit_ol.
  ///
  /// In en, this message translates to:
  /// **'Hesabin yok mu? Kayit Ol'**
  String get hesabin_yok_mu_kayit_ol;

  /// No description provided for @kayit.
  ///
  /// In en, this message translates to:
  /// **'Kayit'**
  String get kayit;

  /// No description provided for @giris_ekranina_don.
  ///
  /// In en, this message translates to:
  /// **'Giris Ekranina Don'**
  String get giris_ekranina_don;

  /// No description provided for @miktar.
  ///
  /// In en, this message translates to:
  /// **'Miktar:'**
  String get miktar;

  /// No description provided for @iptal.
  ///
  /// In en, this message translates to:
  /// **'Iptal'**
  String get iptal;

  /// No description provided for @onayla.
  ///
  /// In en, this message translates to:
  /// **'Onayla'**
  String get onayla;

  /// No description provided for @bankaya_aktar.
  ///
  /// In en, this message translates to:
  /// **'Bankaya Aktar'**
  String get bankaya_aktar;

  /// No description provided for @bankadan_cek.
  ///
  /// In en, this message translates to:
  /// **'Bankadan Cek'**
  String get bankadan_cek;

  /// No description provided for @banka_genisletme.
  ///
  /// In en, this message translates to:
  /// **'Banka Genisletme'**
  String get banka_genisletme;

  /// No description provided for @temizle.
  ///
  /// In en, this message translates to:
  /// **'Temizle'**
  String get temizle;

  /// No description provided for @max_slot.
  ///
  /// In en, this message translates to:
  /// **'Max Slot'**
  String get max_slot;

  /// No description provided for @banka_2.
  ///
  /// In en, this message translates to:
  /// **'🏦 Banka'**
  String get banka_2;

  /// No description provided for @sava.
  ///
  /// In en, this message translates to:
  /// **'Savaş'**
  String get sava;

  /// No description provided for @gizlilik.
  ///
  /// In en, this message translates to:
  /// **'Gizlilik'**
  String get gizlilik;

  /// No description provided for @b_y.
  ///
  /// In en, this message translates to:
  /// **'Büyü'**
  String get b_y;

  /// No description provided for @liderlik.
  ///
  /// In en, this message translates to:
  /// **'Liderlik'**
  String get liderlik;

  /// No description provided for @efsane.
  ///
  /// In en, this message translates to:
  /// **'👑 Efsane'**
  String get efsane;

  /// No description provided for @usta.
  ///
  /// In en, this message translates to:
  /// **'🔱 Usta'**
  String get usta;

  /// No description provided for @kahraman.
  ///
  /// In en, this message translates to:
  /// **'⭐ Kahraman'**
  String get kahraman;

  /// No description provided for @nl.
  ///
  /// In en, this message translates to:
  /// **'🥈 Ünlü'**
  String get nl;

  /// No description provided for @tan_nan.
  ///
  /// In en, this message translates to:
  /// **'🌱 Tanınan'**
  String get tan_nan;

  /// No description provided for @bilinmeyen.
  ///
  /// In en, this message translates to:
  /// **'🕵️ Bilinmeyen'**
  String get bilinmeyen;

  /// No description provided for @karakter_2.
  ///
  /// In en, this message translates to:
  /// **'👤 Karakter'**
  String get karakter_2;

  /// No description provided for @tekrar_dene.
  ///
  /// In en, this message translates to:
  /// **'Tekrar Dene'**
  String get tekrar_dene;

  /// No description provided for @profil_foto_raf_se.
  ///
  /// In en, this message translates to:
  /// **'Profil Fotoğrafı Seç'**
  String get profil_foto_raf_se;

  /// No description provided for @profil_foto_raf_se_2.
  ///
  /// In en, this message translates to:
  /// **'Profil fotoğrafı seç'**
  String get profil_foto_raf_se_2;

  /// No description provided for @er_eve_se.
  ///
  /// In en, this message translates to:
  /// **'Çerçeve Seç'**
  String get er_eve_se;

  /// No description provided for @profili_d_zenle.
  ///
  /// In en, this message translates to:
  /// **'Profili Düzenle'**
  String get profili_d_zenle;

  /// No description provided for @profil_foto_raf_n_de_i_tir.
  ///
  /// In en, this message translates to:
  /// **'Profil Fotoğrafını Değiştir'**
  String get profil_foto_raf_n_de_i_tir;

  /// No description provided for @er_eveyi_de_i_tir.
  ///
  /// In en, this message translates to:
  /// **'Çerçeveyi Değiştir'**
  String get er_eveyi_de_i_tir;

  /// No description provided for @g_nl_k_detox.
  ///
  /// In en, this message translates to:
  /// **'Günlük Detox'**
  String get g_nl_k_detox;

  /// No description provided for @yetenekler_adli_sicil.
  ///
  /// In en, this message translates to:
  /// **'📚 Yetenekler & Adli Sicil'**
  String get yetenekler_adli_sicil;

  /// No description provided for @yetenek_sistemi_yak_nda_g_ncellenecek.
  ///
  /// In en, this message translates to:
  /// **'Yetenek sistemi yakında güncellenecek.'**
  String get yetenek_sistemi_yak_nda_g_ncellenecek;

  /// No description provided for @susturulan_kullan_c_yok.
  ///
  /// In en, this message translates to:
  /// **'Susturulan kullanıcı yok.'**
  String get susturulan_kullan_c_yok;

  /// No description provided for @susturulanlar.
  ///
  /// In en, this message translates to:
  /// **'Susturulanlar'**
  String get susturulanlar;

  /// No description provided for @susturmay_kald_r.
  ///
  /// In en, this message translates to:
  /// **'Susturmayı Kaldır'**
  String get susturmay_kald_r;

  /// No description provided for @konu_may_sil.
  ///
  /// In en, this message translates to:
  /// **'Konuşmayı sil'**
  String get konu_may_sil;

  /// No description provided for @i_ptal.
  ///
  /// In en, this message translates to:
  /// **'İptal'**
  String get i_ptal;

  /// No description provided for @oyuncuyu_sustur.
  ///
  /// In en, this message translates to:
  /// **'Oyuncuyu sustur'**
  String get oyuncuyu_sustur;

  /// No description provided for @uygula.
  ///
  /// In en, this message translates to:
  /// **'Uygula'**
  String get uygula;

  /// No description provided for @moderator_atama.
  ///
  /// In en, this message translates to:
  /// **'Moderator Atama'**
  String get moderator_atama;

  /// No description provided for @sohbet_eri_imi_k_s_tland.
  ///
  /// In en, this message translates to:
  /// **'Sohbet Erişimi Kısıtlandı'**
  String get sohbet_eri_imi_k_s_tland;

  /// No description provided for @filtre_y_netimi.
  ///
  /// In en, this message translates to:
  /// **'Filtre Yönetimi'**
  String get filtre_y_netimi;

  /// No description provided for @filtrelenecek_kelime.
  ///
  /// In en, this message translates to:
  /// **'Filtrelenecek kelime'**
  String get filtrelenecek_kelime;

  /// No description provided for @yerine_konan.
  ///
  /// In en, this message translates to:
  /// **'Yerine konan'**
  String get yerine_konan;

  /// No description provided for @ekle.
  ///
  /// In en, this message translates to:
  /// **'Ekle'**
  String get ekle;

  /// No description provided for @sohbet_mesajla_ma.
  ///
  /// In en, this message translates to:
  /// **'Sohbet & Mesajlaşma'**
  String get sohbet_mesajla_ma;

  /// No description provided for @oyuncu_ad_ile_ara.
  ///
  /// In en, this message translates to:
  /// **'Oyuncu adı ile ara...'**
  String get oyuncu_ad_ile_ara;

  /// No description provided for @hen_z_sohbet_yok.
  ///
  /// In en, this message translates to:
  /// **'Henüz sohbet yok'**
  String get hen_z_sohbet_yok;

  /// No description provided for @oyuncu_arayarak_mesaj_ba_lat.
  ///
  /// In en, this message translates to:
  /// **'Oyuncu arayarak mesaj başlat'**
  String get oyuncu_arayarak_mesaj_ba_lat;

  /// No description provided for @mesajlar_y_kleniyor.
  ///
  /// In en, this message translates to:
  /// **'Mesajlar yükleniyor...'**
  String get mesajlar_y_kleniyor;

  /// No description provided for @hen_z_mesaj_yok.
  ///
  /// In en, this message translates to:
  /// **'Henüz mesaj yok'**
  String get hen_z_mesaj_yok;

  /// No description provided for @konu_may_ba_latmak_i_in_bir_mesaj_yaz.
  ///
  /// In en, this message translates to:
  /// **'Konuşmayı başlatmak için bir mesaj yaz'**
  String get konu_may_ba_latmak_i_in_bir_mesaj_yaz;

  /// No description provided for @sohbet_se_enekleri.
  ///
  /// In en, this message translates to:
  /// **'Sohbet seçenekleri'**
  String get sohbet_se_enekleri;

  /// No description provided for @retim_at_lyesi.
  ///
  /// In en, this message translates to:
  /// **'🔨 Üretim Atölyesi'**
  String get retim_at_lyesi;

  /// No description provided for @bu_kategoride_tarif_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Bu kategoride tarif bulunamadı.'**
  String get bu_kategoride_tarif_bulunamad;

  /// No description provided for @bir_tarif_se_in.
  ///
  /// In en, this message translates to:
  /// **'Bir tarif seçin'**
  String get bir_tarif_se_in;

  /// No description provided for @retim_n_i_zlemesi.
  ///
  /// In en, this message translates to:
  /// **'Üretim Ön İzlemesi'**
  String get retim_n_i_zlemesi;

  /// No description provided for @retilecek_malzeme.
  ///
  /// In en, this message translates to:
  /// **'Üretilecek Malzeme'**
  String get retilecek_malzeme;

  /// No description provided for @gerekli_malzemeler.
  ///
  /// In en, this message translates to:
  /// **'Gerekli Malzemeler'**
  String get gerekli_malzemeler;

  /// No description provided for @batch_say_s.
  ///
  /// In en, this message translates to:
  /// **'Batch Sayısı'**
  String get batch_say_s;

  /// No description provided for @max_5.
  ///
  /// In en, this message translates to:
  /// **'Max: 5'**
  String get max_5;

  /// No description provided for @malzeme_yok.
  ///
  /// In en, this message translates to:
  /// **'⚠ Malzeme yok'**
  String get malzeme_yok;

  /// No description provided for @retim_i_ptal_et.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Üretim İptal Et?'**
  String get retim_i_ptal_et;

  /// No description provided for @bu_i_lem_geri_al_namaz_d_l_geri_verilmeyecektir.
  ///
  /// In en, this message translates to:
  /// **'Bu işlem geri alınamaz. Ödül geri verilmeyecektir!'**
  String get bu_i_lem_geri_al_namaz_d_l_geri_verilmeyecektir;

  /// No description provided for @vazge.
  ///
  /// In en, this message translates to:
  /// **'Vazgeç'**
  String get vazge;

  /// No description provided for @evet_i_ptal_et.
  ///
  /// In en, this message translates to:
  /// **'Evet, İptal Et'**
  String get evet_i_ptal_et;

  /// No description provided for @talep_edildi.
  ///
  /// In en, this message translates to:
  /// **'✓ Talep Edildi'**
  String get talep_edildi;

  /// No description provided for @tamamlan_yor.
  ///
  /// In en, this message translates to:
  /// **'Tamamlanıyor...'**
  String get tamamlan_yor;

  /// No description provided for @retiliyor.
  ///
  /// In en, this message translates to:
  /// **'Üretiliyor...'**
  String get retiliyor;

  /// No description provided for @zindana_sald_rmak_i_in_butona_bas.
  ///
  /// In en, this message translates to:
  /// **'Zindana saldırmak için butona bas.'**
  String get zindana_sald_rmak_i_in_butona_bas;

  /// No description provided for @sald_r_2.
  ///
  /// In en, this message translates to:
  /// **'Saldır'**
  String get sald_r_2;

  /// No description provided for @geri_d_n.
  ///
  /// In en, this message translates to:
  /// **'← Geri Dön'**
  String get geri_d_n;

  /// No description provided for @haz_rlan.
  ///
  /// In en, this message translates to:
  /// **'Hazırlan...'**
  String get haz_rlan;

  /// No description provided for @sava_devam_ediyor.
  ///
  /// In en, this message translates to:
  /// **'Savaş devam ediyor…'**
  String get sava_devam_ediyor;

  /// No description provided for @zindanlara_d_n.
  ///
  /// In en, this message translates to:
  /// **'Zindanlara Dön'**
  String get zindanlara_d_n;

  /// No description provided for @i_lk_2_d_te_cretsiz_taburcu_hakk_n_var.
  ///
  /// In en, this message translates to:
  /// **'İlk 2 düşüşte ücretsiz taburcu hakkın var.'**
  String get i_lk_2_d_te_cretsiz_taburcu_hakk_n_var;

  /// No description provided for @geri_d_n_2.
  ///
  /// In en, this message translates to:
  /// **'Geri Dön'**
  String get geri_d_n_2;

  /// No description provided for @i_lk_ge_i_bonus_d_l_arpan_aktif.
  ///
  /// In en, this message translates to:
  /// **'İLK GEÇİŞ — Bonus ödül çarpanı aktif!'**
  String get i_lk_ge_i_bonus_d_l_arpan_aktif;

  /// No description provided for @kri_ti_k_zafer_50_alt_n_ve_xp.
  ///
  /// In en, this message translates to:
  /// **'KRİTİK ZAFER! +50% altın ve XP'**
  String get kri_ti_k_zafer_50_alt_n_ve_xp;

  /// No description provided for @d_en_e_yalar.
  ///
  /// In en, this message translates to:
  /// **'DÜŞEN EŞYALAR'**
  String get d_en_e_yalar;

  /// No description provided for @ki_lometre_ta_i_d_l.
  ///
  /// In en, this message translates to:
  /// **'KİLOMETRE TAŞI ÖDÜLÜ'**
  String get ki_lometre_ta_i_d_l;

  /// No description provided for @altin.
  ///
  /// In en, this message translates to:
  /// **'ALTIN'**
  String get altin;

  /// No description provided for @e_ya.
  ///
  /// In en, this message translates to:
  /// **'EŞYA'**
  String get e_ya;

  /// No description provided for @hastanedesin.
  ///
  /// In en, this message translates to:
  /// **'Hastanedesin'**
  String get hastanedesin;

  /// No description provided for @hastaneye_git.
  ///
  /// In en, this message translates to:
  /// **'Hastaneye Git'**
  String get hastaneye_git;

  /// No description provided for @g_kar_ila_tirma.
  ///
  /// In en, this message translates to:
  /// **'GÜÇ KARŞILAŞTIRMA'**
  String get g_kar_ila_tirma;

  /// No description provided for @loot.
  ///
  /// In en, this message translates to:
  /// **'Loot'**
  String get loot;

  /// No description provided for @zindan_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Zindan bulunamadı.'**
  String get zindan_bulunamad;

  /// No description provided for @sava_aki_i.
  ///
  /// In en, this message translates to:
  /// **'SAVAŞ AKIŞI'**
  String get sava_aki_i;

  /// No description provided for @ptal.
  ///
  /// In en, this message translates to:
  /// **'ptal'**
  String get ptal;

  /// No description provided for @tamam.
  ///
  /// In en, this message translates to:
  /// **'Tamam'**
  String get tamam;

  /// No description provided for @hastane_2.
  ///
  /// In en, this message translates to:
  /// **'🏥 Hastane'**
  String get hastane_2;

  /// No description provided for @d_l_nizlemesi.
  ///
  /// In en, this message translates to:
  /// **'Ödül Önizlemesi'**
  String get d_l_nizlemesi;

  /// No description provided for @bu_zindan_i_in_loot_bilgisi_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Bu zindan için loot bilgisi bulunamadı.'**
  String get bu_zindan_i_in_loot_bilgisi_bulunamad;

  /// No description provided for @g_lendirme.
  ///
  /// In en, this message translates to:
  /// **'🔥 Güçlendirme'**
  String get g_lendirme;

  /// No description provided for @g_lendirme_yuvalar.
  ///
  /// In en, this message translates to:
  /// **'Güçlendirme Yuvaları'**
  String get g_lendirme_yuvalar;

  /// No description provided for @e_ya_2.
  ///
  /// In en, this message translates to:
  /// **'Eşya'**
  String get e_ya_2;

  /// No description provided for @rune.
  ///
  /// In en, this message translates to:
  /// **'Rune'**
  String get rune;

  /// No description provided for @par_men_9.
  ///
  /// In en, this message translates to:
  /// **'Parşömen (9)'**
  String get par_men_9;

  /// No description provided for @nizleme.
  ///
  /// In en, this message translates to:
  /// **'Önizleme'**
  String get nizleme;

  /// No description provided for @b_rak.
  ///
  /// In en, this message translates to:
  /// **'Bırak'**
  String get b_rak;

  /// No description provided for @g_lendirme_bilgisi.
  ///
  /// In en, this message translates to:
  /// **'Güçlendirme Bilgisi'**
  String get g_lendirme_bilgisi;

  /// No description provided for @g_lendirme_tablosu.
  ///
  /// In en, this message translates to:
  /// **'Güçlendirme Tablosu'**
  String get g_lendirme_tablosu;

  /// No description provided for @envanter_izgaras.
  ///
  /// In en, this message translates to:
  /// **'Envanter Izgarası'**
  String get envanter_izgaras;

  /// No description provided for @s_r_kle_b_rak_aktif.
  ///
  /// In en, this message translates to:
  /// **'Sürükle-bırak aktif'**
  String get s_r_kle_b_rak_aktif;

  /// No description provided for @envanter_y_kleniyor.
  ///
  /// In en, this message translates to:
  /// **'Envanter yükleniyor...'**
  String get envanter_y_kleniyor;

  /// No description provided for @e_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Öğe bulunamadı'**
  String get e_bulunamad;

  /// No description provided for @tier_1_ba_lang.
  ///
  /// In en, this message translates to:
  /// **'🏚️ Tier 1 — Başlangıç'**
  String get tier_1_ba_lang;

  /// No description provided for @tier_2_geli_mi.
  ///
  /// In en, this message translates to:
  /// **'🏗️ Tier 2 — Gelişmiş'**
  String get tier_2_geli_mi;

  /// No description provided for @tier_3_i_leri.
  ///
  /// In en, this message translates to:
  /// **'🏰 Tier 3 — İleri'**
  String get tier_3_i_leri;

  /// No description provided for @tesis_a.
  ///
  /// In en, this message translates to:
  /// **'Tesis Ağı'**
  String get tesis_a;

  /// No description provided for @cezaevi_operasyonlar_kilitli.
  ///
  /// In en, this message translates to:
  /// **'Cezaevi — operasyonlar kilitli'**
  String get cezaevi_operasyonlar_kilitli;

  /// No description provided for @phe.
  ///
  /// In en, this message translates to:
  /// **'🕵️ Şüphe'**
  String get phe;

  /// No description provided for @r_vet.
  ///
  /// In en, this message translates to:
  /// **'💎 Rüşvet'**
  String get r_vet;

  /// No description provided for @genel.
  ///
  /// In en, this message translates to:
  /// **'Genel'**
  String get genel;

  /// No description provided for @depo.
  ///
  /// In en, this message translates to:
  /// **'Depo'**
  String get depo;

  /// No description provided for @y_kseltme_i_in_nce_retimi_bitirin.
  ///
  /// In en, this message translates to:
  /// **'Yükseltme için önce üretimi bitirin.'**
  String get y_kseltme_i_in_nce_retimi_bitirin;

  /// No description provided for @retim_ba_lat_nca_depo_dolacak.
  ///
  /// In en, this message translates to:
  /// **'Üretim başlatınca depo dolacak.'**
  String get retim_ba_lat_nca_depo_dolacak;

  /// No description provided for @i_iler_retiyor.
  ///
  /// In en, this message translates to:
  /// **'İşçiler üretiyor…'**
  String get i_iler_retiyor;

  /// No description provided for @mevcut_seviye.
  ///
  /// In en, this message translates to:
  /// **'Mevcut Seviye'**
  String get mevcut_seviye;

  /// No description provided for @tesis_a_2.
  ///
  /// In en, this message translates to:
  /// **'Tesis Aç'**
  String get tesis_a_2;

  /// No description provided for @r_vet_2.
  ///
  /// In en, this message translates to:
  /// **'Rüşvet'**
  String get r_vet_2;

  /// No description provided for @y_kselt.
  ///
  /// In en, this message translates to:
  /// **'Yükselt'**
  String get y_kselt;

  /// No description provided for @tesisler_y_klenemedi.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Tesisler yüklenemedi'**
  String get tesisler_y_klenemedi;

  /// No description provided for @retim_aktif.
  ///
  /// In en, this message translates to:
  /// **'Üretim aktif'**
  String get retim_aktif;

  /// No description provided for @retim_hatt.
  ///
  /// In en, this message translates to:
  /// **'Üretim Hattı'**
  String get retim_hatt;

  /// No description provided for @geri_ile_tesis_listesine_d_n.
  ///
  /// In en, this message translates to:
  /// **'← Geri ile tesis listesine dön'**
  String get geri_ile_tesis_listesine_d_n;

  /// No description provided for @elindekini_yaz.
  ///
  /// In en, this message translates to:
  /// **'Elindekini yaz'**
  String get elindekini_yaz;

  /// No description provided for @an_ta_ba_yap.
  ///
  /// In en, this message translates to:
  /// **'Anıta Bağış Yap'**
  String get an_ta_ba_yap;

  /// No description provided for @lonca_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Lonca bulunamadı'**
  String get lonca_bulunamad;

  /// No description provided for @lonca_bul.
  ///
  /// In en, this message translates to:
  /// **'Lonca Bul'**
  String get lonca_bul;

  /// No description provided for @her_kayna_ayr_ba_layabilirsin_d_rt_alan_doldurman.
  ///
  /// In en, this message translates to:
  /// **'Her kaynağı ayrı bağışlayabilirsin. Dört alanı doldurman gerekmez — elinde ne varsa onu gönder.'**
  String get her_kayna_ayr_ba_layabilirsin_d_rt_alan_doldurman;

  /// No description provided for @lonca_an_t.
  ///
  /// In en, this message translates to:
  /// **'🏛️ Lonca Anıtı'**
  String get lonca_an_t;

  /// No description provided for @bir_loncaya_ye_de_ilsiniz.
  ///
  /// In en, this message translates to:
  /// **'Bir Loncaya Üye Değilsiniz'**
  String get bir_loncaya_ye_de_ilsiniz;

  /// No description provided for @an_t_maksimum_seviyede_lv_100.
  ///
  /// In en, this message translates to:
  /// **'Anıt maksimum seviyede (Lv.100).'**
  String get an_t_maksimum_seviyede_lv_100;

  /// No description provided for @elinde_olan_kaynaklar_tek_tek_ba_layabilirsin_her.
  ///
  /// In en, this message translates to:
  /// **'Elinde olan kaynakları tek tek bağışlayabilirsin. Her satırdaki miktar, bugünkü limit ve stok birleşimidir.'**
  String get elinde_olan_kaynaklar_tek_tek_ba_layabilirsin_her;

  /// No description provided for @yap_sal_kaynak.
  ///
  /// In en, this message translates to:
  /// **'Yapısal Kaynak'**
  String get yap_sal_kaynak;

  /// No description provided for @mistik_kaynak.
  ///
  /// In en, this message translates to:
  /// **'Mistik Kaynak'**
  String get mistik_kaynak;

  /// No description provided for @kritik_kaynak.
  ///
  /// In en, this message translates to:
  /// **'Kritik Kaynak'**
  String get kritik_kaynak;

  /// No description provided for @alt_n_havuzu.
  ///
  /// In en, this message translates to:
  /// **'Altın Havuzu'**
  String get alt_n_havuzu;

  /// No description provided for @hen_z_katk_kayd_bulunmuyor.
  ///
  /// In en, this message translates to:
  /// **'Henüz katkı kaydı bulunmuyor.'**
  String get hen_z_katk_kayd_bulunmuyor;

  /// No description provided for @lonca_yelerinin_g_lerini_birle_tirerek_y_kseltti_i.
  ///
  /// In en, this message translates to:
  /// **'Lonca üyelerinin güçlerini birleştirerek yükselttiği kutsal yapı.'**
  String get lonca_yelerinin_g_lerini_birle_tirerek_y_kseltti_i;

  /// No description provided for @ba_yap.
  ///
  /// In en, this message translates to:
  /// **'Bağış Yap'**
  String get ba_yap;

  /// No description provided for @loncadan_ayr_l.
  ///
  /// In en, this message translates to:
  /// **'Loncadan Ayrıl'**
  String get loncadan_ayr_l;

  /// No description provided for @loncadan_ayr_lmak_istedi_inize_emin_misiniz.
  ///
  /// In en, this message translates to:
  /// **'Loncadan ayrılmak istediğinize emin misiniz?'**
  String get loncadan_ayr_lmak_istedi_inize_emin_misiniz;

  /// No description provided for @ayr_l.
  ///
  /// In en, this message translates to:
  /// **'Ayrıl'**
  String get ayr_l;

  /// No description provided for @loncay_da_t.
  ///
  /// In en, this message translates to:
  /// **'Loncayı Dağıt'**
  String get loncay_da_t;

  /// No description provided for @loncay_da_tmak_t_m_yeleri_kar_r_ve_an_t_ilerlemesi.
  ///
  /// In en, this message translates to:
  /// **'Loncayı dağıtmak tüm üyeleri çıkarır ve anıt ilerlemesini siler. Emin misiniz?'**
  String get loncay_da_tmak_t_m_yeleri_kar_r_ve_an_t_ilerlemesi;

  /// No description provided for @da_t.
  ///
  /// In en, this message translates to:
  /// **'Dağıt'**
  String get da_t;

  /// No description provided for @lonca_kur.
  ///
  /// In en, this message translates to:
  /// **'Lonca Kur'**
  String get lonca_kur;

  /// No description provided for @kur_10m_alt_n.
  ///
  /// In en, this message translates to:
  /// **'Kur (10M Altın)'**
  String get kur_10m_alt_n;

  /// No description provided for @kat_l_m_g_limiti.
  ///
  /// In en, this message translates to:
  /// **'Katılım Güç Limiti'**
  String get kat_l_m_g_limiti;

  /// No description provided for @s_0_limit_yok_yeni_yeler_bu_g_c_n_alt_ndaysa_kat_lam.
  ///
  /// In en, this message translates to:
  /// **'0 = limit yok. Yeni üyeler bu gücün altındaysa katılamaz.'**
  String get s_0_limit_yok_yeni_yeler_bu_g_c_n_alt_ndaysa_kat_lam;

  /// No description provided for @kaydet.
  ///
  /// In en, this message translates to:
  /// **'Kaydet'**
  String get kaydet;

  /// No description provided for @subay_yap.
  ///
  /// In en, this message translates to:
  /// **'Subay Yap'**
  String get subay_yap;

  /// No description provided for @ye_yap.
  ///
  /// In en, this message translates to:
  /// **'Üye Yap'**
  String get ye_yap;

  /// No description provided for @loncadan_at.
  ///
  /// In en, this message translates to:
  /// **'Loncadan At'**
  String get loncadan_at;

  /// No description provided for @hen_z_bir_loncaya_ye_de_ilsiniz.
  ///
  /// In en, this message translates to:
  /// **'Henüz bir loncaya üye değilsiniz.'**
  String get hen_z_bir_loncaya_ye_de_ilsiniz;

  /// No description provided for @lonca_ara.
  ///
  /// In en, this message translates to:
  /// **'Lonca ara...'**
  String get lonca_ara;

  /// No description provided for @sonu_lar.
  ///
  /// In en, this message translates to:
  /// **'Sonuçlar'**
  String get sonu_lar;

  /// No description provided for @araman_zla_e_le_en_lonca_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Aramanızla eşleşen lonca bulunamadı.'**
  String get araman_zla_e_le_en_lonca_bulunamad;

  /// No description provided for @nerilen_loncalar.
  ///
  /// In en, this message translates to:
  /// **'Önerilen Loncalar'**
  String get nerilen_loncalar;

  /// No description provided for @kat_labilece_iniz_yer_a_k_loncalar.
  ///
  /// In en, this message translates to:
  /// **'Katılabileceğiniz, yer açık loncalar'**
  String get kat_labilece_iniz_yer_a_k_loncalar;

  /// No description provided for @kat_l.
  ///
  /// In en, this message translates to:
  /// **'Katıl'**
  String get kat_l;

  /// No description provided for @yeler.
  ///
  /// In en, this message translates to:
  /// **'Üyeler'**
  String get yeler;

  /// No description provided for @ben.
  ///
  /// In en, this message translates to:
  /// **' (Ben)'**
  String get ben;

  /// No description provided for @an_t_y_klenemedi.
  ///
  /// In en, this message translates to:
  /// **'Anıt yüklenemedi'**
  String get an_t_y_klenemedi;

  /// No description provided for @geri.
  ///
  /// In en, this message translates to:
  /// **'Geri'**
  String get geri;

  /// No description provided for @sald_r_g_c.
  ///
  /// In en, this message translates to:
  /// **'Saldırı Gücü'**
  String get sald_r_g_c;

  /// No description provided for @savunma_g_c.
  ///
  /// In en, this message translates to:
  /// **'Savunma Gücü'**
  String get savunma_g_c;

  /// No description provided for @kazan_lan_puan.
  ///
  /// In en, this message translates to:
  /// **'Kazanılan Puan'**
  String get kazan_lan_puan;

  /// No description provided for @devam.
  ///
  /// In en, this message translates to:
  /// **'Devam'**
  String get devam;

  /// No description provided for @savunma_ekle.
  ///
  /// In en, this message translates to:
  /// **'🛡 Savunma Ekle'**
  String get savunma_ekle;

  /// No description provided for @s_1_elmas_10_savunma_g_c.
  ///
  /// In en, this message translates to:
  /// **'1 Elmas = 10 Savunma Gücü'**
  String get s_1_elmas_10_savunma_g_c;

  /// No description provided for @savunma_ekle_2.
  ///
  /// In en, this message translates to:
  /// **'Savunma Ekle'**
  String get savunma_ekle_2;

  /// No description provided for @b_lge_sald_r_s.
  ///
  /// In en, this message translates to:
  /// **'⚔ Bölge Saldırısı'**
  String get b_lge_sald_r_s;

  /// No description provided for @lonca_sava_2.
  ///
  /// In en, this message translates to:
  /// **'⚔ Lonca Savaşı'**
  String get lonca_sava_2;

  /// No description provided for @sava_kay_tlar.
  ///
  /// In en, this message translates to:
  /// **'Savaş Kayıtları'**
  String get sava_kay_tlar;

  /// No description provided for @aktif_turnuvalar.
  ///
  /// In en, this message translates to:
  /// **'Aktif Turnuvalar'**
  String get aktif_turnuvalar;

  /// No description provided for @loncan_kaydet_d_l_havuzundan_pay_al.
  ///
  /// In en, this message translates to:
  /// **'Loncanı kaydet, ödül havuzundan pay al'**
  String get loncan_kaydet_d_l_havuzundan_pay_al;

  /// No description provided for @harita.
  ///
  /// In en, this message translates to:
  /// **'Harita'**
  String get harita;

  /// No description provided for @liste.
  ///
  /// In en, this message translates to:
  /// **'Liste'**
  String get liste;

  /// No description provided for @b_lge_listesi.
  ///
  /// In en, this message translates to:
  /// **'Bölge Listesi'**
  String get b_lge_listesi;

  /// No description provided for @sald_r_veya_savunma_g_lendir.
  ///
  /// In en, this message translates to:
  /// **'Saldır veya savunma güçlendir'**
  String get sald_r_veya_savunma_g_lendir;

  /// No description provided for @loncaya_ye_de_ilsin.
  ///
  /// In en, this message translates to:
  /// **'Loncaya üye değilsin'**
  String get loncaya_ye_de_ilsin;

  /// No description provided for @sava_a_kat_lmak_ve_b_lge_ele_ge_irmek_i_in_bir_lon.
  ///
  /// In en, this message translates to:
  /// **'Savaşa katılmak ve bölge ele geçirmek için bir loncaya katıl.'**
  String get sava_a_kat_lmak_ve_b_lge_ele_ge_irmek_i_in_bir_lon;

  /// No description provided for @veri_y_klenemedi_a_a_ekerek_yenile.
  ///
  /// In en, this message translates to:
  /// **'Veri yüklenemedi. Aşağı çekerek yenile.'**
  String get veri_y_klenemedi_a_a_ekerek_yenile;

  /// No description provided for @sald_r_3.
  ///
  /// In en, this message translates to:
  /// **'⚔ Saldır'**
  String get sald_r_3;

  /// No description provided for @b_lge_detay.
  ///
  /// In en, this message translates to:
  /// **'🗺 Bölge Detay'**
  String get b_lge_detay;

  /// No description provided for @b_lge_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Bölge bulunamadı'**
  String get b_lge_bulunamad;

  /// No description provided for @bu_b_lge_haritada_art_k_yok_veya_veri_y_klenemedi.
  ///
  /// In en, this message translates to:
  /// **'Bu bölge haritada artık yok veya veri yüklenemedi. Lonca Savaşı merkezinden haritaya dönebilirsin.'**
  String get bu_b_lge_haritada_art_k_yok_veya_veri_y_klenemedi;

  /// No description provided for @trade_geliri.
  ///
  /// In en, this message translates to:
  /// **'Trade Geliri'**
  String get trade_geliri;

  /// No description provided for @d_l.
  ///
  /// In en, this message translates to:
  /// **'Ödül'**
  String get d_l;

  /// No description provided for @savunma_hatt.
  ///
  /// In en, this message translates to:
  /// **'Savunma Hattı'**
  String get savunma_hatt;

  /// No description provided for @son_sald_r_lar.
  ///
  /// In en, this message translates to:
  /// **'Son Saldırılar'**
  String get son_sald_r_lar;

  /// No description provided for @turnuva_detay.
  ///
  /// In en, this message translates to:
  /// **'🏆 Turnuva Detay'**
  String get turnuva_detay;

  /// No description provided for @turnuva_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Turnuva bulunamadı'**
  String get turnuva_bulunamad;

  /// No description provided for @bu_turnuva_silinmi_veya_art_k_mevcut_de_il_lonca_s.
  ///
  /// In en, this message translates to:
  /// **'Bu turnuva silinmiş veya artık mevcut değil. Lonca Savaşı merkezinden aktif turnuvalara bakabilirsin.'**
  String get bu_turnuva_silinmi_veya_art_k_mevcut_de_il_lonca_s;

  /// No description provided for @kat_l_mc_lar.
  ///
  /// In en, this message translates to:
  /// **'Katılımcılar'**
  String get kat_l_mc_lar;

  /// No description provided for @e_le_meler.
  ///
  /// In en, this message translates to:
  /// **'Eşleşmeler'**
  String get e_le_meler;

  /// No description provided for @vs.
  ///
  /// In en, this message translates to:
  /// **' VS '**
  String get vs;

  /// No description provided for @turnuvaya_kat_l.
  ///
  /// In en, this message translates to:
  /// **'Turnuvaya Katıl'**
  String get turnuvaya_kat_l;

  /// No description provided for @sava_kay_tlar_2.
  ///
  /// In en, this message translates to:
  /// **'📜 Savaş Kayıtları'**
  String get sava_kay_tlar_2;

  /// No description provided for @sava_g_nl.
  ///
  /// In en, this message translates to:
  /// **'Savaş Günlüğü'**
  String get sava_g_nl;

  /// No description provided for @son_sald_r_kay_tlar.
  ///
  /// In en, this message translates to:
  /// **'Son saldırı kayıtları'**
  String get son_sald_r_kay_tlar;

  /// No description provided for @saldir.
  ///
  /// In en, this message translates to:
  /// **'SALDIR'**
  String get saldir;

  /// No description provided for @savunma_ekle_3.
  ///
  /// In en, this message translates to:
  /// **'SAVUNMA EKLE'**
  String get savunma_ekle_3;

  /// No description provided for @lonca_sava_i.
  ///
  /// In en, this message translates to:
  /// **'LONCA SAVAŞI'**
  String get lonca_sava_i;

  /// No description provided for @krall_k_se_imi.
  ///
  /// In en, this message translates to:
  /// **'Krallık Seçimi'**
  String get krall_k_se_imi;

  /// No description provided for @krall_k.
  ///
  /// In en, this message translates to:
  /// **'Krallık'**
  String get krall_k;

  /// No description provided for @aday_loncalar.
  ///
  /// In en, this message translates to:
  /// **'Aday loncalar'**
  String get aday_loncalar;

  /// No description provided for @kral.
  ///
  /// In en, this message translates to:
  /// **'Kral'**
  String get kral;

  /// No description provided for @oy_ver.
  ///
  /// In en, this message translates to:
  /// **'Oy Ver'**
  String get oy_ver;

  /// No description provided for @hret_s_ralamas.
  ///
  /// In en, this message translates to:
  /// **'Şöhret Sıralaması'**
  String get hret_s_ralamas;

  /// No description provided for @sezon_puanlar_na_g_re_en_g_l_loncalar.
  ///
  /// In en, this message translates to:
  /// **'Sezon puanlarına göre en güçlü loncalar'**
  String get sezon_puanlar_na_g_re_en_g_l_loncalar;

  /// No description provided for @senin.
  ///
  /// In en, this message translates to:
  /// **'Senin'**
  String get senin;

  /// No description provided for @sava_haritas.
  ///
  /// In en, this message translates to:
  /// **'Savaş Haritası'**
  String get sava_haritas;

  /// No description provided for @b_lgeye_dokunarak_detaylar_g_r.
  ///
  /// In en, this message translates to:
  /// **'Bölgeye dokunarak detayları gör'**
  String get b_lgeye_dokunarak_detaylar_g_r;

  /// No description provided for @senin_loncan.
  ///
  /// In en, this message translates to:
  /// **'Senin loncan'**
  String get senin_loncan;

  /// No description provided for @di_er.
  ///
  /// In en, this message translates to:
  /// **'Diğer'**
  String get di_er;

  /// No description provided for @sahipsiz.
  ///
  /// In en, this message translates to:
  /// **'Sahipsiz'**
  String get sahipsiz;

  /// No description provided for @detay.
  ///
  /// In en, this message translates to:
  /// **'Detay'**
  String get detay;

  /// No description provided for @i_ksir_kullan.
  ///
  /// In en, this message translates to:
  /// **'🧪 İksir Kullan'**
  String get i_ksir_kullan;

  /// No description provided for @envanterde_iksir_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Envanterde iksir bulunamadı'**
  String get envanterde_iksir_bulunamad;

  /// No description provided for @kullan.
  ///
  /// In en, this message translates to:
  /// **'Kullan'**
  String get kullan;

  /// No description provided for @kasa_a.
  ///
  /// In en, this message translates to:
  /// **'KASA AÇ'**
  String get kasa_a;

  /// No description provided for @s_n_rl_bir_s_re_i_in_nefsanevi_hediyeler_seni_bekl.
  ///
  /// In en, this message translates to:
  /// **'Sınırlı bir süre için.\\nEfsanevi hediyeler seni bekliyor.'**
  String get s_n_rl_bir_s_re_i_in_nefsanevi_hediyeler_seni_bekl;

  /// No description provided for @s_500_ile_a.
  ///
  /// In en, this message translates to:
  /// **'500 ile Aç'**
  String get s_500_ile_a;

  /// No description provided for @enerji.
  ///
  /// In en, this message translates to:
  /// **'ENERJİ'**
  String get enerji;

  /// No description provided for @tolerans.
  ///
  /// In en, this message translates to:
  /// **'TOLERANS'**
  String get tolerans;

  /// No description provided for @i_ti_bar.
  ///
  /// In en, this message translates to:
  /// **'İTİBAR'**
  String get i_ti_bar;

  /// No description provided for @koparma.
  ///
  /// In en, this message translates to:
  /// **'Koparma'**
  String get koparma;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get market;

  /// No description provided for @geli_tirme.
  ///
  /// In en, this message translates to:
  /// **'Geliştirme'**
  String get geli_tirme;

  /// No description provided for @demir_madeni.
  ///
  /// In en, this message translates to:
  /// **'Demir Madeni'**
  String get demir_madeni;

  /// No description provided for @karanl_k_orman_temizle.
  ///
  /// In en, this message translates to:
  /// **'Karanlık Orman\\\'ı Temizle'**
  String get karanl_k_orman_temizle;

  /// No description provided for @s_5_i_ksir_kullan.
  ///
  /// In en, this message translates to:
  /// **'5 İksir Kullan'**
  String get s_5_i_ksir_kullan;

  /// No description provided for @i_ksir_kullan_2.
  ///
  /// In en, this message translates to:
  /// **'İksir Kullan'**
  String get i_ksir_kullan_2;

  /// No description provided for @te_hizat.
  ///
  /// In en, this message translates to:
  /// **'Teçhizat'**
  String get te_hizat;

  /// No description provided for @tesis.
  ///
  /// In en, this message translates to:
  /// **'Tesis'**
  String get tesis;

  /// No description provided for @sezon.
  ///
  /// In en, this message translates to:
  /// **'Sezon'**
  String get sezon;

  /// No description provided for @acemi.
  ///
  /// In en, this message translates to:
  /// **'Acemi'**
  String get acemi;

  /// No description provided for @tan_nan_2.
  ///
  /// In en, this message translates to:
  /// **'Tanınan'**
  String get tan_nan_2;

  /// No description provided for @sayg_n.
  ///
  /// In en, this message translates to:
  /// **'Saygın'**
  String get sayg_n;

  /// No description provided for @nl_2.
  ///
  /// In en, this message translates to:
  /// **'Ünlü'**
  String get nl_2;

  /// No description provided for @efsanevi.
  ///
  /// In en, this message translates to:
  /// **'Efsanevi'**
  String get efsanevi;

  /// No description provided for @destans.
  ///
  /// In en, this message translates to:
  /// **'Destansı'**
  String get destans;

  /// No description provided for @i_mparator.
  ///
  /// In en, this message translates to:
  /// **'İmparator'**
  String get i_mparator;

  /// No description provided for @silah.
  ///
  /// In en, this message translates to:
  /// **'Silah'**
  String get silah;

  /// No description provided for @kask.
  ///
  /// In en, this message translates to:
  /// **'Kask'**
  String get kask;

  /// No description provided for @z_rh.
  ///
  /// In en, this message translates to:
  /// **'Zırh'**
  String get z_rh;

  /// No description provided for @eldiven.
  ///
  /// In en, this message translates to:
  /// **'Eldiven'**
  String get eldiven;

  /// No description provided for @ayakkab.
  ///
  /// In en, this message translates to:
  /// **'Ayakkabı'**
  String get ayakkab;

  /// No description provided for @aksesuar.
  ///
  /// In en, this message translates to:
  /// **'Aksesuar'**
  String get aksesuar;

  /// No description provided for @siralama.
  ///
  /// In en, this message translates to:
  /// **'Siralama'**
  String get siralama;

  /// No description provided for @guc_liderleri_canli.
  ///
  /// In en, this message translates to:
  /// **'Guc liderleri • canli'**
  String get guc_liderleri_canli;

  /// No description provided for @tumu.
  ///
  /// In en, this message translates to:
  /// **'Tumu'**
  String get tumu;

  /// No description provided for @tekrar_dene_2.
  ///
  /// In en, this message translates to:
  /// **'Tekrar dene'**
  String get tekrar_dene_2;

  /// No description provided for @henuz_siralama_verisi_yok.
  ///
  /// In en, this message translates to:
  /// **'Henuz siralama verisi yok.'**
  String get henuz_siralama_verisi_yok;

  /// No description provided for @sira.
  ///
  /// In en, this message translates to:
  /// **'Sira'**
  String get sira;

  /// No description provided for @hemen_g_len.
  ///
  /// In en, this message translates to:
  /// **'Hemen Güçlen'**
  String get hemen_g_len;

  /// No description provided for @canli_yaris.
  ///
  /// In en, this message translates to:
  /// **'Canli Yaris'**
  String get canli_yaris;

  /// No description provided for @bahis_yap.
  ///
  /// In en, this message translates to:
  /// **'Bahis Yap'**
  String get bahis_yap;

  /// No description provided for @son_kazananlar.
  ///
  /// In en, this message translates to:
  /// **'Son Kazananlar'**
  String get son_kazananlar;

  /// No description provided for @kazandin.
  ///
  /// In en, this message translates to:
  /// **'Kazandin'**
  String get kazandin;

  /// No description provided for @bahis_yok.
  ///
  /// In en, this message translates to:
  /// **'Bahis yok'**
  String get bahis_yok;

  /// No description provided for @kaybettin.
  ///
  /// In en, this message translates to:
  /// **'Kaybettin'**
  String get kaybettin;

  /// No description provided for @cretsiz_taburcu.
  ///
  /// In en, this message translates to:
  /// **'Ücretsiz Taburcu'**
  String get cretsiz_taburcu;

  /// No description provided for @taburcu_ol.
  ///
  /// In en, this message translates to:
  /// **'Taburcu Ol'**
  String get taburcu_ol;

  /// No description provided for @yetersiz_elmas.
  ///
  /// In en, this message translates to:
  /// **'Yetersiz Elmas'**
  String get yetersiz_elmas;

  /// No description provided for @d_kkana_git.
  ///
  /// In en, this message translates to:
  /// **'Dükkana Git'**
  String get d_kkana_git;

  /// No description provided for @sa_l_ks_n_z_hastanede_de_ilsiniz.
  ///
  /// In en, this message translates to:
  /// **'Sağlıksınız — hastanede değilsiniz'**
  String get sa_l_ks_n_z_hastanede_de_ilsiniz;

  /// No description provided for @ana_sayfaya_d_n.
  ///
  /// In en, this message translates to:
  /// **'Ana Sayfaya Dön'**
  String get ana_sayfaya_d_n;

  /// No description provided for @hastanede.
  ///
  /// In en, this message translates to:
  /// **'Hastanede'**
  String get hastanede;

  /// No description provided for @hastaneden_gizlice_ka.
  ///
  /// In en, this message translates to:
  /// **'🏃‍♂️ Hastaneden Gizlice Kaç'**
  String get hastaneden_gizlice_ka;

  /// No description provided for @ba_ar_rsan_zg_rs_n_doktorlara_yakalan_rsan_15_dk_c.
  ///
  /// In en, this message translates to:
  /// **'Başarırsan özgürsün, doktorlara yakalanırsan +15 DK ceza alırsın!'**
  String get ba_ar_rsan_zg_rs_n_doktorlara_yakalan_rsan_15_dk_c;

  /// No description provided for @item_sat.
  ///
  /// In en, this message translates to:
  /// **'Item Sat'**
  String get item_sat;

  /// No description provided for @stack_bol.
  ///
  /// In en, this message translates to:
  /// **'Stack Bol'**
  String get stack_bol;

  /// No description provided for @yeni_stack_icin_miktar_sec.
  ///
  /// In en, this message translates to:
  /// **'Yeni stack icin miktar sec.'**
  String get yeni_stack_icin_miktar_sec;

  /// No description provided for @item_sil.
  ///
  /// In en, this message translates to:
  /// **'Item Sil'**
  String get item_sil;

  /// No description provided for @kusanilanlar.
  ///
  /// In en, this message translates to:
  /// **'Kusanilanlar'**
  String get kusanilanlar;

  /// No description provided for @envanter_2.
  ///
  /// In en, this message translates to:
  /// **'ENVANTER'**
  String get envanter_2;

  /// No description provided for @bir_item_secin.
  ///
  /// In en, this message translates to:
  /// **'Bir item secin.'**
  String get bir_item_secin;

  /// No description provided for @esya_adi.
  ///
  /// In en, this message translates to:
  /// **'ESYA ADI'**
  String get esya_adi;

  /// No description provided for @senin_s_ralaman.
  ///
  /// In en, this message translates to:
  /// **'Senin Sıralaman'**
  String get senin_s_ralaman;

  /// No description provided for @yenile.
  ///
  /// In en, this message translates to:
  /// **'Yenile'**
  String get yenile;

  /// No description provided for @t_m_zamanlar.
  ///
  /// In en, this message translates to:
  /// **'Tüm Zamanlar'**
  String get t_m_zamanlar;

  /// No description provided for @oyuncu_veya_lonca_ara.
  ///
  /// In en, this message translates to:
  /// **'Oyuncu veya lonca ara...'**
  String get oyuncu_veya_lonca_ara;

  /// No description provided for @drop_ni_zleme.
  ///
  /// In en, this message translates to:
  /// **'DROP ÖNİZLEME'**
  String get drop_ni_zleme;

  /// No description provided for @kapat_2.
  ///
  /// In en, this message translates to:
  /// **'KAPAT'**
  String get kapat_2;

  /// No description provided for @e_ya_adi.
  ///
  /// In en, this message translates to:
  /// **'EŞYA ADI'**
  String get e_ya_adi;

  /// No description provided for @bu_e_ya_kasa_a_l_nda_drop_havuzundan_kabilir.
  ///
  /// In en, this message translates to:
  /// **'Bu eşya kasa açılışında drop havuzundan çıkabilir.'**
  String get bu_e_ya_kasa_a_l_nda_drop_havuzundan_kabilir;

  /// No description provided for @supabase_tarafinda_aktif_kasa_bulunamadi.
  ///
  /// In en, this message translates to:
  /// **'Supabase tarafinda aktif kasa bulunamadi.'**
  String get supabase_tarafinda_aktif_kasa_bulunamadi;

  /// No description provided for @drop_preview.
  ///
  /// In en, this message translates to:
  /// **'Drop Preview'**
  String get drop_preview;

  /// No description provided for @drop_listesini_g_rmek_i_in_goster_a_dokun.
  ///
  /// In en, this message translates to:
  /// **'Drop listesini görmek için Goster\\\'a dokun.'**
  String get drop_listesini_g_rmek_i_in_goster_a_dokun;

  /// No description provided for @oyuncu_pazari.
  ///
  /// In en, this message translates to:
  /// **'Oyuncu Pazari'**
  String get oyuncu_pazari;

  /// No description provided for @sonuc_yok.
  ///
  /// In en, this message translates to:
  /// **'Sonuc yok'**
  String get sonuc_yok;

  /// No description provided for @ara.
  ///
  /// In en, this message translates to:
  /// **'Ara...'**
  String get ara;

  /// No description provided for @acik_ilan_yok.
  ///
  /// In en, this message translates to:
  /// **'Acik ilan yok'**
  String get acik_ilan_yok;

  /// No description provided for @fiyat.
  ///
  /// In en, this message translates to:
  /// **'Fiyat'**
  String get fiyat;

  /// No description provided for @geri_cek.
  ///
  /// In en, this message translates to:
  /// **'Geri cek?'**
  String get geri_cek;

  /// No description provided for @vazgec.
  ///
  /// In en, this message translates to:
  /// **'Vazgec'**
  String get vazgec;

  /// No description provided for @fiyat_guncelle.
  ///
  /// In en, this message translates to:
  /// **'Fiyat Guncelle'**
  String get fiyat_guncelle;

  /// No description provided for @bu_esya_stackable_degil_1_adet.
  ///
  /// In en, this message translates to:
  /// **'Bu esya stackable degil — 1 adet'**
  String get bu_esya_stackable_degil_1_adet;

  /// No description provided for @yeterli_altin_yok.
  ///
  /// In en, this message translates to:
  /// **'Yeterli altin yok'**
  String get yeterli_altin_yok;

  /// No description provided for @satilabilir_esya_yok.
  ///
  /// In en, this message translates to:
  /// **'Satilabilir esya yok'**
  String get satilabilir_esya_yok;

  /// No description provided for @bahsi_kaybettin.
  ///
  /// In en, this message translates to:
  /// **'Bahsi kaybettin'**
  String get bahsi_kaybettin;

  /// No description provided for @hastaneye_kaldirildin.
  ///
  /// In en, this message translates to:
  /// **'Hastaneye kaldirildin'**
  String get hastaneye_kaldirildin;

  /// No description provided for @pvp_arena.
  ///
  /// In en, this message translates to:
  /// **'PvP Arena'**
  String get pvp_arena;

  /// No description provided for @bahisli_arena.
  ///
  /// In en, this message translates to:
  /// **'BAHISLI ARENA'**
  String get bahisli_arena;

  /// No description provided for @altin_yatir_kazan_veya_kaybet.
  ///
  /// In en, this message translates to:
  /// **'Altin yatir, kazan veya kaybet'**
  String get altin_yatir_kazan_veya_kaybet;

  /// No description provided for @rakip_yok.
  ///
  /// In en, this message translates to:
  /// **'Rakip yok'**
  String get rakip_yok;

  /// No description provided for @siralama_bos.
  ///
  /// In en, this message translates to:
  /// **'Siralama bos'**
  String get siralama_bos;

  /// No description provided for @dovus.
  ///
  /// In en, this message translates to:
  /// **'Dovus'**
  String get dovus;

  /// No description provided for @s_15_enerji_harcanir_kazanan_havuzun_92sini_alir.
  ///
  /// In en, this message translates to:
  /// **'15 enerji harcanir. Kazanan havuzun %92sini alir.'**
  String get s_15_enerji_harcanir_kazanan_havuzun_92sini_alir;

  /// No description provided for @dovus_basla.
  ///
  /// In en, this message translates to:
  /// **'Dovus Basla'**
  String get dovus_basla;

  /// No description provided for @mekan_ac.
  ///
  /// In en, this message translates to:
  /// **'Mekan Ac'**
  String get mekan_ac;

  /// No description provided for @imparatorlugunu_kur.
  ///
  /// In en, this message translates to:
  /// **'IMPARATORLUGUNU KUR'**
  String get imparatorlugunu_kur;

  /// No description provided for @bir_tur_sec_adini_koy_ve_han_ticaretine_basla.
  ///
  /// In en, this message translates to:
  /// **'Bir tur sec, adini koy ve han ticaretine basla.'**
  String get bir_tur_sec_adini_koy_ve_han_ticaretine_basla;

  /// No description provided for @orn_golge_han_bar.
  ///
  /// In en, this message translates to:
  /// **'Orn: Golge Han Bar'**
  String get orn_golge_han_bar;

  /// No description provided for @mekan_turu.
  ///
  /// In en, this message translates to:
  /// **'Mekan Turu'**
  String get mekan_turu;

  /// No description provided for @her_tur_farkli_kapasite_ve_pvp_yetenegi_sunar.
  ///
  /// In en, this message translates to:
  /// **'Her tur farkli kapasite ve PvP yetenegi sunar'**
  String get her_tur_farkli_kapasite_ve_pvp_yetenegi_sunar;

  /// No description provided for @pvp_arena_destekli.
  ///
  /// In en, this message translates to:
  /// **'PvP Arena destekli'**
  String get pvp_arena_destekli;

  /// No description provided for @mekan_bulunamadi.
  ///
  /// In en, this message translates to:
  /// **'Mekan bulunamadi'**
  String get mekan_bulunamadi;

  /// No description provided for @listeye_don.
  ///
  /// In en, this message translates to:
  /// **'Listeye Don'**
  String get listeye_don;

  /// No description provided for @vitrin.
  ///
  /// In en, this message translates to:
  /// **'Vitrin'**
  String get vitrin;

  /// No description provided for @vitrin_bos.
  ///
  /// In en, this message translates to:
  /// **'Vitrin bos'**
  String get vitrin_bos;

  /// No description provided for @satin_al.
  ///
  /// In en, this message translates to:
  /// **'Satin Al'**
  String get satin_al;

  /// No description provided for @polis_baskini_nedeniyle_gecici_olarak_kapali.
  ///
  /// In en, this message translates to:
  /// **'Polis baskini nedeniyle gecici olarak kapali.'**
  String get polis_baskini_nedeniyle_gecici_olarak_kapali;

  /// No description provided for @mekani_yonet.
  ///
  /// In en, this message translates to:
  /// **'Mekani Yonet'**
  String get mekani_yonet;

  /// No description provided for @toplam.
  ///
  /// In en, this message translates to:
  /// **'Toplam'**
  String get toplam;

  /// No description provided for @han_agi.
  ///
  /// In en, this message translates to:
  /// **'Han Agi'**
  String get han_agi;

  /// No description provided for @yuklenemedi.
  ///
  /// In en, this message translates to:
  /// **'Yuklenemedi'**
  String get yuklenemedi;

  /// No description provided for @mekan_yok.
  ///
  /// In en, this message translates to:
  /// **'Mekan yok'**
  String get mekan_yok;

  /// No description provided for @canli_ekonomi.
  ///
  /// In en, this message translates to:
  /// **'CANLI EKONOMI'**
  String get canli_ekonomi;

  /// No description provided for @han_ticaret_agi.
  ///
  /// In en, this message translates to:
  /// **'HAN TICARET AGI'**
  String get han_ticaret_agi;

  /// No description provided for @mekan_ac_iksir_sat_sohret_kazan_arenada_dovus_kaca.
  ///
  /// In en, this message translates to:
  /// **'Mekan ac, iksir sat, sohret kazan. Arenada dovus, kacak ticaretle imparatorluk kur.'**
  String get mekan_ac_iksir_sat_sohret_kazan_arenada_dovus_kaca;

  /// No description provided for @benim_mekanim.
  ///
  /// In en, this message translates to:
  /// **'Benim Mekanim'**
  String get benim_mekanim;

  /// No description provided for @sohret_siralamasi.
  ///
  /// In en, this message translates to:
  /// **'Sohret Siralamasi'**
  String get sohret_siralamasi;

  /// No description provided for @en_unlu_mekanlar.
  ///
  /// In en, this message translates to:
  /// **'En unlu mekanlar'**
  String get en_unlu_mekanlar;

  /// No description provided for @mekanin_yok.
  ///
  /// In en, this message translates to:
  /// **'Mekanin yok'**
  String get mekanin_yok;

  /// No description provided for @the_vault.
  ///
  /// In en, this message translates to:
  /// **'THE VAULT'**
  String get the_vault;

  /// No description provided for @toplam_gelir.
  ///
  /// In en, this message translates to:
  /// **'Toplam Gelir'**
  String get toplam_gelir;

  /// No description provided for @vitrini_goruntule.
  ///
  /// In en, this message translates to:
  /// **'Vitrini Goruntule'**
  String get vitrini_goruntule;

  /// No description provided for @aylik_kira.
  ///
  /// In en, this message translates to:
  /// **'Aylik Kira'**
  String get aylik_kira;

  /// No description provided for @stok_ekle_guncelle.
  ///
  /// In en, this message translates to:
  /// **'Stok Ekle / Guncelle'**
  String get stok_ekle_guncelle;

  /// No description provided for @uygun_envanter_yok_iksir_veya_han_itemi_gerekli.
  ///
  /// In en, this message translates to:
  /// **'Uygun envanter yok — iksir veya Han itemi gerekli.'**
  String get uygun_envanter_yok_iksir_veya_han_itemi_gerekli;

  /// No description provided for @mevcut_stok.
  ///
  /// In en, this message translates to:
  /// **'Mevcut Stok'**
  String get mevcut_stok;

  /// No description provided for @stok_bos.
  ///
  /// In en, this message translates to:
  /// **'Stok bos'**
  String get stok_bos;

  /// No description provided for @istatistik_yok.
  ///
  /// In en, this message translates to:
  /// **'Istatistik yok'**
  String get istatistik_yok;

  /// No description provided for @en_cok_satan.
  ///
  /// In en, this message translates to:
  /// **'En Cok Satan'**
  String get en_cok_satan;

  /// No description provided for @maksimum_seviyeye_ulasildi.
  ///
  /// In en, this message translates to:
  /// **'Maksimum seviyeye ulasildi!'**
  String get maksimum_seviyeye_ulasildi;

  /// No description provided for @kapasite.
  ///
  /// In en, this message translates to:
  /// **'+kapasite'**
  String get kapasite;

  /// No description provided for @yukseltme_avantajlari.
  ///
  /// In en, this message translates to:
  /// **'Yukseltme Avantajlari'**
  String get yukseltme_avantajlari;

  /// No description provided for @mekani_yukselt.
  ///
  /// In en, this message translates to:
  /// **'Mekani Yukselt'**
  String get mekani_yukselt;

  /// No description provided for @yukselt.
  ///
  /// In en, this message translates to:
  /// **'Yukselt'**
  String get yukselt;

  /// No description provided for @kacak_madde_sadece_yeralti_polis_baskini_riski.
  ///
  /// In en, this message translates to:
  /// **'Kacak madde — sadece Yeralti, polis baskini riski.'**
  String get kacak_madde_sadece_yeralti_polis_baskini_riski;

  /// No description provided for @stogu_kaldirmak_icin_adeti_0_yap.
  ///
  /// In en, this message translates to:
  /// **'Stogu kaldirmak icin adeti 0 yap.'**
  String get stogu_kaldirmak_icin_adeti_0_yap;

  /// No description provided for @kacak.
  ///
  /// In en, this message translates to:
  /// **'KACAK'**
  String get kacak;

  /// No description provided for @happy_hour.
  ///
  /// In en, this message translates to:
  /// **'HAPPY HOUR'**
  String get happy_hour;

  /// No description provided for @tum_alimlarda_20_indirim.
  ///
  /// In en, this message translates to:
  /// **'Tum alimlarda %20 indirim'**
  String get tum_alimlarda_20_indirim;

  /// No description provided for @polis_suphesi.
  ///
  /// In en, this message translates to:
  /// **'Polis Suphesi'**
  String get polis_suphesi;

  /// No description provided for @kahvehane.
  ///
  /// In en, this message translates to:
  /// **'Kahvehane'**
  String get kahvehane;

  /// No description provided for @d_v_kul_b.
  ///
  /// In en, this message translates to:
  /// **'Dövüş Kulübü'**
  String get d_v_kul_b;

  /// No description provided for @l_ks_lounge.
  ///
  /// In en, this message translates to:
  /// **'Lüks Lounge'**
  String get l_ks_lounge;

  /// No description provided for @yeralt.
  ///
  /// In en, this message translates to:
  /// **'Yeraltı'**
  String get yeralt;

  /// No description provided for @mekan.
  ///
  /// In en, this message translates to:
  /// **'Mekan'**
  String get mekan;

  /// No description provided for @kefalet_de.
  ///
  /// In en, this message translates to:
  /// **'Kefalet Öde'**
  String get kefalet_de;

  /// No description provided for @cezaevi.
  ///
  /// In en, this message translates to:
  /// **'⛓️ Cezaevi'**
  String get cezaevi;

  /// No description provided for @cezaevi_2.
  ///
  /// In en, this message translates to:
  /// **'Cezaevi'**
  String get cezaevi_2;

  /// No description provided for @u_anda_zg_rs_n_z.
  ///
  /// In en, this message translates to:
  /// **'✅ Şu anda özgürsünüz!'**
  String get u_anda_zg_rs_n_z;

  /// No description provided for @g_lge_ekonomi_de_hukuk_ve_d_zen_sa_lan_yor_yasalar.
  ///
  /// In en, this message translates to:
  /// **'Gölge Ekonomi\\\'de hukuk ve düzen sağlanıyor. Yasalara uyduğunuz sürece özgürsünüz!'**
  String get g_lge_ekonomi_de_hukuk_ve_d_zen_sa_lan_yor_yasalar;

  /// No description provided for @hapi_shanedesi_ni_z.
  ///
  /// In en, this message translates to:
  /// **'⛓️ HAPİSHANEDESİNİZ!'**
  String get hapi_shanedesi_ni_z;

  /// No description provided for @yasalara_ayk_r_davran_lar_nedeniyle_hapishanedesin.
  ///
  /// In en, this message translates to:
  /// **'Yasalara aykırı davranışlar nedeniyle hapishanedesiniz. Kefalet ödeyerek erken çıkabilir veya sürenizi tamamlayabilirsiniz.'**
  String get yasalara_ayk_r_davran_lar_nedeniyle_hapishanedesin;

  /// No description provided for @hapishaneden_ka_may_dene.
  ///
  /// In en, this message translates to:
  /// **'🏃‍♂️ Hapishaneden Kaçmayı Dene'**
  String get hapishaneden_ka_may_dene;

  /// No description provided for @ba_ar_rsan_zg_rs_n_yakalan_rsan_15_dk_ceza_al_rs_n.
  ///
  /// In en, this message translates to:
  /// **'Başarırsan özgürsün, yakalanırsan +15 DK ceza alırsın!'**
  String get ba_ar_rsan_zg_rs_n_yakalan_rsan_15_dk_ceza_al_rs_n;

  /// No description provided for @pvp_ma_ge_mi_i.
  ///
  /// In en, this message translates to:
  /// **'⚔️ PvP Maç Geçmişi'**
  String get pvp_ma_ge_mi_i;

  /// No description provided for @hen_z_hi_pvp_ma_n_z_bulunmuyor.
  ///
  /// In en, this message translates to:
  /// **'Henüz hiç PvP maçınız bulunmuyor.'**
  String get hen_z_hi_pvp_ma_n_z_bulunmuyor;

  /// No description provided for @pvp_i_statistikleri.
  ///
  /// In en, this message translates to:
  /// **'⚔️ PvP İstatistikleri'**
  String get pvp_i_statistikleri;

  /// No description provided for @kazanma_oran.
  ///
  /// In en, this message translates to:
  /// **'Kazanma Oranı'**
  String get kazanma_oran;

  /// No description provided for @enerji_2.
  ///
  /// In en, this message translates to:
  /// **'Enerji'**
  String get enerji_2;

  /// No description provided for @galibiyet.
  ///
  /// In en, this message translates to:
  /// **'Galibiyet'**
  String get galibiyet;

  /// No description provided for @ma_lubiyet.
  ///
  /// In en, this message translates to:
  /// **'Mağlubiyet'**
  String get ma_lubiyet;

  /// No description provided for @ge_mi_i_a.
  ///
  /// In en, this message translates to:
  /// **'Geçmişi Aç'**
  String get ge_mi_i_a;

  /// No description provided for @turnuva.
  ///
  /// In en, this message translates to:
  /// **'Turnuva'**
  String get turnuva;

  /// No description provided for @a_k_arenalar.
  ///
  /// In en, this message translates to:
  /// **'🏟️ Açık Arenalar'**
  String get a_k_arenalar;

  /// No description provided for @son_ma_lar.
  ///
  /// In en, this message translates to:
  /// **'📋 Son Maçlar'**
  String get son_ma_lar;

  /// No description provided for @arenaya_git.
  ///
  /// In en, this message translates to:
  /// **'Arenaya Git'**
  String get arenaya_git;

  /// No description provided for @arena.
  ///
  /// In en, this message translates to:
  /// **'Arena'**
  String get arena;

  /// No description provided for @alt_n.
  ///
  /// In en, this message translates to:
  /// **'Altın'**
  String get alt_n;

  /// No description provided for @kritik_zafer_kayd.
  ///
  /// In en, this message translates to:
  /// **'⚡ Kritik zafer kaydı'**
  String get kritik_zafer_kayd;

  /// No description provided for @haftal_k_turnuva.
  ///
  /// In en, this message translates to:
  /// **'Haftalık Turnuva'**
  String get haftal_k_turnuva;

  /// No description provided for @bracket_hen_z_olu_mad_nkay_t_ol_2_kat_l_mc_olunca.
  ///
  /// In en, this message translates to:
  /// **'Bracket henüz oluşmadı.\\nKayıt ol — 2+ katılımcı olunca canlı bracket açılır.'**
  String get bracket_hen_z_olu_mad_nkay_t_ol_2_kat_l_mc_olunca;

  /// No description provided for @ampiyon.
  ///
  /// In en, this message translates to:
  /// **'Şampiyon'**
  String get ampiyon;

  /// No description provided for @turnuvaya_kat_l_kay_tlar_kapal.
  ///
  /// In en, this message translates to:
  /// **'Turnuvaya Katıl (Kayıtlar Kapalı)'**
  String get turnuvaya_kat_l_kay_tlar_kapal;

  /// No description provided for @g_revler_2.
  ///
  /// In en, this message translates to:
  /// **'📜 Görevler'**
  String get g_revler_2;

  /// No description provided for @genel_tamamlanma.
  ///
  /// In en, this message translates to:
  /// **'Genel Tamamlanma'**
  String get genel_tamamlanma;

  /// No description provided for @bitti.
  ///
  /// In en, this message translates to:
  /// **'Bitti'**
  String get bitti;

  /// No description provided for @hen_z_g_rev_yok.
  ///
  /// In en, this message translates to:
  /// **'Henüz görev yok'**
  String get hen_z_g_rev_yok;

  /// No description provided for @farkl_bir_sekmeyi_dene_ya_da_yenile.
  ///
  /// In en, this message translates to:
  /// **'Farklı bir sekmeyi dene ya da yenile.'**
  String get farkl_bir_sekmeyi_dene_ya_da_yenile;

  /// No description provided for @sezona_git_d_l_al.
  ///
  /// In en, this message translates to:
  /// **'🏆 Sezona Git — Ödül Al'**
  String get sezona_git_d_l_al;

  /// No description provided for @d_l_al.
  ///
  /// In en, this message translates to:
  /// **'🎁 Ödülü Al'**
  String get d_l_al;

  /// No description provided for @tamamla.
  ///
  /// In en, this message translates to:
  /// **'✅ Tamamla'**
  String get tamamla;

  /// No description provided for @d_ller.
  ///
  /// In en, this message translates to:
  /// **'🎁 ÖDÜLLER'**
  String get d_ller;

  /// No description provided for @d_l_tan_ml_de_il.
  ///
  /// In en, this message translates to:
  /// **'Ödül tanımlı değil.'**
  String get d_l_tan_ml_de_il;

  /// No description provided for @kazan_lacak_i_tibar_miktar.
  ///
  /// In en, this message translates to:
  /// **'Kazanılacak İtibar Miktarı'**
  String get kazan_lacak_i_tibar_miktar;

  /// No description provided for @i_tibar_kazanc.
  ///
  /// In en, this message translates to:
  /// **'İtibar kazancı:'**
  String get i_tibar_kazanc;

  /// No description provided for @alt_n_maliyeti.
  ///
  /// In en, this message translates to:
  /// **'Altın maliyeti:'**
  String get alt_n_maliyeti;

  /// No description provided for @kalan_alt_n.
  ///
  /// In en, this message translates to:
  /// **'Kalan altın:'**
  String get kalan_alt_n;

  /// No description provided for @yetersiz_alt_n.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Yetersiz altın!'**
  String get yetersiz_alt_n;

  /// No description provided for @ba_la.
  ///
  /// In en, this message translates to:
  /// **'Bağışla'**
  String get ba_la;

  /// No description provided for @kademe_d_lleri.
  ///
  /// In en, this message translates to:
  /// **'🎁 Kademe Ödülleri'**
  String get kademe_d_lleri;

  /// No description provided for @fraksiyon_g_revleri.
  ///
  /// In en, this message translates to:
  /// **'📋 Fraksiyon Görevleri'**
  String get fraksiyon_g_revleri;

  /// No description provided for @i_tibar_faksiyonlar.
  ///
  /// In en, this message translates to:
  /// **'İtibar & Faksiyonlar'**
  String get i_tibar_faksiyonlar;

  /// No description provided for @faksiyonlarla_ili_kilerinizi_g_lendirin.
  ///
  /// In en, this message translates to:
  /// **'Faksiyonlarla ilişkilerinizi güçlendirin'**
  String get faksiyonlarla_ili_kilerinizi_g_lendirin;

  /// No description provided for @battle_pass_2.
  ///
  /// In en, this message translates to:
  /// **'BATTLE PASS'**
  String get battle_pass_2;

  /// No description provided for @aktif_sezon_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Aktif sezon bulunamadı.'**
  String get aktif_sezon_bulunamad;

  /// No description provided for @vip_active.
  ///
  /// In en, this message translates to:
  /// **'VIP ACTIVE'**
  String get vip_active;

  /// No description provided for @bpp_i_lerlemesi.
  ///
  /// In en, this message translates to:
  /// **'BPP İlerlemesi'**
  String get bpp_i_lerlemesi;

  /// No description provided for @ki_li_tli.
  ///
  /// In en, this message translates to:
  /// **'KİLİTLİ'**
  String get ki_li_tli;

  /// No description provided for @cretsi_z.
  ///
  /// In en, this message translates to:
  /// **'ÜCRETSİZ'**
  String get cretsi_z;

  /// No description provided for @aktif_g_rev_bulunamad.
  ///
  /// In en, this message translates to:
  /// **'Aktif görev bulunamadı.'**
  String get aktif_g_rev_bulunamad;

  /// No description provided for @alindi.
  ///
  /// In en, this message translates to:
  /// **'ALINDI'**
  String get alindi;

  /// No description provided for @hesab_n_zdan_kmak_istedi_inize_emin_misiniz.
  ///
  /// In en, this message translates to:
  /// **'Hesabınızdan çıkmak istediğinize emin misiniz?'**
  String get hesab_n_zdan_kmak_istedi_inize_emin_misiniz;

  /// No description provided for @hesab_sil.
  ///
  /// In en, this message translates to:
  /// **'Hesabı Sil'**
  String get hesab_sil;

  /// No description provided for @bu_i_lem_geri_al_namaz_hesab_n_z_ve_t_m_verilerini.
  ///
  /// In en, this message translates to:
  /// **'Bu işlem geri alınamaz! Hesabınız ve tüm verileriniz kalıcı olarak silinecek. Emin misiniz?'**
  String get bu_i_lem_geri_al_namaz_hesab_n_z_ve_t_m_verilerini;

  /// No description provided for @ayarlar_2.
  ///
  /// In en, this message translates to:
  /// **'⚙️ Ayarlar'**
  String get ayarlar_2;

  /// No description provided for @ses_ayarlar.
  ///
  /// In en, this message translates to:
  /// **'🔊 Ses Ayarları'**
  String get ses_ayarlar;

  /// No description provided for @t_m_sesleri_kapat.
  ///
  /// In en, this message translates to:
  /// **'🔇 Tüm Sesleri Kapat'**
  String get t_m_sesleri_kapat;

  /// No description provided for @bildirimler_oyun.
  ///
  /// In en, this message translates to:
  /// **'📱 Bildirimler & Oyun'**
  String get bildirimler_oyun;

  /// No description provided for @bildirimler.
  ///
  /// In en, this message translates to:
  /// **'Bildirimler'**
  String get bildirimler;

  /// No description provided for @otomatik_sava.
  ///
  /// In en, this message translates to:
  /// **'⚔️ Otomatik Savaş'**
  String get otomatik_sava;

  /// No description provided for @pvp_ve_zindan_sava_lar_n_otomatik_y_net.
  ///
  /// In en, this message translates to:
  /// **'PvP ve zindan savaşlarını otomatik yönet'**
  String get pvp_ve_zindan_sava_lar_n_otomatik_y_net;

  /// No description provided for @dil_language.
  ///
  /// In en, this message translates to:
  /// **'🌍 Dil / Language'**
  String get dil_language;

  /// No description provided for @t_rk_e.
  ///
  /// In en, this message translates to:
  /// **'🇹🇷 Türkçe'**
  String get t_rk_e;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'🇬🇧 English'**
  String get english;

  /// No description provided for @profil.
  ///
  /// In en, this message translates to:
  /// **'👤 Profil'**
  String get profil;

  /// No description provided for @hesap.
  ///
  /// In en, this message translates to:
  /// **'🚨 Hesap'**
  String get hesap;

  /// No description provided for @sat_n_al.
  ///
  /// In en, this message translates to:
  /// **'✓ Satın Al'**
  String get sat_n_al;

  /// No description provided for @en_i_yi_de_er.
  ///
  /// In en, this message translates to:
  /// **'En İyi Değer'**
  String get en_i_yi_de_er;

  /// No description provided for @elmas.
  ///
  /// In en, this message translates to:
  /// **'Elmas'**
  String get elmas;

  /// No description provided for @sat_n_al_2.
  ///
  /// In en, this message translates to:
  /// **'Satın Al'**
  String get sat_n_al_2;

  /// No description provided for @u_anda_aktif_teklif_yok.
  ///
  /// In en, this message translates to:
  /// **'Şu anda aktif teklif yok.'**
  String get u_anda_aktif_teklif_yok;

  /// No description provided for @muharebe_ge_idi_yak_nda_aktif_olacak.
  ///
  /// In en, this message translates to:
  /// **'Muharebe Geçidi yakında aktif olacak.'**
  String get muharebe_ge_idi_yak_nda_aktif_olacak;

  /// No description provided for @e_ya_ara.
  ///
  /// In en, this message translates to:
  /// **'Eşya ara...'**
  String get e_ya_ara;

  /// No description provided for @e_ya_se.
  ///
  /// In en, this message translates to:
  /// **'Eşya Seç'**
  String get e_ya_se;

  /// No description provided for @takas_edilebilir_e_ya_yok.
  ///
  /// In en, this message translates to:
  /// **'Takas edilebilir eşya yok'**
  String get takas_edilebilir_e_ya_yok;

  /// No description provided for @teklifim.
  ///
  /// In en, this message translates to:
  /// **'📤 Teklifim'**
  String get teklifim;

  /// No description provided for @kar_teklif.
  ///
  /// In en, this message translates to:
  /// **'📥 Karşı Teklif'**
  String get kar_teklif;

  /// No description provided for @ticaret_2.
  ///
  /// In en, this message translates to:
  /// **'🤝 Ticaret'**
  String get ticaret_2;

  /// No description provided for @ticaret_yapmak_istedi_iniz_oyuncuyu_aray_n.
  ///
  /// In en, this message translates to:
  /// **'Ticaret yapmak istediğiniz oyuncuyu arayın.'**
  String get ticaret_yapmak_istedi_iniz_oyuncuyu_aray_n;

  /// No description provided for @oyuncu_ad.
  ///
  /// In en, this message translates to:
  /// **'Oyuncu adı...'**
  String get oyuncu_ad;

  /// No description provided for @ara_2.
  ///
  /// In en, this message translates to:
  /// **'🔍 Ara'**
  String get ara_2;

  /// No description provided for @engellenenler.
  ///
  /// In en, this message translates to:
  /// **'🚫 Engellenenler'**
  String get engellenenler;

  /// No description provided for @kald_r.
  ///
  /// In en, this message translates to:
  /// **'Kaldır'**
  String get kald_r;

  /// No description provided for @oyuncu_aran_yor.
  ///
  /// In en, this message translates to:
  /// **'Oyuncu aranıyor...'**
  String get oyuncu_aran_yor;

  /// No description provided for @ticaret_iste_i_g_nderildi_kar_taraf_kabul_edene_ka.
  ///
  /// In en, this message translates to:
  /// **'Ticaret isteği gönderildi. Karşı taraf kabul edene kadar bekleyin.'**
  String get ticaret_iste_i_g_nderildi_kar_taraf_kabul_edene_ka;

  /// No description provided for @i_ptal_et.
  ///
  /// In en, this message translates to:
  /// **'İptal Et'**
  String get i_ptal_et;

  /// No description provided for @alt_n_miktar.
  ///
  /// In en, this message translates to:
  /// **'Altın miktarı'**
  String get alt_n_miktar;

  /// No description provided for @alt_n_2.
  ///
  /// In en, this message translates to:
  /// **'💰 Altın'**
  String get alt_n_2;

  /// No description provided for @e_ya_ekle.
  ///
  /// In en, this message translates to:
  /// **'➕ Eşya Ekle'**
  String get e_ya_ekle;

  /// No description provided for @i_ptal_2.
  ///
  /// In en, this message translates to:
  /// **'❌ İptal'**
  String get i_ptal_2;

  /// No description provided for @onayla_2.
  ///
  /// In en, this message translates to:
  /// **'✅ Onayla'**
  String get onayla_2;

  /// No description provided for @onay_n_z_al_nd.
  ///
  /// In en, this message translates to:
  /// **'Onayınız alındı'**
  String get onay_n_z_al_nd;

  /// No description provided for @kar_taraf_n_onay_bekleniyor.
  ///
  /// In en, this message translates to:
  /// **'Karşı tarafın onayı bekleniyor...'**
  String get kar_taraf_n_onay_bekleniyor;

  /// No description provided for @ticaret_tamamland.
  ///
  /// In en, this message translates to:
  /// **'Ticaret Tamamlandı!'**
  String get ticaret_tamamland;

  /// No description provided for @yeni_ticaret.
  ///
  /// In en, this message translates to:
  /// **'Yeni Ticaret'**
  String get yeni_ticaret;

  /// No description provided for @hen_z_ticaret_ge_mi_i_yok.
  ///
  /// In en, this message translates to:
  /// **'Henüz ticaret geçmişi yok.'**
  String get hen_z_ticaret_ge_mi_i_yok;

  /// No description provided for @ben_verdim.
  ///
  /// In en, this message translates to:
  /// **'📤 Ben verdim'**
  String get ben_verdim;

  /// No description provided for @ben_ald_m.
  ///
  /// In en, this message translates to:
  /// **'📥 Ben aldım'**
  String get ben_ald_m;

  /// No description provided for @routeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get routeHome;

  /// No description provided for @routeInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get routeInventory;

  /// No description provided for @routeCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get routeCharacter;

  /// No description provided for @routeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get routeBank;

  /// No description provided for @routeShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get routeShop;

  /// No description provided for @routeMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get routeMarket;

  /// No description provided for @routeTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get routeTrade;

  /// No description provided for @routeCrafting.
  ///
  /// In en, this message translates to:
  /// **'Crafting'**
  String get routeCrafting;

  /// No description provided for @routeDungeon.
  ///
  /// In en, this message translates to:
  /// **'Dungeon'**
  String get routeDungeon;

  /// No description provided for @routeLoot.
  ///
  /// In en, this message translates to:
  /// **'Loot'**
  String get routeLoot;

  /// No description provided for @routeQuests.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get routeQuests;

  /// No description provided for @routeGuild.
  ///
  /// In en, this message translates to:
  /// **'Guild'**
  String get routeGuild;

  /// No description provided for @routeGuildWar.
  ///
  /// In en, this message translates to:
  /// **'Guild War'**
  String get routeGuildWar;

  /// No description provided for @routeGuildMonument.
  ///
  /// In en, this message translates to:
  /// **'Guild Monument'**
  String get routeGuildMonument;

  /// No description provided for @routeMonumentDonate.
  ///
  /// In en, this message translates to:
  /// **'Monument Donation'**
  String get routeMonumentDonate;

  /// No description provided for @routePvp.
  ///
  /// In en, this message translates to:
  /// **'PvP'**
  String get routePvp;

  /// No description provided for @routePvpTournament.
  ///
  /// In en, this message translates to:
  /// **'Weekly Tournament'**
  String get routePvpTournament;

  /// No description provided for @routePvpHistory.
  ///
  /// In en, this message translates to:
  /// **'PvP History'**
  String get routePvpHistory;

  /// No description provided for @routeSeason.
  ///
  /// In en, this message translates to:
  /// **'Battle Pass'**
  String get routeSeason;

  /// No description provided for @routeLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get routeLeaderboard;

  /// No description provided for @routeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get routeSettings;

  /// No description provided for @routeHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get routeHospital;

  /// No description provided for @routePrison.
  ///
  /// In en, this message translates to:
  /// **'Prison'**
  String get routePrison;

  /// No description provided for @routeReputation.
  ///
  /// In en, this message translates to:
  /// **'Reputation'**
  String get routeReputation;

  /// No description provided for @routeEnhancement.
  ///
  /// In en, this message translates to:
  /// **'Enhancement'**
  String get routeEnhancement;

  /// No description provided for @routeFacilities.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get routeFacilities;

  /// No description provided for @routeHorseRace.
  ///
  /// In en, this message translates to:
  /// **'Horse Race'**
  String get routeHorseRace;

  /// No description provided for @routeChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get routeChat;

  /// No description provided for @routeMekans.
  ///
  /// In en, this message translates to:
  /// **'Taverns'**
  String get routeMekans;

  /// No description provided for @routeMyMekan.
  ///
  /// In en, this message translates to:
  /// **'My Tavern'**
  String get routeMyMekan;

  /// No description provided for @routeMekanCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Tavern'**
  String get routeMekanCreate;

  /// No description provided for @routeMekanArena.
  ///
  /// In en, this message translates to:
  /// **'PvP Arena'**
  String get routeMekanArena;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navDungeon.
  ///
  /// In en, this message translates to:
  /// **'Dungeon'**
  String get navDungeon;

  /// No description provided for @navCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get navCharacter;

  /// No description provided for @navMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// No description provided for @playerDefault.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerDefault;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get commonError;

  /// No description provided for @menuBarrier.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuBarrier;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GKK Mobile'**
  String get appTitle;

  /// No description provided for @menuMonument.
  ///
  /// In en, this message translates to:
  /// **'Monument'**
  String get menuMonument;

  /// No description provided for @menuDailyReward.
  ///
  /// In en, this message translates to:
  /// **'Daily Reward'**
  String get menuDailyReward;

  /// No description provided for @menuLogout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get menuLogout;

  /// No description provided for @menuItemUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Item Upgrade'**
  String get menuItemUpgrade;

  /// No description provided for @menuMekans.
  ///
  /// In en, this message translates to:
  /// **'Taverns'**
  String get menuMekans;

  /// No description provided for @menuQuests.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get menuQuests;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get menuChat;

  /// No description provided for @menuHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get menuHospital;

  /// No description provided for @menuPrison.
  ///
  /// In en, this message translates to:
  /// **'Prison'**
  String get menuPrison;

  /// No description provided for @menuLoot.
  ///
  /// In en, this message translates to:
  /// **'Loot Boxes'**
  String get menuLoot;

  /// No description provided for @screenTitleCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get screenTitleCharacter;

  /// No description provided for @screenTitleBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get screenTitleBank;

  /// No description provided for @screenTitleQuests.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get screenTitleQuests;

  /// No description provided for @screenTitleTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get screenTitleTrade;

  /// No description provided for @screenTitleGuildMonument.
  ///
  /// In en, this message translates to:
  /// **'Guild Monument'**
  String get screenTitleGuildMonument;

  /// No description provided for @screenTitleGuildWar.
  ///
  /// In en, this message translates to:
  /// **'Guild War'**
  String get screenTitleGuildWar;

  /// No description provided for @screenTitleMonumentDonate.
  ///
  /// In en, this message translates to:
  /// **'Donate to Monument'**
  String get screenTitleMonumentDonate;

  /// No description provided for @profileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile.'**
  String get profileLoadFailed;

  /// No description provided for @settingsLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get settingsLogoutTitle;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settingsDeleteAccountTitle;

  /// No description provided for @settingsDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone! Your account and all data will be permanently deleted. Are you sure?'**
  String get settingsDeleteAccountConfirm;

  /// No description provided for @settingsNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Display name updated successfully.'**
  String get settingsNameUpdated;

  /// No description provided for @settingsNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 3 characters.'**
  String get settingsNameMinLength;

  /// No description provided for @settingsDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get settingsDisplayNameLabel;

  /// No description provided for @errorWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Error: {detail}'**
  String errorWithDetail(String detail);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
