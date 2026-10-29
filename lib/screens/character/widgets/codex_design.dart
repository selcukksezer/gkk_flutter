import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../models/codex_model.dart';
import '../../../theme/app_colors.dart';

// ─── 2027 Aion 2 Dark Fantasy Palette ──────────────────────────────────────────

abstract final class CodexPalette {
  static const Color void_ = Color(0xFF080B12);
  static const Color navy = Color(0xFF101626);
  static const Color surface = Color(0xFF141C2E);
  static const Color obsidian = Color(0xFF222B3F);
  static const Color titanium = Color(0xFF8E9CAE);
  static const Color gold = Color(0xFFFFB800);
  static const Color goldHi = Color(0xFFFFD64A);
  static const Color goldLo = Color(0xFFE08A00);
  static const Color fuchsia = Color(0xFFE01E5A);
  static const Color neon = Color(0xFF00FF66);
  static const Color solar = Color(0xFFFFD700);
  static const Color coral = Color(0xFFFF6B35);
  static const Color ruby = Color(0xFFE52E2E);
  static const Color textHi = Color(0xFFF2F6FF);

  // Aion 2 High Fantasy Specialized Emissives
  static const Color aetherCyan = Color(0xFF00E5FF);
  static const Color abyssViolet = Color(0xFF8B5CF6);
  static const Color daevaGold = Color(0xFFFFD700);
  static const Color tahabataFlame = Color(0xFFFF3D00);
  static const Color stormwingCyan = Color(0xFF00F0FF);
  static const Color miragentBlue = Color(0xFF2563EB);
  static const Color cardBg = Color(0xFF131929);

  static const LinearGradient goldGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[goldHi, gold, goldLo],
  );

  static const LinearGradient fuchsiaGoldGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[fuchsia, gold],
  );

  static const LinearGradient daevanionGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFFF8F00)],
  );

  static const LinearGradient miragentGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1E3A8A)],
  );

  static const LinearGradient stormwingGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFA78BFA), Color(0xFF7C3AED), Color(0xFF06B6D4)],
  );

  static const LinearGradient tahabataGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF6E40), Color(0xFFFF3D00), Color(0xFFBF360C)],
  );

  static LinearGradient panelGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      navy.withValues(alpha: 0.94),
      void_.withValues(alpha: 0.98),
    ],
  );
}

// ─── Press / Motion Utilities ────────────────────────────────────────────────

class CodexPressable extends StatefulWidget {
  const CodexPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<CodexPressable> createState() => _CodexPressableState();
}

