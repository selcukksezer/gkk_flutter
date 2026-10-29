import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Render mode for a crowd entity.
enum CrowdRenderMode {
  /// Distant entities rendered via Vertex Animated Texture (VAT) mesh deformation.
  vatMesh,

  /// Ultra-distant entities rendered via 8-angle spherical billboard impostor quads.
  impostorBillboard,
}

/// Metadata describing an individual animation clip inside a VAT texture.
class VatClipInfo {
  /// Name of the animation clip (e.g. 'idle', 'walk', 'run', 'combat').
  final String name;

  /// Starting frame index (0-based) in the VAT texture rows.
  final int startFrame;

  /// Ending frame index (inclusive) in the VAT texture rows.
  final int endFrame;

  /// Total number of discrete baked frames in this clip.
  final int frameCount;

  /// Playback frame rate in frames per second.
  final double fps;

  /// Whether the animation loops continuously.
  final bool loop;

  const VatClipInfo({
    required this.name,
    required this.startFrame,
    required this.endFrame,
    required this.frameCount,
    this.fps = 30.0,
    this.loop = true,
  });

  /// Duration of the clip in seconds.
  double get durationSeconds =>
      (frameCount > 0 && fps > 0.0) ? frameCount / fps : 0.0;

  factory VatClipInfo.fromJson(Map<String, dynamic> json) {
    final start = json['start_frame'] as int? ?? 0;
    final end = json['end_frame'] as int? ?? 0;
    final count = json['frame_count'] as int? ?? ((end - start) + 1);
    return VatClipInfo(
      name: json['name'] as String? ?? 'default',
      startFrame: start,
      endFrame: end,
      frameCount: count > 0 ? count : 1,
      fps: (json['fps'] as num?)?.toDouble() ?? 30.0,
      loop: json['loop'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'start_frame': startFrame,
        'end_frame': endFrame,
        'frame_count': frameCount,
        'fps': fps,
        'loop': loop,
      };
}

/// Full metadata describing a Vertex Animation Texture (VAT) asset.
///
/// Compatible with Blender `CrowdVATBaker` JSON output schema.
class VatMetadata {
  final String version;
  final String modelName;
  final int vertexCount;
  final int totalFrames;
  final double fps;
  final double durationSeconds;
  final int textureWidth;
  final int textureHeight;

  /// Minimum coordinate of the global animated bounding box `[x, y, z]`.
  final Float64List bboxMin;

  /// Maximum coordinate of the global animated bounding box `[x, y, z]`.
  final Float64List bboxMax;

  /// Scale vector for de-normalizing VAT coordinates `(bboxMax - bboxMin)`.
  final Float64List scale;

  /// Offset vector for de-normalizing VAT coordinates `(bboxMin)`.
  final Float64List offset;

  /// Available animation clips mapped by name.
  final Map<String, VatClipInfo> clips;

  /// Relative path or asset key for the position map texture.
  final String? positionMapPath;

  /// Relative path or asset key for the normal map texture.
  final String? normalMapPath;

  VatMetadata({
    required this.version,
    required this.modelName,
    required this.vertexCount,
    required this.totalFrames,
    required this.fps,
    required this.durationSeconds,
    required this.textureWidth,
    required this.textureHeight,
    required this.bboxMin,
    required this.bboxMax,
    required this.scale,
    required this.offset,
    required this.clips,
    this.positionMapPath,
    this.normalMapPath,
  });

  /// Factory constructor parsing standard Blender VAT JSON metadata.
  factory VatMetadata.fromJson(Map<String, dynamic> json) {
    final vCount = json['vertex_count'] as int? ?? 0;
    final tFrames = json['total_frames'] as int? ?? 1;
    final tDims = json['texture_dimensions'] as Map<String, dynamic>?;
    final texW = tDims?['width'] as int? ?? vCount;
    final texH = tDims?['height'] as int? ?? tFrames;

    final bbox = json['bounding_box'] as Map<String, dynamic>?;
    final rawMin = (bbox?['min'] as List?)?.cast<num>() ?? [-1.0, 0.0, -1.0];
    final rawMax = (bbox?['max'] as List?)?.cast<num>() ?? [1.0, 2.0, 1.0];
    final rawScale = (bbox?['scale'] as List?)?.cast<num>() ??
        [rawMax[0] - rawMin[0], rawMax[1] - rawMin[1], rawMax[2] - rawMin[2]];
    final rawOffset = (bbox?['offset'] as List?)?.cast<num>() ?? rawMin;

    final minList = Float64List(3)
      ..[0] = rawMin[0].toDouble()
      ..[1] = rawMin[1].toDouble()
      ..[2] = rawMin[2].toDouble();

    final maxList = Float64List(3)
      ..[0] = rawMax[0].toDouble()
      ..[1] = rawMax[1].toDouble()
      ..[2] = rawMax[2].toDouble();

    final scaleList = Float64List(3)
      ..[0] = rawScale[0].toDouble()
      ..[1] = rawScale[1].toDouble()
      ..[2] = rawScale[2].toDouble();

    final offsetList = Float64List(3)
      ..[0] = rawOffset[0].toDouble()
      ..[1] = rawOffset[1].toDouble()
      ..[2] = rawOffset[2].toDouble();

    final clipsMap = <String, VatClipInfo>{};
    final clipsJson = json['clips'] as List?;
    if (clipsJson != null) {
      for (final item in clipsJson) {
        if (item is Map<String, dynamic>) {
          final clip = VatClipInfo.fromJson(item);
          clipsMap[clip.name] = clip;
        }
      }
    }

    if (clipsMap.isEmpty) {
      clipsMap['default'] = VatClipInfo(
        name: 'default',
        startFrame: 0,
        endFrame: tFrames - 1,
        frameCount: tFrames,
        fps: (json['fps'] as num?)?.toDouble() ?? 30.0,
        loop: true,
      );
    }

    final textures = json['textures'] as Map<String, dynamic>?;

    return VatMetadata(
      version: json['version'] as String? ?? '1.0.0',
      modelName: json['model_name'] as String? ?? 'crowd_entity',
      vertexCount: vCount,
      totalFrames: tFrames,
      fps: (json['fps'] as num?)?.toDouble() ?? 30.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ??
          (tFrames / ((json['fps'] as num?)?.toDouble() ?? 30.0)),
      textureWidth: texW,
      textureHeight: texH,
      bboxMin: minList,
      bboxMax: maxList,
      scale: scaleList,
      offset: offsetList,
      clips: clipsMap,
      positionMapPath: textures?['position_map'] as String?,
      normalMapPath: textures?['normal_map'] as String?,
    );
  }

  /// Parses metadata from a raw JSON string.
  factory VatMetadata.fromJsonString(String jsonString) {
    return VatMetadata.fromJson(
        json.decode(jsonString) as Map<String, dynamic>);
  }

  /// Exports metadata to a standard JSON map.
  Map<String, dynamic> toJson() => {
        'version': version,
        'model_name': modelName,
        'vertex_count': vertexCount,
        'total_frames': totalFrames,
        'fps': fps,
        'duration_seconds': durationSeconds,
        'texture_dimensions': {
          'width': textureWidth,
          'height': textureHeight,
        },
        'bounding_box': {
          'min': [bboxMin[0], bboxMin[1], bboxMin[2]],
          'max': [bboxMax[0], bboxMax[1], bboxMax[2]],
          'scale': [scale[0], scale[1], scale[2]],
          'offset': [offset[0], offset[1], offset[2]],
        },
        'clips': clips.values.map((c) => c.toJson()).toList(),
        'textures': {
          if (positionMapPath != null) 'position_map': positionMapPath,
          if (normalMapPath != null) 'normal_map': normalMapPath,
        },
      };

  /// Computes normalized U coordinate (center of pixel) for a given vertex ID.
  ///
  /// Formula: `(vertexId + 0.5) / textureWidth`.
  double computeNormalizedU(int vertexId) {
    if (textureWidth <= 0) return 0.0;
    final clampedId = vertexId.clamp(0, textureWidth - 1);
    return (clampedId + 0.5) / textureWidth;
  }

  /// Computes normalized V coordinate (center of pixel) for a given frame index.
  ///
  /// Formula: `(frameIndex + 0.5) / textureHeight`.
  double computeNormalizedV(double frameIndex) {
    if (textureHeight <= 0) return 0.0;
    final clampedFrame = frameIndex.clamp(0.0, (textureHeight - 1).toDouble());
    return (clampedFrame + 0.5) / textureHeight;
  }

  /// Unpacks normalized position `[0, 1]` to local 3D model space coordinates.
  Float64List unpackPosition(double normX, double normY, double normZ) {
    final result = Float64List(3);
    result[0] = normX * scale[0] + offset[0];
    result[1] = normY * scale[1] + offset[1];
    result[2] = normZ * scale[2] + offset[2];
    return result;
  }

  /// Unpacks normalized normal `[0, 1]` to local unit vector `[-1, 1]`.
  Float64List unpackNormal(double normX, double normY, double normZ) {
    final result = Float64List(3);
    double nx = normX * 2.0 - 1.0;
    double ny = normY * 2.0 - 1.0;
    double nz = normZ * 2.0 - 1.0;
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len > 1e-6) {
      nx /= len;
      ny /= len;
      nz /= len;
    }
    result[0] = nx;
    result[1] = ny;
    result[2] = nz;
    return result;
  }

  /// Retrieves an animation clip by name with fallback to the first available clip.
  VatClipInfo getClip(String clipName) {
    return clips[clipName] ??
        clips['default'] ??
        clips.values.first;
  }
}

/// Frame-rate independent animation state with smooth sub-frame interpolation.
class VatAnimationState {
  VatClipInfo clip;
  double elapsedTime;
  double playbackSpeed;
  double phaseOffset;
  bool isFinished;

