#version 460 core
#include <flutter/runtime_effect.glsl>

// =============================================================================
// Master Aion 2 PBR Material Fragment Shader
// High-Fantasy AAA Cinematic Standard (Aion 2 Visual Standard)
//
// Capabilities:
// 1. Physically-Based Cook-Torrance Specular BRDF (GGX / Smith / Fresnel-Schlick)
// 2. Subsurface Scattering (SSS) Approximation (Translucent glowing wings & skin)
// 3. Thin-Film Optical Iridescence (Dragon scales, enchanted armor, beetle sheen)
// 4. Temporal Emissive Rune Modulation (Harmonic arcane pulsing & breathing)
// 5. Clearcoat Secondary Specular Reflection Layer
// 6. Tangent-Space Normal Mapping with Orthonormal TBN Basis Perturbation
// 7. Microfacet Ambient Occlusion & Environmental Irradiance
// 8. ACES Filmic HDR Tonemapping & sRGB / Gamma 2.2 Output Pipeline
//
// Optimized for Flutter Impeller & Skia GPU Runtime Effect pipeline.
// =============================================================================

precision highp float;
precision highp sampler2D;

// -----------------------------------------------------------------------------
// Numeric Uniforms (Indices 0 .. 53, total 54 floats)
// STRICT: Must be declared before any sampler2D uniforms for Impeller compliance.
// -----------------------------------------------------------------------------

// Viewport & Simulation Coordinates (7 floats)
uniform vec2  uResolution;              // 0..1: Viewport resolution (pixels)
uniform float uTime;                     // 2:    Elapsed time in seconds
uniform vec3  uCameraPos;                // 3..5: Camera position in world/view space
uniform float uNormalIntensity;          // 6:    Normal map bump scaling [0.0 - 2.0]

// Primary Cinematic Light Source (7 floats)
uniform vec3  uLightPos;                 // 7..9:   Light position in world/view space
uniform vec3  uLightColor;               // 10..12: Light source color (Linear RGB)
uniform float uLightIntensity;           // 13:     Light radiant intensity multiplier

// Ambient & Environmental Occlusion (4 floats)
uniform vec3  uAmbientLight;             // 14..16: Ambient environmental radiance (Linear RGB)
uniform float uAOIntensity;              // 17:     Ambient occlusion strength multiplier

// Core PBR Material Properties (8 floats)
uniform vec4  uBaseColor;                // 18..21: Base albedo color (RGBA linear)
uniform float uMetallic;                 // 22:     Metallic factor [0.0 = dielectric, 1.0 = metal]
uniform float uRoughness;                // 23:     Perceptual microfacet roughness [0.04 - 1.0]
uniform float uClearcoat;                // 24:     Clearcoat secondary reflection weight [0.0 - 1.0]
uniform float uClearcoatRoughness;       // 25:     Clearcoat microfacet roughness [0.0 - 1.0]

// Subsurface Scattering (SSS) for Glowing Wings & Translucent Skin (8 floats)
uniform vec4  uSSSParams;                // 26..29: x=weight, y=distortion, z=power, w=scale
uniform vec3  uSSSColor;                 // 30..32: Subsurface internal scatter tint (Linear RGB)
uniform float uSSSExtinction;            // 33:     Absorption / depth extinction coefficient

// Thin-Film Iridescence for Dragon Scales & Enchanted Plate (8 floats)
uniform vec4  uIridescenceParams;        // 34..37: x=weight, y=filmThicknessNm [100-1000], z=filmIOR, w=baseIOR
uniform vec3  uIridescenceTint;          // 38..40: Iridescent fringe chromatic tint (Linear RGB)
uniform float uIridescenceAngleShift;    // 41:     Angular phase dispersion multiplier

// Emissive Rune Pulsating Modulation (8 floats)
uniform vec4  uEmissiveColor;            // 42..45: Emissive rune color (RGB) and peak intensity (A)
uniform vec4  uEmissiveRuneParams;       // 46..49: x=speed, y=frequency, z=dutyCycle, w=modType (0=sine, 1=heartbeat, 2=arcane, 3=overload)

// Texture Tiling & UV Offset (4 floats)
uniform vec2  uTiling;                   // 50..51: UV coordinate scale/tiling factor
uniform vec2  uOffset;                   // 52..53: UV coordinate translation offset

// -----------------------------------------------------------------------------
// Texture Samplers (Declared strictly after numeric uniforms for Impeller)
// Sequential binding slots 0 to 3 matching setImageSampler bindings
// -----------------------------------------------------------------------------
uniform sampler2D uAlbedoMap;             // Slot 0: Base albedo / diffuse map (RGBA linear)
uniform sampler2D uNormalMap;             // Slot 1: Tangent space normal map (RGB)
uniform sampler2D uMetallicRoughnessAOMap; // Slot 2: R = AO, G = Roughness, B = Metallic
uniform sampler2D uEmissiveRuneMap;       // Slot 3: R = Emissive, G = Rune Mask, B = SSS Mask, A = Iridescence Mask

