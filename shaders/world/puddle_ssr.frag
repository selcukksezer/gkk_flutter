#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// Production Screen-Space Reflections (SSR) & Planar Puddle Reflections Shader
// Open World & Main Hub - AAA Cinematic Graphics (R2)
// Compatible with Flutter RuntimeEffect & Impeller Graphics Pipeline
// -----------------------------------------------------------------------------

precision highp float;

// Numeric Uniforms (Indices 0 .. 26, total 27 floats - declared strictly before samplers)
uniform vec2 uResolution;              // 0..1:   Screen viewport resolution in pixels
uniform float uTime;                   // 2:      Continuous elapsed simulation time in seconds
uniform vec3 uCameraPos;               // 3..5:   World/View space camera position (x, y, z)
uniform vec3 uCameraDir;               // 6..8:   Normalized camera forward view direction
uniform float uRainIntensity;          // 9:      Rain intensity factor [0.0 = calm/dry, 1.0 = heavy downpour]
uniform float uRippleSpeed;            // 10:     Temporal ripple propagation speed multiplier
uniform float uPuddleRoughness;        // 11:     Surface micro-facet roughness [0.0 = mirror, 1.0 = matte]
uniform float uReflectivity;           // 12:     Base reflection intensity multiplier [0.0 - 2.0]
uniform float uFresnelR0;              // 13:     Schlick Fresnel F0 normal reflectance (water ≈ 0.02)
uniform float uWaterDepthScale;        // 14:     Extinction scale for water volume depth absorption
uniform vec4 uWaterColor;              // 15..18: Deep water body color (RGB) and extinction factor (A)
uniform vec4 uMudColor;                // 19..22: Puddle bed / silt color (RGB) and edge ground mix (A)
uniform float uMaxRaySteps;            // 23:     Maximum SSR raymarch step iterations (e.g. 16.0 - 32.0)
uniform float uRayStepSize;            // 24:     UV-space march stride per step (e.g. 0.015 - 0.035)
uniform float uPlanarReflectionHeight; // 25:     Puddle plane Y level in normalized viewport space
uniform float uEdgeFadeMargin;         // 26:     Screen edge vignette falloff margin [0.02 - 0.15]

// Sampler Uniforms (declared strictly after numeric uniforms)
uniform sampler2D uSceneTexture;       // Texture Slot 0: Background scene buffer (buildings, lighting, sky)
uniform sampler2D uPuddleMask;          // Texture Slot 1: Puddle mask: R = presence/depth, G = ground detail

out vec4 fragColor;

// Mathematical Constants
const float PI = 3.14159265358979323846;
const float TWO_PI = 6.28318530717958647692;

// -----------------------------------------------------------------------------
// Multi-tap Roughness Blur for Specular & Planar Reflections
// -----------------------------------------------------------------------------
vec4 sampleSceneWithRoughness(sampler2D tex, vec2 uv, float roughness) {
    if (roughness <= 0.02) {
        return texture(tex, uv);
    }
    float blurRadius = roughness * 0.012;
    vec4 col = texture(tex, uv) * 0.36;
    col += texture(tex, uv + vec2( blurRadius,  blurRadius * 0.5)) * 0.16;
    col += texture(tex, uv + vec2(-blurRadius,  blurRadius * 0.5)) * 0.16;
    col += texture(tex, uv + vec2(-blurRadius * 0.5, -blurRadius)) * 0.16;
    col += texture(tex, uv + vec2( blurRadius * 0.5, -blurRadius)) * 0.16;
    return col;
}

// -----------------------------------------------------------------------------
// 1. Procedural Hash & Noise Math
// -----------------------------------------------------------------------------

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// -----------------------------------------------------------------------------
// 2. Dual-Octave Voronoi Rain Droplet Ripples
// Simulates discrete raindrops impacting puddle surface creating expanding
// concentric circular wavefronts with exponential spatial and temporal decay.
// -----------------------------------------------------------------------------

