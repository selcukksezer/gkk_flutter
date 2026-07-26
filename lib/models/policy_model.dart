class LegalDocument {
  const LegalDocument({
    required this.type,
    required this.version,
    required this.title,
    required this.bodyMd,
    this.publishedAt,
  });

  final String type;
  final int version;
  final String title;
  final String bodyMd;
  final DateTime? publishedAt;

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    DateTime? publishedAt;
    final dynamic raw = json['published_at'];
    if (raw is String && raw.isNotEmpty) {
      publishedAt = DateTime.tryParse(raw);
    }
    return LegalDocument(
      type: (json['type'] ?? json['doc_type'] ?? '').toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      title: (json['title'] ?? '').toString(),
      bodyMd: (json['body_md'] ?? '').toString(),
      publishedAt: publishedAt,
    );
  }
}

class PolicyStatus {
  const PolicyStatus({
    required this.allAccepted,
    required this.missing,
  });

  final bool allAccepted;
  final List<String> missing;

  factory PolicyStatus.fromJson(Map<String, dynamic> json) {
    final dynamic rawMissing = json['missing'];
    final List<String> missing = <String>[];
    if (rawMissing is List) {
      for (final dynamic item in rawMissing) {
        missing.add(item.toString());
      }
    }
    return PolicyStatus(
      allAccepted: json['all_accepted'] == true,
      missing: missing,
    );
  }
}