out vec4 fragColor;

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------
const float PI = 3.14159265358979323846;
const float INV_PI = 0.31830988618379067154;
const float EPSILON = 1e-5;

// Dielectric base reflectance (4% reflectance for non-metals)
const vec3 DIELECTRIC_F0 = vec3(0.04);

// -----------------------------------------------------------------------------
// 1. Normal Distribution Function: GGX / Trowbridge-Reitz
// Evaluates microfacet alignment probability along half-vector H.
// -----------------------------------------------------------------------------
float distributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return a2 / max(denom, EPSILON);
}

// -----------------------------------------------------------------------------
// 2. Geometric Shadowing / Masking: Smith Schlick-GGX
// Accounts for mutual microfacet self-shadowing and masking.
// -----------------------------------------------------------------------------
float geometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float denom = NdotV * (1.0 - k) + k;
    return NdotV / max(denom, EPSILON);
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0001);
    float NdotL = max(dot(N, L), 0.0);
    float ggx1 = geometrySchlickGGX(NdotV, roughness);
    float ggx2 = geometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

// -----------------------------------------------------------------------------
// 3. Fresnel Reflectance: Schlick Approximation
// Computes ratio of reflected vs refracted light as incident angle varies.
// -----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (vec3(1.0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// -----------------------------------------------------------------------------
// 4. Thin-Film Optical Iridescence (Dragon Scales & Enchanted Armor)
// Computes constructive and destructive wave interference across spectral bands:
// Red (650nm), Green (532nm), Blue (440nm).
// -----------------------------------------------------------------------------
vec3 evaluateThinFilmIridescence(
    float cosTheta,
    float thicknessNm,
    float filmIOR,
    float baseIOR,
    float angleShift
) {
    // Snell's Law to calculate angle of refraction inside thin film
    float sinThetaI = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));
    float sinThetaT = sinThetaI / max(filmIOR, 1.001);
    float cosThetaT = sqrt(max(0.0, 1.0 - sinThetaT * sinThetaT));

    // Optical Path Difference: OPD = 2 * n1 * d * cos(theta_t)
    float opd = 2.0 * filmIOR * thicknessNm * cosThetaT * (1.0 + angleShift * (1.0 - cosTheta));

    // Standard visible spectrum representative wavelengths in nanometers
    vec3 wavelengths = vec3(650.0, 532.0, 440.0);

    // Phase shift: phi = (2 * PI * OPD / lambda)
    vec3 phase = (2.0 * PI * opd) / wavelengths;

    // Interface reflection phase flips (when going from lower to higher IOR)
    float r01 = (1.0 - filmIOR) / (1.0 + filmIOR);
    float r12 = (filmIOR - baseIOR) / (filmIOR + baseIOR);
    if (r01 * r12 < 0.0) {
        phase += PI;
    }

    // Airy interference intensity formula for thin transparent films
    vec3 interference = 0.5 + 0.5 * cos(phase);

    // Apply chromatic dispersion fringe enhancement
    return clamp(interference * uIridescenceTint, 0.0, 1.0);
}

// -----------------------------------------------------------------------------
// 5. Subsurface Scattering (SSS) Approximation
// Simulates light diffusing through translucent geometry (wings, skin, ears).
// Backlight transmission model with normal distortion and absorption falloff.
// -----------------------------------------------------------------------------
vec3 evaluateSubsurfaceScattering(
    vec3 N,
    vec3 V,
    vec3 L,
    vec3 lightRadiance,
    float sssMask
) {
    float weight = uSSSParams.x * sssMask;
    if (weight <= 0.001) {
        return vec3(0.0);
    }

    float distortion = uSSSParams.y;
    float power = uSSSParams.z;
    float scale = uSSSParams.w;

    // Distorted light vector pointing through the geometry back towards view
    vec3 sssL = normalize(L + N * distortion);
    float inScatter = clamp(dot(V, -sssL), 0.0, 1.0);
    float sssIntensity = pow(inScatter, power) * scale;

    // Exponential thickness extinction falloff
    float extinction = exp(-uSSSExtinction);

    return uSSSColor * lightRadiance * (sssIntensity * extinction * weight);
}

