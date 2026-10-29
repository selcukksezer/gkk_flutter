#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uProgress;
uniform float uEnergyIntensity;
uniform vec4 uPrimaryColor;
uniform vec4 uSecondaryColor;
uniform vec4 uGoldColor;

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 4; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;
    vec2 pixelPos = FlutterFragCoord().xy;

    vec3 col = mix(vec3(0.02, 0.04, 0.08), vec3(0.06, 0.10, 0.18), 1.0 - uv.y);

    vec2 p = uv * vec2(3.0, 1.5);
    p.x -= uTime * 0.25;

    vec2 q = vec2(fbm(p + vec2(0.0, 0.0)), fbm(p + vec2(5.2, 1.3)));
    vec2 r = vec2(fbm(p + 4.0 * q + vec2(1.7, 9.2)), fbm(p + 4.0 * q + vec2(8.3, 2.8)));
    float f = fbm(p + 4.0 * r);

    float wave1 = sin(uv.x * 6.28 * 2.0 + uTime * 2.0) * 0.15;
    float wave2 = cos(uv.x * 6.28 * 3.5 - uTime * 1.5) * 0.10;
    float energyLine = smoothstep(0.4, 0.0, abs(uv.y - 0.5 - wave1 - wave2));

    vec3 energyColor = mix(uPrimaryColor.rgb, uSecondaryColor.rgb, clamp(f * 1.5, 0.0, 1.0));
    col += energyColor * energyLine * uEnergyIntensity * 0.65;
    col += uPrimaryColor.rgb * pow(f, 3.0) * uEnergyIntensity * 0.45;

    float sheenCoord = uv.x + uv.y * 0.35;
    float sheenPos = fract(uProgress);
    float sheenDist = abs(sheenCoord - sheenPos * 1.35 + 0.15);
    float sheenGlow = smoothstep(0.12, 0.0, sheenDist);

    vec3 sheenRainbow = vec3(
        smoothstep(0.08, 0.0, abs(sheenDist - 0.02)),
        smoothstep(0.08, 0.0, sheenDist),
        smoothstep(0.08, 0.0, abs(sheenDist + 0.02))
    );
    col += sheenRainbow * 0.25 + vec3(1.0) * pow(sheenGlow, 2.0) * 0.35;

    float borderDistX = min(pixelPos.x, uResolution.x - pixelPos.x);
    float borderDistY = min(pixelPos.y, uResolution.y - pixelPos.y);
    float borderDist = min(borderDistX, borderDistY);

    if (borderDist < 2.5) {
        float goldIntensity = smoothstep(0.0, 1.5, borderDist);
        vec3 gold = uGoldColor.rgb * (1.2 - goldIntensity * 0.5);

        float perimeterCoord = (pixelPos.x + pixelPos.y) / (uResolution.x + uResolution.y);
        float glint = smoothstep(0.06, 0.0, abs(fract(perimeterCoord - uProgress * 1.2) - 0.5));
        gold += vec3(1.0, 0.95, 0.8) * glint * 1.5;

        col = mix(gold, col, clamp(borderDist / 2.5, 0.0, 1.0));
    }

    float vignette = 1.0 - length((uv - 0.5) * vec2(1.2, 1.5)) * 0.45;
    col *= clamp(vignette, 0.3, 1.0);

    fragColor = vec4(col, 1.0);
}
