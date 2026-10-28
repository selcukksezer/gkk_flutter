#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;

out vec4 fragColor;

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 uv = pos / max(uSize, vec2(1.0));

  // Rising thermal convection ribbons & molten ember glow
  float verticalFade = smoothstep(0.05, 0.45, uv.y) * (1.0 - smoothstep(0.72, 1.0, uv.y));
  float bottomGlow = smoothstep(0.35, 1.0, uv.y);

  float waveA = sin(uv.x * 14.0 + sin(uv.y * 9.0 - uTime * 2.4) * 2.1 + uTime * 0.8);
  float waveB = cos(uv.x * 23.0 - uTime * 1.7 + uv.y * 13.0);
  float hazeBand = pow(clamp(0.5 + 0.5 * (waveA * 0.65 + waveB * 0.35), 0.0, 1.0), 2.6);

  // Subtle drifting ember filaments
  float emberTrack = sin(uv.x * 38.0 + sin(uTime * 1.3 + uv.y * 6.0) * 3.0);
  float emberPulse = sin(uv.y * 28.0 + uTime * 3.8 + uv.x * 11.0);
  float sparks = pow(clamp(emberTrack * emberPulse, 0.0, 1.0), 8.0);

  vec3 magmaCrimson = vec3(0.84, 0.16, 0.09);
  vec3 solarAmber = vec3(1.00, 0.56, 0.16);
  vec3 whiteHot = vec3(1.00, 0.90, 0.66);

  vec3 col = mix(magmaCrimson, solarAmber, hazeBand);
  col = mix(col, whiteHot, sparks * 0.85);

  float alpha = (verticalFade * hazeBand * 0.16 + bottomGlow * 0.11 + sparks * verticalFade * 0.36) * clamp(uIntensity, 0.0, 1.5);
  fragColor = vec4(col * alpha, alpha);
}
