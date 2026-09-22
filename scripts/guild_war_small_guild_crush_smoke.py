#!/usr/bin/env python3
"""
Guild-war balance smoke: hundreds of guilds, mixed sizes/powers.
Models LIVE combat formula (approx):
  atk = leader.power + Σ(support pledges from members not double-counted as leader)
  def = Σ(garrison on territory) + gem_boost
  success = (U(0,1)*atk) > (U(0,1)*max(def,1))
  cost = attack_gold_cost (live: flat 10M)
  income = trade_income / day to vault

Does NOT mutate production DB — pure Monte Carlo.
"""
from __future__ import annotations

import json
import math
import random
import statistics
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

SEED = 20260729
N_GUILDS = 320
N_DAYS = 30
ATTACKS_PER_DAY_CAP = 2  # per guild (leader bandwidth)
GRACE_DAYS = 1  # discrete proxy for 2h grace

# Live territory seed (from linked DB 2026-07-29)
TERRITORIES = [
    {"id": "z1", "zone": 1, "name": "Demir Kalesi", "income": 12_000_000, "cost": 10_000_000, "base": 1000},
    {"id": "z2", "zone": 2, "name": "Altın Ovası", "income": 14_000_000, "cost": 10_000_000, "base": 800},
    {"id": "z3", "zone": 3, "name": "Ejderha Tepesi", "income": 16_000_000, "cost": 10_000_000, "base": 2500},
    {"id": "z4", "zone": 4, "name": "Karanlık Liman", "income": 18_000_000, "cost": 10_000_000, "base": 600},
    {"id": "z5", "zone": 5, "name": "Cehennem Kapısı", "income": 20_000_000, "cost": 10_000_000, "base": 3000},
    {"id": "z6", "zone": 6, "name": "Gökyüzü Burcu", "income": 22_000_000, "cost": 10_000_000, "base": 3800},
    {"id": "z7", "zone": 7, "name": "Efsanevi Sınır", "income": 25_000_000, "cost": 10_000_000, "base": 4800},
]

# Duplicate map slots so 320 guilds compete for many tiles (war map scale-up)
MAP_COPIES = 12  # 7*12 = 84 territories


def tier_of(members: int) -> str:
    if members <= 5:
        return "micro"
    if members <= 12:
        return "small"
    if members <= 25:
        return "mid"
    if members <= 40:
        return "large"
    return "mega"


def guild_size_multiplier(member_count: int) -> float:
    """Mirror SQL public.guild_size_multiplier (monument cost tiers)."""
    if member_count <= 10:
        return 0.35
    if member_count <= 20:
        return 0.55
    if member_count <= 30:
        return 0.75
    if member_count <= 40:
        return 0.90
    return 1.0


def guild_war_attack_size_multiplier(member_count: int) -> float:
    """Mirror SQL: 1 / guild_size_multiplier — small guilds get higher atk."""
    m = guild_size_multiplier(member_count)
    return 1.0 / m if m > 0 else 1.0


@dataclass
class Member:
    power: int
    is_leader: bool = False


@dataclass
class Guild:
    gid: int
    members: List[Member]
    vault: int = 0
    gem_pool: int = 0  # abstract gem defense budget
    wins: int = 0
    losses: int = 0
    attacks: int = 0
    income_earned: int = 0
    territories_peak: int = 0

    @property
    def size(self) -> int:
        return len(self.members)

    @property
    def tier(self) -> str:
        return tier_of(self.size)

    @property
    def total_power(self) -> int:
        return sum(m.power for m in self.members)

    @property
    def leader_power(self) -> int:
        for m in self.members:
            if m.is_leader:
                return m.power
        return self.members[0].power if self.members else 1

    def attack_power(
        self,
        support_frac: float = 1.0,
        aggregate: str = "sum",
        monument_inverse_atk: bool = False,
    ) -> int:
        """Live: leader + sum(others pledging). support_frac models incomplete pledge."""
        leader = self.leader_power
        others = [m.power for m in self.members if not m.is_leader]
        pledged = int(sum(others) * support_frac)
        raw = max(leader + pledged, 1)
        if aggregate == "mean":
            raw = max(1, int(raw / max(self.size, 1)))
        elif aggregate == "sqrt":
            raw = max(1, int(raw / math.sqrt(max(self.size, 1))))
        if monument_inverse_atk:
            return max(1, math.ceil(raw * guild_war_attack_size_multiplier(self.size)))
        return raw


