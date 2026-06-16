#!/usr/bin/env python3
"""Second pass: catch remaining ScaffoldMessenger SnackBar patterns."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
PUBSPEC = ROOT / "pubspec.yaml"
PACKAGE = "gkk_flutter"
if PUBSPEC.exists():
    m = re.search(r"^name:\s*(\S+)", PUBSPEC.read_text(), re.M)
    if m:
        PACKAGE = m.group(1)
IMPORT = f"import 'package:{PACKAGE}/components/common/app_messenger.dart';"


def files_with_scaffold() -> list[Path]:
    out = subprocess.check_output(
        ["rg", "-l", r"ScaffoldMessenger\.of", str(LIB), "--glob", "!*.bak"],
        text=True,
    )
    return [Path(p) for p in out.strip().splitlines() if p]


def ensure_import(text: str) -> str:
    if "app_messenger.dart" in text:
        return text
    lines = text.splitlines(keepends=True)
    last_import = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    lines.insert(last_import + 1, IMPORT + "\n")
    return "".join(lines)


def classify(block: str) -> str:
    lower = block.lower()
    if any(k in lower for k in ("hata", "error", "basarisiz", "başarısız", "yetersiz", "red", "danger", "❌")):
        return "showError"
    if any(k in lower for k in ("green", "success", "✅", "🎉", "🏆", "başari", "basari", "alındı", "alindi", "tamamland", "başarılı")):
        return "showSuccess"
    if any(k in lower for k in ("orange", "warning", "uyari", "uyarı")):
        return "showWarning"
    return "show"


def extract_message(block: str) -> str | None:
    m = re.search(r"content:\s*Text\((.+?)\)\s*,?", block, re.DOTALL)
    if not m:
        return None
    return m.group(1).strip()


def replace_block(block: str) -> str:
    ctx = "context"
    ctx_m = re.search(r"ScaffoldMessenger\.of\(([^)]+)\)", block)
    if ctx_m:
        ctx = ctx_m.group(1).strip()
    msg = extract_message(block)
    if msg is None:
        return block
    fn = classify(block)
    return f"AppMessenger.{fn}({ctx}, {msg});"


def migrate(text: str) -> str:
    patterns = [
        r"ScaffoldMessenger\.of\([^)]+\)\s*\n\s*\.showSnackBar\(\s*SnackBar\([\s\S]*?\)\s*,?\s*\);",
        r"ScaffoldMessenger\.of\([^)]+\)\.showSnackBar\(\s*SnackBar\([\s\S]*?\)\s*,?\s*\);",
        r"ScaffoldMessenger\.of\([^)]+\)\.showSnackBar\(\s*const SnackBar\([\s\S]*?\)\s*,?\s*\);",
        r"if \(mounted\)\s+ScaffoldMessenger\.of\([^)]+\)\.showSnackBar\(\s*const SnackBar\([\s\S]*?\)\s*,?\s*\);",
        r"ScaffoldMessenger\.of\([^)]+\)\.showSnackBar\(\s*const SnackBar\([\s\S]*?\)\s*,?\s*\);",
    ]
    for pat in patterns:
        text = re.sub(pat, lambda m: replace_block(m.group(0)), text)
    # Inline one-liners in if blocks: if (x) { ScaffoldMessenger...; return; }
    text = re.sub(
        r"\{\s*ScaffoldMessenger\.of\([^)]+\)\.showSnackBar\(\s*const SnackBar\(content: Text\(([^)]+)\)\)\);\s*return;\s*\}",
        lambda m: f"{{ AppMessenger.showError(context, {m.group(1)}); return; }}",
        text,
    )
    return text


def main() -> None:
    changed = []
    for path in files_with_scaffold():
        original = path.read_text()
        text = ensure_import(original)
        text = migrate(text)
        if text != original:
            path.write_text(text)
            changed.append(path.relative_to(ROOT))
    print(f"Pass 2 migrated {len(changed)} files:")
    for p in changed:
        print(f"  - {p}")


if __name__ == "__main__":
    main()
