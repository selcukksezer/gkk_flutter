#!/usr/bin/env python3
"""Generate audit fix checklist from page audit markdown reports."""

from __future__ import annotations

import json
import re
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIT_DIR = ROOT / "reports" / "audits" / "audit_2026-06-27"
PATTERNS_FILE = ROOT / "scripts" / "audit_cross_app_patterns.json"
OUTPUT_FILE = AUDIT_DIR / "TODO.md"
SUMMARY_FILE = AUDIT_DIR / "SUMMARY.md"

SKIP_FILES = {"SUMMARY.md", "TODO.md"}

# SUMMARY Top 10 manual priority overrides (title substring -> priority)
SUMMARY_PRIORITY_OVERRIDES: dict[str, str] = {
    "Trade": "P0",
    "Loot": "P0",
    "Chat": "P1",
    "Facility": "P1",
    "Guild war": "P1",
    "Logout": "P1",
    "DefensePowerBar": "P2",
    "Mekan modülü": "P2",
}

QA_GAPS = [
    (
        "/guild/monument/donate",
        "Loncasız hesap → yalnızca empty state; bağış formu render edilmedi",
    ),
    (
        "/facilities/farm",
        "Slug mismatch (farm ≠ farming) → üretim/yükseltme UI doğrulanmadı",
    ),
    (
        "/dungeon/battle",
        "Query params yok → savaş/zafer/hastane fazları yakalanmadı",
    ),
    (
        "/pvp/history",
        "Boş liste; dolu maç kartı ve filtre sonuçları yok",
    ),
    (
        "/pvp/tournament",
        "0 katılımcı; bracket dolu hali yok",
    ),
    (
        "/guild-war/tournament/:id",
        "0 lonca katılımcı; join CTA görünmedi",
    ),
    (
        "/my-mekan",
        "Mekan yok empty; 4 tab dolu hali yok",
    ),
    (
        "/mekans/:id",
        "Vitrin boş; satın alma sheet ve dolu grid yok",
    ),
    (
        "/mekans/:id/arena",
        "Sıralama sekmesi yok; qa_bot_* fixture",
    ),
    (
        "/guild-war/logs",
        "Empty state ve filtre-boş senaryo yok",
    ),
    (
        "/guild-war/territory/:id",
        "Savunma bar overflow; saldırılar fold altında",
    ),
    (
        "Cross-app",
        "Header `Hi` İngilizce; bottom nav `Home` İngilizce; ticker kesik",
    ),
]


@dataclass
class AuditItem:
    slug: str
    report_path: str
    item_type: str  # UI/UX | Kod/Refaktör
    title: str
    problem: str
    solution: str
    target_file: str | None = None
    priority: str = "P2"
    cross_app_id: str | None = None


@dataclass
class CrossAppBucket:
    pattern_id: str
    priority: str
    title: str
    solution: str
    target_file: str | None
    problems: list[str] = field(default_factory=list)
    affected_slugs: list[str] = field(default_factory=list)
    report_paths: list[str] = field(default_factory=list)


def load_patterns() -> list[dict]:
    with PATTERNS_FILE.open(encoding="utf-8") as f:
        return json.load(f)


def match_cross_app(text: str, patterns: list[dict]) -> str | None:
    combined = text.lower()
    for pattern in patterns:
        for kw in pattern["match_keywords"]:
            kw_lower = kw.lower()
            if kw_lower == "gamebottombar":
                # Avoid false match inside gameBottomBarClearance(...)
                if re.search(r"gamebottombar(?!clearance)", combined):
                    return pattern["id"]
                continue
            if kw_lower in combined:
                return pattern["id"]
    return None


def extract_header_info(content: str) -> tuple[str, str | None]:
    """Return (screen_name, dart_path)."""
    title_match = re.search(
        r"# 📦 DOSYA/SAYFA ANALİZİ:\s*(\w+)\s*\(`(lib/[^`)]+)`\)",
        content,
    )
    if title_match:
        return title_match.group(1), title_match.group(2)
    alt = re.search(r"`(lib/screens/[^`]+\.dart)`", content)
    if alt:
        return Path(alt.group(1)).stem, alt.group(1)
    return "Unknown", None


def parse_field(block_lines: list[str], field_name: str) -> str:
    prefix = f"* **{field_name}:**"
    for line in block_lines:
        if line.startswith(prefix):
            return line[len(prefix) :].strip()
    return ""