// -----------------------------------------------------------------------------
// 6. Temporal Emissive Rune Modulation
// Produces breathing, arcane rhythmic, or overdrive surges for runic armor.
// -----------------------------------------------------------------------------
float evaluateRunePulsation(float time, vec4 params) {
    float speed = params.x;
    float freq = params.y;
    float dutyCycle = clamp(params.z, 0.1, 8.0);
    int modType = int(params.w + 0.5);

    float t = time * speed;

    if (modType == 0) {
        // Continuous Sine Breathing: smooth natural organic pulse
        float s = sin(t * freq * 2.0 * PI) * 0.5 + 0.5;
        return pow(s, dutyCycle);
    } else if (modType == 1) {
        // Heartbeat Dual Pulse: Aion 2 ancient draconic heartbeat pattern
        float cycle = fract(t * freq);
        float p1 = smoothstep(0.0, 0.08, cycle) * (1.0 - smoothstep(0.08, 0.22, cycle));
        float p2 = smoothstep(0.25, 0.33, cycle) * (1.0 - smoothstep(0.33, 0.48, cycle));
        return clamp(pow(p1 * 1.0 + p2 * 0.6, dutyCycle), 0.0, 1.0);
    } else if (modType == 2) {
        // Arcane Harmonic Superposition: multi-frequency ethereal shimmer
        float h1 = sin(t * freq * 1.0 * 2.0 * PI);
        float h2 = sin(t * freq * 2.37 * 2.0 * PI) * 0.5;
        float h3 = sin(t * freq * 4.81 * 2.0 * PI) * 0.25;
        float combined = (h1 + h2 + h3) / 1.75 * 0.5 + 0.5;
        return pow(clamp(combined, 0.0, 1.0), dutyCycle);
    } else {
        // Overload Power Surge: rapid high-intensity flickering flare
        float fastFlicker = fract(sin(floor(t * 24.0) * 43758.5453));
        float surge = sin(t * freq * 2.0 * PI) * 0.5 + 0.5;
        return pow(surge, dutyCycle) * (0.8 + 0.2 * fastFlicker);
    }
}

// -----------------------------------------------------------------------------
// 7. Surface Normal & Tangent Space Derivation
// -----------------------------------------------------------------------------
vec3 deriveSurfaceNormal(vec2 uv, vec2 fragCoord) {
    // Sample tangent normal from normal map (Slot 1)
    vec4 nSample = texture(uNormalMap, uv);
    vec3 tangentNormal;
    if (length(nSample.rgb) > 0.01) {
        tangentNormal = nSample.xyz * 2.0 - 1.0;
        tangentNormal.xy *= uNormalIntensity;
        tangentNormal = normalize(tangentNormal);
    } else {
        tangentNormal = vec3(0.0, 0.0, 1.0);
    }

    // Compute geometric curvature from screen UV for preview spheres / models
    vec2 ndc = (fragCoord / uResolution) * 2.0 - 1.0;
    ndc.y = -ndc.y; // Invert Y to match OpenGL / Flutter coordinate orientation

    float distSq = dot(ndc, ndc);
    vec3 baseGeoNormal;
    if (distSq < 1.0) {
        // Spherical dome normal for material test preview
        baseGeoNormal = vec3(ndc.x, ndc.y, sqrt(max(0.0, 1.0 - distSq)));
    } else {
        // Flat planar normal pointing along view axis
        baseGeoNormal = vec3(0.0, 0.0, 1.0);
    }
    baseGeoNormal = normalize(baseGeoNormal);

    // Construct orthonormal tangent-bitangent-normal (TBN) matrix
    vec3 up = abs(baseGeoNormal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(up, baseGeoNormal));
    vec3 bitangent = cross(baseGeoNormal, tangent);
    mat3 tbn = mat3(tangent, bitangent, baseGeoNormal);

    // Perturb geometric normal with tangent space normal
    vec3 n = normalize(tbn * tangentNormal);
    return n;
}