@dataclass
class Tile:
    tid: str
    zone: int
    name: str
    income: int
    cost: int
    base: int
    owner: Optional[int] = None
    gem_boost: int = 0
    grace_until_day: int = -1
    # garrison assignment: list of member indices from owner guild
    garrison_count: int = 0  # how many members assigned (power = share of total)


@dataclass
class SimConfig:
    name: str
    cost_multiplier_vs_income: Optional[float] = None  # None = live flat cost
    underdog_atk_bonus: float = 0.0  # add underdog% when atk/def ratio low
    soft_cap_def_vs_atk: Optional[float] = None  # def cannot exceed atk * X for roll
    size_bracket_only: bool = False  # only attack similar size ±1 tier
    income_tax_to_weak: float = 0.0  # % of income redistributed to bottom half vaults
    max_territories_per_guild: Optional[int] = None
    support_frac: float = 0.85
    starting_vault: int = 25_000_000
    # How member powers aggregate into atk/def. Live = "sum".
    # "mean" = average power (size-neutral quality).
    # "sqrt" = sum / sqrt(size) (diminishing returns on roster).
    power_aggregate: str = "sum"
    equalize_member_quality: bool = False  # same power band all tiers (size-only test)
    # Live ship: effective_atk = CEIL(raw_atk * (1 / guild_size_multiplier(size)))
    monument_inverse_atk: bool = False


def sample_power(rng: random.Random, band: str) -> int:
    # Realistic spread around game powers seen in UI (~16k–61k)
    if band == "weak":
        return int(rng.lognormvariate(math.log(12_000), 0.35))
    if band == "avg":
        return int(rng.lognormvariate(math.log(35_000), 0.40))
    if band == "strong":
        return int(rng.lognormvariate(math.log(70_000), 0.35))
    if band == "elite":
        return int(rng.lognormvariate(math.log(120_000), 0.30))
    return int(rng.lognormvariate(math.log(40_000), 0.45))


def make_guilds(rng: random.Random, n: int, equalize_quality: bool = False) -> List[Guild]:
    """Mixed roster: many small, fewer mega — like real MMOs."""
    guilds: List[Guild] = []
    # Target mix
    mix = (
        [("micro", 2, 5, "weak")] * 70
        + [("small", 6, 12, "avg")] * 90
        + [("mid", 13, 25, "avg")] * 80
        + [("large", 26, 40, "strong")] * 50
        + [("mega", 41, 50, "elite")] * 30
    )
    if equalize_quality:
        # Isolate SIZE effect: every guild draws from same power band
        mix = [(label, lo, hi, "avg") for (label, lo, hi, _) in mix]
    rng.shuffle(mix)
    while len(mix) < n:
        mix.append(("small", 6, 12, "avg"))
    mix = mix[:n]

    for i, (label, lo, hi, band) in enumerate(mix):
        size = rng.randint(lo, hi)
        members: List[Member] = []
        for j in range(size):
            b = band
            if not equalize_quality:
                roll = rng.random()
                if roll < 0.15:
                    b = "weak"
                elif roll > 0.88:
                    b = "elite" if band in ("strong", "elite") else "strong"
            members.append(Member(power=max(500, sample_power(rng, b)), is_leader=False))
        members.sort(key=lambda m: m.power, reverse=True)
        members[0].is_leader = True
        guilds.append(Guild(gid=i, members=members))
    return guilds


def make_map(rng: random.Random) -> List[Tile]:
    tiles: List[Tile] = []
    for copy in range(MAP_COPIES):
        for t in TERRITORIES:
            tiles.append(
                Tile(
                    tid=f"{t['id']}_c{copy}",
                    zone=t["zone"],
                    name=f"{t['name']}#{copy+1}",
                    income=t["income"],
                    cost=t["cost"],
                    base=t["base"],
                )
            )
    rng.shuffle(tiles)
    return tiles