def split_items(section_text: str, start_pattern: str) -> list[list[str]]:
    """Split section into item blocks starting with start_pattern."""
    lines = section_text.splitlines()
    blocks: list[list[str]] = []
    current: list[str] = []

    for line in lines:
        if line.startswith(start_pattern):
            if current:
                blocks.append(current)
            current = [line]
        elif current:
            # Stop at code fence start for next structural element
            if line.startswith("## ") and not line.startswith("## 1.") and not line.startswith("## 2."):
                break
            current.append(line)

    if current:
        blocks.append(current)

    return blocks


def infer_priority(title: str, problem: str, item_type: str) -> str:
    combined = f"{title} {problem}"
    for key, prio in SUMMARY_PRIORITY_OVERRIDES.items():
        if key.lower() in combined.lower():
            return prio
    if item_type == "UI/UX":
        if any(
            w in combined.lower()
            for w in ("wcag", "dolandır", "prod", "bug", "yanlış route", "copy-paste")
        ):
            return "P1"
    if item_type == "Kod/Refaktör":
        if any(w in combined.lower() for w in ("security", "stale", "sync yok", "bypass")):
            return "P1"
    return "P2"


def parse_audit_file(path: Path, patterns: list[dict]) -> tuple[list[AuditItem], dict[str, CrossAppBucket]]:
    content = path.read_text(encoding="utf-8")
    slug = path.stem
    report_rel = f"reports/audits/audit_2026-06-27/{slug}.md"
    _, dart_path = extract_header_info(content)

    cross_buckets: dict[str, CrossAppBucket] = {}
    page_items: list[AuditItem] = []

    # Section 1
    sec1_match = re.search(
        r"## 1\. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI\n(.*?)(?=\n## 2\.|\Z)",
        content,
        re.DOTALL,
    )
    if sec1_match:
        blocks = split_items(sec1_match.group(1), "* **Sorunlu Bileşen/Yer:**")
        for block in blocks:
            title = parse_field(block, "Sorunlu Bileşen/Yer")
            problem = parse_field(block, "Hata Tanımı")
            solution = parse_field(block, "Kesin Çözüm ve Öneri")
            if not title or not problem:
                continue

            combined = f"{title} {problem} {solution}"
            cross_id = match_cross_app(combined, patterns)

            item = AuditItem(
                slug=slug,
                report_path=report_rel,
                item_type="UI/UX",
                title=title,
                problem=problem,
                solution=solution,
                target_file=dart_path,
                priority=infer_priority(title, problem, "UI/UX"),
                cross_app_id=cross_id,
            )

            if cross_id:
                if cross_id not in cross_buckets:
                    pat = next(p for p in patterns if p["id"] == cross_id)
                    cross_buckets[cross_id] = CrossAppBucket(
                        pattern_id=cross_id,
                        priority=pat["priority"],
                        title=pat["title"],
                        solution=pat["solution"],
                        target_file=pat.get("target_file"),
                    )
                bucket = cross_buckets[cross_id]
                if slug not in bucket.affected_slugs:
                    bucket.affected_slugs.append(slug)
                    bucket.report_paths.append(report_rel)
                if problem not in bucket.problems:
                    bucket.problems.append(problem)
            else:
                page_items.append(item)

    # Section 2
    sec2_match = re.search(
        r"## 2\. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR.*?\n(.*?)(?=\n---|\Z)",
        content,
        re.DOTALL,
    )
    if sec2_match:
        blocks = split_items(sec2_match.group(1), "* **Hatalı Kod Yapısı:**")
        for block in blocks:
            title = parse_field(block, "Hatalı Kod Yapısı")
            problem = parse_field(block, "Risk/Maliyet")
            if not title or not problem:
                continue

            # Solution from refactor comment in code block if present
            solution = ""
            refactor_match = re.search(r"// OLMASI GEREKEN[^\n]*\n(.+?)(?:\n```|\Z)", "\n".join(block), re.DOTALL)
            if refactor_match:
                solution = refactor_match.group(1).strip()[:200]
            if not solution:
                solution = "Bölüm 2 refactor önerisine bakınız."

            combined = f"{title} {problem} {solution}"
            cross_id = match_cross_app(combined, patterns)

            item = AuditItem(
                slug=slug,
                report_path=report_rel,
                item_type="Kod/Refaktör",
                title=title,
                problem=problem,
                solution=solution,
                target_file=dart_path,
                priority=infer_priority(title, problem, "Kod/Refaktör"),
                cross_app_id=cross_id,
            )

            if cross_id:
                if cross_id not in cross_buckets:
                    pat = next(p for p in patterns if p["id"] == cross_id)
                    cross_buckets[cross_id] = CrossAppBucket(
                        pattern_id=cross_id,
                        priority=pat["priority"],
                        title=pat["title"],
                        solution=pat["solution"],
                        target_file=pat.get("target_file"),
                    )
                bucket = cross_buckets[cross_id]
                if slug not in bucket.affected_slugs:
                    bucket.affected_slugs.append(slug)
                    bucket.report_paths.append(report_rel)
                if problem not in bucket.problems:
                    bucket.problems.append(problem)
            else:
                page_items.append(item)

    return page_items, cross_buckets


