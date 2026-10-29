# AION 2 DARK / HIGH-FANTASY ART DIRECTION BIBLE & SHADER SPECIFICATION
**Project**: `gkk_flutter` AAA Graphics Modernization  
**Authority**: Lead Art Director (`aion2_1_art_director`)  
**Version**: 2.0.0 — Production Benchmark  
**Status**: Authoritative Reference Standard  
**Target Visual Fidelity**: 2027 Cinematic AAA Dark/High-Fantasy MMORPG (Aion 2 Benchmark)

---

## 1. EXECUTIVE VISION & CORE AESTHETIC PHILOSOPHY

### 1.1 The Aion 2 Aesthetic Benchmark
The visual identity of `gkk_flutter` transcends conventional stylized mobile gaming, transitioning into an authoritative **Aion 2-tier Dark and High-Fantasy MMORPG experience**. This aesthetic is characterized by:
- **Heroic Grandeur**: Monumental scale in architecture, dramatic verticality, and imposing character silhouettes.
- **Duality of Light and Shadow**: The sharp juxtaposition between ethereal celestial luminescence (*Elyos / Daeva*) and oppressive, dark gothic obsidian depths (*Asmodian / Archon*).
- **Physical Realism Infused with Arcane Energy**: Materials obey rigorous Physically Based Rendering (PBR) laws (metallic-roughness workflow), punctuated by hyper-vibrant, high-dynamic-range (HDR) runic emissives and translucent energy fields.
- **Cinematic Atmospheric Depth**: Every scene must breathe through multi-layered volumetric fog, crepuscular light shafts (god rays), dynamic weather reflections, and airborne micro-particles.

```
       [ CELESTIAL RADIANCE: DAEVA ]               [ ABYSSAL OBSIDIAN: ARCHON ]
   Ivory Plate • Filigree Gold • Solar Motes     Black Steel • Shadow Violet • Cold Spark
                       \                               /
                        \                             /
                         ▼                           ▼
                 ┌───────────────────────────────────────────┐
                 │       AION 2 CORE VISUAL PHILOSOPHY       │
                 │   - Physically Grounded PBR Foundations   │
                 │   - Luminous Arcane Translucency & Wings  │
                 │   - Gothic Verticality & Volumetrics      │
                 │   - High-Impact Cinematic Combat Shaders  │
                 └───────────────────────────────────────────┘
```

### 1.2 Core Visual Pillars
1. **Pillar 1: Ornate Material Contrast**  
   Never permit flat, uniform surfaces. Every surface must display micro-detail: etched filigree on burnished steel, micro-scratches on polished gold, wet slick coats on pitted stone, and layered velvet textures under metal plates.
2. **Pillar 2: Luminous Ethereality (Wings & Arcana)**  
   Wings are not static textures; they are living manifestations of pure Aether. They feature anisotropic feather sheen, translucent membrane backscattering, gradient emission at the feather shafts, and trailing starlight dust.
3. **Pillar 3: Somber Monumentality (World & Architecture)**  
   Environments evoke ancient fallen empires: towering gothic arches, ribbed vaults, monolithic obsidian spires carved with dormant runes, and damp cobblestones reflecting distant torchlight.
4. **Pillar 4: Kinetic Brutality & Spell Radiance (VFX)**  
   Combat impacts must possess tangible physical weight. Weapon swings cast sweeping ribbon trails with lightning cores; critical hits trigger chromatic wing bursts; spells manifest through multi-tiered concentric runic circles; impacts tear ground meshes with glowing molten fissures.

---

## 2. CHARACTER MODEL BENCHMARKS & MATERIAL GUIDELINES

```
             ┌──────────────────────────────────────────────────┐
             │            CHARACTER SILHOUETTE MATRIX           │
             ├──────────────────────────────────────────────────┤
             │ Head Ratio: 8.5 : 1 (Heroic Proportions)         │
             │ Shoulder Width: Broad, tapered v-torso           │
             │ Armor Silhouette: Flared pauldrons, sharp tips   │
             │ Wing Span: 2.4x - 3.2x character height          │
             │ Cape/Tassets: Trailing cloth with gravity bias   │
             └──────────────────────────────────────────────────┘
```

### 2.1 Ornate Metallic Armor (Daeva / Archon Champions)
Every armor set must exhibit clear material layer separation:
1. **Primary Structural Plate (60% Surface Area)**:
   - *Daeva*: Cold forged celestial silver/mithril with subtle blued specular glint.
   - *Archon*: Blackened carbon steel or abyssal iron with dark gunmetal anisotropic highlights.
   - Micro-detail: Directional brushed polish normal overlay, micro-scratches (`roughness` modulation of ±0.08), edge wear highlights.
2. **Ornate Filigree & Inlays (25% Surface Area)**:
   - Raised relief trims (0.5mm - 2.0mm procedural bevel or normal displacement).
   - *Daeva*: Burnished imperial gold (`#E5B842`, metallic 1.0, roughness 0.22) with delicate floral and angelic knotwork.
   - *Archon*: Crimson-tinted obsidian or deep electrum (`#A33B3B`, metallic 0.95, roughness 0.18) with sharp barbed runes.
3. **Flexible Sub-Layers & Undergarments (15% Surface Area)**:
   - Quilted arming doublet (velvet / heavy weave cloth, anisotropic sheen, metallic 0.0, roughness 0.85).
   - Padded leather straps (`#2E1F18`, roughness 0.55, metallic 0.05) with brass buckles.

### 2.2 Glowing Ethereal Wings (Daeva & Archon Wings)
Wings represent the pinnacle of Aion 2 character artistry. A single static mesh is strictly prohibited. Wings must be composed of a multi-mesh hierarchy:
- **Layer 1: Structural Bone & Primary Quill Mesh**:
   - Rigid armature, ornate metallic root casing, specular highlights along the lead edge.
- **Layer 2: Volumetric Secondary Feathers**:
   - Layered feather planes with alpha-to-coverage and dithered transparency.
   - Double-sided custom shading with subsurface light transmission (backscattering).
- **Layer 3: Ethereal Energy Membrane & Motes**:
   - Translucent outer aura driven by view-angle Fresnel.
   - Scrolling procedural caustic texture simulating flowing liquid Aether.
   - Particle emitter spawning downward-drifting luminous embers/feathers that dissolve over 1.2 seconds.

