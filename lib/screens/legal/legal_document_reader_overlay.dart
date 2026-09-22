import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/legal/legal_document_content.dart';
import '../../models/policy_model.dart';
import '../../theme/app_text_styles.dart';
import '../support/widgets/support_design.dart';
import 'legal_document_body.dart';

/// Policy gate gibi Navigator dışı katmanlarda belge okuyucu.
/// Kabul checkbox'ı ancak metin sonuna kaydırılıp "Okudum" denince açılır.
class LegalDocumentReaderOverlay extends StatefulWidget {
  const LegalDocumentReaderOverlay({
    super.key,
    required this.document,
    required this.onFinished,
    required this.onDismiss,
  });

  final LegalDocument document;
  final ValueChanged<String> onFinished;
  final VoidCallback onDismiss;

  @override
  State<LegalDocumentReaderOverlay> createState() =>
      _LegalDocumentReaderOverlayState();
}

class _LegalDocumentReaderOverlayState extends State<LegalDocumentReaderOverlay> {
  late final ScrollController _scrollController = ScrollController()
    ..addListener(_onScroll);
  bool _reachedBottom = false;

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double max = _scrollController.position.maxScrollExtent;
    final bool atBottom =
        max <= 8 || _scrollController.offset >= max - 48;
    if (atBottom != _reachedBottom) {
      setState(() => _reachedBottom = atBottom);
    }
  }

  void _checkInitialScrollExtent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final LegalDocument resolved = LegalDocumentContent.resolve(widget.document);
    _checkInitialScrollExtent();

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  color: SettingsPalette.void_.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: widget.onDismiss,
                        icon: const Icon(Icons.close_rounded),
                        color: SettingsPalette.textHi,
                      ),
                      Expanded(
                        child: Text(
                          resolved.title,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: SettingsPalette.textHi,
                            fontSize: 17,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SettingsGlassCard(
                      accent: SettingsPalette.gold,
                      glow: true,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: LegalDocumentBody(
                        document: resolved,
                        scrollController: _scrollController,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _reachedBottom
                        ? 'Metni okuduktan sonra onaylayabilirsin.'
                        : 'Onay için metnin sonuna kaydır.',
                    textAlign: TextAlign.center,
                    style: supportCaptionStyle,
                  ),
                  const SizedBox(height: 8),
                  SettingsPrimaryButton(
                    label: 'Okudum',
                    onPressed: _reachedBottom
                        ? () => widget.onFinished(resolved.type)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
