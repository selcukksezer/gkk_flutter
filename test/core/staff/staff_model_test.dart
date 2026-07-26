import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/models/staff_model.dart';

void main() {
  group('StaffProfile', () {
    test('admin has all permissions implicitly', () {
      const StaffProfile admin = StaffProfile(
        isStaff: true,
        role: 'admin',
        badge: 'admin',
        permissions: <String>[],
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.has('bug.approve_reward'), isTrue);
      expect(admin.hasLiveOpsAccess, isTrue);
    });

    test('gm only has explicit permissions', () {
      const StaffProfile gm = StaffProfile(
        isStaff: true,
        role: 'gm',
        badge: 'gm',
        permissions: <String>['ticket.view_all', 'liveops.broadcast'],
      );
      expect(gm.has('ticket.view_all'), isTrue);
      expect(gm.has('bug.approve_reward'), isFalse);
      expect(gm.hasLiveOpsAccess, isFalse);
    });

    test('StaffDashboard parses open_chat_reports', () {
      final StaffDashboard dash = StaffDashboard.fromJson(<String, dynamic>{
        'open_tickets': 2,
        'pending_bugs': 3,
        'open_chat_reports': 5,
        'recent_audit': <Map<String, dynamic>>[
          <String, dynamic>{'action': 'approve_bug', 'target_type': 'bug_report'},
        ],
      });
      expect(dash.openTickets, 2);
      expect(dash.pendingBugs, 3);
      expect(dash.openChatReports, 5);
      expect(dash.recentAudit, hasLength(1));
    });
  });
}
