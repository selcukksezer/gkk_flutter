#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// Bilateral Depth-Aware Blur Shader for SSAO Noise Elimination
// Edge-preserving smoothing preventing ambient occlusion bleeding across silhouettes
// Compatible with Flutter RuntimeEffect & Impeller Graphics Pipeline
// -----------------------------------------------------------------------------

precision highp float;

// Uniforms: All scalar and vector uniforms declared before samplers
// Exact 6-Float Layout matching PostProcessPipelineController.buildBilateralUniforms
uniform vec2 uResolution;      // [0..1] Viewport resolution (pixels)
uniform vec2 uBlurDirection;   // [2..3] Direction vector: vec2(1.0, 0.0) horizontal or vec2(0.0, 1.0) vertical
uniform float uSpatialSigma;   // [4]    Spatial blur sigma (e.g. 2.5)
uniform float uDepthThreshold; // [5]    Depth edge sensitivity (e.g. 0.08)

// Samplers declared after numeric uniforms
uniform sampler2D uAoTexture;    // [Sampler 0] Texture containing raw AO in R and linear depth in G
uniform sampler2D uDepthTexture; // [Sampler 1] Fallback depth buffer if not packed in uAoTexture

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 safeRes = max(uResolution, vec2(1.0));
    vec2 uv = fragCoord / safeRes;
    vec2 texelSize = 1.0 / safeRes;
    vec2 halfTexel = 0.5 * texelSize;

    vec4 centerSample = texture(uAoTexture, uv);
    float centerAo = centerSample.r;
    float centerZ = centerSample.g;

    // If depth is not packed into the G channel, sample from uDepthTexture
    if (centerZ <= 0.0001) {
        centerZ = texture(uDepthTexture, uv).r;
    }

    float sigmaSpatial = (uSpatialSigma > 0.0) ? uSpatialSigma : 2.5;
    float sigmaDepth = (uDepthThreshold > 0.0) ? uDepthThreshold : 0.08;
    float twoSigmaSpatialSq = 2.0 * sigmaSpatial * sigmaSpatial;
    float twoSigmaDepthSq = 2.0 * sigmaDepth * sigmaDepth;

    // Filter kernel radius (-4 to +4 taps along direction)
    const int KERNEL_RADIUS = 4;
    vec2 stepVec = uBlurDirection * texelSize;

    float totalWeight = 0.0;
    float filteredAo = 0.0;

    for (int i = -KERNEL_RADIUS; i <= KERNEL_RADIUS; ++i) {
        float offset = float(i);
        vec2 sampleUv = uv + stepVec * offset;
        sampleUv = clamp(sampleUv, halfTexel, vec2(1.0) - halfTexel);

        vec4 tapSample = texture(uAoTexture, sampleUv);
        float tapAo = tapSample.r;
        float tapZ = tapSample.g;

        if (tapZ <= 0.0001) {
            tapZ = texture(uDepthTexture, sampleUv).r;
        }

        // Spatial Gaussian weight
        float spatialDistSq = offset * offset;
        float wSpatial = exp(-spatialDistSq / twoSigmaSpatialSq);

        // Depth discontinuity weight (reject taps across geometric edges)
        float depthDiff = abs(tapZ - centerZ);
        float wDepth = exp(-(depthDiff * depthDiff) / twoSigmaDepthSq);

        float weight = wSpatial * wDepth;
        filteredAo += tapAo * weight;
        totalWeight += weight;
    }

    float finalAo = clamp((totalWeight > 0.0001) ? (filteredAo / totalWeight) : centerAo, 0.0, 1.0);
    fragColor = vec4(finalAo, centerZ, centerSample.b, centerSample.a);
}
