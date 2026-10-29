import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/screens/staff/staff_liveops_screen.dart';
import 'package:gkk_flutter/screens/staff/widgets/staff_portraits.dart';
import 'package:gkk_flutter/screens/support/widgets/support_design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StaffRank Enum & Properties', () {
    test('resolves grandmaster for admin/owner/grandmaster roles', () {
      expect(StaffRank.fromRole('admin'), StaffRank.grandmaster);
      expect(StaffRank.fromRole('super_admin'), StaffRank.grandmaster);
      expect(StaffRank.fromRole('owner'), StaffRank.grandmaster);
      expect(StaffRank.fromRole('grandmaster'), StaffRank.grandmaster);
      expect(StaffRank.grandmaster.title, 'GRANDMASTER');
      expect(StaffRank.grandmaster.accent, SettingsPalette.gold);
    });

    test('resolves leadArchon for gm/archon/master roles', () {
      expect(StaffRank.fromRole('gm'), StaffRank.leadArchon);
      expect(StaffRank.fromRole('lead_archon'), StaffRank.leadArchon);
      expect(StaffRank.fromRole('game_master'), StaffRank.leadArchon);
      expect(StaffRank.leadArchon.title, 'LEAD ARCHON');
      expect(StaffRank.leadArchon.accent, SettingsPalette.neon);
    });

    test('resolves warden for support/operator/null roles', () {
      expect(StaffRank.fromRole('support'), StaffRank.warden);
      expect(StaffRank.fromRole('operator'), StaffRank.warden);
      expect(StaffRank.fromRole(null), StaffRank.warden);
      expect(StaffRank.fromRole(''), StaffRank.warden);
      expect(StaffRank.warden.title, 'WARDEN');
      expect(StaffRank.warden.accent, SettingsPalette.coral);
    });
  });

  group('StaffRankBorderPainter & Avatar Frame', () {
    testWidgets('StaffRankAvatarFrame renders with Grandmaster rank', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StaffRankAvatarFrame(
                rank: StaffRank.grandmaster,
                size: 80,
                fallbackInitials: 'GM',
                isOnline: true,
                badgeText: 'GM',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StaffRankAvatarFrame), findsOneWidget);
      expect(find.text('GM'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('StaffRankAvatarFrame renders with Lead Archon rank', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StaffRankAvatarFrame(
                rank: StaffRank.leadArchon,
                size: 80,
                fallbackInitials: 'LA',
                isOnline: false,
                badgeText: 'ARCHON',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StaffRankAvatarFrame), findsOneWidget);
      expect(find.text('LA'), findsOneWidget);
      expect(find.text('ARCHON'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('StaffRankAvatarFrame renders with Warden rank', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StaffRankAvatarFrame(
                rank: StaffRank.warden,
                size: 80,
                fallbackInitials: 'WD',
                isOnline: true,
                badgeText: 'WARDEN',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StaffRankAvatarFrame), findsOneWidget);
      expect(find.text('WD'), findsOneWidget);
      expect(find.text('WARDEN'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  group('StaffPortraitCard', () {
    testWidgets('renders name, rank, and subtitle correctly', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StaffPortraitCard(
                name: 'SELÇUK ARCHON',
                rank: StaffRank.grandmaster,
                statusSubtitle: 'LiveOps Console Terminal Active',
                isOnline: true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('SELÇUK ARCHON'), findsOneWidget);
      expect(find.text('GRANDMASTER'), findsOneWidget);
      expect(find.text('LiveOps Console Terminal Active'), findsOneWidget);

      await tester.tap(find.text('SELÇUK ARCHON'));
      expect(tapped, isTrue);
    });
  });

  group('LiveOpsPulseNode & Telemetry Charts', () {
    testWidgets('LiveOpsPulseNode renders telemetry metrics and ripples', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiveOpsPulseNode(
                nodeName: 'AUTH & GATEWAY CLUSTER (EU-1)',
                latencyMs: 14,
                loadPercent: 32,
                accent: SettingsPalette.neon,
                statusText: 'OPERATIONAL',
              ),
            ),
          ),
        ),
      );

      expect(find.text('AUTH & GATEWAY CLUSTER (EU-1)'), findsOneWidget);
      expect(find.text('14ms · 32% load · OPERATIONAL'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('LiveOpsTelemetryChart renders sparkline waveform and current metric', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiveOpsTelemetryChart(
                title: 'Sunucu Gecikme Telemetrisi',
                currentMetric: '18.4',
                metricUnit: 'ms',
                subtitle: 'Son 60 saniye dinamik ping eğrisi',
                lineColor: SettingsPalette.neon,
                dataPoints: <double>[24, 22, 19, 18, 17, 21, 23, 19, 18, 16, 18, 19, 18.4],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sunucu Gecikme Telemetrisi'), findsOneWidget);
      expect(find.text('18.4'), findsOneWidget);
      expect(find.text('ms'), findsOneWidget);
      expect(find.text('Son 60 saniye dinamik ping eğrisi'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  group('StaffLiveOpsScreen Access & Architecture', () {
    testWidgets('shows unauthorized view when staff profile has no liveops access', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            staffProvider.overrideWith(
              (ref) => _FakeStaffNotifier(
                const StaffProfile(isStaff: false, role: 'user'),
              ),
            ),
          ],
          child: const MaterialApp(
            home: StaffLiveOpsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('LiveOps yetkisi yok'), findsOneWidget);
    });

    testWidgets('renders LiveOps console when profile is admin with telemetry and portraits', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            staffProvider.overrideWith(
              (ref) => _FakeStaffNotifier(
                const StaffProfile(
                  isStaff: true,
                  role: 'admin',
                  permissions: <String>['liveops.broadcast', 'liveops.daily_rewards', 'liveops.bp_season'],
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: StaffLiveOpsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header row check
      expect(find.text('LiveOps konsol'), findsOneWidget);

      // Staff Portrait Card in Overview tab
      expect(find.text('ADMIN'), findsWidgets);
      expect(find.text('GRANDMASTER'), findsWidgets);

      // Telemetry nodes in Overview tab
      expect(find.text('Telemetri Düğümleri'), findsOneWidget);
      expect(find.text('AUTH & GATEWAY CLUSTER (EU-1)'), findsOneWidget);
      expect(find.text('MATCHMAKER ENGINE & INSTANCE BUS'), findsOneWidget);

      // Telemetry charts in Overview tab
      expect(find.text('Sunucu Gecikme Telemetrisi'), findsOneWidget);
      expect(find.text('LiveOps İşlem Verimi'), findsOneWidget);

      // Maintenance card
      expect(find.text('Sunucu Bakım Yönetimi'), findsOneWidget);
      expect(find.text('DURUM: ÇEVRİMİÇİ (TÜM SERVİSLER AKTİF)'), findsOneWidget);
    });
  });
}

class _FakeStaffNotifier extends StaffNotifier {
  _FakeStaffNotifier(this._initialProfile);

  final StaffProfile _initialProfile;

  @override
  StaffState build() {
    return StaffState(
      profile: _initialProfile,
      loading: false,
      loaded: true,
    );
  }
}
