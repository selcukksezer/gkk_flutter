#version 460 core
#include <flutter/runtime_effect.glsl>

// -----------------------------------------------------------------------------
// Clustered Crowd Lighting Fragment Shader (AAA 2027 Pipeline)
// Compatible with Flutter Impeller & SkSL Runtime Effect Pipelines
//
// Eliminates individual per-entity dynamic point lights across 10,000 instances
// (strictly prohibited by R4) by clustering dynamic lights into a 3D spatial voxel
// or screen-space clustered tile-depth grid. Each fragment calculates its cluster
// index and loops ONLY over active lights assigned to that specific cluster.
// -----------------------------------------------------------------------------

precision highp float;
precision highp int;
precision highp sampler2D;

// Float & Vector Uniforms (MUST precede all sampler uniforms in Flutter runtime effects)
uniform vec2 uResolution;             // Viewport dimensions (pixels: width, height)
uniform vec3 uClusterDims;            // Cluster resolution: vec3(dimX, dimY, dimZ), e.g. (16, 9, 24)
uniform vec4 uDepthParams;            // x=zNear, y=zFar, z=logFactor (dimZ / log(zFar/zNear)), w=invZFarNear
uniform vec3 uVoxelMin;               // World-space 3D voxel grid minimum bounds (minX, minY, minZ)
uniform vec3 uVoxelMax;               // World-space 3D voxel grid maximum bounds (maxX, maxY, maxZ)
uniform float uClusterMode;           // 0.0 = Screen-space tiled depth slices, 1.0 = World-space 3D voxel grid
uniform float uMaxLightsPerCluster;   // Maximum lights stored per cluster cell (e.g. 32.0)
uniform vec4 uAmbientIrradiance;      // vec4(ambientR, ambientG, ambientB, ambientIntensity)
uniform vec3 uCameraPos;              // World-space camera position for specular highlights
uniform float uSpecularRoughness;     // Default material surface roughness [0.01, 1.0]
uniform float uLightTextureWidth;     // Texture width for light data sampler (e.g. 256.0)
uniform float uClusterTextureWidth;   // Texture width for cluster grid sampler (e.g. 256.0)

// Sampler Uniforms (Declared strictly after all numeric uniforms)
uniform sampler2D uAlbedoTexture;      // Base albedo / diffuse color texture
uniform sampler2D uNormalTexture;      // World-space or tangent normal map [0,1] -> [-1,1]
uniform sampler2D uDepthTexture;       // Scene depth buffer (0.0 to 1.0 non-linear or linear)
uniform sampler2D uClusterGridTexture; // RGBA texture: R=offsetLow, G=offsetHigh, B=lightCount, A=reserved
uniform sampler2D uLightIndexTexture;  // R/RGBA texture storing flat light indices
uniform sampler2D uLightDataTexture;   // RGBA32F texture storing light position, radius, color, and falloff

out vec4 fragColor;

// Maximum unroll limit for GPU driver compiler compatibility
const int MAX_CLUSTER_LIGHTS = 32;

// -----------------------------------------------------------------------------
// Depth Linearization: converts non-linear depth [0, 1] to view-space linear Z
// -----------------------------------------------------------------------------
float linearizeDepth(float nonLinearDepth, float near, float far) {
    float n = max(near, 0.001);
    float f = max(far, n + 1.0);
    if (nonLinearDepth >= 1.0) return f;
    if (nonLinearDepth <= 0.0) return n;
    return (n * f) / max(f - nonLinearDepth * (f - n), 0.00001);
}

// -----------------------------------------------------------------------------
// Calculate Cluster Index in Screen-Space (Tiled X/Y with Logarithmic Depth Z)
// -----------------------------------------------------------------------------
ivec3 computeScreenSpaceCluster(vec2 uv, float linearZ) {
    int cx = int(clamp(floor(uv.x * uClusterDims.x), 0.0, uClusterDims.x - 1.0));
    int cy = int(clamp(floor(uv.y * uClusterDims.y), 0.0, uClusterDims.y - 1.0));

    // Logarithmic depth slice: slice = floor(log(linearZ / zNear) * logFactor)
    float zNear = max(uDepthParams.x, 0.001);
    float zFar = max(uDepthParams.y, zNear + 1.0);
    float clampedZ = clamp(linearZ, zNear, zFar);
    
    float depthNorm = log(clampedZ / zNear) / max(log(zFar / zNear), 0.0001);
    int cz = int(clamp(floor(depthNorm * uClusterDims.z), 0.0, uClusterDims.z - 1.0));

    return ivec3(cx, cy, cz);
}

