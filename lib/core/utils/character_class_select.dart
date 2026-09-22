/// Interprets `select_character_class` RPC payload (no network).
enum CharacterClassSelectOutcome {
  success,
  alreadySelected,
  failed,
}

abstract final class CharacterClassSelect {
  static CharacterClassSelectOutcome interpretResponse(dynamic response) {
    if (response is! Map) {
      return CharacterClassSelectOutcome.failed;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(response);
    if (map['success'] == true) {
      return CharacterClassSelectOutcome.success;
    }

    final String error = (map['error']?.toString() ?? '').toLowerCase();
    final bool hasSelectedClass =
        (map['selected_class']?.toString() ?? '').trim().isNotEmpty;
    if (hasSelectedClass ||
        error.contains('zaten') ||
        error.contains('already')) {
      return CharacterClassSelectOutcome.alreadySelected;
    }
    return CharacterClassSelectOutcome.failed;
  }
}
