#version 460 core
#include <flutter/runtime_effect.glsl>

// =============================================================================
// Ground Decal Projection Blend Shader (GLSL 460 / Flutter RuntimeEffect)
// Supports OBB Decal Projection onto Ground Plane with:
// - Surface Normal Alignment & Angle Attenuation
// - Albedo Modulation & Tinting
// - Tangent-Space Normal Overlay Blending (RNM / Reoriented Normal Mapping)
// - Roughness Variation & Metallic Blending
// - Procedural R3 Decal Generation (Scorch, Blood, Cracked Earth, Slash Gouge)
// - Texture Sampling Fallback & Overlays
// - Smooth Edge Border Softness & Depth Fade
// - Inverse View-Projection & Screen-to-OBB Projection Mapping
// =============================================================================

precision highp float;

// -----------------------------------------------------------------------------
// Numeric Uniforms: Total 26 floats (Offsets 0 .. 25)
// Declared strictly before samplers for Flutter Impeller runtime effect standard.
// -----------------------------------------------------------------------------
uniform vec2 uResolution;        // [0..1]   Screen / ground target viewport resolution
uniform vec2 uDecalCenter;       // [2..3]   Projected decal center in pixel coordinates
uniform vec2 uDecalHalfSize;     // [4..5]   Half-extents of decal bounding box (halfWidth, halfHeight)
uniform float uDecalRotation;    // [6]      Decal rotation angle in radians (yaw)
uniform float uOpacity;          // [7]      Current opacity [0.0, 1.0] from fade timeline
uniform vec4 uAlbedoTint;        // [8..11]  Decal albedo tint / color modulation (RGBA)
uniform float uNormalStrength;   // [12]     Normal perturbation strength [0.0, 2.0]
uniform float uRoughnessMod;     // [13]     Decal target roughness [0.0, 1.0]
uniform float uDecalType;        // [14]     0.0=scorch, 1.0=blood, 2.0=crackedEarth, 3.0=slashGouge, 4.0=texture
uniform vec3 uSurfaceNormal;     // [15..17] Ground surface normal (world/tangent space)
uniform vec3 uProjectorNormal;   // [18..20] Decal projection direction pointing towards surface
uniform float uAngleCutoff;      // [21]     Minimum dot product for projection (e.g. cos(60 deg) = 0.5)
uniform float uEdgeSoftness;     // [22]     Decal boundary border softness fraction [0.01, 0.5]
uniform float uTime;             // [23]     Animation time in seconds (for embers, sheen, sparks)
uniform float uProceduralSeed;   // [24]     Unique random seed for noise variation
uniform float uDepthClip;        // [25]     Decal OBB depth attenuation factor [0.0, 1.0]

// -----------------------------------------------------------------------------
// Sampler Uniforms (Declared strictly after all numeric uniforms)
// -----------------------------------------------------------------------------
uniform sampler2D uGroundTexture; // Sampler 0: Base ground albedo (RGB) & roughness (A)
uniform sampler2D uDecalTexture;  // Sampler 1: Custom decal albedo & opacity (RGBA)
uniform sampler2D uNormalTexture; // Sampler 2: Tangent-space normal map (RGB)

out vec4 fragColor;

// -----------------------------------------------------------------------------
// Math & Safe Vector Operations
// -----------------------------------------------------------------------------
vec3 safeNormalize(vec3 v, vec3 fallback) {
    float lenSq = dot(v, v);
    return (lenSq > 1e-8) ? (v * inversesqrt(lenSq)) : fallback;
}

