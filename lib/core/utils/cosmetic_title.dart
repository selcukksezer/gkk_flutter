/// Maps stored `users.cosmetic_title` keys to player-facing labels.
const Map<String, String> kCosmeticTitleLabels = <String, String>{
  'onur_nisani': 'Onur Nişanı',
  'kodex_ustasi': 'Kodex Ustası',
};

String? cosmeticTitleDisplayLabel(String? titleKey) {
  final String trimmed = titleKey?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return kCosmeticTitleLabels[trimmed] ?? trimmed;
}

bool hasCosmeticTitle(String? titleKey) =>
    cosmeticTitleDisplayLabel(titleKey) != null;
