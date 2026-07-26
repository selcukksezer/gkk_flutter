import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/support_model.dart';
import '../models/support_detail_model.dart';

class SupportNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<List<SupportTicketSummary>> loadMyTickets() async {
    final dynamic raw = await SupabaseService.client.rpc('get_my_tickets');
    if (raw is! Map || raw['success'] != true) return <SupportTicketSummary>[];
    return _parseTickets(raw['items']);
  }

  Future<List<BugReportSummary>> loadMyBugReports() async {
    final dynamic raw = await SupabaseService.client.rpc('get_my_bug_reports');
    if (raw is! Map || raw['success'] != true) return <BugReportSummary>[];
    return _parseBugs(raw['items']);
  }

  Future<String?> createTicket({
    required String category,
    required String subject,
    required String body,
  }) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'create_support_ticket',
        params: <String, dynamic>{
          'p_category': category,
          'p_subject': subject,
          'p_body': body,
        },
      );
      if (raw is Map && raw['success'] == false) {
        return raw['error']?.toString();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> submitBugReport({
    required String category,
    required String title,
    required String description,
    String? reproSteps,
  }) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'submit_bug_report',
        params: <String, dynamic>{
          'p_category': category,
          'p_title': title,
          'p_description': description,
          'p_repro_steps': reproSteps,
          'p_client_meta': <String, dynamic>{
            'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
            'locale': Platform.localeName,
          },
        },
      );
      if (raw is Map && raw['success'] == false) {
        return raw['error']?.toString();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> replyTicket(String ticketId, String body) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'reply_support_ticket',
        params: <String, dynamic>{'p_ticket_id': ticketId, 'p_body': body},
      );
      if (raw is Map && raw['success'] == false) return raw['error']?.toString();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<SupportTicketDetail?> loadTicketDetail(String ticketId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_support_ticket_detail',
        params: <String, dynamic>{'p_ticket_id': ticketId},
      );
      if (raw is Map && raw['success'] == true) {
        return SupportTicketDetail.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> staffReplyTicket(String ticketId, String body) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'staff_reply_ticket',
        params: <String, dynamic>{'p_ticket_id': ticketId, 'p_body': body},
      );
      if (raw is Map && raw['success'] == false) return raw['error']?.toString();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> staffUpdateTicketStatus(String ticketId, String status, {String? note}) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'staff_update_ticket_status',
        params: <String, dynamic>{
          'p_ticket_id': ticketId,
          'p_status': status,
          'p_note': note,
        },
      );
      if (raw is Map && raw['success'] == false) return raw['error']?.toString();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<BugReportDetail?> loadBugDetail(String reportId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'staff_get_bug_report_detail',
        params: <String, dynamic>{'p_report_id': reportId},
      );
      if (raw is Map && raw['success'] == true && raw['report'] is Map) {
        final Map<String, dynamic> payload = Map<String, dynamic>.from(raw['report'] as Map);
        payload['followups'] = raw['followups'];
        return BugReportDetail.fromJson(payload);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<PlayerBugReportDetail?> loadPlayerBugDetail(String reportId) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_player_bug_report_detail',
        params: <String, dynamic>{'p_report_id': reportId},
      );
      if (raw is Map && raw['success'] == true) {
        return PlayerBugReportDetail.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> appendBugFollowup(String reportId, String body) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'append_bug_report_followup',
        params: <String, dynamic>{'p_report_id': reportId, 'p_body': body},
      );
      if (raw is Map && raw['success'] == false) return raw['error']?.toString();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> staffUpdateBug(String reportId, String status, {String? note}) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'staff_update_bug_report',
        params: <String, dynamic>{
          'p_report_id': reportId,
          'p_status': status,
          'p_note': note,
        },
      );
      if (raw is Map && raw['success'] == false) return raw['error']?.toString();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> staffSuggestBugReward(String reportId, int gems, {String? note}) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'staff_suggest_bug_reward',
        params: <String, dynamic>{
          'p_report_id': reportId,
          'p_gems': gems,
          'p_note': note,
        },
      );
      if (raw is Map && raw['success'] == false) return raw['error']?.toString();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  List<SupportTicketSummary> _parseTickets(dynamic raw) {
    if (raw is! List) return <SupportTicketSummary>[];
    return raw
        .whereType<Map>()
        .map((Map m) => SupportTicketSummary.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  List<BugReportSummary> _parseBugs(dynamic raw) {
    if (raw is! List) return <BugReportSummary>[];
    return raw
        .whereType<Map>()
        .map((Map m) => BugReportSummary.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

final supportProvider = NotifierProvider<SupportNotifier, void>(SupportNotifier.new);
