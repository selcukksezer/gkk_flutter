import 'package:flutter/foundation.dart';

/// Lightweight retention event hooks — debugPrint now, SDK later.
abstract final class RetentionAnalytics {
  static void codexClaimAll({int? claimedCount, int? gold, int? gems}) {
    debugPrint(
      '[RetentionAnalytics] codexClaimAll '
      'count=$claimedCount gold=$gold gems=$gems',
    );
  }

  static void nightMarketBuy({String? offerId, String? itemName, int? qty}) {
    debugPrint(
      '[RetentionAnalytics] nightMarketBuy '
      'offer=$offerId item=$itemName qty=$qty',
    );
  }

  static void nemesisRevengeInvite({String? rivalId}) {
    debugPrint(
      '[RetentionAnalytics] nemesisRevengeInvite rival=$rivalId',
    );
  }
}
