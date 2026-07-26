import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/player/player_action_sheet.dart';
import '../../models/staff_model.dart';

bool canOpenStaffPlayerActions(StaffProfile profile) {
  if (!profile.isStaff) return false;
  return profile.has('player.view_detail') ||
      profile.has('player.ban') ||
      profile.has('player.unban') ||
      profile.has('player.rename') ||
      profile.has('player.grant_gold') ||
      profile.has('player.deduct_gold') ||
      profile.has('player.grant_gems') ||
      profile.has('player.deduct_gems') ||
      profile.has('player.adjust_energy') ||
      profile.has('player.adjust_xp') ||
      profile.has('player.adjust_reputation') ||
      profile.has('player.adjust_health') ||
      profile.has('player.adjust_inventory') ||
      profile.has('player.restrict_hospital') ||
      profile.has('player.restrict_prison') ||
      profile.has('player.restrict_trade') ||
      profile.has('player.chat_mute');
}

Future<void> openStaffPlayerActions(
  BuildContext context,
  WidgetRef ref, {
  required String authId,
  required String username,
  String? displayName,
  String? staffBadge,
  String? kingBadge,
}) async {
  if (authId.isEmpty) return;
  await showPlayerActionSheet(
    context,
    ref,
    authId: authId,
    username: username,
    displayName: displayName,
    staffBadge: staffBadge,
    kingBadge: kingBadge,
  );
}
