#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// Production GLSL 460 Fragment Shader: Dungeon Lighting & Dynamic Shadows
// 2027 Cinematic AAA Graphics Pipeline (R3 Dark Fantasy Standard)
//
// Features:
// 1. Multi-light accumulation (up to 8 dynamic lights, bounded by uLightCount)
// 2. Multi-model falloff (windowed inverse-square, smoothstep, linear)
// 3. Procedural torch micro-flicker and chromatic aura (fire, rune, soul, explosion)
// 4. Dynamic pseudo-3D shadow penumbra falloff and cavity AO modulation
// 5. Blinn-Phong specular glints with normal reconstruction
// 6. Filmic ACES tonemapping and gamma 2.2 correction
// 7. Strictly packed 109-float uniform buffer matching DungeonLightSystem
// -----------------------------------------------------------------------------

precision highp float;

// -----------------------------------------------------------------------------
// Uniform Declarations (Exact 109-Float Layout matching dungeon_light_system.dart)
// -----------------------------------------------------------------------------
// Global Uniforms: [0..12] = 13 floats
uniform vec2 uResolution;             // [0..1]   Viewport width, height (pixels)
uniform float uTime;                  // [2]      Elapsed simulation time (seconds)
uniform vec3 uAmbientColor;           // [3..5]   Abyssal ambient color RGB
uniform float uAmbientIntensity;      // [6]      Ambient intensity multiplier
uniform float uLightCount;            // [7]      Active light count in buffer [0..8]
uniform float uAoModulation;          // [8]      Cavity AO darkening strength
uniform float uShadowSoftness;        // [9]      Shadow penumbra softness scale
uniform vec3 uCameraPos;              // [10..12] Camera world position for specular highlights

// Per-Light Array Uniforms: 3 * 32 = 96 floats
// Total floats: 13 + 96 = 109 floats
uniform vec4 uLightPosRadius[8];      // [13..44]  (x, y, z, radius) per light
uniform vec4 uLightColorIntensity[8]; // [45..76]  (r, g, b, intensity) per light
uniform vec4 uLightParams[8];         // [77..108] (lightType, falloffType, shadowHardness, specularPower)

// Sampler Uniform (Must be declared strictly after all numeric uniforms)
uniform sampler2D uTexture;

out vec4 fragColor;

// Constants
const int MAX_LIGHTS = 8;
const float PI = 3.14159265359;

// -----------------------------------------------------------------------------
// Attenuation Calculations
// -----------------------------------------------------------------------------

// Unreal Engine 4/5 windowed inverse-square attenuation
// att = [(1 - (d/r)^4)^2] / (d^2 + 1)
float computeWindowedInverseSquare(float dist, float radius) {
    if (dist >= radius || radius <= 0.0001) return 0.0;
    float norm = dist / radius;
    float norm4 = norm * norm * norm * norm;
    float window = clamp(1.0 - norm4, 0.0, 1.0);
    return (window * window) / (dist * dist + 1.0);
}

// Hermite cubic smoothstep falloff: (1 - 3t^2 + 2t^3) / (d + 1)
float computeSmoothstepFalloff(float dist, float radius) {
    if (dist >= radius || radius <= 0.0001) return 0.0;
    float t = clamp(dist / radius, 0.0, 1.0);
    float smoothCutoff = 1.0 - t * t * (3.0 - 2.0 * t);
    return smoothCutoff / (dist + 1.0);
}

// Fast artistic linear falloff: clamp(1 - d/r, 0, 1)
float computeLinearFalloff(float dist, float radius) {
    if (dist >= radius || radius <= 0.0001) return 0.0;
    return clamp(1.0 - (dist / radius), 0.0, 1.0);
}

// Evaluates falloff based on light's falloffType parameter
float evaluateFalloff(float dist, float radius, float falloffType) {
    if (falloffType > 1.5) {
        return computeLinearFalloff(dist, radius);
    } else if (falloffType > 0.5) {
        return computeSmoothstepFalloff(dist, radius);
    } else {
        return computeWindowedInverseSquare(dist, radius);
    }
}