  VatAnimationState({
    required this.clip,
    this.elapsedTime = 0.0,
    this.playbackSpeed = 1.0,
    this.phaseOffset = 0.0,
    this.isFinished = false,
  });

  /// Advances animation playback time in seconds independently of render frame rate.
  void advance(double dt) {
    if (isFinished && !clip.loop) return;
    elapsedTime += dt * playbackSpeed;
    if (!clip.loop && clip.durationSeconds > 0.0) {
      if (elapsedTime >= clip.durationSeconds) {
        elapsedTime = clip.durationSeconds;
        isFinished = true;
      }
    }
  }

  /// Computes the effective time within the active clip.
  double get effectiveTime {
    final duration = clip.durationSeconds;
    if (duration <= 0.0) return 0.0;
    final totalTime = elapsedTime + phaseOffset;
    if (clip.loop) {
      return totalTime % duration;
    } else {
      return totalTime.clamp(0.0, duration);
    }
  }

  /// Computes the current floor frame index (integer).
  int get currentFrame {
    if (clip.frameCount <= 1) return clip.startFrame;
    final duration = clip.durationSeconds;
    if (duration <= 0.0) return clip.startFrame;
    final progress = (effectiveTime / duration).clamp(0.0, 1.0);
    // Maps progress across the frame count
    final rawFrame = clip.startFrame + (progress * clip.frameCount);
    final floorFrame = rawFrame.floor();
    if (clip.loop) {
      if (floorFrame > clip.endFrame) {
        return clip.startFrame;
      }
      return floorFrame.clamp(clip.startFrame, clip.endFrame);
    } else {
      return floorFrame.clamp(clip.startFrame, clip.endFrame);
    }
  }

