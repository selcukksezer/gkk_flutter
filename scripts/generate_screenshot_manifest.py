#!/usr/bin/env python3
"""Build manifest.json from captured PNGs in an audit screenshot folder."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Slug prefixes → route patterns (dynamic ids use resolved slug filenames).
SLUG_ROUTE_HINTS: dict[str, str] = {
    "splash": "/",
    "login": "/login",
    "register": "/register",
    "onboarding_character_select": "/onboarding/character-select",
    "home": "/home",
    "inventory": "/inventory",
    "character": "/character",
    "dungeon": "/dungeon",
    "dungeon_battle": "/dungeon/battle",
    "pvp": "/pvp",
    "pvp_history": "/pvp/history",
    "pvp_tournament": "/pvp/tournament",
    "leaderboard": "/leaderboard",
    "season": "/season",
    "guild": "/guild",
    "guild_war": "/guild-war",
    "guild_war_logs": "/guild-war/logs",
    "guild_monument": "/guild/monument",
    "guild_monument_donate": "/guild/monument/donate",
    "loot": "/loot",
    "horse_race": "/horse-race",
    "market": "/market",
    "shop": "/shop",
    "bank": "/bank",
    "trade": "/trade",
    "crafting": "/crafting",
    "enhancement": "/enhancement",
    "facilities": "/facilities",
    "facilities_farm": "/facilities/farm",
    "mekans": "/mekans",
    "mekans_create": "/mekans/create",
    "my_mekan": "/my-mekan",
    "quests": "/quests",
    "hospital": "/hospital",
    "prison": "/prison",
    "chat": "/chat",
    "settings": "/settings",
    "reputation": "/reputation",
}


def route_for_slug(slug: str) -> str:
    if slug in SLUG_ROUTE_HINTS:
        return SLUG_ROUTE_HINTS[slug]
    if slug.startswith("guild_war_tournament_"):
        tid = slug.removeprefix("guild_war_tournament_").replace("_", "-")
        return f"/guild-war/tournament/{tid}"
    if slug.startswith("guild_war_territory_"):
        tid = slug.removeprefix("guild_war_territory_").replace("_", "-")
        return f"/guild-war/territory/{tid}"
    if slug.endswith("_arena") and slug.startswith("mekans_"):
        mid = slug.removeprefix("mekans_").removesuffix("_arena").replace("_", "-")
        return f"/mekans/{mid}/arena"
    if slug.startswith("mekans_"):
        mid = slug.removeprefix("mekans_").replace("_", "-")
        return f"/mekans/{mid}"
    return f"/{slug.replace('_', '/')}"


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: generate_screenshot_manifest.py <output_dir> [device]", file=sys.stderr)
        return 1

    output_dir = Path(sys.argv[1]).resolve()
    device = sys.argv[2] if len(sys.argv) > 2 else "unknown"

    pngs = sorted(output_dir.glob("*.png"))
    entries = []
    for png in pngs:
        slug = png.stem
        entries.append(
            {
                "route": route_for_slug(slug),
                "slug": slug,
                "file": str(png),
                "bytes": png.stat().st_size,
                "status": "captured",
            }
        )

    manifest = {
        "run_id": datetime.now(timezone.utc).isoformat(),
        "output_dir": str(output_dir),
        "device": device,
        "captured": len(entries),
        "failed": 0,
        "failures": [],
        "screenshots": entries,
    }

    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {manifest_path} ({len(entries)} screenshots)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