// -----------------------------------------------------------------------------
// Noise & Procedural Synthesis Utilities
// -----------------------------------------------------------------------------
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345) + vec2(uProceduralSeed * 17.13, uProceduralSeed * 31.41));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
    float n = sin(dot(p, vec2(127.1, 311.7)) + uProceduralSeed * 5.71);
    float m = sin(dot(p, vec2(269.5, 183.3)) + uProceduralSeed * 9.17);
    return fract(vec2(n, m) * 43758.5453);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    // Rotate to reduce axial bias
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 4; ++i) {
        v += a * valueNoise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// 2D Cellular / Voronoi Distance Function
vec3 voronoi(vec2 p) {
    vec2 n = floor(p);
    vec2 f = fract(p);

    vec2 mg, mr;
    float md = 8.0;
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash22(n + g);
            vec2 r = g + o - f;
            float d = dot(r, r);
            if (d < md) {
                md = d;
                mr = r;
                mg = g;
            }
        }
    }

    // Second pass for border distance (cracks)
    float md2 = 8.0;
    for (int j = -2; j <= 2; ++j) {
        for (int i = -2; i <= 2; ++i) {
            vec2 g = mg + vec2(float(i), float(j));
            vec2 o = hash22(n + g);
            vec2 r = g + o - f;
            if (dot(mr - r, mr - r) > 0.00001) {
                md2 = min(md2, dot(0.5 * (mr + r), normalize(r - mr)));
            }
        }
    }

    return vec3(sqrt(md), md2, hash21(n + mg));
}

// -----------------------------------------------------------------------------
// Normal Overlay Blending: Reoriented Normal Mapping (RNM)
// Blends base ground normal with decal perturbation normal
// Reference: Colin Barré-Brisebois & Stephen Hill (2012)
// -----------------------------------------------------------------------------
vec3 blendRNM(vec3 nBase, vec3 nDecal) {
    vec3 t = nBase + vec3(0.0, 0.0, 1.00001);
    vec3 u = vec3(-nDecal.x, -nDecal.y, nDecal.z);
    vec3 r = t * dot(t, u) - u * t.z;
    return safeNormalize(r, vec3(0.0, 0.0, 1.0));
}

// -----------------------------------------------------------------------------
// Projected Decal Mapping & Inverse View-Projection Matrix Lookups
// -----------------------------------------------------------------------------

// 2D Screen-to-OBB-Local Decal Inverse Projection:
// Maps screen/render target fragment coordinates into normalized canonical OBB space [-1, 1]^2
// Formula: P_local = S^-1 * R(-theta) * (P_frag - C_decal)
vec2 projectFragToDecalLocal(vec2 fragCoord, vec2 center, vec2 halfSize, float rotation) {
    vec2 offset = fragCoord - center;
    float cosR = cos(-rotation);
    float sinR = sin(-rotation);
    // 2D Inverse rotation matrix R(-theta):
    vec2 rotOffset = vec2(
        offset.x * cosR - offset.y * sinR,
        offset.x * sinR + offset.y * cosR
    );
    // Inverse scale matrix S^-1 (normalize by half-extents):
    return rotOffset / max(halfSize, vec2(1.0));
}

// 3D Inverse View-Projection Matrix Lookup (Deferred G-Buffer Decal Reconstruction):
// Reconstructs world-space position from screen UV and normalized depth [0, 1]
// using the inverse view-projection matrix: P_world = (invViewProj * P_ndc).xyz / w
vec3 reconstructWorldPosition(vec2 uv, float depth, mat4 invViewProj) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 worldPos = invViewProj * ndc;
    return worldPos.xyz / max(worldPos.w, 0.000001);
}

// -----------------------------------------------------------------------------
// Procedural Decal Generators
// -----------------------------------------------------------------------------