  /// Computes the next frame index for smooth sub-frame blending.
  int get nextFrame {
    if (clip.frameCount <= 1) return clip.startFrame;
    final curr = currentFrame;
    if (curr >= clip.endFrame) {
      return clip.loop ? clip.startFrame : clip.endFrame;
    }
    return curr + 1;
  }

  /// Smooth interpolation factor `[0.0, 1.0]` between [currentFrame] and [nextFrame].
  double get lerpFactor {
    if (clip.frameCount <= 1) return 0.0;
    final duration = clip.durationSeconds;
    if (duration <= 0.0) return 0.0;
    final progress = (effectiveTime / duration).clamp(0.0, 1.0);
    final rawFrame = clip.startFrame + (progress * clip.frameCount);
    final factor = rawFrame - rawFrame.floor();
    return factor.clamp(0.0, 1.0);
  }

  /// Resets animation timing and optionally sets a new phase offset.
  void reset({double newPhaseOffset = 0.0}) {
    elapsedTime = 0.0;
    phaseOffset = newPhaseOffset;
    isFinished = false;
  }

  /// Switches active animation clip seamlessly.
  void setClip(VatClipInfo newClip, {bool preserveTime = false}) {
    clip = newClip;
    if (!preserveTime) {
      elapsedTime = 0.0;
      isFinished = false;
    }
  }
}

/// Configuration and coordinate calculations for 8-angle billboard impostor atlases.
class ImpostorAtlasConfig {
  /// Number of distinct yaw viewing angles (default: 8).
  final int angleCount;

