#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;

out vec4 fragColor;

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 uv = pos / max(uSize, vec2(1.0));
  vec2 centered = (uv - 0.5) * 2.0;
  float radial = 1.0 - smoothstep(0.18, 1.0, length(centered));

  // Dual-layer interference water caustics in isometric perspective
  vec2 p1 = vec2(uv.x * 9.5, uv.y * 15.0);
  float w1 = sin(p1.x + uTime * 1.65 + sin(p1.y * 0.85 - uTime * 1.15));
  float w2 = cos(p1.y * 1.15 - uTime * 1.40 + cos(p1.x * 1.10 + uTime * 0.95));
  float w3 = sin((p1.x + p1.y) * 0.78 - uTime * 1.95);

  float network = abs(w1 + w2 * 0.85 + w3 * 0.55) / 2.4;
  float causticCrest = pow(clamp(1.0 - network, 0.0, 1.0), 3.4);
  float rippleRing = 0.5 + 0.5 * sin(length(centered) * 14.0 - uTime * 2.6);

  vec3 deepAqua = vec3(0.08, 0.48, 0.76);
  vec3 brightCyan = vec3(0.56, 0.93, 1.00);
  vec3 goldGlint = vec3(1.00, 0.86, 0.52);

  vec3 col = mix(deepAqua, brightCyan, clamp(causticCrest * 1.35 + rippleRing * 0.22, 0.0, 1.0));
  col = mix(col, goldGlint, pow(causticCrest, 2.2) * 0.35);

  float alpha = radial * clamp(0.12 + causticCrest * 0.58 + rippleRing * 0.08, 0.0, 0.82) * clamp(uIntensity, 0.0, 1.5);
  fragColor = vec4(col * alpha, alpha);
}
