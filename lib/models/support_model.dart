class SupportTicketSummary {
  const SupportTicketSummary({
    required this.id,
    required this.category,
    required this.subject,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.username,
  });

  final String id;
  final String category;
  final String subject;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? username;

  factory SupportTicketSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? key) {
      final dynamic raw = json[key];
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    return SupportTicketSummary(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: parse('created_at'),
      updatedAt: parse('updated_at'),
      username: json['username']?.toString(),
    );
  }
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.isStaff,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String body;
  final bool isStaff;
  final DateTime? createdAt;

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final dynamic raw = json['created_at'];
    if (raw is String) createdAt = DateTime.tryParse(raw);
    return SupportTicketMessage(
      id: (json['id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      isStaff: json['is_staff'] == true,
      createdAt: createdAt,
    );
  }
}

class BugReportSummary {
  const BugReportSummary({
    required this.id,
    required this.category,
    required this.title,
    required this.status,
    this.username,
    this.rewardGemsApproved,
    this.suggestedGems,
    this.reviewNote,
    this.description,
    this.reproSteps,
    this.createdAt,
  });

  final String id;
  final String category;
  final String title;
  final String status;
  final String? username;
  final int? rewardGemsApproved;
  final int? suggestedGems;
  final String? reviewNote;
  final String? description;
  final String? reproSteps;
  final DateTime? createdAt;

  factory BugReportSummary.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final dynamic raw = json['created_at'];
    if (raw is String) createdAt = DateTime.tryParse(raw);
    return BugReportSummary(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      username: json['username']?.toString(),
      rewardGemsApproved: (json['reward_gems_approved'] as num?)?.toInt(),
      suggestedGems: (json['suggested_gems'] as num?)?.toInt(),
      reviewNote: json['review_note']?.toString(),
      description: json['description']?.toString(),
      reproSteps: json['repro_steps']?.toString(),
      createdAt: createdAt,
    );
  }
}