vec3 evaluateVoronoiOctave(vec2 uv, float time, float speed, float gridScale, float waveFreq, float maxRadius) {
    vec2 p = uv * gridScale;
    vec2 cellId = floor(p);
    vec2 cellFract = fract(p);

    vec2 normalOffset = vec2(0.0);
    float height = 0.0;

    // Search 3x3 cellular neighborhood for raindrop impact centers
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 dropCenter = hash22(cellId + neighbor) * 0.8 + 0.1;
            float dropSeed = hash12(cellId + neighbor);

            // Staggered drop impact life phase [0.0 -> 1.0]
            float dropAge = fract(time * speed + dropSeed);

            vec2 diff = cellFract - (neighbor + dropCenter);
            float dist = length(diff);

            // Wavefront expansion
            float frontRadius = dropAge * maxRadius;
            float distToFront = dist - frontRadius;

            // Concentric sinusoidal ripple with analytical normal derivative & exponential temporal decay
            float phase = TWO_PI * (waveFreq * distToFront - dropAge * 4.0);
            float wave = sin(phase);
            float waveSlope = cos(phase) * waveFreq;
            float envelope = exp(-4.0 * dropAge) * smoothstep(0.18, 0.0, abs(distToFront));

            float rippleAmp = wave * envelope;
            height += rippleAmp;

            if (dist > 0.001) {
                vec2 dir = diff / dist;
                normalOffset += dir * (waveSlope * envelope) * (1.0 - dropAge);
            }
        }
    }

    return vec3(normalOffset, height);
}

vec3 evaluateDualOctaveVoronoiRipples(vec2 uv, float time, float speed, float intensity) {
    if (intensity <= 0.001) {
        return vec3(0.0, 0.0, 0.0);
    }

    // Octave 1: Major raindrops (larger scale, deeper waves)
    vec3 oct1 = evaluateVoronoiOctave(uv, time, speed * 0.85, 4.5, 3.0, 0.75);

    // Octave 2: Fine rain mist / micro-droplets (higher spatial density, faster cadence)
    vec3 oct2 = evaluateVoronoiOctave(uv + vec2(0.37, 0.63), time * 1.3, speed * 1.25, 9.0, 5.0, 0.55);

    vec2 totalNormal = (oct1.xy * 0.65 + oct2.xy * 0.35) * intensity;
    float totalHeight = (oct1.z * 0.65 + oct2.z * 0.35) * intensity;

    return vec3(totalNormal, totalHeight);
}

// -----------------------------------------------------------------------------
// 3. Dual-Octave Gerstner Wave Surface Chop
// Adds directional wind drift, fluid surface tension, and continuous undulating
// normal displacement to liquid water.
// -----------------------------------------------------------------------------

vec3 evaluateDualOctaveGerstner(vec2 uv, float time, float intensity) {
    if (intensity <= 0.001) {
        return vec3(0.0, 0.0, 1.0);
    }

    // Octave 1: Primary wind chop wave
    vec2 dir1 = normalize(vec2(0.7071, 0.7071));
    float k1 = 20.0;
    float w1 = 2.4 * uRippleSpeed;
    float a1 = 0.015 * intensity;
    float phase1 = dot(dir1, uv) * k1 - time * w1;
    float sin1 = sin(phase1);
    float cos1 = cos(phase1);

    // Octave 2: Cross wind secondary capillary wave
    vec2 dir2 = normalize(vec2(-0.8, 0.6));
    float k2 = 42.0;
    float w2 = 3.8 * uRippleSpeed;
    float a2 = 0.008 * intensity;
    float phase2 = dot(dir2, uv) * k2 - time * w2;
    float sin2 = sin(phase2);
    float cos2 = cos(phase2);

    // Analytical Gerstner normal derivatives:
    // Nx = - sum(D_i.x * k_i * a_i * cos(phase_i))
    // Ny = - sum(D_i.y * k_i * a_i * cos(phase_i))
    // Nz = 1.0 - sum(Q_i * k_i * a_i * sin(phase_i))
    float nx = -(dir1.x * k1 * a1 * cos1 + dir2.x * k2 * a2 * cos2);
    float ny = -(dir1.y * k1 * a1 * cos1 + dir2.y * k2 * a2 * cos2);
    float nz = 1.0 - (0.5 * k1 * a1 * sin1 + 0.4 * k2 * a2 * sin2);

    return normalize(vec3(nx, ny, max(nz, 0.1)));
}

