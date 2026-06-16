#!/usr/bin/env python3
"""One-off migration: ScaffoldMessenger SnackBar -> AppMessenger."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

IMPORT_LINE = "import 'package:gkk_mobile/components/common/app_messenger.dart';"

# Try to detect package name from pubspec
PUBSPEC = ROOT / "pubspec.yaml"
PACKAGE = "gkk_mobile"
if PUBSPEC.exists():
    m = re.search(r"^name:\s*(\S+)", PUBSPEC.read_text(), re.M)
    if m:
        PACKAGE = m.group(1)

IMPORT_LINE = f"import 'package:{PACKAGE}/components/common/app_messenger.dart';"


def dart_files() -> list[Path]:
    out = subprocess.check_output(
        ["rg", "-l", r"ScaffoldMessenger\.of", str(LIB)],
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
    insert_at = last_import + 1
    lines.insert(insert_at, IMPORT_LINE + "\n")
    return "".join(lines)


def replace_helpers(text: str) -> str:
    patterns = [
        (
            r"void _showSnack\(String message\) \{\s*if \(!mounted\) return;\s*ScaffoldMessenger\.of\(\s*context,?\s*\)\.showSnackBar\(\s*SnackBar\(content: Text\(message\)\),?\s*\);\s*\}",
            """void _showSnack(String message) {
    if (!mounted) return;
    AppMessenger.show(context, message);
  }""",
        ),
        (
            r"void _showSnack\(String msg\) \{\s*if \(!mounted\) return;\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(content: Text\(msg\), duration: const Duration\(seconds: 3\)\),\s*\);\s*\}",
            """void _showSnack(String msg) {
    if (!mounted) return;
    AppMessenger.show(context, msg);
  }""",
        ),
        (
            r"void _showSnack\(String message\) \{\s*// Intentionally disabled: user requested no bottom snackbar notifications\.\s*\}",
            """void _showSnack(String message) {
    if (!mounted) return;
    AppMessenger.show(context, message);
  }""",
        ),
        (
            r"void _showComingSoon\(String message\) \{\s*ScaffoldMessenger\.of\(\s*context,\s*\)\.showSnackBar\(SnackBar\(content: Text\(message\)\)\);\s*\}",
            """void _showComingSoon(String message) {
    AppMessenger.showInfo(context, message);
  }""",
        ),
        (
            r"void _snack\(String msg, \{bool isError = false\}\) \{\s*if \(!mounted\) return;\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(SnackBar\([^)]+\)\);\s*\}",
            """void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppMessenger.showError(context, msg);
    } else {
      AppMessenger.showSuccess(context, msg);
    }
  }""",
        ),
        (
            r"void _showSnack\(String msg\) \{\s*if \(!mounted\) return;\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\([^)]+\),\s*\);\s*\}",
            """void _showSnack(String msg) {
    if (!mounted) return;
    AppMessenger.show(context, msg);
  }""",
        ),
    ]
    for pattern, repl in patterns:
        text = re.sub(pattern, repl, text, flags=re.DOTALL)
    return text


def replace_inline_snackbars(text: str) -> str:
    # Multi-line ScaffoldMessenger.of(...).showSnackBar( ... );
    def replacer(match: re.Match[str]) -> str:
        block = match.group(0)
        # Extract Text('...') or Text("...")
        text_match = re.search(r"Text\(\s*'([^']*)'", block)
        if not text_match:
            text_match = re.search(r'Text\(\s*"([^"]*)"', block)
        if not text_match:
            text_match = re.search(r"Text\(\s*([^,)]+)\)", block)
        if not text_match:
            return block
        msg_expr = text_match.group(1) if text_match.lastindex else text_match.group(1)
        # If dynamic expression (contains $ or not simple string)
        raw = text_match.group(0)
        if "$" in raw or "const" not in block and not raw.startswith("Text( '"):
            # dynamic message
            dynamic = text_match.group(1) if "'" not in raw[:10] else None
            if dynamic is None:
                inner = re.search(r"Text\((.+?)\)", block, re.DOTALL)
                msg = inner.group(1).strip() if inner else "'Mesaj'"
            else:
                msg = dynamic
        else:
            msg = f"'{text_match.group(1)}'" if text_match.lastindex == 1 else text_match.group(1)

        is_error = any(
            k in block.lower()
            for k in (
                "red",
                "danger",
                "hata",
                "error",
                "basarisiz",
                "başarısız",
                "yetersiz",
            )
        )
        is_success = any(
            k in block.lower()
            for k in ("green", "success", "basari", "başari", "alındı", "alindi", "tamamland")
        )
        is_warning = "orange" in block.lower() or "warning" in block.lower()

        if is_error:
            fn = "AppMessenger.showError"
        elif is_success:
            fn = "AppMessenger.showSuccess"
        elif is_warning:
            fn = "AppMessenger.showWarning"
        else:
            fn = "AppMessenger.show"

        # Use full Text(...) expression for dynamic messages
        inner_match = re.search(r"content:\s*Text\((.+?)\),?", block, re.DOTALL)
        if inner_match:
            inner = inner_match.group(1).strip()
            if inner.startswith("'") or inner.startswith('"') or inner.startswith("const"):
                if inner.startswith("'") or inner.startswith('"'):
                    message_arg = inner
                else:
                    message_arg = inner.replace("const ", "")
            else:
                message_arg = inner
        else:
            message_arg = msg

        return f"{fn}(context, {message_arg});"

    pattern = r"ScaffoldMessenger\.of\([^)]*\)\.showSnackBar\(\s*SnackBar\([\s\S]*?\)\s*,?\s*\);"
    text = re.sub(pattern, replacer, text)
    # Chained variant: ScaffoldMessenger.of(context)\n        .showSnackBar(...)
    pattern2 = r"ScaffoldMessenger\.of\(\s*[^)]+\s*\)\s*\n\s*\.showSnackBar\(\s*SnackBar\([\s\S]*?\)\s*,?\s*\);"
    text = re.sub(pattern2, replacer, text)
    return text


def migrate_file(path: Path) -> bool:
    original = path.read_text()
    text = original
    text = ensure_import(text)
    text = replace_helpers(text)
    text = replace_inline_snackbars(text)
    if text != original:
        path.write_text(text)
        return True
    return False


def main() -> None:
    changed = []
    for path in dart_files():
        if migrate_file(path):
            changed.append(path.relative_to(ROOT))
    print(f"Migrated {len(changed)} files:")
    for p in changed:
        print(f"  - {p}")


if __name__ == "__main__":
    main()