  /// Number of horizontal columns in the atlas grid (default: 4).
  final int columns;

  /// Number of vertical rows in the atlas grid (default: 2).
  final int rows;

  const ImpostorAtlasConfig({
    this.angleCount = 8,
    this.columns = 4,
    this.rows = 2,
  });

  static const double twoPi = 2.0 * math.pi;

  /// Quantizes the relative viewing angle into an 8-angle atlas index [0 .. 7].
  ///
  /// Angles:
  /// - 0: Front (facing directly towards camera)
  /// - 1: Front-Right (45°)
  /// - 2: Right (90°)
  /// - 3: Back-Right (135°)
  /// - 4: Back (facing directly away from camera / 180°)
  /// - 5: Back-Left (225°)
  /// - 6: Left (270°)
  /// - 7: Front-Left (315°)
  int computeAngleIndex(double entityFacingYaw, double cameraYaw) {
    // Relative viewing angle in range [0, 2*PI)
    double relativeAngle = (cameraYaw - entityFacingYaw) % twoPi;
    if (relativeAngle < 0.0) {
      relativeAngle += twoPi;
    }

    final angleStep = twoPi / angleCount;
    final halfStep = angleStep * 0.5;
    final shiftedAngle = (relativeAngle + halfStep) % twoPi;
    final index = (shiftedAngle / angleStep).floor();
    return index.clamp(0, angleCount - 1);
  }

  /// Computes sub-UV texture coordinates `(uMin, vMin, uMax, vMax)` for a given angle index.
  (double, double, double, double) computeTileUVBounds(int angleIndex) {
    final clampedIndex = angleIndex.clamp(0, angleCount - 1);
    final col = clampedIndex % columns;
    final row = clampedIndex ~/ columns;

    final tileW = 1.0 / columns;
    final tileH = 1.0 / rows;

    final uMin = col * tileW;
    final vMin = row * tileH;
    final uMax = uMin + tileW;
    final vMax = vMin + tileH;

    return (uMin, vMin, uMax, vMax);
  }

  /// Transforms standard quad UV `[0, 1]` to atlas sub-region UV coordinates.
  (double, double) transformUV(int angleIndex, double u, double v) {
    final (uMin, vMin, uMax, vMax) = computeTileUVBounds(angleIndex);
    final clampedU = u.clamp(0.0, 1.0);
    final clampedV = v.clamp(0.0, 1.0);
    final finalU = uMin + clampedU * (uMax - uMin);
    final finalV = vMin + clampedV * (vMax - vMin);
    return (finalU, finalV);
  }
}

/// An individual crowd entity in the world simulation.
class CrowdEntity {
  /// Unique identifier.
  final int id;

  /// World space position (x, y, z).
  double posX;
  double posY;
  double posZ;

  /// Facing orientation in radians around the Y axis.
  double rotationY;

