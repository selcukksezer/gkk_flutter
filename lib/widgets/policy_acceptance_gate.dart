import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/legal/legal_document_content.dart';
import '../core/tutorial/tutorial_modal_suppress.dart';
import '../models/policy_model.dart';
import '../providers/policy_provider.dart';
import '../screens/legal/legal_document_reader_overlay.dart';
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
  final Set<String> _readTypes = <String>{};
  LegalDocument? _readingDoc;
  bool _accepting = false;
  String? _acceptError;

  @override
  void initState() {
    super.initState();
    // Heal stale Riverpod state after register/hot-reload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(policyProvider.notifier).refresh());
    });
  }

  Future<void> _acceptAll() async {
    if (_accepting) return;
    setState(() {
      _accepting = true;
      _acceptError = null;
    });
    final String? err = await ref.read(policyProvider.notifier).acceptAll();
    if (!mounted) return;
    setState(() => _accepting = false);
    if (err != null) {
      setState(() => _acceptError = err);
      return;
    }
    setState(() {
      _readTypes.clear();
      _acceptError = null;
    });
  }

  void _onDocumentFinished(String type) {
    setState(() {
      _readTypes.add(type);
      _readingDoc = null;
      _acceptError = null;
    });
  }

  bool _canAccept(List<LegalDocument> missingDocs) {
    if (missingDocs.isEmpty) return false;
    for (final LegalDocument doc in missingDocs) {
      if (!_readTypes.contains(doc.type)) return false;
    }
    return true;
  }

  String? _progressHint(List<LegalDocument> missingDocs) {
    if (missingDocs.isEmpty) return null;
    final int read = missingDocs
        .where((LegalDocument d) => _readTypes.contains(d.type))
        .length;
    if (read >= missingDocs.length) return null;
    return 'Okunan: $read / ${missingDocs.length} — kalan belgeleri Oku → ile bitir';
  }

  @override
  Widget build(BuildContext context) {
    final PolicyState policy = ref.watch(policyProvider);
    if (policy.isLoading || !policy.needsAcceptance) {
      return widget.child;
    }

    final List<String> missing =
        (policy.status?.missingForGameplay ?? <String>[]);
    final List<LegalDocument> missingDocs = missing
        .where((String type) => !kRegisterOnlyLegalDocTypes.contains(type))
        .map((String type) {
          for (final LegalDocument doc in policy.documents) {
            if (doc.type == type) return doc;
          }
          return LegalDocument(
            type: type,
            version: 1,
            title: LegalDocumentContent.resolve(
              LegalDocument(type: type, version: 1, title: '', bodyMd: ''),
            ).title,
            bodyMd: '',
          );
        })
        .toList(growable: false);

    if (missingDocs.isEmpty) {
      return widget.child;
    }

    final String? progressHint = _progressHint(missingDocs);

    return TutorialSuppressScope(
      active: true,
      child: Stack(
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
                      title: 'Sözleşmeler',
                      subtitle: 'Her belgeyi oku, sonuna kaydır, Okudum de',
                      accent: SettingsPalette.gold,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: missingDocs.map((LegalDocument doc) {
                          final LegalDocument resolved =
                              LegalDocumentContent.resolve(doc);
                          final bool read = _readTypes.contains(doc.type);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SettingsGlassCard(
                              accent: read
                                  ? SettingsPalette.neon
                                  : SettingsPalette.obsidian,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Icon(
                                    read
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: read
                                        ? SettingsPalette.neon
                                        : SettingsPalette.textMid,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          resolved.title,
                                          style: AppTextStyles.bodyBold.copyWith(
                                            color: SettingsPalette.textHi,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SettingsPressable(
                                          onTap: () => setState(
                                            () => _readingDoc = resolved,
                                          ),
                                          child: Text(
                                            read ? 'Tekrar oku →' : 'Oku →',
                                            style: supportCaptionStyle.copyWith(
                                              color: SettingsPalette.fuchsia,
                                            ),
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
                    if (progressHint != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        progressHint,
                        textAlign: TextAlign.center,
                        style: supportCaptionStyle.copyWith(
                          color: SettingsPalette.gold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (_acceptError != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _acceptError!,
                        textAlign: TextAlign.center,
                        style: supportCaptionStyle.copyWith(
                          color: SettingsPalette.ruby,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SettingsPrimaryButton(
                      label: 'Kabul et ve devam et',
                      loading: _accepting,
                      onPressed: _canAccept(missingDocs) && !_accepting
                          ? _acceptAll
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_readingDoc != null)
            LegalDocumentReaderOverlay(
              document: _readingDoc!,
              onFinished: _onDocumentFinished,
              onDismiss: () => setState(() => _readingDoc = null),
            ),
        ],
      ),
    );
  }
}
