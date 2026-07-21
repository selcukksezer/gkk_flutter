import '../models/facility_model.dart';

class FacilityPreviewItem {
  const FacilityPreviewItem({required this.rarity, required this.quantity});

  final String rarity;
  final int quantity;

  factory FacilityPreviewItem.fromJson(Map<String, dynamic> json) {
    return FacilityPreviewItem(
      rarity: (json['rarity'] ?? 'common').toString().toLowerCase(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class FacilityProductionPreview {
  const FacilityProductionPreview({
    required this.remainingSeconds,
    required this.isReady,
    required this.baseCount,
    required this.totalCount,
    required this.items,
  });

  static const FacilityProductionPreview empty = FacilityProductionPreview(
    remainingSeconds: 0,
    isReady: false,
    baseCount: 0,
    totalCount: 0,
    items: <FacilityPreviewItem>[],
  );

  final int remainingSeconds;
  final bool isReady;
  final int baseCount;
  final int totalCount;
  final List<FacilityPreviewItem> items;

  factory FacilityProductionPreview.fromJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      return FacilityProductionPreview.empty;
    }

    final dynamic rawItems = json['items'];
    final List<FacilityPreviewItem> items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((row) => FacilityPreviewItem.fromJson(Map<String, dynamic>.from(row)))
            .where((item) => item.quantity > 0)
            .toList()
        : <FacilityPreviewItem>[];

    return FacilityProductionPreview(
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
      isReady: json['is_ready'] == true,
      baseCount: (json['base_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }

  List<FacilityQueueItem> toQueueItems({required bool completed}) {
    return items
        .map(
          (FacilityPreviewItem item) => FacilityQueueItem(
            id: item.rarity,
            quantity: item.quantity,
            rarity: item.rarity,
            startedAt: '',
            completesAt: '',
            isCompleted: completed,
          ),
        )
        .toList();
  }
}
