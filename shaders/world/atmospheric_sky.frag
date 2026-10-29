#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// -----------------------------------------------------------------------------
// Production AAA Dynamic Procedural Skybox & Atmospheric Scattering Shader
// 2027 Cinematic Graphics Pipeline (R2 Open World Standard)
//
// Features:
// 1. Physically-based Rayleigh scattering (wavelength-dependent blue sky).
// 2. Mie forward-scattering haze around Sun and Moon (Henyey-Greenstein phase).
// 3. Dynamic multi-phase celestial orbit (Dawn, Noon, Dusk, Midnight).
// 4. Photorealistic Sun disk with limb darkening and atmospheric extinction.
// 5. High-fidelity Moon disk with cratering and lunar halo.
// 6. Dark Fantasy Astral Midnight: procedural starfield with scintillation +
//    multi-octave fractal cosmic nebula clouds (magenta / astral cyan).
// 7. Ground bounce / nadir horizon transition.
// 8. Built-in ACES filmic tonemapping for high-dynamic-range (HDR) radiance.
// -----------------------------------------------------------------------------

// Float & Vector Uniforms (Ordered sequentially for Flutter FragmentProgram)
uniform vec2  uResolution;       // Viewport resolution in pixels (0..1)
uniform float uTime;             // Simulation time in seconds (2)
uniform float uTimeOfDay;        // Normalized diurnal time [0.0, 1.0) (3)
uniform vec3  uSunDirection;     // Normalized sun direction vector (4..6)
uniform vec3  uMoonDirection;    // Normalized moon direction vector (7..9)
uniform vec3  uSunColor;         // Sun linear RGB radiance (10..12)
uniform vec3  uMoonColor;        // Moon linear RGB radiance (13..15)
uniform vec3  uRayleighCoeff;    // Rayleigh scattering coefficients per RGB (16..18)
uniform float uRayleighScale;    // Rayleigh scattering intensity multiplier (19)
uniform float uMieCoeff;         // Mie scattering coefficient (20)
uniform float uMieG;             // Mie forward scattering asymmetry factor g (21)
uniform float uTurbidity;        // Atmospheric turbidity / aerosol haze (22)
uniform vec3  uGroundColor;      // Ground nadir ambient bounce color (23..25)
uniform vec3  uNebulaColor1;     // Dark fantasy nebula primary cosmic hue (26..28)
uniform vec3  uNebulaColor2;     // Dark fantasy nebula secondary cosmic hue (29..31)
uniform float uNebulaIntensity;  // Nebula emission boost multiplier (32)
uniform float uStarIntensity;    // Starfield brightness scalar (33)
uniform vec3  uCameraRotation;   // Pitch, Yaw, Roll in radians (34..36)
uniform float uFov;              // Vertical Field of View in radians (37)
uniform float uExposure;         // Exposure compensation scalar (38)

out vec4 fragColor;

// -----------------------------------------------------------------------------
// Mathematical Constants
// -----------------------------------------------------------------------------
const float PI        = 3.14159265358979323846;
const float TWO_PI    = 6.28318530717958647692;
const float INV_FOUR_PI = 0.07957747154594766788; // 1 / (4 * PI)

// -----------------------------------------------------------------------------
// Fast 3D Simplex / Hash Functions for Stars and Nebula Turbulence
// -----------------------------------------------------------------------------
float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += vec3(dot(p, p.zyx + 31.32));
    return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += vec3(dot(p, p.yxz + 33.33));
    return fract((p.xxy + p.yxx) * p.zyx);
}

// 3D Value Noise for smooth nebula volumetric clouds
float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);

    float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));

    float x00 = mix(n000, n100, u.x);
    float x10 = mix(n010, n110, u.x);
    float x01 = mix(n001, n101, u.x);
    float x11 = mix(n011, n111, u.x);

    float y0 = mix(x00, x10, u.y);
    float y1 = mix(x01, x11, u.y);

    return mix(y0, y1, u.z);
}

// 4-Octave Fractional Brownian Motion (fBm) for deep space nebula
float nebulaFbm(vec3 p) {
    float total = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    mat3 rot = mat3(
         0.00,  0.80,  0.60,
        -0.80,  0.36, -0.48,
        -0.60, -0.48,  0.64
    );

    for (int i = 0; i < 4; i++) {
        total += amplitude * noise3d(p * frequency);
        p = rot * p * 2.02;
        amplitude *= 0.5;
    }
    return total;
}

