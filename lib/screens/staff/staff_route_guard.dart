import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/staff_provider.dart';
import '../../routing/app_router.dart';
import '../support/widgets/support_design.dart';
import '../support/widgets/support_screen_shell.dart';

/// Blocks non-staff access to `/staff` routes.
class StaffRouteGuard extends ConsumerWidget {
  const StaffRouteGuard({
    super.key,
    required this.child,
    this.requireAdmin = false,
    this.requireLiveOps = false,
  });

  final Widget child;
  final bool requireAdmin;
  final bool requireLiveOps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StaffState staff = ref.watch(staffProvider);
    // İlk staff doğrulaması — hub içi refresh'te child'ı unmount etme (tab loop).
    if (staff.isLoading && !staff.profile.isStaff) {
      return const SupportScreenShell(
        title: 'Staff',
        body: Center(child: CircularProgressIndicator(color: SettingsPalette.gold)),
      );
    }
    if (!staff.profile.isStaff ||
        (requireAdmin && !staff.profile.isAdmin) ||
        (requireLiveOps && !staff.profile.hasLiveOpsAccess)) {
      return SupportScreenShell(
        title: 'Yetkisiz',
        body: Center(
          child: SettingsGlassCard(
            accent: SettingsPalette.ruby,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Bu alana erişim yetkiniz yok.',
                  style: TextStyle(color: SettingsPalette.textMid),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SettingsPrimaryButton(
                  label: 'Ayarlara dön',
                  onPressed: () => context.go(AppRoutes.settings),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return child;
  }
}