```
       WING STRUCTURE DIAGRAM:
       
       [Armature Root]
             │
             ├──► [Primary Quills] ──► Solid Base, Metallic Accent (Roughness 0.3)
             │
             ├──► [Mid Feather Planes] ──► Subsurface Scattering + Fresnel Edge Glow
             │
             └──► [Outer Ethereal Aura] ──► Translucent Membrane, Scrolling Noise
                                           └─► Spawns Starlight Motes (GPU Particles)
```

#### Wing Archetype Comparison:
| Feature | Daeva (Celestial Seraph) | Archon (Abyssal Sovereign) |
|---|---|---|
| **Feather Core Tone** | Pure Pearlescent Ivory (`#F5F7FA`) | Deep Abyssal Slate / Void Violet (`#120E18`) |
| **Energy Vein Color** | Solar Gold / Cyan Gradient (`#FFE494` -> `#7CE8FF`) | Electric Violet / Crimson Pulse (`#B145FF` -> `#FF2A6D`) |
| **Fresnel Rim Color** | Warm Starlight Cyan (`#A3F2FF`, 9500K) | Saturated Nebula Magenta (`#DC47F5`, 14000K) |
| **Particle Motes** | Floating crystalline sparks, falling light plumes | Smoldering void cinders, crackling electrical arcs |
| **Rest Idle Motion** | Gentle breathing cycle (0.4 Hz sine flutter) | Predatory twitch and flare (0.2 Hz slow pulse with micro-snaps) |

### 2.3 Flowing Cloth & Cape Dynamics
- **Shader Requirements**: Vertex displacement using dual-frequency sine wave modulation combined with character velocity vectors:
  $$\vec{D}_{\text{cloth}} = \vec{V}_{\text{velocity}} \times (-0.15) + \sin(\omega_1 t + \vec{P} \cdot \vec{K}_1) \vec{A}_1 + \cos(\omega_2 t + \vec{P} \cdot \vec{K}_2) \vec{A}_2$$
- **Micro-Fabric Shading**: Velvet/Cloth approximation using inverted Fresnel (rim light grazing softness):
  $$I_{\text{sheen}} = \left(1.0 - \vec{N} \cdot \vec{V}\right)^4 \times C_{\text{fabric\_tint}}$$

---

## 3. ENVIRONMENT & WORLD ARCHITECTURE BENCHMARKS

```
     ┌───────────────────────────────────────────────────────────────┐
     │                AION 2 WORLD VISUAL ANATOMY                    │
     ├───────────────────────────────────────────────────────────────┤
     │  SKY / CELESTIAL CANOPY: Shattered moon, swirling Aether rift │
     │  VERTICAL SILHOUETTE: Towering gothic buttresses, spires      │
     │  MIDGROUND: Obsidian monoliths, ancient weathered arches      │
     │  FOREGROUND: Reflective wet cobblestones, puddle SSR, moss    │
     └───────────────────────────────────────────────────────────────┘
```

### 3.1 Gothic Cathedrals & Monolithic Citadels
- **Architectural Style**: French Gothic meets Dark Brutalism. Soaring lancet windows, sharp gargoyles, multi-tiered rose windows, and ribbed groin vaults.
- **Stone Material Standards**:
  - Weathered Granitic Ashlar (`albedo`: `#38373B`, `roughness`: 0.74, `metallic`: 0.02).
  - Deep recess Ambient Occlusion (AO) baked into vertex channels or packed into the Red channel of the ORM map (Occlusion, Roughness, Metallic).
  - Crevice dirt and creeping pale moss in upward-facing normal masks ($N_y > 0.65$).
- **Stained Glass & Divine Windows**:
  - Transmissive unlit emission with high HDR values (2.5 - 4.0 multiplier) projecting volumetric caustic shafts onto the floor.

### 3.2 Monolithic Obsidian Pillars
- Monolithic spires that defy conventional gravity, suspended in mid-air or rising diagonally from shattered ground.
- **Visual Properties**:
  - Glassy, dark volcanic obsidian (`#0F1115`, `metallic`: 0.88, `roughness`: 0.04 - 0.12).
  - Sharp, fractured conchoidal cleavage along edge bevels.
  - Ancient glowing runic carvings embedded flush with stone faces:
    * Dormant state: Deep dormant crimson (`#380A0A`, emission 0.2).
    * Active/Combat state: Scorching solar gold (`#FFAE19`, emission 4.8) pulsing with a 1.5 Hz breathing curve.

### 3.3 Reflective Wet Cobblestones & Terrain Shading
Ground planes in the Open Hub and Dungeons are the primary contact surface for players. Flat tiling textures are strictly prohibited.
- **Layer 1: Base Cobblestone**:
  - Hand-hewn uneven river stones with deep grout channels.
  - Normal map intensity: 1.25x with micro-cavity displacement.
  - Dry stone roughness: 0.72 - 0.88.
- **Layer 2: Wetness & Puddle Masking**:
  - Height-based water accumulation: Puddles collect in cavities where height $H < H_{\text{threshold}}$.
  - Water surface roughness: 0.015 - 0.035 (specular mirror reflection).
  - Transition zone: 5cm damp edge where roughness drops smoothly from 0.75 to 0.10 and albedo darkens by 35% (diffuse darkening due to water saturation).
- **Layer 3: Dynamic Rain Ripples**:
  - Animated dual-layer normal map generating concentric expanding ring ripples ($1.8 \text{ Hz}$).

### 3.4 Volumetric Sun Rays (God Rays) & Atmospheric Scattering
- **Scattering Model**: Henyey-Greenstein phase function for forward-scattering Mie volumetrics through mountain gaps and cathedral clerestory windows:
  $$p(\theta) = \frac{1}{4\pi} \frac{1 - g^2}{\left(1 + g^2 - 2g \cos\theta\right)^{3/2}}$$
  where $g = 0.65$ (strong forward scattering toward the camera).
- **Atmospheric Palette**:
  - Day / High Pass: Golden sunlight shafts (5200K) piercing deep cobalt shadows (9500K ambient sky).
  - Dusk / Cataclysm: Violet-tinted crepuscular beams (7200K) illuminating low-hanging mountain mist.

---

## 4. COMBAT VFX & KINETIC FEEDBACK BENCHMARKS

