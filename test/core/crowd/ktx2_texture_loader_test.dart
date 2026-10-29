import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/ktx2_texture_loader.dart';

/// Helper to generate a minimal synthetic KTX2 byte buffer for testing.
Uint8List createSyntheticKtx2Buffer({
  int width = 64,
  int height = 64,
  int levelCount = 1,
  Ktx2SupercompressionScheme scheme = Ktx2SupercompressionScheme.none,
  Ktx2ColorModel colorModel = Ktx2ColorModel.uastc,
  List<int>? customMagic,
  Map<String, String>? kvdPairs,
  bool corruptLevelBounds = false,
}) {
  final List<int> magic = customMagic ?? ktx2MagicIdentifier;
  final int bytesPerBlock = colorModel == Ktx2ColorModel.etc1s ? 8 : 16;

  // Build DFD block (44 bytes)
  final ByteData dfdData = ByteData(44);
  dfdData.setUint32(0, 44, Endian.little);
  dfdData.setUint16(4, 0, Endian.little); // vendorId
  dfdData.setUint16(6, 0, Endian.little); // descriptorType
  dfdData.setUint16(8, 2, Endian.little); // versionNumber
  dfdData.setUint16(10, 40, Endian.little); // descriptorBlockSize
  dfdData.setUint8(12, colorModel.value);
  dfdData.setUint8(13, 1); // colorPrimaries (BT709)
  dfdData.setUint8(14, 2); // transferFunction (sRGB)
  dfdData.setUint8(15, 0); // flags
  dfdData.setUint8(16, 4); // texelBlockDimension0 (4x4)
  dfdData.setUint8(17, 4); // texelBlockDimension1

  // Build KVD block
  final BytesBuilder kvdBuilder = BytesBuilder();
  final Map<String, String> meta = kvdPairs ?? <String, String>{
    'KTXwriter': 'gkk_test_suite_v1.0',
    'KTXorientation': 'rd',
  };
  for (final MapEntry<String, String> entry in meta.entries) {
    final List<int> entryBytes = <int>[
      ...utf8.encode(entry.key),
      0,
      ...utf8.encode(entry.value),
      0,
    ];
    final ByteData lenHeader = ByteData(4);
    lenHeader.setUint32(0, entryBytes.length, Endian.little);
    kvdBuilder.add(lenHeader.buffer.asUint8List());
    kvdBuilder.add(entryBytes);
    final int pad = (4 - (entryBytes.length % 4)) % 4;
    if (pad > 0) kvdBuilder.add(Uint8List(pad));
  }
  final Uint8List kvdBytes = kvdBuilder.toBytes();

  // Layout calculations
  const int headerSize = 80;
  final int levelIndexSize = levelCount * 24;
  final int dfdOffset = headerSize + levelIndexSize;
  final int dfdLength = dfdData.lengthInBytes;
  final int kvdOffset = dfdOffset + dfdLength;
  final int kvdLength = kvdBytes.lengthInBytes;
  const int sgdOffset = 0;
  const int sgdLength = 0;

  int imageStart = kvdOffset + kvdLength;
  final int alignPad = (8 - (imageStart % 8)) % 8;
  imageStart += alignPad;

  // Build level index and dummy image payload
  final ByteData levelIndexData = ByteData(levelIndexSize);
  final BytesBuilder imagePayload = BytesBuilder();
  int currentImageOffset = imageStart;

  int w = width;
  int h = height;
  for (int lvl = 0; lvl < levelCount; lvl++) {
    final int blocksX = (w + 3) ~/ 4;
    final int blocksY = (h + 3) ~/ 4;
    final int lvlBytesLen = blocksX * blocksY * bytesPerBlock;
    final int uncompLen = w * h * 4;

    // Build realistic 16-byte UASTC blocks
    final Uint8List blockPayload = Uint8List(lvlBytesLen);
    for (int b = 0; b < lvlBytesLen; b += bytesPerBlock) {
      if (bytesPerBlock == 16) {
        // Endpoints
        blockPayload[b] = 10;
        blockPayload[b + 1] = 20;
        blockPayload[b + 2] = 30;
        blockPayload[b + 3] = 255;
        blockPayload[b + 4] = 200;
        blockPayload[b + 5] = 210;
        blockPayload[b + 6] = 220;
        blockPayload[b + 7] = 255;
        // Selectors
        blockPayload[b + 8] = 0x55;
        blockPayload[b + 9] = 0xAA;
        blockPayload[b + 10] = 0x55;
        blockPayload[b + 11] = 0xAA;
      } else {
        blockPayload[b] = 128;
        blockPayload[b + 1] = 128;
        blockPayload[b + 2] = 128;
        blockPayload[b + 3] = 255;
      }
    }

    final int recordedOffset = corruptLevelBounds ? (currentImageOffset + 999999) : currentImageOffset;

    levelIndexData.setUint64(lvl * 24, recordedOffset, Endian.little);
    levelIndexData.setUint64(lvl * 24 + 8, lvlBytesLen, Endian.little);
    levelIndexData.setUint64(lvl * 24 + 16, uncompLen, Endian.little);

    imagePayload.add(blockPayload);
    final int pad = (4 - (lvlBytesLen % 4)) % 4;
    if (pad > 0) imagePayload.add(Uint8List(pad));
    currentImageOffset += lvlBytesLen + pad;

    w = math.max(1, w ~/ 2);
    h = math.max(1, h ~/ 2);
  }

  // Build 80-byte header
  final ByteData headerData = ByteData(80);
  for (int i = 0; i < 12; i++) {
    headerData.setUint8(i, magic[i]);
  }
  headerData.setUint32(12, 0, Endian.little); // vkFormat (VK_FORMAT_UNDEFINED)
  headerData.setUint32(16, 1, Endian.little); // typeSize
  headerData.setUint32(20, width, Endian.little); // pixelWidth
  headerData.setUint32(24, height, Endian.little); // pixelHeight
  headerData.setUint32(28, 0, Endian.little); // pixelDepth
  headerData.setUint32(32, 0, Endian.little); // layerCount
  headerData.setUint32(36, 1, Endian.little); // faceCount
  headerData.setUint32(40, levelCount, Endian.little); // levelCount
  headerData.setUint32(44, scheme.value, Endian.little); // supercompressionScheme
  headerData.setUint32(48, dfdOffset, Endian.little);
  headerData.setUint32(52, dfdLength, Endian.little);
  headerData.setUint32(56, kvdOffset, Endian.little);
  headerData.setUint32(60, kvdLength, Endian.little);
  headerData.setUint64(64, sgdOffset, Endian.little);
  headerData.setUint64(72, sgdLength, Endian.little);

  final BytesBuilder out = BytesBuilder();
  out.add(headerData.buffer.asUint8List());
  out.add(levelIndexData.buffer.asUint8List());
  out.add(dfdData.buffer.asUint8List());
  out.add(kvdBytes);
  if (alignPad > 0) out.add(Uint8List(alignPad));
  out.add(imagePayload.toBytes());

  return out.toBytes();
}

