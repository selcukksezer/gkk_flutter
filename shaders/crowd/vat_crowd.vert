#version 460 core
#include <flutter/runtime_effect.glsl>

// VAT Crowd Vertex Shader — Impeller Fragment Compatible Wrapper
precision highp float;
out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy;
    fragColor = vec4(uv, 1.0, 1.0);
}
