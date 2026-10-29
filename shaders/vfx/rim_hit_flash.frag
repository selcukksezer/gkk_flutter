#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// -----------------------------------------------------------------------------
// Production AAA Combat VFX: Rim-Light Hit Flash & Emissive Silhouette
//
// Features:
// 1. View-angle dot normal Fresnel rim with sharp exponential falloff
// 2. Instantaneous onset on damage event with exponential decay envelope
// 3. Silhouette edge bleed (gradient & 8-tap alpha neighborhood dilation)
// 4. Overbright bloom luminance multiplier for downstream HDR bloom passes
// 5. Customizable tint colors (white flash, blood red, magical cyan, etc.)
// -----------------------------------------------------------------------------

// Uniforms: All scalar and vector uniforms must be declared before samplers
uniform vec2  uResolution;          // Viewport or sprite size (width, height)
uniform float uIntensity;            // Active flash envelope intensity [0.0, 1.0]
uniform vec3  uTintColor;            // Linear RGB tint (e.g. white, blood red, cyan)
uniform float uRimPower;             // Fresnel exponential sharpness factor (e.g. 2.0 - 6.0)
uniform float uRimIntensity;         // Fresnel rim strength multiplier (e.g. 1.0 - 4.0)
uniform float uInnerFlash;           // Direct full-body inner emissive factor [0.0, 1.0]
uniform float uEdgeBleedWidth;       // Silhouette edge bleed kernel radius in texels
uniform float uEdgeBleedIntensity;   // Silhouette edge bleed glow strength
uniform float uBloomMultiplier;      // HDR luminance overdrive for post-process bloom
uniform float uNormalMode;           // 0.0 = Sobel gradient, 1.0 = Normal map, 2.0 = Billboard dome

// Samplers
uniform sampler2D uTexture;          // Base character / sprite texture
uniform sampler2D uNormalMap;        // Optional normal map texture

out vec4 fragColor;

