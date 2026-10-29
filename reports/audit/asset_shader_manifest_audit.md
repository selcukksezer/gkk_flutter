# Physical Disk Asset, GLB, PNG, Font, Seed & GLSL Manifest Audit

- **Gatekeeper**: `dedicated_asset_io_gatekeeper` (Gatekeeper #3 — `PROMPT_ORDUSU.md`)
- **Workspace**: `/Users/selcuk/Documents/gkk_flutter`
- **Audit Mode**: Single-process Python 3.12 binary/AST/manifest static verification (zero Flutter builds, zero Blender renders)
- **Overall Gate Verdict**: **FAIL (5 CRITICAL, 1 HIGH, 7 WARN)**

---

## Executive Summary

| Gate | Scope | Audited | Status | Summary |
| :--- | :--- | :---: | :---: | :--- |
| **1. `pubspec.yaml` ↔ Disk** | `assets:`, `shaders:`, `fonts:` vs `assets/`, `shaders/`, `lib/shaders/` | 78 manifest entries / 1,097 bundled files | **FAIL (CRITICAL)** | All 78 declared paths exist on disk, **but** 2 physical GLSL shaders under `lib/shaders/social/glsl/*.frag` are referenced at runtime and missing from `pubspec.yaml`; 12 parent directory entries contain 0 direct files. |
| **2. `lib/**/*.dart` References** | `Image.asset`, `AssetImage`, `FragmentProgram.fromAsset`, `rootBundle`, `AudioPlayer`, `GoogleFonts`, registries | 145 literal/API refs + 73 dynamic templates | **FAIL (CRITICAL)** | 3 `Chest.glb` vs `chest.glb` case-sensitivity bugs (iOS/Android crash); 6 missing shader paths in Dart (`shaders/social/*.frag`, `shaders/world/{wind_vegetation,water_puddle,volumetric_fog}.frag`); 9 missing `EnhanceSoundCues` MP3s; 2 unbundled `GoogleFonts` families. |
| **3. `supabase/seeds/*.sql` ↔ Icons** | All 6 SQL seed files resolved via `ItemIconResolver` | 304 item rows | **FAIL (CRITICAL)** | `chest_leather_rare.png` physically missing on disk (`plan1_items.generated.sql:44`); 6 `res_time_*` rows (`plan2_resources.generated.sql:90-95`) fail resolution due to `⏳` (`U+23F3`) missing from `ItemIconResolver._emojiRegex`. |
| **4. Binary & `<45 MB` Gate** | Git-tracked sizes, `.glb` v2 chunks/vertices, `.png` IHDR/IEND, `.jpg`, `.ttf` | 4,139 tracked files / 215 GLB / 722 PNG / 91 JPG / 30 TTF | **FAIL (CRITICAL)** | Tracked `backups/2026-07-22-yedek/full_data.sql` is **78.08 MB** (`>45 MB` limit). All 215 GLBs have valid `glTF` v2 headers & non-zero vertices, but 10 GLBs reference missing external `Textures/colormap.png`. All 722 PNGs, 91 JPGs, 30 TTFs valid. |
| **5. GLSL Uniform Layouts** | Physical `.frag`/`.vert` uniform slots & samplers vs Dart `setFloat`/`setImageSampler` | 20 shader files / 16 runtime packers | **PASS (WARN)** | 16/16 runtime fragment shader packers match float uniform slot indices and sampler indices 1:1. `ShaderCatalog` metadata has uniform count drift on `dungeon_lighting.frag` and omits 4 physical shaders. |

---

## Gate 1: `pubspec.yaml` (`assets:` & `shaders:`) vs Physical Disk

### 1.1 Manifest Coverage Totals
- **`flutter.assets` (`pubspec.yaml:100-175`)**: 64 entries declared (59 directories, 5 explicit shader files) → **1,083 files** bundled. Every declared path exists physically on disk.
- **`flutter.shaders` (`pubspec.yaml:177-201`)**: 14 Impeller fragment shaders declared → **14 files** bundled. Every declared shader exists physically on disk.
- **`flutter.fonts`**: 0 explicit `fonts:` entries; offline TTFs are bundled via `assets/google_fonts/` (`pubspec.yaml:105`, 30 `.ttf` files).
- **Physical `assets/` leaf directories**: 100% of leaf directories under `assets/` containing files are declared in `pubspec.yaml`.

### 1.2 CRITICAL — Unbundled Physical Shaders Referenced in `lib/`
| Severity | Physical File | Referenced At | Issue |
| :---: | :--- | :--- | :--- |
| **CRITICAL** | `lib/shaders/social/glsl/celestial_banner.frag:1` (3,126 B) | `lib/shaders/social/social_shaders.dart:26`, `:311` | Loaded via `ui.FragmentProgram.fromAsset('lib/shaders/social/glsl/celestial_banner.frag')`, **NOT declared** under `flutter.shaders:` in `pubspec.yaml:177-201`. Throws asset load error on iOS/Android and silently degrades to CPU fallback. |
| **CRITICAL** | `lib/shaders/social/glsl/emblem_aura.frag:1` (2,753 B) | `lib/shaders/social/social_shaders.dart:32`, `:311` | Loaded via `ui.FragmentProgram.fromAsset('lib/shaders/social/glsl/emblem_aura.frag')`, **NOT declared** under `flutter.shaders:` in `pubspec.yaml:177-201`. |
| **WARN** | `lib/shaders/social/glsl/test.txt:1` (3 B) | *(unreferenced)* | Stray 3-byte scratch file inside `lib/shaders/social/glsl/`. |

### 1.3 WARN — Empty Parent Directory Declarations in `pubspec.yaml`
Flutter directory entries in `pubspec.yaml` are **non-recursive** (they bundle only direct child files of that folder, not subfolders). These 12 entries contain **0 direct files** (only subdirectories):
- `pubspec.yaml:103` — `assets/ui/`
- `pubspec.yaml:108` — `assets/models/`
- `pubspec.yaml:112` — `assets/models/weapons/textures/`
- `pubspec.yaml:121` — `assets/textures/`
- `pubspec.yaml:122` — `assets/textures/pbr_2k/`
- `pubspec.yaml:127` — `assets/textures/baked/`
- `pubspec.yaml:131` — `assets/renders/`
- `pubspec.yaml:140` — `assets/images/`
- `pubspec.yaml:144` — `assets/images/portraits/`
- `pubspec.yaml:151` — `assets/images/icons/`
- `pubspec.yaml:158` — `assets/images/backgrounds/`
- `pubspec.yaml:164` — `assets/images/vfx_sprites/`

---

## Gate 2: `lib/**/*.dart` Asset, Model, Audio, Font & Shader References

### 2.1 CRITICAL — Case-Sensitivity Mismatches (Breaks iOS/Android `AssetManifest`)
macOS APFS (case-insensitive by default) masks casing mismatches locally, whereas Flutter's `AssetManifest.bin` and iOS/Android filesystems are **strictly case-sensitive** and throw `Unable to load asset` at runtime:

| Severity | Dart Reference (`path:line`) | Referenced Literal | Actual File on Disk |
| :---: | :--- | :--- | :--- |
| **CRITICAL** | `lib/screens/facilities/widgets/facility_3d_model_resolver.dart:146` | `'assets/models/environment/Chest.glb'` (`clay_pit` `primaryGlbPath`) | `assets/models/environment/chest.glb` |
| **CRITICAL** | `lib/screens/facilities/widgets/facility_3d_model_resolver.dart:409` | `'assets/models/environment/Chest.glb'` (`_allEnvironmentGlbPaths`) | `assets/models/environment/chest.glb` |
| **CRITICAL** | `lib/components/kingdom/kingdom_realm_3d_viewport.dart:257` | `'assets/models/environment/Chest.glb'` | `assets/models/environment/chest.glb` |

*(Note: `assets/models/props/Chest.glb` is uppercase `Chest.glb`, whereas `assets/models/environment/chest.glb` is lowercase `chest.glb`.)*

### 2.2 CRITICAL — Non-Existent Shader Asset Paths in Dart
| Severity | Dart Reference (`path:line`) | Missing Shader Path | Notes / Disk Status |
| :---: | :--- | :--- | :--- |
| **CRITICAL** | `lib/shaders/social/social_shaders.dart:23` (loaded at `:308`) | `'shaders/social/celestial_banner.frag'` | Does **not** exist under `shaders/`; physical file is at `lib/shaders/social/glsl/celestial_banner.frag` (also unbundled). |
| **CRITICAL** | `lib/shaders/social/social_shaders.dart:29` (loaded at `:308`) | `'shaders/social/emblem_aura.frag'` | Does **not** exist under `shaders/`; physical file is at `lib/shaders/social/glsl/emblem_aura.frag` (also unbundled). |
| **CRITICAL** | `lib/screens/home/widgets/hub_wind_vegetation.dart:1064` (loaded at `:1112`) | `'shaders/world/wind_vegetation.frag'` | Missing on disk and absent from `pubspec.yaml`; `FragmentProgram.fromAsset` always fails and falls back to CPU path. |
| **CRITICAL** | `lib/core/shaders/shader_registry.dart:350` (`& :1414`) | `'shaders/world/wind_vegetation.frag'` | Registered in `ShaderAssetPaths` & `ShaderCatalog.defaultDescriptors`; missing on disk & `pubspec.yaml`. |
| **CRITICAL** | `lib/core/shaders/shader_registry.dart:351` (`& :1463`) | `'shaders/world/water_puddle.frag'` | Missing on disk & `pubspec.yaml` (superseded physically by `shaders/world/puddle_ssr.frag`). |
| **CRITICAL** | `lib/core/shaders/shader_registry.dart:352` (`& :1516`) | `'shaders/world/volumetric_fog.frag'` | Missing on disk & `pubspec.yaml`. |

### 2.3 WARN — Missing Audio SFX Assets (`EnhanceSoundCues`)
`assets/audio/` contains only `assets/audio/main_theme.wav` (validly loaded via `AssetSource('audio/main_theme.wav')` at `lib/core/services/music_service.dart:15,80`). `EnhanceSoundCues` is not yet wired to an `AudioPlayer`, but declares 9 non-existent SFX files (and `assets/audio/sfx/` is absent from disk & `pubspec.yaml`):
- `lib/screens/enhancement/enhancement_design.dart:34` — `'audio/sfx/forge_strike.mp3'`
- `lib/screens/enhancement/enhancement_design.dart:42` — `'audio/sfx/forge_charge.mp3'`
- `lib/screens/enhancement/enhancement_design.dart:50` — `'audio/sfx/forge_success.mp3'`
- `lib/screens/enhancement/enhancement_design.dart:57` — `'audio/sfx/forge_failure.mp3'`
- `lib/screens/enhancement/enhancement_design.dart:64` — `'audio/sfx/forge_destroyed.mp3'`
- `lib/screens/enhancement/enhancement_design.dart:71` — `'audio/sfx/socket_insert.mp3'`
- `lib/screens/enhancement/enhancement_design.dart:78` — `'audio/sfx/socket_remove.mp3'`
- `lib/screens/enhancement/enhancement_design.dart:85` — `'audio/sfx/rune_activated.mp3'`
- `lib/screens/enhancement/enhancement_design.dart:92` — `'audio/sfx/risk_critical.mp3'`

### 2.4 WARN — Unbundled `GoogleFonts` Families (Offline Fallback Gap)
`assets/google_fonts/` bundles 30 TTF files covering `Cinzel`, `CinzelDecorative`, `JetBrainsMono`, `Outfit`, `PlusJakartaSans`, and `Urbanist`. Two widgets request unbundled font families (requiring runtime HTTP fetch or degrading offline):
- `lib/components/daily_reward/daily_calendar_grid.dart:282` — `GoogleFonts.robotoMono(...)` (no `RobotoMono-*.ttf` in `assets/google_fonts/`)
- `lib/screens/auth/banned_screen.dart:869` — `GoogleFonts.sourceCodePro(...)` (no `SourceCodePro-*.ttf` in `assets/google_fonts/`)

### 2.5 Verified Dynamic Asset Templates & Registries (PASS)
- `lib/components/common/profile_avatar.dart:10-16` (`assets/avatars/profil1.png` .. `profil7.png`): **7 / 7** exist & bundled (`pubspec.yaml:139`).
- `lib/components/layout/game_quick_menu.dart:82-109` (`assets/menuitems/$menuIconFile`): **25 / 25** PNGs exist & bundled (`pubspec.yaml:106`).
- `lib/screens/dungeon/widgets/dungeon_cave_theme.dart:427` + `lib/screens/dungeon/widgets/dungeon_cave_palettes.dart:27` (`assets/dungeons/dungeon$number.${palette.ext}`): **58 / 58** files (`dungeon1..58` across `.jpg`/`.png`) exist & bundled (`pubspec.yaml:107`).
- `lib/utils/item_icon_resolver.dart:6-20,156-222`: 100% of `_legacyWeaponAliasByStem` (13 stems × 6 rarities) and `_economyAliases` targets exist in `assets/items/generated/` & are bundled (`pubspec.yaml:102`).

---

## Gate 3: `supabase/seeds/*.sql` ↔ `ItemIconResolver` Parity

Audited all **304 item rows** across all 6 seed files in `supabase/seeds/`:

| SQL Seed File | Item Rows | Resolved & Bundled | Broken / Missing | Status |
| :--- | :---: | :---: | :---: | :---: |
| `supabase/seeds/plan1_items.generated.sql` | 192 | 191 | **1 CRITICAL** | **FAIL** |
| `supabase/seeds/plan2_resources.generated.sql` | 90 | 84 | **6 HIGH** | **FAIL** |
| `supabase/seeds/plan1_consumables.generated.sql` | 19 | 19 | 0 *(WARN on `catalyst` enum)* | **PASS (WARN)** |
| `supabase/seeds/flutter_item_icon_updates.generated.sql` | 3 | 3 | 0 *(WARN on dead primary path)* | **PASS (WARN)** |
| `supabase/seeds/seed_guild_war.sql` | 0 | — | 0 | **PASS** |
| `supabase/seeds/seed_guild_war_v2.sql` | 0 | — | 0 | **PASS** |

### 3.1 Detailed SQL Seed Findings
1. **CRITICAL — Missing Physical PNG (`supabase/seeds/plan1_items.generated.sql:44`)**:
   - Row: `id = 'chest_leather_rare'`, `icon = 'chest_leather_rare'`, `type = 'armor'`, `rarity = 'rare'`.
   - `ItemIconResolver.candidateAssetPathsFor` (`lib/utils/item_icon_resolver.dart:262-320`) generates `assets/items/generated/chest_leather_rare.png` and `assets/items/armor/chest_leather_rare.png`.
   - On disk, `chest_leather_{common,uncommon,epic,legendary,mythic}.png` all exist in `assets/items/generated/`, **but `assets/items/generated/chest_leather_rare.png` is physically missing** (`assets/items/armor/` does not exist either). Renders fallback glyph in UI.
2. **HIGH — `⏳` (`U+23F3`) Emoji Regex Gap Breaking 6 `res_time_*` Resources (`supabase/seeds/plan2_resources.generated.sql:90-95` + `lib/utils/item_icon_resolver.dart:22-25,276-277`)**:
   - Rows: `res_time_common` (`:90`), `res_time_uncommon` (`:91`), `res_time_rare` (`:92`), `res_time_epic` (`:93`), `res_time_legendary` (`:94`), `res_time_mythic` (`:95`) all set `icon = '⏳'` (`U+23F3` HOURGLASS WITH FLOWING SAND).
   - Physical PNGs `assets/items/generated/res_time_{common,uncommon,rare,epic,legendary,mythic}.png` **all exist on disk** and are covered by `pubspec.yaml:102`.
   - **Root Cause**: `lib/utils/item_icon_resolver.dart:22-25` defines `_emojiRegex = r'^[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]+$'`, which excludes Miscellaneous Technical `U+2300–U+23FF` (`⏳` = `U+23F3`). Consequently `isLikelyEmoji('⏳')` returns `false`, so `candidateAssetPathsFor` (`L276-277`) uses `key = '⏳'` instead of falling back to `itemId` (`res_time_*`), probing non-existent `assets/items/generated/⏳.png`! (Meanwhile `ItemIconView` at `lib/components/common/item_icon_view.dart:141` uses a different regex that *does* treat `⏳` as emoji only after all candidate PNGs fail — bypassing the generated artwork.)
3. **WARN — Stale Primary Path in `supabase/seeds/flutter_item_icon_updates.generated.sql:4-6`**:
   - Updates `boots_moccasins_{common,epic,legendary}` to `icon = 'assets/icons/armor/boots_moccasins_*.png'`.
   - Neither `assets/icons/armor/` nor normalized `assets/items/armor/` (`lib/utils/item_icon_resolver.dart:245`) exists on disk; the first two candidate asset loads fail on every render before falling back to `assets/items/generated/boots_moccasins_*.png`.
4. **WARN — Unmapped `type = 'catalyst'` in `supabase/seeds/plan1_consumables.generated.sql:18-23`**:
   - 6 `catalyst_*` rows (`catalyst_luck_common..legendary`, `catalyst_power_rare`) resolve cleanly to `assets/items/generated/catalyst_*.png`, but `'catalyst'` is missing from `ItemType` (`lib/models/item_model.dart:3-13`, falling back to `ItemType.material` at `L460`) and relies on `key.startsWith('catalyst_')` in `lib/utils/item_icon_resolver.dart:97`.

---

## Gate 4: Binary Integrity (GLB, PNG, JPG, TTF) & `<45 MB` GitHub Gate

### 4.1 GitHub `<45 MB` File Size Gate (4,139 Git-Tracked Files)
| Severity | File Path | Size (Bytes) | Size (MB) | Tracked in Git | Gate (`<45 MB`) |
| :---: | :--- | ---: | ---: | :---: | :---: |
| **CRITICAL** | `backups/2026-07-22-yedek/full_data.sql:1` | 81,870,438 | **78.08 MB** | **YES** | **FAIL (>45 MB)** |
| **WARN** | `assets/textures/pbr_2k/stone_wall/{Rock030_2K-PNG_NormalGL,normal,normal_gl,normal_opengl}.png` (4 identical copies) | 24,380,693 ea | 23.25 MB ea | YES | PASS *(93.0 MB duplicate bloat)* |
| **WARN** | `assets/textures/pbr_2k/stone_wall/{Rock030_2K-PNG_NormalDX,normal_dx,normal_directx}.png` (3 identical copies) | 24,373,834 ea | 23.24 MB ea | YES | PASS *(69.7 MB duplicate bloat)* |
| **WARN** | `assets/textures/pbr_2k/ground_dirt/{Ground037_2K-PNG_NormalDX,normal_dx,normal_directx}.png` (3 identical copies) | 24,339,858 ea | 23.21 MB ea | YES | PASS *(69.6 MB duplicate bloat)* |
| **WARN** | `assets/textures/pbr_2k/ground_dirt/{Ground037_2K-PNG_NormalGL,normal,normal_gl,normal_opengl}.png` (4 identical copies) | 24,337,199 ea | 23.21 MB ea | YES | PASS *(92.8 MB duplicate bloat)* |

- Largest `.glb` file on disk: `assets/models/props/Banner.glb` (**2.71 MB** — well under 45 MB).

### 4.2 Binary glTF 2.0 (`.glb`) Header & Geometry Audit (215 Files)
- **Header & Structure**: **215 / 215** `.glb` files in `assets/models/` have valid `glTF` magic (`0x46546C67`), version `2`, exact container byte length matching file size, valid JSON chunk (`0x4E4F534A`), and **non-zero mesh & vertex counts** (`min` vertices > 0 across all 215 models).
- **WARN — 10 GLB Files With Broken External Texture URI (`Textures/colormap.png`)**:
  These 10 Kenney/KayKit exports reference an external relative URI `'Textures/colormap.png'` inside their glTF `images` array instead of an embedded bufferView, and neither `assets/models/environment/Textures/colormap.png` nor `assets/models/monsters/Textures/colormap.png` exists on disk or in `pubspec.yaml`:
  1. `assets/models/environment/altar-stone.glb`
  2. `assets/models/environment/cliff.glb`
  3. `assets/models/environment/column-large.glb`
  4. `assets/models/environment/crypt-large.glb`
  5. `assets/models/environment/fire-basket.glb`
  6. `assets/models/environment/pillar-obelisk.glb`
  7. `assets/models/environment/rock_boulder.glb`
  8. `assets/models/monsters/character-zombie.glb`
  9. `assets/models/monsters/ghost.glb`
  10. `assets/models/monsters/zombie.glb`
- **WARN — `MeshAssetRegistry` (`lib/core/assets/mesh_asset_registry.dart`) Metadata Drift**:
  - `lib/core/assets/mesh_asset_registry.dart:317` defaults `ModelLodInfo.isDracoCompressed = true`, mislabeling uncompressed `battleaxe.glb` (`:1622`), `magic_staff.glb` (`:1652`), and `Dagger.glb` (`:1682`) as Draco-compressed (neither `KHR_draco_mesh_compression` nor `EXT_meshopt_compression` is present in their glTF JSON).
  - All 42 `ModelLodInfo` entries (`:1571-2264`) match physical `fileSizeBytes` 100%, and all 74 unique paths in `MeshAssetRegistry` exist on disk & in `pubspec.yaml`, but hardcoded `vertexCount`/`triangleCount` metadata diverges from actual GLB accessor counts (e.g., `Sword_LOD0.glb` at `:1571`: declared `2210`v/`4280`t vs actual `1956`v/`1006`t).
  - 16 `path*` constants (`:1162-1225`) are not registered in `_registerDefaultCc0Catalog()`; 157 of 215 physical `.glb` files are consumed directly by screen/facility resolvers outside `MeshAssetRegistry`.

### 4.3 PNG, JPEG & Font Binary Integrity (PASS)
- **722 / 722 PNGs**: Valid 8-byte PNG signature (`89 50 4E 47 0D 0A 1A 0A`), valid 13-byte `IHDR`, positive dimensions (`<= 2048×2048`), and valid trailing `IEND` chunk. Zero corrupt or 0-byte PNGs.
- **91 / 91 JPEGs**: Valid SOI magic (`FF D8 FF`) and EOI marker, non-zero dimensions.
- **30 / 30 TTF Fonts** (`assets/google_fonts/*.ttf`): Valid TrueType/OpenType sfnt header (`00 01 00 00` / `OTTO`), non-zero size.

---

## Gate 5: GLSL Shader Uniform Layouts vs Dart Packers

### 5.1 Runtime Impeller Fragment Shaders (16 / 16 Layout Parity PASS)
Verified every `#version 460 core` Impeller shader's float uniform slot count (accounting for `float`=1, `vec2`=2, `vec3`=3, `vec4`=4, `mat4`=16, arrays `vec4[N]`=`4*N`) and `sampler2D` count against Dart `setFloat(...)` and `setImageSampler(...)` calls:

| Shader File | Bundled in `pubspec.yaml` | GLSL Floats | Dart `setFloat` Slots | GLSL Samplers | Dart Samplers | Dart Packer (`path:line`) | Parity |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- | :---: |
| `shaders/postprocess/aces_tonemap.frag` | YES (`:179`) | 8 | `0..7` (8) | 1 | `0` (1) | `lib/rendering/postprocess/postprocess_pipeline.dart:67` | **PASS** |
| `shaders/postprocess/ssao.frag` | YES (`:180`) | 9 | `0..8` (9) | 2 | `0..1` (2) | `lib/rendering/postprocess/postprocess_pipeline.dart:84` | **PASS** |
| `shaders/postprocess/ssao_bilateral_blur.frag` | YES (`:181`) | 6 | `0..5` (6) | 2 | `0..1` (2) | `lib/rendering/postprocess/postprocess_pipeline.dart:102` | **PASS** |
| `shaders/postprocess/ssao_composite_aces.frag` | YES (`:182`) | 8 | `0..7` (8) | 2 | `0..1` (2) | `lib/rendering/postprocess/postprocess_pipeline.dart:118` | **PASS** |
| `shaders/lighting/dungeon_lighting.frag` | YES (`:184`) | 109 | `0..108` (109) | 1 | `0` (1) | `lib/core/lighting/dungeon_light_system.dart:1082` | **PASS** |
| `shaders/materials/aion2_pbr_master.frag` | YES (`:186`) | 54 | `0..53` (54) | 4 | `0..3` (4) | `lib/core/materials/aion2_material_system.dart:853` | **PASS** |
| `shaders/vfx/forge_fire.frag` | YES (`:188`) | 18 | `0..17` (18) | 0 | 0 | `lib/screens/crafting/widgets/crafting_forge_effects.dart:564` | **PASS** |
| `shaders/vfx/gpu_particles.frag` | YES (`:189`) | 24 | `0..23` (24) | 0 | 0 | `lib/core/vfx/gpu_particle_system.dart:1147` | **PASS** |
| `shaders/vfx/ground_decal.frag` | YES (`:190`) | 26 | `0..25` (26) | 3 | `0..2` (3) | `lib/core/vfx/ground_decal_system.dart:1227` | **PASS** |
| `shaders/vfx/ribbon_trail.frag` | YES (`:191`) | 22 | `0..21` (22) | 1 | `0` (1) | `lib/core/vfx/ribbon_trail_renderer.dart:1017` | **PASS** |
| `shaders/vfx/rim_hit_flash.frag` | YES (`:192`) | 13 | `0..12` (13) | 2 | `0..1` (2) | `lib/core/vfx/rim_hit_flash_effect.dart:684` | **PASS** |
| `shaders/vfx/shockwave_refraction.frag` | YES (`:193`) | 18 | `0..17` (18) | 2 | `0..1` (2) | `lib/core/vfx/refraction_effect.dart:729` | **PASS** |
| `shaders/world/atmospheric_sky.frag` | YES (`:195`) | 39 | `0..38` (39) | 0 | 0 | `lib/core/world/dynamic_skybox.dart:1505` | **PASS** |
| `shaders/world/puddle_ssr.frag` | YES (`:196`) | 27 | `0..26` (27) | 2 | `0..1` (2) | `lib/core/world/puddle_reflection_layer.dart:861` | **PASS** |
| `lib/shaders/social/glsl/celestial_banner.frag` | **NO** *(CRITICAL)* | 17 | `0..16` (17) | 0 | 0 | `lib/shaders/social/social_shaders.dart:72` | **Layout PASS / Unbundled** |
| `lib/shaders/social/glsl/emblem_aura.frag` | **NO** *(CRITICAL)* | 14 | `0..13` (14) | 0 | 0 | `lib/shaders/social/social_shaders.dart:178` | **Layout PASS / Unbundled** |

*(Note: Non-Impeller vertex/UBO/SSBO shaders `shaders/crowd/{vat_crowd.vert,vat_crowd.frag,gpu_instancing.vert}` and `shaders/lighting/clustered_crowd_lighting.frag` use `#version 300 es` / `450` / `std140` / `std430` blocks and are appropriately listed under `flutter.assets` at `pubspec.yaml:172-175` rather than `flutter.shaders`.)*

### 5.2 WARN — `ShaderCatalog` (`lib/core/shaders/shader_registry.dart`) Metadata Drift
- `lib/core/shaders/shader_registry.dart:614-635`: Descriptor for `shaders/lighting/dungeon_lighting.frag` lists only `uResolution` (`floatCount: 2`, `samplerCount: 1`), whereas the physical GLSL shader has **109 floats** (correctly packed by `DungeonLightSystem` at `lib/core/lighting/dungeon_light_system.dart:1082`).
- 4 physical shaders (`shaders/materials/aion2_pbr_master.frag`, `shaders/world/atmospheric_sky.frag`, `shaders/world/puddle_ssr.frag`, `shaders/lighting/clustered_crowd_lighting.frag`) are not registered in `ShaderCatalog.defaultDescriptors`, while 3 deleted/uncreated shaders (`wind_vegetation.frag`, `water_puddle.frag`, `volumetric_fog.frag`) remain registered (`:350-352`, `:1414-1565`).

---

## Prioritized Remediation Checklist

1. **[CRITICAL — Git `<45 MB`]** Untrack & remove `backups/2026-07-22-yedek/full_data.sql:1` (78.08 MB) and add `backups/**/*.sql` to `.gitignore`.
2. **[CRITICAL — Case-Sensitive GLB]** Change `'assets/models/environment/Chest.glb'` → `'assets/models/environment/chest.glb'` at `lib/screens/facilities/widgets/facility_3d_model_resolver.dart:146`, `:409`, and `lib/components/kingdom/kingdom_realm_3d_viewport.dart:257`.
3. **[CRITICAL — Social & World Shaders]** Move or register `celestial_banner.frag` & `emblem_aura.frag` under `shaders/social/` and add them to `pubspec.yaml:177-201` (`flutter.shaders:`); delete `lib/shaders/social/glsl/test.txt`; remove or implement `shaders/world/{wind_vegetation,water_puddle,volumetric_fog}.frag` in `lib/screens/home/widgets/hub_wind_vegetation.dart:1064` and `lib/core/shaders/shader_registry.dart:350-352`.
4. **[CRITICAL — Missing Seed Icon]** Generate/commit `assets/items/generated/chest_leather_rare.png` for `supabase/seeds/plan1_items.generated.sql:44`.
5. **[HIGH — `⏳` Emoji Resolver Bug]** Add `\u{2300}-\u{23FF}` to `ItemIconResolver._emojiRegex` at `lib/utils/item_icon_resolver.dart:23` so `supabase/seeds/plan2_resources.generated.sql:90-95` (`res_time_*`) resolves via `itemId` to `assets/items/generated/res_time_*.png`.
6. **[WARN — Hygiene & Bloat]** Deduplicate 14 × 23.2 MB normal maps in `assets/textures/pbr_2k/{ground_dirt,stone_wall}/`, embed or supply `Textures/colormap.png` for the 10 Kenney/KayKit `.glb` models, bundle `RobotoMono` & `SourceCodePro` TTFs (or switch to `JetBrainsMono`), clean 12 empty parent dir entries in `pubspec.yaml`, and sync `MeshAssetRegistry` / `ShaderCatalog` metadata.