// -----------------------------------------------------------------------------
// Atmospheric Scattering Phase Functions
// -----------------------------------------------------------------------------
// Rayleigh phase function: Pr(cosTheta) = (3 / 16*PI) * (1 + cosTheta^2)
float rayleighPhase(float cosTheta) {
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

// Henyey-Greenstein Mie phase function:
// Pm(cosTheta, g) = (1 / 4*PI) * (1 - g^2) / (1 + g^2 - 2*g*cosTheta)^(1.5)
float miePhase(float cosTheta, float g) {
    float g2 = g * g;
    float denom = max(1.0 + g2 - 2.0 * g * clamp(cosTheta, -1.0, 1.0), 1e-4);
    return INV_FOUR_PI * (1.0 - g2) / pow(denom, 1.5);
}

// Optical air mass approximation (Kasten-Young model)
float opticalAirMass(float cosZenith) {
    float z = clamp(cosZenith, 0.0, 1.0);
    return 1.0 / (z + 0.15 * pow(93.885 - acos(z) * (180.0 / PI), -1.253));
}

// -----------------------------------------------------------------------------
// Procedural Starfield with Scintillation (Twinkle)
// -----------------------------------------------------------------------------
float renderStars(vec3 rayDir, float time) {
    // Project ray onto high-frequency celestial grid
    vec3 p = rayDir * 280.0;
    vec3 id = floor(p);
    vec3 f = fract(p) - 0.5;

    float starRad = 0.0;
    // Inspect 3x3x3 neighborhood for stable spherical distribution
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 cell = id + vec3(float(x), float(y), float(z));
                vec3 h = hash33(cell);
                // Only a fraction of cells contain visible stars
                if (h.x > 0.88) {
                    vec3 starOffset = vec3(float(x), float(y), float(z)) + (h - 0.5) * 0.8;
                    float dist = length(f - starOffset);
                    // Star size and base brightness
                    float size = 0.03 + 0.07 * h.y;
                    // Twinkle scintillation using sine wave keyed to cell hash
                    float twinkle = 0.7 + 0.3 * sin(time * (2.0 + 5.0 * h.z) + h.y * 30.0);
                    float intensity = smoothstep(size, 0.0, dist) * h.y * twinkle;
                    starRad += intensity;
                }
            }
        }
    }
    return starRad;
}

// -----------------------------------------------------------------------------
// Procedural Dark Fantasy Nebula
// -----------------------------------------------------------------------------
vec3 renderNebula(vec3 rayDir, float time) {
    // Slow temporal cosmic drift
    vec3 drift = vec3(time * 0.005, time * 0.003, -time * 0.004);
    vec3 p = rayDir * 2.5 + drift;

    // Multi-stage domain warped fBm
    float q = nebulaFbm(p);
    vec3 warpedP = p + vec3(q * 1.2, -q * 0.8, q * 1.0);
    float n = nebulaFbm(warpedP * 1.8);

    // Dynamic color gradient mixing primary cosmic purple and astral cyan
    float mask = smoothstep(0.35, 0.82, n);
    float colorBlend = smoothstep(0.4, 0.75, q);
    vec3 nebulaCol = mix(uNebulaColor1, uNebulaColor2, colorBlend);

    // Core filament glow
    float filament = pow(smoothstep(0.45, 0.88, n), 2.5) * 2.0;
    nebulaCol += vec3(filament * 0.5, filament * 0.7, filament * 1.0);

    return nebulaCol * mask;
}

// -----------------------------------------------------------------------------
// Sun and Moon Celestial Disks
// -----------------------------------------------------------------------------
vec3 renderSunDisk(vec3 rayDir, vec3 sunDir, vec3 sunCol, vec3 extinction) {
    float cosTheta = dot(rayDir, sunDir);
    // Angular sun radius ~ 0.012 radians (approx 0.7 degrees)
    const float sunRadius = 0.012;
    float angle = acos(clamp(cosTheta, -1.0, 1.0));

    // Antialiased sharp limb
    float disk = smoothstep(sunRadius * 1.05, sunRadius * 0.95, angle);
    if (disk <= 0.0) return vec3(0.0);

    // Solar limb darkening: center is brighter, edges darken
    float u = 0.6; // Limb darkening coefficient
    float rNorm = angle / sunRadius;
    float mu = sqrt(max(0.0, 1.0 - rNorm * rNorm));
    float limbDarkening = 1.0 - u * (1.0 - mu);

    // High HDR solar radiance filtered by atmospheric extinction
    return sunCol * (25.0 * disk * limbDarkening) * extinction;
}

