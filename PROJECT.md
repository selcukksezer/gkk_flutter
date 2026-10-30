# Project: gkk_flutter AAA Mobile Overhaul & Fullstack Audit

## Architecture
- **Target Platforms**: Mobile only (iOS Metal/Impeller, Android Vulkan/Impeller).
- **Frontend Architecture**: 33 Mobile screens (`lib/screens/`), 82 shared components (`lib/components/`), Riverpod state management (`lib/providers/`), custom GLSL Impeller shaders (`shaders/`, `lib/shaders/`), 3D viewport rendering (`lib/rendering/`).
- **Backend Architecture**: Supabase PostgreSQL (546 SQL migrations, 6 seed scripts), 16+1 Dart Repositories (`lib/repositories/`), 17 Services (`lib/core/services/`), 38 Data Models (`lib/models/`).
- **Hardware Isolation**: Single-queue gatekeeper execution for heavy tasks (QA runner, Blender GPU runner, Asset I/O).

## Feature Inventory
| # | Feature / Screen | Description & Viewports | Milestone | Source |
|---|------------------|-------------------------|-----------|--------|
| 1 | HomeScreen 3D Viewport Fix | Fix exploding grey CPU 3D triangles in `Hero3dGlbViewport` & `Hub3DViewport` | M1 | ORIGINAL_REQUEST R1 |
| 2 | HomeScreen AAA Background | Replace flat grey polygon mountain with AAA Aion 2 artwork | M1 | ORIGINAL_REQUEST R1 |
| 3 | Marquee Text Fix | Prevent character clipping/truncation in ticker (`'azarı açık!`) | M1 | ORIGINAL_REQUEST R1 |
| 4 | Inventory (`/inventory`) | `InventoryGrid`, `ItemDetailSheet`, 123+ generated item icons | M3 | Survey 33 Screens |
| 5 | Character (`/character`) | `CharacterTurntableViewport` 360°, `EquipmentSocketDock`, `StatAllocationPanel` | M3 | Survey 33 Screens |
| 6 | Codex (`/character/codex`) | `CodexDesign`, `BadgeShowcasePanel`, `MilestoneTracker` | M3 | Survey 33 Screens |
| 7 | Dungeon Hub (`/dungeon`) | `DungeonCard`, `DungeonMonsterGlbViewport`, `DifficultySelector` | M2 | Survey 33 Screens |
| 8 | Dungeon Battle (`/dungeon/battle`) | `CombatVfxLayer`, `HitStopController`, `ScreenShakeHost`, 9 VFX modules | M2 | Survey 33 Screens |
| 9 | Siege Hub (`/dungeon/siege`) | `SiegeBossEncounterCard`, `SiegeLeaderboardView` | M2 | Survey 33 Screens |
| 10 | Siege Battle (`/dungeon/siege/challenge`) | `SiegeChallengeController`, `BossRageBar`, `VfxParticleOverlay` | M2 | Survey 33 Screens |
| 11 | PvP Arena (`/pvp`) | `PvpGladiator3dView`, `ColosseumArenaLighting`, `NemesisRivalCard` | M2 | Survey 33 Screens |
| 12 | PvP History (`/pvp/history`) | `PvpCombatLogTile`, `RevengeChallengeButton` | M2 | Survey 33 Screens |
| 13 | PvP Tournament (`/pvp/tournament`) | `TournamentBracketView`, `TournamentMatchTile` | M2 | Survey 33 Screens |
| 14 | Guild (`/guild`) | `GuildHeaderCard`, `CelestialBannerWidget`, `GuildMemberList` | M5 | Survey 33 Screens |
| 15 | Guild Vault (`/guild/vault`) | `VaultDepositSheet`, `VaultAuditLog`, atomic locks | M5 | Survey 33 Screens |
| 16 | Guild Monument (`/guild/monument`) | `MonumentTierDisplay`, `MonumentPerkGrid`, `emblem_aura.frag` | M5 | Survey 33 Screens |
| 17 | Monument Donate (`/guild/monument/donate`) | `DonationResourceSlider`, `BlessingBuffPreview` | M5 | Survey 33 Screens |
| 18 | Guild War Hub (`/guild-war`) | `TerritoryMapGrid`, `SiegeWarTacticsPanel` | M2 | Survey 33 Screens |
| 19 | Market (`/market`) | `MarketTickerCard`, `OrderBookView`, `MarketBuySellSheet` | M4 | Survey 33 Screens |
| 20 | Shop (`/shop`) | `NightMarketBanner`, `DiamondPurchaseTile`, `FeaturedOfferCarousel` | M4 | Survey 33 Screens |
| 21 | Trade (`/trade`) | `DualTradeWindow`, `TradeSlotGrid`, `TradeLockConfirmationButton` | M4 | Survey 33 Screens |
| 22 | Bank (`/bank`) | `BankSlotGrid`, `BankCrystalTabs`, `BankUnlockModal`, atomic locks | M4 | Survey 33 Screens |
| 23 | Crafting (`/crafting`) | `RecipeCategoryTabs`, `CraftingQueueTile`, `ForgeFireCanvas` | M4 | Survey 33 Screens |
| 24 | Enhancement (`/enhancement`) | `AnvilTurntableView`, `EnhancementSlotDock`, `SuccessRateMeter` | M3 | Survey 33 Screens |
| 25 | Facilities (`/facilities`) | `FacilityKingdomCard`, `FacilityUpgradeQueue`, `FacilityIncomeTimer` | M6 | Survey 33 Screens |
| 26 | Loot Hub (`/loot`) | `LootBoxCarousel`, `ChestOpeningSequence`, `RarityRaycastLight` | M3 | Survey 33 Screens |
| 27 | Horse Race (`/horse-race`) | `RaceTrackCanvas`, `HorseBettingOddsPanel`, `LiveJockeyAnimation` | M6 | Survey 33 Screens |
| 28 | Hospital (`/hospital`) | `HealthRecoveryGauge`, `GemHealButton`, `EscapeChanceWheel` | M6 | Survey 33 Screens |
| 29 | Prison (`/prison`) | `IronCellBarsOverlay`, `SentenceCountdownTimer`, `BribeGuardActionSheet` | M6 | Survey 33 Screens |
| 30 | Mekans (`/mekans`) | `Mekan3dViewport`, `MekanAtmosphereLayer`, `MekanRosterTile` | M6 | Survey 33 Screens |
| 31 | Quests (`/quests`) | `QuestStoryCard`, `DailyWeeklyQuestTabs`, `ObjectiveProgressTrack` | M6 | Survey 33 Screens |
| 32 | Reputation (`/reputation`) | `FactionStandingsChart`, `ReputationPerkTrack`, `FactionShopGrid` | M5 | Survey 33 Screens |
| 33 | Season (`/season`) | `BattlePassTrackTierView`, `FreeVsVipLane`, `SeasonCountdownBanner` | M5 | Survey 33 Screens |
| 34 | Leaderboard (`/leaderboard`) | `LeaderboardPodiumTop3`, `RankedPlayerTile`, `PersonalRankStickyFooter` | M5 | Survey 33 Screens |
| 35 | Settings & System (`/settings`) | `HardwareTierSelector`, `PreloaderCacheDiagnosticsCard`, telemetry | M7 | Survey 33 Screens |
| 36 | 3D Asset Forensics & PBR Baking | Audit 215+ `.glb` models, eliminate primitive shapes, Draco | M8 | PROMPT_ORDUSU Dept 08 |
| 37 | Impeller Shader Compliance | 18 GLSL shaders Metal/Vulkan compliance, Dart uniform sync | M9 | PROMPT_ORDUSU Dept 09 |
| 38 | E2E & Golden Test Suites | Real 390x844 mobile screenshot suite, 194 test suites repair | M10 | PROMPT_ORDUSU Dept 10 |
| 39 | Supabase SQL Hardening | 4 idempotent migrations: search_path, atomic locks, RLS, missing RPCs | M11 | ORIGINAL_REQUEST R3 |
| 40 | Dart Backend RPC Contract Parity | Align 306 `.rpc()` calls with database function signatures, fix casts | M12 | ORIGINAL_REQUEST R3 |
| 41 | Final Verification & Audit | 5/5 Chief Auditor consensus, 0 analyze errors, git commit & push | M13 | PROMPT_ORDUSU Section 4 |


## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | `battalion_01_hub_hud` | HomeScreen regressions (3D triangles, mountain background, marquee) + HUD | none | IN_PROGRESS |
| M2 | `battalion_02_combat_screens` | Dungeon, PvP, Guild War, 9 combat VFX modules | none | IN_PROGRESS |
| M3 | `battalion_03_hero_inventory` | Character 3D turntable, inventory, enhancement, loot | none | IN_PROGRESS |
| M4 | `battalion_04_economy` | Market, trade, bank, shop, crafting | none | IN_PROGRESS |
| M5 | `battalion_05_social` | Guild, chat, friends, leaderboard, season | none | IN_PROGRESS |
| M6 | `battalion_06_world_ops` | Mekans, facilities, hospital, prison, horse race, quests | none | IN_PROGRESS |
| M7 | `battalion_07_onboarding_staff_theme` | Theme system, settings, staff, AdaptiveQualityScaler, Preloader | none | IN_PROGRESS |
| M8 | `battalion_08_glb_forensic_inspectors` | 215+ GLB models audit, PBR maps, mesh asset registry | none | IN_PROGRESS |
| M9 | `battalion_09_shader_pbr_manifest` | 18 GLSL fragment shaders, Impeller bindings, pubspec sync | none | IN_PROGRESS |
| M10 | `battalion_10_test_golden_authors` | Golden test suite, test repair, fullstack contract tests | none | IN_PROGRESS |
| M11 | `fullstack_supabase_audit` | Supabase migrations, RLS policies, atomic locks, search_path | none | IN_PROGRESS |
| M12 | `fullstack_dart_parity` | Repository/Provider/Model RPC parity with SQL | M11 | PLANNED |
| M13 | `final_chief_audit` | 5/5 Chief Auditor verification, flutter analyze, commit & push | M1-M12 | PLANNED |