// -----------------------------------------------------------------------------
// Calculate Cluster Index in World-Space 3D Voxel Grid
// -----------------------------------------------------------------------------
ivec3 computeWorldVoxelCluster(vec3 worldPos) {
    vec3 voxelRange = max(uVoxelMax - uVoxelMin, vec3(0.001));
    vec3 normalizedPos = clamp((worldPos - uVoxelMin) / voxelRange, vec3(0.0), vec3(0.9999));

    int cx = int(floor(normalizedPos.x * uClusterDims.x));
    int cy = int(floor(normalizedPos.y * uClusterDims.y));
    int cz = int(floor(normalizedPos.z * uClusterDims.z));

    return ivec3(
        clamp(cx, 0, int(uClusterDims.x) - 1),
        clamp(cy, 0, int(uClusterDims.y) - 1),
        clamp(cz, 0, int(uClusterDims.z) - 1)
    );
}

// -----------------------------------------------------------------------------
// Convert 3D Cluster Coordinates to Linear 1D Index
// -----------------------------------------------------------------------------
int clusterCoordToLinearIndex(ivec3 clusterCoord) {
    int sliceSize = int(uClusterDims.x) * int(uClusterDims.y);
    return clusterCoord.z * sliceSize + clusterCoord.y * int(uClusterDims.x) + clusterCoord.x;
}

// -----------------------------------------------------------------------------
// Sample 2D Data Texture via 1D Linear Texel Offset
// -----------------------------------------------------------------------------
vec4 fetchTexel1D(sampler2D tex, int linearIndex, float textureWidth) {
    if (linearIndex < 0) return vec4(0.0);
    int tw = max(int(textureWidth), 1);
    ivec2 coord = ivec2(linearIndex % tw, linearIndex / tw);
    
    // Bounds check against actual texture dimensions if queryable
    ivec2 texDim = textureSize(tex, 0);
    if (texDim.x > 0 && texDim.y > 0) {
        if (coord.x >= texDim.x || coord.y >= texDim.y) {
            return vec4(0.0);
        }
    }
    
    return texelFetch(tex, coord, 0);
}