```
  [ ATTACK SEQUENCE ] ──► [ HIT IMPACT (t = 0) ] ──────────────► [ RECOVERY & AFTERMATH ]
         │                           │                                      │
  - Lightning Ribbon Trail    - 40ms Hit-Stop (Time dilation 0.05)   - Dissipating Embers
  - Multi-Ring Magic Circles   - Directional Camera Shake (8-12px)    - Molten Ground Fissure
  - Weapon Charge Glow        - 4-Frame Rim Hit Flash (White-hot)    - Residual Smoke Plumes
                              - Ethereal Wing Burst on Critical Hit
```

### 4.1 Multi-Layered Magic Rings & Runic Incantations
Cast rings must not be flat 2D sprites. They consist of a 4-tiered concentric dynamic hierarchy:
1. **Tier 1: Central Glyphic Core (Radius $0.0 - 0.4$)**:
   - Rotating high-density runic script (clockwise, $\omega = 0.8 \text{ rad/s}$).
   - Color: White-hot core (`#FFFFFF`) bleeding into saturated spell color.
2. **Tier 2: Sacred Geometry Star / Octagram (Radius $0.35 - 0.75$)**:
   - Geometric intersecting lines with sharp additive bloom.
   - Counter-rotating ($\omega = -0.45 \text{ rad/s}$).
3. **Tier 3: Outer Runic Inscription Ring (Radius $0.70 - 0.95$)**:
   - High-ancient language runes, individual glyphs pulsing with independent sine offsets.
4. **Tier 4: Barrier Edge & Refractive Shockwave (Radius $0.90 - 1.05$)**:
   - Thin bright perimeter line (thickness 0.012).
   - Screen-space refraction ring distorting the background by 8 - 14 pixels.

### 4.2 Ethereal Wing Flashes (Critical Strikes & Burst Skills)
When a Daeva or Archon scores a Critical Hit or unleashes a Burst Execution:
- **Frame 0 - 3**: Character wings snap outward to 130% scale in a sharp, explosive flare.
- **Frame 1 - 2**: Pure white-hot Fresnel rim flash (`#FFFFFF`, emission 12.0) engulfs the feather silhouettes.
- **Frame 3 - 8**: 160 GPU feather fragments and light sparks detonate radially from the wingtips.
- **Frame 8 - 20**: Exponential return to normal wing scale and idle luminescence.

### 4.3 Lightning-Infused Ribbon Weapon Trails
Melee swings, arrows, and magical projectiles generate continuous ribbon geometry:
- **Geometry**: Quad-strip mesh generated along the weapon blade tip to hilt over the preceding 12 frames.
- **Shader Architecture**:
  - Base Layer: Smooth gradient alpha fade along the trailing edge ($u = 0.0 \text{ at hilt}$, $u = 1.0 \text{ at tip}$).
  - Texture: Scrolling Voronoi / Perlin noise generating jagged electric filament arcs.
  - Core: Over-exposed electric white filament (`#E8FFFF`, width 0.15).
  - Corona: Saturated violet-cyan ionized glow (`#00E5FF` and `#7B1FA2`, width 0.85).
  - Spark Emitters: 20 micro-sparks shed per swing, affected by air resistance and gravity.

### 4.4 Explosive Ground Cracks & Decals
Impacts slamming into the earth fracture the surface:
- **Projection Box**: Projected decal box oriented to the terrain normal.
- **Visual Layers**:
  - Radial fractured basalt fissures with depth-parallax displacement.
  - Subterranean molten lava or glowing blue Aether magma exposed inside fissures (`#FF4500` or `#00E5FF`, emission 6.5).
  - Decal life cycle: 0.1s instant crack opening -> 2.5s smoldering cooling phase (emission shifts from white-yellow -> orange -> dull red -> cold char) -> 1.0s alpha fadeout.
  - Rising embers: 45 GPU cinder particles drifting upward from the open crack.

### 4.5 Kinetic Impact Feel Specifications (Game Feel)
| Feedback Mechanism | Value Range | Implementation Requirement |
|---|---|---|
| **Hit-Stop (Micro-Freeze)** | 35ms - 50ms | Time scale reduced to $0.05$ on impact frame; resumes linearly over $3$ frames. |
| **Directional Camera Shake** | 6px - 14px displacement | Impulse directed along the reverse vector of the strike; decays via damped harmonic oscillator ($\zeta = 0.62$). |
| **Rim-Light Hit Flash** | 4 frames (66ms) | Inverted Fresnel normal flash on the victim's mesh (`#FFFFFF` -> target blood/energy hue). |
| **Chromatic Aberration Spike** | 3.5px offset | RGB split along screen edges during heavy boss hits or ultimate execution abilities. |

---

## 5. MASTER COLOR PALETTES & LIGHTING TEMPERATURE SCIENCE

```
             LIGHTING TEMPERATURE SPECTRUM (KELVIN)
  1800K       2200K        3500K       5500K       7500K        9500K       14000K
    │           │            │           │           │            │           │
    ▼           ▼            ▼           ▼           ▼            ▼           ▼
[Candle]   [Warm Torch]  [Golden Hr]  [Neutral]  [Overcast]  [Leyline Cyan] [Abyssal Void]
(#FF6E1A)   (#FFA73B)    (#FFE2A3)   (#FFF4E8)  (#D4E6FF)    (#5CE1E6)      (#9B51E0)
```

### 5.1 Color Temperature Reference & Radiance Table
| Light Source | Temperature (K) | Hex Representation | Normalized RGB Multiplier | Typical Intensity |
|---|---|---|---|---|
| **Catacomb Torch / Brazier** | 2200K | `#FFA73B` | `vec3(1.000, 0.655, 0.231)` | 800 - 1500 lm |
| **Dungeon Campfire / Forge** | 2600K | `#FFB964` | `vec3(1.000, 0.725, 0.392)` | 1800 - 3200 lm |
| **Sunrise / Golden God-Rays** | 3600K | `#FFE3B0` | `vec3(1.000, 0.890, 0.690)` | 45,000 - 90,000 lx |
| **Neutral Sun (Noon Key)** | 5600K | `#FFF6F0` | `vec3(1.000, 0.965, 0.941)` | 100,000 lx |
| **Sky Ambient (Daylight Shadow)** | 7800K | `#CDE2FF` | `vec3(0.804, 0.886, 1.000)` | 8,000 - 14,000 lx |
| **Aether Leyline / Celestial Well**| 9500K | `#7CE8FF` | `vec3(0.486, 0.910, 1.000)` | 2,500 - 5,000 lm |
| **Abyssal Void / Dark Magic** | 13500K | `#B145FF` | `vec3(0.694, 0.271, 1.000)` | 1,200 - 3,500 lm |

