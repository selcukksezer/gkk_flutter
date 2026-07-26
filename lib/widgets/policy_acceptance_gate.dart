import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/common/app_messenger.dart';
import '../models/policy_model.dart';
import '../providers/policy_provider.dart';
import '../routing/app_router.dart';
import '../screens/support/widgets/support_design.dart';
import '../theme/app_text_styles.dart';

/// Blocks gameplay until active legal docs are accepted.
class PolicyAcceptanceGate extends ConsumerStatefulWidget {
  const PolicyAcceptanceGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PolicyAcceptanceGate> createState() => _PolicyAcceptanceGateState();
}

class _PolicyAcceptanceGateState extends ConsumerState<PolicyAcceptanceGate> {
  final Set<String> _checked = <String>{};

  Future<void> _acceptAll() async {
    final String? err = await ref.read(policyProvider.notifier).acceptAll();
    if (!mounted) return;
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      setState(() => _checked.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final PolicyState policy = ref.watch(policyProvider);
    if (policy.isLoading || !policy.needsAcceptance) {
      return widget.child;
    }

    final List<LegalDocument> missingDocs = policy.documents.where((LegalDocument d) {
      final List<String> missing = policy.status?.missing ?? <String>[];
      return missing.contains(d.type);
    }).toList(growable: false);

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: SettingsPalette.void_.withValues(alpha: 0.78)),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: SettingsGlassCard(
              accent: SettingsPalette.gold,
              glow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SettingsSectionHeader(
                    icon: Icons.gavel_rounded,
                    title: 'Güncellenmiş sözleşmeler',
                    subtitle: 'Devam için oku + kabul et',
                    accent: SettingsPalette.gold,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: missingDocs.map((LegalDocument doc) {
                        final bool checked = _checked.contains(doc.type);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SettingsGlassCard(
                            accent: checked ? SettingsPalette.neon : SettingsPalette.obsidian,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Checkbox(
                                  value: checked,
                                  activeColor: SettingsPalette.gold,
                                  checkColor: SettingsPalette.void_,
                                  onChanged: (bool? v) => setState(() {
                                    if (v == true) {
                                      _checked.add(doc.type);
                                    } else {
                                      _checked.remove(doc.type);
                                    }
                                  }),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        doc.title,
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: SettingsPalette.textHi,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SettingsPressable(
                                        onTap: () => context.push('${AppRoutes.legal}/${doc.type}'),
                                        child: Text(
                                          'Oku →',
                                          style: supportCaptionStyle.copyWith(color: SettingsPalette.fuchsia),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SettingsPrimaryButton(
                    label: 'Kabul et ve devam et',
                    onPressed: missingDocs.every((LegalDocument d) => _checked.contains(d.type))
                        ? _acceptAll
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
