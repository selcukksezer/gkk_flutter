import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/horse_race/horse_race_provider.dart';
import 'package:gkk_flutter/screens/horse_race/widgets/horse_bet_panel.dart';
import 'package:gkk_flutter/screens/horse_race/widgets/horse_recent_winners_panel.dart';
import 'package:gkk_flutter/screens/horse_race/widgets/horse_result_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const HorseRaceScript defaultScript = HorseRaceScript(
    durationMs: 8000,
    finishOrder: <String>['horse_1', 'horse_2'],
    winnerId: 'horse_1',
    keyframes: <HorseRaceKeyframe>[],
  );

  final List<HorseRaceEntry> testHorses = <HorseRaceEntry>[
    const HorseRaceEntry(
      horseId: 'horse_1',
      name: 'Gök Fırtınası',
      emoji: '⚡',
      laneColor: '#FFD700',
      goldMultiplier: 2.50,
      gemMultiplier: 2.50,
      winChancePct: 40.0,
      sortOrder: 1,
    ),
    const HorseRaceEntry(
      horseId: 'horse_2',
      name: 'Karanlık Gölge',
      emoji: '🌑',
      laneColor: '#00FFFF',
      goldMultiplier: 3.80,
      gemMultiplier: 3.80,
      winChancePct: 26.0,
      sortOrder: 2,
    ),
  ];

  final List<HorseRaceRecentWinner> testWinners = <HorseRaceRecentWinner>[
    const HorseRaceRecentWinner(
      roundId: 'round_100',
      winnerHorseId: 'horse_1',
      winnerName: 'Gök Fırtınası',
      winnerEmoji: '⚡',
    ),
    const HorseRaceRecentWinner(
      roundId: 'round_99',
      winnerHorseId: 'horse_2',
      winnerName: 'Karanlık Gölge',
      winnerEmoji: '🌑',
    ),
  ];

  group('HorseRecentWinnersPanel 2027 Glassmorphism', () {
    testWidgets('renders winner podium rows and expand button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HorseRecentWinnersPanel(winners: testWinners),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Son Kazananlar'), findsOneWidget);
      expect(find.text('Gök Fırtınası'), findsOneWidget);
      expect(find.text('Karanlık Gölge'), findsOneWidget);
      expect(find.text('1. KÜRSÜ'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.textContaining('ŞAMPİYON'), findsWidgets);
    });
  });

  group('HorseResultOverlay 2027 Glassmorphism', () {
    testWidgets('renders victory modal on win with payout', (
      WidgetTester tester,
    ) async {
      bool dismissed = false;

      final HorseRaceState state = HorseRaceState(
        loading: false,
        horses: testHorses,
        round: const HorseRaceRound(
          id: 'round_101',
          phase: HorseRacePhase.finished,
          secondsLeft: 0,
          winnerHorseId: 'horse_1',
          raceScript: defaultScript,
        ),
        uiPhase: HorseRaceUiPhase.result,
        myBet: const HorseRaceBet(
          horseId: 'horse_1',
          currencyType: 'gold',
          betAmount: 50000,
          multiplier: 2.50,
          won: true,
          payoutAmount: 125000,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            horseRaceProvider.overrideWith(() => _MockHorseRaceNotifier(state)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: <Widget>[
                  HorseResultOverlay(onDismiss: () => dismissed = true),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ŞAMPİYONLUK ZAFERİ'), findsOneWidget);
      expect(find.text('Gök Fırtınası'), findsOneWidget);
      expect(find.text('TOPLAM KAZANÇ'), findsOneWidget);
      expect(find.text('Tamam'), findsOneWidget);

      await tester.tap(find.text('Tamam'));
      expect(dismissed, isTrue);
    });
  });

  group('HorseBetPanel 2027 Glassmorphism', () {
    testWidgets('renders controls, currency toggle and horses', (
      WidgetTester tester,
    ) async {
      final HorseRaceState state = HorseRaceState(
        loading: false,
        horses: testHorses,
        round: const HorseRaceRound(
          id: 'round_102',
          phase: HorseRacePhase.betting,
          secondsLeft: 60,
          winnerHorseId: null,
          raceScript: defaultScript,
        ),
        uiPhase: HorseRaceUiPhase.bettingBoard,
        settings: const HorseRaceSettings(
          goldMinBet: 10000,
          goldMaxBet: 5000000,
          gemMinBet: 1,
          gemMaxBet: 50,
          goldMaxMultiplier: 12.0,
          gemMaxMultiplier: 12.0,
          bettingSeconds: 90,
          racingSeconds: 8,
          finishedSeconds: 10,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            horseRaceProvider.overrideWith(() => _MockHorseRaceNotifier(state)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HorseBetPanel(
                raceState: state,
                isBetting: true,
                bettingRoundId: 'round_102',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('horse_race_bet_controls')), findsOneWidget);
      expect(find.text('Altın'), findsOneWidget);
      expect(find.text('Elmas'), findsOneWidget);
      expect(find.text('Bahis Yap'), findsOneWidget);
      expect(find.text('Gök Fırtınası'), findsOneWidget);
      expect(find.text('Karanlık Gölge'), findsOneWidget);

      // Select horse 1
      await tester.tap(find.text('Gök Fırtınası'));
      await tester.pumpAndSettle();
      expect(find.text('SEÇİLDİ'), findsOneWidget);
    });
  });
}

class _MockHorseRaceNotifier extends HorseRaceNotifier {
  _MockHorseRaceNotifier(this._initial);

  final HorseRaceState _initial;

  @override
  HorseRaceState build() => _initial;

  @override
  Future<void> refresh({bool silent = false}) async {}
}
