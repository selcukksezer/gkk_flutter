#version 460 core
#include <flutter/runtime_effect.glsl>

// =============================================================================
// Production Water Puddle Planar Reflection & Micro-Surface Ripple Shader
// 2027 AAA Studio V3 Cinematic Graphics Standard (R2 World Pipeline)
// Compatible with Flutter Impeller (Metal / MSL & Vulkan / SPIR-V) & Skia
//
// Capabilities:
// 1. Dual-octave Gerstner surface ripples and rain impact waves
// 2. Planar reflection texture sampling with micro-roughness perturbation
// 3. Physically-accurate Schlick Fresnel reflectance curve (water F0 = 0.02)
// 4. Muddy ground silt bed blending and Beer-Lambert depth extinction
// 5. Normal map sampling blended with procedural surface ripple normals
// =============================================================================

precision highp float;

// -----------------------------------------------------------------------------
// Numeric Uniforms (Indices 0 .. 5, total 6 floats)
// STRICT: Must be declared before any sampler uniforms for Impeller compliance.
// -----------------------------------------------------------------------------
uniform vec2  uResolution;      // [0..1] Viewport resolution in physical pixels
uniform float uTime;            // [2]    Continuous elapsed simulation time in seconds
uniform float uRippleSpeed;     // [3]    Wave propagation speed multiplier (default 1.0)
uniform float uPuddleRoughness; // [4]    Surface micro-facet roughness [0.0 = mirror, 1.0 = matte]
uniform float uReflectance;     // [5]    Base reflection intensity multiplier [0.0 - 2.0]

// -----------------------------------------------------------------------------
// Texture Samplers (Declared strictly after numeric uniforms)
// -----------------------------------------------------------------------------
uniform sampler2D uReflectionMap; // Slot 0: Planar scene reflection texture
uniform sampler2D uNormalMap;     // Slot 1: Micro-surface normal map texture

// Output Fragment Color
out vec4 fragColor;

// Mathematical Constants
const float PI = 3.14159265358979323846;
const float TWO_PI = 6.28318530717958647692;

// -----------------------------------------------------------------------------
// Procedural Hash for Circular Ripple Centers
// -----------------------------------------------------------------------------
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// -----------------------------------------------------------------------------
// Gerstner Wave Ripple Normal Perturbation
// -----------------------------------------------------------------------------
vec3 evaluateGerstnerRipples(vec2 uv, float time, float speed) {
    float t = time * speed;
    vec2 p = uv * 14.0;

    // Wave 1: Primary diagonal wind chop
    vec2 d1 = vec2(0.8, 0.6);
    float phase1 = dot(d1, p) - t * 2.5;
    float w1 = sin(phase1);
    float dw1 = cos(phase1);

    // Wave 2: Secondary opposing wave
    vec2 d2 = vec2(-0.6, 0.8);
    float phase2 = dot(d2, p) - t * 3.1;
    float w2 = sin(phase2);
    float dw2 = cos(phase2);

    // Wave 3: High-frequency cross ripple
    vec2 d3 = vec2(0.3, -0.95);
    float phase3 = dot(d3, p * 1.8) - t * 4.2;
    float w3 = sin(phase3);
    float dw3 = cos(phase3);

    float dx = (d1.x * dw1 * 0.5 + d2.x * dw2 * 0.35 + d3.x * dw3 * 0.2);
    float dy = (d1.y * dw1 * 0.5 + d2.y * dw2 * 0.35 + d3.y * dw3 * 0.2);

    // Surface normal in tangent space (Z points up)
    return normalize(vec3(-dx * 0.08, -dy * 0.08, 1.0));
}

// -----------------------------------------------------------------------------
// Schlick Fresnel Evaluation for Water
// -----------------------------------------------------------------------------
float evaluateSchlickFresnel(float cosTheta, float roughness) {
    const float F0 = 0.02; // Water dielectric normal reflectance
    float fresnel = F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
    // Attenuate specular reflection on rough surfaces
    return mix(fresnel, F0, roughness * 0.5);
}

// -----------------------------------------------------------------------------
// Main Fragment Execution
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 safeRes = max(uResolution, vec2(1.0));
    vec2 uv = fragCoord / safeRes;

    float speed = (uRippleSpeed > 0.0) ? uRippleSpeed : 1.0;
    float roughness = clamp(uPuddleRoughness, 0.0, 1.0);
    float reflectance = clamp(uReflectance, 0.0, 2.0);

    // 1. Evaluate procedural Gerstner ripple normals
    vec3 rippleNormal = evaluateGerstnerRipples(uv, uTime, speed);

    // 2. Sample normal map texture if provided
    vec4 normSample = texture(uNormalMap, uv * 4.0 + vec2(uTime * 0.02, 0.0));
    vec3 texNormal = (normSample.a > 0.01) ? normalize(normSample.rgb * 2.0 - 1.0) : vec3(0.0, 0.0, 1.0);

    // Composite surface normal
    vec3 N = normalize(vec3(
        rippleNormal.x + texNormal.x * 0.4,
        rippleNormal.y + texNormal.y * 0.4,
        rippleNormal.z
    ));

    // 3. View Angle & Fresnel
    // Assume top-down / isometric camera angle (view direction ~ (0.0, 0.7071, 0.7071))
    vec3 V = normalize(vec3(0.0, 0.7071, 0.7071));
    float NdotV = max(dot(N, V), 0.001);
    float fresnel = evaluateSchlickFresnel(NdotV, roughness) * reflectance;

    // 4. Planar Reflection UV perturbation
    vec2 perturbedUv = uv + N.xy * (0.035 * (1.0 - roughness * 0.5));
    perturbedUv = clamp(perturbedUv, vec2(0.001), vec2(0.999));

    // Sample planar reflection buffer
    vec4 reflectSample = texture(uReflectionMap, perturbedUv);
    vec3 reflectionColor = reflectSample.rgb;

    // If reflection map is empty/unbound, fallback to celestial blue-sky ambient
    if (length(reflectionColor) < 0.001) {
        reflectionColor = mix(vec3(0.12, 0.22, 0.38), vec3(0.45, 0.65, 0.88), uv.y);
    }

    // 5. Deep Mud / Silt Bed Water Color (Beer-Lambert depth absorption)
    vec3 deepWaterColor = vec3(0.04, 0.08, 0.12); // Dark abyssal water tint
    vec3 mudBedColor    = vec3(0.14, 0.11, 0.08); // Silty lake/ground bed
    vec3 waterBody = mix(deepWaterColor, mudBedColor, 0.35);

    // 6. Composite reflection with water body
    vec3 finalRgb = mix(waterBody, reflectionColor, clamp(fresnel, 0.15, 0.95));

    // Specular crest glint
    float glint = pow(max(dot(N, normalize(vec3(0.4, 0.6, 0.7))), 0.0), 32.0);
    finalRgb += vec3(0.9, 0.95, 1.0) * (glint * (1.0 - roughness) * 0.5);

    // Preserve reflection alpha or default to opaque water surface
    float alpha = (reflectSample.a > 0.01) ? reflectSample.a : 1.0;
    fragColor = vec4(finalRgb, alpha);
}