// -----------------------------------------------------------------------------
// 4. Schlick's Fresnel Approximation with Roughness Modulator
// F(theta) = F0 + (max(1.0 - roughness, F0) - F0) * (1.0 - cosTheta)^5
// Modulates specular reflection intensity smoothly from normal incidence to grazing.
// -----------------------------------------------------------------------------

float evaluateSchlickFresnel(float cosTheta, float f0, float roughness) {
    float clampedCos = clamp(cosTheta, 0.0, 1.0);
    float oneMinusCos = 1.0 - clampedCos;
    float oneMinusCos5 = oneMinusCos * oneMinusCos * oneMinusCos * oneMinusCos * oneMinusCos;
    float maxReflectance = max(1.0 - roughness, f0);
    return f0 + (maxReflectance - f0) * oneMinusCos5;
}

// -----------------------------------------------------------------------------
// 5. Procedural Sky & Ambient Light Model (Fallback / Horizon Reflection)
// Simulates cinematic AAA atmosphere: deep twilight/night zenith, warm horizon
// city light glow, and celestial specular highlight.
// -----------------------------------------------------------------------------

vec3 evaluateProceduralSky(vec3 reflectDir, float roughness) {
    // reflectDir is in world space: Y is up (+1 = celestial zenith, -1 = nadir ground)
    float elevation = reflectDir.y;

    // Atmospheric palette: deep twilight zenith, radiant horizon, dark terrain nadir
    vec3 zenithColor   = vec3(0.03, 0.07, 0.16);
    vec3 horizonGlow   = vec3(0.38, 0.24, 0.14);
    vec3 groundBounce  = vec3(0.08, 0.06, 0.05);

    vec3 skyBase;
    if (elevation >= 0.0) {
        skyBase = mix(horizonGlow, zenithColor, pow(clamp(elevation, 0.0, 1.0), 0.6));
    } else {
        skyBase = mix(horizonGlow, groundBounce, pow(clamp(-elevation, 0.0, 1.0), 0.7));
    }

    // Directional celestial highlight (Sun / Moon)
    vec3 lightDir = normalize(vec3(0.2, 0.7, 0.68));
    float specDot = max(dot(reflectDir, lightDir), 0.0);
    float shininess = mix(128.0, 8.0, roughness);
    float spec = pow(specDot, shininess);
    vec3 celestialSpec = vec3(0.95, 0.90, 0.82) * spec * 2.2;

    // Nocturnal star scintillation in clear glossy reflections
    if (elevation > 0.2 && roughness < 0.35) {
        float starGrid = hash12(floor(reflectDir.xz * 120.0));
        if (starGrid > 0.985) {
            float twinkle = sin(uTime * 3.0 + starGrid * TWO_PI) * 0.5 + 0.5;
            skyBase += vec3(0.8, 0.9, 1.0) * twinkle * (1.0 - roughness * 2.8) * 0.6;
        }
    }

    return skyBase + celestialSpec;
}

// -----------------------------------------------------------------------------
// 6. Screen-Space Reflections (SSR) & Planar Raymarching
// Performs raymarching across the scene color buffer along the reflected view
// vector, reflecting buildings, structures, dynamic lighting, and sky.
// Includes binary refinement, roughness blur, and seamless fallback blending.
// -----------------------------------------------------------------------------