// -----------------------------------------------------------------------------
// 8. ACES Filmic Tonemapping & Color Transform (Krzysztof Narkowicz Standard)
// Maps high-dynamic-range radiance [0.0, +inf] into displayable [0.0, 1.0].
// -----------------------------------------------------------------------------
vec3 acesTonemap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// -----------------------------------------------------------------------------
// Main Fragment Execution
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = (fragCoord / uResolution) * uTiling + uOffset;

    // Sample Material Texture Maps
    vec4 albedoSample = texture(uAlbedoMap, uv);
    vec4 pbrSample = texture(uMetallicRoughnessAOMap, uv);
    vec4 runeSample = texture(uEmissiveRuneMap, uv);

    // If texture slot is unbound/empty (returns zeros), safely fallback to parameter defaults
    bool hasAlbedo = albedoSample.a > 0.001 || length(albedoSample.rgb) > 0.001;
    vec3 albedoTex = hasAlbedo ? albedoSample.rgb : vec3(1.0);
    float alphaTex = hasAlbedo ? albedoSample.a : 1.0;

    vec3 albedo = uBaseColor.rgb * albedoTex;
    float alpha = uBaseColor.a * alphaTex;

    bool hasPbr = length(pbrSample.rgba) > 0.001;
    float roughness = clamp(uRoughness * (hasPbr ? pbrSample.g : 1.0), 0.04, 1.0);
    float metallic  = clamp(uMetallic  * (hasPbr ? pbrSample.b : 1.0), 0.0, 1.0);
    float ao        = clamp(uAOIntensity * (hasPbr ? pbrSample.r : 1.0), 0.0, 1.0);

    bool hasRune = length(runeSample.rgba) > 0.001;
    float emissiveMask    = hasRune ? runeSample.r : 1.0;
    float runePatternMask = hasRune ? runeSample.g : 1.0;
    float sssMask         = hasRune ? runeSample.b : 1.0;
    float iridMask        = hasRune ? runeSample.a : 1.0;

    // Compute Surface Vectors
    vec3 N = deriveSurfaceNormal(uv, fragCoord);

    // World position reconstruction for fragment
    vec3 fragPos = vec3((fragCoord / uResolution - 0.5) * 2.0, 0.0);
    vec3 V = normalize(uCameraPos - fragPos);
    vec3 L = normalize(uLightPos - fragPos);
    vec3 H = normalize(V + L);

    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0001);
    float VdotH = max(dot(V, H), 0.0);

    // -------------------------------------------------------------------------
    // Cook-Torrance Microfacet BRDF Evaluation
    // -------------------------------------------------------------------------
    vec3 F0 = mix(DIELECTRIC_F0, albedo, metallic);

    // Thin-film Iridescence Sheen Modification
    float iridWeight = uIridescenceParams.x * iridMask;
    if (iridWeight > 0.001) {
        vec3 iridColor = evaluateThinFilmIridescence(
            NdotV,
            uIridescenceParams.y,
            uIridescenceParams.z,
            uIridescenceParams.w,
            uIridescenceAngleShift
        );
        // Iridescence modulates the specular Fresnel response
        F0 = mix(F0, iridColor, iridWeight);
    }

    // Normal Distribution, Geometry Shadowing, and Fresnel
    float D = distributionGGX(N, H, roughness);
    float G = geometrySmith(N, V, L, roughness);
    vec3  F = fresnelSchlick(VdotH, F0);

    // Specular BRDF Term
    vec3 numerator = D * G * F;
    float denominator = 4.0 * NdotV * NdotL + 0.0001;
    vec3 specular = numerator / denominator;

    // Energy Conservation: Diffuse vs Specular
    vec3 kS = F;
    vec3 kD = (vec3(1.0) - kS) * (1.0 - metallic);
    vec3 diffuse = kD * albedo * INV_PI;

    // Clearcoat Secondary Specular Layer (Aion 2 polished lacquered armor)
    vec3 clearcoatSpecular = vec3(0.0);
    if (uClearcoat > 0.001) {
        float Dc = distributionGGX(N, H, uClearcoatRoughness);
        float Gc = geometrySmith(N, V, L, uClearcoatRoughness);
        vec3  Fc = fresnelSchlick(VdotH, DIELECTRIC_F0);
        clearcoatSpecular = (Dc * Gc * Fc) / (4.0 * NdotV * NdotL + 0.0001) * uClearcoat;
    }

    // Direct Lighting Contribution
    vec3 lightRadiance = uLightColor * uLightIntensity;
    vec3 directLighting = (diffuse + specular + clearcoatSpecular) * lightRadiance * NdotL;

    // Subsurface Scattering (SSS) Contribution (Wings & Skin)
    vec3 sssContribution = evaluateSubsurfaceScattering(N, V, L, lightRadiance, sssMask);

    // Ambient Environmental Lighting (Irradiance + Ambient Specular)
    vec3 ambientFresnel = fresnelSchlickRoughness(NdotV, F0, roughness);
    vec3 ambientDiffuse = (vec3(1.0) - ambientFresnel) * (1.0 - metallic) * albedo * uAmbientLight;
    vec3 ambientSpecular = ambientFresnel * uAmbientLight * (1.0 - roughness * 0.5);
    vec3 ambientLighting = (ambientDiffuse + ambientSpecular) * ao;

    // Emissive Rune Pulsating Modulation
    float runePulse = evaluateRunePulsation(uTime, uEmissiveRuneParams);
    vec3 emissive = uEmissiveColor.rgb * (uEmissiveColor.a * emissiveMask * runePatternMask * runePulse);

    // Final Radiance Accumulation (Linear HDR)
    vec3 linearHdr = directLighting + sssContribution + ambientLighting + emissive;

    // ACES Filmic Tonemapping to compress high-dynamic-range highlights
    vec3 tonemapped = acesTonemap(linearHdr);

    // Gamma 2.2 correction to sRGB mobile standard
    vec3 finalRgb = pow(tonemapped, vec3(1.0 / 2.2));

    // Output fragColor with alpha
    fragColor = vec4(finalRgb, alpha);
}