def merge_cross_bucket(
    existing: dict[str, CrossAppBucket], new: dict[str, CrossAppBucket]
) -> None:
    for cid, bucket in new.items():
        if cid not in existing:
            existing[cid] = CrossAppBucket(
                pattern_id=bucket.pattern_id,
                priority=bucket.priority,
                title=bucket.title,
                solution=bucket.solution,
                target_file=bucket.target_file,
                problems=list(bucket.problems),
                affected_slugs=list(bucket.affected_slugs),
                report_paths=list(bucket.report_paths),
            )
            continue
        target = existing[cid]
        for slug in bucket.affected_slugs:
            if slug not in target.affected_slugs:
                target.affected_slugs.append(slug)
        for rp in bucket.report_paths:
            if rp not in target.report_paths:
                target.report_paths.append(rp)
        for prob in bucket.problems:
            if prob not in target.problems:
                target.problems.append(prob)


def add_summary_p0_items(cross: dict[str, CrossAppBucket]) -> None:
    """Ensure SUMMARY Top 10 P0 items exist even if keyword match missed."""
    extras = [
        (
            "cross-trade-sync",
            "P0",
            "Trade karşı teklif realtime senkronu yok",
            "Supabase Realtime veya polling; Onayla disabled + Beta banner",
            "lib/screens/trade/trade_screen.dart",
            ["trade"],
        ),
        (
            "cross-loot-route-bug",
            "P0",
            "Loot currentRoute AppRoutes.shop copy-paste bug",
            "currentRoute: AppRoutes.loot olarak düzelt",
            "lib/screens/loot/loot_hub_screen.dart",
            ["loot"],
        ),
        (
            "cross-chat-chrome",
            "P1",
            "Chat GameChrome dışında — header/nav kopuk",
            "GameTopBar + GameBottomBar entegrasyonu veya chat-specific chrome",
            "lib/screens/chat/chat_screen.dart",
            ["chat"],
        ),
        (
            "cross-facility-slug",
            "P1",
            "Facility route slug farm ≠ farming",
            "Router alias farm→farming veya smoke manifest düzelt",
            "lib/routing/app_router.dart",
            ["facility_detail"],
        ),
        (
            "cross-guild-war-null",
            "P1",
            "Guild war tournament/territory null → SizedBox.shrink()",
            "Empty/error widget + geri CTA",
            "lib/screens/guild_war/tournament_detail_screen.dart",
            ["guild_war_tournament_detail", "guild_war_territory_detail"],
        ),
        (
            "cross-defense-bar-overflow",
            "P2",
            "DefensePowerBar current > max (2600/1000)",
            "clamp(current, 0, max) veya max değeri backend'den doğru çek",
            "lib/screens/guild_war/territory_detail_screen.dart",
            ["guild_war_territory_detail"],
        ),
    ]
    for pid, prio, title, solution, target, slugs in extras:
        if pid in cross:
            continue
        cross[pid] = CrossAppBucket(
            pattern_id=pid,
            priority=prio,
            title=title,
            solution=solution,
            target_file=target,
            problems=[title],
            affected_slugs=slugs,
            report_paths=[f"reports/audits/audit_2026-06-27/{s}.md" for s in slugs],
        )


def render_cross_section(cross: dict[str, CrossAppBucket]) -> str:
    lines = ["## A. Cross-App Düzeltmeler (tek fix, çok sayfa)", ""]
    order = {"P0": 0, "P1": 1, "P2": 2}
    sorted_items = sorted(cross.values(), key=lambda b: (order.get(b.priority, 9), b.title))

    for bucket in sorted_items:
        slug_links = ", ".join(
            f"[{s}.md](reports/audits/audit_2026-06-27/{s}.md)" for s in sorted(bucket.affected_slugs)
        )
        problem_text = bucket.problems[0] if bucket.problems else bucket.title
        if len(bucket.problems) > 1:
            problem_text += f" (+{len(bucket.problems) - 1} ek rapor varyasyonu)"

        lines.append(f"- [ ] **[{bucket.priority}] {bucket.title}**")
        lines.append(f"  - **Sorun:** {problem_text}")
        lines.append(f"  - **Çözüm:** {bucket.solution}")
        if bucket.target_file:
            lines.append(f"  - **Hedef dosya:** `{bucket.target_file}`")
        lines.append(f"  - **Etkilenen raporlar ({len(bucket.affected_slugs)}):** {slug_links}")
        lines.append("")

    return "\n".join(lines)


