// =============================================================================
// AAA GPU Instancing Vertex Shader for Medium-Range Entities (LOD2)
// 2027 Cinematic Graphics Pipeline (10,000 Player Crowd System)
// Target: Impeller / Vulkan / Metal / OpenGL ES 3.0+
//
// Features:
// - Instance Buffer Layout:
//     * mat4 aInstanceModelMatrix (16 floats, locations 5..8)
//     * vec4 aInstanceAnimData    (4 floats, location 9)
//         x: currentFrame (animation frame index)
//         y: normalizedPhase (0.0 to 1.0)
//         z: animType (0: Idle, 1: Walk, 2: Run, 3: Combat, 4: Stun)
//         w: blendWeight / secondary frame
//     * vec4 aInstanceTintColor   (4 floats, location 10: R, G, B, A)
//   Total Stride = 24 floats (96 bytes), aligned to 16 bytes.
//
// - Dual-Path LOD2 Vertex Animation:
//     * Path 0 (Procedural LOD2 Rig Deformation): Zero texture memory bandwidth
//       analytical skeletal locomotion for thousands of mid-range entities.
//     * Path 1 (Simplified Bone Matrix Texture Palette): 8-12 reduced LOD2 bone
//       transforms sampled from compact bone matrix palette texture.
//     * Path 2 (Rigid LOD2 Mesh): Direct instance matrix transformation.
// =============================================================================
#version 300 es
precision highp float;
precision highp int;

// -----------------------------------------------------------------------------
// Base Mesh Vertex Attributes
// -----------------------------------------------------------------------------
layout(location = 0) in vec3 aPosition;      // Local vertex position
layout(location = 1) in vec3 aNormal;        // Local vertex normal
layout(location = 2) in vec2 aTexCoords;     // Texture UV coordinates
layout(location = 3) in vec4 aBoneIndices;   // LOD2 simplified bone indices (0..11)
layout(location = 4) in vec4 aBoneWeights;   // LOD2 bone blend weights (sum = 1.0)

// -----------------------------------------------------------------------------
// Per-Instance Stream Attributes (VBO Stride = 24 floats / 96 bytes)
// -----------------------------------------------------------------------------
// 4x4 Model Transformation Matrix (16 floats, consumes 4 attribute slots)
layout(location = 5) in mat4 aInstanceModelMatrix;

// Instance Animation Parameters (4 floats)
// x = frameIndex, y = normalizedPhase, z = animType, w = blendWeight
layout(location = 9) in vec4 aInstanceAnimData;

// Instance Tint / Team / Hit Flash Color (4 floats: RGBA)
layout(location = 10) in vec4 aInstanceTintColor;

// -----------------------------------------------------------------------------
// Uniforms
// Strict Impeller / GLES 3.0 layout: Numeric uniforms precede samplers
// -----------------------------------------------------------------------------
uniform mat4 uViewProjection;               // Camera View-Projection Matrix
uniform mat4 uView;                         // Camera View Matrix
uniform vec3 uCameraPosition;               // World-space camera position
uniform float uTime;                        // Global elapsed time in seconds

// Animation Mode Control
// 0: Procedural LOD2 Rig, 1: Bone Matrix Texture Palette, 2: Rigid LOD2
uniform int uAnimMode;

// Texture dimensions and rig specs (used when uAnimMode == 1):
// x: bonesPerRig (e.g. 12.0), y: totalFrames (e.g. 60.0), z: texWidth, w: texHeight
uniform vec4 uBoneTextureParams;

// Bone Matrix Texture Palette (strictly placed after numeric uniforms)
uniform sampler2D uBoneTexture;

// -----------------------------------------------------------------------------
// Outputs to Fragment Shader (Varyings)
// -----------------------------------------------------------------------------
out vec2 vTexCoords;
out vec3 vWorldNormal;
out vec3 vWorldPos;
out vec4 vTintColor;
out float vDistanceToCamera;
out vec3 vViewDir;
out float vAnimPhase;

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------
const float PI = 3.14159265358979323846;
const float TWO_PI = 6.28318530717958647692;
const float EPSILON = 1e-5;

// -----------------------------------------------------------------------------
// Simplified LOD2 Bone Index Mapping:
// 0: Root / Pelvis
// 1: Spine / Torso
// 2: Head / Neck
// 3: Left Upper Arm
// 4: Right Upper Arm
// 5: Left Thigh / Leg
// 6: Right Thigh / Leg
// 7: Weapon / Hand Anchor
// -----------------------------------------------------------------------------

