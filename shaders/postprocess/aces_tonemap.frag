#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// Production GLSL 460 Fragment Shader: ACES Filmic Tonemapping & Color Grading
// AAA Cinematic Standard for Flutter Impeller & Skia GPU RuntimeEffect Pipeline
//
// Features:
// 1. Dual ACES Filmic Curves:
//    - Stephen Hill (@self_shadow) & Stephen Black fitted model (ACEScg AP1 primaries)
//    - Krzysztof Narkowicz fast analytical curve fit for mobile efficiency
// 2. Dual Exposure Controls:
//    - Photographic EV stops (2^EV multiplier)
//    - Direct linear exposure factor
// 3. Dual Gamma Transfer Modes:
//    - Accurate IEC 61966-2-1 standard piecewise sRGB transfer function
//    - Fast power-law Gamma 2.2 approximation: C^(1 / 2.2)
// 4. Pre-gain linear multiplier & optional HDR white-point luminance ceiling clamp
// 5. Strict Impeller Float-Uniform packing (8 floats total) followed by Sampler
// -----------------------------------------------------------------------------

precision highp float;

// -----------------------------------------------------------------------------
// Uniform Declarations (Exact 8-Float Layout matching PostProcessPipelineController)
// STRICT: All scalar and vector numeric uniforms MUST precede sampler uniforms!
// -----------------------------------------------------------------------------
uniform vec2  uResolution;   // [0..1] Viewport resolution (pixels: width, height)
uniform float uExposure;     // [2]    Exposure value (EV stops or linear multiplier)
uniform float uExposureMode; // [3]    Mode: 0.0 = linear factor, 1.0 = EV stops (2^EV)
uniform float uFitType;      // [4]    Algorithm: 0.0 = Stephen Hill ACES, 1.0 = Narkowicz ACES
uniform float uGammaMode;    // [5]    Output gamma: 0.0 = IEC 61966-2-1 sRGB, 1.0 = Gamma 2.2
uniform float uPreGain;      // [6]    Pre-tonemapping linear gain multiplier (default 1.0)
uniform float uWhitePoint;   // [7]    HDR white point luminance clamp (0.0 = unconstrained)

// Sampler Declarations (Indexed after numeric buffer)
uniform sampler2D uSceneTexture; // [Sampler 0] High-dynamic range linear scene texture

// Fragment Shader Output
out vec4 fragColor;

// -----------------------------------------------------------------------------
// 1. Krzysztof Narkowicz ACES Fit
// Fast analytical approximation of ACES curve fit
// Reference: Krzysztof Narkowicz (2015) "ACES Filmic Tone Mapping Curve"
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
// 2. Stephen Hill / ACES Fitted Model
// High-precision spectral fit with sRGB to ACEScg AP1 color matrix,
// RRT+ODT fit curve, and ACES to sRGB output matrix.
// Reference: Stephen Hill (@self_shadow) & Stephen Black
// Matrices are column-major in GLSL.
// -----------------------------------------------------------------------------
// sRGB to ACEScg (AP1) matrix (column-major)
const mat3 ACES_INPUT_MAT = mat3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
);

// ACEScg to sRGB matrix (column-major)
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
// 3. Display Transfer Functions (Gamma Correction)
// -----------------------------------------------------------------------------
// Accurate IEC 61966-2-1 piecewise Linear-to-sRGB transfer function
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

// Power-law Gamma 2.2 approximation
vec3 linearToGamma22(vec3 linearColor) {
    return pow(clamp(linearColor, 0.0, 1.0), vec3(1.0 / 2.2));
}

// -----------------------------------------------------------------------------
// Main Post-Processing Fragment Entry Point
// -----------------------------------------------------------------------------
void main() {
    // 1. Compute normalized texture coordinates
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / max(uResolution, vec2(1.0));
    uv = clamp(uv, 0.0, 1.0);

    // 2. Fetch HDR linear scene sample
    vec4 sampleColor = texture(uSceneTexture, uv);
    vec3 linearColor = max(sampleColor.rgb, vec3(0.0));

    // 3. Apply pre-gain linear multiplier
    float preGain = (uPreGain > 0.0) ? uPreGain : 1.0;
    linearColor *= preGain;

    // 4. Apply exposure adjustment (Linear multiplier or EV stops: 2^EV)
    float exposureFactor = 1.0;
    if (uExposureMode > 0.5) {
        exposureFactor = exp2(uExposure);
    } else {
        exposureFactor = (uExposure > 0.0) ? uExposure : 1.0;
    }
    linearColor *= exposureFactor;

    // 5. Optional HDR white-point luminance ceiling clamp
    if (uWhitePoint > 0.0) {
        linearColor = min(linearColor, vec3(uWhitePoint));
    }

    // 6. Apply ACES Filmic Tonemapping curve
    vec3 tonemapped;
    if (uFitType > 0.5) {
        tonemapped = acesNarkowicz(linearColor);
    } else {
        tonemapped = acesStephenHill(linearColor);
    }

    // 7. Apply display gamma correction
    vec3 finalRgb;
    if (uGammaMode > 0.5) {
        finalRgb = linearToGamma22(tonemapped);
    } else {
        finalRgb = linearToSrgb(tonemapped);
    }

    // 8. Output final color, preserving source alpha
    fragColor = vec4(finalRgb, sampleColor.a);
}
