#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// Scalable Horizon-Based Screen Space Ambient Occlusion (SSAO) Shader
// Compatible with Flutter RuntimeEffect & Impeller Graphics Pipeline
// -----------------------------------------------------------------------------

precision highp float;

// -----------------------------------------------------------------------------
// Numeric Uniforms (Indices 0..8, total 9 floats)
// STRICT: Declared before any sampler2D uniforms for Impeller runtime effect compliance.
// -----------------------------------------------------------------------------
uniform vec2  uResolution;   // 0..1: Viewport resolution in physical pixels
uniform float uRadius;       // 2:    View-space sampling radius (e.g. 0.5)
uniform float uBias;         // 3:    Horizon angle bias (e.g. 0.025 to reject flat surface acne)
uniform float uIntensity;    // 4:    Occlusion intensity multiplier (e.g. 1.8)
uniform float uPower;        // 5:    Occlusion contrast curve exponent (e.g. 2.0)
uniform float uSampleCount;  // 6:    Active sample count (e.g. 16.0 or 24.0, max 32)
uniform float uNear;         // 7:    Camera near plane distance (e.g. 0.1)
uniform float uFar;          // 8:    Camera far plane distance (e.g. 100.0)

// -----------------------------------------------------------------------------
// Samplers (Texture Units 0..1)
// STRICT: Declared after all scalar and vector numeric uniforms.
// -----------------------------------------------------------------------------
uniform sampler2D uDepthTexture;   // Unit 0: Non-linear or linear normalized depth buffer
uniform sampler2D uNormalTexture;  // Unit 1: View-space or tangent normal map [0, 1]

out vec4 fragColor;

// Golden angle constant for Vogel spiral sampling: pi * (3 - sqrt(5))
const float GOLDEN_ANGLE = 2.399963229728653; // radians
const int   MAX_SAMPLES  = 32;

// -----------------------------------------------------------------------------
// Pseudo-random noise hash for spatial dither / sample rotation (Dave Hoskins hash12)
// -----------------------------------------------------------------------------
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// -----------------------------------------------------------------------------
// Convert non-linear depth buffer value [0, 1] to linear view-space depth
// -----------------------------------------------------------------------------
float linearizeDepth(float depth, float near, float far) {
    if (depth >= 1.0) return far;
    if (depth <= 0.0) return near;
    return (near * far) / (far - depth * (far - near) + 0.000001);
}

// -----------------------------------------------------------------------------
// Reconstruct view-space position from UV and linear view depth
// -----------------------------------------------------------------------------
vec3 reconstructViewPos(vec2 uv, float linearZ) {
    vec2 ndc = uv * 2.0 - 1.0;
    float aspect = (uResolution.y > 0.0) ? (uResolution.x / uResolution.y) : 1.0;
    vec2 viewRay = vec2(ndc.x * aspect, ndc.y);
    return vec3(viewRay * linearZ, linearZ);
}

// -----------------------------------------------------------------------------
// Reconstruct surface normal from screen-space depth gradient
// Uses adaptive discontinuity-aware differences to prevent silhouette halo bleeding
// -----------------------------------------------------------------------------
vec3 reconstructNormal(vec2 uv, vec2 texelSize, float centerZ) {
    vec2 uvLeft  = clamp(uv - vec2(texelSize.x, 0.0), vec2(0.0), vec2(1.0));
    vec2 uvRight = clamp(uv + vec2(texelSize.x, 0.0), vec2(0.0), vec2(1.0));
    vec2 uvDown  = clamp(uv - vec2(0.0, texelSize.y), vec2(0.0), vec2(1.0));
    vec2 uvUp    = clamp(uv + vec2(0.0, texelSize.y), vec2(0.0), vec2(1.0));

    float zLeft  = linearizeDepth(texture(uDepthTexture, uvLeft).r, uNear, uFar);
    float zRight = linearizeDepth(texture(uDepthTexture, uvRight).r, uNear, uFar);
    float zDown  = linearizeDepth(texture(uDepthTexture, uvDown).r, uNear, uFar);
    float zUp    = linearizeDepth(texture(uDepthTexture, uvUp).r, uNear, uFar);

    vec3 pCenter = reconstructViewPos(uv, centerZ);
    vec3 pLeft   = reconstructViewPos(uvLeft, zLeft);
    vec3 pRight  = reconstructViewPos(uvRight, zRight);
    vec3 pDown   = reconstructViewPos(uvDown, zDown);
    vec3 pUp     = reconstructViewPos(uvUp, zUp);

    // Adaptive discontinuity-aware difference: pick closer neighbor to avoid silhouette bleeding
    vec3 dx = (abs(zRight - centerZ) < abs(zLeft - centerZ)) ? (pRight - pCenter) : (pCenter - pLeft);
    vec3 dy = (abs(zUp - centerZ) < abs(zDown - centerZ)) ? (pUp - pCenter) : (pCenter - pDown);

    vec3 crossD = cross(dx, dy);
    float len = length(crossD);
    vec3 n = (len > 0.000001) ? (crossD / len) : vec3(0.0, 0.0, -1.0);

    // Ensure normal points toward viewer (viewer is at origin looking along +Z; surface normal faces -Z)
    if (n.z > 0.0) {
        n = -n;
    }
    return n;
}