// -----------------------------------------------------------------------------
// Shader Entry Point
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / max(uResolution, vec2(1.0));

    // Sample base diffuse texture
    vec4 baseColor = texture(uTexture, uv);

    // If flash is inactive, output pure base color immediately
    if (uIntensity <= 0.0001) {
        fragColor = baseColor;
        return;
    }

    vec2 texel = 1.0 / max(uResolution, vec2(1.0));
    vec2 bleedRadius = texel * max(uEdgeBleedWidth, 0.5);

    // -------------------------------------------------------------------------
    // 1. Silhouette Edge Bleed (8-tap neighborhood sampling)
    // -------------------------------------------------------------------------
    const float kDiag = 0.70710678;
    float sumNeighborAlpha = 0.0;
    sumNeighborAlpha += texture(uTexture, clamp(uv + vec2( bleedRadius.x, 0.0), vec2(0.0), vec2(1.0))).a;
    sumNeighborAlpha += texture(uTexture, clamp(uv + vec2(-bleedRadius.x, 0.0), vec2(0.0), vec2(1.0))).a;
    sumNeighborAlpha += texture(uTexture, clamp(uv + vec2(0.0,  bleedRadius.y), vec2(0.0), vec2(1.0))).a;
    sumNeighborAlpha += texture(uTexture, clamp(uv + vec2(0.0, -bleedRadius.y), vec2(0.0), vec2(1.0))).a;
    sumNeighborAlpha += texture(uTexture, clamp(uv + vec2( bleedRadius.x * kDiag,  bleedRadius.y * kDiag), vec2(0.0), vec2(1.0))).a;
    sumNeighborAlpha += texture(uTexture, clamp(uv + vec2(-bleedRadius.x * kDiag,  bleedRadius.y * kDiag), vec2(0.0), vec2(1.0))).a;
    sumNeighborAlpha += texture(uTexture, clamp(uv + vec2( bleedRadius.x * kDiag, -bleedRadius.y * kDiag), vec2(0.0), vec2(1.0))).a;
    sumNeighborAlpha += texture(uTexture, clamp(uv + vec2(-bleedRadius.x * kDiag, -bleedRadius.y * kDiag), vec2(0.0), vec2(1.0))).a;
    float avgNeighborAlpha = sumNeighborAlpha * 0.125;

    // Edge difference: high at silhouette transitions
    float edgeFactor = abs(baseColor.a - avgNeighborAlpha) * uEdgeBleedIntensity;

    // Outer silhouette bleed: glows outward into transparent boundary
    float outerBleed = clamp(avgNeighborAlpha * (1.0 - baseColor.a) * uEdgeBleedIntensity, 0.0, 1.0);

    // If completely outside the sprite and beyond edge bleed threshold, discard flash
    if (baseColor.a <= 0.001 && outerBleed <= 0.001) {
        fragColor = baseColor;
        return;
    }

    // -------------------------------------------------------------------------
    // 2. Normal Estimation (Mode 0: Gradient Sobel, Mode 1: Map, Mode 2: Dome)
    // -------------------------------------------------------------------------
    vec3 N;
    if (uNormalMode < 0.5) {
        // Mode 0: Analytical edge gradient from alpha & luminance
        vec4 sLeft  = texture(uTexture, clamp(uv - vec2(texel.x * 1.5, 0.0), vec2(0.0), vec2(1.0)));
        vec4 sRight = texture(uTexture, clamp(uv + vec2(texel.x * 1.5, 0.0), vec2(0.0), vec2(1.0)));
        vec4 sDown  = texture(uTexture, clamp(uv - vec2(0.0, texel.y * 1.5), vec2(0.0), vec2(1.0)));
        vec4 sUp    = texture(uTexture, clamp(uv + vec2(0.0, texel.y * 1.5), vec2(0.0), vec2(1.0)));

        // Combine alpha gradient with luminance gradient for internal contours & opaque cards
        float lumL = dot(sLeft.rgb,  vec3(0.299, 0.587, 0.114));
        float lumR = dot(sRight.rgb, vec3(0.299, 0.587, 0.114));
        float lumD = dot(sDown.rgb,  vec3(0.299, 0.587, 0.114));
        float lumU = dot(sUp.rgb,    vec3(0.299, 0.587, 0.114));

        vec2 gradAlpha = vec2(sRight.a - sLeft.a, sUp.a - sDown.a);
        vec2 gradLum   = vec2(lumR - lumL, lumU - lumD);
        vec2 grad = gradAlpha * 2.5 + gradLum * 0.8;
        float zDepth = clamp(baseColor.a, 0.25, 1.0);
        N = normalize(vec3(-grad.x * 3.0, -grad.y * 3.0, zDepth));
    } else if (uNormalMode < 1.5) {
        // Mode 1: Tangent-space normal map with NaN protection
        vec3 nSample = texture(uNormalMap, uv).xyz * 2.0 - 1.0;
        float len = length(nSample);
        N = (len > 0.001) ? normalize(vec3(nSample.xy, max(nSample.z, 0.05))) : vec3(0.0, 0.0, 1.0);
    } else {
        // Mode 2: Billboard analytical spherical dome normal
        vec2 p = (uv - vec2(0.5)) * 2.0;
        float rSq = dot(p, p);
        float z = sqrt(max(0.0, 1.0 - clamp(rSq, 0.0, 1.0)));
        N = normalize(vec3(p.x, -p.y, max(z, 0.1)));
    }

    // View vector pointing out of screen towards viewer in tangent/view space
    vec3 V = vec3(0.0, 0.0, 1.0);

    // -------------------------------------------------------------------------
    // 3. View-Angle Dot Normal & Exponential Fresnel Rim Falloff
    // -------------------------------------------------------------------------
    float NdotV = clamp(dot(N, V), 0.0, 1.0);
    float grazing = clamp(1.0 - NdotV, 0.0, 1.0);
    float fresnel = pow(grazing, max(uRimPower, 0.01)) * uRimIntensity;

    // -------------------------------------------------------------------------
    // 4. Emissive Silhouette Composition with Bloom Overdrive
    // -------------------------------------------------------------------------
    // Inner body flash (uniform damage illumination across silhouette)
    float innerFlash = baseColor.a * uInnerFlash;

    // Combined emissive highlight factor
    float highlightFactor = (fresnel * baseColor.a + edgeFactor + innerFlash) * uIntensity;

    // Emissive color multiplied by HDR bloom multiplier
    vec3 emissive = uTintColor * highlightFactor * uBloomMultiplier;

    // Composite: Additive glow onto diffuse base
    vec3 outRgb = baseColor.rgb + emissive;
    float outAlpha = clamp(baseColor.a + outerBleed * uIntensity, 0.0, 1.0);

    fragColor = vec4(outRgb, outAlpha);
}
