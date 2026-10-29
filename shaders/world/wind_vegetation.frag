#version 460

#include <flutter/runtime_effect.glsl>

// Wind Vegetation Shader — stub pending full implementation.
// Outputs a neutral passthrough color until wind simulation is wired.

uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  // Neutral transparent passthrough — no visual effect until real wind sim.
  fragColor = vec4(0.0);
}
