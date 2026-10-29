#version 460 core
#include <flutter/runtime_effect.glsl>

// =============================================================================
// Unified Post-Processing Composite: SSAO Modulation + ACES Filmic Tonemapping
// High-Performance Single-Pass Screen Composite for AAA Mobile & Desktop
//
// Pipeline Capabilities:
// 1. Bilateral-filtered Ambient Occlusion modulation with direct light preservation
// 2. Camera exposure adjustment (Linear multiplier or EV stops: 2^EV)
// 3. Dual ACES filmic tonemapping curve fits:
//    - Stephen Hill / Academy fitted model (AP1 color matrix + RRT/ODT rational fit)
//    - Krzysztof Narkowicz fast analytical curve fit
// 4. Output transfer functions:
//    - Accurate IEC 61966-2-1 standard linear-to-sRGB
//    - Standard display Gamma 2.2 power law
//
// Optimized for Flutter Impeller & Skia GPU Runtime Effect pipeline.
// =============================================================================

precision highp float;
precision mediump sampler2D;

// -----------------------------------------------------------------------------
// Uniforms: All numeric uniforms declared before samplers (8 floats total)
// STRICT: Must precede sampler2D declarations for Impeller runtime effect layout
// -----------------------------------------------------------------------------
uniform vec2  uResolution;             // [0..1] Viewport resolution in pixels (width, height)
uniform float uExposure;               // [2]    Exposure value (stops in EV or linear factor)
uniform float uExposureMode;           // [3]    0.0 = Linear multiplier, 1.0 = EV stops (2^EV)
uniform float uFitType;                // [4]    0.0 = Stephen Hill ACES, 1.0 = Krzysztof Narkowicz ACES
uniform float uGammaMode;              // [5]    0.0 = Accurate IEC 61966-2-1 sRGB, 1.0 = Gamma 2.2
uniform float uAoIntensity;            // [6]    SSAO blend intensity onto scene ambient (e.g. 1.0)
uniform float uAoDirectLightPreserve;   // [7]    Direct light preserved from AO shadowing (e.g. 0.25)

// -----------------------------------------------------------------------------
// Texture Samplers (Declared strictly after numeric uniforms)
// -----------------------------------------------------------------------------
uniform sampler2D uSceneTexture;       // Texture unit 0: Linear HDR scene color
uniform sampler2D uAoTexture;          // Texture unit 1: Denoised AO factor in R channel

out vec4 fragColor;

// -----------------------------------------------------------------------------
// 1. ACES Color Transform Matrices (Stephen Hill Fit)
// Transforms linear sRGB -> ACEScg AP1 -> RRT/ODT -> sRGB
// Matrices are column-major in GLSL matching AP1 gamut transfer
// -----------------------------------------------------------------------------
const mat3 ACES_INPUT_MAT = mat3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
);

const mat3 ACES_OUTPUT_MAT = mat3(
    1.60475, -0.10208, -0.00327,
    -0.53108, 1.10813, -0.07276,
    -0.07367, -0.00605, 1.07602
);

vec3 rrtAndOdtFit(vec3 v) {
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 acesStephenHill(vec3 color) {
    vec3 v = ACES_INPUT_MAT * color;
    vec3 rrt = rrtAndOdtFit(v);
    vec3 srgb = ACES_OUTPUT_MAT * rrt;
    return clamp(srgb, 0.0, 1.0);
}

// -----------------------------------------------------------------------------
// 2. Krzysztof Narkowicz Fast ACES Curve Fit
// -----------------------------------------------------------------------------
vec3 acesNarkowicz(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// -----------------------------------------------------------------------------
// 3. Transfer Functions: IEC 61966-2-1 sRGB and Gamma 2.2
// -----------------------------------------------------------------------------
float linearToSrgbChannel(float c) {
    c = clamp(c, 0.0, 1.0);
    if (c <= 0.0031308) {
        return c * 12.92;
    } else {
        return 1.055 * pow(c, 1.0 / 2.4) - 0.055;
    }
}

vec3 linearToSrgb(vec3 linearColor) {
    return vec3(
        linearToSrgbChannel(linearColor.r),
        linearToSrgbChannel(linearColor.g),
        linearToSrgbChannel(linearColor.b)
    );
}

vec3 linearToGamma22(vec3 linearColor) {
    return pow(clamp(linearColor, 0.0, 1.0), vec3(1.0 / 2.2));
}

// -----------------------------------------------------------------------------
// Main Post-Processing Fragment Shader Execution
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 res = max(uResolution, vec2(1.0));
    vec2 uv = fragCoord / res;

    // Sample HDR Scene Color
    vec4 sceneColor = texture(uSceneTexture, uv);
    vec3 linearRgb = max(sceneColor.rgb, vec3(0.0));

    // Sample Bilateral-Filtered AO factor in R channel
    float rawAo = texture(uAoTexture, uv).r;
    float ao = clamp(rawAo, 0.0, 1.0);
    float aoIntensity = (uAoIntensity >= 0.0) ? uAoIntensity : 1.0;
    float directPreserve = clamp((uAoDirectLightPreserve >= 0.0) ? uAoDirectLightPreserve : 0.25, 0.0, 1.0);

    // Ambient Occlusion modulates ambient light while preserving specular/direct highlights
    // Clamped to [0.0, 1.0] to prevent extrapolation artifacts when aoIntensity > 1.0
    float aoMultiplier = clamp(mix(1.0, mix(directPreserve, 1.0, ao), aoIntensity), 0.0, 1.0);
    linearRgb *= aoMultiplier;

    // Apply Camera Exposure (EV stops: 2^EV, or linear multiplier)
    float exposureFactor = 1.0;
    if (uExposureMode > 0.5) {
        exposureFactor = exp2(uExposure);
    } else {
        exposureFactor = (uExposure > 0.0) ? uExposure : 1.0;
    }
    linearRgb *= exposureFactor;

    // Apply ACES Filmic Tonemapping
    vec3 tonemapped;
    if (uFitType > 0.5) {
        tonemapped = acesNarkowicz(linearRgb);
    } else {
        tonemapped = acesStephenHill(linearRgb);
    }

    // Apply Output Gamma Correction (Accurate sRGB vs Gamma 2.2)
    vec3 finalRgb;
    if (uGammaMode > 0.5) {
        finalRgb = linearToGamma22(tonemapped);
    } else {
        finalRgb = linearToSrgb(tonemapped);
    }

    fragColor = vec4(clamp(finalRgb, 0.0, 1.0), sceneColor.a);
}
