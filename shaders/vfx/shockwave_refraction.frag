#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// -----------------------------------------------------------------------------
// Production-Ready Refraction & Distortion Shader Pipeline (AAA 2027)
// Compatible with Flutter RuntimeEffect & Impeller Graphics Pipeline
//
// Capabilities:
// - Spherical / circular shockwave expansion curves with adjustable frequency,
//   thickness, dampening, and easing.
// - Radial chromatic aberration splitting R, G, B channels along wave normal.
// - Normal-map sampled UV distortion blended with analytical wave equations.
// - Specialized visual modes:
//     0.0 = Blast Shockwave (explosions, physical ground impacts)
//     1.0 = Critical Hit (high-frequency dual harmonics, intense dispersion, flash)
//     2.0 = Heat Haze (convective turbulence, rising heat distortion)
//     3.0 = Magical Shield Impact (standing interference rings, barrier shimmer)
// - Wavefront energy tint & additive bloom flare for impactful combat feel.
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Numeric Uniforms (Indices 0 .. 17, total 18 floats)
// STRICT: Declared before any sampler2D uniforms for Impeller compliance.
// -----------------------------------------------------------------------------
uniform vec2 uResolution;           // 0..1:   Viewport / canvas size in device pixels
uniform vec2 uCenter;               // 2..3:   Effect origin in normalized UV coords [0..1]
uniform float uProgress;            // 4:      Shockwave expansion progress [0.0..1.0]
uniform float uTime;                // 5:      Elapsed continuous time in seconds
uniform float uMaxRadius;           // 6:      Maximum expansion radius normalized to min dimension
uniform float uThickness;           // 7:      Thickness / width of wavefront ring
uniform float uRefractionStrength;  // 8:      Peak distortion displacement amplitude
uniform float uChromaticAberration; // 9:      Radial chromatic dispersion magnitude
uniform float uDampening;           // 10:     Exponential decay factor over time / progress
uniform float uFrequency;           // 11:     Wave oscillation frequency / ripple count
uniform float uMode;                // 12:     Effect mode: 0=Shockwave, 1=Crit, 2=Heat, 3=Shield
uniform float uUseNormalMap;        // 13:     0.0 = analytical procedural normal, 1.0 = texture
uniform vec4 uTint;                 // 14..17: Wavefront glow tint (RGB) and intensity factor (A)

// -----------------------------------------------------------------------------
// Texture Samplers (Strictly declared after all numeric uniforms)
// -----------------------------------------------------------------------------
uniform sampler2D uSceneTexture;    // Slot 0: Scene background buffer being refracted
uniform sampler2D uNormalMapTexture;// Slot 1: Optional normal map for surface ripples / fluid noise

out vec4 fragColor;

