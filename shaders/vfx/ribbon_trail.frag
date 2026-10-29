#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// -----------------------------------------------------------------------------
// AAA Weapon Swing Ribbon Trail & Mesh Fragment Shader (2027 Cinematic Pipeline)
// Compatible with Flutter RuntimeEffect & Impeller Graphics Pipeline
//
// Features:
// - Dynamic UV scrolling along weapon swing arc (U coordinate)
// - Analytical multi-harmonic plasma distortion and chromatic dispersion
// - High-order transverse edge feathering (V coordinate) to eliminate polygon edges
// - Longitudinal age decay with customizable power curve (head to tail)
// - HDR Bloom Boost (> 1.0 emissive radiance) for bloom post-processing passes
// - Procedural energy wave synthesis blended with optional texture sampling
// -----------------------------------------------------------------------------

// Float & Vector Uniforms (must precede samplers in Flutter runtime shaders)
uniform vec2 uResolution;          // Viewport resolution in canvas pixels
uniform float uTime;               // Elapsed time in seconds for animation
uniform vec4 uBaseColor;           // Core trail color (RGBA linear)
uniform vec4 uGlowColor;           // Emissive HDR glow tint (RGBA linear)
uniform vec4 uBounds;              // Trail mesh AABB: vec4(minX, minY, width, height)
uniform float uScrollSpeed;        // UV texture scrolling velocity along swing arc
uniform float uDistortionStrength; // Magnitude of UV warp distortion (e.g. 0.05 - 0.2)
uniform float uDistortionFreq;     // Spatial frequency of plasma distortion
uniform float uGlowIntensity;      // HDR bloom radiance multiplier (e.g. 2.0 - 6.0)
uniform float uFadePower;          // Longitudinal head-to-tail decay exponent
uniform float uTransversePower;    // Transverse edge-to-core glow sharpness exponent
uniform float uTextureMix;         // 0.0 = pure procedural energy, 1.0 = full texture

// Sampler Uniforms (must follow all numeric uniforms)
uniform sampler2D uTrailTexture;   // Trail texture (streak / noise / slash gradient)

out vec4 fragColor;

const float PI = 3.14159265358979323846;
const float TWO_PI = 6.28318530717958647692;

// -----------------------------------------------------------------------------
// Procedural Wave & Plasma Turbulence
// Synthesizes layered sine-cosine harmonic waves to model magical energy and heat
// -----------------------------------------------------------------------------
vec2 computeDistortion(vec2 uv, float time, float freq, float strength) {
    if (strength <= 0.0001) {
        return vec2(0.0);
    }

    // Wrap time periodically to avoid floating-point precision degradation on mobile GPUs
    float animTime = mod(time, 628.31853);
    float t = animTime * 2.5;
    float wave1 = sin(uv.x * freq * 6.28318 + t * 1.3) * cos(uv.y * freq * 3.14159 - t * 0.8);
    float wave2 = sin((uv.x + uv.y) * (freq * 1.8) - t * 2.1);
    float wave3 = cos((uv.x * 2.5 - uv.y * 1.5) * freq + t * 3.7);

    vec2 offset = vec2(
        wave1 * 0.6 + wave2 * 0.4,
        wave2 * 0.5 + wave3 * 0.5
    );

    return offset * strength;
}

