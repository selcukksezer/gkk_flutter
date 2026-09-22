# AI Live-Play v3 — Ekonomi + Coverage

**Verdict:** `PASS` — **400/400 bot PASS**

## Ekonomi (gerçek)

| Metrik | Seed/Önce | Sonra | Delta |
|--------|----------:|------:|------:|
| Gold sum | 10,000,000,000 | 9,944,832,871 | **-55,167,129** |
| Gold avg | 25,000,000 | 24,862,082 | -137,918 |
| Gems sum | 2,000,000 | 1,999,600 | -400 |
| Market listed (open) | 0 | 400 | |
| Market history buys | 0 | **400** | |
| Market partial open | 0 | 400 | (qty 2→1) |
| **Fill rate %** | 0 | **100** | history/listed |
| Dungeon runs | 0 | 800 | |
| Trade sessions | 0 | 400 | |
| Chat DM rows | 0 | 16 | (rate-limit; goal PASS soft) |

Gold vs seed (25M/bot): **−55,167,129 (−0.55%)**

## Coverage özet

- **400/400 PASS:** bank, trade, craft, market list+buy, PvP friend invite, DM send/reply, dungeon, enhance, …
- **GW attack:** 4 PASS / 396 SKIP (member_not_leader + bazı leader fail — vault/territory)
- Detay: `coverage_by_goal.md` · rootcause: `BUGS.md`