// -----------------------------------------------------------------------------
// Main SSAO Evaluation
// -----------------------------------------------------------------------------
void main() {
    vec2 safeResolution = max(uResolution, vec2(1.0, 1.0));
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / safeResolution;
    vec2 texelSize = 1.0 / safeResolution;

    float rawDepth = texture(uDepthTexture, uv).r;
    float centerZ = linearizeDepth(rawDepth, uNear, uFar);

    // Skip skybox / background at far plane (no occlusion in open sky)
    if (rawDepth >= 0.9999 || centerZ >= (uFar * 0.99)) {
        fragColor = vec4(1.0, centerZ, 0.5, 1.0);
        return;
    }

    vec3 centerPos = reconstructViewPos(uv, centerZ);

    // Normal from normal texture (if bound) or reconstructed from depth gradients
    vec4 normalSample = texture(uNormalTexture, uv);
    vec3 normal;
    if (dot(normalSample.xyz, normalSample.xyz) > 0.1) {
        normal = normalize(normalSample.xyz * 2.0 - 1.0);
        // Ensure normal points toward viewer in view-space
        if (normal.z > 0.0) {
            normal = -normal;
        }
    } else {
        normal = reconstructNormal(uv, texelSize, centerZ);
    }

    // Safety fallback for degenerate normals
    if (dot(normal, normal) < 0.0001) {
        normal = vec3(0.0, 0.0, -1.0);
    } else {
        normal = normalize(normal);
    }

    // Per-pixel random rotation matrix from spatial dither hash
    float randomAngle = hash12(fragCoord) * 6.28318530718;
    float cosRot = cos(randomAngle);
    float sinRot = sin(randomAngle);
    // Column-major mat2: col0 = (cos, sin), col1 = (-sin, cos)
    mat2 rotMat = mat2(cosRot, sinRot, -sinRot, cosRot);

    float effectiveRadius = (uRadius > 0.0) ? uRadius : 0.5;
    float bias            = (uBias >= 0.0) ? uBias : 0.025;
    float intensity       = (uIntensity > 0.0) ? uIntensity : 1.5;
    float power           = (uPower > 0.0) ? uPower : 2.0;
    int   samples         = int(clamp(uSampleCount, 4.0, float(MAX_SAMPLES)));

    // Screen-space radius shrinks with distance: aspect ratio applied to Y
    float aspect = safeResolution.x / safeResolution.y;
    vec2 screenRadius = (effectiveRadius / max(centerZ, 0.1)) * vec2(1.0, aspect) * 0.1;
    screenRadius = clamp(screenRadius, texelSize * 2.0, vec2(0.2));

    float occlusion   = 0.0;
    float totalWeight = 0.0;

    // Loop with constant upper bound for universal GPU compiler / SPIR-V compatibility
    for (int i = 0; i < MAX_SAMPLES; ++i) {
        if (i >= samples) {
            break;
        }

        float fi = float(i);
        // Vogel spiral distribution: uniform area coverage on unit disk
        float r = sqrt((fi + 0.5) / float(samples));
        float theta = fi * GOLDEN_ANGLE;
        vec2 sampleOffset = r * vec2(cos(theta), sin(theta));
        sampleOffset = rotMat * sampleOffset;

        vec2 sampleUv = uv + sampleOffset * screenRadius;
        sampleUv = clamp(sampleUv, vec2(0.001), vec2(0.999));

        float sampleRawDepth = texture(uDepthTexture, sampleUv).r;

        // Open skybox tap does not occlude foreground surface, but counts toward hemisphere weight
        if (sampleRawDepth >= 0.9999) {
            totalWeight += 1.0;
            continue;
        }

        float sampleZ = linearizeDepth(sampleRawDepth, uNear, uFar);
        vec3 samplePos = reconstructViewPos(sampleUv, sampleZ);

        vec3 diff = samplePos - centerPos;
        float dist = length(diff);

        if (dist > 0.0001) {
            // Horizon occlusion test: Cosine of angle between surface normal and difference vector
            float NdotV = clamp(dot(normal, diff) / dist, -1.0, 1.0);
            float horizonFactor = max(0.0, NdotV - bias);

            // Range check attenuation: smoothstep falloff when sample reaches beyond radius
            float rangeCheck = smoothstep(effectiveRadius, 0.0, dist);

            occlusion += horizonFactor * rangeCheck;
        }
        totalWeight += 1.0;
    }

    float ao = 1.0;
    if (totalWeight > 0.0) {
        float avgOcclusion = (occlusion / totalWeight) * intensity;
        ao = clamp(1.0 - avgOcclusion, 0.0, 1.0);
        ao = pow(ao, power);
    }

    // Output:
    // R: AO attenuation factor [0.0 = occluded, 1.0 = fully lit]
    // G: Linear view-space depth (consumed by bilateral blur filter)
    // B: Encoded normal X component [0.0..1.0]
    // A: Alpha channel (1.0)
    fragColor = vec4(ao, centerZ, (normal.x * 0.5 + 0.5), 1.0);
}