### 5.2 Authoritative Color Hex Palettes

#### A. Daeva Celestial Palette (Elyos / High-Fantasy Divine)
- **Primary Metal (Celestial Mithril)**: `#D6E0EB` (Silver-Blue Sheen)
- **Secondary Filigree (Imperial Gold)**: `#E5B842` (Rich Antique Gold)
- **Tertiary Undercloth (Ivory Silk)**: `#F7F5F0` (Warm Cream White)
- **Emissive Aether (Sunlight Cyan)**: `#4DEEEA` (Radiant Cyan Glow)
- **Deep Accent (Cobalt Royal)**: `#1E3A8A` (Deep Sapphire Blue)

#### B. Archon Abyssal Palette (Asmodian / Dark-Fantasy Shadow)
- **Primary Metal (Obsidian Steel)**: `#15171C` (Near-Black Gunmetal)
- **Secondary Filigree (Cursed Electrum)**: `#8E2828` (Blood Iron Crimson)
- **Tertiary Undercloth (Void Velvet)**: `#24182E` (Deep Nightshade Violet)
- **Emissive Aether (Nebula Magenta)**: `#D946EF` (Intense Electric Purple)
- **Deep Accent (Abyssal Shadow)**: `#090A0F` (True Pitch Black)

#### C. Gothic Environment & Cathedrals
- **Weathered Gothic Stone**: `#3C3B3F` (Granite Grey)
- **Polished Black Obsidian**: `#0D0E12` (Mirror Black Glass)
- **Stained Glass Sapphire**: `#1D4ED8` (Transmissive Azure)
- **Stained Glass Ruby**: `#B91C1C` (Transmissive Blood Red)
- **Ancient Floor Moss**: `#2D472C` (Subdued Olive Dampness)

#### D. Combat VFX Elemental Palettes
- **Holy / Divine Smite**: `#FFF4CC` (Core) -> `#FFD700` (Mid) -> `#FF9900` (Outer Glow)
- **Storm / Lightning Arc**: `#F0FEFF` (Core) -> `#00E5FF` (Mid) -> `#3D5AFE` (Outer Glow)
- **Pyre / Hellfire Flame**: `#FFFFD0` (Core) -> `#FF5722` (Mid) -> `#990000` (Smoke/Edge)
- **Void / Abyssal Rift**: `#FFFFFF` (Core) -> `#E040FB` (Mid) -> `#311B92` (Vortex Edge)

---

## 6. PHYSICAL MATERIAL SPECIFICATIONS (PBR MATRIX)

Every material asset in `gkk_flutter` must adhere to these empirical ranges. Hand-crafted values outside these tolerances violate the AAA benchmark.

| Material Surface | Base Color (Albedo Hex) | Roughness ($R$) | Metallic ($M$) | Normal Intensity | Clearcoat | Notes / Shading Model |
|---|---|---|---|---|---|---|
| **Polished Imperial Gold** | `#F9D36B` | $0.18 - 0.26$ | $1.00$ | $1.0\times$ | $0.15$ | High specular glint, clearcoat micro-shine |
| **Etched Mithril Silver** | `#D8E2EC` | $0.22 - 0.34$ | $0.95$ | $1.2\times$ | $0.00$ | Filigree cavity roughness increased to 0.45 |
| **Abyssal Black Steel** | `#1C1E24` | $0.28 - 0.42$ | $0.90$ | $1.1\times$ | $0.05$ | Anisotropic brushed highlights along limb axis |
| **Polished Obsidian Monolith**| `#0C0D10` | $0.03 - 0.08$ | $0.85$ | $0.8\times$ | $0.80$ | Mirror-like sharpness, deep Fresnel reflectivity |
| **Wet Cobblestone (Puddle)** | `#18181A` | $0.02 - 0.05$ | $0.00$ | $0.3\times$ | $0.00$ | Flat water normal, specular reflection = $0.04$ |
| **Damp Cobblestone (Edge)** | `#2B2A2E` | $0.15 - 0.35$ | $0.00$ | $1.2\times$ | $0.00$ | Diffuse darkened by $30\%$, damp sheen |
| **Dry Gothic Ashlar Stone** | `#4A494E` | $0.72 - 0.88$ | $0.00$ | $1.4\times$ | $0.00$ | Micro-porous stone, high ambient occlusion |
| **Ethereal Wing Membrane** | `#E8F8FF` | $0.10 - 0.20$ | $0.00$ | $0.5\times$ | $0.50$ | Custom Translucency / Subsurface Backscatter |
| **Arming Doublet Cloth** | `#332E38` | $0.82 - 0.94$ | $0.00$ | $1.0\times$ | $0.00$ | Micro-fiber velvet sheen via inverted Fresnel |
| **Stained Cathedral Glass** | `#1E3A8A` | $0.05 - 0.12$ | $0.00$ | $0.4\times$ | $0.90$ | Transmissive additive emission ($HDR \times 3.5$) |
| **Molten Earth Fissure** | `#FF3700` | $0.40 - 0.60$ | $0.00$ | $1.5\times$ | $0.00$ | Emissive HDR multiplier $= 6.5$, animated pulse |
| **Dragon Bone Spire** | `#DDD4C2` | $0.45 - 0.65$ | $0.05$ | $1.3\times$ | $0.10$ | Subsurface organic scattering with ivory tint |

---

## 7. MATHEMATICAL SHADER SPECIFICATIONS (PRODUCTION GLSL)

The following production-ready GLSL shaders define the exact mathematical and visual behavior for the custom Flutter Impeller / WebGL graphics pipeline.

### 7.1 Ethereal Wing Translucency Shader (`aion2_wing_ethereal.frag`)
Features dual-sided translucent backscattering, Fresnel rim light, and animated procedural Aether veins.

