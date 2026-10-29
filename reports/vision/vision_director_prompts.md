# AION 2 MOBILE VISUAL TRANSFORMATION — CREATIVE DIRECTOR PROMPTS & IMPROVEMENT DIRECTIVES

**Document**: `reports/vision/vision_director_prompts.md`  
**Author**: `vision_prompt_director` (Autonomous Creative Director & Product Owner Proxy)  
**Date**: 2026-10-28T21:30:00Z  
**Target Repository**: `gkk_flutter` (`prawn`)  
**Mission**: Guide, challenge, and mobilize the 200-subagent army toward the definitive 2027 Aion 2 mobile visual fidelity, PBR shader perfection, and uncompromising closed-loop quality gates.

---

## 1. Creative Director Vision & Executive Manifesto

> *"We are not building a generic mobile toy, and we are not accepting 2005-era flat polygons. gkk_flutter is being elevated into a top-tier 2027 AAA mobile dark-fantasy masterwork. Every surface must tell a story through authentic PBR textures, every spell must radiate with volumetric luminance and refracted shockwaves, and every frame must run like silk at 60 FPS on iOS and Android devices. No primitive cube assemblies, no placeholder URLs, no unwired code. We push together at full concurrency until victory!"*

---

## 2. Forensic Status Assessment (Repo State as of 2026-10-28T21:30:00Z)

Our live inspection across assets, shaders, screens, and test suites reveals significant architectural triumphs alongside urgent critical quality gates that must be surmounted immediately:

### 2.1. The Wins (Groundwork Established)
1. **Authoritative Aion 2 Art Direction Bible (`reports/art/aion2_art_direction_bible.md`)**:
   - Masterfully defined Kelvin lighting science (2200K warm torch to 9000K cold ethereal cyan), Elyos/Daeva vs. Asmodian/Archon palettes, and 9 core production pillars.
2. **First Genuine Aion 2 Draco Assets (`assets/models/aion2/`)**:
   - `aion2_dark_fantasy_sword.glb`, `aion2_ethereal_wings.glb`, and `aion2_gothic_dungeon_pillar.glb` have been synthesized with 4-tier LOD hierarchies (LOD0, LOD1, LOD2, Impostor) and Draco level 7 compression.
   - Accompanied by 15 real 1024x1024 PBR image maps (`assets/models/aion2/textures/`: Albedo, Normal, Roughness, Metallic, Emission).
3. **14 Impeller GLSL Shaders Declared in `pubspec.yaml`**:
   - ACES Tonemap, SSAO, Bilateral Blur, SSAO Composite ACES, Dungeon Lighting, Clustered Crowd Lighting, Rim Hit Flash, Ribbon Trail, GPU Particles, Shockwave Refraction, Ground Decal, Puddle SSR, Atmospheric Sky, and Aion 2 PBR Master.
4. **Architectural Screen Wiring**:
   - `HomeScreen` is wired with `HubSceneViewport` coordinating dynamic skybox GI, PBR cobblestones, foliage wind vertex displacement, puddle SSR reflections, volumetric god rays, and ACES tonemapping.
   - `DungeonBattleScreen` is wired with `DungeonAtmosphereController`, triggering procedural scorch marks, slash gouges, blood splatters, and screen shake on combat hits.

---

### 2.2. The Critical Quality Gates & Deficiencies (VETO ALERTS)

1. **VETO ALERT #1: Primitive Blockout Props & Empty Textures (`assets/models/props/`)**:
   - The Visual Challenger (`screenshot_4_audit_challenger`) has issued a formal **VETO / REJECT**:
   - `scripts/blender/procedural_props.py` constructs props using basic `create_cube`, `create_uvsphere`, and `create_cone` primitives.
   - The directories in `assets/models/textures/` (`Brazier_IronEmbers`, `Flagstones_CrackedTile`, etc.) are completely **EMPTY** (0 bytes).
   - **Directive**: Replace or sculpt these props with authentic CC0 photogrammetric/high-poly geometry, or source authentic CC0 models with genuine image-based PBR maps.
2. **VETO ALERT #2: Missing Model Asset Registration in `pubspec.yaml`**:
   - `pubspec.yaml` lists images, UI, and shaders under `assets:`, but **omits `assets/models/` and `assets/models/aion2/`**!
   - Flutter runtime AssetBundle cannot package or load `.glb` models unless their paths are registered in `pubspec.yaml`.
3. **VETO ALERT #3: Missing Real Mobile Screenshots & Visual Inspection Report**:
   - `reports/screenshots/blender_renders/` is currently EMPTY (0 PNG files).
   - `reports/screenshots/mobile_goldens/` only contains a basic probe (`test_probe.png`).
   - Authentic 390x844 mobile golden screenshots for `HomeScreen`, `DungeonBattleScreen`, `CharacterScreen`, and `InventoryScreen` must be rendered and captured.
   - `reports/screenshots/visual_inspection_report.md` has not yet been authored by `screenshot_3_visual_inspector`.

---

## 3. Action Battalions for the 200 Subagents Army

To achieve unanimous 5/5 pass across all Chief Auditors, the 200 subagents army must execute these synchronized operational directives:

