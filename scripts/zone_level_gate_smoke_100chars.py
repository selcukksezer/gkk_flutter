#!/usr/bin/env python3
"""
Zone level-gate smoke: 100 distinct character profiles × varied dungeons.

Grounding (live Supabase snapshot 2026-07-31):
  - public.dungeon_zones.required_level
  - public.dungeons.xp_reward / energy_cost / power_requirement / zone
  - public.xp_needed_for_level(n) = floor(100 * n * (1 + n * 0.15))
  - level_cap = 70, avg max_energy ≈ 100

Does NOT call enter_dungeon / mutate DB — pure access + XP-path simulation
mirroring dungeon_zone_level_gate_error (level < required → block).

Usage:
  python3 scripts/zone_level_gate_smoke_100chars.py
  python3 scripts/zone_level_gate_smoke_100chars.py --out reports/zone_level_gate_smoke_100chars_20260731
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import random
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

SEED = 20260731
N_CHARS = 100
LEVEL_CAP = 70
DAILY_ENERGY = 100  # live users.max_energy avg

# Live dungeon_zones (2026-07-31)
ZONES = [
    {"zone": 1, "name": "Gölgeli Orman", "dungeon_min": 1, "dungeon_max": 10, "required_level": 1},
    {"zone": 2, "name": "Derin Mağara", "dungeon_min": 11, "dungeon_max": 20, "required_level": 15},
    {"zone": 3, "name": "Ateş Çölü", "dungeon_min": 21, "dungeon_max": 30, "required_level": 25},
    {"zone": 4, "name": "Fırtına Dağı", "dungeon_min": 31, "dungeon_max": 40, "required_level": 35},
    {"zone": 5, "name": "Yeraltı Cehennemi", "dungeon_min": 41, "dungeon_max": 50, "required_level": 45},
    {"zone": 6, "name": "Kırık Gökyüzü", "dungeon_min": 51, "dungeon_max": 60, "required_level": 55},
    {"zone": 7, "name": "Efsanevi Tehlikeler", "dungeon_min": 61, "dungeon_max": 65, "required_level": 65},
]

# Live public.dungeons (id, zone, order, xp, power, energy, boss)
DUNGEONS_RAW = [
    ("dng_001", 1, 1, 30, 0, 5, False),
    ("dng_002", 1, 2, 40, 1500, 5, False),
    ("dng_003", 1, 3, 50, 2500, 5, False),
    ("dng_004", 1, 4, 60, 3500, 6, False),
    ("dng_005", 1, 5, 75, 4500, 6, False),
    ("dng_006", 1, 6, 90, 5500, 6, False),
    ("dng_007", 1, 7, 105, 6500, 7, False),
    ("dng_008", 1, 8, 120, 7500, 7, False),
    ("dng_009", 1, 9, 140, 8500, 7, False),
    ("dng_010", 1, 10, 160, 10000, 8, True),
    ("dng_011", 2, 11, 180, 12000, 8, False),
    ("dng_012", 2, 12, 200, 14500, 8, False),
    ("dng_013", 2, 13, 225, 17000, 9, False),
    ("dng_014", 2, 14, 250, 19500, 9, False),
    ("dng_015", 2, 15, 280, 22000, 9, False),
    ("dng_016", 2, 16, 310, 25000, 10, False),
    ("dng_017", 2, 17, 340, 28000, 10, False),
    ("dng_018", 2, 18, 380, 31000, 10, False),
    ("dng_019", 2, 19, 420, 35000, 11, False),
    ("dng_020", 2, 20, 470, 40000, 12, True),
    ("dng_021", 3, 21, 520, 44000, 12, False),
    ("dng_022", 3, 22, 570, 50000, 12, False),
    ("dng_023", 3, 23, 630, 56000, 13, False),
    ("dng_024", 3, 24, 690, 62000, 13, False),
    ("dng_025", 3, 25, 760, 68000, 14, False),
    ("dng_026", 3, 26, 830, 74000, 14, False),
    ("dng_027", 3, 27, 910, 80000, 15, False),
    ("dng_028", 3, 28, 1000, 86000, 15, False),
    ("dng_029", 3, 29, 1100, 93000, 16, False),
    ("dng_030", 3, 30, 1200, 100000, 18, True),
    ("dng_031", 4, 31, 1320, 110000, 18, False),
    ("dng_032", 4, 32, 1450, 122000, 18, False),
    ("dng_033", 4, 33, 1590, 134000, 19, False),
    ("dng_034", 4, 34, 1750, 146000, 19, False),
    ("dng_035", 4, 35, 1920, 158000, 20, False),
    ("dng_036", 4, 36, 2110, 170000, 20, False),
    ("dng_037", 4, 37, 2320, 182000, 22, False),
    ("dng_038", 4, 38, 2550, 194000, 22, False),
    ("dng_039", 4, 39, 2800, 207000, 24, False),
    ("dng_040", 4, 40, 3080, 220000, 25, True),
    ("dng_041", 5, 41, 3380, 230000, 25, False),
    ("dng_042", 5, 42, 3720, 242000, 26, False),
    ("dng_043", 5, 43, 4090, 254000, 26, False),
    ("dng_044", 5, 44, 4500, 268000, 28, False),
    ("dng_045", 5, 45, 4950, 282000, 28, False),
    ("dng_046", 5, 46, 5440, 296000, 30, False),
    ("dng_047", 5, 47, 5990, 310000, 30, False),
    ("dng_048", 5, 48, 6580, 320000, 32, False),
    ("dng_049", 5, 49, 7240, 330000, 32, False),
    ("dng_050", 5, 50, 7960, 340000, 35, True),
    ("dng_051", 6, 51, 8760, 350000, 35, False),
    ("dng_052", 6, 52, 9630, 358000, 36, False),
    ("dng_053", 6, 53, 10590, 366000, 36, False),
    ("dng_054", 6, 54, 11650, 374000, 38, False),
    ("dng_055", 6, 55, 12810, 382000, 38, False),
    ("dng_056", 6, 56, 14100, 390000, 40, False),
    ("dng_057", 6, 57, 15500, 398000, 40, False),
    ("dng_058", 6, 58, 17050, 406000, 42, False),
    ("dng_059", 6, 59, 18750, 414000, 42, False),
    ("dng_060", 6, 60, 20650, 420000, 45, True),
    ("dng_061", 7, 61, 22700, 425000, 45, True),
    ("dng_062", 7, 62, 25000, 432000, 48, True),
    ("dng_063", 7, 63, 27500, 438000, 48, True),
    ("dng_064", 7, 64, 30200, 444000, 50, True),
    ("dng_065", 7, 65, 33200, 450000, 50, True),
]

# Softlock / grind thresholds (assumptions — see RAPOR)
# Softlock = stuck near a gate with weak farm path — NOT full 10-level band clear time.
PRE_GATE_WINDOW = 3  # levels immediately below next gate (e.g. 12–14 before Z2@15)
SOFTLOCK_DAYS_WARN = 4.0  # full-energy days from pre-gate window → next gate
SOFTLOCK_DAYS_FAIL = 10.0
DAYS_PER_LEVEL_WARN = 2.0  # single level-up via best open dungeon
MIN_OPEN_DUNGEONS_WARN = 3  # too few enterable dungeons in pre-gate window
# Rough power curve proxy: progressive toward zone mid power (NOT live formula)
POWER_SCALE = 5500


@dataclass(frozen=True)
class Dungeon:
    id: str
    zone: int
    order: int
    xp: int
    power: int
    energy: int
    is_boss: bool


@dataclass
class Character:
    cid: int
    level: int
    power: int
    class_name: str
    band: str


CLASSES = ("warrior", "mage", "rogue", "ranger", "paladin")


def xp_needed_for_level(level: int) -> int:
    """Mirror public.xp_needed_for_level."""
    if level is None or level < 1:
        return 0
    return int(math.floor(100 * level * (1 + level * 0.15)))


def total_xp_for_level(level: int) -> int:
    """Mirror public.total_xp_for_level — cumulative XP to REACH level."""
    if level is None or level <= 1:
        return 0
    return sum(xp_needed_for_level(i) for i in range(1, level))


def zone_required(zone: int) -> int:
    for z in ZONES:
        if z["zone"] == zone:
            return int(z["required_level"])
    return 1


def zone_open(player_level: int, zone: int) -> bool:
    return player_level >= zone_required(zone)


def gate_error(player_level: int, dungeon: Dungeon) -> Optional[dict]:
    """Mirror dungeon_zone_level_gate_error — None = allowed."""
    req = zone_required(dungeon.zone)
    if player_level < req:
        return {
            "success": False,
            "error_code": "zone_level_gate",
            "required_level": req,
            "zone": dungeon.zone,
        }
    return None


def build_dungeons() -> List[Dungeon]:
    return [
        Dungeon(id=r[0], zone=r[1], order=r[2], xp=r[3], power=r[4], energy=r[5], is_boss=r[6])
        for r in DUNGEONS_RAW
    ]


def level_band(level: int) -> str:
    if level <= 14:
        return "01-14_Z1_only"
    if level <= 24:
        return "15-24_Z1-2"
    if level <= 34:
        return "25-34_Z1-3"
    if level <= 44:
        return "35-44_Z1-4"
    if level <= 54:
        return "45-54_Z1-5"
    if level <= 64:
        return "55-64_Z1-6"
    return "65-70_all"


def rough_power(level: int, rng: random.Random) -> int:
    """Proxy only — not live combat power. Spreads ±25% around level*POWER_SCALE."""
    base = int(level * POWER_SCALE)
    jitter = rng.uniform(0.75, 1.25)
    return max(0, int(base * jitter))


def sample_levels(n: int, rng: random.Random) -> List[int]:
    """Spread 100 levels across 1–70 with extra mass near gate edges."""
    levels: List[int] = []
    # Gate-edge stress: 14,15,24,25,34,35,44,45,54,55,64,65 (+ neighbors)
    edges = [1, 2, 5, 10, 13, 14, 15, 16, 20, 23, 24, 25, 26, 30, 33, 34, 35, 36,
             40, 43, 44, 45, 46, 50, 53, 54, 55, 56, 60, 63, 64, 65, 66, 70]
    for e in edges:
        levels.append(e)
    # Uniform fill for remaining
    while len(levels) < n:
        levels.append(rng.randint(1, LEVEL_CAP))
    rng.shuffle(levels)
    return levels[:n]


def next_gate_after(level: int) -> Optional[Tuple[int, int]]:
    """Return (zone, required_level) of next locked zone, or None if all open."""
    for z in ZONES:
        if level < z["required_level"]:
            return z["zone"], z["required_level"]
    return None


def accessible_dungeons(level: int, dungeons: Sequence[Dungeon]) -> List[Dungeon]:
    return [d for d in dungeons if zone_open(level, d.zone)]


def xp_to_reach(from_level: int, to_level: int) -> int:
    """XP needed starting at from_level (0 progress) to reach to_level."""
    if to_level <= from_level:
        return 0
    return sum(xp_needed_for_level(l) for l in range(from_level, to_level))


def farm_metrics(level: int, dungeons: Sequence[Dungeon]) -> dict:
    open_ds = accessible_dungeons(level, dungeons)
    if not open_ds:
        return {
            "open_dungeons": 0,
            "open_zones": [],
            "best_xp": 0,
            "best_dungeon": None,
            "best_energy": None,
            "daily_runs": 0,
            "daily_xp": 0,
            "xp_to_next_level": xp_needed_for_level(level) if level < LEVEL_CAP else 0,
            "runs_to_next_level": None,
            "days_to_next_level": None,
            "next_gate": None,
            "xp_to_next_gate": None,
            "days_to_next_gate": None,
            "in_pre_gate_window": False,
            "softlock": "HARD_NO_CONTENT",
        }

    # Prefer highest XP among open; if power proxy matters, prefer beatable
    best = max(open_ds, key=lambda d: d.xp)
    daily_runs = max(0, DAILY_ENERGY // max(best.energy, 1))
    daily_xp = daily_runs * best.xp
    xp_next = xp_needed_for_level(level) if level < LEVEL_CAP else 0
    runs_next = math.ceil(xp_next / best.xp) if best.xp and xp_next else 0
    days_next = (xp_next / daily_xp) if daily_xp and xp_next else 0.0

    ng = next_gate_after(level)
    if ng is None:
        xp_gate = 0
        days_gate = 0.0
        gate_label = None
    else:
        _, req = ng
        xp_gate = xp_to_reach(level, req)
        days_gate = (xp_gate / daily_xp) if daily_xp else float("inf")
        gate_label = f"Z{ng[0]}@{req}"

    soft = "OK"
    in_pre_gate = False
    if ng is not None:
        _, req = ng
        in_pre_gate = (req - PRE_GATE_WINDOW) <= level < req
        # Softlock only judged in pre-gate window (or zero content).
        if in_pre_gate:
            if days_gate >= SOFTLOCK_DAYS_FAIL:
                soft = "FAIL_SLOW_TO_GATE"
            elif days_gate >= SOFTLOCK_DAYS_WARN:
                soft = "WARN_SLOW_TO_GATE"
            if len(open_ds) < MIN_OPEN_DUNGEONS_WARN:
                soft = "WARN_LOW_CONTENT" if soft == "OK" else soft
        # Any level: absurd single-level grind = warn (still can farm)
        if days_next >= DAYS_PER_LEVEL_WARN and soft == "OK":
            soft = "WARN_SLOW_LEVEL"

    open_zones = sorted({d.zone for d in open_ds})
    return {
        "open_dungeons": len(open_ds),
        "open_zones": open_zones,
        "best_xp": best.xp,
        "best_dungeon": best.id,
        "best_energy": best.energy,
        "daily_runs": daily_runs,
        "daily_xp": daily_xp,
        "xp_to_next_level": xp_next,
        "runs_to_next_level": runs_next,
        "days_to_next_level": round(days_next, 2),
        "next_gate": gate_label,
        "xp_to_next_gate": xp_gate,
        "days_to_next_gate": round(days_gate, 2) if days_gate != float("inf") else None,
        "in_pre_gate_window": in_pre_gate,
        "softlock": soft,
    }


def build_characters(rng: random.Random) -> List[Character]:
    levels = sample_levels(N_CHARS, rng)
    chars: List[Character] = []
    for i, lv in enumerate(levels, start=1):
        chars.append(
            Character(
                cid=i,
                level=lv,
                power=rough_power(lv, rng),
                class_name=rng.choice(CLASSES),
                band=level_band(lv),
            )
        )
    return chars


def attempt_plan(char: Character, dungeons: Sequence[Dungeon], rng: random.Random) -> List[Dungeon]:
    """Each char tries ~8 dungeons: mix open + locked zones."""
    by_zone: Dict[int, List[Dungeon]] = defaultdict(list)
    for d in dungeons:
        by_zone[d.zone].append(d)

    picks: List[Dungeon] = []
    open_z = [z["zone"] for z in ZONES if zone_open(char.level, z["zone"])]
    locked_z = [z["zone"] for z in ZONES if not zone_open(char.level, z["zone"])]

    for z in open_z:
        picks.append(rng.choice(by_zone[z]))
    # Always poke 2–3 locked zones if any
    for z in rng.sample(locked_z, k=min(3, len(locked_z))):
        picks.append(rng.choice(by_zone[z]))
    # Extra random variety
    while len(picks) < 8:
        picks.append(rng.choice(list(dungeons)))
    # Dedup preserve order
    seen = set()
    out: List[Dungeon] = []
    for d in picks:
        if d.id not in seen:
            seen.add(d.id)
            out.append(d)
    return out


def run_sim(out_dir: Path) -> dict:
    rng = random.Random(SEED)
    dungeons = build_dungeons()
    chars = build_characters(rng)

    attempt_rows: List[dict] = []
    char_rows: List[dict] = []
    false_pos = 0  # low level entered high zone
    false_neg = 0  # high level blocked wrongly
    allow_ok = 0
    deny_ok = 0

    for char in chars:
        farm = farm_metrics(char.level, dungeons)
        char_rows.append(
            {
                "char_id": char.cid,
                "level": char.level,
                "band": char.band,
                "class": char.class_name,
                "power_proxy": char.power,
                "open_zones": ",".join(str(z) for z in farm["open_zones"]),
                "open_dungeons": farm["open_dungeons"],
                "best_dungeon": farm["best_dungeon"],
                "best_xp": farm["best_xp"],
                "daily_xp": farm["daily_xp"],
                "xp_to_next_level": farm["xp_to_next_level"],
                "days_to_next_level": farm["days_to_next_level"],
                "next_gate": farm["next_gate"],
                "xp_to_next_gate": farm["xp_to_next_gate"],
                "days_to_next_gate": farm["days_to_next_gate"],
                "in_pre_gate_window": farm["in_pre_gate_window"],
                "softlock": farm["softlock"],
            }
        )

        for d in attempt_plan(char, dungeons, rng):
            err = gate_error(char.level, d)
            allowed = err is None
            should_allow = char.level >= zone_required(d.zone)
            # Model is exact mirror → FP/FN should be 0; still count for contract check
            if allowed and not should_allow:
                false_pos += 1
                verdict = "FALSE_POSITIVE"
            elif (not allowed) and should_allow:
                false_neg += 1
                verdict = "FALSE_NEGATIVE"
            elif allowed:
                allow_ok += 1
                verdict = "ALLOW_OK"
            else:
                deny_ok += 1
                verdict = "DENY_OK"

            # Secondary: power proxy hint (not enforced by zone gate)
            power_ok = char.power >= d.power
            attempt_rows.append(
                {
                    "char_id": char.cid,
                    "level": char.level,
                    "dungeon_id": d.id,
                    "zone": d.zone,
                    "zone_required": zone_required(d.zone),
                    "gate_allowed": allowed,
                    "verdict": verdict,
                    "xp_reward": d.xp,
                    "energy_cost": d.energy,
                    "power_req": d.power,
                    "power_proxy_ok": power_ok,
                }
            )

    # Band aggregates
    band_agg: Dict[str, dict] = {}
    by_band: Dict[str, List[dict]] = defaultdict(list)
    for row in char_rows:
        by_band[row["band"]].append(row)

    for band, rows in sorted(by_band.items()):
        days = [r["days_to_next_gate"] for r in rows if r["days_to_next_gate"] is not None]
        band_agg[band] = {
            "n_chars": len(rows),
            "levels": sorted({r["level"] for r in rows}),
            "open_zones_sample": rows[0]["open_zones"],
            "median_open_dungeons": sorted(r["open_dungeons"] for r in rows)[len(rows) // 2],
            "median_daily_xp": sorted(r["daily_xp"] for r in rows)[len(rows) // 2],
            "median_days_to_next_gate": (
                sorted(days)[len(days) // 2] if days else None
            ),
            "softlock_counts": dict(
                sorted(
                    {
                        k: sum(1 for r in rows if r["softlock"] == k)
                        for k in {r["softlock"] for r in rows}
                    }.items()
                )
            ),
            "worst_days_to_gate": max(days) if days else None,
        }

    # Level-by-level access matrix (1..70)
    access_matrix = []
    for lv in range(1, LEVEL_CAP + 1):
        m = farm_metrics(lv, dungeons)
        access_matrix.append(
            {
                "level": lv,
                "open_zones": m["open_zones"],
                "open_dungeons": m["open_dungeons"],
                "best_dungeon": m["best_dungeon"],
                "best_xp": m["best_xp"],
                "daily_xp": m["daily_xp"],
                "days_to_next_level": m["days_to_next_level"],
                "next_gate": m["next_gate"],
                "days_to_next_gate": m["days_to_next_gate"],
                "softlock": m["softlock"],
            }
        )

    # Pre-gate stress levels (last level before each gate + window starts)
    pre_gate_levels = [14, 24, 34, 44, 54, 64]
    pre_gate = {lv: farm_metrics(lv, dungeons) for lv in pre_gate_levels}
    # Full band clear times (info): start-of-band → next gate
    band_starts = [1, 15, 25, 35, 45, 55, 65]
    band_clear = {}
    for lv in band_starts:
        m = farm_metrics(lv, dungeons)
        band_clear[lv] = {
            "next_gate": m["next_gate"],
            "days_to_next_gate": m["days_to_next_gate"],
            "open_dungeons": m["open_dungeons"],
            "best_dungeon": m["best_dungeon"],
            "daily_xp": m["daily_xp"],
        }

    soft_fail = sum(1 for r in char_rows if r["softlock"].startswith("FAIL"))
    soft_warn = sum(1 for r in char_rows if r["softlock"].startswith("WARN"))
    soft_ok = sum(1 for r in char_rows if r["softlock"] == "OK")
    pre_gate_chars = [r for r in char_rows if r["in_pre_gate_window"]]

    # Healthy if: FP=0, FN=0, no FAIL softlocks, every pre-gate edge can farm + days < FAIL
    pre_gate_fail = any(
        (pre_gate[lv]["days_to_next_gate"] or 0) >= SOFTLOCK_DAYS_FAIL for lv in pre_gate_levels
    )
    can_always_farm = all(r["open_dungeons"] > 0 for r in char_rows)
    healthy = (
        false_pos == 0
        and false_neg == 0
        and soft_fail == 0
        and not pre_gate_fail
        and can_always_farm
        and all(pre_gate[lv]["open_dungeons"] > 0 for lv in pre_gate_levels)
    )

    # Threshold tweak suggestions if unhealthy / warn at pre-gate edges
    tweaks: List[str] = []
    for lv in pre_gate_levels:
        m = pre_gate[lv]
        days = m["days_to_next_gate"]
        if days is not None and days >= SOFTLOCK_DAYS_WARN:
            ng = m["next_gate"]
            tweaks.append(
                f"Lv{lv}: {days:.1f}d full-energy farm to {ng} via {m['best_dungeon']} "
                f"({m['best_xp']} XP/run). Consider lower next-gate OR more XP in open zones."
            )
    # Optional pacing note: longest band clear (not softlock)
    if band_clear:
        slowest = max(
            ((lv, v) for lv, v in band_clear.items() if v["days_to_next_gate"] is not None),
            key=lambda x: x[1]["days_to_next_gate"],
            default=None,
        )
        if slowest and slowest[1]["days_to_next_gate"] >= 20:
            tweaks.append(
                f"Pacing (not softlock): Lv{slowest[0]} → {slowest[1]['next_gate']} "
                f"≈ {slowest[1]['days_to_next_gate']}d dungeon-only. Quests/other XP unmodeled."
            )

    # Zone XP density for gap analysis
    zone_xp = []
    for z in ZONES:
        zd = [d for d in dungeons if d.zone == z["zone"]]
        zone_xp.append(
            {
                "zone": z["zone"],
                "name": z["name"],
                "required_level": z["required_level"],
                "dungeon_count": len(zd),
                "xp_min": min(d.xp for d in zd),
                "xp_max": max(d.xp for d in zd),
                "xp_avg": round(sum(d.xp for d in zd) / len(zd)),
                "energy_at_max_xp": max(zd, key=lambda d: d.xp).energy,
            }
        )

    summary = {
        "seed": SEED,
        "n_chars": N_CHARS,
        "n_attempts": len(attempt_rows),
        "allow_ok": allow_ok,
        "deny_ok": deny_ok,
        "false_positives": false_pos,
        "false_negatives": false_neg,
        "softlock_ok": soft_ok,
        "softlock_warn": soft_warn,
        "softlock_fail": soft_fail,
        "pre_gate_char_n": len(pre_gate_chars),
        "can_always_farm": can_always_farm,
        "healthy": healthy,
        "verdict": "HEALTHY" if healthy else "UNHEALTHY",
        "assumptions": {
            "daily_energy": DAILY_ENERGY,
            "xp_curve": "floor(100 * L * (1 + L * 0.15))",
            "farm_strategy": "always farm highest-XP enterable dungeon (ignore power/death)",
            "multipliers": "no monument/farm/class XP mult (base xp_reward only)",
            "other_xp_sources": "quests/craft/arena NOT modeled → dungeon-only lower bound",
            "pre_gate_window": PRE_GATE_WINDOW,
            "softlock_warn_days": SOFTLOCK_DAYS_WARN,
            "softlock_fail_days": SOFTLOCK_DAYS_FAIL,
            "days_per_level_warn": DAYS_PER_LEVEL_WARN,
        },
        "zones": ZONES,
        "zone_xp": zone_xp,
        "band_agg": band_agg,
        "pre_gate": {str(k): v for k, v in pre_gate.items()},
        "band_clear": {str(k): v for k, v in band_clear.items()},
        "tweaks": tweaks,
    }

    out_dir.mkdir(parents=True, exist_ok=True)

    with (out_dir / "characters.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(char_rows[0].keys()))
        w.writeheader()
        w.writerows(char_rows)

    with (out_dir / "attempts.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(attempt_rows[0].keys()))
        w.writeheader()
        w.writerows(attempt_rows)

    with (out_dir / "access_matrix.csv").open("w", newline="", encoding="utf-8") as f:
        # flatten open_zones
        flat = []
        for row in access_matrix:
            flat.append({**row, "open_zones": ",".join(str(z) for z in row["open_zones"])})
        w = csv.DictWriter(f, fieldnames=list(flat[0].keys()))
        w.writeheader()
        w.writerows(flat)

    with (out_dir / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    return summary


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--out",
        type=Path,
        default=Path("reports/zone_level_gate_smoke_100chars_20260731"),
    )
    args = ap.parse_args()
    summary = run_sim(args.out)
    print(json.dumps({
        "verdict": summary["verdict"],
        "healthy": summary["healthy"],
        "false_positives": summary["false_positives"],
        "false_negatives": summary["false_negatives"],
        "softlock_ok": summary["softlock_ok"],
        "softlock_warn": summary["softlock_warn"],
        "softlock_fail": summary["softlock_fail"],
        "can_always_farm": summary["can_always_farm"],
        "n_attempts": summary["n_attempts"],
        "tweaks": summary["tweaks"],
        "pre_gate_days": {
            k: v.get("days_to_next_gate") for k, v in summary["pre_gate"].items()
        },
        "band_clear_days": {
            k: v.get("days_to_next_gate") for k, v in summary["band_clear"].items()
        },
        "out": str(args.out),
    }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