```glsl
#version 460 core

precision highp float;

// Uniforms
uniform vec3 u_cameraPosition;
uniform vec3 u_lightDirection;       // Normalized toward light
uniform vec3 u_lightColor;           // Key light radiance
uniform vec3 u_ambientColor;         // Ambient fill
uniform vec3 u_wingCoreColor;        // e.g., Daeva Ivory vec3(0.96, 0.97, 0.98)
uniform vec3 u_wingEdgeColor;        // e.g., Radiant Cyan vec3(0.48, 0.91, 1.00)
uniform float u_time;
uniform float u_featherDensity;
uniform sampler2D u_noiseTexture;

// Inputs from Vertex Shader
in vec3 v_worldPosition;
in vec3 v_worldNormal;
in vec2 v_texCoord;

// Output
out vec4 fragColor;

void main() {
    vec3 N = normalize(v_worldNormal);
    vec3 V = normalize(u_cameraPosition - v_worldPosition);
    vec3 L = normalize(u_lightDirection);
    
    // 1. Two-Sided Subsurface Scattering Approximation (Backscattering)
    // Invert normal for back-light penetration through translucent feather membrane
    float sssDot = max(dot(-N, L), 0.0);
    float sssDistortion = 0.45;
    vec3 sssLightDir = normalize(L + N * sssDistortion);
    float sssIntensity = pow(clamp(dot(V, -sssLightDir), 0.0, 1.0), 3.0) * 1.8;
    vec3 sssColor = u_wingEdgeColor * sssIntensity;

    // 2. High-Exponent Celestial Fresnel Rim
    float NdotV = clamp(dot(N, V), 0.0, 1.0);
    float fresnel = pow(1.0 - NdotV, 3.8);
    vec3 rimGlow = mix(u_wingCoreColor, u_wingEdgeColor, fresnel) * fresnel * 3.5;

    // 3. Flowing Aether Caustic Noise
    vec2 scrollingUV1 = v_texCoord * 4.0 + vec2(u_time * 0.08, u_time * 0.15);
    vec2 scrollingUV2 = v_texCoord * 7.0 - vec2(u_time * 0.12, u_time * 0.05);
    float noise1 = texture(u_noiseTexture, scrollingUV1).r;
    float noise2 = texture(u_noiseTexture, scrollingUV2).r;
    float aetherVeins = smoothstep(0.45, 0.85, noise1 * noise2 * 2.2);
    vec3 veinEmission = u_wingEdgeColor * aetherVeins * 4.2;

    // 4. Direct Diffuse and Feather Structure
    float NdotL = max(dot(N, L), 0.0);
    vec3 diffuse = u_wingCoreColor * (NdotL * u_lightColor + u_ambientColor);

    // 5. Feather Transparency Falloff
    float alphaFade = smoothstep(0.0, 0.25, v_texCoord.y); // Fades toward root
    float finalAlpha = clamp(fresnel * 0.85 + alphaFade * 0.75 + aetherVeins * 0.4, 0.15, 0.98);

    // Final Composite
    vec3 finalRgb = diffuse + sssColor + rimGlow + veinEmission;
    fragColor = vec4(finalRgb, finalAlpha);
}
```

### 7.2 Filigree Anisotropic Ornate Armor Shader (`aion2_armor_filigree.frag`)
Evaluates full Cook-Torrance microfacet BRDF with directional brushed metal anisotropy and micro-etched gold filigree.

```glsl
#version 460 core

precision highp float;

uniform vec3 u_cameraPosition;
uniform vec3 u_lightDirection;
uniform vec3 u_lightColor;
uniform vec3 u_ambientColor;
uniform sampler2D u_albedoMap;
uniform sampler2D u_normalMap;
uniform sampler2D u_ormMap;           // R = Ambient Occlusion, G = Roughness, B = Metallic
uniform sampler2D u_filigreeMask;     // R = Filigree Height/Mask

in vec3 v_worldPosition;
in vec3 v_worldNormal;
in vec3 v_worldTangent;
in vec3 v_worldBitangent;
in vec2 v_texCoord;

out vec4 fragColor;

const float PI = 3.14159265359;

// GGX Distribution with Anisotropy
float D_GGX_Anisotropic(float at, float ab, float ToH, float BoH, float NoH) {
    float a2 = at * ab;
    vec3 d = vec3(ab * ToH, at * BoH, a2 * NoH);
    float d2 = dot(d, d);
    float b2 = a2 / d2;
    return a2 * b2 * b2 * (1.0 / PI);
}

// Schlick-GGX Geometry
float GeometrySchlickGGX(float NoV, float k) {
    return NoV / (NoV * (1.0 - k) + k);
}

float GeometrySmith(float NoV, float NoL, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return GeometrySchlickGGX(NoV, k) * GeometrySchlickGGX(NoL, k);
}

// Fresnel-Schlick
vec3 FresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

void main() {
    // Tangent Space to World Normal
    mat3 TBN = mat3(normalize(v_worldTangent), normalize(v_worldBitangent), normalize(v_worldNormal));
    vec3 normalSample = texture(u_normalMap, v_texCoord).rgb * 2.0 - 1.0;
    vec3 N = normalize(TBN * normalSample);
    vec3 T = normalize(v_worldTangent);
    vec3 B = normalize(v_worldBitangent);

    vec3 V = normalize(u_cameraPosition - v_worldPosition);
    vec3 L = normalize(u_lightDirection);
    vec3 H = normalize(V + L);

    // Sample PBR Maps
    vec4 albedoSample = texture(u_albedoMap, v_texCoord);
    vec3 orm = texture(u_ormMap, v_texCoord).rgb;
    float ao = orm.r;
    float roughness = clamp(orm.g, 0.04, 1.0);
    float metallic = orm.b;

    // Filigree Mask Integration (Elevates Gold Trim)
    float filigree = texture(u_filigreeMask, v_texCoord).r;
    vec3 goldBaseColor = vec3(0.95, 0.72, 0.26); // Imperial Gold Filigree
    vec3 baseColor = mix(albedoSample.rgb, goldBaseColor, filigree);
    roughness = mix(roughness, 0.22, filigree);
    metallic = mix(metallic, 1.0, filigree);

    // Dielectric / Conductor Fresnel Base F0
    vec3 F0 = vec3(0.04);
    F0 = mix(F0, baseColor, metallic);

    // Vector Dot Products
    float NoV = max(dot(N, V), 0.001);
    float NoL = max(dot(N, L), 0.001);
    float NoH = max(dot(N, H), 0.0);
    float VoH = max(dot(V, H), 0.0);
    float ToH = dot(T, H);
    float BoH = dot(B, H);

    // Anisotropic Parameters (brushed armor direction)
    float anisotropy = 0.55 * (1.0 - filigree); // Filigree is isotropic, plate is anisotropic
    float at = max(roughness * (1.0 + anisotropy), 0.001);
    float ab = max(roughness * (1.0 - anisotropy), 0.001);

    // Specular Microfacet Evaluation
    float D = D_GGX_Anisotropic(at, ab, ToH, BoH, NoH);
    float G = GeometrySmith(NoV, NoL, roughness);
    vec3 F = FresnelSchlick(VoH, F0);

    vec3 numerator = D * G * F;
    float denominator = 4.0 * NoV * NoL + 0.0001;
    vec3 specular = numerator / denominator;

    // Diffuse Energy Conservation
    vec3 kS = F;
    vec3 kD = (vec3(1.0) - kS) * (1.0 - metallic);
    vec3 diffuse = kD * baseColor / PI;

    // Final Lighting Accumulation
    vec3 radiance = u_lightColor * NoL;
    vec3 directLight = (diffuse + specular) * radiance;
    vec3 ambient = u_ambientColor * baseColor * ao;

    // Subtle edge clearcoat glint
    float clearcoatFresnel = pow(1.0 - NoV, 4.0) * 0.45;
    vec3 finalColor = directLight + ambient + vec3(clearcoatFresnel);

    fragColor = vec4(finalColor, albedoSample.a);
}
```

