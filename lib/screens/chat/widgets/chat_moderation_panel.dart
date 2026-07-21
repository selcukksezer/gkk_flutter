import 'package:flutter/material.dart';

import '../chat_design_system.dart';
import '../chat_models.dart';

class ChatModerationPanel extends StatelessWidget {
  const ChatModerationPanel({
    super.key,
    required this.moderationState,
    required this.isLoading,
    required this.filterTermController,
    required this.filterReplacementController,
    required this.onCreateFilter,
    required this.onDeleteFilter,
  });

  final ChatModerationState moderationState;
  final bool isLoading;
  final TextEditingController filterTermController;
  final TextEditingController filterReplacementController;
  final VoidCallback onCreateFilter;
  final ValueChanged<String> onDeleteFilter;

  @override
  Widget build(BuildContext context) {
    if (!moderationState.permissions.canManageFilters) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
      decoration: BoxDecoration(
        gradient: ChatDesignSystem.gradientBgPanel,
        border: Border.all(color: ChatDesignSystem.colorWarning.withValues(alpha: 0.25), width: 1),
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusXl),
        boxShadow: ChatDesignSystem.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [ChatDesignSystem.colorWarning.withValues(alpha: 0.08), ChatDesignSystem.colorWarning.withValues(alpha: 0.02)]),
              border: Border(bottom: BorderSide(color: ChatDesignSystem.colorWarning.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.filter_list_rounded, size: 18, color: ChatDesignSystem.colorWarning),
                const SizedBox(width: ChatDesignSystem.spaceSm),
                const Text('Filtre Yönetimi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ChatDesignSystem.colorTextPrimary)),
                const Spacer(),
                if (isLoading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(ChatDesignSystem.colorWarning.withValues(alpha: 0.6))),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(flex: 2, child: _FilterTextField(controller: filterTermController, label: 'Filtrelenecek kelime')),
                    const SizedBox(width: ChatDesignSystem.spaceMd),
                    Expanded(flex: 1, child: _FilterTextField(controller: filterReplacementController, label: 'Yerine konan')),
                    const SizedBox(width: ChatDesignSystem.spaceMd),
                    _ModButton(onPressed: onCreateFilter, label: 'Ekle'),
                  ],
                ),
                if (moderationState.filters.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ChatDesignSystem.spaceMd),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: ChatDesignSystem.spaceMd),
                  Text(
                    'Aktif Filtreler (${moderationState.filters.length})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorTextTertiary),
                  ),
                  const SizedBox(height: ChatDesignSystem.spaceSm),
                  ...List.generate(moderationState.filters.length, (int idx) {
                    final ChatFilter f = moderationState.filters[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceSm),
                      child: Container(
                        padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '"${f.term}" → "${f.replacement}"',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorTextPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(f.scope, style: const TextStyle(fontSize: 10, color: ChatDesignSystem.colorTextTertiary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: ChatDesignSystem.spaceSm),
                            GestureDetector(
                              onTap: () => onDeleteFilter(f.id),
                              child: Container(
                                padding: const EdgeInsets.all(ChatDesignSystem.spaceXs),
                                decoration: BoxDecoration(
                                  color: ChatDesignSystem.colorError.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
                                ),
                                child: const Icon(Icons.close_rounded, size: 16, color: ChatDesignSystem.colorError),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12, color: ChatDesignSystem.colorTextPrimary),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(fontSize: 12, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceMd, vertical: ChatDesignSystem.spaceSm),
          isDense: true,
        ),
      ),
    );
  }
}

class _ModButton extends StatelessWidget {
  const _ModButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceLg, vertical: ChatDesignSystem.spaceSm),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [ChatDesignSystem.colorSuccess.withValues(alpha: 0.3), ChatDesignSystem.colorSuccess.withValues(alpha: 0.15)]),
          border: Border.all(color: ChatDesignSystem.colorSuccess.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_circle_outline_rounded, size: 14, color: ChatDesignSystem.colorSuccess),
            const SizedBox(width: ChatDesignSystem.spaceXs),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorSuccess)),
          ],
        ),
      ),
    );
  }
}
