#!/usr/bin/env python3
"""Replace static UI strings in lib/ with context.l10n.* references."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
ARB = ROOT / "lib/l10n/app_en.arb"

MANUAL = {
    "Home": "routeHome",
    "Inventory": "routeInventory",
    "BATTLE PASS": "routeSeason",
    "👤 Karakter": "routeCharacter",
    "📜 Görevler": "routeQuests",
    "🤝 Ticaret": "routeTrade",
    "⚔ Lonca Savaşı": "routeGuildWar",
    "🏛️ Lonca Anıtı": "routeGuildMonument",
    "🏦 Banka": "routeBank",
    "Mağaza": "routeShop",
    "Pazar": "routeMarket",
    "Zanaat": "routeCrafting",
    "Lonca": "routeGuild",
    "Anıta Bağış Yap": "routeMonumentDonate",
    "Haftalık Turnuva": "routePvpTournament",
    "Sıralama": "routeLeaderboard",
    "Oyuncu": "playerDefault",
    "Tekrar Dene": "commonRetry",
    "İptal": "commonCancel",
    "Menü": "navMenu",
    "Ana Sayfa": "navHome",
    "Envanter": "navInventory",
    "Zindan": "navDungeon",
    "Karakter": "navCharacter",
}


def load_value_to_key() -> dict[str, str]:
    en = json.loads(ARB.read_text(encoding="utf-8"))
    value_to_key: dict[str, str] = {}
    priority = ("route", "nav", "common", "menu", "player", "app")
    for key, val in en.items():
        if key.startswith("@@"):
            continue
        if val not in value_to_key:
            value_to_key[val] = key
        else:
            existing = value_to_key[val]
            if any(key.startswith(p) for p in priority) and not any(
                existing.startswith(p) for p in priority
            ):
                value_to_key[val] = key
    value_to_key.update(MANUAL)
    return value_to_key


def import_line_for(path: Path) -> str:
    depth = len(path.relative_to(LIB).parts) - 1
    return f"import '{'../' * depth}l10n/l10n.dart';\n"


def migrate_file(path: Path, value_to_key: dict[str, str]) -> bool:
    original = path.read_text(encoding="utf-8")
    content = original

    for s, key in sorted(value_to_key.items(), key=lambda x: -len(x[0])):
        if len(s) < 2 or "${" in s or "\n" in s:
            continue
        esc = re.escape(s)

        text_pat = re.compile(rf"const\s+Text\(\s*'{esc}'\s*\)")
        content = text_pat.sub(f"Text(context.l10n.{key})", content)

        text_pat2 = re.compile(rf"Text\(\s*'{esc}'\s*\)")
        content = text_pat2.sub(f"Text(context.l10n.{key})", content)

        for field in ("label", "title", "subtitle", "hintText", "barrierLabel", "tooltip"):
            field_pat = re.compile(rf"{field}:\s*'{esc}'")
            content = field_pat.sub(f"{field}: context.l10n.{key}", content)

    if content == original:
        return False

    if "context.l10n." in content and "l10n/l10n.dart" not in content:
        imp = import_line_for(path)
        m = re.search(r"(import [^;]+;\n)", content)
        if m:
            insert_at = content.rfind("import ", 0, m.end()) 
            # after last import
            last_import = 0
            for im in re.finditer(r"^import [^;]+;\n", content, re.M):
                last_import = im.end()
            content = content[:last_import] + imp + content[last_import:]
        else:
            content = imp + content

    path.write_text(content, encoding="utf-8")
    return True


def main() -> None:
    value_to_key = load_value_to_key()
    changed = []
    for path in sorted(LIB.rglob("*.dart")):
        if "l10n" in path.parts or path.name.endswith(".g.dart"):
            continue
        if migrate_file(path, value_to_key):
            changed.append(str(path.relative_to(ROOT)))
    print(f"Migrated {len(changed)} files")
    for p in changed:
        print(f"  {p}")


if __name__ == "__main__":
    main()
