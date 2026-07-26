import '../../models/support_model.dart';

class SupportTicketDetail {
  const SupportTicketDetail({
    required this.ticket,
    this.messages = const <SupportTicketMessage>[],
  });

  final SupportTicketSummary ticket;
  final List<SupportTicketMessage> messages;

  factory SupportTicketDetail.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> ticketJson =
        Map<String, dynamic>.from(json['ticket'] as Map? ?? json);
    final List<SupportTicketMessage> msgs = <SupportTicketMessage>[];
    final dynamic rawMsgs = json['messages'];
    if (rawMsgs is List) {
      for (final dynamic row in rawMsgs) {
        if (row is Map) {
          msgs.add(SupportTicketMessage.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    return SupportTicketDetail(
      ticket: SupportTicketSummary.fromJson(ticketJson),
      messages: msgs,
    );
  }
}

class BugReportDetail {
  const BugReportDetail({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    this.playerId,
    this.username,
    this.reproSteps,
    this.clientMeta,
    this.rewardGemsApproved,
    this.suggestedGems,
    this.reviewNote,
    this.createdAt,
    this.followups = const <BugReportFollowup>[],
  });

  final String id;
  final String category;
  final String title;
  final String description;
  final String status;
  final String? playerId;
  final String? username;
  final String? reproSteps;
  final Map<String, dynamic>? clientMeta;
  final int? rewardGemsApproved;
  final int? suggestedGems;
  final String? reviewNote;
  final DateTime? createdAt;
  final List<BugReportFollowup> followups;

  factory BugReportDetail.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final dynamic raw = json['created_at'];
    if (raw is String) createdAt = DateTime.tryParse(raw);
    return BugReportDetail(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      playerId: json['player_id']?.toString(),
      username: json['username']?.toString(),
      reproSteps: json['repro_steps']?.toString(),
      clientMeta: json['client_meta'] is Map
          ? Map<String, dynamic>.from(json['client_meta'] as Map)
          : null,
      rewardGemsApproved: (json['reward_gems_approved'] as num?)?.toInt(),
      suggestedGems: (json['suggested_gems'] as num?)?.toInt(),
      reviewNote: json['review_note']?.toString(),
      createdAt: createdAt,
      followups: BugReportFollowup.parseList(json['followups']),
    );
  }
}

class BugReportFollowup {
  const BugReportFollowup({
    required this.id,
    required this.body,
    required this.isStaff,
    this.createdAt,
  });

  final String id;
  final String body;
  final bool isStaff;
  final DateTime? createdAt;

  factory BugReportFollowup.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final dynamic raw = json['created_at'];
    if (raw is String) createdAt = DateTime.tryParse(raw);
    return BugReportFollowup(
      id: (json['id'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      isStaff: json['is_staff'] == true,
      createdAt: createdAt,
    );
  }

  static List<BugReportFollowup> parseList(dynamic raw) {
    if (raw is! List) return const <BugReportFollowup>[];
    return raw
        .whereType<Map>()
        .map((Map m) => BugReportFollowup.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

class PlayerBugReportDetail {
  const PlayerBugReportDetail({
    required this.report,
    this.followups = const <BugReportFollowup>[],
  });

  final BugReportSummary report;
  final List<BugReportFollowup> followups;

  factory PlayerBugReportDetail.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> reportJson =
        Map<String, dynamic>.from(json['report'] as Map? ?? json);
    return PlayerBugReportDetail(
      report: BugReportSummary.fromJson(reportJson),
      followups: BugReportFollowup.parseList(json['followups']),
    );
  }
}