// 1. Scorch Mark: Charred burnt soot core with glowing ember perimeter
void evaluateScorchMark(vec2 localCoord, out vec4 albedo, out vec3 normal, out float roughness) {
    float r = length(localCoord);
    float angle = atan(localCoord.y, abs(localCoord.x) > 1e-6 ? localCoord.x : 1e-6);
    float noiseEdge = fbm(localCoord * 4.0 + vec2(cos(angle), sin(angle)));

    // Irregular burnt perimeter
    float burnRadius = 0.85 + 0.18 * (noiseEdge - 0.5);
    float burnMask = 1.0 - smoothstep(burnRadius - 0.25, burnRadius, r);

    // Deep charred center core
    float sootDensity = smoothstep(burnRadius, 0.1, r) * (0.8 + 0.2 * noiseEdge);
    vec3 sootColor = vec3(0.03, 0.025, 0.025);

    // Fiery glowing embers on the burn boundary
    float emberRing = smoothstep(burnRadius - 0.22, burnRadius - 0.05, r) *
                      (1.0 - smoothstep(burnRadius - 0.05, burnRadius + 0.02, r));
    float pulse = 0.5 + 0.5 * sin(uTime * 3.8 + noiseEdge * 6.28);
    vec3 emberColor = vec3(1.0, 0.38, 0.06) * (1.5 + 1.2 * pulse);

    vec3 compositeRgb = mix(sootColor, emberColor, emberRing * 0.75);
    float alpha = burnMask * uAlbedoTint.a;

    // Normal perturbation: rough cratered char indent
    float bump = (noiseEdge - 0.5) * burnMask * 0.4;
    normal = safeNormalize(vec3(localCoord.x * bump, localCoord.y * bump, 1.0), vec3(0.0, 0.0, 1.0));
    roughness = mix(0.92, 0.4, emberRing); // Dry soot is rough, ember glow has lower roughness
    albedo = vec4(compositeRgb * uAlbedoTint.rgb, alpha);
}

// 2. Blood Splatter: Organic arterial splatter with micro droplets & wet sheen
void evaluateBloodSplatter(vec2 localCoord, out vec4 albedo, out vec3 normal, out float roughness) {
    float r = length(localCoord);
    vec3 cell = voronoi(localCoord * 5.5);
    float noise = fbm(localCoord * 6.0);

    // Main splatter mass with tendril arms
    float arms = sin(atan(localCoord.y, abs(localCoord.x) > 1e-6 ? localCoord.x : 1e-6) * 7.0 + noise * 4.0) * 0.18;
    float mainRadius = 0.55 + arms;
    float mainSplatter = 1.0 - smoothstep(mainRadius - 0.12, mainRadius, r);

    // Satellite micro-droplets outside the core
    float droplets = step(cell.x, 0.22) * smoothstep(0.4, 0.9, r) * step(r, 0.95);
    float combinedMask = clamp(mainSplatter + droplets, 0.0, 1.0);

    // Deep crimson arterial red with thick coagulated darker spots
    vec3 freshBlood = vec3(0.48, 0.015, 0.02);
    vec3 thickBlood = vec3(0.18, 0.005, 0.008);
    vec3 bloodColor = mix(freshBlood, thickBlood, smoothstep(0.0, 0.45, r));

    // Meniscus surface tension normal perturbation at droplet border
    float edgeRidge = smoothstep(0.0, 0.08, abs(r - mainRadius));
    vec2 nOffset = localCoord * (1.0 - edgeRidge) * 0.6;
    normal = safeNormalize(vec3(-nOffset.x, -nOffset.y, 1.0), vec3(0.0, 0.0, 1.0));

    // High wetness = very low roughness
    roughness = 0.08;
    albedo = vec4(bloodColor * uAlbedoTint.rgb, combinedMask * uAlbedoTint.a);
}

// 3. Cracked Earth / Stone: Fissure network with deep cavity shading & dusty roughness
void evaluateCrackedEarth(vec2 localCoord, out vec4 albedo, out vec3 normal, out float roughness) {
    float r = length(localCoord);
    float radialFalloff = 1.0 - smoothstep(0.65, 0.95, r);

    // Voronoi cell borders produce rock fracture crevices
    vec3 v = voronoi(localCoord * 4.5);
    float crackDist = v.y; // distance to cell edge
    float crackWidth = 0.06;
    float crackMask = (1.0 - smoothstep(0.0, crackWidth, crackDist)) * radialFalloff;

    // Rock facet shading
    float facetShade = 0.7 + 0.3 * v.z;
    vec3 rockCavity = vec3(0.08, 0.07, 0.06);
    vec3 rockDust = vec3(0.35, 0.30, 0.25) * facetShade;
    vec3 earthColor = mix(rockDust, rockCavity, crackMask * 0.85);

    // Normal perturbation: sharp cliff-like indent into fissures
    vec2 crackNormalDir = safeNormalize(vec3(localCoord, 0.0), vec3(0.001, 0.001, 0.0)).xy;
    normal = safeNormalize(vec3(crackNormalDir * (crackMask * 0.8), 1.0), vec3(0.0, 0.0, 1.0));

    // Dusty matte roughness
    roughness = 0.88;
    albedo = vec4(earthColor * uAlbedoTint.rgb, crackMask * uAlbedoTint.a);
}