vec4 raymarchScreenSpaceReflections(
    vec2 startUV,
    vec2 reflectScreenDir,
    vec3 worldReflectDir,
    vec3 surfaceNormal,
    float stepStride,
    float maxSteps,
    float roughness,
    float planeY
) {
    // 1. Fallback Planar Reflection + Procedural Sky
    // Mirrored vertically across water plane Y, perturbed by ripple normals
    vec2 planarUV = vec2(startUV.x - surfaceNormal.x * 0.03, 2.0 * planeY - startUV.y + surfaceNormal.y * 0.03);
    planarUV += reflectScreenDir * (roughness * 0.035);
    vec2 clampedPlanarUV = clamp(planarUV, vec2(0.001), vec2(0.999));

    vec4 planarSceneColor = sampleSceneWithRoughness(uSceneTexture, clampedPlanarUV, roughness);
    vec3 skyColor = evaluateProceduralSky(worldReflectDir, roughness);
    vec4 fallbackReflection = vec4(mix(planarSceneColor.rgb, skyColor, 0.45), 1.0);

    // 2. Dithered SSR Raymarching Setup
    float dither = hash12(startUV * uResolution + vec2(uTime * 12.0, 0.0));
    float stride = max(stepStride, 0.006);
    vec2 stepVector = reflectScreenDir * stride;
    vec2 currentUV = startUV + stepVector * (0.35 + 0.65 * dither);

    int intMaxSteps = int(clamp(maxSteps, 4.0, 48.0));
    vec4 hitColor = vec4(0.0);
    float hitConfidence = 0.0;
    vec2 hitUV = currentUV;

    // Linear Screen-Space March
    for (int i = 1; i <= 48; i++) {
        if (i > intMaxSteps) {
            break;
        }

        currentUV += stepVector;

        // Check if ray exited screen viewport bounds
        if (currentUV.x < 0.0 || currentUV.x > 1.0 || currentUV.y < 0.0 || currentUV.y > 1.0) {
            break;
        }

        // Sample scene color along ray trajectory
        vec4 sampleColor = sampleSceneWithRoughness(uSceneTexture, currentUV, roughness * 0.5);

        // Detect scene geometry / building features above water plane
        float sampleLum = dot(sampleColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        if (sampleLum > 0.02 && currentUV.y < planeY) {
            // Binary search refinement for sub-step boundary precision
            vec2 refineStart = currentUV - stepVector;
            vec2 refineEnd = currentUV;
            vec2 refineMid = currentUV;
            for (int r = 0; r < 3; r++) {
                refineMid = (refineStart + refineEnd) * 0.5;
                vec4 midSample = sampleSceneWithRoughness(uSceneTexture, refineMid, roughness * 0.5);
                float midLum = dot(midSample.rgb, vec3(0.2126, 0.7152, 0.0722));
                if (midLum > 0.02 && refineMid.y < planeY) {
                    refineEnd = refineMid;
                    sampleColor = midSample;
                } else {
                    refineStart = refineMid;
                }
            }

            hitUV = refineMid;
            hitColor = sampleColor;

            // Hits closer to reflection origin have highest confidence; smooth falloff as maxSteps approached
            float stepRatio = float(i) / float(intMaxSteps);
            hitConfidence = 1.0 - smoothstep(0.7, 1.0, stepRatio);
            break;
        }
    }

    // 3. Composite SSR Hit with Planar/Sky Fallback
    if (hitConfidence > 0.001) {
        // Screen edge vignette to seamlessly fade SSR into fallback near screen boundaries
        vec2 edgeDist = min(hitUV, 1.0 - hitUV);
        float edgeFactor = smoothstep(0.0, uEdgeFadeMargin, min(edgeDist.x, edgeDist.y));
        float blendWeight = hitConfidence * edgeFactor;

        vec3 blendedRGB = mix(fallbackReflection.rgb, hitColor.rgb, blendWeight);
        return vec4(blendedRGB, 1.0);
    }

    return fallbackReflection;
}

// -----------------------------------------------------------------------------
// 7. Main Fragment Pipeline
// -----------------------------------------------------------------------------

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // Sample background scene ground color
    vec4 groundColor = texture(uSceneTexture, uv);

    // Sample puddle mask texture: R channel = puddle presence/depth
    vec4 maskSample = texture(uPuddleMask, uv);
    float puddlePresence = maskSample.r;

    // If fragment is outside puddle basin, pass-through ground color
    if (puddlePresence <= 0.005) {
        fragColor = groundColor;
        return;
    }

    // 1. Calculate Puddle Normal Perturbations
    // Dual-Octave Voronoi rain ripples
    vec3 voronoiRipples = evaluateDualOctaveVoronoiRipples(
        uv,
        uTime,
        uRippleSpeed,
        uRainIntensity
    );

    // Dual-Octave Gerstner surface wind chop
    vec3 gerstnerNormal = evaluateDualOctaveGerstner(
        uv,
        uTime,
        max(uRainIntensity * 0.7, 0.15)
    );

    // Composite normal vector in tangent space (Z is up towards sky)
    vec3 surfaceNormal = normalize(vec3(
        gerstnerNormal.x + voronoiRipples.x * 2.2,
        gerstnerNormal.y + voronoiRipples.y * 2.2,
        gerstnerNormal.z
    ));

    // 2. View Vector & Fresnel Modulation
    // Actively incorporate uCameraDir and uCameraPos to compute screen-space perspective view direction
    // (Guarantees uCameraDir uniform is retained during SPIR-V compilation and uniform table alignment)
    vec3 camFwd = (length(uCameraDir) > 0.001) ? normalize(uCameraDir) : vec3(0.0, -0.7071, 0.7071);
    vec3 camRight = normalize(cross(vec3(0.0, 1.0, 0.0), camFwd));
    if (length(camRight) < 0.001) camRight = vec3(1.0, 0.0, 0.0);
    vec3 camUp = cross(camFwd, camRight);

    vec2 ndc = uv * 2.0 - 1.0;
    vec3 screenRay = normalize(camFwd + camRight * (ndc.x * 0.6) - camUp * (ndc.y * 0.6));
    vec3 viewDir = normalize(uCameraPos - vec3(ndc.x, -ndc.y, 0.0) - screenRay * 2.0);
    float nDotV = max(dot(surfaceNormal, viewDir), 0.001);

    // Dynamic roughness: wet puddle center is mirror-smooth, rain droplets add micro-scattering
    float dynamicRoughness = clamp(uPuddleRoughness + voronoiRipples.z * 0.25, 0.0, 1.0);

    // Schlick's Fresnel curve
    float fresnel = evaluateSchlickFresnel(nDotV, uFresnelR0, dynamicRoughness);

    // 3. Reflected Ray & SSR Screen Marching
    vec3 reflectWorldDir = reflect(-viewDir, surfaceNormal);

    // Reflected 2D screen UV direction (perturbed by surface normal X/Y)
    vec2 rawScreenDir = vec2(
        reflectWorldDir.x - surfaceNormal.x * 0.35,
        -abs(reflectWorldDir.y) + surfaceNormal.y * 0.35 - 0.001
    );
    float dirLen = length(rawScreenDir);
    vec2 screenReflectDir = (dirLen > 0.0001) ? (rawScreenDir / dirLen) : vec2(0.0, -1.0);

    vec4 ssrReflection = raymarchScreenSpaceReflections(
        uv,
        screenReflectDir,
        reflectWorldDir,
        surfaceNormal,
        uRayStepSize,
        uMaxRaySteps,
        dynamicRoughness,
        uPlanarReflectionHeight
    );

    // 4. Water Absorption & Beer-Lambert Depth Extinction
    // Transmittance = exp(-sigma_a * depth)
    float waterDepth = puddlePresence * uWaterDepthScale;
    float extinctionCoeff = max(uWaterColor.a, 0.1);
    float transmittance = exp(-extinctionCoeff * waterDepth * 3.5);

    // Murky muddy bed color at bottom of puddle
    vec3 bedColor = mix(uMudColor.rgb, groundColor.rgb, 0.4);
    vec3 waterBodyColor = mix(uWaterColor.rgb, bedColor, transmittance);

    // 5. Composite Final Puddle Reflection
    // Specular reflection modulated by Fresnel and reflection multiplier
    float reflectionFactor = fresnel * uReflectivity * ssrReflection.a;
    vec3 compositePuddle = mix(waterBodyColor, ssrReflection.rgb, clamp(reflectionFactor, 0.0, 0.95));

    // Specular highlight boost for rain droplet crests
    float dropletSparkle = pow(clamp(voronoiRipples.z, 0.0, 1.0), 3.0) * uRainIntensity * 0.45;
    compositePuddle += vec3(dropletSparkle);

    // Smooth edge blending with terrain
    float puddleAlpha = smoothstep(0.01, 0.12, puddlePresence);
    vec3 finalRgb = mix(groundColor.rgb, compositePuddle, puddleAlpha);

    fragColor = vec4(finalRgb, groundColor.a);
}