// -----------------------------------------------------------------------------
// Pseudo-3D Shadow Penumbra Attenuation
// -----------------------------------------------------------------------------
float evaluateShadowAttenuation(
    vec3 fragPos,
    vec3 lightPos,
    float lightRadius,
    float shadowHardness,
    float shadowSoftness
) {
    if (shadowHardness <= 0.001) return 1.0;

    float distToLight = length(fragPos - lightPos);
    if (distToLight >= lightRadius) return 0.0;

    float penumbraScale = max(0.1, shadowSoftness * (1.0 - shadowHardness * 0.7));
    float softShadow = (1.0 - shadowHardness) + shadowHardness * 1.0;

    float depthDiff = max(0.0, fragPos.z - lightPos.z);
    float depthShadow = exp(-depthDiff * 0.15 * shadowHardness);

    float radiusFactor = clamp(1.0 - (distToLight / max(lightRadius, 0.0001)), 0.0, 1.0);
    float clampedNorm = clamp(radiusFactor / penumbraScale, 0.0, 1.0);
    float penumbraMod = clampedNorm * clampedNorm * (3.0 - 2.0 * clampedNorm);

    return clamp(softShadow * depthShadow * penumbraMod, 0.0, 1.0);
}

// -----------------------------------------------------------------------------
// ACES Filmic Tonemapping (Krzysztof Narkowicz fit)
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
// Main Shader Body
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    if (uResolution.x <= 0.0 || uResolution.y <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 uv = fragCoord / uResolution;
    vec4 texSample = texture(uTexture, uv);

    // Alpha cutout check
    if (texSample.a <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // Convert sRGB albedo to linear space
    vec3 albedoLinear = pow(max(texSample.rgb, vec3(0.0)), vec3(2.2));
    float lum = dot(albedoLinear, vec3(0.2126, 0.7152, 0.0722));

    // Surface normal & cavity estimation via 4-tap local cross filter
    vec2 texel = 1.0 / uResolution;
    float lumL = dot(pow(max(texture(uTexture, uv - vec2(texel.x, 0.0)).rgb, vec3(0.0)), vec3(2.2)), vec3(0.2126, 0.7152, 0.0722));
    float lumR = dot(pow(max(texture(uTexture, uv + vec2(texel.x, 0.0)).rgb, vec3(0.0)), vec3(2.2)), vec3(0.2126, 0.7152, 0.0722));
    float lumD = dot(pow(max(texture(uTexture, uv - vec2(0.0, texel.y)).rgb, vec3(0.0)), vec3(2.2)), vec3(0.2126, 0.7152, 0.0722));
    float lumU = dot(pow(max(texture(uTexture, uv + vec2(0.0, texel.y)).rgb, vec3(0.0)), vec3(2.2)), vec3(0.2126, 0.7152, 0.0722));

    vec3 normal = normalize(vec3((lumL - lumR) * 2.0, (lumD - lumU) * 2.0, 1.0));
    float localAvg = (lumL + lumR + lumD + lumU) * 0.25;
    float cavity = clamp(1.0 + (lum - localAvg) * 1.5, 0.0, 1.0);

    // Cavity Ambient Occlusion modulation
    float aoRaw = clamp(lum * 0.8 + cavity * 0.2, 0.0, 1.0);
    float aoPower = 1.0 + 1.2 * clamp(uAoModulation, 0.0, 1.0);
    float ambientAoMod = pow(aoRaw, aoPower);
    if (cavity < 1.0) {
        float cavityBlend = 1.0 + (cavity - 1.0) * clamp(uAoModulation * 0.7, 0.0, 1.0);
        ambientAoMod *= cavityBlend;
    }
    ambientAoMod = clamp(ambientAoMod, 0.0, 1.0);

    // Global Ambient Term
    vec3 ambient = uAmbientColor * (uAmbientIntensity * ambientAoMod);

    // Fragment position in 2.5D space (surface height at z = 0.0)
    vec3 fragPos = vec3(fragCoord.xy, 0.0);
    vec3 viewVec = uCameraPos - fragPos;
    vec3 viewDir = length(viewVec) > 0.0001 ? normalize(viewVec) : vec3(0.0, 0.0, 1.0);

    // Multi-Light Accumulation
    vec3 totalDiffuse = vec3(0.0);
    vec3 totalSpecular = vec3(0.0);
    int activeLights = int(clamp(uLightCount, 0.0, float(MAX_LIGHTS)));

    for (int i = 0; i < MAX_LIGHTS; ++i) {
        if (i >= activeLights) break;

        vec4 posRad = uLightPosRadius[i];
        vec4 colInt = uLightColorIntensity[i];
        vec4 params = uLightParams[i];

        vec3 lightPos = posRad.xyz;
        float lightRadius = posRad.w;
        vec3 lightColor = colInt.rgb;
        float lightIntensity = colInt.a;

        float lightType = params.x;
        float falloffType = params.y;
        float shadowHardness = params.z;
        float specularPower = max(params.w, 1.0);

        vec3 lightVec = lightPos - fragPos;
        float dist = length(lightVec);

        if (dist >= lightRadius || lightRadius <= 0.001 || lightIntensity <= 0.0001) {
            continue;
        }

        vec3 lightDir = lightVec / max(dist, 0.0001);

        // Falloff
        float falloff = evaluateFalloff(dist, lightRadius, falloffType);
        if (falloff <= 0.00001) continue;

        // Specialized Light Type Modulation & Chromatic Auras
        if (lightType < 0.5) {
            // Torch (Type 0.0): Procedural micro-flicker & warm amber aura gradient
            float microFlicker = 1.0 + 0.05 * sin(uTime * 14.3 + lightPos.x * 0.1)
                                     + 0.03 * cos(uTime * 23.7 + lightPos.y * 0.1);
            falloff *= microFlicker;

            float auraNorm = clamp(dist / lightRadius, 0.0, 1.0);
            vec3 torchAura = mix(vec3(1.0, 0.95, 0.7), vec3(1.0, 0.45, 0.1), auraNorm);
            lightColor = mix(lightColor, lightColor * torchAura, 0.35);
        } else if (lightType < 1.5) {
            // Pulsing Rune (Type 1.0): Chromatic dispersion aura shift to cyan rim
            float runePulse = sin(uTime * 2.5 + lightPos.x * 0.05) * 0.5 + 0.5;
            vec3 cyanRim = vec3(0.0, 0.9, 1.0);
            float rimFactor = pow(clamp(dist / lightRadius, 0.0, 1.0), 1.5);
            lightColor = mix(lightColor, cyanRim, rimFactor * 0.55 * (0.7 + 0.3 * runePulse));
        } else if (lightType < 2.5) {
            // Fiery Explosion (Type 2.0): Thermal blackbody flare gradient
            float expDist = clamp(dist / lightRadius, 0.0, 1.0);
            vec3 thermalAura = mix(vec3(1.0, 0.92, 0.65), vec3(1.0, 0.28, 0.05), expDist * expDist);
            lightColor = mix(lightColor, thermalAura, 0.45);
        } else if (lightType < 3.5) {
            // Ethereal Soul (Type 3.0): Phantom shimmer & spectral luminosity
            float shimmer = 1.0 + 0.10 * sin(uTime * 4.2 + dist * 0.15)
                                 + 0.06 * cos(uTime * 7.1 + lightPos.y * 0.05);
            falloff *= shimmer;
        } else if (lightType < 4.5) {
            // Standard Point Light (Type 4.0): Omnidirectional inverse falloff without aura tinting
        } else {
            // Directional Spot Light (Type 5.0): Downward conic beam towards dungeon floor
            vec3 spotDir = vec3(0.0, 0.0, -1.0);
            float cosTheta = dot(-lightDir, spotDir);
            float spotCutoff = 0.7071; // ~45 degree inner cone
            float spotFeather = 0.5;   // ~60 degree outer cutoff
            float spotAtten = smoothstep(spotFeather, spotCutoff, cosTheta);
            falloff *= spotAtten;
        }

        // Pseudo-3D Dynamic Shadow Penumbra
        float shadowAtten = evaluateShadowAttenuation(
            fragPos,
            lightPos,
            lightRadius,
            shadowHardness,
            uShadowSoftness
        );

        // Cavity Direct AO dampening
        float directAo = 1.0 - (1.0 - aoRaw) * clamp(uAoModulation * 0.4, 0.0, 1.0);

        // Lambertian Diffuse
        float nDotL = max(dot(normal, lightDir), 0.0);

        // Blinn-Phong Specular
        vec3 h = lightDir + viewDir;
        float hLen = length(h);
        vec3 halfDir = hLen > 0.0001 ? (h / hLen) : normal;
        float nDotH = max(dot(normal, halfDir), 0.0);
        float spec = pow(max(nDotH, 0.0), specularPower);

        // Combined Light Radiance
        float flux = falloff * lightIntensity * shadowAtten * directAo;
        totalDiffuse += lightColor * (nDotL * flux);
        totalSpecular += lightColor * (spec * flux * 0.3);
    }

    // Compose final lit color in linear HDR space
    vec3 litLinear = albedoLinear * (ambient + totalDiffuse) + totalSpecular;

    // ACES Filmic Tonemapping
    vec3 tonemapped = acesTonemap(litLinear);

    // Gamma correction to sRGB (gamma 2.2)
    vec3 finalRgb = pow(tonemapped, vec3(1.0 / 2.2));

    fragColor = vec4(finalRgb, texSample.a);
}