class _CodexPressableState extends State<CodexPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class CodexStagger extends StatelessWidget {
  const CodexStagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (index % 10) * 40),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? c) {
        final double elastic = Curves.easeOutBack.transform(v.clamp(0.0, 1.0));
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - elastic)),
            child: Transform.scale(
              scale: 0.93 + 0.07 * elastic,
              child: c,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

// ─── Gear Set Models (Daevanion, Miragent, Stormwing, Tahabata) ──────────────

class CodexGearSetPiece {
  const CodexGearSetPiece({
    required this.id,
    required this.name,
    required this.slot,
    required this.category,
    required this.rarity,
    required this.lore,
    required this.hintLocation,
    required this.stats,
    required this.iconData,
  });

  final String id;
  final String name;
  final String slot; // 'Silah', 'Zırh', 'Kask', 'Çizme', 'Aksesuar'
  final String category; // 'weapon', 'armor', 'accessory'
  final String rarity; // 'mythic', 'legendary'
  final String lore;
  final String hintLocation;
  final Map<String, String> stats;
  final IconData iconData;
}

class CodexGearSet {
  const CodexGearSet({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.lore,
    required this.themeColor,
    required this.gradient,
    required this.icon,
    required this.pieces,
    required this.bonus2Piece,
    required this.bonus4Piece,
  });

  final String id;
  final String name;
  final String subtitle;
  final String lore;
  final Color themeColor;
  final LinearGradient gradient;
  final IconData icon;
  final List<CodexGearSetPiece> pieces;
  final String bonus2Piece;
  final String bonus4Piece;

  static const CodexGearSet daevanion = CodexGearSet(
    id: 'daevanion',
    name: 'Daevanion Seti',
    subtitle: 'Kutsal Atreia Muhafız Takımı (İlahi Deva)',
    themeColor: CodexPalette.daevaGold,
    gradient: CodexPalette.daevanionGrad,
    icon: Icons.auto_awesome_rounded,
    bonus2Piece: '+250 Can, +5% Fiziksel Savunma',
    bonus4Piece: '+12% Kutsal Hasar, +15% Kritik Direnci, "Deva Kutsaması" Aurası',
    lore:
        'Kadim Atreia tapınaklarında kutsanmış, Devaların uyanışında giyilen ilahi zırh takımı. Saf Aether ışığı yayar ve karanlık orduları dize getirir.',
    pieces: <CodexGearSetPiece>[
      CodexGearSetPiece(
        id: 'daevanion_sword',
        name: 'Daevanion Kutsal Uzunkılıç',
        slot: 'Silah',
        category: 'weapon',
        rarity: 'mythic',
        lore:
            'Aether madeninden dövülmüş ve Sanctum başrahiplerince kutsanmış, saf ilahi enerji yayan efsanevi çift el kılıcı.',
        hintLocation: 'Bölge 1 - Sanctum Tapınak Alanı',
        stats: <String, String>{
          'Fiziksel Saldırı': '+380',
          'Kutsal Hasar': '+65',
          'Kritik Oranı': '+8%',
        },
        iconData: Icons.colorize_rounded,
      ),
      CodexGearSetPiece(
        id: 'daevanion_cuirass',
        name: 'Daevanion Işık Göğüslüğü',
        slot: 'Zırh',
        category: 'armor',
        rarity: 'mythic',
        lore:
            'Gökten inen saf ışık kristaliyle dokunmuş zırh. Taşıyıcısının göğsünü karanlık lanetlere karşı aşılmaz bir kalkan gibi örter.',
        hintLocation: 'Bölge 1 - Kutsal Muhafız Görevi',
        stats: <String, String>{
          'Fiziksel Savunma': '+420',
          'Büyü Direnci': '+210',
          'Maksimum Can': '+300',
        },
        iconData: Icons.shield_rounded,
      ),
      CodexGearSetPiece(
        id: 'daevanion_greaves',
        name: 'Daevanion Şövalye Dizlikleri',
        slot: 'Zırh',
        category: 'armor',
        rarity: 'legendary',
        lore:
            'Savaş meydanında sarsılmaz bir duruş sağlayan altın kaplamalı Deva dizlikleri.',
        hintLocation: 'Bölge 2 - Eltnen Çölü Keşfi',
        stats: <String, String>{
          'Fiziksel Savunma': '+280',
          'Sarsılmazlık': '+15%',
          'Hareket Hızı': '+8',
        },
        iconData: Icons.accessibility_new_rounded,
      ),
      CodexGearSetPiece(
        id: 'daevanion_wings',
        name: 'Daevanion Kanat Yadigarı',
        slot: 'Aksesuar',
        category: 'accessory',
        rarity: 'mythic',
        lore:
            'Deva rütbesine yükselen seçilmiş kahramanlara verilen, havada süzülürken altın aether tozları saçan kutsal kanat yadigarı.',
        hintLocation: 'Bölge 1 - Uçuş Tapınağı Yükselişi',
        stats: <String, String>{
          'Uçuş Süresi': '+45s',
          'Tüm Dirençler': '+10%',
          'Şans Bonusu': '+12',
        },
        iconData: Icons.flight_rounded,
      ),
    ],
  );

  static const CodexGearSet miragent = CodexGearSet(
    id: 'miragent',
    name: 'Miragent / Fenris Seti',
    subtitle: 'Sanctum & Pandaemonium Muhafız Lejyonu',
    themeColor: CodexPalette.miragentBlue,
    gradient: CodexPalette.miragentGrad,
    icon: Icons.military_tech_rounded,
    bonus2Piece: '+320 Enerji / MP, +8% Saldırı Hızı',
    bonus4Piece: '+18% Yetenek Gücü, +20 Hareket Hızı, "Miragent İradesi"',
    lore:
        'Sanctum ve Pandaemonium elit muhafızlarının kan yeminiyle kuşandığı, efsanevi sadakat zırhı. Savaş alanında taşıyıcısına tükenmez dayanıklılık bahşeder.',
    pieces: <CodexGearSetPiece>[
      CodexGearSetPiece(
        id: 'miragent_greatsword',
        name: 'Miragent Şövalye Çift El Kılıcı',
        slot: 'Silah',
        category: 'weapon',
        rarity: 'mythic',
        lore:
            'Muhafız birliğinin komutanları için özel saf çelikten üretilmiş, keskinliğiyle zırhları kağıt gibi yaran kadim kılıç.',
        hintLocation: 'Bölge 3 - Heiron Kalesi Başarımları',
        stats: <String, String>{
          'Fiziksel Saldırı': '+410',
          'Zırh Delme': '+14%',
          'Saldırı Hızı': '+7%',
        },
        iconData: Icons.colorize_rounded,
      ),
      CodexGearSetPiece(
        id: 'fenris_dagger',
        name: 'Fenris Dişi Gölge Hançeri',
        slot: 'Silah',
        category: 'weapon',
        rarity: 'legendary',
        lore:
            'Gölge suikastçılarının karanlıkta düşman boğazına sapladığı, fırtına zehriyle kaplanmış ölümcül hançer.',
        hintLocation: 'Bölge 3 - Fenris Av Bölgesi',
        stats: <String, String>{
          'Fiziksel Saldırı': '+310',
          'Kritik Çarpanı': '+22%',
          'Zehir Hasarı': '+45/sn',
        },
        iconData: Icons.flash_on_rounded,
      ),
      CodexGearSetPiece(
        id: 'miragent_hauberk',
        name: 'Miragent Tapınakçı Zırhı',
        slot: 'Zırh',
        category: 'armor',
        rarity: 'mythic',
        lore:
            'Mavi safir halkalarla örülmüş, büyü darbelerini emerek taşıyıcısının aether havuzuna dönüştüren kutsal gövde zırhı.',
        hintLocation: 'Bölge 3 - Pandaemonium Madalyası',
        stats: <String, String>{
          'Fiziksel Savunma': '+390',
          'Büyü Savunması': '+340',
          'Enerji Yenilenmesi': '+18/sn',
        },
        iconData: Icons.shield_rounded,
      ),
      CodexGearSetPiece(
        id: 'fenris_spaulders',
        name: 'Fenris Gölge Omuzlukları',
        slot: 'Zırh',
        category: 'armor',
        rarity: 'legendary',
        lore:
            'Kurt başı kabartmalarıyla süslenmiş, yakın dövüşte karşı darbeleri saptıran sağlam omuz korumalığı.',
        hintLocation: 'Bölge 3 - Lejyon Kampı Görevleri',
        stats: <String, String>{
          'Fiziksel Savunma': '+240',
          'Karşı Darbe İhtimali': '+9%',
          'Kritik Direnci': '+11%',
        },
        iconData: Icons.shield_outlined,
      ),
    ],
  );

  static const CodexGearSet stormwing = CodexGearSet(
    id: 'stormwing',
    name: 'Stormwing Abyss Seti',
    subtitle: 'Beshmundir Tapınağı Kadim Uçurum Takımı',
    themeColor: CodexPalette.abyssViolet,
    gradient: CodexPalette.stormwingGrad,
    icon: Icons.cyclone_rounded,
    bonus2Piece: '+10% Kritik Oranı, +350 Fırtına Hasarı',
    bonus4Piece: '+25% Kritik Hasar, "Tempest Roar" Şok Dalgası Patlaması',
    lore:
        'Beshmundir Tapınağının en derin zindanında hapsedilen kadim ejderha Stormwingin kristal pullarından dövülmüş dehşet verici zırh. Uçurum fırtınalarının gücünü barındırır.',
    pieces: <CodexGearSetPiece>[
      CodexGearSetPiece(
        id: 'stormwing_bow',
        name: 'Stormwing Caelum Yayı',
        slot: 'Silah',
        category: 'weapon',
        rarity: 'mythic',
        lore:
            'Gök gürültüsü kirişine gerilmiş ejderha kemiği gövdesiyle, fırlatılan her oku şimşek okuna dönüştüren efsanevi yay.',
        hintLocation: 'Bölge 4 - Beshmundir Tapınağı Zindanı',
        stats: <String, String>{
          'Menzilli Saldırı': '+445',
          'Fırtına Hasarı': '+95',
          'Kritik Oranı': '+15%',
        },
        iconData: Icons.navigation_rounded,
      ),
      CodexGearSetPiece(
        id: 'stormwing_plate',
        name: 'Stormwing Uçurum Zırhı',
        slot: 'Zırh',
        category: 'armor',
        rarity: 'mythic',
        lore:
            'Koyu mor ejderha pullarından örülü, darbe aldığında düşmana şimşek geri tepmesi yansıtan güçlü levha göğüslük.',
        hintLocation: 'Bölge 4 - Stormwing Boss Sandığı',
        stats: <String, String>{
          'Fiziksel Savunma': '+460',
          'Elektrik Direnci': '+320',
          'Şok Direnci': '+20%',
        },
        iconData: Icons.shield_rounded,
      ),
      CodexGearSetPiece(
        id: 'stormwing_boots',
        name: 'Stormwing Kristal Çizmeleri',
        slot: 'Zırh',
        category: 'armor',
        rarity: 'legendary',
        lore:
            'Rüzgar üzerinde yürümeyi mümkün kılan, adımları hızlandıran ejderha pençesi çizmeleri.',
        hintLocation: 'Bölge 4 - Uçurum Fırtınası Alanı',
        stats: <String, String>{
          'Fiziksel Savunma': '+250',
          'Hareket Hızı': '+18',
          'Kaçınma Oranı': '+12%',
        },
        iconData: Icons.directions_run_rounded,
      ),
      CodexGearSetPiece(
        id: 'stormwing_orb',
        name: 'Stormwing Yozlaşmış Küre',
        slot: 'Silah',
        category: 'weapon',
        rarity: 'mythic',
        lore:
            'Stormwingin son nefesinde hapsettiği fırtına kalbini taşıyan, büyü gücünü yıkıcı seviyelere çıkaran küre.',
        hintLocation: 'Bölge 4 - Tapınak Sonu Boss Düşüşü',
        stats: <String, String>{
          'Büyü Saldırısı': '+490',
          'Yetenek Hızı': '+14%',
          'Büyü Kritik': '+16%',
        },
        iconData: Icons.lens_blur_rounded,
      ),
    ],
  );

  static const CodexGearSet tahabata = CodexGearSet(
    id: 'tahabata',
    name: 'Tahabata Silahları',
    subtitle: 'Karanlık Poeta Alev Hükümdarı Cephaneliği',
    themeColor: CodexPalette.tahabataFlame,
    gradient: CodexPalette.tahabataGrad,
    icon: Icons.local_fire_department_rounded,
    bonus2Piece: '+15% Ateş Delme, +400 Yanma Hasarı (DoT)',
    bonus4Piece: '+30% Tüm Saldırı Gücü, "Flames of Poeta" Patlaması',
    lore:
        'Geleceğin kararmış Poetasını küle çeviren Tahabatanın lav yüreğinden damıtılan alev silahları. Dokunduğu yeri eriten kadim ve sönmeyen bir ateş saçar.',
    pieces: <CodexGearSetPiece>[
      CodexGearSetPiece(
        id: 'tahabata_greatsword',
        name: 'Tahabata Alevli Çift El Kılıcı',
        slot: 'Silah',
        category: 'weapon',
        rarity: 'mythic',
        lore:
            'Tahabatanın erimiş omurgasından şekillendirilen, savrulduğunda lav dalgaları fırlatan efsanevi çift el kılıcı.',
        hintLocation: 'Bölge 5 - Karanlık Poeta S-Sınıfı Zindan',
        stats: <String, String>{
          'Fiziksel Saldırı': '+510',
          'Ateş Hasarı': '+120',
          'Kritik Çarpanı': '+28%',
        },
        iconData: Icons.colorize_rounded,
      ),
      CodexGearSetPiece(
        id: 'tahabata_dagger',
        name: 'Tahabata Yakıcı Hançeri',
        slot: 'Silah',
        category: 'weapon',
        rarity: 'mythic',
        lore:
            'Düşmanın etini dağlayan lav sıcaklığında kabzaya sahip, temas anında zırhı eriten hançer.',
        hintLocation: 'Bölge 5 - Lav Krateri Gizli Sandığı',
        stats: <String, String>{
          'Fiziksel Saldırı': '+395',
          'Ateş Delme': '+18%',
          'Yanma Şansı': '+35%',
        },
        iconData: Icons.flash_on_rounded,
      ),
      CodexGearSetPiece(
        id: 'tahabata_staff',
        name: 'Tahabata Lav Asası',
        slot: 'Silah',
        category: 'weapon',
        rarity: 'mythic',
        lore:
            'Gökten meteor yağdırma gücüne sahip magma çekirdeğiyle güçlendirilmiş felaket asası.',
        hintLocation: 'Bölge 5 - Tahabata Taht Salonu',
        stats: <String, String>{
          'Büyü Saldırısı': '+535',
          'Meteor Çapı': '+2.5m',
          'Ateş Hasarı': '+140',
        },
        iconData: Icons.flare_rounded,
      ),
      CodexGearSetPiece(
        id: 'tahabata_shield',
        name: 'Tahabata Ejderha Kalkanı',
        slot: 'Zırh',
        category: 'armor',
        rarity: 'legendary',
        lore:
            'Ejderha pullarıyla örülmüş, ön cepheden gelen büyü ve fiziksel darbeleri lav ateşiyle eriten siper kalkanı.',
        hintLocation: 'Bölge 5 - Poeta Zindan Sonu Düşüşü',
        stats: <String, String>{
          'Bloklama Oranı': '+32%',
          'Fiziksel Savunma': '+380',
          'Ateş Direnci': '+400',
        },
        iconData: Icons.shield_rounded,
      ),
    ],
  );

  static const List<CodexGearSet> allSets = <CodexGearSet>[
    daevanion,
    miragent,
    stormwing,
    tahabata,
  ];

  bool isPieceDiscovered(
    CodexGearSetPiece piece,
    Iterable<CodexEntry> discoveredEntries,
  ) {
    final String pieceId = piece.id.toLowerCase();
    final String pieceName = piece.name.toLowerCase();
    for (final CodexEntry e in discoveredEntries) {
      if (!e.isDiscovered) continue;
      final String key = e.entryKey.toLowerCase();
      final String name = e.displayName.toLowerCase();
      if (key == pieceId ||
          name == pieceName ||
          key.contains(pieceId) ||
          pieceId.contains(key) ||
          name.contains(pieceName) ||
          pieceName.contains(name)) {
        return true;
      }
    }
    return false;
  }

  int discoveredPiecesCount(Iterable<CodexEntry> discoveredEntries) {
    int count = 0;
    for (final CodexGearSetPiece piece in pieces) {
      if (isPieceDiscovered(piece, discoveredEntries)) {
        count++;
      }
    }
    return count;
  }

  bool is2PieceUnlocked(Iterable<CodexEntry> discoveredEntries) =>
      discoveredPiecesCount(discoveredEntries) >= 2;

  bool is4PieceUnlocked(Iterable<CodexEntry> discoveredEntries) =>
      discoveredPiecesCount(discoveredEntries) >= 4;
}

// ─── Radial Completion Ring ──────────────────────────────────────────────────

class CodexCompletionRing extends StatelessWidget {
  const CodexCompletionRing({
    super.key,
    required this.progress,
    required this.discovered,
    required this.total,
    this.size = 72,
  });

  final double progress;
  final int discovered;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double clamped = progress.clamp(0.0, 1.0);
    final int pct = (clamped * 100).round();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(size, size),
            painter: _CompletionRingPainter(progress: clamped),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ShaderMask(
                shaderCallback: (Rect b) =>
                    CodexPalette.goldGrad.createShader(b),
                child: Text(
                  '%$pct',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ARŞİV',
                style: GoogleFonts.urbanist(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: CodexPalette.titanium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletionRingPainter extends CustomPainter {
  const _CompletionRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - 9) / 2;

    // Background Track
    final Paint trackPaint = Paint()
      ..color = CodexPalette.obsidian.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Glowing Foreground Arc
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final SweepGradient sweep = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: const <Color>[
        CodexPalette.fuchsia,
        CodexPalette.gold,
        CodexPalette.aetherCyan,
      ],
      stops: const <double>[0.0, 0.6, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final Paint arcPaint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, arcPaint);

    // Glowing dot at the tip
    final double endAngle = -math.pi / 2 + sweepAngle;
    final Offset tip = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );

    final Paint glowPaint = Paint()
      ..color = CodexPalette.aetherCyan.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(tip, 4, glowPaint);

    final Paint tipPaint = Paint()..color = Colors.white;
    canvas.drawCircle(tip, 2.5, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _CompletionRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─── Stat Unlocked Toast Banner ──────────────────────────────────────────────

class CodexStatUnlockedToast {
  CodexStatUnlockedToast._();

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    Color? accentColor,
  }) {
    HapticFeedback.heavyImpact();
    final Color accent = accentColor ?? CodexPalette.gold;

    final OverlayState overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) {
        return Positioned(
          top: MediaQuery.of(ctx).padding.top + 16,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (BuildContext context, double v, Widget? child) {
                return Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -20 * (1 - v)),
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          CodexPalette.navy.withValues(alpha: 0.95),
                          CodexPalette.void_.withValues(alpha: 0.98),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.6),
                        width: 1.4,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                accent.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                            ),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.8),
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                title.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message,
                                style: GoogleFonts.urbanist(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: CodexPalette.textHi,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 3200), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}

// ─── Vault Hero (Dark Fantasy Armory Compendium) ──────────────────────────────

class CodexVaultHero extends StatelessWidget {
  const CodexVaultHero({
    super.key,
    required this.dashboard,
    required this.claiming,
    required this.onClaim,
    this.milestoneScrollController,
    this.discoveredEntries = const <CodexEntry>[],
  });

  final CodexDashboard dashboard;
  final bool claiming;
  final VoidCallback? onClaim;
  final ScrollController? milestoneScrollController;
  final List<CodexEntry> discoveredEntries;

  @override
  Widget build(BuildContext context) {
    final double progress = dashboard.progress.clamp(0.0, 1.0);
    final bool canClaim =
        dashboard.claimableMilestones > 0 && onClaim != null && !claiming;

    // Calculate active set bonuses
    int active2P = 0;
    int active4P = 0;
    for (final CodexGearSet s in CodexGearSet.allSets) {
      if (s.is2PieceUnlocked(discoveredEntries)) active2P++;
      if (s.is4PieceUnlocked(discoveredEntries)) active4P++;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: CodexPalette.panelGrad,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: CodexPalette.gold.withValues(alpha: 0.42),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: CodexPalette.gold.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: CustomPaint(
                    painter: DotGridPainter(spacing: 13, dotOpacity: 0.06),
                  ),
                ),
                Positioned(
                  top: -40,
                  right: -25,
                  child: IgnorePointer(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            CodexPalette.aetherCyan.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CodexPalette.gold
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: CodexPalette.gold
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        'AION 2 ARMORY',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1,
                                          color: CodexPalette.gold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (dashboard.newEntries24h > 0)
                                      _StatChip(
                                        label: '+${dashboard.newEntries24h} yeni',
                                        color: CodexPalette.neon,
                                      ),
                                    if (dashboard.luckBonus > 0) ...<Widget>[
                                      const SizedBox(width: 5),
                                      _StatChip(
                                        label: 'ŞANS +${dashboard.luckBonus}',
                                        color: CodexPalette.solar,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'KODEX & CEPHANELİK',
                                  style: GoogleFonts.outfit(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    height: 1,
                                    color: CodexPalette.textHi,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    ShaderMask(
                                      shaderCallback: (Rect b) => CodexPalette
                                          .goldGrad
                                          .createShader(b),
                                      child: Text(
                                        '${dashboard.discovered}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 2,
                                        left: 4,
                                      ),
                                      child: Text(
                                        '/ ${dashboard.total} Kayıt',
                                        style: GoogleFonts.urbanist(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: CodexPalette.titanium,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          CodexCompletionRing(
                            progress: progress,
                            discovered: dashboard.discovered,
                            total: dashboard.total,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _GoldProgressBar(value: progress),
                      if (active2P > 0 || active4P > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: CodexPalette.navy.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: CodexPalette.aetherCyan
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.shield_moon_rounded,
                                size: 14,
                                color: CodexPalette.aetherCyan,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Set Bonusları: $active2P [2-Parça] · $active4P [4-Parça] Aktif',
                                style: GoogleFonts.urbanist(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: CodexPalette.aetherCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (dashboard.milestones.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        CodexMilestoneTrack(
                          milestones: dashboard.milestones,
                          scrollController: milestoneScrollController,
                        ),
                      ],
                      if (canClaim || claiming) ...<Widget>[
                        const SizedBox(height: 10),
                        CodexPressable(
                          onTap: claiming ? null : onClaim,
                          enabled: !claiming,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: CodexPalette.goldGrad,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: CodexPalette.gold
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.redeem_rounded,
                                  size: 16,
                                  color: CodexPalette.void_,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  claiming
                                      ? 'Ödüller Alınıyor...'
                                      : '${dashboard.claimableMilestones} Aşama Ödülü Topla',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: CodexPalette.void_,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _GoldProgressBar extends StatelessWidget {
  const _GoldProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: <Widget>[
            Container(color: CodexPalette.obsidian),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: CodexPalette.fuchsiaGoldGrad,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Milestone Track ─────────────────────────────────────────────────────────

class CodexMilestoneTrack extends StatelessWidget {
  const CodexMilestoneTrack({
    super.key,
    required this.milestones,
    this.scrollController,
  });

  final List<CodexMilestone> milestones;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: milestones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (BuildContext context, int index) {
          return CodexMilestoneCard(milestone: milestones[index]);
        },
      ),
    );
  }
}

class CodexMilestoneCard extends StatelessWidget {
  const CodexMilestoneCard({super.key, required this.milestone});

  final CodexMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final Color accent = milestone.claimed
        ? CodexPalette.neon
        : milestone.claimable
            ? CodexPalette.gold
            : CodexPalette.titanium;
    final bool showGem = milestone.rewardGems > 0;
    final bool showGold = milestone.rewardGold > 0;

    return Container(
      width: 66,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            CodexPalette.obsidian.withValues(alpha: 0.95),
            CodexPalette.void_.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: milestone.claimable
            ? <BoxShadow>[
                BoxShadow(
                  color: CodexPalette.gold.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '${milestone.threshold}',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          if (showGold || showGem)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (showGold) ...<Widget>[
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 10,
                      color: CodexPalette.gold,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _compact(milestone.rewardGold),
                      style: GoogleFonts.urbanist(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: CodexPalette.gold,
                      ),
                    ),
                  ],
                  if (showGold && showGem) const SizedBox(width: 4),
                  if (showGem) ...<Widget>[
                    const Icon(
                      Icons.diamond_rounded,
                      size: 9,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 1),
                    Text(
                      '${milestone.rewardGems}',
                      style: GoogleFonts.urbanist(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            const SizedBox(height: 11),
          const SizedBox(height: 3),
          Icon(
            milestone.claimed
                ? Icons.check_circle_rounded
                : milestone.claimable
                    ? Icons.redeem_rounded
                    : Icons.lock_outline_rounded,
            size: 13,
            color: accent.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) {
      final double m = value / 1000000;
      return m == m.roundToDouble()
          ? '${m.toStringAsFixed(0)}M'
          : '${m.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final double k = value / 1000;
      return k == k.roundToDouble()
          ? '${k.toStringAsFixed(0)}K'
          : '${k.toStringAsFixed(0)}K';
    }
    return '$value';
  }
}

// ─── Search & Category Filters ───────────────────────────────────────────────

class CodexSearchField extends StatelessWidget {
  const CodexSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.urbanist(
          color: CodexPalette.textHi,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Ara: kılıç, zırh, Daevanion, Stormwing, boss...',
          hintStyle: GoogleFonts.urbanist(
            color: CodexPalette.titanium.withValues(alpha: 0.7),
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: CodexPalette.titanium,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: CodexPalette.titanium,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: CodexPalette.navy.withValues(alpha: 0.9),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: CodexPalette.gold.withValues(alpha: 0.22),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: CodexPalette.gold.withValues(alpha: 0.22),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: CodexPalette.aetherCyan,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class CodexCategoryBar extends StatelessWidget {
  const CodexCategoryBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    required this.counts,
  });

  final List<(String type, String label, IconData icon)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Map<String, (int discovered, int total)> counts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final (String type, String label, IconData icon) = tabs[i];
          final bool active = i == selectedIndex;
          final (int d, int t) = counts[type] ?? (0, 0);

          return CodexPressable(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: active ? CodexPalette.goldGrad : null,
                color: active
                    ? null
                    : CodexPalette.navy.withValues(alpha: 0.85),
                border: Border.all(
                  color: active
                      ? CodexPalette.gold
                      : CodexPalette.obsidian.withValues(alpha: 0.6),
                  width: active ? 1.2 : 1,
                ),
                boxShadow: active
                    ? <BoxShadow>[
                        BoxShadow(
                          color: CodexPalette.gold.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    icon,
                    size: 15,
                    color: active ? CodexPalette.void_ : CodexPalette.titanium,
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: GoogleFonts.urbanist(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? CodexPalette.void_
                              : CodexPalette.textHi,
                        ),
                      ),
                      Text(
                        '$d/$t',
                        style: GoogleFonts.urbanist(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? CodexPalette.void_.withValues(alpha: 0.75)
                              : CodexPalette.titanium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CodexRarityFilter extends StatelessWidget {
  const CodexRarityFilter({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(String key, String label, int count)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int i) {
          final (String key, String label, int count) = options[i];
          final bool active = key == selected;
          final Color accent = _accentFor(key);
          return CodexPressable(
            onTap: () => onChanged(key),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  count > 0 ? '$label $count' : label,
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    color: active ? accent : CodexPalette.titanium,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2,
                  width: active ? 18 : 0,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _accentFor(String key) {
    return switch (key) {
      'legendary' || 'mythic' => CodexPalette.gold,
      'epic' => CodexPalette.fuchsia,
      'rare' => AppColors.rarityRare,
      'common' => AppColors.rarityCommon,
      'hidden' => CodexPalette.coral,
      _ => CodexPalette.gold,
    };
  }
}

class CodexSectionHeader extends StatelessWidget {
  const CodexSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.urbanist(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: CodexPalette.titanium,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: GoogleFonts.urbanist(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: CodexPalette.titanium.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gear Set Showcase Section (Daevanion, Miragent, Stormwing, Tahabata) ─────

class CodexGearSetShowcase extends StatelessWidget {
  const CodexGearSetShowcase({
    super.key,
    required this.sets,
    required this.discoveredEntries,
    required this.onInspectPiece,
  });

  final List<CodexGearSet> sets;
  final List<CodexEntry> discoveredEntries;
  final void Function(CodexGearSetPiece piece, CodexGearSet set) onInspectPiece;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: CodexSectionHeader(
            title: 'KADİM ATREIA SETLERİ',
            subtitle: '4 Efsanevi Takım · 16 Parça',
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: sets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final CodexGearSet gearSet = sets[index];
            return CodexGearSetCard(
              gearSet: gearSet,
              discoveredEntries: discoveredEntries,
              onInspectPiece: (CodexGearSetPiece p) => onInspectPiece(p, gearSet),
            );
          },
        ),
      ],
    );
  }
}

class CodexGearSetCard extends StatelessWidget {
  const CodexGearSetCard({
    super.key,
    required this.gearSet,
    required this.discoveredEntries,
    required this.onInspectPiece,
  });

  final CodexGearSet gearSet;
  final List<CodexEntry> discoveredEntries;
  final ValueChanged<CodexGearSetPiece> onInspectPiece;

  @override
  Widget build(BuildContext context) {
    final int unlockedCount = gearSet.discoveredPiecesCount(discoveredEntries);
    final bool is2P = gearSet.is2PieceUnlocked(discoveredEntries);
    final bool is4P = gearSet.is4PieceUnlocked(discoveredEntries);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            CodexPalette.navy.withValues(alpha: 0.95),
            CodexPalette.void_.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gearSet.themeColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: gearSet.themeColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: CustomPaint(
              painter: DotGridPainter(spacing: 12, dotOpacity: 0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gearSet.gradient,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: gearSet.themeColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        gearSet.icon,
                        color: CodexPalette.void_,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            gearSet.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: CodexPalette.textHi,
                            ),
                          ),
                          Text(
                            gearSet.subtitle,
                            style: GoogleFonts.urbanist(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: gearSet.themeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: unlockedCount > 0
                            ? gearSet.themeColor.withValues(alpha: 0.16)
                            : CodexPalette.obsidian,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: unlockedCount > 0
                              ? gearSet.themeColor.withValues(alpha: 0.5)
                              : CodexPalette.titanium.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        '$unlockedCount/4 Parça',
                        style: GoogleFonts.urbanist(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: unlockedCount > 0
                              ? gearSet.themeColor
                              : CodexPalette.titanium,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  gearSet.lore,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: CodexPalette.titanium,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                // 4 Pieces Row
                Row(
                  children: List<Widget>.generate(gearSet.pieces.length, (int i) {
                    final CodexGearSetPiece piece = gearSet.pieces[i];
                    final bool isDiscovered =
                        gearSet.isPieceDiscovered(piece, discoveredEntries);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                        child: CodexPressable(
                          onTap: () => onInspectPiece(piece),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDiscovered
                                  ? CodexPalette.surface.withValues(alpha: 0.9)
                                  : CodexPalette.obsidian.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDiscovered
                                    ? gearSet.themeColor.withValues(alpha: 0.6)
                                    : CodexPalette.titanium
                                        .withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              children: <Widget>[
                                Icon(
                                  piece.iconData,
                                  size: 20,
                                  color: isDiscovered
                                      ? gearSet.themeColor
                                      : CodexPalette.titanium
                                          .withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  piece.slot,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isDiscovered
                                        ? CodexPalette.textHi
                                        : CodexPalette.titanium,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isDiscovered ? 'AÇIK' : 'KİLİTLİ',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w900,
                                    color: isDiscovered
                                        ? CodexPalette.neon
                                        : CodexPalette.fuchsia
                                            .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                // Set Bonus Milestones
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CodexPalette.obsidian.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: CodexPalette.titanium.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      _SetBonusRow(
                        prefix: '2P',
                        bonus: gearSet.bonus2Piece,
                        unlocked: is2P,
                        color: gearSet.themeColor,
                      ),
                      const SizedBox(height: 6),
                      _SetBonusRow(
                        prefix: '4P',
                        bonus: gearSet.bonus4Piece,
                        unlocked: is4P,
                        color: gearSet.themeColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetBonusRow extends StatelessWidget {
  const _SetBonusRow({
    required this.prefix,
    required this.bonus,
    required this.unlocked,
    required this.color,
  });

  final String prefix;
  final String bonus;
  final bool unlocked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: unlocked
                ? color.withValues(alpha: 0.2)
                : CodexPalette.void_.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: unlocked
                  ? color
                  : CodexPalette.titanium.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            prefix,
            style: GoogleFonts.urbanist(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: unlocked ? color : CodexPalette.titanium,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            bonus,
            style: GoogleFonts.urbanist(
              fontSize: 10,
              fontWeight: unlocked ? FontWeight.w800 : FontWeight.w600,
              color: unlocked
                  ? CodexPalette.textHi
                  : CodexPalette.titanium.withValues(alpha: 0.6),
            ),
          ),
        ),
        Icon(
          unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          size: 13,
          color: unlocked ? CodexPalette.neon : CodexPalette.titanium,
        ),
      ],
    );
  }
}

// ─── Interactive 3D Turntable Viewport ────────────────────────────────────────

class CodexTurntable3DView extends StatefulWidget {
  const CodexTurntable3DView({
    super.key,
    required this.accentColor,
    required this.iconData,
    this.itemId = '',
    this.size = 180,
  });

  final Color accentColor;
  final IconData iconData;
  final String itemId;
  final double size;

  @override
  State<CodexTurntable3DView> createState() => _CodexTurntable3DViewState();
}

class _CodexTurntable3DViewState extends State<CodexTurntable3DView>
    with SingleTickerProviderStateMixin {
  double _rotationAngle = 0.0;
  late AnimationController _autoSpinCtrl;

  @override
  void initState() {
    super.initState();
    _autoSpinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _rotationAngle += 0.005;
          });
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _autoSpinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        setState(() {
          _rotationAngle += details.primaryDelta! * 0.015;
        });
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _TurntablePedestalPainter(
                angle: _rotationAngle,
                accentColor: widget.accentColor,
              ),
            ),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..rotateY(_rotationAngle),
              child: widget.itemId.isNotEmpty
                  ? ItemIconView(
                      itemId: widget.itemId,
                      iconValue: '',
                      size: widget.size * 0.44,
                    )
                  : Container(
                      width: widget.size * 0.46,
                      height: widget.size * 0.46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            widget.accentColor.withValues(alpha: 0.5),
                            widget.accentColor.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.iconData,
                        size: widget.size * 0.28,
                        color: widget.accentColor,
                      ),
                    ),
            ),
            Positioned(
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: CodexPalette.void_.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.threesixty_rounded,
                      size: 11,
                      color: widget.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '3D ÇEVİR · KAYDIR',
                      style: GoogleFonts.urbanist(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: CodexPalette.titanium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurntablePedestalPainter extends CustomPainter {
  const _TurntablePedestalPainter({
    required this.angle,
    required this.accentColor,
  });

  final double angle;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.68);
    final double rx = size.width * 0.42;
    final double ry = size.height * 0.18;

    // Glowing Platform Ellipse
    final Rect platformRect =
        Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);

    final Paint fillPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accentColor.withValues(alpha: 0.28),
          CodexPalette.navy.withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(platformRect);
    canvas.drawOval(platformRect, fillPaint);

    final Paint ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(platformRect, ringPaint);

    // Rotating Runic Marks on the rim
    const int marks = 8;
    final Paint markPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2.0;

    for (int i = 0; i < marks; i++) {
      final double theta = angle + (i * 2 * math.pi / marks);
      final double px = center.dx + rx * math.cos(theta);
      final double py = center.dy + ry * math.sin(theta);
      canvas.drawCircle(Offset(px, py), 1.6, markPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TurntablePedestalPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

// ─── Entry Cards (Grid Tiles) ────────────────────────────────────────────────

class CodexEntryCard extends StatelessWidget {
  const CodexEntryCard({
    super.key,
    required this.entry,
    required this.rarityColor,
    required this.onTap,
  });

  final CodexEntry entry;
  final Color rarityColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool discovered = entry.isDiscovered;
    final Color glow = discovered ? rarityColor : CodexPalette.fuchsia;
    final String hint = entry.hintLabel;

    return CodexPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                CodexPalette.surface.withValues(alpha: 0.96),
                CodexPalette.void_.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: discovered
                  ? rarityColor.withValues(alpha: 0.5)
                  : CodexPalette.titanium.withValues(alpha: 0.16),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: discovered ? 0.16 : 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 12, dotOpacity: 0.04),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: <Widget>[
                    if (hint.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.urbanist(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: discovered
                                ? CodexPalette.solar
                                : CodexPalette.fuchsia.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Center(
                        child: discovered && entry.entryType == 'item'
                            ? ItemIconView(
                                itemId: entry.entryKey,
                                iconValue: '',
                                size: 34,
                              )
                            : _CodexEntryOrb(
                                discovered: discovered,
                                accent: discovered
                                    ? rarityColor
                                    : CodexPalette.fuchsia,
                                size: 34,
                                entryType: entry.entryType,
                              ),
                      ),
                    ),
                    Text(
                      discovered ? entry.displayName : '???',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: discovered
                            ? CodexPalette.textHi
                            : CodexPalette.titanium,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      discovered ? codexRarityLabel(entry.rarity) : 'GİZLİ',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: discovered
                            ? rarityColor
                            : CodexPalette.fuchsia.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodexEntryOrb extends StatelessWidget {
  const _CodexEntryOrb({
    required this.discovered,
    required this.accent,
    this.size = 48,
    this.entryType = 'item',
  });

  final bool discovered;
  final Color accent;
  final double size;
  final String entryType;

  IconData get _icon {
    if (!discovered) return Icons.help_outline_rounded;
    return switch (entryType) {
      'boss' => Icons.whatshot_rounded,
      'dungeon' => Icons.castle_rounded,
      _ => Icons.auto_stories_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final double inner = size * 0.82;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.42),
                  accent.withValues(alpha: 0.06),
                  CodexPalette.void_.withValues(alpha: 0.4),
                ],
                stops: const <double>[0, 0.55, 1],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.72),
                width: 1.5,
              ),
            ),
            child: Icon(
              _icon,
              color: discovered
                  ? accent
                  : CodexPalette.titanium.withValues(alpha: 0.85),
              size: size * 0.38,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Item Inspect Modal (Full Lore + 3D Turntable Preview) ───────────────────

class CodexEntryDetailSheet extends StatelessWidget {
  const CodexEntryDetailSheet({
    super.key,
    required this.entry,
    required this.rarityColor,
    this.customLore,
    this.setAffiliation,
    this.statAttributes,
  });

  final CodexEntry entry;
  final Color rarityColor;
  final String? customLore;
  final String? setAffiliation;
  final Map<String, String>? statAttributes;

  static Future<void> show(
    BuildContext context, {
    required CodexEntry entry,
    required Color rarityColor,
    String? customLore,
    String? setAffiliation,
    Map<String, String>? statAttributes,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kodex İnceleme',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => CodexEntryDetailSheet(
        entry: entry,
        rarityColor: rarityColor,
        customLore: customLore,
        setAffiliation: setAffiliation,
        statAttributes: statAttributes,
      ),
      transitionBuilder: (
        BuildContext context,
        Animation<double> a,
        _,
        Widget child,
      ) {
        final Animation<double> curved = CurvedAnimation(
          parent: a,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String rarity = codexRarityLabel(entry.rarity);
    final String typeLabel = switch (entry.entryType) {
      'boss' => 'Boss',
      'dungeon' => 'Zindan',
      _ => 'Eşya',
    };

    final String lore = customLore ?? _defaultLoreForEntry(entry);

    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                    maxHeight: 640,
                  ),
                  decoration: BoxDecoration(
                    gradient: CodexPalette.panelGrad,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: <Widget>[
                      const Positioned.fill(
                        child: CustomPaint(
                          painter:
                              DotGridPainter(spacing: 13, dotOpacity: 0.07),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Top Bar
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: rarityColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          rarityColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    '${rarity.isEmpty ? 'KAYIT' : rarity.toUpperCase()} · ${typeLabel.toUpperCase()}',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                      color: rarityColor,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                CodexPressable(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: CodexPalette.obsidian,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: CodexPalette.titanium
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: CodexPalette.titanium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 3D Turntable Viewport
                            CodexTurntable3DView(
                              accentColor: rarityColor,
                              iconData: entry.entryType == 'boss'
                                  ? Icons.whatshot_rounded
                                  : entry.entryType == 'dungeon'
                                      ? Icons.castle_rounded
                                      : Icons.colorize_rounded,
                              itemId: entry.entryType == 'item'
                                  ? entry.entryKey
                                  : '',
                              size: 160,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              entry.displayName,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: CodexPalette.textHi,
                              ),
                            ),
                            if (setAffiliation != null) ...<Widget>[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: CodexPalette.daevaGold
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: CodexPalette.daevaGold
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  setAffiliation!,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: CodexPalette.daevaGold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // Lore Paragraph
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CodexPalette.obsidian
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CodexPalette.titanium
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'KADİM ARŞİV NOTU',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: CodexPalette.titanium,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lore,
                                    style: GoogleFonts.urbanist(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: CodexPalette.textHi,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (statAttributes != null &&
                                statAttributes!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: CodexPalette.obsidian
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: CodexPalette.titanium
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Column(
                                  children: statAttributes!.entries
                                      .map(
                                        (MapEntry<String, String> e) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              Text(
                                                e.key,
                                                style: GoogleFonts.urbanist(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: CodexPalette.titanium,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                e.value,
                                                style: GoogleFonts.urbanist(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: CodexPalette.textHi,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            // Origin & Discovery Date
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CodexPalette.obsidian
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CodexPalette.titanium
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  _DetailRow(
                                    icon: Icons.place_rounded,
                                    label: 'Köken Bölgesi',
                                    value: entry.hintLabel,
                                  ),
                                  if (entry.discoveredAt != null) ...<Widget>[
                                    const SizedBox(height: 6),
                                    _DetailRow(
                                      icon: Icons.history_rounded,
                                      label: 'Keşfedilme',
                                      value: _fmtDate(entry.discoveredAt!),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            CodexPressable(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: CodexPalette.goldGrad,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: CodexPalette.gold
                                          .withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'KAPAT',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    color: CodexPalette.void_,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _defaultLoreForEntry(CodexEntry entry) {
    if (entry.entryType == 'boss') {
      return '${entry.displayName}, Atreia karanlık uçurumlarında uyanmış kadim bir zindan efendisidir. Yenilmesi durumunda cephanelikte efsanevi zırh ve silahların kilidini açar.';
    }
    if (entry.entryType == 'dungeon') {
      return '${entry.displayName}, bilinmeyen tehlikeler ve gizli hazineler barındıran kadim bir labirenttir. Devaların gücünü sınayan zorlu sınavlar içerir.';
    }
    return '${entry.displayName}, Atreia madenlerinden işlenmiş eşsiz bir cephanelik parçasıdır. Taşıyıcısının savaş gücünü artıran aether enerjisiyle donatılmıştır.';
  }

  static String _fmtDate(DateTime dt) {
    final DateTime local = dt.toLocal();
    final String d =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    return d;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: CodexPalette.titanium),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.urbanist(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: CodexPalette.titanium,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.urbanist(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: CodexPalette.textHi,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty & Legacy Tab Header ───────────────────────────────────────────────

class CodexEmptyState extends StatelessWidget {
  const CodexEmptyState({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            gradient: CodexPalette.panelGrad,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CodexPalette.titanium.withValues(alpha: 0.22),
            ),
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 14, dotOpacity: 0.05),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CodexPalette.obsidian,
                      border: Border.all(
                        color: CodexPalette.fuchsia.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(icon, size: 26, color: CodexPalette.titanium),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CodexPalette.titanium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CodexTabHeader extends StatelessWidget {
  const CodexTabHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.discovered,
    required this.total,
  });

  final String title;
  final IconData icon;
  final int discovered;
  final int total;

  @override
  Widget build(BuildContext context) {
    return CodexSectionHeader(
      title: title.toUpperCase(),
      subtitle: '$discovered / $total keşfedildi',
    );
  }
}