  /// Scale factors (scaleX, scaleY, scaleZ).
  double scaleX;
  double scaleY;
  double scaleZ;

  /// Frame-rate independent animation state controller.
  final VatAnimationState animState;

  /// Color tint multipliers (R, G, B, A).
  double tintR;
  double tintG;
  double tintB;
  double tintA;

  /// Active rendering mode (VAT Mesh vs Impostor Billboard).
  CrowdRenderMode renderMode;

  /// Bounding sphere radius in world units for culling and depth sorting.
  double boundingRadius;

  CrowdEntity({
    required this.id,
    required this.posX,
    required this.posY,
    required this.posZ,
    this.rotationY = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.scaleZ = 1.0,
    required this.animState,
    this.tintR = 1.0,
    this.tintG = 1.0,
    this.tintB = 1.0,
    this.tintA = 1.0,
    this.renderMode = CrowdRenderMode.vatMesh,
    this.boundingRadius = 1.0,
  });

  /// Factory creating an entity with a specified animation clip and random phase offset.
  factory CrowdEntity.create({
    required int id,
    required double posX,
    required double posY,
    required double posZ,
    double rotationY = 0.0,
    double scale = 1.0,
    required VatClipInfo clip,
    double playbackSpeed = 1.0,
    double phaseOffset = 0.0,
    CrowdRenderMode renderMode = CrowdRenderMode.vatMesh,
    double tintR = 1.0,
    double tintG = 1.0,
    double tintB = 1.0,
    double tintA = 1.0,
    double boundingRadius = 1.0,
  }) {
    return CrowdEntity(
      id: id,
      posX: posX,
      posY: posY,
      posZ: posZ,
      rotationY: rotationY,
      scaleX: scale,
      scaleY: scale,
      scaleZ: scale,
      animState: VatAnimationState(
        clip: clip,
        playbackSpeed: playbackSpeed,
        phaseOffset: phaseOffset,
      ),
      tintR: tintR,
      tintG: tintG,
      tintB: tintB,
      tintA: tintA,
      renderMode: renderMode,
      boundingRadius: boundingRadius,
    );
  }
}

/// Camera data required for billboard orientations and view calculations.
class CameraData {
  final double posX;
  final double posY;
  final double posZ;
  final double yaw;
  final double pitch;

  /// World space normalized right vector `[x, y, z]`.
  final Float64List rightVector;

  /// World space normalized up vector `[x, y, z]`.
  final Float64List upVector;

  /// World space normalized forward vector `[x, y, z]`.
  final Float64List forwardVector;

  CameraData({
    required this.posX,
    required this.posY,
    required this.posZ,
    required this.yaw,
    required this.pitch,
    required this.rightVector,
    required this.upVector,
    required this.forwardVector,
  });

  /// Creates camera data looking from `[posX, posY, posZ]` with yaw and pitch.
  factory CameraData.fromAngles({
    required double posX,
    required double posY,
    required double posZ,
    required double yaw,
    double pitch = 0.0,
  }) {
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);

    // Forward vector
    final fwd = Float64List(3)
      ..[0] = sinY * cosP
      ..[1] = sinP
      ..[2] = cosY * cosP;

    // Up reference
    const upX = 0.0;
    const upY = 1.0;
    const upZ = 0.0;

    // Right = Forward x Up
    double rx = fwd[1] * upZ - fwd[2] * upY;
    double ry = fwd[2] * upX - fwd[0] * upZ;
    double rz = fwd[0] * upY - fwd[1] * upX;
    final rLen = math.sqrt(rx * rx + ry * ry + rz * rz);
    if (rLen > 1e-6) {
      rx /= rLen;
      ry /= rLen;
      rz /= rLen;
    }

    final right = Float64List(3)
      ..[0] = rx
      ..[1] = ry
      ..[2] = rz;

    // True Up = Right x Forward
    double ux = ry * fwd[2] - rz * fwd[1];
    double uy = rz * fwd[0] - rx * fwd[2];
    double uz = rx * fwd[1] - ry * fwd[0];
    final uLen = math.sqrt(ux * ux + uy * uy + uz * uz);
    if (uLen > 1e-6) {
      ux /= uLen;
      uy /= uLen;
      uz /= uLen;
    }