vec3 renderMoonDisk(vec3 rayDir, vec3 moonDir, vec3 sunDir, vec3 moonCol) {
    float cosTheta = dot(rayDir, moonDir);
    const float moonRadius = 0.011;
    float angle = acos(clamp(cosTheta, -1.0, 1.0));

    // Lunar phase shading based on angle between sun and moon
    float phaseDot = dot(-moonDir, sunDir);
    float phaseTerm = clamp(phaseDot * 0.5 + 0.5, 0.2, 1.0);

    // Ethereal lunar halo glow surrounding the lunar disk
    float haloAngle = angle / (moonRadius * 7.0);
    float halo = exp(-haloAngle * 3.0) * 0.40 * phaseTerm;

    float disk = smoothstep(moonRadius * 1.08, moonRadius * 0.92, angle);
    if (disk <= 0.0) {
        return moonCol * halo;
    }

    // Analytical crater texture perturbation
    vec3 localP = rayDir * 40.0;
    float craters = 0.75 + 0.25 * noise3d(localP);

    vec3 moonSurface = moonCol * (4.5 * disk * craters * phaseTerm);
    return moonSurface + moonCol * halo;
}

// -----------------------------------------------------------------------------
// Camera View Ray Reconstruction
// -----------------------------------------------------------------------------
vec3 getCameraRay(vec2 fragCoord, vec2 resolution, vec3 camRot, float fov) {
    // Screen coords normalized to [-1, 1] keeping square aspect ratio
    float minRes = max(min(resolution.x, resolution.y), 1.0);
    vec2 ndc = (2.0 * fragCoord - resolution) / minRes;
    float clampedFov = clamp(fov, 0.1, 3.0);
    float tanHalfFov = tan(clampedFov * 0.5);

    // Forward is +Z, Right is +X, Up is +Y (OpenGL / Impeller right-handed)
    vec3 rayCam = normalize(vec3(ndc.x * tanHalfFov, -ndc.y * tanHalfFov, 1.0));

    // Pitch (around X), Yaw (around Y), Roll (around Z)
    float cp = cos(camRot.x); float sp = sin(camRot.x);
    float cy = cos(camRot.y); float sy = sin(camRot.y);
    float cr = cos(camRot.z); float sr = sin(camRot.z);

    mat3 pitchMat = mat3(
        1.0, 0.0, 0.0,
        0.0,  cp, -sp,
        0.0,  sp,  cp
    );

    mat3 yawMat = mat3(
         cy, 0.0,  sy,
        0.0, 1.0, 0.0,
        -sy, 0.0,  cy
    );

    mat3 rollMat = mat3(
         cr, -sr, 0.0,
         sr,  cr, 0.0,
        0.0, 0.0, 1.0
    );

    mat3 rotMat = yawMat * pitchMat * rollMat;
    return normalize(rotMat * rayCam);
}

// -----------------------------------------------------------------------------
// Krzysztof Narkowicz ACES Filmic Tonemapping
// -----------------------------------------------------------------------------
vec3 acesTonemap(vec3 x) {
    vec3 v = max(x, vec3(0.0));
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0.0, 1.0);
}

