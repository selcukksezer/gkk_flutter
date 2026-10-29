#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// 2027 Aion 2 Mobile - Animated Emblem Aura & Particle Radiance Shader
// Compatible with Flutter RuntimeEffect & Impeller Graphics Pipeline
//
// Features:
// - Multi-tier breathing radial aura glow with harmonic pulses
// - Rotating celestial sunburst light rays
// - Orbiting particle radiance & sparks
// - Ethereal chromatic edge bloom
// -----------------------------------------------------------------------------

uniform vec2 uResolution;
uniform float uTime;
uniform float uProgress;
uniform vec4 uAuraColor;
uniform vec4 uCoreColor;
uniform float uPulseSpeed;
uniform float uAuraRadius;

out vec4 fragColor;

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

void main() {
    vec2 uv = (FlutterFragCoord().xy - 0.5 * uResolution.xy) / min(uResolution.x, uResolution.y);
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // 1. Harmonic Breathing Aura Pulse
    float pulse = 0.5 + 0.5 * sin(uTime * uPulseSpeed * 3.14159);
    float currentRadius = uAuraRadius * (0.85 + 0.15 * pulse);

    // Multi-layer radial glow falloff
    float glow1 = exp(-dist * 6.0 / currentRadius);
    float glow2 = exp(-dist * 2.8 / currentRadius);
    float glowCore = exp(-dist * 12.0 / currentRadius);

    vec3 aura = uAuraColor.rgb * glow2 * 0.6 + uAuraColor.rgb * glow1 * 0.8;
    vec3 core = uCoreColor.rgb * glowCore * 1.2;

    // 2. Rotating Celestial Light Rays
    float rayCount = 12.0;
    float rayRot = uTime * 0.4;
    float rays = 0.5 + 0.5 * cos(angle * rayCount + rayRot);
    rays = pow(rays, 3.0) * exp(-dist * 4.0);
    aura += uAuraColor.rgb * rays * 0.7;

    // Counter-rotating fine secondary rays
    float rays2 = 0.5 + 0.5 * cos(angle * 24.0 - uTime * 0.6);
    rays2 = pow(rays2, 4.0) * exp(-dist * 5.5);
    aura += uCoreColor.rgb * rays2 * 0.4;

    // 3. Orbiting Particle Radiance
    float particles = 0.0;
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float orbitR = currentRadius * (0.4 + 0.5 * hash(fi * 1.3));
        float speed = (0.8 + 0.6 * hash(fi * 3.7)) * (mod(fi, 2.0) == 0.0 ? 1.0 : -1.0);
        float pAngle = uTime * speed + fi * (6.28318 / 16.0);
        vec2 pPos = vec2(cos(pAngle), sin(pAngle)) * orbitR;

        // Particle sparkle pulse
        float pDist = length(uv - pPos);
        float sparkle = exp(-pDist * 50.0) * (0.6 + 0.4 * sin(uTime * 4.0 + fi));
        particles += sparkle;
    }

    vec3 finalCol = aura + core + vec3(1.0, 0.95, 0.8) * particles * 1.5;
    float alpha = clamp(glow2 * 0.8 + glowCore + rays * 0.6 + particles, 0.0, 1.0);

    fragColor = vec4(finalCol, alpha);
}