    final up = Float64List(3)
      ..[0] = ux
      ..[1] = uy
      ..[2] = uz;

    return CameraData(
      posX: posX,
      posY: posY,
      posZ: posZ,
      yaw: yaw,
      pitch: pitch,
      rightVector: right,
      upVector: up,
      forwardVector: fwd,
    );
  }
}

/// Pre-allocated, zero-allocation instance data buffer for GPU instancing.
///
/// Buffer layout per instance (Stride = 28 floats / 112 bytes):
/// - Floats 0..15: 4x4 Column-Major Model Transformation Matrix
///   - 0..3: Column 0 (X axis rotation + scale)
///   - 4..7: Column 1 (Y axis rotation + scale)
///   - 8..11: Column 2 (Z axis rotation + scale)
///   - 12..15: Column 3 (World Position x, y, z, 1.0)
/// - Floats 16..19: Animation & Render Data
///   - 16: currentFrame (float)
///   - 17: nextFrame (float)
///   - 18: lerpFactor (float [0.0, 1.0])
///   - 19: renderMode (0.0 = VAT mesh, 1.0 = Impostor billboard)
/// - Floats 20..23: Tint & Material
///   - 20: tintR
///   - 21: tintG
///   - 22: tintB
///   - 23: tintA
/// - Floats 24..27: Extra parameters
///   - 24: boundingRadius
///   - 25: entityId
///   - 26: customFlags
///   - 27: spare
class CrowdInstanceBuffer {
  /// Number of 32-bit floats per instance.
  static const int floatsPerInstance = 28;

  /// Byte stride per instance.
  static const int bytesPerInstance = floatsPerInstance * 4;

  int _capacity;
  Float32List _buffer;

  CrowdInstanceBuffer({int initialCapacity = 10000})
      : _capacity = initialCapacity,
        _buffer = Float32List(initialCapacity * floatsPerInstance);

  int get capacity => _capacity;
  Float32List get buffer => _buffer;

  /// Ensures capacity for at least [requiredCapacity] instances without excessive allocations.
  void ensureCapacity(int requiredCapacity) {
    if (requiredCapacity <= _capacity) return;
    int newCap = _capacity * 2;
    if (newCap < requiredCapacity) {
      newCap = requiredCapacity;
    }
    final newBuffer = Float32List(newCap * floatsPerInstance);
    newBuffer.setRange(0, _buffer.length, _buffer);
    _buffer = newBuffer;
    _capacity = newCap;
  }

  /// Writes an instance into the buffer at the given index in-place with zero GC allocations.
  void packInstance({
    required int index,
    required double posX,
    required double posY,
    required double posZ,
    required double rotationY,
    required double scaleX,
    required double scaleY,
    required double scaleZ,
    required double currentFrame,
    required double nextFrame,
    required double lerpFactor,
    required double renderMode,
    required double tintR,
    required double tintG,
    required double tintB,
    required double tintA,
    double boundingRadius = 1.0,
    double entityId = 0.0,
    double customFlags = 0.0,
  }) {
    final offset = index * floatsPerInstance;

    // Fast column-major 4x4 matrix for position + yaw rotation + non-uniform scale
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);

    // Column 0
    _buffer[offset + 0] = (cosY * scaleX).toDouble();
    _buffer[offset + 1] = 0.0;
    _buffer[offset + 2] = (-sinY * scaleX).toDouble();
    _buffer[offset + 3] = 0.0;

    // Column 1
    _buffer[offset + 4] = 0.0;
    _buffer[offset + 5] = scaleY.toDouble();
    _buffer[offset + 6] = 0.0;
    _buffer[offset + 7] = 0.0;

    // Column 2
    _buffer[offset + 8] = (sinY * scaleZ).toDouble();
    _buffer[offset + 9] = 0.0;
    _buffer[offset + 10] = (cosY * scaleZ).toDouble();
    _buffer[offset + 11] = 0.0;