// 4. Slash Impact Gouge: Linear directional chasm with metal strike spark embers
void evaluateSlashGouge(vec2 localCoord, out vec4 albedo, out vec3 normal, out float roughness) {
    // Oriented primarily along Y axis in local space
    float halfLength = 0.85;
    float halfWidth = 0.18;

    float normY = localCoord.y / halfLength;
    float normX = localCoord.x / halfWidth;

    // Tapered slash profile (wider at impact entry, narrow taper at exit)
    float taper = mix(1.2, 0.35, (normY + 1.0) * 0.5);
    float distX = abs(localCoord.x) / max(halfWidth * taper, 1e-5);
    float distY = abs(localCoord.y);

    float noiseGouge = fbm(localCoord * 8.0);
    float gougeMask = (1.0 - smoothstep(0.8, 1.0, distX)) *
                      (1.0 - smoothstep(halfLength - 0.15, halfLength, distY));

    // Raised debris lip on flanks
    float lipMask = smoothstep(0.65, 0.95, distX) * (1.0 - smoothstep(0.95, 1.25, distX)) *
                    (1.0 - smoothstep(halfLength - 0.1, halfLength, distY));

    // Dark gouged trench core
    vec3 trenchColor = vec3(0.06, 0.05, 0.05);

    // Friction heat glow at deepest strike point
    float strikeHeat = (1.0 - smoothstep(0.0, 0.35, length(localCoord))) *
                       (0.6 + 0.4 * sin(uTime * 5.0 + noiseGouge * 4.0));
    vec3 heatColor = vec3(1.2, 0.5, 0.1);
    vec3 slashColor = mix(trenchColor, heatColor, strikeHeat * 0.6);

    // Anisotropic V-shaped gouge normal
    float nx = sign(localCoord.x) * gougeMask * 0.7 - sign(localCoord.x) * lipMask * 0.4;
    normal = safeNormalize(vec3(nx, (noiseGouge - 0.5) * 0.3, 1.0), vec3(0.0, 0.0, 1.0));

    roughness = mix(0.75, 0.25, strikeHeat);
    albedo = vec4(slashColor * uAlbedoTint.rgb, clamp(gougeMask + lipMask * 0.6, 0.0, 1.0) * uAlbedoTint.a);
}