// -----------------------------------------------------------------------------
// Procedural Slash Energy Pattern
// Produces vibrant multi-stream energy filaments when no texture is provided
// -----------------------------------------------------------------------------
float computeEnergyStreams(vec2 uv, float time) {
    float u = uv.x;
    float v = uv.y;

    // Center filament profile: 1.0 at center (v = 0.5), tapering to 0.0 at edges
    float core = clamp(1.0 - abs(v - 0.5) * 2.0, 0.0, 1.0);

    // Wrap time periodically to avoid precision loss
    float animTime = mod(time, 628.31853);

    // Multi-filament energy lines traveling along the arc
    float stream1 = sin((u * 12.0 - animTime * 6.0) + sin(v * 8.0)) * 0.5 + 0.5;
    float stream2 = cos((u * 20.0 - animTime * 10.0) - cos(v * 12.0)) * 0.5 + 0.5;
    float stream3 = sin((u * 32.0 - animTime * 15.0) + v * 16.0) * 0.5 + 0.5;

    float filaments = stream1 * 0.5 + stream2 * 0.3 + stream3 * 0.2;
    return mix(filaments, 1.0, 0.4) * core;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // Calculate normalized local UV coordinates:
    // If uBounds has valid positive width and height, use localized trail UVs;
    // otherwise fallback to full-screen viewport UVs.
    vec2 uv;
    float boundsFalloff = 1.0;
    if (uBounds.z > 0.001 && uBounds.w > 0.001) {
        uv = (fragCoord - uBounds.xy) / uBounds.zw;

        // Discard fragments strictly outside localized trail bounds
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            discard;
        }

        // Feather extreme quad boundary edges to avoid harsh rasterizer stepping
        vec2 edgeDist = min(uv, 1.0 - uv);
        float edgeMin = min(edgeDist.x, edgeDist.y);
        boundsFalloff = smoothstep(0.0, 0.015, edgeMin);
    } else {
        uv = fragCoord / max(uResolution, vec2(1.0));
    }

    // Normalized UV clamped strictly to [0, 1]
    vec2 clampedUv = clamp(uv, 0.0, 1.0);

    // 1. Procedural Distortion & Chromatic Dispersion
    vec2 distortion = computeDistortion(clampedUv, uTime, uDistortionFreq, uDistortionStrength);

    // Chromatic dispersion offsets for cinematic refraction / plasma shimmer
    vec2 uvRed   = clampedUv + distortion * 1.08;
    vec2 uvGreen = clampedUv + distortion;
    vec2 uvBlue  = clampedUv + distortion * 0.92;

    // Apply UV scrolling along the arc (U axis)
    if (abs(uScrollSpeed) > 0.0001) {
        float scrollOffset = mod(uTime * uScrollSpeed, 1.0);
        uvRed.x   = fract(fract(uvRed.x - scrollOffset) + 1.0);
        uvGreen.x = fract(fract(uvGreen.x - scrollOffset) + 1.0);
        uvBlue.x  = fract(fract(uvBlue.x - scrollOffset) + 1.0);
    } else {
        uvRed.x   = clamp(uvRed.x, 0.0, 1.0);
        uvGreen.x = clamp(uvGreen.x, 0.0, 1.0);
        uvBlue.x  = clamp(uvBlue.x, 0.0, 1.0);
    }

    // Clamp transverse Y to valid texture coordinate range
    uvRed.y   = clamp(uvRed.y, 0.0, 1.0);
    uvGreen.y = clamp(uvGreen.y, 0.0, 1.0);
    uvBlue.y  = clamp(uvBlue.y, 0.0, 1.0);

    // 2. Texture Sampling with Chromatic Separation
    vec4 texColor = vec4(1.0);
    if (uTextureMix > 0.001) {
        float r = texture(uTrailTexture, uvRed).r;
        float g = texture(uTrailTexture, uvGreen).g;
        float b = texture(uTrailTexture, uvBlue).b;
        float a = texture(uTrailTexture, uvGreen).a;
        vec4 sampled = vec4(r, g, b, a);
        texColor = mix(vec4(1.0), sampled, clamp(uTextureMix, 0.0, 1.0));
    }

    // 3. Procedural Energy Synthesis
    float proceduralEnergy = computeEnergyStreams(clampedUv + distortion * 0.5, uTime);

    // 4. Longitudinal Head-to-Tail Falloff (U axis)
    // u = 0.0 is the leading edge (brightest), u = 1.0 is the fading tail
    float lengthDecay = clamp(1.0 - clampedUv.x, 0.0, 1.0);
    float longitudinalFactor = (lengthDecay > 0.0001)
        ? pow(lengthDecay, max(uFadePower, 0.05))
        : 0.0;

    // 5. Transverse Edge-to-Center Glow (V axis)
    // Center at v = 0.5 is maximum intensity, tapering to 0.0 at upper and lower edges
    float distFromCenter = abs(clampedUv.y - 0.5) * 2.0;
    float centerProfile = clamp(1.0 - distFromCenter, 0.0, 1.0);
    float transverseFactor = (centerProfile > 0.0001)
        ? pow(centerProfile, max(uTransversePower, 0.05))
        : 0.0;

    // 6. High-Intensity White Core Mask
    // Center blade line gets ultra-bright white core
    float coreSharpness = (centerProfile > 0.0001)
        ? (pow(centerProfile, 4.0) * longitudinalFactor)
        : 0.0;

    // 7. Composite Alpha & Radiance
    float combinedAlpha = longitudinalFactor * transverseFactor * texColor.a * boundsFalloff;
    combinedAlpha *= mix(1.0, proceduralEnergy, 1.0 - clamp(uTextureMix, 0.0, 1.0));

    // Base tinted color
    vec3 baseRgb = uBaseColor.rgb * texColor.rgb;

    // Emissive Glow and HDR Bloom Boost
    // When uGlowIntensity > 1.0, high-energy areas exceed 1.0 RGB for bloom thresholding
    float bloomMultiplier = max(uGlowIntensity, 0.0);
    float glowAlpha = clamp(uGlowColor.a, 0.0, 1.0);
    vec3 glowRgb = uGlowColor.rgb * (glowAlpha * transverseFactor * longitudinalFactor * bloomMultiplier);

    // Add white-hot blade core for high-tier game feel
    vec3 whiteCore = vec3(1.0, 1.0, 1.0) * (coreSharpness * bloomMultiplier * glowAlpha * 1.5);

    // Final total Alpha
    float totalAlpha = clamp(combinedAlpha * clamp(uBaseColor.a, 0.0, 1.0), 0.0, 1.0);

    // If using outside bounds or fully faded, discard fragment to preserve fillrate
    if (totalAlpha <= 0.001) {
        discard;
    }

    // Final Linear RGB composition (premultiplied by totalAlpha)
    vec3 finalRgb = (baseRgb + glowRgb + whiteCore) * totalAlpha;

    fragColor = vec4(finalRgb, totalAlpha);
}