### 7.3 Wet Cobblestone Puddle & Rain Ripple Shader (`aion2_wet_cobblestone.frag`)
Computes realistic water height thresholding, diffuse stone darkening, dual animated normal ripple distortion, and screen-space planar mirror reflection.

```glsl
#version 460 core

precision highp float;

uniform vec3 u_cameraPosition;
uniform vec3 u_lightDirection;
uniform vec3 u_lightColor;
uniform vec3 u_ambientColor;
uniform float u_time;
uniform float u_puddleThreshold;    // e.g. 0.42 (puddles form where height < threshold)
uniform float u_rainIntensity;      // 0.0 = dry, 1.0 = torrential rain

uniform sampler2D u_stoneAlbedo;
uniform sampler2D u_stoneNormal;
uniform sampler2D u_stoneHeight;
uniform sampler2D u_rippleNormal;
uniform sampler2D u_ssrTexture;      // Screen-space reflection texture

in vec3 v_worldPosition;
in vec3 v_worldNormal;
in vec3 v_worldTangent;
in vec3 v_worldBitangent;
in vec2 v_texCoord;
in vec4 v_screenPos;

out vec4 fragColor;

void main() {
    mat3 TBN = mat3(normalize(v_worldTangent), normalize(v_worldBitangent), normalize(v_worldNormal));
    
    // Sample Stone Base Maps
    float height = texture(u_stoneHeight, v_texCoord).r;
    vec3 stoneAlbedo = texture(u_stoneAlbedo, v_texCoord).rgb;
    vec3 stoneNormal = normalize(TBN * (texture(u_stoneNormal, v_texCoord).rgb * 2.0 - 1.0));

    // Dynamic Rain Ripple Normal Synthesis
    vec2 rippleUV1 = v_texCoord * 12.0 + vec2(u_time * 0.35, u_time * 0.28);
    vec2 rippleUV2 = v_texCoord * 16.0 - vec2(u_time * 0.42, u_time * 0.31);
    vec3 ripple1 = texture(u_rippleNormal, rippleUV1).rgb * 2.0 - 1.0;
    vec3 ripple2 = texture(u_rippleNormal, rippleUV2).rgb * 2.0 - 1.0;
    vec3 combinedRippleNormal = normalize(TBN * (ripple1 + ripple2) * 0.5);

    // Compute Puddle Mask & Damp Edge Transition
    // Transition range of 0.08 produces damp porous borders around puddles
    float puddleMask = 1.0 - smoothstep(u_puddleThreshold - 0.05, u_puddleThreshold + 0.03, height);
    float dampMask = 1.0 - smoothstep(u_puddleThreshold, u_puddleThreshold + 0.12, height);

    // Porous Stone Darkening when saturated with water
    vec3 wetStoneAlbedo = stoneAlbedo * mix(1.0, 0.62, dampMask);

    // Puddle Surface Properties: Perfectly flat normal displaced only by rain ripples
    vec3 waterNormal = normalize(mix(vec3(0.0, 1.0, 0.0), combinedRippleNormal, 0.15 * u_rainIntensity));
    vec3 finalNormal = normalize(mix(stoneNormal, waterNormal, puddleMask));
    float finalRoughness = mix(mix(0.82, 0.25, dampMask), 0.02, puddleMask);

    // Screen Space Reflection Sample
    vec2 screenUv = (v_screenPos.xy / v_screenPos.w) * 0.5 + 0.5;
    vec2 ssrOffset = finalNormal.xz * (0.04 * puddleMask);
    vec3 ssrColor = texture(u_ssrTexture, screenUv + ssrOffset).rgb;

    // Lighting Vectors
    vec3 V = normalize(u_cameraPosition - v_worldPosition);
    vec3 L = normalize(u_lightDirection);
    vec3 H = normalize(V + L);

    float NoL = max(dot(finalNormal, L), 0.0);
    float NoV = max(dot(finalNormal, V), 0.0);
    float NoH = max(dot(finalNormal, H), 0.0);

    // Water Specular Highlight & Fresnel
    float fresnelWater = 0.02 + 0.98 * pow(1.0 - NoV, 5.0);
    float specPower = mix(12.0, 512.0, puddleMask);
    float specHighlight = pow(NoH, specPower) * mix(0.1, 4.5, puddleMask);

    // Composite Stone Diffuse + SSR + Puddle Specular
    vec3 diffuse = wetStoneAlbedo * (NoL * u_lightColor + u_ambientColor);
    vec3 puddleReflection = mix(diffuse, ssrColor, fresnelWater * puddleMask);
    vec3 finalColor = puddleReflection + specHighlight * u_lightColor;

    fragColor = vec4(finalColor, 1.0);
}
```

### 7.4 Multi-Layered Runic Magic Invocation Ring Shader (`aion2_magic_ring.frag`)
Generates 4 concentric rotating runic circles with additive bloom and edge shockwave distortion.

