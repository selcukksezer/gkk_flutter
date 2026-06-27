#!/usr/bin/env python3
"""Migrate static UI strings inside build() methods only (skips const/static)."""
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
    "Tekrar Dene": "commonRetry",
    "İptal": "commonCancel",
    "Iptal": "commonCancel",
    "Oyuncu": "playerDefault",
    "Profil yüklenemedi.": "profileLoadFailed",
    "Profil yuklenemedi.": "profileLoadFailed",
    "Envanter yuklenemedi.": "envanter_yuklenemedi",
}


def load_value_to_key() -> dict[str, str]:
    en = json.loads(ARB.read_text(encoding="utf-8"))
    out: dict[str, str] = {}
    for key, val in en.items():
        if not key.startswith("@@"):
            out[val] = key
    out.update(MANUAL)
    return out


def import_line(path: Path) -> str:
    depth = len(path.relative_to(LIB).parts) - 1
    return f"import '{'../' * depth}l10n/l10n.dart';\n"


def extract_build_bodies(content: str) -> list[tuple[int, int]]:
    """Return (start, end) char offsets for build method bodies."""
    spans: list[tuple[int, int]] = []
    for m in re.finditer(
        r"Widget\s+build\s*\(\s*BuildContext\s+context[^)]*\)\s*\{",
        content,
    ):
        start = m.end()
        depth = 1
        i = start
        while i < len(content) and depth > 0:
            if content[i] == "{":
                depth += 1
            elif content[i] == "}":
                depth -= 1
            i += 1
        spans.append((start, i - 1))
    return spans


def migrate_file(path: Path, v2k: dict[str, str]) -> bool:
    original = path.read_text(encoding="utf-8")
    if "l10n/l10n.dart" in original and "context.l10n." in original:
        # already partially migrated
        pass

    spans = extract_build_bodies(original)
    if not spans:
        return False

    # work backwards to preserve offsets
    content = original
    changed = False
    for start, end in reversed(spans):
        body = content[start:end]
        new_body = body
        for s, key in sorted(v2k.items(), key=lambda x: -len(x[0])):
            if len(s) < 2 or "${" in s or "\n" in s:
                continue
            esc = re.escape(s)
            # skip if preceded by const on same statement-ish
            patterns = [
                (rf"Text\(\s*'{esc}'\s*\)", f"Text(context.l10n.{key})"),
                (rf"const\s+Text\(\s*'{esc}'\s*\)", f"Text(context.l10n.{key})"),
                (rf"label:\s*'{esc}'", f"label: context.l10n.{key}"),
                (rf"title:\s*'{esc}'", f"title: context.l10n.{key}"),
                (rf"subtitle:\s*'{esc}'", f"subtitle: context.l10n.{key}"),
                (rf"hintText:\s*'{esc}'", f"hintText: context.l10n.{key}"),
            ]
            for pat, repl in patterns:
                new_body2 = re.sub(pat, repl, new_body)
                if new_body2 != new_body:
                    new_body = new_body2
                    changed = True
        if new_body != body:
            content = content[:start] + new_body + content[end:]
            changed = True

    if not changed:
        return False

    if "context.l10n." in content and "l10n/l10n.dart" not in content:
        last = 0
        for im in re.finditer(r"^import [^;]+;\n", content, re.M):
            last = im.end()
        content = content[:last] + import_line(path) + content[last:]

    path.write_text(content, encoding="utf-8")
    return True


def main() -> None:
    v2k = load_value_to_key()
    changed = [p.relative_to(ROOT) for p in sorted(LIB.rglob("*.dart")) if "l10n" not in p.parts and migrate_file(p, v2k)]
    print(f"v2 migrated {len(changed)} files")


if __name__ == "__main__":
    main()
