#version 460 core
#include <flutter/runtime_effect.glsl>

// =============================================================================
// Production Vertex Animated Texture (VAT) & 8-Angle Impostor Crowd Fragment Shader
// Target: 10,000 Distant Entities in a Single Draw Call (Flutter / Impeller / 3D Pipeline)
// Architecture: R4 Crowd Rendering Pipeline
// =============================================================================

precision highp float;

// -----------------------------------------------------------------------------
// Inputs from Vertex Shader / Raster Stage
// -----------------------------------------------------------------------------
in vec2 vTexCoords;
in vec3 vWorldNormal;
in vec3 vWorldPos;
in vec4 vInstanceTint;
in float vRenderMode;
in float vDistanceToCamera;

// -----------------------------------------------------------------------------
// Float & Vector Uniforms (Indices 0 .. 14, total 15 floats)
// STRICT: Must be declared before any sampler2D uniforms for Impeller compliance.
// Exact 15-Float Layout matching ShaderRegistry (vatCrowdFrag)
// -----------------------------------------------------------------------------
uniform vec3 uLightDir;           // 0..2:  Normalized world direction towards primary light source
uniform vec3 uLightColor;         // 3..5:  Primary light color & intensity
uniform vec3 uAmbientColor;       // 6..8:  Sky/ground ambient hemisphere color
uniform vec3 uFogColor;           // 9..11: Atmospheric distance fog color
uniform float uFogStart;          // 12:    Distance in world units where fog starts
uniform float uFogEnd;            // 13:    Distance in world units where fog reaches 100%
uniform float uAlphaCutoff;       // 14:    Alpha cutoff threshold for billboard cutout (default: 0.5)

// -----------------------------------------------------------------------------
// Texture Samplers (Declared strictly after all numeric uniforms)
// -----------------------------------------------------------------------------
uniform sampler2D uAlbedoMap;     // Slot 0: Base diffuse / albedo texture for VAT mesh
uniform sampler2D uImpostorAtlas; // Slot 1: 8-angle billboard impostor atlas

// Output Fragment Color
out vec4 fragColor;

void main() {
    vec4 baseColor;
    vec3 normal = normalize(vWorldNormal);
    vec3 lightDir = normalize(uLightDir);

    if (vRenderMode < 0.5) {
        // =========================================================================
        // MODE 0: VAT Mesh Shading
        // =========================================================================
        vec4 texColor = texture(uAlbedoMap, vTexCoords);
        baseColor = texColor * vInstanceTint;

        // Half-Lambert wrapped diffuse lighting for soft cinematic shading on crowd
        float nDotL = max(dot(normal, lightDir), 0.0);
        float wrappedDiffuse = pow(nDotL * 0.5 + 0.5, 1.5);
        vec3 litColor = baseColor.rgb * (uAmbientColor + uLightColor * wrappedDiffuse);

        baseColor = vec4(litColor, baseColor.a);
    } else {
        // =========================================================================
        // MODE 1: 8-Angle Billboard Impostor Shading
        // =========================================================================
        vec4 atlasSample = texture(uImpostorAtlas, vTexCoords);

        // Alpha discard for billboard cutout edges
        float cutoff = (uAlphaCutoff > 0.0) ? uAlphaCutoff : 0.5;
        if (atlasSample.a < cutoff) {
            discard;
        }

        // Apply instance tint and ambient/directional lighting to billboard
        vec4 impostorBase = atlasSample * vInstanceTint;
        float nDotL = max(dot(normal, lightDir), 0.0);
        float diff = max(nDotL, 0.35); // Soft clamp for billboard front-facing quads
        vec3 litColor = impostorBase.rgb * (uAmbientColor + uLightColor * diff);

        baseColor = vec4(litColor, impostorBase.a);
    }

    // =============================================================================
    // Atmospheric Distance Fog Blend (R2 / R4 Cinematic Atmosphere)
    // =============================================================================
    float fogStart = (uFogEnd > uFogStart) ? uFogStart : 50.0;
    float fogEnd = (uFogEnd > uFogStart) ? uFogEnd : 300.0;
    float rawFog = clamp((vDistanceToCamera - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
    // Smoothstep for realistic non-linear atmospheric haze
    float fogFactor = rawFog * rawFog * (3.0 - 2.0 * rawFog);

    vec3 finalRgb = mix(baseColor.rgb, uFogColor, fogFactor);
    fragColor = vec4(finalRgb, baseColor.a);
}