```glsl
#version 460 core

precision highp float;

uniform float u_time;
uniform vec3 u_coreColor;     // White core: vec3(1.0, 1.0, 1.0)
uniform vec3 u_magicColor;    // High-Aion Arcane Cyan: vec3(0.0, 0.9, 1.0)
uniform sampler2D u_runeTexture;
uniform sampler2D u_starGeometryTexture;

in vec2 v_texCoord;
out vec4 fragColor;

const float PI = 3.14159265359;

void main() {
    // Transform UV to Centered Polar Coordinates [-1.0 to 1.0]
    vec2 uv = v_texCoord * 2.0 - 1.0;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x); // [-PI to PI]
    float normAngle = (angle + PI) / (2.0 * PI); // [0.0 to 1.0]

    // Discard fragments outside outer ring boundary
    if (dist > 1.05) {
        discard;
    }

    // Tier 1: Inner Glowing Core (Radius 0.0 to 0.28)
    float corePulse = sin(u_time * 3.0) * 0.15 + 0.85;
    float innerGlow = smoothstep(0.28, 0.0, dist) * corePulse;
    vec3 colorCore = u_coreColor * innerGlow * 3.5;

    // Tier 2: Rotating Geometry Star (Radius 0.25 to 0.65)
    float starRotSpeed = u_time * 0.4;
    vec2 starUV = uv;
    float s = sin(starRotSpeed);
    float c = cos(starRotSpeed);
    starUV = mat2(c, -s, s, c) * starUV;
    float starPattern = texture(u_starGeometryTexture, starUV * 0.75 + 0.5).r;
    float starMask = smoothstep(0.25, 0.32, dist) * (1.0 - smoothstep(0.60, 0.68, dist));
    vec3 colorStar = u_magicColor * starPattern * starMask * 2.8;

    // Tier 3: Counter-Rotating Outer Runic Inscription (Radius 0.68 to 0.92)
    float runeRot = normAngle - u_time * 0.08;
    vec2 runeUV = vec2(fract(runeRot * 6.0), (dist - 0.68) / (0.92 - 0.68));
    float runeAlpha = texture(u_runeTexture, runeUV).r;
    float runeRingMask = smoothstep(0.68, 0.70, dist) * (1.0 - smoothstep(0.90, 0.92, dist));
    vec3 colorRunes = mix(u_magicColor, u_coreColor, 0.4) * runeAlpha * runeRingMask * 4.0;

    // Tier 4: Perimeter Energy Ring & Pulse (Radius 0.94 to 1.00)
    float rimRing = smoothstep(0.94, 0.96, dist) * (1.0 - smoothstep(0.98, 1.00, dist));
    float rimPulse = sin(u_time * 6.0 + angle * 8.0) * 0.3 + 0.7;
    vec3 colorRim = u_magicColor * rimRing * rimPulse * 5.0;

    // Composite Additive Glow
    vec3 finalRgb = colorCore + colorStar + colorRunes + colorRim;
    float finalAlpha = clamp(innerGlow + (starPattern * starMask) + (runeAlpha * runeRingMask) + rimRing, 0.0, 1.0);

    fragColor = vec4(finalRgb, finalAlpha);
}
```

### 7.5 Volumetric Crepuscular Ray & Mie Scattering Shader (`aion2_volumetric_fog.frag`)
Post-processing ray-marching pass integrating sun occlusion depth, exponential height density, and forward Henyey-Greenstein Mie scattering.

```glsl
#version 460 core

precision highp float;

uniform vec3 u_cameraPosition;
uniform vec3 u_sunDirection;        // Vector pointing toward the sun
uniform vec3 u_sunColor;            // Radiance of the sun (e.g. 5200K vec3(1.0, 0.92, 0.82))
uniform mat4 u_inverseViewProj;
uniform sampler2D u_depthTexture;
uniform sampler2D u_sceneColorTexture;
uniform float u_fogDensity;         // Typical: 0.012
uniform float u_fogHeightFalloff;   // Typical: 0.08

in vec2 v_texCoord;
out vec4 fragColor;

const int NUM_STEPS = 48;           // Step count for Ultra tier (scaled down on lower tiers)
const float PI = 3.14159265359;
const float G_MIE = 0.68;            // Strong forward scattering factor

// Henyey-Greenstein Phase Function
float ComputeMiePhase(float cosAngle) {
    float g2 = G_MIE * G_MIE;
    return (1.0 / (4.0 * PI)) * ((1.0 - g2) / pow(1.0 + g2 - 2.0 * G_MIE * cosAngle, 1.5));
}

// Reconstruct World Position from Depth
vec3 WorldPosFromDepth(vec2 uv, float depth) {
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 worldSpace = u_inverseViewProj * clipSpace;
    return worldSpace.xyz / worldSpace.w;
}

void main() {
    float depth = texture(u_depthTexture, v_texCoord).r;
    vec3 targetWorldPos = WorldPosFromDepth(v_texCoord, depth);
    vec3 sceneColor = texture(u_sceneColorTexture, v_texCoord).rgb;

    vec3 rayStart = u_cameraPosition;
    vec3 rayDir = targetWorldPos - rayStart;
    float rayLength = length(rayDir);
    rayDir = normalize(rayDir);

    // Limit maximum ray march distance to avoid infinite depth artifacts
    rayLength = min(rayLength, 150.0);
    float stepSize = rayLength / float(NUM_STEPS);
    vec3 stepVector = rayDir * stepSize;

    float cosTheta = dot(rayDir, u_sunDirection);
    float phase = ComputeMiePhase(cosTheta);

    // Raymarching Integration
    vec3 currentPos = rayStart + stepVector * 0.5;
    vec3 accumulatedLight = vec3(0.0);
    float opticalDepth = 0.0;

    for (int i = 0; i < NUM_STEPS; ++i) {
        // Height-based exponential fog density
        float heightDensity = exp(-currentPos.y * u_fogHeightFalloff);
        float stepDensity = u_fogDensity * heightDensity * stepSize;
        opticalDepth += stepDensity;

        // In-scattering accumulation
        float transmittance = exp(-opticalDepth);
        accumulatedLight += u_sunColor * phase * stepDensity * transmittance;

        currentPos += stepVector;
    }

    // Composite Volumetrics over Scene Color
    float finalTransmittance = exp(-opticalDepth);
    vec3 finalComposite = sceneColor * finalTransmittance + accumulatedLight * 2.4;

    fragColor = vec4(finalComposite, 1.0);
}
```