// -----------------------------------------------------------------------------
// Smooth Windowed Inverse Square Attenuation (Frostbite / Filament PBR standard)
// att = [saturate(1 - (d / radius)^4)]^2 / (d^2 + 1)
// -----------------------------------------------------------------------------
float computeSmoothAttenuation(float dist, float radius) {
    if (dist >= radius || radius <= 0.0) return 0.0;
    float ratio = dist / radius;
    float ratio4 = ratio * ratio * ratio * ratio;
    float smoothFactor = clamp(1.0 - ratio4, 0.0, 1.0);
    return (smoothFactor * smoothFactor) / (dist * dist + 1.0);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // Sample Base Color / Albedo
    vec4 albedo = texture(uAlbedoTexture, uv);
    if (albedo.a <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // Sample Normal
    vec4 normalSample = texture(uNormalTexture, uv);
    vec3 normal = normalize(normalSample.xyz * 2.0 - 1.0);
    if (length(normal) < 0.1) {
        normal = vec3(0.0, 1.0, 0.0); // Default upward normal
    }

    // Sample Depth and reconstruct linear depth / world position
    float depthSample = texture(uDepthTexture, uv).r;
    float linearZ = linearizeDepth(depthSample, uDepthParams.x, uDepthParams.y);

    // Reconstruct world/view position from screen UV and linear depth
    vec2 ndc = uv * 2.0 - 1.0;
    vec3 viewRay = vec3(
        ndc.x * (uResolution.x / uResolution.y) * linearZ,
        -ndc.y * linearZ,
        linearZ
    );
    vec3 worldPos = uCameraPos + viewRay;

    // Determine Cluster (Screen-Space Depth Sliced vs World Voxel Grid)
    ivec3 clusterCoord;
    if (uClusterMode < 0.5) {
        clusterCoord = computeScreenSpaceCluster(uv, linearZ);
    } else {
        clusterCoord = computeWorldVoxelCluster(worldPos);
    }

    int linearClusterIndex = clusterCoordToLinearIndex(clusterCoord);
    int totalClusters = int(uClusterDims.x) * int(uClusterDims.y) * int(uClusterDims.z);
    linearClusterIndex = clamp(linearClusterIndex, 0, max(totalClusters - 1, 0));

    // Fetch Cluster Grid Texel: R=offsetLow, G=offsetHigh, B=lightCount, A=reserved
    vec4 clusterData = fetchTexel1D(uClusterGridTexture, linearClusterIndex, uClusterTextureWidth);
    int lightOffset = int(floor(clusterData.r * 255.0 + 0.5)) + int(floor(clusterData.g * 255.0 + 0.5)) * 256;
    int lightCount = int(floor(clusterData.b * 255.0 + 0.5));
    lightCount = min(lightCount, min(int(uMaxLightsPerCluster), MAX_CLUSTER_LIGHTS));

    // View direction for specular reflection
    vec3 viewDir = normalize(uCameraPos - worldPos);
    float roughness = clamp(uSpecularRoughness, 0.05, 1.0);
    float shininess = mix(128.0, 8.0, roughness);

    // Accumulate Clustered Lights
    vec3 totalDiffuse = vec3(0.0);
    vec3 totalSpecular = vec3(0.0);

    for (int i = 0; i < MAX_CLUSTER_LIGHTS; i++) {
        if (i >= lightCount) break;

        // Fetch Light Index from flattened light index texture
        int indexLookup = lightOffset + i;
        vec4 indexTexel = fetchTexel1D(uLightIndexTexture, indexLookup, uClusterTextureWidth);
        int lightIdx = int(floor(indexTexel.r * 255.0 + 0.5)) + int(floor(indexTexel.g * 255.0 + 0.5)) * 256;
        if (lightIdx < 0) continue;

        // Fetch Light Data (Texel 0: pos.xyz + radius, Texel 1: color.rgb * intensity + falloff)
        int lightDataTexel0 = lightIdx * 2;
        int lightDataTexel1 = lightIdx * 2 + 1;
        vec4 posAndRadius = fetchTexel1D(uLightDataTexture, lightDataTexel0, uLightTextureWidth);
        vec4 colorAndFalloff = fetchTexel1D(uLightDataTexture, lightDataTexel1, uLightTextureWidth);

        vec3 lightPos = posAndRadius.xyz;
        float radius = posAndRadius.w;
        vec3 lightColor = colorAndFalloff.rgb;

        // Light vector & distance
        vec3 lightVec = lightPos - worldPos;
        float dist = length(lightVec);

        if (dist >= radius || radius <= 0.001) {
            continue;
        }

        vec3 lightDir = lightVec / max(dist, 0.0001);

        // Attenuation calculation
        float attenuation = computeSmoothAttenuation(dist, radius);
        if (attenuation <= 0.0001) continue;

        // Diffuse Lambertian term
        float nDotL = max(dot(normal, lightDir), 0.0);

        // Specular Blinn-Phong term
        vec3 halfVec = normalize(lightDir + viewDir);
        float nDotH = max(dot(normal, halfVec), 0.0);
        float specularTerm = pow(nDotH, shininess) * (1.0 - roughness);

        // Radiance accumulation
        vec3 radiance = lightColor * attenuation;
        totalDiffuse += radiance * nDotL;
        totalSpecular += radiance * specularTerm;
    }

    // Environmental / Spherical Harmonic Ambient term
    vec3 ambient = uAmbientIrradiance.rgb * uAmbientIrradiance.a;

    // Final Lighting composition (PBR diffuse + specular + ambient)
    vec3 finalRgb = max(albedo.rgb * (ambient + totalDiffuse) + totalSpecular, vec3(0.0));

    fragColor = vec4(finalRgb, albedo.a);
}
