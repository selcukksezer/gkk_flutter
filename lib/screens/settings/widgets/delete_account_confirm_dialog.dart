import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/universal_game_dialog.dart';
import '../../../core/services/app_haptics.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'settings_design.dart';

/// Hesap silme — kullanıcı adı birebir eşleşmeden onay disabled.
Future<bool?> showDeleteAccountConfirmDialog(
  BuildContext context, {
  required String username,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.settingsDeleteAccountTitle,
    barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (
      BuildContext ctx,
      Animation<double> anim,
      Animation<double> secondary,
      Widget? child,
    ) {
      final double scale = Curves.easeOutBack.transform(anim.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: FadeTransition(
          opacity: anim,
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _DeleteAccountConfirmBody(username: username),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DeleteAccountConfirmBody extends StatefulWidget {
  const _DeleteAccountConfirmBody({required this.username});

  final String username;

  @override
  State<_DeleteAccountConfirmBody> createState() =>
      _DeleteAccountConfirmBodyState();
}

class _DeleteAccountConfirmBodyState extends State<_DeleteAccountConfirmBody> {
  late final TextEditingController _controller;
  String? _mismatchError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      if (_mismatchError != null) {
        setState(() => _mismatchError = null);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      _controller.text.trim() == widget.username;

  void _onConfirm() {
    if (!_matches) {
      AppHaptics.medium();
      setState(() {
        _mismatchError = context.l10n.settingsDeleteUsernameMismatch;
      });
      return;
    }
    AppHaptics.heavy();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool canConfirm = _matches;

    return Material(
      color: Colors.transparent,
      child: UniversalDialogPanel(
        borderColor: AppColors.mysticRuby.withValues(alpha: 0.55),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.mysticRuby.withValues(alpha: 0.18),
                    border: Border.all(
                      color: AppColors.mysticRuby.withValues(alpha: 0.55),
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.mysticRuby,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.settingsDeleteAccountTitle,
                    style: AppTextStyles.dialogTitle.copyWith(
                      color: SettingsPalette.textHi,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsDeleteAccountConfirm,
              style: AppTextStyles.dialogBody.copyWith(
                color: SettingsPalette.textMid,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.settingsDeleteUsernamePrompt(widget.username),
              style: AppTextStyles.caption.copyWith(
                color: SettingsPalette.titanium,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (canConfirm) _onConfirm();
              },
              style: AppTextStyles.body.copyWith(color: SettingsPalette.textHi),
              decoration: InputDecoration(
                hintText: widget.username,
                hintStyle: AppTextStyles.caption.copyWith(
                  color: SettingsPalette.titanium.withValues(alpha: 0.45),
                ),
                errorText: _mismatchError,
                filled: true,
                fillColor: SettingsPalette.obsidian.withValues(alpha: 0.65),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: SettingsPalette.titanium.withValues(alpha: 0.35),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: canConfirm
                        ? AppColors.mysticRuby
                        : SettingsPalette.gold.withValues(alpha: 0.7),
                    width: 1.4,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.mysticRuby),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.mysticRuby,
                    width: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: canConfirm ? 1 : 0.45,
              child: SettingsDangerButton(
                label: l10n.hesab_sil,
                icon: Icons.delete_forever_rounded,
                onPressed: canConfirm ? _onConfirm : null,
              ),
            ),
            const SizedBox(height: 8),
            SettingsOutlineButton(
              label: l10n.commonCancel,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