const float PI = 3.14159265358979323846;
const float TWO_PI = 6.28318530717958647692;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / max(uResolution, vec2(1.0));

    // Aspect ratio correction to preserve isotropic circular wavefronts
    float minDim = min(uResolution.x, uResolution.y);
    vec2 aspectScale = uResolution / max(minDim, 1.0);
    vec2 delta = (uv - uCenter) * aspectScale;
    float dist = length(delta);
    vec2 radialDir = (dist > 0.00001) ? (delta / dist) / aspectScale : vec2(0.0, 0.0);

    vec2 displacement = vec2(0.0);
    float decayFactor = 0.0;

    // -------------------------------------------------------------------------
    // Mode-Specific Distortion Synthesizers
    // -------------------------------------------------------------------------
    if (uMode < 0.5) {
        // --- Mode 0: Blast Shockwave (Explosions / Physical Impacts) ---
        float currentRadius = uMaxRadius * uProgress;
        float distToFront = dist - currentRadius;
        float halfThick = max(uThickness * 0.5, 0.0001);

        if (abs(distToFront) < halfThick) {
            float x = distToFront / halfThick; // [-1.0 .. 1.0]
            // Hann window envelope for seamless boundary tapering
            float envelope = 0.5 * (1.0 + cos(x * PI));
            // Sinusoidal displacement across wave ring (physically based wave gradient)
            float wave = -sin(x * PI * max(uFrequency, 0.1));
            float timeDecay = exp(-uDampening * uProgress) * clamp(1.0 - uProgress, 0.0, 1.0);
            decayFactor = timeDecay * envelope;
            displacement = radialDir * (wave * envelope * timeDecay * uRefractionStrength);
        }
    } else if (uMode < 1.5) {
        // --- Mode 1: Critical Hit Blast (High-velocity dual-harmonic wave) ---
        // Fast square-root initial expansion for instant hit feel
        float currentRadius = uMaxRadius * sqrt(clamp(uProgress, 0.0, 1.0));
        float distToFront = dist - currentRadius;
        float halfThick = max(uThickness * 0.5, 0.0001);

        if (abs(distToFront) < halfThick) {
            float x = distToFront / halfThick;
            float envelope = 0.5 * (1.0 + cos(x * PI));
            // Multi-harmonic violent ripple
            float wavePrimary = -sin(x * PI * max(uFrequency, 0.1));
            float waveSecondary = -0.4 * sin(x * TWO_PI * max(uFrequency, 0.1));
            float combinedWave = wavePrimary + waveSecondary;

            float timeDecay = exp(-uDampening * 0.7 * uProgress) * clamp(1.0 - uProgress, 0.0, 1.0);
            decayFactor = timeDecay * envelope;
            displacement = radialDir * (combinedWave * envelope * timeDecay * uRefractionStrength);
        }
    } else if (uMode < 2.5) {
        // --- Mode 2: Heat Haze (Convective rising turbulence) ---
        vec2 hazeUv = uv * (max(uFrequency, 1.0) * 8.0);
        hazeUv.y -= uTime * 2.5; // rising convection drift

        float w1 = sin(hazeUv.x * 2.0 + sin(hazeUv.y * 3.0 + uTime * 3.5));
        float w2 = cos(hazeUv.y * 2.5 + cos(hazeUv.x * 3.5 - uTime * 2.8));
        float w3 = sin((hazeUv.x + hazeUv.y) * 1.8 + uTime * 2.2);

        vec2 rawTurbulence = vec2(w1 + w3 * 0.4, w2 + w1 * 0.35) * 0.5;

        // Radial falloff plume from origin center
        float hazeRadius = max(uMaxRadius, 0.01);
        float hazeFalloff = clamp(1.0 - dist / hazeRadius, 0.0, 1.0);
        hazeFalloff = smoothstep(0.0, 1.0, hazeFalloff);

        displacement = (rawTurbulence / aspectScale) * (uRefractionStrength * hazeFalloff);
        decayFactor = hazeFalloff;
    } else {
        // --- Mode 3: Magical Shield Impact (Interference ripples & barrier shimmer) ---
        float currentRadius = uMaxRadius * uProgress;
        float phase = (dist - currentRadius) / max(uThickness, 0.001);
        float ringWave = sin(phase * PI * max(uFrequency, 0.1));

        float spatialDecay = exp(-dist * 2.5 / max(uMaxRadius, 0.01));
        float timeDecay = exp(-uDampening * uProgress) * clamp(1.0 - uProgress, 0.0, 1.0);

        // Subtle 6-fold hexagonal lattice modulation for magical runic barrier
        float angle = (dist > 0.00001) ? atan(delta.y, delta.x) : 0.0;
        float hexMod = 1.0 + 0.18 * cos(angle * 6.0);

        // Shield barrier cutoff envelope: barrier only exists within uMaxRadius
        float barrierMask = smoothstep(1.0, 0.85, dist / max(uMaxRadius, 0.01));
        decayFactor = timeDecay * spatialDecay * barrierMask;

        float shieldMag = ringWave * spatialDecay * timeDecay * hexMod * barrierMask;
        displacement = radialDir * (shieldMag * uRefractionStrength);
    }

    // -------------------------------------------------------------------------
    // Optional Normal Map Texture Perturbation
    // -------------------------------------------------------------------------
    if (uUseNormalMap > 0.5) {
        vec2 normalUv = uv * 3.0 + vec2(uTime * 0.05, uTime * 0.02);
        vec3 normalSample = texture(uNormalMapTexture, normalUv).rgb;
        vec2 normalDelta = (normalSample.rg * 2.0 - 1.0);

        float normalDecay = (uMode > 1.5 && uMode < 2.5) ? decayFactor : (decayFactor * 0.6);
        displacement += (normalDelta / aspectScale) * (uRefractionStrength * normalDecay * 0.5);
    }

    // -------------------------------------------------------------------------
    // Radial Chromatic Aberration
    // -------------------------------------------------------------------------
    float chromaticIntensity = uChromaticAberration;
    if (uMode > 0.5 && uMode < 1.5) {
        chromaticIntensity *= 2.5; // Extra chromatic dispersion on critical hits
    }

    float dispMagnitude = length(displacement * aspectScale);
    float chromaticOffset = chromaticIntensity * (dispMagnitude / max(uRefractionStrength, 0.0001));

    vec2 offsetR = displacement + radialDir * chromaticOffset;
    vec2 offsetG = displacement;
    vec2 offsetB = displacement - radialDir * chromaticOffset;

    vec2 uvR = clamp(uv + offsetR, vec2(0.0001), vec2(0.9999));
    vec2 uvG = clamp(uv + offsetG, vec2(0.0001), vec2(0.9999));
    vec2 uvB = clamp(uv + offsetB, vec2(0.0001), vec2(0.9999));

    float r = texture(uSceneTexture, uvR).r;
    float g = texture(uSceneTexture, uvG).g;
    float b = texture(uSceneTexture, uvB).b;
    float a = texture(uSceneTexture, uvG).a;

    // -------------------------------------------------------------------------
    // Wavefront Energy Tint & Critical Hit Flash Flare
    // -------------------------------------------------------------------------
    float energyRatio = clamp(dispMagnitude / max(uRefractionStrength, 0.0001), 0.0, 2.0);
    vec3 glow = uTint.rgb * (energyRatio * uTint.a);

    // Add bright central flash on critical hit impact start
    if (uMode > 0.5 && uMode < 1.5) {
        float centerFlash = clamp(1.0 - dist / max(uMaxRadius * 0.35, 0.01), 0.0, 1.0);
        float flashDecay = exp(-uDampening * 4.0 * uProgress);
        glow += vec3(1.0, 0.96, 0.82) * (centerFlash * flashDecay * 0.9);
    }

    vec3 finalRgb = vec3(r, g, b) + glow;
    fragColor = vec4(finalRgb, a);
}