## Interface Contracts
### UI ↔ Riverpod Providers
- UI widgets strictly consume state via `ref.watch` on designated domain providers (`lib/providers/`).
- State mutations execute via provider notifier methods, preventing unthrottled concurrent invocations.

### Repositories ↔ Supabase Client
- All RPC calls invoke typed database functions with explicit parameter maps.
- All monetary and item transactions enforce server-side row-level locks via `SELECT ... FOR UPDATE`.

### Rendering ↔ Shaders
- GLSL uniforms in `shaders/*.frag` map 1:1 to Dart `FragmentShader.setFloat` and `setImageSampler` calls.

## Code Layout
- `lib/screens/`: 33 mobile game screens
- `lib/components/`: 82 reusable UI components
- `lib/theme/`: Obsidian-glass + gold runes Aion 2 design system
- `lib/rendering/`: 3D viewports and render passes
- `lib/shaders/`: Dart FragmentShader bridges
- `shaders/`: GLSL fragment shaders targeting Impeller (Metal/Vulkan)
- `assets/models/`: Genuine CC0 `.glb` 3D meshes (Draco compressed)
- `assets/textures/`: 1K/2K PBR textures (Albedo, Normal, Roughness, Metallic, AO)
- `assets/images/`: High-resolution illustrations, portraits, backgrounds
- `lib/repositories/`: Supabase data access layer (16+1 repos)
- `lib/providers/`: State management (37 Riverpod providers)
- `lib/models/`: Strongly typed data entities (38 models)
- `supabase/migrations/`: Database schema, RLS, and PL/pgSQL RPC functions
- `test/`: Automated unit, contract, and golden test suites