def render_page_section(page_items: dict[str, list[AuditItem]]) -> str:
    lines = ["## B. Sayfa Bazlı Düzeltmeler", ""]
    prio_order = {"P0": 0, "P1": 1, "P2": 2}

    for slug in sorted(page_items.keys()):
        items = page_items[slug]
        if not items:
            continue
        report_path = f"reports/audits/audit_2026-06-27/{slug}.md"
        screen = items[0].target_file or slug
        lines.append(f"### {slug} — [{slug}.md]({report_path})")
        if items[0].target_file:
            lines.append(f"**Kaynak kod:** `{items[0].target_file}`")
        lines.append("")

        sorted_items = sorted(items, key=lambda i: (prio_order.get(i.priority, 9), i.item_type, i.title))
        for idx, item in enumerate(sorted_items, 1):
            lines.append(f"- [ ] **[{item.priority} · {item.item_type}]** {item.title}")
            lines.append(f"  - **Sorun:** {item.problem}")
            lines.append(f"  - **Çözüm:** {item.solution}")
            lines.append(f"  - **Kaynak rapor:** [{slug}.md]({item.report_path})")
            if item.target_file:
                lines.append(f"  - **Hedef dosya:** `{item.target_file}`")
            lines.append("")

    return "\n".join(lines)


def render_qa_section() -> str:
    lines = [
        "## C. Screenshot QA Görevleri (fix değil — fixture/seed gerekir)",
        "",
        "Bu maddeler kod fix değil; screenshot doğrulaması için QA fixture gerektirir.",
        "",
    ]
    for route, desc in QA_GAPS:
        lines.append(f"- [ ] **{route}**")
        lines.append(f"  - **Sorun:** {desc}")
        lines.append(f"  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)")
        lines.append("")
    return "\n".join(lines)


def count_checkboxes(text: str) -> int:
    return text.count("- [ ]")


def main() -> None:
    patterns = load_patterns()
    all_page_items: dict[str, list[AuditItem]] = defaultdict(list)
    merged_cross: dict[str, CrossAppBucket] = {}

    audit_files = sorted(
        p for p in AUDIT_DIR.glob("*.md") if p.name not in SKIP_FILES
    )

    per_file_cross: list[dict[str, CrossAppBucket]] = []
    for path in audit_files:
        page_items, cross_buckets = parse_audit_file(path, patterns)
        all_page_items[path.stem].extend(page_items)
        per_file_cross.append(cross_buckets)

    for buckets in per_file_cross:
        merge_cross_bucket(merged_cross, buckets)

    add_summary_p0_items(merged_cross)

    cross_section = render_cross_section(merged_cross)
    page_section = render_page_section(all_page_items)
    qa_section = render_qa_section()

    cross_count = len(re.findall(r"^- \[ \]", cross_section, re.MULTILINE))
    page_count = sum(len(v) for v in all_page_items.values())
    qa_count = len(QA_GAPS)
    total = cross_count + page_count + qa_count

    p0 = p1 = p2 = 0
    for b in merged_cross.values():
        if b.priority == "P0":
            p0 += 1
        elif b.priority == "P1":
            p1 += 1
        else:
            p2 += 1
    for items in all_page_items.values():
        for item in items:
            if item.priority == "P0":
                p0 += 1
            elif item.priority == "P1":
                p1 += 1
            else:
                p2 += 1

    today = date.today().isoformat()
    header = f"""# GKK Flutter — Audit Fix Checklist

**Tarih:** {today}  
**Kaynak audit:** `reports/audits/audit_2026-06-27/`  
**İlerleme:** 0 / {total}  
**Üretim:** `python3 scripts/generate_audit_todo.py`

---

## Öncelik Özeti

| P0 | P1 | P2 | Cross-App | Sayfa Bazlı | QA Görevleri | Toplam |
|----|----|----|-----------|-------------|--------------|--------|
| {p0} | {p1} | {p2} | {cross_count} | {page_count} | {qa_count} | {total} |

> Cross-app maddeler tek fix ile birden fazla sayfayı kapatır. Tamamlandığında ilgili sayfa maddelerini de işaretleyin.

---

"""

    body = "\n".join([header, cross_section, "---", "", page_section, "---", "", qa_section])

    OUTPUT_FILE.write_text(body, encoding="utf-8")
    print(f"Wrote {OUTPUT_FILE}")
    print(f"  Cross-app: {cross_count}")
    print(f"  Page-specific: {page_count}")
    print(f"  QA tasks: {qa_count}")
    print(f"  Total checkboxes: {total}")
    print(f"  Audit files parsed: {len(audit_files)}")


if __name__ == "__main__":
    main()