### Battalion 1: Asset Realism & PBR Purity Corps
- **Purge Primitive Blockouts**: Ensure all 3D props and environmental meshes use authentic high-density geometry with beveled edges, sculpted details, and UV unwraps. No raw cubes, spheres, or cones masquerading as game assets.
- **Image-Based PBR Texture Maps**: Ensure every single model has genuine 1K/2K texture maps (Albedo, NormalGL, Roughness, Metallic, AO, and Emission where applicable).
- **Pubspec Asset Registry**: Add `- assets/models/` and `- assets/models/aion2/` to `pubspec.yaml` so that runtime asset loading succeeds in release builds.

### Battalion 2: Impeller Shader & Mobile Lighting Corps
- **Zero-Warning Shader Compilation**: Verify all 14 GLSL fragment shaders compile cleanly under Impeller's shader compiler (`impellerc`) without uniform layout mismatches or precision errors.
- **Mobile TBDR Efficiency**: Minimize overdraw in transparent passes (ribbon trails, particle emitters, volumetric fog). Keep texture sampling within mobile GPU memory bandwidth limits.
- **Kelvin Temperature Contrast**: Emphasize the dramatic visual tension of Aion 2: warm golden torchlight (2200K) against chilly abyssal shadows and ethereal cyan celestial radiance (9000K).

### Battalion 3: Closed-Loop Screenshot & Visual QA Corps
- **Blender Beauty Renders**: `screenshot_1_blender_renderer` must produce high-resolution mobile portrait renders (1080x2400) of the Main Hub and Dungeon scenes and save them to `reports/screenshots/blender_renders/`.
- **Flutter Mobile Goldens**: `screenshot_2_flutter_golden_capture` must expand `mobile_screenshot_suite_test.dart` to capture authentic 390x844 mobile frames with notch / Dynamic Island safe areas across all major game screens.
- **Pixel-Level Visual Audit**: `screenshot_3_visual_inspector` must visually inspect all generated PNGs and write `reports/screenshots/visual_inspection_report.md`, certifying that 2005-era graphics are eradicated and 2027 Aion 2 standards are fully met.

### Battalion 4: 10,000 Crowd & Mobile Optimization Corps
- **Adaptive Performance Tiers**: Validate seamless switching between Eco (30 FPS, aggressive culling, low RAM), Medium, High, and Ultra Aion 2 (60/120 FPS, full PBR, god rays, bloom).
- **Zero-Jank Preloader**: Ensure preloading and shader warm-up remain strictly budgeted under 2ms per frame, avoiding cold-start stalls.

### Battalion 5: The Council of 5 Chief Auditors
- `chief_auditor_1_real_assets`: Verify physical existence of real `.glb` models, 2K PBR textures, and Draco compression on disk.
- `chief_auditor_2_mobile_visual_qa`: Audit mobile screenshots and ensure all 14 shaders are actively producing visual magic.
- `chief_auditor_3_combat_gameplay`: Certify that combat juice (particles, trails, camera shake, hit-stop, decals) enhances game feel without altering underlying mobile RPG rules.
- `chief_auditor_4_mobile_perf_10k`: Validate the 10,000 entity crowd rendering and mobile memory footprint.
- `chief_auditor_5_e2e_forensic`: Enforce 100% test suite pass, zero flutter analyze errors, clean pubspec registration, and git tree readiness.

---

## 4. Vision Director Directives for Sub-Orchestrators & Workers

Use these exact directives to align and energize all active sub-orchestrators:

```text
[DIRECTIVE FOR ASSET CORPS]:
"Register assets/models/ and assets/models/aion2/ in pubspec.yaml immediately!
Audit all 36 props in assets/models/props/: eliminate all primitive blockout geometry.
Deliver high-detail sculpted geometry and authentic image-based 1K/2K PBR texture maps.
Every single asset must look like it belongs in Aion 2 (2027)!"

[DIRECTIVE FOR SCREENSHOT & QA CORPS]:
"Execute Blender render pipeline scripts now! We need the 1080x2400 beauty shots of the Main Hub and Gothic Dungeon in reports/screenshots/blender_renders/.
Execute the Flutter mobile golden capture suite across HomeScreen, DungeonBattleScreen, CharacterScreen, and InventoryScreen at 390x844 with safe area insets.
Author reports/screenshots/visual_inspection_report.md with empirical image proof.
Do not stop until the Visual Challenger's veto is turned into an enthusiastic APPROVAL!"

[DIRECTIVE FOR INTEGRATION & ENGINE CORPS]:
"Verify flutter analyze passes with 0 errors. Ensure every shader declared in pubspec.yaml is cleanly hooked into the runtime render pipeline. Protect mobile 60 FPS performance and thumb ergonomics. We are shipping a masterpiece for Android and iOS!"
```

---

## 5. Continuous Momentum & Concurrency Mandate

We are building history on `gkk_flutter`. The Creative Direction is set, the bar is high, and our standards are absolute. No half-measures. No stopping. Full speed ahead!

**Hedefe tam cila ile ulaşana kadar durmak yok — tam kapasite 200 subagents!**