// -----------------------------------------------------------------------------
// Main Fragment Shader
// -----------------------------------------------------------------------------
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // 1. Reconstruct world-space ray direction
    vec3 rayDir = getCameraRay(fragCoord, uResolution, uCameraRotation, uFov);

    // 2. Atmospheric geometric terms
    float cosZenith = clamp(rayDir.y, 0.001, 1.0);
    float sunCosZenith = clamp(uSunDirection.y, -0.2, 1.0);

    // Optical path length (air mass)
    float airMassView = opticalAirMass(cosZenith);
    float airMassSun = opticalAirMass(max(sunCosZenith, 0.001));

    // Scattering phase angles
    float cosSun = dot(rayDir, uSunDirection);
    float cosMoon = dot(rayDir, uMoonDirection);

    float pRayleighSun = rayleighPhase(cosSun);
    float pMieSun = miePhase(cosSun, uMieG);

    float pRayleighMoon = rayleighPhase(cosMoon);
    float pMieMoon = miePhase(cosMoon, uMieG);

    // 3. Scattering coefficients with turbidity
    vec3 betaR = uRayleighCoeff * uRayleighScale;
    vec3 betaM = vec3(uMieCoeff) * uTurbidity;
    vec3 betaExt = betaR + betaM;

    // Transmittance through atmosphere
    vec3 sunTransmittance = exp(-betaExt * (airMassSun * 4.0));
    vec3 viewTransmittance = exp(-betaExt * (airMassView * 4.0));

    // In-scattering factor (1 - exp(-extinction * path)) / extinction
    vec3 inscatterFactor = (vec3(1.0) - viewTransmittance) / max(betaExt, vec3(1e-5));

    // 4. Primary Solar Atmospheric In-Scattering
    vec3 sunPhaseRadiance = (betaR * pRayleighSun + betaM * pMieSun) * uSunColor;
    vec3 sunScattering = sunPhaseRadiance * inscatterFactor * sunTransmittance;

    // 5. Lunar Atmospheric In-Scattering (soft silver night glow)
    float moonElevation = smoothstep(-0.10, 0.15, uMoonDirection.y);
    vec3 moonPhaseRadiance = (betaR * pRayleighMoon + betaM * pMieMoon) * uMoonColor;
    vec3 moonScattering = moonPhaseRadiance * inscatterFactor * (0.4 * moonElevation);

    // Sun altitude blend factor: smooth fade during dawn/dusk twilight
    float sunElevation = smoothstep(-0.15, 0.20, uSunDirection.y);
    float nightFactor = 1.0 - smoothstep(0.0, 0.15, uSunDirection.y);

    // 6. Deep Astral Space Layer (Stars & Fantasy Nebula)
    vec3 spaceRadiance = vec3(0.0);
    if (nightFactor > 0.001 && rayDir.y > 0.0) {
        float zenithFade = smoothstep(0.0, 0.25, rayDir.y);
        float stars = renderStars(rayDir, uTime) * uStarIntensity;
        vec3 nebula = renderNebula(rayDir, uTime) * uNebulaIntensity;

        spaceRadiance = (vec3(stars) + nebula) * zenithFade * nightFactor;
    }

    // 7. Celestial Disks (Sun & Moon)
    vec3 sunDisk = vec3(0.0);
    if (uSunDirection.y > -0.05) {
        sunDisk = renderSunDisk(rayDir, uSunDirection, uSunColor, sunTransmittance);
    }

    vec3 moonDisk = vec3(0.0);
    if (uMoonDirection.y > -0.05) {
        moonDisk = renderMoonDisk(rayDir, uMoonDirection, uSunDirection, uMoonColor);
    }

    // 8. Composite Total Sky Radiance (HDR)
    vec3 skyRadiance = (sunScattering * sunElevation) + moonScattering + spaceRadiance + sunDisk + moonDisk;

    // 9. Horizon Glow & Nadir Ground Transition
    // Horizon glow band: peak intensity near the horizon (-0.05 to +0.08)
    float horizonGlowFactor = 1.0 - smoothstep(0.0, 0.12, abs(rayDir.y));
    vec3 horizonGlowColor = mix(skyRadiance, (uSunDirection.y > 0.0 ? uSunColor * 0.3 : uMoonColor * 0.2), 0.25);
    skyRadiance += horizonGlowColor * (horizonGlowFactor * 0.25);

    if (rayDir.y < 0.05) {
        // Horizon haze blend transitioning down to ground nadir color
        float groundBlend = smoothstep(0.05, -0.25, rayDir.y);
        vec3 horizonHaze = mix(skyRadiance, uGroundColor, 0.4);
        skyRadiance = mix(horizonHaze, uGroundColor, groundBlend);
    }

    // 10. Exposure compensation & ACES Tonemapping
    float exposure = max(uExposure, 0.01);
    vec3 exposedRadiance = skyRadiance * exposure;
    vec3 tonemappedColor = acesTonemap(exposedRadiance);

    // Gamma 2.2 output
    vec3 finalRgb = pow(clamp(tonemappedColor, 0.0, 1.0), vec3(1.0 / 2.2));

    fragColor = vec4(finalRgb, 1.0);
}