// Fetches 4x4 bone matrix from bone texture palette (1 bone = 4 texels of RGBA32F)
mat4 fetchBoneMatrix(int boneIndex, float frameIndex) {
    float bonesPerRig = max(uBoneTextureParams.x, 1.0);
    float texWidth = max(uBoneTextureParams.z, 1.0);
    float texHeight = max(uBoneTextureParams.w, 1.0);

    // Bounds safety: prevent sampling outside allocated bone palette texture
    int clampedBone = clamp(boneIndex, 0, int(bonesPerRig) - 1);
    float rowV = (frameIndex + 0.5) / texHeight;
    float boneBaseU = float(clampedBone * 4);

    vec4 r0 = texture(uBoneTexture, vec2((boneBaseU + 0.5) / texWidth, rowV));
    vec4 r1 = texture(uBoneTexture, vec2((boneBaseU + 1.5) / texWidth, rowV));
    vec4 r2 = texture(uBoneTexture, vec2((boneBaseU + 2.5) / texWidth, rowV));
    vec4 r3 = texture(uBoneTexture, vec2((boneBaseU + 3.5) / texWidth, rowV));

    return mat4(r0, r1, r2, r3);
}

// -----------------------------------------------------------------------------
// Path 0: Efficient Analytical LOD2 Skeletal Deformation
// Eliminates texture memory bandwidth completely for mid-range crowds (25m - 80m).
// Provides fluid locomotion, breathing, and running lean.
// -----------------------------------------------------------------------------
void computeProceduralLOD2Skinning(
    in vec3 inPos,
    in vec3 inNorm,
    in vec4 boneIdx,
    in vec4 boneWgt,
    in vec4 animData,
    out vec3 outPos,
    out vec3 outNorm
) {
    float phase = animData.y * TWO_PI; // 2 * PI * normalizedPhase
    float animType = animData.z;       // 0: Idle, 1: Walk, 2: Run, 3: Combat, 4: Stun
    float speedMultiplier = mix(1.0, 1.8, clamp(animType - 1.0, 0.0, 1.0));

    // Locomotion activity factor: 0.0 for Idle (0), 1.0 for Walk/Run (1, 2)
    float locomotionFactor = (animType >= 0.5 && animType < 3.5) ? 1.0 : (animType >= 3.5 ? 0.2 : 0.0);

    // Analytical bone deformation offsets
    vec3 animatedPos = inPos;
    vec3 animatedNorm = inNorm;

    // Accumulate deformation across 4 bone weights
    for (int i = 0; i < 4; i++) {
        float weight = boneWgt[i];
        if (weight <= 0.001) continue;

        // Truncation-safe float-to-int conversion (prevents 0.9999 -> 0 bug)
        int b = int(floor(boneIdx[i] + 0.5));
        vec3 boneDisplacement = vec3(0.0);
        vec3 boneRotDelta = vec3(0.0);

        if (b == 0) {
            // Root / Pelvis: Vertical bounce and lateral sway
            float bounce = sin(phase * 2.0 * speedMultiplier) * 0.04 * max(locomotionFactor, 0.3);
            float sway = cos(phase * speedMultiplier) * 0.02 * max(locomotionFactor, 0.3);
            boneDisplacement = vec3(sway, bounce, 0.0);
        } else if (b == 1) {
            // Spine / Torso: Forward lean and breathing expansion
            float lean = (animType >= 1.0) ? 0.08 : 0.0;
            float breath = sin(uTime * 2.5) * 0.015;
            boneDisplacement = vec3(0.0, breath, -lean * (inPos.y * 0.2));
        } else if (b == 2) {
            // Head: Horizon stabilization
            float headBob = sin(phase * 2.0 * speedMultiplier) * 0.015 * max(locomotionFactor, 0.3);
            boneDisplacement = vec3(0.0, headBob, 0.0);
        } else if (b == 3) {
            // Left Arm: Forward-backward pendulum swing
            float armSwing = sin(phase * speedMultiplier) * 0.25 * locomotionFactor;
            boneDisplacement = vec3(0.0, -abs(armSwing) * 0.05, armSwing * 0.3);
            boneRotDelta = vec3(armSwing * 0.4, 0.0, 0.0);
        } else if (b == 4) {
            // Right Arm: Counter-phase pendulum swing
            float armSwing = sin(phase * speedMultiplier + PI) * 0.25 * locomotionFactor;
            boneDisplacement = vec3(0.0, -abs(armSwing) * 0.05, armSwing * 0.3);
            boneRotDelta = vec3(armSwing * 0.4, 0.0, 0.0);
        } else if (b == 5) {
            // Left Leg: Stride displacement & knee lift
            float legStride = sin(phase * speedMultiplier + PI) * 0.35 * locomotionFactor;
            float kneeLift = max(0.0, sin(phase * speedMultiplier + PI)) * 0.12 * locomotionFactor;
            boneDisplacement = vec3(0.0, kneeLift, legStride * 0.4);
        } else if (b == 6) {
            // Right Leg: Counter-phase stride displacement & knee lift
            float legStride = sin(phase * speedMultiplier) * 0.35 * locomotionFactor;
            float kneeLift = max(0.0, sin(phase * speedMultiplier)) * 0.12 * locomotionFactor;
            boneDisplacement = vec3(0.0, kneeLift, legStride * 0.4);
        } else if (b == 7) {
            // Weapon / Hand Anchor: Follows right arm pendulum swing with weapon inertia
            float weaponSwing = sin(phase * speedMultiplier + PI) * 0.25 * locomotionFactor;
            boneDisplacement = vec3(0.0, -abs(weaponSwing) * 0.05, weaponSwing * 0.35);
            boneRotDelta = vec3(weaponSwing * 0.5, 0.0, 0.0);
        }

        // Apply weighted deformation
        animatedPos += boneDisplacement * weight;
        animatedNorm += cross(boneRotDelta, inNorm) * weight;
    }

    outPos = animatedPos;
    outNorm = (length(animatedNorm) > EPSILON) ? normalize(animatedNorm) : inNorm;
}