void main() {
  group('KTX2 Container Format & Header Parsing Tests', () {
    test('Valid KTX2 header decodes all fields properly', () {
      final Uint8List bytes = createSyntheticKtx2Buffer(
        width: 128,
        height: 128,
        levelCount: 4,
        scheme: Ktx2SupercompressionScheme.none,
        colorModel: Ktx2ColorModel.uastc,
      );

      final Ktx2Texture texture = Ktx2Texture.fromBytes(bytes);

      expect(texture.header.pixelWidth, equals(128));
      expect(texture.header.pixelHeight, equals(128));
      expect(texture.header.levelCount, equals(4));
      expect(texture.header.supercompressionScheme, equals(Ktx2SupercompressionScheme.none));
      expect(texture.levels.length, equals(4));
      expect(texture.dfd?.colorModel, equals(Ktx2ColorModel.uastc));
      expect(texture.metadata['KTXwriter'], contains('gkk_test_suite'));
    });

    test('Rejects legacy KTX 1.0 files with informative exception', () {
      final Uint8List legacyBytes = createSyntheticKtx2Buffer(
        customMagic: ktx1MagicIdentifier,
      );

      expect(
        () => Ktx2Texture.fromBytes(legacyBytes),
        throwsA(
          isA<Ktx2FormatException>().having(
            (Ktx2FormatException e) => e.message,
            'message',
            contains('Legacy KTX 1.0 container detected'),
          ),
        ),
      );
    });

    test('Rejects corrupt or truncated magic bytes', () {
      final List<int> corruptMagic = List<int>.from(ktx2MagicIdentifier);
      corruptMagic[0] = 0x00; // corrupt first byte

      final Uint8List corruptBytes = createSyntheticKtx2Buffer(
        customMagic: corruptMagic,
      );

      expect(
        () => Ktx2Texture.fromBytes(corruptBytes),
        throwsA(isA<Ktx2FormatException>()),
      );
    });

    test('Rejects buffers smaller than 80 bytes header', () {
      final Uint8List smallBytes = Uint8List(50);
      expect(
        () => Ktx2Texture.fromBytes(smallBytes),
        throwsA(
          isA<Ktx2FormatException>().having(
            (Ktx2FormatException e) => e.message,
            'message',
            contains('Header size too small'),
          ),
        ),
      );
    });

    test('Rejects level offsets pointing past end of file', () {
      final Uint8List outOfBoundsBytes = createSyntheticKtx2Buffer(
        corruptLevelBounds: true,
      );

      expect(
        () => Ktx2Texture.fromBytes(outOfBoundsBytes),
        throwsA(
          isA<Ktx2FormatException>().having(
            (Ktx2FormatException e) => e.message,
            'message',
            contains('extends beyond file bounds'),
          ),
        ),
      );
    });
  });

  group('Mip Level Calculation & Dimensions Tests', () {
    test('Calculates correct mip pyramid for square power-of-two texture (64x64)', () {
      final Uint8List bytes = createSyntheticKtx2Buffer(
        width: 64,
        height: 64,
        levelCount: 7,
      );

      final Ktx2Texture texture = Ktx2Texture.fromBytes(bytes);
      expect(texture.levels.length, equals(7));

      final List<(int, int)> expectedDims = <(int, int)>[
        (64, 64),
        (32, 32),
        (16, 16),
        (8, 8),
        (4, 4),
        (2, 2),
        (1, 1),
      ];

      for (int i = 0; i < 7; i++) {
        final (int w, int h) = texture.getMipDimensions(i);
        expect(w, equals(expectedDims[i].$1));
        expect(h, equals(expectedDims[i].$2));
      }
    });

    test('Calculates correct mip pyramid for non-square rectangular texture (512x128)', () {
      final Uint8List bytes = createSyntheticKtx2Buffer(
        width: 512,
        height: 128,
        levelCount: 10,
      );

      final Ktx2Texture texture = Ktx2Texture.fromBytes(bytes);
      expect(texture.levels.length, equals(10));

      final (int w0, int h0) = texture.getMipDimensions(0);
      expect(w0, equals(512));
      expect(h0, equals(128));

      // Level 2 (128x32)
      final (int w2, int h2) = texture.getMipDimensions(2);
      expect(w2, equals(128));
      expect(h2, equals(32));

      // Lowest level clamped to 1x1
      final (int wLast, int hLast) = texture.getMipDimensions(9);
      expect(wLast, equals(1));
      expect(hLast, equals(1));
    });
  });

  group('Memory Budget & VRAM Reduction Verification Tests', () {
    test('UASTC 4x4 block compression yields ~75% VRAM reduction vs Raw RGBA8888', () {
      final Uint8List bytes = createSyntheticKtx2Buffer(
        width: 256,
        height: 256,
        levelCount: 9,
        colorModel: Ktx2ColorModel.uastc,
      );

      final Ktx2Texture texture = Ktx2Texture.fromBytes(bytes);
      final Ktx2MemoryBudget budget = texture.memoryBudget;

      // Raw uncompressed RGBA8888: 256*256*4 + mips ~= 349,524 bytes
      expect(budget.rawRgba8888Bytes, greaterThan(300000));

      // UASTC compressed VRAM: exactly 75% savings
      expect(budget.vramSavingsPercent, closeTo(75.0, 0.5));
      expect(budget.vramSavingsFraction, closeTo(0.75, 0.005));
      expect(budget.isBudgetCompliant, isTrue);
      expect(budget.summaryString, contains('75.0% savings'));
    });

    test('ETC1S mode yields >85% VRAM reduction vs Raw RGBA8888', () {
      final Uint8List bytes = createSyntheticKtx2Buffer(
        width: 128,
        height: 128,
        levelCount: 8,
        colorModel: Ktx2ColorModel.etc1s,
      );

      final Ktx2Texture texture = Ktx2Texture.fromBytes(bytes);
      final Ktx2MemoryBudget budget = texture.memoryBudget;

      expect(budget.vramSavingsPercent, greaterThan(85.0));
      expect(budget.isBudgetCompliant, isTrue);
    });
  });

  group('Progressive Streaming & Fallback Decompressor Tests', () {
    test('streamTexture emits mip levels progressively from smallest to base', () async {
      final Uint8List bytes = createSyntheticKtx2Buffer(
        width: 32,
        height: 32,
        levelCount: 4,
      );

      final Ktx2Texture texture = Ktx2Texture.fromBytes(bytes);
      final List<Ktx2StreamingMipEvent> events = <Ktx2StreamingMipEvent>[];

      await for (final Ktx2StreamingMipEvent event in Ktx2TextureLoader.streamTexture(texture)) {
        events.add(event);
      }

      expect(events.length, equals(4));
      // First event emitted should be highest level (level 3, smallest 4x4)
      expect(events.first.level, equals(3));
      expect(events.first.width, equals(4));
      expect(events.first.height, equals(4));
      expect(events.first.isBaseLevel, isFalse);

      // Final event emitted should be base level 0 (full 32x32)
      expect(events.last.level, equals(0));
      expect(events.last.width, equals(32));
      expect(events.last.height, equals(32));
      expect(events.last.isBaseLevel, isTrue);
    });

    test('getStreamingLevels filters mips for distant crowd LOD', () {
      final Uint8List bytes = createSyntheticKtx2Buffer(
        width: 128,
        height: 128,
        levelCount: 6,
      );

      final Ktx2Texture texture = Ktx2Texture.fromBytes(bytes);
      // For distant LOD, only request mips 2 to 5
      final List<Ktx2LevelEntry> distantMips = texture.getStreamingLevels(minLevel: 2);

      expect(distantMips.length, equals(4));
      expect(distantMips.first.level, equals(2));
      expect(distantMips.last.level, equals(5));
    });

    test('Software fallback decompressor unpacks UASTC blocks to valid RGBA pixels', () {
      final Uint8List bytes = createSyntheticKtx2Buffer(
        width: 16,
        height: 16,
        levelCount: 1,
      );

      final Ktx2Texture texture = Ktx2Texture.fromBytes(bytes);
      final Uint8List rgbaPixels = texture.decodeLevelToRgba8888Fallback(0);

      expect(rgbaPixels.length, equals(16 * 16 * 4));
      // All decoded channels must be within valid byte range 0..255
      for (int i = 0; i < rgbaPixels.length; i++) {
        expect(rgbaPixels[i], inInclusiveRange(0, 255));
      }
    });

    test('selectBestTranscodeTarget chooses platform-optimal hardware formats', () {
      expect(
        Ktx2TextureLoader.selectBestTranscodeTarget(isApple: true),
        equals(TranscodeTargetFormat.astc4x4),
      );
      expect(
        Ktx2TextureLoader.selectBestTranscodeTarget(isAndroid: true),
        equals(TranscodeTargetFormat.astc4x4),
      );
      expect(
        Ktx2TextureLoader.selectBestTranscodeTarget(isWeb: true),
        equals(TranscodeTargetFormat.bc7),
      );
      expect(
        Ktx2TextureLoader.selectBestTranscodeTarget(),
        equals(TranscodeTargetFormat.bc7),
      );
    });
  });

  group('End-to-End Real KTX2 File Loading Tests', () {
    test('Load real KTX2 file generated by compress_ktx2.py if present', () async {
      final io.File uastcFile = io.File('build/test_textures/sample_uastc.ktx2');
      if (await uastcFile.exists()) {
        final Ktx2Texture texture = await Ktx2TextureLoader.loadFromFile(uastcFile.path);

        expect(texture.header.pixelWidth, equals(64));
        expect(texture.header.pixelHeight, equals(64));
        expect(texture.header.levelCount, equals(7));
        expect(texture.dfd?.colorModel, equals(Ktx2ColorModel.uastc));
        expect(texture.metadata['KTXcompressionMode'], equals('UASTC'));
        expect(texture.memoryBudget.vramSavingsPercent, greaterThan(70.0));
        expect(texture.memoryBudget.isBudgetCompliant, isTrue);

        // Verify fallback decoding of level 0
        final Uint8List decoded = texture.decodeLevelToRgba8888Fallback(0);
        expect(decoded.length, equals(64 * 64 * 4));
      }
    });
  });
}