---

## 8. PERFORMANCE SCALING & QUALITY TIER ARCHITECTURE

To strictly satisfy the User Mandate (*"Unity motoru kullanılacaksa eğer mantıklıysa değerlendirme yapsın ajanlar... ama düşük sistemli oyuncuları unutmayacağız"*), graphics features are partitioned into 4 distinct Adaptive Quality Tiers.

```
                  ┌───────────────────────────────────────────────┐
                  │          ADAPTIVE GRAPHICS SCALER             │
                  └───────────────────────┬───────────────────────┘
                                          │
          ┌───────────────────┬───────────┴───────────┬───────────────────┐
          ▼                   ▼                       ▼                   ▼
    [ LOW / ECO ]       [ MEDIUM ]              [ HIGH ]            [ ULTRA AAA ]
   - 60 FPS Floor     - 60 FPS Target        - 60 FPS Fidelity   - Aion 2 Native
   - No Volumetrics   - Screen Rays (Radial) - 24-Step God Rays  - 48-Step God Rays
   - Half-Res VFX     - Full-Res VFX         - Clustered Lights  - Full PBR SSR
   - VAT Impostors    - GPU Instancing LOD2  - LOD0 Near Clust.  - 10k VAT Batch
```

### 8.1 Adaptive Quality Tier Matrix
| Feature Parameter | Low / Eco (Low-Spec 60 FPS) | Medium Tier | High Tier | Ultra (Aion 2 Cinematic) |
|---|---|---|---|---|
| **Target Hardware** | Helio P60, Adreno 506 (3GB RAM) | SD 778G, Mali-G77 (6GB RAM) | SD 8 Gen 1, A14 (8GB RAM) | SD 8 Gen 3, A17 Pro (12GB+ RAM) |
| **Volumetric God-Rays** | Disabled (Baked Lightmap Only) | 2D Radial Post-Process Sun Blur | 24-Step Raymarch ($50\%$ Res) | 48-Step Mie Scattering (Full Res) |
| **Wet Cobblestone SSR** | Analytic Specular Only | Half-Res Planar Reflection | Full-Res Planar Reflection | Full SSR + Rain Ripple Distortion |
| **Character Wings** | Single Alpha-Blend Plane | Dual-Plane + Simple Rim Glow | Full SSS + Fresnel Veins | Full SSS + Caustic Noise + Motes |
| **Armor Filigree** | Normal Map Only (Isotropic) | Normal + ORM Specular | Anisotropic Cook-Torrance | Anisotropic GGX + Clearcoat Glint |
| **Combat Magic Rings** | 2-Tier Sprite Animation | 3-Tier Dynamic Mesh Rotation | 4-Tier + Additive Bloom | 4-Tier + Refractive Screen Distortion |
| **Max 10K Crowd Pipeline**| 100% VAT Billboard Impostors | LOD2 GPU Instances (100 Near) | LOD1/2 Instancing (250 Near) | LOD0 Full Rig (50) + LOD1/2 (500) + VAT |
| **Shadow Resolution** | Disabled / Blob Shadow | 1024 Cascaded Shadow (2 splits)| 2048 Cascaded Shadow (3 splits)| 4096 Cascaded Shadow (4 splits) + PCSS |
| **Post-Processing** | Reinhard Fast Tonemapping | ACES Filmic + Fast FXAA | ACES Filmic + Bloom + SSAO | ACES Filmic + HDR Bloom + Bilateral SSAO |

### 8.2 Texture Memory & Draco Compression Budgets
To avoid Out-of-Memory (OOM) crashes on low-spec hardware while rendering high-density Aion 2 scenes:
- **Texture Packing**: Standardized ORM layout:
  - **Red Channel**: Ambient Occlusion (AO).
  - **Green Channel**: Roughness ($0.0 = \text{Smooth}, 1.0 = \text{Rough}$).
  - **Blue Channel**: Metallic ($0.0 = \text{Dielectric}, 1.0 = \text{Pure Metal}$).
  - **Alpha Channel (optional)**: Height displacement or Emissive mask.
- **Compression Formats**:
  - Desktop / High Mobile: **KTX2 with Basis Universal (Zstandard / UASTC)**.
  - Standard Mobile: **ASTC 6x6 (Character Hero)** and **ASTC 8x8 (World Tiling)**.
- **Polygon & Draco 3D Compression**:
  - All `.glb` assets must pass through Draco geometric compression (position quantization: 14 bits, normal: 10 bits, texcoord: 12 bits).
  - Target LOD0 Hero Polygon Budget: $\le 32,000$ triangles.
  - Target LOD1 Mid Polygon Budget: $\le 12,000$ triangles.
  - Target LOD2 Crowd Polygon Budget: $\le 2,800$ triangles.
  - Target Impostor Billboard Budget: $2$ quads ($4$ triangles) referencing Vertex Animated Textures (VAT).

---

## 9. CLOSED-LOOP VISUAL AUDIT & ACCEPTANCE CRITERIA

Before any asset, shader, or scene is cleared for production release:
1. **Material PBR Compliance**: Albedo must never drop below RGB $(15, 15, 15)$ or exceed $(245, 245, 245)$. No pure pitch blacks or blown-out whites in unlit diffuse.
2. **Temperature Separation**: Warm local lighting ($2200\text{K} - 2800\text{K}$) must distinctly contrast against cold ambient fill ($7500\text{K} - 9500\text{K}$). Monochromatic scenes are rejected.
3. **Wing Ethereal Quality**: Wings must demonstrate visible Fresnel rim illumination under grazing angles ($\theta > 65^\circ$) and animated Aether vein displacement.
4. **Wet Surface Integrity**: Transitions between dry stone and wet puddles must exhibit diffuse albedo darkening ($\ge 30\%$) and normal map flattening in submerged zones.
5. **Frame Budget Zero-Jank Guarantee**: Background shader pre-compilation and asynchronous warm-up must consume $\le 2.0\text{ms}$ per frame during scene loading to prevent GC stutters.

---
*Signed and Approved for Production Delivery,*  
**Aion 2 Art Director** (`aion2_1_art_director`)  
*gkk_flutter High-Fantasy Graphics Modernization Core Team*