    // Column 3 (Translation)
    _buffer[offset + 12] = posX.toDouble();
    _buffer[offset + 13] = posY.toDouble();
    _buffer[offset + 14] = posZ.toDouble();
    _buffer[offset + 15] = 1.0;

    // Animation & Render Data
    _buffer[offset + 16] = currentFrame;
    _buffer[offset + 17] = nextFrame;
    _buffer[offset + 18] = lerpFactor;
    _buffer[offset + 19] = renderMode;

    // Tint
    _buffer[offset + 20] = tintR;
    _buffer[offset + 21] = tintG;
    _buffer[offset + 22] = tintB;
    _buffer[offset + 23] = tintA;

    // Extra
    _buffer[offset + 24] = boundingRadius;
    _buffer[offset + 25] = entityId;
    _buffer[offset + 26] = customFlags;
    _buffer[offset + 27] = 0.0;
  }
}

/// Represents the completed single draw call batch for thousands of crowd entities.
class CrowdDrawCallBatch {
  /// Total number of active instances packed in this batch.
  final int instanceCount;

  /// Number of draw calls generated. Strictly guaranteed to be 1 per R4 requirement.
  final int drawCallCount;

  /// Raw instance data buffer ready for GPU upload (`glBufferSubData` / Vulkan vertex buffer).
  final Float32List instanceData;

  /// Active byte length of the instance buffer to upload.
  final int bufferByteLength;

  /// Float stride per instance (28).
  final int strideFloats;

  /// Mesh vertex count per instance (e.g. 120 vertices for VAT mesh, or 4 for billboard quad).
  final int vertexCountPerInstance;

  /// VAT metadata associated with this draw call batch.
  final VatMetadata vatMetadata;

  /// Time taken in microseconds to step animations and pack the GPU buffer.
  final int packingTimeMicros;

  const CrowdDrawCallBatch({
    required this.instanceCount,
    this.drawCallCount = 1,
    required this.instanceData,
    required this.bufferByteLength,
    required this.strideFloats,
    required this.vertexCountPerInstance,
    required this.vatMetadata,
    required this.packingTimeMicros,
  });

  /// Total virtual vertices processed by the GPU in this single draw call.
  int get totalGpuVertices => instanceCount * vertexCountPerInstance;

  /// Total memory footprint of this batch in kilobytes.
  double get memoryKBytes => bufferByteLength / 1024.0;
}

/// Production-ready Vertex Animated Texture (VAT) & Impostor Crowd Renderer.
///
/// Designed for 10,000+ distant entities rendered in a single draw call.
class VatCrowdRenderer {
  final VatMetadata metadata;
  final ImpostorAtlasConfig impostorConfig;
  final CrowdInstanceBuffer instanceBuffer;

  /// Statistics tracking for performance monitoring.
  int _lastActiveInstances = 0;
  int _lastPackingMicros = 0;
  int _totalBatchesGenerated = 0;

  VatCrowdRenderer({
    required this.metadata,
    ImpostorAtlasConfig? impostorConfig,
    int initialCapacity = 10000,
  })  : impostorConfig = impostorConfig ?? const ImpostorAtlasConfig(),
        instanceBuffer = CrowdInstanceBuffer(initialCapacity: initialCapacity);

  int get lastActiveInstances => _lastActiveInstances;
  int get lastPackingMicros => _lastPackingMicros;
  int get totalBatchesGenerated => _totalBatchesGenerated;

