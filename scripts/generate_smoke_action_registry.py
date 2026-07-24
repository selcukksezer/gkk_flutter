#!/usr/bin/env python3
"""Generate lib/qa/smoke_action_registry_full.dart from reports/_ui_action_inventory.json."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / "reports" / "_ui_action_inventory.json"
OUT = ROOT / "lib" / "qa" / "smoke_action_registry_full.dart"

SCREEN_ROUTES: dict[str, str] = {
    "lib/screens/auth/login_screen.dart": "/login",
    "lib/screens/auth/register_screen.dart": "/register",
    "lib/screens/auth/character_select_screen.dart": "/onboarding/character-select",
    "lib/screens/auth/splash_screen.dart": "/",
    "lib/screens/bank/bank_screen.dart": "/bank",
    "lib/screens/character/character_screen.dart": "/character",
    "lib/screens/chat/chat_screen.dart": "/chat",
    "lib/screens/chat/chat_screen_new.dart": "/chat",
    "lib/screens/crafting/crafting_screen.dart": "/crafting",
    "lib/screens/dungeon/dungeon_battle_screen.dart": "/dungeon/battle",
    "lib/screens/dungeon/dungeon_screen.dart": "/dungeon",
    "lib/screens/dungeon/widgets/featured_cave_dungeon_card.dart": "/dungeon",
    "lib/screens/enhancement/enhancement_screen.dart": "/enhancement",
    "lib/screens/facilities/facilities_screen.dart": "/facilities",
    "lib/screens/facilities/facility_detail_screen.dart": "/facilities/farm",
    "lib/screens/guild/guild_monument_donate_screen.dart": "/guild/monument/donate",
    "lib/screens/guild/guild_monument_screen.dart": "/guild/monument",
    "lib/screens/guild/guild_screen.dart": "/guild",
    "lib/screens/guild_war/battle_result_screen.dart": "/guild-war",
    "lib/screens/guild_war/guild_war_defense_sheet.dart": "/guild-war",
    "lib/screens/guild_war/guild_war_hub_screen.dart": "/guild-war",
    "lib/screens/guild_war/territory_detail_screen.dart": "/guild-war/territory/sample-id",
    "lib/screens/guild_war/tournament_detail_screen.dart": "/guild-war/tournament/sample-id",
    "lib/screens/guild_war/war_logs_screen.dart": "/guild-war/logs",
    "lib/screens/guild_war/widgets/guild_war_empty_state.dart": "/guild-war",
    "lib/screens/guild_war/widgets/guild_war_sub_screen_scaffold.dart": "/guild-war",
    "lib/screens/guild_war/widgets/kingdom_election_panel.dart": "/guild-war",
    "lib/screens/guild_war/widgets/territory_card.dart": "/guild-war",
    "lib/screens/guild_war/widgets/territory_map_view.dart": "/guild-war",
    "lib/screens/guild_war/widgets/tournament_card.dart": "/guild-war",
    "lib/screens/home/home_screen.dart": "/home",
    "lib/screens/home/widgets/sticky_action_bar.dart": "/home",
    "lib/screens/hospital/hospital_screen.dart": "/hospital",
    "lib/screens/inventory/inventory_screen.dart": "/inventory",
    "lib/screens/leaderboard/leaderboard_screen.dart": "/leaderboard",
    "lib/screens/loot/loot_chest_widgets.dart": "/loot",
    "lib/screens/loot/loot_hub_screen.dart": "/loot",
    "lib/screens/market/widgets/market_browse_tab.dart": "/market",
    "lib/screens/market/widgets/market_listing_card.dart": "/market",
    "lib/screens/market/widgets/market_my_market_tab.dart": "/market",
    "lib/screens/market/widgets/market_price_edit_sheet.dart": "/market",
    "lib/screens/market/widgets/market_quantity_sheet.dart": "/market",
    "lib/screens/market/widgets/market_sell_tab.dart": "/market",
    "lib/screens/market/widgets/market_tab_bar.dart": "/market",
    "lib/screens/mekans/mekan_arena_screen.dart": "/mekans/sample-id/arena",
    "lib/screens/mekans/mekan_create_screen.dart": "/mekans/create",
    "lib/screens/mekans/mekan_detail_screen.dart": "/mekans/sample-id",
    "lib/screens/mekans/mekans_screen.dart": "/mekans",
    "lib/screens/mekans/my_mekan_screen.dart": "/my-mekan",
    "lib/screens/mekans/widgets/mekan_design.dart": "/mekans/sample-id",
    "lib/screens/mekans/widgets/mekan_scaffold.dart": "/mekans",
    "lib/screens/prison/prison_screen.dart": "/prison",
    "lib/screens/pvp/pvp_history_screen.dart": "/pvp/history",
    "lib/screens/pvp/pvp_screen.dart": "/pvp",
    "lib/screens/pvp/pvp_tournament_screen.dart": "/pvp/tournament",
    "lib/screens/quests/quests_screen.dart": "/quests",
    "lib/screens/reputation/reputation_screen.dart": "/reputation",
    "lib/screens/season/season_screen.dart": "/season",
    "lib/screens/settings/settings_screen.dart": "/settings",
    "lib/screens/shop/shop_screen.dart": "/shop",
    "lib/screens/trade/trade_screen.dart": "/trade",
}

SKIP_RPCS = {"delete_account"}
SKIP_SCREEN_PATTERNS = (
    "splash_screen",
    "login_screen",
    "register_screen",
)
DEVICE_SKIP_KEYWORDS = ("camera", "photo", "gallery", "image_picker", "microphone")


def slug(screen: str) -> str:
    base = screen.split("/")[-1].replace(".dart", "")
    return re.sub(r"[^a-z0-9_]+", "_", base.lower())


def infer_route(screen: str) -> str:
    if screen in SCREEN_ROUTES:
        return SCREEN_ROUTES[screen]
    if "/widgets/" in screen:
        parent = screen.split("/widgets/")[0] + ".dart"
        if parent in SCREEN_ROUTES:
            return SCREEN_ROUTES[parent]
    raise KeyError(f"No route mapping for {screen}")


def coverage_for(screen: str, index: int, rpcs: list[str]) -> tuple[str, str | None, str | None]:
    if any(p in screen for p in SKIP_SCREEN_PATTERNS):
        return "skip", None, "auth_flow_manual"
    if index <= len(rpcs):
        rpc = rpcs[index - 1]
        if rpc in SKIP_RPCS:
            return "skip", rpc, "destructive_rpc"
        return "rpc", rpc, None
    if "settings_screen" in screen and index >= 6:
        return "skip", None, "destructive_or_device"
    return "auto_tap", None, None


def main() -> None:
    data = json.loads(INVENTORY.read_text(encoding="utf-8"))
    entries: list[dict] = []

    for screen, meta in sorted(data.items()):
        actions = int(meta.get("actions") or 0)
        if actions <= 0:
            continue
        route = infer_route(screen)
        rpcs = list(meta.get("rpcs") or [])
        screen_slug = slug(screen)
        for i in range(1, actions + 1):
            coverage, rpc, skip_reason = coverage_for(screen, i, rpcs)
            entries.append(
                {
                    "id": f"{screen_slug}.action_{i:02d}",
                    "screen": screen,
                    "route": route,
                    "index": i,
                    "coverage": coverage,
                    "rpc": rpc,
                    "skip_reason": skip_reason,
                }
            )

    total = len(entries)
    if total != 350:
        raise SystemExit(f"Expected 350 actions, got {total}")

    lines = [
        "// GENERATED by scripts/generate_smoke_action_registry.py — do not edit.",
        "// Source: reports/_ui_action_inventory.json",
        "",
        "class SmokeActionEntry {",
        "  const SmokeActionEntry({",
        "    required this.id,",
        "    required this.screenFile,",
        "    required this.route,",
        "    required this.actionIndex,",
        "    required this.coverage,",
        "    this.rpcName,",
        "    this.skipReason,",
        "  });",
        "",
        "  final String id;",
        "  final String screenFile;",
        "  final String route;",
        "  final int actionIndex;",
        "  /// auto_tap | rpc | skip",
        "  final String coverage;",
        "  final String? rpcName;",
        "  final String? skipReason;",
        "}",
        "",
        "class SmokeActionRegistryFull {",
        "  const SmokeActionRegistryFull._();",
        "",
        f"  static const int totalActionCount = {total};",
        "",
        "  static const List<SmokeActionEntry> allActions = <SmokeActionEntry>[",
    ]

    for e in entries:
        rpc = f"'{e['rpc']}'" if e["rpc"] else "null"
        skip = f"'{e['skip_reason']}'" if e["skip_reason"] else "null"
        lines.append(
            "    SmokeActionEntry("
            f"id: '{e['id']}', "
            f"screenFile: '{e['screen']}', "
            f"route: '{e['route']}', "
            f"actionIndex: {e['index']}, "
            f"coverage: '{e['coverage']}', "
            f"rpcName: {rpc}, "
            f"skipReason: {skip}),"
        )

    lines.extend(
        [
            "  ];",
            "",
            "  static List<SmokeActionEntry> byCoverage(String coverage) =>",
            "      allActions.where((SmokeActionEntry a) => a.coverage == coverage).toList();",
            "",
            "  static int get autoTapCount => byCoverage('auto_tap').length;",
            "  static int get rpcCount => byCoverage('rpc').length;",
            "  static int get skipCount => byCoverage('skip').length;",
            "",
            "  static List<String> get uniqueRpcNames {",
            "    final Set<String> seen = <String>{};",
            "    for (final SmokeActionEntry a in allActions) {",
            "      if (a.rpcName != null) seen.add(a.rpcName!);",
            "    }",
            "    return seen.toList()..sort();",
            "  }",
            "}",
            "",
        ]
    )

    OUT.write_text("\n".join(lines), encoding="utf-8")
    auto = sum(1 for e in entries if e["coverage"] == "auto_tap")
    rpc = sum(1 for e in entries if e["coverage"] == "rpc")
    skip = sum(1 for e in entries if e["coverage"] == "skip")
    print(f"Wrote {OUT} — total={total} auto_tap={auto} rpc={rpc} skip={skip}")


if __name__ == "__main__":
    main()