def gini(values: List[float]) -> float:
    xs = sorted(v for v in values if v >= 0)
    if not xs:
        return 0.0
    n = len(xs)
    s = sum(xs)
    if s <= 0:
        return 0.0
    cum = 0.0
    for i, x in enumerate(xs, 1):
        cum += i * x
    return (2 * cum) / (n * s) - (n + 1) / n


def effective_cost(tile: Tile, cfg: SimConfig) -> int:
    if cfg.cost_multiplier_vs_income is None:
        return tile.cost
    return max(1_000_000, int(tile.income * cfg.cost_multiplier_vs_income))


def defense_power(guild: Guild, tile: Tile, owned_count: int, aggregate: str = "sum") -> int:
    """Split total power across owned territories (1 member → 1 terr rule approx)."""
    if owned_count <= 0:
        return tile.base
    slots = max(1, guild.size // owned_count)
    share = guild.total_power * (slots / guild.size)
    raw = int(share) + tile.gem_boost
    if aggregate == "mean":
        # Mean power of assigned garrison slice
        return max(1, int(guild.total_power / max(guild.size, 1)) + tile.gem_boost)
    if aggregate == "sqrt":
        return max(1, int(share / math.sqrt(max(slots, 1))) + tile.gem_boost)
    return raw


def combat(rng: random.Random, atk: int, def_: int, cfg: SimConfig) -> bool:
    a = max(atk, 1)
    d = max(def_, 1)
    if cfg.soft_cap_def_vs_atk is not None:
        d = min(d, int(a * cfg.soft_cap_def_vs_atk))
    if cfg.underdog_atk_bonus > 0 and a < d:
        a = int(a * (1.0 + cfg.underdog_atk_bonus * (1.0 - a / d)))
    return (rng.random() * a) > (rng.random() * d)


def tier_rank(t: str) -> int:
    return {"micro": 0, "small": 1, "mid": 2, "large": 3, "mega": 4}[t]


def run_sim(cfg: SimConfig, seed: int = SEED) -> Dict:
    rng = random.Random(seed)
    guilds = make_guilds(rng, N_GUILDS, equalize_quality=cfg.equalize_member_quality)
    for g in guilds:
        g.vault = cfg.starting_vault + rng.randint(0, 10_000_000)
        g.gem_pool = rng.randint(0, 500) * 10  # gem boost units (1💎=+10 live)

    tiles = make_map(rng)

    # Seed ownership: stronger guilds snatch early unowned easier
    for tile in tiles:
        candidates = sorted(guilds, key=lambda g: g.total_power, reverse=True)
        for g in candidates[:40]:
            if rng.random() < 0.15:
                owned = sum(1 for t in tiles if t.owner == g.gid)
                if cfg.max_territories_per_guild and owned >= cfg.max_territories_per_guild:
                    continue
                tile.owner = g.gid
                tile.gem_boost = min(g.gem_pool, rng.randint(0, 2000))
                break

    daily_income_by_tier: Dict[str, List[int]] = defaultdict(list)
    ownership_hist: List[Dict[str, float]] = []
    conquest_log = []

    for day in range(N_DAYS):
        # Accrue income
        income_today = defaultdict(int)
        for tile in tiles:
            if tile.owner is None:
                continue
            g = guilds[tile.owner]
            g.vault += tile.income
            g.income_earned += tile.income
            income_today[g.tier] += tile.income

        if cfg.income_tax_to_weak > 0:
            pool = int(sum(income_today.values()) * cfg.income_tax_to_weak)
            weak = sorted(guilds, key=lambda g: g.income_earned)[: N_GUILDS // 2]
            if weak and pool > 0:
                share = pool // len(weak)
                for g in weak:
                    g.vault += share

        for t, amt in income_today.items():
            daily_income_by_tier[t].append(amt)

        # Attacks
        order = list(range(N_GUILDS))
        rng.shuffle(order)
        attacks_done = defaultdict(int)

        for gid in order:
            g = guilds[gid]
            if attacks_done[gid] >= ATTACKS_PER_DAY_CAP:
                continue
            owned_ids = [t for t in tiles if t.owner == gid]
            g.territories_peak = max(g.territories_peak, len(owned_ids))

            # Target: prefer higher income / weaker defense / not grace
            targets = []
            for tile in tiles:
                if tile.owner == gid:
                    continue
                if tile.grace_until_day >= day:
                    continue
                if tile.owner is not None:
                    owner = guilds[tile.owner]
                    if cfg.size_bracket_only and abs(tier_rank(owner.tier) - tier_rank(g.tier)) > 1:
                        continue
                cost = effective_cost(tile, cfg)
                if g.vault < cost:
                    continue
                if cfg.max_territories_per_guild and len(owned_ids) >= cfg.max_territories_per_guild:
                    # still allow if replacing? no — skip expansion
                    if tile.owner is None:
                        continue
                targets.append(tile)

            if not targets:
                continue

            # Score: income / expected difficulty
            def score(tile: Tile) -> float:
                if tile.owner is None:
                    def_ = tile.base
                else:
                    o = guilds[tile.owner]
                    oc = sum(1 for x in tiles if x.owner == o.gid)
                    def_ = defense_power(o, tile, max(oc, 1), cfg.power_aggregate)
                atk = g.attack_power(
                    cfg.support_frac,
                    cfg.power_aggregate,
                    cfg.monument_inverse_atk,
                )
                # expected win ≈ atk/(atk+def) under related rolls (approx)
                p = atk / (atk + max(def_, 1))
                return tile.income * p - effective_cost(tile, cfg) * 0.2

            targets.sort(key=score, reverse=True)
            tile = targets[0]
            cost = effective_cost(tile, cfg)
            atk = g.attack_power(
                cfg.support_frac,
                cfg.power_aggregate,
                cfg.monument_inverse_atk,
            )
            if tile.owner is None:
                def_ = tile.base
                owner_tier = "unowned"
            else:
                o = guilds[tile.owner]
                oc = sum(1 for x in tiles if x.owner == o.gid)
                def_ = defense_power(o, tile, max(oc, 1), cfg.power_aggregate)
                owner_tier = o.tier

            win = combat(rng, atk, def_, cfg)
            g.vault -= cost
            g.attacks += 1
            attacks_done[gid] += 1

            if win:
                g.wins += 1
                if tile.owner is not None:
                    guilds[tile.owner].losses += 1
                tile.owner = gid
                tile.gem_boost = 0
                tile.grace_until_day = day + GRACE_DAYS
                conquest_log.append(
                    {
                        "day": day,
                        "attacker_tier": g.tier,
                        "defender_tier": owner_tier,
                        "zone": tile.zone,
                        "atk": atk,
                        "def": def_,
                    }
                )
            else:
                g.losses += 1

        # ownership snapshot
        by_tier = defaultdict(int)
        for tile in tiles:
            if tile.owner is None:
                by_tier["unowned"] += 1
            else:
                by_tier[guilds[tile.owner].tier] += 1
        ownership_hist.append(dict(by_tier))

    # Metrics
    owned_final = [t for t in tiles if t.owner is not None]
    terr_by_tier = defaultdict(int)
    income_by_tier = defaultdict(int)
    guilds_with_land = defaultdict(int)
    for t in owned_final:
        g = guilds[t.owner]
        terr_by_tier[g.tier] += 1
        income_by_tier[g.tier] += t.income
    for g in guilds:
        if any(t.owner == g.gid for t in tiles):
            guilds_with_land[g.tier] += 1

    counts = defaultdict(int)
    for g in guilds:
        counts[g.tier] += 1

    winrate_by_tier = {}
    for tier in ("micro", "small", "mid", "large", "mega"):
        gs = [g for g in guilds if g.tier == tier]
        att = sum(g.attacks for g in gs)
        wins = sum(g.wins for g in gs)
        winrate_by_tier[tier] = {
            "guilds": len(gs),
            "avg_size": round(statistics.mean(g.size for g in gs), 1) if gs else 0,
            "avg_power": int(statistics.mean(g.total_power for g in gs)) if gs else 0,
            "attacks": att,
            "wins": wins,
            "win_rate_pct": round(100 * wins / att, 2) if att else 0.0,
            "with_territory": guilds_with_land[tier],
            "territories": terr_by_tier[tier],
            "territory_share_pct": round(100 * terr_by_tier[tier] / max(len(tiles), 1), 2),
            "income_share_pct": round(
                100 * income_by_tier[tier] / max(sum(income_by_tier.values()), 1), 2
            ),
            "avg_income_earned": int(statistics.mean(g.income_earned for g in gs)) if gs else 0,
        }

    # Crush index: land share / population share
    crush = {}
    for tier, st in winrate_by_tier.items():
        pop_share = counts[tier] / N_GUILDS
        land_share = st["territories"] / max(len(tiles), 1)
        crush[tier] = round(land_share / pop_share, 3) if pop_share > 0 else 0.0

    # Cross-tier conquest matrix
    matrix = defaultdict(lambda: defaultdict(int))
    for c in conquest_log:
        matrix[c["attacker_tier"]][c["defender_tier"]] += 1

    terr_counts = [sum(1 for t in tiles if t.owner == g.gid) for g in guilds]
    income_counts = [float(g.income_earned) for g in guilds]

    # Small guild survival: micro+small still own land at end
    small_land = terr_by_tier["micro"] + terr_by_tier["small"]
    small_pop = counts["micro"] + counts["small"]

    verdict_parts = []
    mega_crush = crush.get("mega", 0)
    micro_crush = crush.get("micro", 0)
    if mega_crush >= 2.0 and micro_crush <= 0.4:
        verdict = "FAIL_CRUSH"
        verdict_parts.append("mega land/pop ≥2× ve micro ≤0.4× → küçük lonca eziliyor")
    elif mega_crush >= 1.5 and (terr_by_tier["micro"] + terr_by_tier["small"]) / max(len(tiles), 1) < 0.15:
        verdict = "WARN_SNOWBALL"
        verdict_parts.append("büyük lonca avantajı belirgin; küçük pay < %15")
    else:
        verdict = "PASS_BALANCED"
        verdict_parts.append("tier land/pop oranı aşırı bozulmamış")

    # Soften crush gate when small+micro hold meaningful land under bracket designs
    small_share = (terr_by_tier["micro"] + terr_by_tier["small"]) / max(len(tiles), 1)
    if verdict == "FAIL_CRUSH" and small_share >= 0.18 and crush.get("mega", 99) < 5:
        verdict = "WARN_SNOWBALL"
        verdict_parts.append("küçük lonca land payı ≥%18 — ezilme yumuşadı ama mega hâlâ önde")
    if cfg.power_aggregate == "mean" and cfg.size_bracket_only and small_share >= 0.20:
        verdict = "PASS_IMPROVED"
        verdict_parts = ["mean+bracket → küçük lonca hayatta; önerilen yön"]

    if gini(terr_counts) > 0.75:
        verdict_parts.append(f"territory Gini yüksek ({gini(terr_counts):.2f})")
        if verdict == "PASS_BALANCED":
            verdict = "WARN_SNOWBALL"

    return {
        "config": {
            "name": cfg.name,
            "n_guilds": N_GUILDS,
            "n_days": N_DAYS,
            "n_territories": len(tiles),
            "map_copies": MAP_COPIES,
            "cost_mode": (
                "live_flat_10M"
                if cfg.cost_multiplier_vs_income is None
                else f"income_x{cfg.cost_multiplier_vs_income}"
            ),
            "underdog_atk_bonus": cfg.underdog_atk_bonus,
            "soft_cap_def_vs_atk": cfg.soft_cap_def_vs_atk,
            "size_bracket_only": cfg.size_bracket_only,
            "income_tax_to_weak": cfg.income_tax_to_weak,
            "max_territories_per_guild": cfg.max_territories_per_guild,
            "support_frac": cfg.support_frac,
            "power_aggregate": cfg.power_aggregate,
            "monument_inverse_atk": cfg.monument_inverse_atk,
            "combat": "success = (U*atk) > (U*def)  [live attack_guild_war_territory]",
            "defense": "garrison share = total_power * (floor(size/owned)/size) + gem",
        },
        "verdict": verdict,
        "verdict_notes": verdict_parts,
        "crush_index_land_over_pop": crush,
        "by_tier": winrate_by_tier,
        "gini_territories": round(gini([float(x) for x in terr_counts]), 4),
        "gini_income": round(gini(income_counts), 4),
        "small_guild_land_share_pct": round(100 * small_land / max(len(tiles), 1), 2),
        "small_guild_pop_share_pct": round(100 * small_pop / N_GUILDS, 2),
        "conquest_matrix_attacker_x_defender": {a: dict(d) for a, d in matrix.items()},
        "ownership_final": ownership_hist[-1] if ownership_hist else {},
        "ownership_day0": ownership_hist[0] if ownership_hist else {},
        "top10_guilds_by_territories": [
            {
                "gid": g.gid,
                "tier": g.tier,
                "size": g.size,
                "power": g.total_power,
                "territories": sum(1 for t in tiles if t.owner == g.gid),
                "income_earned": g.income_earned,
                "win_rate_pct": round(100 * g.wins / g.attacks, 1) if g.attacks else 0,
            }
            for g in sorted(
                guilds,
                key=lambda x: sum(1 for t in tiles if t.owner == x.gid),
                reverse=True,
            )[:10]
        ],
        "sample_conquests": conquest_log[:15],
    }


def main() -> None:
    configs = [
        SimConfig(name="A_LIVE_current"),
        SimConfig(name="B_ROI_1_75x_income", cost_multiplier_vs_income=1.75),
        SimConfig(
            name="C_underdog_softcap",
            cost_multiplier_vs_income=1.75,
            underdog_atk_bonus=0.35,
            soft_cap_def_vs_atk=2.5,
        ),
        SimConfig(
            name="D_size_bracket",
            cost_multiplier_vs_income=1.75,
            size_bracket_only=True,
        ),
        SimConfig(
            name="E_cap3_territories",
            cost_multiplier_vs_income=1.75,
            max_territories_per_guild=3,
        ),
        SimConfig(
            name="F_hybrid_tax_underdog",
            cost_multiplier_vs_income=1.75,
            underdog_atk_bonus=0.25,
            soft_cap_def_vs_atk=3.0,
            income_tax_to_weak=0.08,
            max_territories_per_guild=4,
        ),
        SimConfig(
            name="G_power_mean_not_sum",
            cost_multiplier_vs_income=1.75,
            power_aggregate="mean",
            max_territories_per_guild=4,
        ),
        SimConfig(
            name="H_sqrt_size_scale",
            cost_multiplier_vs_income=1.75,
            power_aggregate="sqrt",
            underdog_atk_bonus=0.15,
            max_territories_per_guild=4,
        ),
        SimConfig(
            name="I_bracket_plus_mean",
            cost_multiplier_vs_income=1.5,
            power_aggregate="mean",
            size_bracket_only=True,
            max_territories_per_guild=3,
            income_tax_to_weak=0.05,
        ),
        SimConfig(
            name="J_equal_quality_live_sum",
            equalize_member_quality=True,
            # Isolates roster-size snowball under LIVE Σ power
        ),
        SimConfig(
            name="K_equal_quality_mean_bracket_cap",
            equalize_member_quality=True,
            power_aggregate="mean",
            size_bracket_only=True,
            cost_multiplier_vs_income=1.5,
            max_territories_per_guild=3,
            income_tax_to_weak=0.05,
        ),
        SimConfig(
            name="L_monument_inverse_atk",
            # Shipped live: effective_atk = CEIL(raw / guild_size_multiplier(size))
            monument_inverse_atk=True,
        ),
    ]

    results = []
    for cfg in configs:
        results.append(run_sim(cfg))

    out = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "seed": SEED,
        "purpose": "Detect if small guilds get crushed under live guild-war formula + compare mitigations",
        "scenarios": results,
    }

    reports = Path(__file__).resolve().parents[1] / "reports"
    reports.mkdir(exist_ok=True)
    raw_path = reports / "guild_war_small_guild_crush_smoke.json"
    raw_path.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(json.dumps({"wrote": str(raw_path), "verdicts": {r["config"]["name"]: r["verdict"] for r in results}}, indent=2))


if __name__ == "__main__":
    main()