  /// Updates animation timing, evaluates sub-frame interpolation, and packs
  /// all crowd entities into a single GPU instance buffer for rendering.
  CrowdDrawCallBatch renderCrowd({
    required List<CrowdEntity> entities,
    required double deltaTime,
    required CameraData camera,
    bool advanceAnimations = true,
  }) {
    final stopwatch = Stopwatch()..start();

    final count = entities.length;
    instanceBuffer.ensureCapacity(count);

    for (int i = 0; i < count; i++) {
      final entity = entities[i];

      // 1. Advance animation independently of frame rate
      if (advanceAnimations) {
        entity.animState.advance(deltaTime);
      }

      final animState = entity.animState;
      final currFrame = animState.currentFrame.toDouble();
      final nextFrame = animState.nextFrame.toDouble();
      final lerp = animState.lerpFactor;

      final isImpostor = entity.renderMode == CrowdRenderMode.impostorBillboard;
      final modeVal = isImpostor ? 1.0 : 0.0;

      // 2. Pack instance directly into preallocated typed buffer
      instanceBuffer.packInstance(
        index: i,
        posX: entity.posX,
        posY: entity.posY,
        posZ: entity.posZ,
        rotationY: entity.rotationY,
        scaleX: entity.scaleX,
        scaleY: entity.scaleY,
        scaleZ: entity.scaleZ,
        currentFrame: currFrame,
        nextFrame: nextFrame,
        lerpFactor: lerp,
        renderMode: modeVal,
        tintR: entity.tintR,
        tintG: entity.tintG,
        tintB: entity.tintB,
        tintA: entity.tintA,
        boundingRadius: entity.boundingRadius,
        entityId: entity.id.toDouble(),
      );
    }

    stopwatch.stop();

    _lastActiveInstances = count;
    _lastPackingMicros = stopwatch.elapsedMicroseconds;
    _totalBatchesGenerated++;

    final activeFloats = count * CrowdInstanceBuffer.floatsPerInstance;
    final activeBytes = activeFloats * 4;

    return CrowdDrawCallBatch(
      instanceCount: count,
      drawCallCount: 1, // Single draw call guarantee
      instanceData: instanceBuffer.buffer,
      bufferByteLength: activeBytes,
      strideFloats: CrowdInstanceBuffer.floatsPerInstance,
      vertexCountPerInstance: metadata.vertexCount,
      vatMetadata: metadata,
      packingTimeMicros: stopwatch.elapsedMicroseconds,
    );
  }

  /// Calculates the spherical billboard orientation matrix for an impostor quad.
  ///
  /// Quad normal points towards camera, right aligned with camera right,
  /// up aligned with camera up.
  static Float32List computeSphericalBillboardQuad({
    required double centerX,
    required double centerY,
    required double centerZ,
    required double width,
    required double height,
    required CameraData camera,
  }) {
    // 4 quad vertices (x, y, z) each: Top-Left, Bottom-Left, Top-Right, Bottom-Right
    final vertices = Float32List(12);

    final halfW = width * 0.5;
    final halfH = height * 0.5;

    final rx = camera.rightVector[0];
    final ry = camera.rightVector[1];
    final rz = camera.rightVector[2];

    final ux = camera.upVector[0];
    final uy = camera.upVector[1];
    final uz = camera.upVector[2];

    // V0: Top-Left (-halfW, +halfH)
    vertices[0] = (centerX - rx * halfW + ux * halfH).toDouble();
    vertices[1] = (centerY - ry * halfW + uy * halfH).toDouble();
    vertices[2] = (centerZ - rz * halfW + uz * halfH).toDouble();

    // V1: Bottom-Left (-halfW, -halfH)
    vertices[3] = (centerX - rx * halfW - ux * halfH).toDouble();
    vertices[4] = (centerY - ry * halfW - uy * halfH).toDouble();
    vertices[5] = (centerZ - rz * halfW - uz * halfH).toDouble();

    // V2: Top-Right (+halfW, +halfH)
    vertices[6] = (centerX + rx * halfW + ux * halfH).toDouble();
    vertices[7] = (centerY + ry * halfW + uy * halfH).toDouble();
    vertices[8] = (centerZ + rz * halfW + uz * halfH).toDouble();

    // V3: Bottom-Right (+halfW, -halfH)
    vertices[9] = (centerX + rx * halfW - ux * halfH).toDouble();
    vertices[10] = (centerY + ry * halfW - uy * halfH).toDouble();
    vertices[11] = (centerZ + rz * halfW - uz * halfH).toDouble();

    return vertices;
  }
}
