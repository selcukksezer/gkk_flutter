#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// AAA Forge Fire & Heat Convection Fragment Shader (2027 Mobile Pipeline)
// Optimized for Mobile TBDR GPUs (Tile-Based Deferred Renderers)
// Impeller & SkSL Compatible Runtime Effect
// -----------------------------------------------------------------------------

// Float & Vector Uniforms (must precede all sampler uniforms in Flutter runtime effects)
uniform vec2 uResolution;         // Viewport resolution in physical pixels [width, height]
uniform float uTime;              // Global animation time in continuous seconds
uniform float uHeatIntensity;     // Dynamic forge heat intensity in [0.0, 1.0]
uniform vec4 uCoreColor;          // Incandescent molten core color (HDR values supported)
uniform vec4 uFlameColor;         // Primary flame radiant color (golden-orange)
uniform vec4 uEmberColor;         // Deep ember/cooling crimson flame edge
uniform float uTurbulence;        // Simplex/curl convective turbulence factor
uniform float uHeightFactor;       // Vertical flame reach multiplier

out vec4 fragColor;

// -----------------------------------------------------------------------------
// Fast 2D Hash & Procedural Gradient Noise for TBDR Performance (Zero texture lookups)
// -----------------------------------------------------------------------------
vec2 hash2(vec2 p) {
    // Periodic coordinate wrapping prevents precision degradation on mobile GPUs over time
    p = mod(p, 289.0);
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float fastNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Quintic Hermite curve for C1-continuous gradients (smooth derivative)
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// 3-Octave Fractal Brownian Motion for rich, detailed licking flame tongues
float flameFbm(vec2 p) {
    float v = 0.50 * fastNoise(p);
    p = p * 2.02 + vec2(1.3, -1.7);
    v += 0.30 * fastNoise(p);
    p = p * 2.15 + vec2(-2.1, 1.4);
    v += 0.20 * fastNoise(p);
    return v;
}

void main() {
    vec2 coord = FlutterFragCoord().xy;

    // Viewport-relative coordinates with division-by-zero protection:
    // x centered in [-aspect, +aspect], y in [0.0 (bottom hearth), 1.0 (top)]
    vec2 res = max(uResolution, vec2(1.0));
    float aspect = res.x / res.y;
    vec2 uv = coord / res;
    float nx = (uv.x - 0.5) * 2.0 * aspect;
    float ny = 1.0 - uv.y; // 0.0 at hearth base, 1.0 at upper chamber

    // Dynamic flame reach based on heat intensity (idle simmer ~0.35, blast forge ~1.05)
    float heat = clamp(uHeatIntensity, 0.0, 1.0);
    float maxReach = (0.35 + 0.65 * heat) * max(uHeightFactor, 0.1);

    // Lateral hearth envelope width (scales with heat)
    float hearthHalfWidth = 1.25 + heat * 0.45;

    // Quick early-out for TBDR mobile tile discard (zero overdraw beyond flame envelope)
    // Envelope threshold placed comfortably beyond the smooth fade distance
    if (ny < -0.05 || ny > maxReach + 0.22 || abs(nx) > (hearthHalfWidth + 0.45)) {
        discard;
    }

    // Dynamic upward convection velocity: higher heat = faster roaring flame
    float speed = 1.8 + heat * 2.4;
    // Cyclic time wrapping to prevent high-value float jitter during long sessions
    float time = mod(uTime * speed, 628.31853);

    // Convective domain warping: turbulent updraft along y
    float turb = max(uTurbulence, 0.0) * (0.8 + 0.6 * heat);
    vec2 flowUv = vec2(nx * 1.8, ny * 2.2);

    // Lateral thermal sway & organic flickering draft (dual harmonics)
    float sway = sin(ny * 6.0 - time * 2.2) * 0.08 * turb;
    float microFlicker = sin(time * 14.0 + nx * 5.0) * 0.03 * (0.4 + heat * 0.6)
                       + cos(time * 8.5 - nx * 3.7) * 0.02 * turb;
    flowUv.x += sway + microFlicker;
    flowUv.y -= time;

    // Convective curl-like domain warping for authentic licking fire tendrils
    vec2 warpUv = flowUv * 0.85 + vec2(0.7, -time * 0.35);
    vec2 curlWarp = vec2(fastNoise(warpUv), fastNoise(warpUv + vec2(4.3, 2.8)));
    flowUv += curlWarp * (0.22 * turb);

    // Multi-octave flame turbulence
    float n = flameFbm(flowUv);

    // Tapering flame envelope: parabolic base hearth narrowing to sharp fire tips
    float taper = 1.0 - smoothstep(0.0, maxReach, ny);
    float lateralDist = abs(nx) / max(0.001, taper * (0.85 + heat * 0.35));
    float flameBody = 1.0 - lateralDist;

    // Add turbulent noise to the flame boundary
    float flameEnergy = flameBody + n * 0.55 * (0.7 + heat * 0.6);

    // Vertical falloff towards flame apex
    flameEnergy *= smoothstep(maxReach + 0.08, 0.02, ny);

    // Bottom hearth coal radiance (glowing coal bed at ny = 0)
    float hearthGlow = exp(-ny * (4.5 - heat * 2.0)) * exp(-nx * nx * 1.5) * (0.5 + heat * 0.7);
    flameEnergy = max(flameEnergy, hearthGlow);

    // Smooth horizontal attenuation preventing any hard edge clipping at the hearth boundary
    float horizFade = smoothstep(hearthHalfWidth + 0.35, hearthHalfWidth - 0.15, abs(nx));
    flameEnergy *= horizFade;

    if (flameEnergy <= 0.005) {
        discard;
    }

    // Multi-tier blackbody temperature grading across energy density:
    // 1. Ember rim (cool deep crimson / smoky char)
    // 2. Flame body (golden-orange radiant plasma)
    // 3. Superheated core (incandescent molten white/yellow)
    vec4 col = vec4(0.0);

    float coreThreshold = 0.65 - heat * 0.15;
    float midThreshold = 0.28;

    if (flameEnergy > coreThreshold) {
        // Superheated core: blend from flame color into radiant molten core
        float t = clamp((flameEnergy - coreThreshold) / max(0.001, 1.0 - coreThreshold), 0.0, 1.0);
        col = mix(uFlameColor, uCoreColor, t * t);
        // Boost core radiance by heat and HDR energy
        col.rgb *= (1.0 + heat * 0.6);
        if (flameEnergy > 1.0) {
            col.rgb += uCoreColor.rgb * (flameEnergy - 1.0) * 0.7;
        }
    } else if (flameEnergy > midThreshold) {
        // Mid flame body: blend from deep ember crimson to vibrant flame orange
        float t = (flameEnergy - midThreshold) / max(0.001, coreThreshold - midThreshold);
        col = mix(uEmberColor, uFlameColor, smoothstep(0.0, 1.0, t));
    } else {
        // Outer cooler ember envelope: decaying into subtle dark smoky char
        float t = clamp(flameEnergy / max(0.001, midThreshold), 0.0, 1.0);
        vec3 smokeColor = uEmberColor.rgb * 0.25;
        col.rgb = mix(smokeColor, uEmberColor.rgb, smoothstep(0.0, 0.7, t));
        col.a = uEmberColor.a * t;
    }

    // Alpha modulated by height, energy, and horizontal falloff
    float alpha = clamp(flameEnergy * 1.3, 0.0, 1.0) * col.a;
    // Fade out smoothly at ground border and top boundary
    alpha *= smoothstep(-0.02, 0.04, ny);
    alpha *= smoothstep(maxReach + 0.12, maxReach - 0.1, ny);
    alpha *= horizFade;

    // Premultiplied alpha output for Flutter Canvas compositing
    fragColor = vec4(col.rgb * alpha, alpha);
}
