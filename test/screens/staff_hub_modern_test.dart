import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/screens/staff/widgets/staff_design.dart';
import 'package:gkk_flutter/screens/support/widgets/support_design.dart';

void main() {
  group('StaffRoleTier & StaffRoleBadge (2027 Aion 2 Standard)', () {
    test('role tier parsing and mapping', () {
      expect(StaffRoleTier.fromString('admin'), StaffRoleTier.administrator);
      expect(StaffRoleTier.fromString('ADMINISTRATOR'), StaffRoleTier.administrator);
      expect(StaffRoleTier.fromString('gm'), StaffRoleTier.gm);
      expect(StaffRoleTier.fromString('gamemaster'), StaffRoleTier.gm);
      expect(StaffRoleTier.fromString('support'), StaffRoleTier.support);
      expect(StaffRoleTier.fromString('destek'), StaffRoleTier.support);
      expect(StaffRoleTier.fromString('unknown_role'), StaffRoleTier.operator);
      expect(StaffRoleTier.fromString(null), StaffRoleTier.support);

      expect(StaffRoleTier.administrator.displayName, 'ADMINISTRATOR');
      expect(StaffRoleTier.gm.displayName, 'GAME MASTER');
      expect(StaffRoleTier.support.displayName, 'SUPPORT SPECIALIST');
      expect(StaffRoleTier.operator.displayName, 'OPERATOR');

      expect(StaffRoleTier.administrator.tierCode, contains('ARCHON'));
      expect(StaffRoleTier.gm.tierCode, contains('SENTINEL'));
      expect(StaffRoleTier.support.tierCode, contains('CURATOR'));
      expect(StaffRoleTier.operator.tierCode, contains('OBSERVER'));
    });

    testWidgets('renders full and compact StaffRoleBadge', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                StaffRoleBadge(tier: StaffRoleTier.administrator),
                StaffRoleBadge(tier: StaffRoleTier.gm, compact: true),
                StaffRoleBadge(tier: StaffRoleTier.support, compact: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ADMINISTRATOR'), findsOneWidget);
      expect(find.text('RANK 01 · ARCHON'), findsOneWidget);
      expect(find.text('GAME MASTER'), findsOneWidget);
      expect(find.text('SUPPORT SPECIALIST'), findsOneWidget);
    });
  });

  group('StaffConsoleCard & StaffCommandActionTile', () {
    testWidgets('renders StaffConsoleCard with child and border styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaffConsoleCard(
              accent: SettingsPalette.gold,
              child: Text('Console Active'),
            ),
          ),
        ),
      );

      expect(find.text('Console Active'), findsOneWidget);
    });

    testWidgets('StaffCommandActionTile responds to tap and displays badges', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffCommandActionTile(
              title: 'Elmas Onay Konsolu',
              subtitle: 'GM talep kuyruğu',
              icon: Icons.diamond_outlined,
              badgeText: '5 BEKLEYEN',
              badgeColor: SettingsPalette.gold,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Elmas Onay Konsolu'), findsOneWidget);
      expect(find.text('GM talep kuyruğu'), findsOneWidget);
      expect(find.text('5 BEKLEYEN'), findsOneWidget);

      await tester.tap(find.text('Elmas Onay Konsolu'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('StaffTelemetryHud & StaffHeroBanner', () {
    testWidgets('StaffTelemetryHud triggers stat shortcuts', (WidgetTester tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffTelemetryHud(
              openTickets: 7,
              pendingBugs: 4,
              openChatReports: 2,
              onTicketsTap: () => tappedIndex = 0,
              onBugsTap: () => tappedIndex = 1,
              onChatReportsTap: () => tappedIndex = 2,
            ),
          ),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('TELEMETRY SYNC · ONLINE'), findsOneWidget);

      await tester.tap(find.text('Ticket'));
      await tester.pumpAndSettle();
      expect(tappedIndex, 0);

      await tester.tap(find.text('Bug'));
      await tester.pumpAndSettle();
      expect(tappedIndex, 1);

      await tester.tap(find.text('Rapor'));
      await tester.pumpAndSettle();
      expect(tappedIndex, 2);
    });

    testWidgets('StaffHeroBanner displays luminous role and operational header', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StaffHeroBanner(
                isAdmin: true,
                roleTier: StaffRoleTier.administrator,
                openTickets: 12,
                pendingBugs: 3,
                openChatReports: 1,
              ),
            ),
          ),
        ),
      );

      expect(find.text('ADMIN KOMUTA MATRİSİ'), findsOneWidget);
      expect(find.text('ADMINISTRATOR'), findsOneWidget);
      expect(find.text('CANLI MODERASYON'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('StaffTabStrip with tabBadges', () {
    testWidgets('StaffTabStrip renders tab badges and triggers selection', (WidgetTester tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffTabStrip(
              tabs: StaffDesign.hubTabs,
              selectedIndex: selected,
              tabBadges: const <int, int>{
                2: 8,
                3: 5,
              },
              onSelected: (int idx) => selected = idx,
            ),
          ),
        ),
      );

      expect(find.text('ÖZET'), findsOneWidget);
      expect(find.text('TICKET'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.text('TICKET'));
      await tester.pumpAndSettle();
      expect(selected, 2);
    });
  });
}
