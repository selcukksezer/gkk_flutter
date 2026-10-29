class KingdomMarketBlessingStatus {
  const KingdomMarketBlessingStatus({
    required this.active,
    this.goldDiscountPct = 0,
    this.gemDiscountPct = 0,
    this.startedAt,
    this.expiresAt,
    this.activatedByUsername,
    this.activatedByGuildName,
  });

  final bool active;
  final int goldDiscountPct;
  final int gemDiscountPct;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? activatedByUsername;
  final String? activatedByGuildName;

  factory KingdomMarketBlessingStatus.inactive() =>
      const KingdomMarketBlessingStatus(active: false);

  factory KingdomMarketBlessingStatus.fromJson(Map<String, dynamic> json) {
    return KingdomMarketBlessingStatus(
      active: json['active'] == true,
      goldDiscountPct: _asInt(json['gold_discount_pct']),
      gemDiscountPct: _asInt(json['gem_discount_pct']),
      startedAt: _parseDate(json['started_at']),
      expiresAt: _parseDate(json['expires_at']),
      activatedByUsername: json['activated_by_username']?.toString(),
      activatedByGuildName: json['activated_by_guild_name']?.toString(),
    );
  }

  int discountPctForCurrency(String currency) {
    if (!active) return 0;
    if (currency == 'gems') return gemDiscountPct;
    return goldDiscountPct;
  }

  int applyDiscount(int basePrice, String currency) {
    final int pct = discountPctForCurrency(currency);
    if (pct <= 0) return basePrice;
    return (basePrice * (100 - pct) / 100).floor();
  }

  bool hasDiscountForCurrency(String currency) => discountPctForCurrency(currency) > 0;

  /// Effective discount percent: defaults to [goldDiscountPct], fallback to [gemDiscountPct].
  int get discountPercent =>
      goldDiscountPct > 0 ? goldDiscountPct : gemDiscountPct;

  String get activatorLabel {
    final String? guild = activatedByGuildName?.trim();
    final String? user = activatedByUsername?.trim();
    if (guild != null && guild.isNotEmpty && user != null && user.isNotEmpty) {
      return '$guild · $user';
    }
    if (guild != null && guild.isNotEmpty) return guild;
    if (user != null && user.isNotEmpty) return user;
    return 'Krallık lideri';
  }

  String discountSummary() {
    final List<String> parts = <String>[];
    if (goldDiscountPct > 0) parts.add('altın %$goldDiscountPct');
    if (gemDiscountPct > 0) parts.add('elmas %$gemDiscountPct');
    return parts.isEmpty ? 'indirim yok' : parts.join(' · ');
  }

  String bannerMessage({String? locationLabel}) {
    final String where = locationLabel == null ? 'Mağaza, pazar ve eşya' : locationLabel;
    return '👑 Kral indirimi aktif — $where: ${discountSummary()}. '
        '${activatorLabel} tarafından uygulandı.';
  }

  String remainingLabel() {
    final DateTime? end = expiresAt;
    if (end == null) return '';
    final Duration diff = end.difference(DateTime.now());
    if (diff.isNegative) return 'Süre doldu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} dk kaldı';
    return '${diff.inSeconds.clamp(0, 59)} sn kaldı';
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
