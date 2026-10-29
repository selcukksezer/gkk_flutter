#version 460

#include <flutter/runtime_effect.glsl>

// Water Puddle Shader — stub pending full implementation.
// Outputs a neutral passthrough color until puddle reflection is wired.

uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  // Neutral transparent passthrough — no visual effect until real puddle SSR.
  fragColor = vec4(0.0);
}