// -----------------------------------------------------------------------------
// Main Shader Routine
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 groundUv = fragCoord / uResolution;

    // Sample underlying ground surface (albedo in RGB, roughness in A)
    vec4 groundSample = texture(uGroundTexture, groundUv);
    vec3 groundAlbedo = groundSample.rgb;
    float groundRoughness = (groundSample.a > 0.001) ? groundSample.a : 0.72;

    // 1. Transform fragment coordinates into decal local projection space [-1, 1]
    // Uses 2D Screen-to-OBB-Local inverse projection
    vec2 localCoord = projectFragToDecalLocal(fragCoord, uDecalCenter, uDecalHalfSize, uDecalRotation);

    // 2. OBB Box Extent Clipping with Border Softness
    vec2 boxDist = abs(localCoord);
    float maxDist = max(boxDist.x, boxDist.y);
    float edgeSoftness = clamp(uEdgeSoftness, 0.01, 0.5);
    float boxFalloff = 1.0 - smoothstep(1.0 - edgeSoftness, 1.0, maxDist);

    if (boxFalloff <= 0.001) {
        fragColor = vec4(groundAlbedo, groundRoughness);
        return;
    }

    // 3. Surface Normal Alignment Check
    // Decal projector points towards ground (-uProjectorNormal).
    // Alignment is dot product between ground surface normal and projector axis.
    vec3 nSurf = safeNormalize(uSurfaceNormal, vec3(0.0, 0.0, 1.0));
    vec3 nProj = safeNormalize(uProjectorNormal, vec3(0.0, 0.0, -1.0));
    float normalDot = dot(nSurf, -nProj);

    float angleCutoff = clamp(uAngleCutoff, 0.05, 0.95);
    float alignmentFactor = smoothstep(angleCutoff - 0.08, angleCutoff + 0.08, normalDot);

    if (alignmentFactor <= 0.001) {
        fragColor = vec4(groundAlbedo, groundRoughness);
        return;
    }

    // 4. Decal Evaluation: Procedural or Texture
    vec4 decalAlbedo = vec4(0.0);
    vec3 decalTangentNormal = vec3(0.0, 0.0, 1.0);
    float decalRoughness = clamp(uRoughnessMod, 0.0, 1.0);

    if (uDecalType < 0.5) {
        // 0.0 = Scorch Mark
        evaluateScorchMark(localCoord, decalAlbedo, decalTangentNormal, decalRoughness);
    } else if (uDecalType < 1.5) {
        // 1.0 = Blood Splatter
        evaluateBloodSplatter(localCoord, decalAlbedo, decalTangentNormal, decalRoughness);
    } else if (uDecalType < 2.5) {
        // 2.0 = Cracked Earth
        evaluateCrackedEarth(localCoord, decalAlbedo, decalTangentNormal, decalRoughness);
    } else if (uDecalType < 3.5) {
        // 3.0 = Slash Impact Gouge
        evaluateSlashGouge(localCoord, decalAlbedo, decalTangentNormal, decalRoughness);
    } else {
        // 4.0 = Texture / Custom Decal
        vec2 decalUv = clamp(localCoord * 0.5 + 0.5, 0.0, 1.0);
        vec4 texColor = texture(uDecalTexture, decalUv);
        decalAlbedo = texColor * uAlbedoTint;

        vec4 texNorm = texture(uNormalTexture, decalUv);
        decalTangentNormal = safeNormalize(texNorm.xyz * 2.0 - 1.0, vec3(0.0, 0.0, 1.0));
        decalRoughness = uRoughnessMod;
    }

    // 5. Normal Perturbation & Reoriented Normal Mapping (RNM) Blending
    decalTangentNormal = safeNormalize(
        mix(vec3(0.0, 0.0, 1.0), decalTangentNormal, uNormalStrength),
        vec3(0.0, 0.0, 1.0)
    );
    vec3 blendedNormal = blendRNM(nSurf, decalTangentNormal);

    // Dynamic micro-relief shading from perturbed normal against projector axis
    float reliefLighting = clamp(dot(blendedNormal, -nProj) * 0.5 + 0.5, 0.45, 1.0);
    vec3 shadedDecalColor = decalAlbedo.rgb * reliefLighting;

    // 6. Composite Effective Alpha with Depth Attenuation
    float depthFactor = clamp(uDepthClip, 0.0, 1.0);
    float effectiveAlpha = decalAlbedo.a * uOpacity * alignmentFactor * boxFalloff * depthFactor;
    effectiveAlpha = clamp(effectiveAlpha, 0.0, 1.0);

    if (effectiveAlpha <= 0.001) {
        fragColor = vec4(groundAlbedo, groundRoughness);
        return;
    }

    // 7. Blend Albedo and Roughness onto Ground Target
    vec3 blendedAlbedo = mix(groundAlbedo, shadedDecalColor, effectiveAlpha);
    float blendedRoughness = mix(groundRoughness, decalRoughness, effectiveAlpha);

    fragColor = vec4(blendedAlbedo, blendedRoughness);
}
