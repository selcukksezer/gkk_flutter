/// Single tutorial coach-mark step definition.
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.route,
    this.requiresPrior = const <String>[],
    this.isCore = false,
    this.isDaily = false,
    this.dayNumber,
  });

  final String id;
  final String title;
  final String body;
  final String? primaryLabel;
  final String? route;
  final List<String> requiresPrior;
  final bool isCore;
  final bool isDaily;
  final int? dayNumber;
}

/// Routes used as tutorial triggers.
abstract final class TutorialRoutes {
  static const String home = '/home';
  static const String dungeon = '/dungeon';
  static const String inventory = '/inventory';
  static const String character = '/character';
  static const String enhancement = '/enhancement';
  static const String bank = '/bank';
  static const String market = '/market';
  static const String shop = '/shop';
  static const String hospital = '/hospital';
  static const String prison = '/prison';
  static const String season = '/season';
  static const String quests = '/quests';
  static const String crafting = '/crafting';
  static const String facilities = '/facilities';
  static const String pvp = '/pvp';
  static const String guild = '/guild';
  static const String guildWar = '/guild-war';
  static const String dungeonSiegeHub = '/dungeon/siege';
  static const String horseRace = '/horse-race';
  static const String mekans = '/mekans';
  static const String myMekan = '/my-mekan';
  static const String trade = '/trade';
}