// -----------------------------------------------------------------------------
// Path 1: Simplified Bone Matrix Palette Skinning
// -----------------------------------------------------------------------------
void computePaletteSkinning(
    in vec3 inPos,
    in vec3 inNorm,
    in vec4 boneIdx,
    in vec4 boneWgt,
    in float frameIndex,
    out vec3 outPos,
    out vec3 outNorm
) {
    vec4 totalLocalPos = vec4(0.0);
    vec3 totalLocalNorm = vec3(0.0);
    vec4 pos4 = vec4(inPos, 1.0);
    float totalWeight = 0.0;

    for (int i = 0; i < 4; i++) {
        float weight = boneWgt[i];
        if (weight > 0.001) {
            // Truncation-safe float-to-int conversion
            int bIdx = int(floor(boneIdx[i] + 0.5));
            mat4 boneMat = fetchBoneMatrix(bIdx, frameIndex);
            totalLocalPos += (boneMat * pos4) * weight;
            totalLocalNorm += (mat3(boneMat) * inNorm) * weight;
            totalWeight += weight;
        }
    }

    // Guard against unskinned or zero-weight vertices (prevents NaN & vertex collapse)
    if (totalWeight > 0.0001) {
        outPos = totalLocalPos.xyz / totalWeight;
        outNorm = (length(totalLocalNorm) > EPSILON) ? normalize(totalLocalNorm) : inNorm;
    } else {
        outPos = inPos;
        outNorm = inNorm;
    }
}

// -----------------------------------------------------------------------------
// Main Shader Execution
// -----------------------------------------------------------------------------
void main() {
    vTexCoords = aTexCoords;
    vTintColor = aInstanceTintColor;
    vAnimPhase = aInstanceAnimData.y;

    vec3 skinnedPos = aPosition;
    vec3 skinnedNorm = aNormal;

    // Select skinning strategy based on LOD2 configuration
    if (uAnimMode == 0) {
        // Procedural LOD2 analytical rig deformation (optimal crowd throughput)
        computeProceduralLOD2Skinning(
            aPosition,
            aNormal,
            aBoneIndices,
            aBoneWeights,
            aInstanceAnimData,
            skinnedPos,
            skinnedNorm
        );
    } else if (uAnimMode == 1) {
        // Bone Matrix Texture Palette lookup
        computePaletteSkinning(
            aPosition,
            aNormal,
            aBoneIndices,
            aBoneWeights,
            aInstanceAnimData.x,
            skinnedPos,
            skinnedNorm
        );
    }
    // Else uAnimMode == 2: Rigid LOD2 mesh (no deformation applied)

    // Unpack Instance Model Matrix and transform to World Space
    vec4 worldPosition = aInstanceModelMatrix * vec4(skinnedPos, 1.0);
    vWorldPos = worldPosition.xyz;

    // Normal Matrix Transformation:
    // Extract upper 3x3 rotational/scaling component of per-instance model matrix
    mat3 normalMatrix = mat3(aInstanceModelMatrix);
    vec3 worldNormal = normalMatrix * skinnedNorm;
    vWorldNormal = (length(worldNormal) > EPSILON) ? normalize(worldNormal) : vec3(0.0, 1.0, 0.0);

    // Compute Camera Distance and View Direction (with NaN protection)
    vec3 toCamera = uCameraPosition - worldPosition.xyz;
    float camDist = length(toCamera);
    vDistanceToCamera = camDist;
    vViewDir = (camDist > EPSILON) ? (toCamera / camDist) : vec3(0.0, 0.0, 1.0);

    // Clip-Space Projection
    gl_Position = uViewProjection * worldPosition;
}
