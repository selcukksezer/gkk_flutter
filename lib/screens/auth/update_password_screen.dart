import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../core/utils/auth_validators.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'widgets/auth_design.dart';
import 'widgets/auth_form_shell.dart';

enum _PasswordStrengthLevel {
  empty,
  weak,
  fair,
  strong,
  celestial,
}

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _hasHapticTriggeredMatch = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onFieldChanged);
    _confirmController.addListener(_onFieldChanged);

    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

      if (previous?.status == AuthStatus.loading &&
          next.status == AuthStatus.unauthenticated &&
          next.errorMessage == null) {
        AppMessenger.showSuccess(
          context,
          context.l10n.auth_update_password_success,
        );
        context.go(AppRoutes.login);
        return;
      }

      if (next.status == AuthStatus.error && next.errorMessage != null) {
        AppMessenger.showError(context, next.errorMessage!);
      }
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onFieldChanged);
    _confirmController.removeListener(_onFieldChanged);
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final String password = _passwordController.text;
    final String confirm = _confirmController.text;

    if (password.isNotEmpty &&
        confirm.isNotEmpty &&
        password == confirm &&
        !_hasHapticTriggeredMatch) {
      _hasHapticTriggeredMatch = true;
      HapticFeedback.selectionClick();
    } else if (password != confirm) {
      _hasHapticTriggeredMatch = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    await ref.read(authProvider.notifier).updatePassword(
          newPassword: _passwordController.text,
        );
  }

  // --- Password Strength Criteria ---
  bool get _hasMinLength =>
      _passwordController.text.length >= AuthValidators.minPasswordLength;

  bool get _hasLetter =>
      AuthValidators.passwordLetter.hasMatch(_passwordController.text);

  bool get _hasDigit =>
      AuthValidators.passwordDigit.hasMatch(_passwordController.text);

  bool get _hasUpperLower =>
      RegExp(r'[A-Z]').hasMatch(_passwordController.text) &&
      RegExp(r'[a-z]').hasMatch(_passwordController.text);

  bool get _hasSpecialOrLong =>
      RegExp(r'[!@#\$%^&*()_\-+=<>?/{}[\]~`]').hasMatch(_passwordController.text) ||
      _passwordController.text.length >= 12;

  _PasswordStrengthLevel get _strengthLevel {
    final String password = _passwordController.text;
    if (password.isEmpty) return _PasswordStrengthLevel.empty;

    int passedCount = 0;
    if (_hasMinLength) passedCount++;
    if (_hasLetter && _hasDigit) passedCount++;
    if (_hasUpperLower) passedCount++;
    if (_hasSpecialOrLong) passedCount++;

    if (!_hasMinLength || !_hasLetter || !_hasDigit) {
      return _PasswordStrengthLevel.weak;
    }

    switch (passedCount) {
      case 2:
        return _PasswordStrengthLevel.fair;
      case 3:
        return _PasswordStrengthLevel.strong;
      case 4:
        return _PasswordStrengthLevel.celestial;
      default:
        return _PasswordStrengthLevel.weak;
    }
  }

  int get _strengthActiveBars {
    switch (_strengthLevel) {
      case _PasswordStrengthLevel.empty:
        return 0;
      case _PasswordStrengthLevel.weak:
        return 1;
      case _PasswordStrengthLevel.fair:
        return 2;
      case _PasswordStrengthLevel.strong:
        return 3;
      case _PasswordStrengthLevel.celestial:
        return 4;
    }
  }

  Color get _strengthColor {
    switch (_strengthLevel) {
      case _PasswordStrengthLevel.empty:
        return Colors.white.withValues(alpha: 0.12);
      case _PasswordStrengthLevel.weak:
        return const Color(0xFFFF3366); // Cyber Crimson Neon
      case _PasswordStrengthLevel.fair:
        return const Color(0xFFF59E0B); // Arcane Amber
      case _PasswordStrengthLevel.strong:
        return const Color(0xFF38BDF8); // Arcane Cyan
      case _PasswordStrengthLevel.celestial:
        return const Color(0xFF10B981); // Emerald Celestial
    }
  }

  String _strengthLabel(bool isTr) {
    switch (_strengthLevel) {
      case _PasswordStrengthLevel.empty:
        return isTr ? 'BEKLENİYOR' : 'AWAITING';
      case _PasswordStrengthLevel.weak:
        return isTr ? 'ZAYIF MÜHÜR' : 'WEAK WARD';
      case _PasswordStrengthLevel.fair:
        return isTr ? 'ORTA KALKAN' : 'FAIR SHIELD';
      case _PasswordStrengthLevel.strong:
        return isTr ? 'GÜÇLÜ KORUMA' : 'STRONG AEGIS';
      case _PasswordStrengthLevel.celestial:
        return isTr ? 'KUSURSUZ MÜHÜR' : 'CELESTIAL SEAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final bool isLoading = authState.status == AuthStatus.loading;
    final AppLocalizations l10n = context.l10n;
    final bool isTr = Localizations.localeOf(context).languageCode == 'tr';

    final String password = _passwordController.text;
    final String confirm = _confirmController.text;
    final bool isConfirmNotEmpty = confirm.isNotEmpty;
    final bool isMatch = password.isNotEmpty && password == confirm;

    final Color confirmAccent = !isConfirmNotEmpty
        ? AuthDesign.gold
        : isMatch
            ? const Color(0xFF10B981)
            : const Color(0xFFFF3366);

    return AuthFormShell(
      kind: AuthScreenKind.updatePassword,
      badge: l10n.auth_update_password_title,
      title: l10n.krallik_kapisi,
      subtitle: l10n.auth_update_password_subtitle,
      sectionLabel: l10n.auth_form_section,
      footer: AuthGhostLink(
        label: l10n.giris_ekranina_don,
        enabled: !isLoading,
        onPressed: isLoading
            ? null
            : () {
                HapticFeedback.selectionClick();
                context.go(AppRoutes.login);
              },
        accent: AuthDesign.gold,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Password Field
            AuthField(
              controller: _passwordController,
              label: l10n.auth_password,
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              accent: _strengthLevel == _PasswordStrengthLevel.empty
                  ? AuthDesign.gold
                  : _strengthColor,
              validator: (String? value) =>
                  AuthValidators.validatePassword(value, l10n),
              suffix: IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                tooltip: _obscurePassword
                    ? l10n.auth_toggle_password_show
                    : l10n.auth_toggle_password_hide,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AuthDesign.titanium,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Frosted Glass Strength Indicator Shell
            _buildFrostedStrengthPanel(isTr),

            const SizedBox(height: AppSpacing.base),

            // Confirm Password Field
            AuthField(
              controller: _confirmController,
              label: l10n.auth_password_confirm,
              icon: Icons.verified_user_outlined,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              accent: confirmAccent,
              onFieldSubmitted: (_) {
                if (!isLoading) _submit();
              },
              validator: (String? value) => AuthValidators.validatePasswordConfirm(
                value,
                _passwordController.text,
                l10n,
              ),
              suffix: IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _obscureConfirm = !_obscureConfirm);
                },
                tooltip: _obscureConfirm
                    ? l10n.auth_toggle_password_show
                    : l10n.auth_toggle_password_hide,
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isConfirmNotEmpty
                      ? confirmAccent
                      : AuthDesign.titanium,
                  size: 20,
                ),
              ),
            ),

            // Realtime Confirmation Match Pill
            if (isConfirmNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _buildMatchPill(isMatch: isMatch, isTr: isTr),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Tactile Action Button
            AuthGoldButton(
              label: isLoading
                  ? l10n.auth_update_password_loading
                  : l10n.auth_update_password_button,
              loading: isLoading,
              icon: Icons.lock_reset_rounded,
              onPressed: isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedStrengthPanel(bool isTr) {
    final Color currentColor = _strengthColor;
    final int activeBars = _strengthActiveBars;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1D).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: currentColor.withValues(
                alpha: _strengthLevel == _PasswordStrengthLevel.empty ? 0.12 : 0.40,
              ),
              width: 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: currentColor.withValues(
                  alpha: _strengthLevel == _PasswordStrengthLevel.empty ? 0.0 : 0.12,
                ),
                blurRadius: 14,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header Row: Label & Tier Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: currentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isTr ? 'GÜVENLİK DERECESİ' : 'SECURITY LEVEL',
                        style: GoogleFonts.urbanist(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                          color: AuthDesign.textMid,
                        ),
                      ),
                    ],
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: currentColor.withValues(alpha: 0.55),
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      _strengthLabel(isTr),
                      style: GoogleFonts.urbanist(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: currentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 4 Segmented Neon Bars
              Row(
                children: List<Widget>.generate(4, (int index) {
                  final bool isActive = index < activeBars;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 3,
                        right: index == 3 ? 0 : 3,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: isActive
                              ? currentColor
                              : Colors.white.withValues(alpha: 0.08),
                          boxShadow: isActive
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: currentColor.withValues(alpha: 0.70),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Checklist Requirement Badges (2x2 Grid)
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildRequirementBadge(
                      label: isTr ? '8+ Karakter' : '8+ Characters',
                      met: _hasMinLength,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRequirementBadge(
                      label: isTr ? 'Harf ve Rakam' : 'Letter & Digit',
                      met: _hasLetter && _hasDigit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildRequirementBadge(
                      label: isTr ? 'Büyük/Küçük Harf' : 'Mixed Case',
                      met: _hasUpperLower,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRequirementBadge(
                      label: isTr ? 'Sembol veya 12+' : 'Symbol or 12+',
                      met: _hasSpecialOrLong,
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

  Widget _buildRequirementBadge({
    required String label,
    required bool met,
  }) {
    final Color badgeColor = met
        ? const Color(0xFF10B981)
        : AuthDesign.textLow;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: met
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: met
              ? const Color(0xFF10B981).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: badgeColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.urbanist(
                fontSize: 11,
                fontWeight: met ? FontWeight.w700 : FontWeight.w500,
                color: met ? AuthDesign.textHi : AuthDesign.textLow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchPill({
    required bool isMatch,
    required bool isTr,
  }) {
    final Color color = isMatch
        ? const Color(0xFF10B981)
        : const Color(0xFFFF3366);

    final String text = isMatch
        ? (isTr ? 'Şifreler başarıyla eşleşti' : 'Passwords match')
        : (isTr ? 'Şifreler henüz eşleşmiyor' : 'Passwords do not match');

    final IconData icon = isMatch
        ? Icons.verified_rounded
        : Icons.highlight_off_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.urbanist(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

