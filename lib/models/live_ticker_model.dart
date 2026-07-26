class LiveTickerItem {
  const LiveTickerItem({
    required this.id,
    required this.type,
    required this.text,
    this.createdAt,
    this.maxPasses,
    this.passesRemaining,
  });

  final String id;
  final String type;
  final String text;
  final DateTime? createdAt;
  final int? maxPasses;
  final int? passesRemaining;

  bool get isStaffBroadcast => type == 'staff_broadcast';

  /// Sunucu geneli geçiş sayacı (fallback / ambient / night_market hariç).
  bool get tracksGlobalPasses =>
      !id.startsWith('fallback:') &&
      !isStaffBroadcast &&
      type != 'night_market' &&
      type != 'ambient';

  factory LiveTickerItem.fromJson(Map<String, dynamic> json) {
    final String rawText = (json['text'] ?? json['message'] ?? '').toString().trim();
    DateTime? createdAt;
    final dynamic rawAt = json['created_at'];
    if (rawAt is String && rawAt.isNotEmpty) {
      createdAt = DateTime.tryParse(rawAt);
    }
    return LiveTickerItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'ambient').toString(),
      text: rawText.isEmpty ? '🌌 Kamp sessiz…' : rawText,
      createdAt: createdAt,
      maxPasses: _asIntOrNull(json['max_passes']),
      passesRemaining: _asIntOrNull(json['passes_remaining']),
    );
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class LiveTickerFeed {
  const LiveTickerFeed({
    required this.items,
    this.retiredTickerIds = const <String>[],
  });

  final List<LiveTickerItem> items;
  final List<String> retiredTickerIds;

  static const LiveTickerFeed empty = LiveTickerFeed(items: <LiveTickerItem>[]);

  factory LiveTickerFeed.fromJson(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];
    if (rawItems is! List) {
      return LiveTickerFeed.empty;
    }
    final List<LiveTickerItem> parsed = <LiveTickerItem>[];
    for (final dynamic row in rawItems) {
      if (row is Map) {
        parsed.add(LiveTickerItem.fromJson(Map<String, dynamic>.from(row)));
      }
    }
    final List<String> retired = <String>[];
    final dynamic rawRetired = json['retired_ticker_ids'];
    if (rawRetired is List) {
      for (final dynamic id in rawRetired) {
        final String s = id?.toString() ?? '';
        if (s.isNotEmpty) retired.add(s);
      }
    }
    return LiveTickerFeed(items: parsed, retiredTickerIds: retired);
  }
}
