const Map<String, String> _hospitalReasonLabels = <String, String>{
  'pvp_defeat': 'PvP mağlubiyeti',
  'pvp defeat': 'PvP mağlubiyeti',
  'pvp maçı kaybı': 'PvP maçı kaybı',
  'pvp maci kaybi': 'PvP maçı kaybı',
  'overdose': 'Aşırı doz',
  'arena maci kaybi': 'Arena maçı kaybı',
  'arena maci kaybı': 'Arena maçı kaybı',
  'han iksiri overdose': 'Han iksiri aşırı dozu',
  'dungeon_failure': 'Zindan yaralanması',
  'zindan başarısızlığı': 'Zindan yaralanması',
  'zindan yaralanması': 'Zindan yaralanması',
};

const Map<String, String> _prisonReasonLabels = <String, String>{
  'theft': 'Hırsızlık',
  'smuggling': 'Kaçakçılık',
  'assault': 'Saldırı',
  'legal_violation': 'Yasal ihlal',
  'yasal ihlal': 'Yasal ihlal',
};

const Map<String, String> _facilityTypeLabels = <String, String>{
  'farming': 'Çiftlik',
  'farm': 'Çiftlik',
  'mining': 'Maden',
  'mushroom_farm': 'Mantar çiftliği',
  'alchemy': 'Simya laboratuvarı',
  'blacksmith': 'Demirci',
  'tavern': 'Han',
  'warehouse': 'Depo',
};

String labelHospitalReason(String? raw) =>
    _labelRestrictionReason(raw, _hospitalReasonLabels, fallback: 'Zindan yaralanması');

String labelPrisonReason(String? raw) =>
    _labelRestrictionReason(raw, _prisonReasonLabels, fallback: 'Yasal ihlal');

String _labelRestrictionReason(
  String? raw,
  Map<String, String> labels, {
  required String fallback,
}) {
  if (raw == null || raw.trim().isEmpty) return fallback;

  final String trimmed = raw.trim();
  final String key = trimmed.toLowerCase();
  final String? exact = labels[key];
  if (exact != null) return exact;

  for (final MapEntry<String, String> entry in labels.entries) {
    if (key.contains(entry.key)) return entry.value;
  }

  final RegExp collectedPattern = RegExp(
    r'^Collected at ([^(\s]+(?:_[^(\s]+)*)\s*\(risk',
    caseSensitive: false,
  );
  final RegExpMatch? collectedMatch = collectedPattern.firstMatch(trimmed);
  if (collectedMatch != null) {
    final String facilityType = collectedMatch.group(1)!.trim().toLowerCase();
    final String facilityLabel =
        _facilityTypeLabels[facilityType] ?? _humanizeToken(facilityType);
    return 'Tesis toplama riski ($facilityLabel)';
  }

  if (key.startsWith('collected at ')) {
    final String facility = trimmed
        .replaceFirst(RegExp(r'^Collected at ', caseSensitive: false), '')
        .split('(')
        .first
        .trim()
        .toLowerCase();
    if (facility.isNotEmpty) {
      final String facilityLabel =
          _facilityTypeLabels[facility] ?? _humanizeToken(facility);
      return 'Tesis toplama riski ($facilityLabel)';
    }
    return 'Tesis toplama riski';
  }

  return _humanizeToken(trimmed);
}

String _humanizeToken(String raw) {
  final String normalized = raw.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return raw;
  return normalized[0].toUpperCase() + normalized.substring(1);
}
