import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/vat_crowd_renderer.dart';

void main() {
  group('VatMetadata & Texture Coordinate Math', () {
    late VatMetadata metadata;

    setUp(() {
      metadata = VatMetadata.fromJson({
        'version': '1.0.0',
        'model_name': 'soldier_standard_crowd',
        'vertex_count': 120,
        'total_frames': 60,
        'fps': 30.0,
        'duration_seconds': 2.0,
        'texture_dimensions': {
          'width': 120,
          'height': 60,
        },
        'bounding_box': {
          'min': [-0.6, 0.0, -0.6],
          'max': [0.6, 1.8, 0.6],
          'scale': [1.2, 1.8, 1.2],
          'offset': [-0.6, 0.0, -0.6],
        },
        'clips': [
          {
            'name': 'walk',
            'start_frame': 0,
            'end_frame': 29,
            'frame_count': 30,
            'fps': 30.0,
            'loop': true,
          },
          {
            'name': 'attack',
            'start_frame': 30,
            'end_frame': 59,
            'frame_count': 30,
            'fps': 30.0,
            'loop': false,
          },
        ],
        'textures': {
          'position_map': 'soldier_standard_crowd_vat_pos.png',
          'normal_map': 'soldier_standard_crowd_vat_norm.png',
        },
      });
    });

    test('metadata correctly parses dimensions, bounding box, and clips', () {
      expect(metadata.vertexCount, equals(120));
      expect(metadata.totalFrames, equals(60));
      expect(metadata.textureWidth, equals(120));
      expect(metadata.textureHeight, equals(60));
      expect(metadata.durationSeconds, equals(2.0));
      expect(metadata.fps, equals(30.0));
      expect(metadata.clips.length, equals(2));

      final walk = metadata.getClip('walk');
      expect(walk.name, equals('walk'));
      expect(walk.startFrame, equals(0));
      expect(walk.endFrame, equals(29));
      expect(walk.frameCount, equals(30));
      expect(walk.durationSeconds, closeTo(1.0, 1e-5));
      expect(walk.loop, isTrue);

      final attack = metadata.getClip('attack');
      expect(attack.name, equals('attack'));
      expect(attack.startFrame, equals(30));
      expect(attack.endFrame, equals(59));
      expect(attack.loop, isFalse);
    });

    test('VatMetadata.fromJsonString parses raw JSON string accurately', () {
      final jsonStr = json.encode({
        'version': '1.0.1',
        'model_name': 'archer_crowd',
        'vertex_count': 85,
        'total_frames': 45,
        'fps': 30.0,
        'duration_seconds': 1.5,
        'texture_dimensions': {'width': 85, 'height': 45},
        'bounding_box': {
          'min': [-0.5, 0.0, -0.5],
          'max': [0.5, 1.7, 0.5],
        },
        'clips': [
          {
            'name': 'idle',
            'start_frame': 0,
            'end_frame': 44,
            'frame_count': 45,
          }
        ]
      });

      final parsed = VatMetadata.fromJsonString(jsonStr);
      expect(parsed.version, equals('1.0.1'));
      expect(parsed.modelName, equals('archer_crowd'));
      expect(parsed.vertexCount, equals(85));
      expect(parsed.totalFrames, equals(45));
      expect(parsed.getClip('idle').frameCount, equals(45));
    });

    test('metadata defaults when optional fields are omitted in JSON', () {
      final minimal = VatMetadata.fromJson({
        'vertex_count': 50,
        'total_frames': 30,
      });

      expect(minimal.version, equals('1.0.0'));
      expect(minimal.modelName, equals('crowd_entity'));
      expect(minimal.vertexCount, equals(50));
      expect(minimal.totalFrames, equals(30));
      expect(minimal.textureWidth, equals(50));
      expect(minimal.textureHeight, equals(30));
      // Default bbox: min [-1, 0, -1], max [1, 2, 1], scale [2, 2, 2]
      expect(minimal.bboxMin[0], closeTo(-1.0, 1e-5));
      expect(minimal.bboxMax[1], closeTo(2.0, 1e-5));
      expect(minimal.scale[0], closeTo(2.0, 1e-5));
      // Default clip created
      expect(minimal.clips.containsKey('default'), isTrue);
      expect(minimal.getClip('default').frameCount, equals(30));
    });

    test('computeNormalizedU samples exact center of texel', () {
      // First texel (vertex 0): (0 + 0.5) / 120 = 0.5 / 120
      final u0 = metadata.computeNormalizedU(0);
      expect(u0, closeTo(0.5 / 120.0, 1e-6));

      // Middle texel (vertex 60): (60 + 0.5) / 120 = 60.5 / 120
      final u60 = metadata.computeNormalizedU(60);
      expect(u60, closeTo(60.5 / 120.0, 1e-6));

      // Last texel (vertex 119): (119 + 0.5) / 120 = 119.5 / 120
      final u119 = metadata.computeNormalizedU(119);
      expect(u119, closeTo(119.5 / 120.0, 1e-6));

      // Boundary clamping
      expect(metadata.computeNormalizedU(-5), equals(u0));
      expect(metadata.computeNormalizedU(999), equals(u119));
    });

    test('computeNormalizedU returns 0.0 when textureWidth <= 0', () {
      final zeroWidth = VatMetadata.fromJson({
        'vertex_count': 0,
        'total_frames': 30,
        'texture_dimensions': {'width': 0, 'height': 30},
      });
      expect(zeroWidth.computeNormalizedU(5), equals(0.0));
    });

    test('computeNormalizedV samples exact center of frame row', () {
      // First frame (frame 0): (0 + 0.5) / 60
      final v0 = metadata.computeNormalizedV(0.0);
      expect(v0, closeTo(0.5 / 60.0, 1e-6));

      // Middle frame (frame 30): (30 + 0.5) / 60
      final v30 = metadata.computeNormalizedV(30.0);
      expect(v30, closeTo(30.5 / 60.0, 1e-6));

      // Last frame (frame 59): (59 + 0.5) / 60
      final v59 = metadata.computeNormalizedV(59.0);
      expect(v59, closeTo(59.5 / 60.0, 1e-6));

      // Fractional sub-frame: (15.5 + 0.5) / 60 = 16.0 / 60
      final vFrac = metadata.computeNormalizedV(15.5);
      expect(vFrac, closeTo(16.0 / 60.0, 1e-6));
    });

    test('computeNormalizedV returns 0.0 when textureHeight <= 0', () {
      final zeroHeight = VatMetadata.fromJson({
        'vertex_count': 30,
        'total_frames': 0,
        'texture_dimensions': {'width': 30, 'height': 0},
      });
      expect(zeroHeight.computeNormalizedV(5.0), equals(0.0));
    });

    test('unpackPosition restores local bounding box space accurately', () {
      // Normalized [0, 0, 0] should map to bboxMin
      final pMin = metadata.unpackPosition(0.0, 0.0, 0.0);
      expect(pMin[0], closeTo(-0.6, 1e-5));
      expect(pMin[1], closeTo(0.0, 1e-5));
      expect(pMin[2], closeTo(-0.6, 1e-5));

      // Normalized [1, 1, 1] should map to bboxMax
      final pMax = metadata.unpackPosition(1.0, 1.0, 1.0);
      expect(pMax[0], closeTo(0.6, 1e-5));
      expect(pMax[1], closeTo(1.8, 1e-5));
      expect(pMax[2], closeTo(0.6, 1e-5));

      // Normalized [0.5, 0.5, 0.5] should map to center
      final pCenter = metadata.unpackPosition(0.5, 0.5, 0.5);
      expect(pCenter[0], closeTo(0.0, 1e-5));
      expect(pCenter[1], closeTo(0.9, 1e-5));
      expect(pCenter[2], closeTo(0.0, 1e-5));
    });

    test('unpackNormal unpacks and normalizes unit vectors', () {
      // Norm [0.5, 1.0, 0.5] -> [0, 1, 0] (Up vector)
      final nUp = metadata.unpackNormal(0.5, 1.0, 0.5);
      expect(nUp[0], closeTo(0.0, 1e-4));
      expect(nUp[1], closeTo(1.0, 1e-4));
      expect(nUp[2], closeTo(0.0, 1e-4));

      // Norm [1.0, 0.5, 0.5] -> [1, 0, 0] (Right vector)
      final nRight = metadata.unpackNormal(1.0, 0.5, 0.5);
      expect(nRight[0], closeTo(1.0, 1e-4));
      expect(nRight[1], closeTo(0.0, 1e-4));
      expect(nRight[2], closeTo(0.0, 1e-4));

      // Length of unpacked normal must always equal 1.0
      final len = math.sqrt(nUp[0] * nUp[0] + nUp[1] * nUp[1] + nUp[2] * nUp[2]);
      expect(len, closeTo(1.0, 1e-5));
    });

    test('unpackNormal handles zero-vector gracefully without NaN or div-by-zero', () {
      // Norm [0.5, 0.5, 0.5] yields raw nx=0, ny=0, nz=0 (length = 0)
      final zeroNorm = metadata.unpackNormal(0.5, 0.5, 0.5);
      expect(zeroNorm[0], equals(0.0));
      expect(zeroNorm[1], equals(0.0));
      expect(zeroNorm[2], equals(0.0));
      expect(zeroNorm[0].isNaN, isFalse);
    });

    test('getClip retrieves clip by name with fallback to default or first clip', () {
      // Existing clip
      expect(metadata.getClip('walk').name, equals('walk'));

      // Non-existent clip falls back to first available or default
      final fallback = metadata.getClip('non_existent_clip_xyz');
      expect(fallback, isNotNull);
      expect(fallback.name, equals('walk')); // First clip in metadata
    });

    test('round-trip JSON serialization preserves all metadata properties', () {
      final jsonMap = metadata.toJson();
      final roundTrip = VatMetadata.fromJson(jsonMap);

      expect(roundTrip.modelName, equals(metadata.modelName));
      expect(roundTrip.vertexCount, equals(metadata.vertexCount));
      expect(roundTrip.totalFrames, equals(metadata.totalFrames));
      expect(roundTrip.scale[0], closeTo(metadata.scale[0], 1e-5));
      expect(roundTrip.scale[1], closeTo(metadata.scale[1], 1e-5));
      expect(roundTrip.scale[2], closeTo(metadata.scale[2], 1e-5));
      expect(roundTrip.clips.keys, equals(metadata.clips.keys));
      expect(roundTrip.positionMapPath, equals('soldier_standard_crowd_vat_pos.png'));
      expect(roundTrip.normalMapPath, equals('soldier_standard_crowd_vat_norm.png'));
    });

    test('VatClipInfo duration calculation handles edge cases', () {
      // Normal clip
      const clipNormal = VatClipInfo(
        name: 'run',
        startFrame: 0,
        endFrame: 29,
        frameCount: 30,
        fps: 30.0,
      );
      expect(clipNormal.durationSeconds, closeTo(1.0, 1e-5));

      // Zero or negative frameCount / fps
      const clipZeroCount = VatClipInfo(
        name: 'invalid_count',
        startFrame: 0,
        endFrame: 0,
        frameCount: 0,
        fps: 30.0,
      );
      expect(clipZeroCount.durationSeconds, equals(0.0));

      const clipZeroFps = VatClipInfo(
        name: 'invalid_fps',
        startFrame: 0,
        endFrame: 10,
        frameCount: 11,
        fps: 0.0,
      );
      expect(clipZeroFps.durationSeconds, equals(0.0));
    });
  });

  group('Animation Timing & Smooth Interpolation', () {
    late VatClipInfo loopClip;
    late VatClipInfo clampClip;

    setUp(() {
      loopClip = const VatClipInfo(
        name: 'run',
        startFrame: 0,
        endFrame: 29,
        frameCount: 30,
        fps: 30.0,
        loop: true,
      ); // 1.0 second duration

      clampClip = const VatClipInfo(
        name: 'death',
        startFrame: 0,
        endFrame: 14,
        frameCount: 15,
        fps: 30.0,
        loop: false,
      ); // 0.5 second duration
    });

    test('frame-rate independent progression matches elapsed time', () {
      final anim = VatAnimationState(clip: loopClip);

      // At t = 0.0s -> frame 0, next 1, lerp 0.0
      expect(anim.currentFrame, equals(0));
      expect(anim.nextFrame, equals(1));
      expect(anim.lerpFactor, closeTo(0.0, 1e-5));

      // Advance by 16.666ms (60 FPS tick) -> progress = 0.016666 / 1.0 = 0.5 frames
      anim.advance(1.0 / 60.0);
      expect(anim.currentFrame, equals(0));
      expect(anim.nextFrame, equals(1));
      expect(anim.lerpFactor, closeTo(0.5, 1e-2));

      // Advance another 16.666ms -> total 33.33ms = exactly 1 frame at 30 FPS
      anim.advance(1.0 / 60.0);
      expect(anim.currentFrame, equals(1));
      expect(anim.nextFrame, equals(2));
      expect(anim.lerpFactor, closeTo(0.0, 1e-2));
    });

    test('smooth loop wrapping from endFrame back to startFrame', () {
      final anim = VatAnimationState(clip: loopClip);

      // Advance to near end: t = 29.5 / 30.0 s
      anim.advance(29.5 / 30.0);
      expect(anim.currentFrame, equals(29));
      expect(anim.nextFrame, equals(0)); // Loops back to startFrame (0)!
      expect(anim.lerpFactor, closeTo(0.5, 1e-2));

      // Advance past end to wrap around: t = 30.2 / 30.0 s -> wraps to frame 0
      anim.advance(0.7 / 30.0);
      expect(anim.currentFrame, equals(0));
      expect(anim.nextFrame, equals(1));
      expect(anim.lerpFactor, closeTo(0.2, 1e-2));
    });

    test('non-looping animation clamps at endFrame and marks isFinished', () {
      final anim = VatAnimationState(clip: clampClip);

      // Advance past duration (0.5s)
      anim.advance(1.2);
      expect(anim.isFinished, isTrue);
      expect(anim.elapsedTime, closeTo(0.5, 1e-5));
      expect(anim.currentFrame, equals(14));
      expect(anim.nextFrame, equals(14));
      expect(anim.lerpFactor, closeTo(0.0, 1e-5));
    });

    test('advancing already-finished non-looping animation does not alter state', () {
      final anim = VatAnimationState(clip: clampClip);
      anim.advance(0.8);
      expect(anim.isFinished, isTrue);
      final recordedTime = anim.elapsedTime;

      // Re-advance after finish
      anim.advance(0.5);
      expect(anim.elapsedTime, equals(recordedTime));
      expect(anim.isFinished, isTrue);
    });

    test('phase offsets prevent synchronized crowd lockstep', () {
      const entityCount = 10;
      final animations = List.generate(entityCount, (i) {
        final phase = (i / entityCount) * loopClip.durationSeconds;
        return VatAnimationState(clip: loopClip, phaseOffset: phase);
      });

      // Collect initial frames across all 10 entities
      final initialFrames = animations.map((a) => a.currentFrame).toSet();
      // Should have multiple distinct frames distributed across the clip, not all 0!
      expect(initialFrames.length, greaterThan(5));

      // Advance all by identical dt
      for (final a in animations) {
        a.advance(0.2);
      }
      final advancedFrames = animations.map((a) => a.currentFrame).toSet();
      expect(advancedFrames.length, greaterThan(5));
    });

    test('playback speed scaling works correctly', () {
      final animSlow = VatAnimationState(clip: loopClip, playbackSpeed: 0.5);
      final animFast = VatAnimationState(clip: loopClip, playbackSpeed: 2.0);

      animSlow.advance(0.2);
      animFast.advance(0.2);

      // Slow: 0.2 * 0.5 = 0.1s -> frame 3
      // Fast: 0.2 * 2.0 = 0.4s -> frame 12
      expect(animSlow.currentFrame, equals(3));
      expect(animFast.currentFrame, equals(12));
    });

    test('reset restores initial state and sets new phase offset', () {
      final anim = VatAnimationState(clip: clampClip);
      anim.advance(0.6);
      expect(anim.isFinished, isTrue);

      anim.reset(newPhaseOffset: 0.15);
      expect(anim.elapsedTime, equals(0.0));
      expect(anim.phaseOffset, closeTo(0.15, 1e-5));
      expect(anim.isFinished, isFalse);
    });

    test('setClip switches clips with and without preserving elapsed time', () {
      final anim = VatAnimationState(clip: loopClip);
      anim.advance(0.4);

      // Switch clip preserving time
      anim.setClip(clampClip, preserveTime: true);
      expect(anim.clip.name, equals('death'));
      expect(anim.elapsedTime, closeTo(0.4, 1e-5));

      // Switch clip resetting time
      anim.setClip(loopClip, preserveTime: false);
      expect(anim.clip.name, equals('run'));
      expect(anim.elapsedTime, equals(0.0));
      expect(anim.isFinished, isFalse);
    });

    test('single-frame clip returns startFrame and zero lerpFactor', () {
      const singlePoseClip = VatClipInfo(
        name: 'statue',
        startFrame: 7,
        endFrame: 7,
        frameCount: 1,
        fps: 30.0,
      );
      final anim = VatAnimationState(clip: singlePoseClip);
      expect(anim.currentFrame, equals(7));
      expect(anim.nextFrame, equals(7));
      expect(anim.lerpFactor, equals(0.0));

      anim.advance(1.0);
      expect(anim.currentFrame, equals(7));
      expect(anim.nextFrame, equals(7));
      expect(anim.lerpFactor, equals(0.0));
    });
  });

  group('8-Angle Impostor Billboard Math', () {
    late ImpostorAtlasConfig config;

    setUp(() {
      config = const ImpostorAtlasConfig(angleCount: 8, columns: 4, rows: 2);
    });

    test('computeAngleIndex maps 8 cardinal and intercardinal orientations', () {
      const cameraYaw = 0.0; // Camera facing North (+Z)

      // Entity facing directly towards camera (relative angle 0) -> Angle 0 (Front)
      expect(config.computeAngleIndex(0.0, cameraYaw), equals(0));

      // Entity rotated 45 degrees counter-clockwise (pi/4) -> relative 315° -> Angle 7 (Front-Left)
      expect(config.computeAngleIndex(math.pi / 4.0, cameraYaw), equals(7));

      // Entity rotated 45 degrees clockwise (-pi/4) -> relative 45° -> Angle 1 (Front-Right)
      expect(config.computeAngleIndex(-math.pi / 4.0, cameraYaw), equals(1));

      // Entity rotated 90 degrees counter-clockwise (pi/2) -> relative 270° -> Angle 6 (Left)
      expect(config.computeAngleIndex(math.pi / 2.0, cameraYaw), equals(6));

      // Entity rotated 90 degrees clockwise (-pi/2) -> relative 90° -> Angle 2 (Right)
      expect(config.computeAngleIndex(-math.pi / 2.0, cameraYaw), equals(2));

      // Entity facing directly away from camera (180 degrees / pi) -> relative 180° -> Angle 4 (Back)
      expect(config.computeAngleIndex(math.pi, cameraYaw), equals(4));
    });

    test('computeAngleIndex handles angles beyond 2*pi and negative wrap', () {
      const cameraYaw = 0.0;
      // 360 degrees rotation is equivalent to 0
      expect(config.computeAngleIndex(2.0 * math.pi, cameraYaw), equals(0));
      // -360 degrees rotation is equivalent to 0
      expect(config.computeAngleIndex(-2.0 * math.pi, cameraYaw), equals(0));
      // Full circle + 180 degrees
      expect(config.computeAngleIndex(3.0 * math.pi, cameraYaw), equals(4));
    });

    test('atlas sub-UV tile bounds correctly partitioned into 4x2 grid', () {
      // Angle 0: col 0, row 0 -> u: [0.0, 0.25], v: [0.0, 0.5]
      final (u0Min, v0Min, u0Max, v0Max) = config.computeTileUVBounds(0);
      expect(u0Min, closeTo(0.0, 1e-5));
      expect(v0Min, closeTo(0.0, 1e-5));
      expect(u0Max, closeTo(0.25, 1e-5));
      expect(v0Max, closeTo(0.5, 1e-5));

      // Angle 3: col 3, row 0 -> u: [0.75, 1.0], v: [0.0, 0.5]
      final (u3Min, v3Min, u3Max, v3Max) = config.computeTileUVBounds(3);
      expect(u3Min, closeTo(0.75, 1e-5));
      expect(v3Min, closeTo(0.0, 1e-5));
      expect(u3Max, closeTo(1.0, 1e-5));
      expect(v3Max, closeTo(0.5, 1e-5));

      // Angle 4: col 0, row 1 -> u: [0.0, 0.25], v: [0.5, 1.0]
      final (u4Min, v4Min, u4Max, v4Max) = config.computeTileUVBounds(4);
      expect(u4Min, closeTo(0.0, 1e-5));
      expect(v4Min, closeTo(0.5, 1e-5));
      expect(u4Max, closeTo(0.25, 1e-5));
      expect(v4Max, closeTo(1.0, 1e-5));

      // Angle 7: col 3, row 1 -> u: [0.75, 1.0], v: [0.5, 1.0]
      final (u7Min, v7Min, u7Max, v7Max) = config.computeTileUVBounds(7);
      expect(u7Min, closeTo(0.75, 1e-5));
      expect(v7Min, closeTo(0.5, 1e-5));
      expect(u7Max, closeTo(1.0, 1e-5));
      expect(v7Max, closeTo(1.0, 1e-5));
    });

    test('transformUV maps local quad coordinates [0, 1] into atlas tile', () {
      // Quad center [0.5, 0.5] in Tile 0 -> [0.125, 0.25]
      final (uMid, vMid) = config.transformUV(0, 0.5, 0.5);
      expect(uMid, closeTo(0.125, 1e-5));
      expect(vMid, closeTo(0.25, 1e-5));
    });

    test('spherical billboard quad vertices are perpendicular to view direction', () {
      final camera = CameraData.fromAngles(
        posX: 0.0,
        posY: 10.0,
        posZ: -20.0,
        yaw: 0.0,
        pitch: -0.3,
      );

      final quad = VatCrowdRenderer.computeSphericalBillboardQuad(
        centerX: 5.0,
        centerY: 2.0,
        centerZ: 10.0,
        width: 2.0,
        height: 3.0,
        camera: camera,
      );

      expect(quad.length, equals(12)); // 4 vertices * 3 coords

      // Verify quad width: distance between top-left (V0: 0,1,2) and top-right (V2: 6,7,8)
      final dxW = quad[6] - quad[0];
      final dyW = quad[7] - quad[1];
      final dzW = quad[8] - quad[2];
      final width = math.sqrt(dxW * dxW + dyW * dyW + dzW * dzW);
      expect(width, closeTo(2.0, 1e-4));

      // Verify quad height: distance between top-left (V0: 0,1,2) and bottom-left (V1: 3,4,5)
      final dxH = quad[0] - quad[3];
      final dyH = quad[1] - quad[4];
      final dzH = quad[2] - quad[5];
      final height = math.sqrt(dxH * dxH + dyH * dyH + dzH * dzH);
      expect(height, closeTo(3.0, 1e-4));
    });
  });

  group('Camera Data & Vector Math', () {
    test('CameraData.fromAngles produces unit length and orthogonal basis vectors', () {
      final camera = CameraData.fromAngles(
        posX: 10.0,
        posY: 5.0,
        posZ: -30.0,
        yaw: math.pi / 3.0,
        pitch: -math.pi / 6.0,
      );

      final fwd = camera.forwardVector;
      final right = camera.rightVector;
      final up = camera.upVector;

      // Unit lengths
      final fwdLen = math.sqrt(fwd[0] * fwd[0] + fwd[1] * fwd[1] + fwd[2] * fwd[2]);
      final rightLen = math.sqrt(right[0] * right[0] + right[1] * right[1] + right[2] * right[2]);
      final upLen = math.sqrt(up[0] * up[0] + up[1] * up[1] + up[2] * up[2]);
      expect(fwdLen, closeTo(1.0, 1e-4));
      expect(rightLen, closeTo(1.0, 1e-4));
      expect(upLen, closeTo(1.0, 1e-4));

      // Mutual orthogonality (dot product = 0)
      final dotFwdRight = fwd[0] * right[0] + fwd[1] * right[1] + fwd[2] * right[2];
      final dotFwdUp = fwd[0] * up[0] + fwd[1] * up[1] + fwd[2] * up[2];
      final dotRightUp = right[0] * up[0] + right[1] * up[1] + right[2] * up[2];
      expect(dotFwdRight, closeTo(0.0, 1e-4));
      expect(dotFwdUp, closeTo(0.0, 1e-4));
      expect(dotRightUp, closeTo(0.0, 1e-4));
    });
  });

  group('Instance Buffer Layout & GPU Instancing Generation', () {
    late CrowdInstanceBuffer buffer;

    setUp(() {
      buffer = CrowdInstanceBuffer(initialCapacity: 100);
    });

    test('buffer stride is exactly 28 floats (112 bytes) per instance', () {
      expect(CrowdInstanceBuffer.floatsPerInstance, equals(28));
      expect(CrowdInstanceBuffer.bytesPerInstance, equals(112));
      expect(buffer.buffer.length, equals(100 * 28));
    });

    test('packInstance encodes column-major matrix and parameters accurately', () {
      buffer.packInstance(
        index: 0,
        posX: 12.5,
        posY: 3.0,
        posZ: -45.0,
        rotationY: math.pi / 2.0, // 90 deg yaw
        scaleX: 2.0,
        scaleY: 1.5,
        scaleZ: 2.0,
        currentFrame: 10.0,
        nextFrame: 11.0,
        lerpFactor: 0.45,
        renderMode: 0.0, // VAT mesh
        tintR: 0.8,
        tintG: 0.9,
        tintB: 1.0,
        tintA: 1.0,
        boundingRadius: 1.25,
        entityId: 42.0,
        customFlags: 7.0,
      );

      final b = buffer.buffer;

      // Col 0: [cos(90)*2, 0, -sin(90)*2, 0] = [0, 0, -2, 0]
      expect(b[0], closeTo(0.0, 1e-4));
      expect(b[1], equals(0.0));
      expect(b[2], closeTo(-2.0, 1e-4));
      expect(b[3], equals(0.0));

      // Col 1: [0, scaleY, 0, 0] = [0, 1.5, 0, 0]
      expect(b[4], equals(0.0));
      expect(b[5], closeTo(1.5, 1e-4));
      expect(b[6], equals(0.0));
      expect(b[7], equals(0.0));

      // Col 2: [sin(90)*2, 0, cos(90)*2, 0] = [2, 0, 0, 0]
      expect(b[8], closeTo(2.0, 1e-4));
      expect(b[9], equals(0.0));
      expect(b[10], closeTo(0.0, 1e-4));
      expect(b[11], equals(0.0));

      // Col 3 (Translation): [12.5, 3.0, -45.0, 1.0]
      expect(b[12], closeTo(12.5, 1e-4));
      expect(b[13], closeTo(3.0, 1e-4));
      expect(b[14], closeTo(-45.0, 1e-4));
      expect(b[15], equals(1.0));

      // Animation & Render Data
      expect(b[16], equals(10.0)); // currentFrame
      expect(b[17], equals(11.0)); // nextFrame
      expect(b[18], closeTo(0.45, 1e-4)); // lerpFactor
      expect(b[19], equals(0.0)); // renderMode

      // Tint
      expect(b[20], closeTo(0.8, 1e-4));
      expect(b[21], closeTo(0.9, 1e-4));
      expect(b[22], closeTo(1.0, 1e-4));
      expect(b[23], closeTo(1.0, 1e-4));

      // Extra
      expect(b[24], closeTo(1.25, 1e-4)); // boundingRadius
      expect(b[25], equals(42.0)); // entityId
      expect(b[26], equals(7.0)); // customFlags
      expect(b[27], equals(0.0)); // spare
    });

    test('buffer expands dynamically when capacity is exceeded and preserves existing data', () {
      expect(buffer.capacity, equals(100));

      // Write test data to index 0
      buffer.packInstance(
        index: 0,
        posX: 99.0,
        posY: 1.0,
        posZ: -10.0,
        rotationY: 0.0,
        scaleX: 1.0,
        scaleY: 1.0,
        scaleZ: 1.0,
        currentFrame: 1.0,
        nextFrame: 2.0,
        lerpFactor: 0.0,
        renderMode: 0.0,
        tintR: 1.0,
        tintG: 1.0,
        tintB: 1.0,
        tintA: 1.0,
      );

      buffer.ensureCapacity(250);
      expect(buffer.capacity, greaterThanOrEqualTo(250));
      expect(buffer.buffer.length, equals(buffer.capacity * 28));

      // Verify data at index 0 preserved
      expect(buffer.buffer[12], closeTo(99.0, 1e-4));
      expect(buffer.buffer[13], closeTo(1.0, 1e-4));

      // ensureCapacity with smaller or equal size is a no-op
      final prevCap = buffer.capacity;
      buffer.ensureCapacity(50);
      expect(buffer.capacity, equals(prevCap));
    });
  });

  group('VatCrowdRenderer & 10,000 Entity Single Draw-Call Stress Test', () {
    late VatMetadata metadata;
    late VatCrowdRenderer renderer;
    late CameraData camera;

    setUp(() {
      metadata = VatMetadata.fromJson({
        'version': '1.0.0',
        'model_name': 'soldier_crowd_distant',
        'vertex_count': 120,
        'total_frames': 60,
        'fps': 30.0,
        'duration_seconds': 2.0,
        'bounding_box': {
          'min': [-0.6, 0.0, -0.6],
          'max': [0.6, 1.8, 0.6],
        },
        'clips': [
          {
            'name': 'march',
            'start_frame': 0,
            'end_frame': 59,
            'frame_count': 60,
            'fps': 30.0,
            'loop': true,
          }
        ],
      });

      renderer = VatCrowdRenderer(
        metadata: metadata,
        initialCapacity: 10000,
      );

      camera = CameraData.fromAngles(
        posX: 0.0,
        posY: 15.0,
        posZ: -50.0,
        yaw: 0.0,
        pitch: -0.2,
      );
    });

    test('renders 1,000 mixed crowd entities in a single draw call batch', () {
      final clip = metadata.getClip('march');
      final entities = List.generate(1000, (i) {
        return CrowdEntity.create(
          id: i,
          posX: (i % 50) * 2.0 - 50.0,
          posY: 0.0,
          posZ: (i ~/ 50) * 2.0 + 10.0,
          rotationY: (i * 0.1) % (2.0 * math.pi),
          clip: clip,
          phaseOffset: (i * 0.033) % 2.0,
          renderMode: (i % 2 == 0)
              ? CrowdRenderMode.vatMesh
              : CrowdRenderMode.impostorBillboard,
          tintR: 0.9,
          tintG: 0.8,
          tintB: 0.7,
        );
      });

      final batch = renderer.renderCrowd(
        entities: entities,
        deltaTime: 0.01666, // 60 FPS tick
        camera: camera,
      );

      expect(batch.instanceCount, equals(1000));
      expect(batch.drawCallCount, equals(1),
          reason: 'R4 strictly requires single draw call for distant entities');
      expect(batch.bufferByteLength, equals(1000 * 28 * 4));
      expect(batch.totalGpuVertices, equals(1000 * 120));
      expect(batch.memoryKBytes, closeTo((1000 * 28 * 4) / 1024.0, 1e-4));
      expect(renderer.lastActiveInstances, equals(1000));
      expect(renderer.totalBatchesGenerated, equals(1));
    });

    test('advanceAnimations: false leaves animation state untouched during rendering', () {
      final clip = metadata.getClip('march');
      final entity = CrowdEntity.create(
        id: 99,
        posX: 0.0,
        posY: 0.0,
        posZ: 0.0,
        clip: clip,
        phaseOffset: 0.0,
      );

      expect(entity.animState.elapsedTime, equals(0.0));

      renderer.renderCrowd(
        entities: [entity],
        deltaTime: 0.5,
        camera: camera,
        advanceAnimations: false,
      );

      // Elapsed time should still be 0.0
      expect(entity.animState.elapsedTime, equals(0.0));

      // With advanceAnimations: true
      renderer.renderCrowd(
        entities: [entity],
        deltaTime: 0.5,
        camera: camera,
        advanceAnimations: true,
      );

      // Elapsed time advanced by 0.5s
      expect(entity.animState.elapsedTime, closeTo(0.5, 1e-5));
    });

    test('renderCrowd handles empty entity list gracefully', () {
      final batch = renderer.renderCrowd(
        entities: [],
        deltaTime: 0.01666,
        camera: camera,
      );

      expect(batch.instanceCount, equals(0));
      expect(batch.drawCallCount, equals(1));
      expect(batch.bufferByteLength, equals(0));
      expect(batch.totalGpuVertices, equals(0));
      expect(batch.memoryKBytes, equals(0.0));
    });

    test('STRESS BENCHMARK: 10,000 entities in 1 single draw call executes cleanly', () {
      final clip = metadata.getClip('march');
      final entities = List.generate(10000, (i) {
        return CrowdEntity.create(
          id: i,
          posX: (i % 100) * 2.0 - 100.0,
          posY: 0.0,
          posZ: (i ~/ 100) * 2.0 + 20.0,
          rotationY: (i * 0.05) % (2.0 * math.pi),
          clip: clip,
          phaseOffset: (i * 0.01) % 2.0,
          renderMode: (i < 5000)
              ? CrowdRenderMode.vatMesh
              : CrowdRenderMode.impostorBillboard,
          tintR: 1.0,
          tintG: 1.0,
          tintB: 1.0,
        );
      });

      // Warm-up pass
      renderer.renderCrowd(
        entities: entities,
        deltaTime: 0.01666,
        camera: camera,
      );

      // Timed pass
      final sw = Stopwatch()..start();
      final batch = renderer.renderCrowd(
        entities: entities,
        deltaTime: 0.01666,
        camera: camera,
      );
      sw.stop();

      final elapsedMs = sw.elapsedMilliseconds;

      expect(batch.instanceCount, equals(10000));
      expect(batch.drawCallCount, equals(1));
      expect(batch.bufferByteLength, equals(10000 * 28 * 4)); // 1,120,000 bytes (~1.07 MB)
      expect(batch.totalGpuVertices, equals(10000 * 120)); // 1,200,000 virtual vertices
      expect(batch.memoryKBytes, closeTo(1120000.0 / 1024.0, 1e-2));

      // Packing 10,000 instances into pre-allocated buffer is verified to complete cleanly and efficiently
      expect(elapsedMs, lessThan(250),
          reason: '10K instance buffer packing must complete within a single frame budget even under CI load');
    });

    test('integrity: instance buffer values are verified genuine and match input', () {
      final clip = metadata.getClip('march');
      final entity = CrowdEntity.create(
        id: 777,
        posX: 42.0,
        posY: 1.5,
        posZ: -88.0,
        rotationY: 0.0,
        scale: 1.5,
        clip: clip,
        phaseOffset: 0.5,
        renderMode: CrowdRenderMode.vatMesh,
        tintR: 0.5,
        tintG: 0.6,
        tintB: 0.7,
      );

      final batch = renderer.renderCrowd(
        entities: [entity],
        deltaTime: 0.0,
        camera: camera,
        advanceAnimations: false,
      );

      final buf = batch.instanceData;
      expect(buf[12], closeTo(42.0, 1e-4)); // Pos X
      expect(buf[13], closeTo(1.5, 1e-4));  // Pos Y
      expect(buf[14], closeTo(-88.0, 1e-4)); // Pos Z
      expect(buf[19], equals(0.0)); // VAT mode
      expect(buf[20], closeTo(0.5, 1e-4)); // Tint R
      expect(buf[21], closeTo(0.6, 1e-4)); // Tint G
      expect(buf[22], closeTo(0.7, 1e-4)); // Tint B
      expect(buf[25], equals(777.0)); // Entity ID
    });
  });
}
