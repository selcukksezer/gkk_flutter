import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';

/// Magic 12-byte identifier for Khronos KTX 2.0 files.
/// «KTX 20»\r\n\x1A\n
const List<int> ktx2MagicIdentifier = <int>[
  0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A,
];

/// Magic 12-byte identifier for legacy KTX 1.0 files.
/// «KTX 11»\r\n\x1A\n
const List<int> ktx1MagicIdentifier = <int>[
  0xAB, 0x4B, 0x54, 0x58, 0x20, 0x31, 0x31, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A,
];

/// Exception thrown when KTX2 binary data is corrupt, unsupported, or invalid.
class Ktx2FormatException implements Exception {
  final String message;
  final int? byteOffset;

  const Ktx2FormatException(this.message, [this.byteOffset]);

  @override
  String toString() => byteOffset != null
      ? 'Ktx2FormatException: $message (at byte offset $byteOffset)'
      : 'Ktx2FormatException: $message';
}

/// Supported supercompression schemes defined in the KTX 2.0 specification.
enum Ktx2SupercompressionScheme {
  none(0),
  basisLz(1),
  zstandard(2),
  zlib(3),
  unknown(-1);

  final int value;
  const Ktx2SupercompressionScheme(this.value);

  static Ktx2SupercompressionScheme fromValue(int val) {
    for (final Ktx2SupercompressionScheme scheme in values) {
      if (scheme.value == val) return scheme;
    }
    return Ktx2SupercompressionScheme.unknown;
  }
}

/// Khronos Data Format Descriptor (DFD) color models.
enum Ktx2ColorModel {
  unspecified(0),
  etc1s(163),
  uastc(166),
  unknown(-1);

  final int value;
  const Ktx2ColorModel(this.value);

  static Ktx2ColorModel fromValue(int val) {
    for (final Ktx2ColorModel model in values) {
      if (model.value == val) return model;
    }
    return Ktx2ColorModel.unknown;
  }
}

/// Target GPU compression format when transcoding Basis Universal textures.
enum TranscodeTargetFormat {
  bc7,        // High fidelity desktop / console / modern Apple (8 bpp)
  astc4x4,    // Mobile iOS / modern Android (8 bpp)
  etc2Rgba8,  // Universal Android OpenGL ES 3.0 (8 bpp)
  bc1,        // Low-end RGB without alpha (4 bpp)
  rgba8888Fallback, // Uncompressed 32 bpp software fallback
}

/// Parsed KTX 2.0 Container Header (80 bytes total).
class Ktx2Header {
  final int vkFormat;
  final int typeSize;
  final int pixelWidth;
  final int pixelHeight;
  final int pixelDepth;
  final int layerCount;
  final int faceCount;
  final int levelCount;
  final Ktx2SupercompressionScheme supercompressionScheme;
  final int dfdByteOffset;
  final int dfdByteLength;
  final int kvdByteOffset;
  final int kvdByteLength;
  final int sgdByteOffset;
  final int sgdByteLength;

  const Ktx2Header({
    required this.vkFormat,
    required this.typeSize,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.pixelDepth,
    required this.layerCount,
    required this.faceCount,
    required this.levelCount,
    required this.supercompressionScheme,
    required this.dfdByteOffset,
    required this.dfdByteLength,
    required this.kvdByteOffset,
    required this.kvdByteLength,
    required this.sgdByteOffset,
    required this.sgdByteLength,
  });

  /// Parse and validate header from 80-byte header slice.
  factory Ktx2Header.fromByteData(ByteData data, int totalFileSize) {
    if (data.lengthInBytes < 80) {
      throw Ktx2FormatException(
        'Header size too small: expected 80 bytes, got ${data.lengthInBytes}',
      );
    }

    // Verify 12-byte Magic Identifier
    for (int i = 0; i < 12; i++) {
      final int b = data.getUint8(i);
      if (b != ktx2MagicIdentifier[i]) {
        // Check if legacy KTX 1.0
        if (i < 8 && b == ktx1MagicIdentifier[i]) {
          throw const Ktx2FormatException(
            'Legacy KTX 1.0 container detected. Only KTX 2.0 Basis Universal format is supported.',
            0,
          );
        }
        throw Ktx2FormatException('Invalid KTX 2.0 magic identifier at index $i', i);
      }
    }

    // Read header fields (little endian)
    final int vkFormat = data.getUint32(12, Endian.little);
    final int typeSize = data.getUint32(16, Endian.little);
    final int pixelWidth = data.getUint32(20, Endian.little);
    final int pixelHeight = data.getUint32(24, Endian.little);
    final int pixelDepth = data.getUint32(28, Endian.little);
    final int layerCount = data.getUint32(32, Endian.little);
    final int faceCount = data.getUint32(36, Endian.little);
    final int levelCount = data.getUint32(40, Endian.little);
    final int supercompressionVal = data.getUint32(44, Endian.little);
    final int dfdByteOffset = data.getUint32(48, Endian.little);
    final int dfdByteLength = data.getUint32(52, Endian.little);
    final int kvdByteOffset = data.getUint32(56, Endian.little);
    final int kvdByteLength = data.getUint32(60, Endian.little);
    final int sgdByteOffset = data.getUint64(64, Endian.little);
    final int sgdByteLength = data.getUint64(72, Endian.little);

    if (pixelWidth == 0) {
      throw const Ktx2FormatException('Invalid pixelWidth: 0 is not allowed for valid textures.', 20);
    }
    if (levelCount == 0) {
      throw const Ktx2FormatException('Invalid levelCount: must be >= 1.', 40);
    }

    // Bounds validation against total file length
    if (dfdByteOffset + dfdByteLength > totalFileSize) {
      throw Ktx2FormatException(
        'DFD block extends beyond file boundary: offset $dfdByteOffset + len $dfdByteLength > $totalFileSize',
        48,
      );
    }
    if (kvdByteOffset + kvdByteLength > totalFileSize) {
      throw Ktx2FormatException(
        'KVD block extends beyond file boundary: offset $kvdByteOffset + len $kvdByteLength > $totalFileSize',
        56,
      );
    }

    return Ktx2Header(
      vkFormat: vkFormat,
      typeSize: typeSize,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight == 0 ? 1 : pixelHeight,
      pixelDepth: pixelDepth,
      layerCount: layerCount,
      faceCount: faceCount,
      levelCount: levelCount,
      supercompressionScheme: Ktx2SupercompressionScheme.fromValue(supercompressionVal),
      dfdByteOffset: dfdByteOffset,
      dfdByteLength: dfdByteLength,
      kvdByteOffset: kvdByteOffset,
      kvdByteLength: kvdByteLength,
      sgdByteOffset: sgdByteOffset,
      sgdByteLength: sgdByteLength,
    );
  }
}

/// Description of a single mip level in the KTX2 level index.
class Ktx2LevelEntry {
  final int level;
  final int width;
  final int height;
  final int byteOffset;
  final int byteLength;
  final int uncompressedByteLength;

  const Ktx2LevelEntry({
    required this.level,
    required this.width,
    required this.height,
    required this.byteOffset,
    required this.byteLength,
    required this.uncompressedByteLength,
  });

  @override
  String toString() =>
      'Ktx2LevelEntry(level: $level, ${width}x$height, offset: $byteOffset, len: $byteLength, uncomp: $uncompressedByteLength)';
}

/// Parsed Khronos Data Format Descriptor (DFD).
class Ktx2DfdDescriptor {
  final int totalSize;
  final int vendorId;
  final int descriptorType;
  final int versionNumber;
  final int descriptorBlockSize;
  final Ktx2ColorModel colorModel;
  final int colorPrimaries;
  final int transferFunction;
  final int flags;
  final int texelBlockDimensionX;
  final int texelBlockDimensionY;

  const Ktx2DfdDescriptor({
    required this.totalSize,
    required this.vendorId,
    required this.descriptorType,
    required this.versionNumber,
    required this.descriptorBlockSize,
    required this.colorModel,
    required this.colorPrimaries,
    required this.transferFunction,
    required this.flags,
    required this.texelBlockDimensionX,
    required this.texelBlockDimensionY,
  });

  factory Ktx2DfdDescriptor.fromByteData(ByteData data, int offset) {
    if (offset + 28 > data.lengthInBytes) {
      throw Ktx2FormatException('Truncated DFD descriptor block at offset $offset', offset);
    }

    final int totalSize = data.getUint32(offset, Endian.little);
    final int vendorId = data.getUint16(offset + 4, Endian.little);
    final int descriptorType = data.getUint16(offset + 6, Endian.little);
    final int versionNumber = data.getUint16(offset + 8, Endian.little);
    final int descriptorBlockSize = data.getUint16(offset + 10, Endian.little);

    final int colorModelVal = data.getUint8(offset + 12);
    final int colorPrimaries = data.getUint8(offset + 13);
    final int transferFunction = data.getUint8(offset + 14);
    final int flags = data.getUint8(offset + 15);
    final int blockDimX = data.getUint8(offset + 16);
    final int blockDimY = data.getUint8(offset + 17);

    return Ktx2DfdDescriptor(
      totalSize: totalSize,
      vendorId: vendorId,
      descriptorType: descriptorType,
      versionNumber: versionNumber,
      descriptorBlockSize: descriptorBlockSize,
      colorModel: Ktx2ColorModel.fromValue(colorModelVal),
      colorPrimaries: colorPrimaries,
      transferFunction: transferFunction,
      flags: flags,
      texelBlockDimensionX: blockDimX == 0 ? 4 : blockDimX,
      texelBlockDimensionY: blockDimY == 0 ? 4 : blockDimY,
    );
  }
}

/// Memory budget analysis comparing uncompressed RGBA8888 against compressed GPU VRAM.
class Ktx2MemoryBudget {
  final int pixelWidth;
  final int pixelHeight;
  final int levelCount;
  final int rawRgba8888Bytes;
  final int compressedVramBytes;
  final int containerSizeBytes;
  final double vramSavingsFraction;
  final double vramSavingsPercent;
  final double diskSavingsPercent;
  final bool isBudgetCompliant; // True if >= 70% VRAM savings

  const Ktx2MemoryBudget({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.levelCount,
    required this.rawRgba8888Bytes,
    required this.compressedVramBytes,
    required this.containerSizeBytes,
    required this.vramSavingsFraction,
    required this.vramSavingsPercent,
    required this.diskSavingsPercent,
    required this.isBudgetCompliant,
  });

  /// Calculate memory metrics across all mip levels.
  factory Ktx2MemoryBudget.calculate({
    required int width,
    required int height,
    required int levelCount,
    required int containerSize,
    required Ktx2ColorModel colorModel,
  }) {
    int rawTotal = 0;
    int vramTotal = 0;

    int w = width;
    int h = height;

    final int bytesPerBlock = colorModel == Ktx2ColorModel.etc1s ? 8 : 16;

    for (int i = 0; i < levelCount; i++) {
      final int cw = math.max(1, w);
      final int ch = math.max(1, h);

      // Raw uncompressed RGBA8888: 4 bytes per texel
      rawTotal += cw * ch * 4;

      // Hardware block compressed: 4x4 blocks
      final int blocksX = (cw + 3) ~/ 4;
      final int blocksY = (ch + 3) ~/ 4;
      vramTotal += blocksX * blocksY * bytesPerBlock;

      w = math.max(1, w ~/ 2);
      h = math.max(1, h ~/ 2);
    }

    final double savingsFraction = rawTotal > 0 ? (1.0 - (vramTotal / rawTotal)) : 0.0;
    final double savingsPercent = savingsFraction * 100.0;
    final double diskSavings = rawTotal > 0 ? (1.0 - (containerSize / rawTotal)) * 100.0 : 0.0;

    return Ktx2MemoryBudget(
      pixelWidth: width,
      pixelHeight: height,
      levelCount: levelCount,
      rawRgba8888Bytes: rawTotal,
      compressedVramBytes: vramTotal,
      containerSizeBytes: containerSize,
      vramSavingsFraction: savingsFraction,
      vramSavingsPercent: savingsPercent,
      diskSavingsPercent: diskSavings,
      isBudgetCompliant: savingsPercent >= 70.0,
    );
  }

  String get summaryString =>
      'KTX2 Budget: ${pixelWidth}x$pixelHeight ($levelCount levels) | '
      'Raw RGBA: ${(rawRgba8888Bytes / 1024).toStringAsFixed(1)} KB -> '
      'VRAM: ${(compressedVramBytes / 1024).toStringAsFixed(1)} KB '
      '(${vramSavingsPercent.toStringAsFixed(1)}% savings, budget compliant: $isBudgetCompliant)';
}

/// Fully decoded KTX2 Texture Container ready for streaming or GPU upload.
class Ktx2Texture {
  final Ktx2Header header;
  final List<Ktx2LevelEntry> levels;
  final Ktx2DfdDescriptor? dfd;
  final Map<String, String> metadata;
  final Uint8List rawBytes;
  final Ktx2MemoryBudget memoryBudget;

  const Ktx2Texture({
    required this.header,
    required this.levels,
    required this.dfd,
    required this.metadata,
    required this.rawBytes,
    required this.memoryBudget,
  });

  /// Parse a complete KTX2 container from a byte buffer.
  factory Ktx2Texture.fromBytes(Uint8List bytes) {
    if (bytes.lengthInBytes < 80) {
      throw Ktx2FormatException('Header size too small: file has only ${bytes.lengthInBytes} bytes, expected at least 80 bytes');
    }

    final ByteData byteData = ByteData.sublistView(bytes);
    final Ktx2Header header = Ktx2Header.fromByteData(byteData, bytes.lengthInBytes);

    // Parse Level Index Table (starts at byte 80, length = levelCount * 24 bytes)
    const int levelIndexStart = 80;
    final int levelIndexEnd = levelIndexStart + (header.levelCount * 24);
    if (levelIndexEnd > bytes.lengthInBytes) {
      throw Ktx2FormatException(
        'Level index table extends beyond file boundary: $levelIndexEnd > ${bytes.lengthInBytes}',
        levelIndexStart,
      );
    }

    final List<Ktx2LevelEntry> levels = <Ktx2LevelEntry>[];
    int mipW = header.pixelWidth;
    int mipH = header.pixelHeight;

    for (int i = 0; i < header.levelCount; i++) {
      final int entryOffset = levelIndexStart + (i * 24);
      final int byteOffset = byteData.getUint64(entryOffset, Endian.little);
      final int byteLength = byteData.getUint64(entryOffset + 8, Endian.little);
      final int uncompLength = byteData.getUint64(entryOffset + 16, Endian.little);

      if (byteOffset + byteLength > bytes.lengthInBytes) {
        throw Ktx2FormatException(
          'Mip level $i image data extends beyond file bounds: offset $byteOffset + len $byteLength > ${bytes.lengthInBytes}',
          entryOffset,
        );
      }

      levels.add(
        Ktx2LevelEntry(
          level: i,
          width: math.max(1, mipW),
          height: math.max(1, mipH),
          byteOffset: byteOffset,
          byteLength: byteLength,
          uncompressedByteLength: uncompLength,
        ),
      );

      mipW = math.max(1, mipW ~/ 2);
      mipH = math.max(1, mipH ~/ 2);
    }

    // Parse Data Format Descriptor (DFD)
    Ktx2DfdDescriptor? dfd;
    if (header.dfdByteLength > 0 && header.dfdByteOffset + header.dfdByteLength <= bytes.lengthInBytes) {
      dfd = Ktx2DfdDescriptor.fromByteData(byteData, header.dfdByteOffset);
    }

    // Parse Key/Value Data (KVD) metadata
    final Map<String, String> metadata = <String, String>{};
    if (header.kvdByteLength > 0 && header.kvdByteOffset + header.kvdByteLength <= bytes.lengthInBytes) {
      int cursor = header.kvdByteOffset;
      final int kvdEnd = header.kvdByteOffset + header.kvdByteLength;
      while (cursor + 4 <= kvdEnd) {
        final int entryLen = byteData.getUint32(cursor, Endian.little);
        cursor += 4;
        if (cursor + entryLen > kvdEnd) break;

        final Uint8List entryBytes = bytes.sublist(cursor, cursor + entryLen);
        final int nullIdx = entryBytes.indexOf(0);
        if (nullIdx != -1) {
          final String key = utf8.decode(entryBytes.sublist(0, nullIdx), allowMalformed: true);
          final String val = utf8.decode(
            entryBytes.sublist(nullIdx + 1, entryBytes.last == 0 ? entryBytes.length - 1 : entryBytes.length),
            allowMalformed: true,
          );
          metadata[key] = val;
        }

        cursor += entryLen;
        // 4-byte alignment
        final int pad = (4 - (entryLen % 4)) % 4;
        cursor += pad;
      }
    }

    // Compute memory budget
    final Ktx2ColorModel colorModel = dfd?.colorModel ?? Ktx2ColorModel.uastc;
    final Ktx2MemoryBudget budget = Ktx2MemoryBudget.calculate(
      width: header.pixelWidth,
      height: header.pixelHeight,
      levelCount: header.levelCount,
      containerSize: bytes.lengthInBytes,
      colorModel: colorModel,
    );

    return Ktx2Texture(
      header: header,
      levels: levels,
      dfd: dfd,
      metadata: metadata,
      rawBytes: bytes,
      memoryBudget: budget,
    );
  }

  /// Get the raw compressed bytes for a specific mip level.
  Uint8List getLevelBytes(int level) {
    if (level < 0 || level >= levels.length) {
      throw RangeError.range(level, 0, levels.length - 1, 'level');
    }
    final Ktx2LevelEntry entry = levels[level];
    return rawBytes.sublist(entry.byteOffset, entry.byteOffset + entry.byteLength);
  }

  /// Get mip level dimensions (width, height).
  (int, int) getMipDimensions(int level) {
    if (level < 0 || level >= levels.length) {
      throw RangeError.range(level, 0, levels.length - 1, 'level');
    }
    return (levels[level].width, levels[level].height);
  }

  /// Software fallback decompressor: decodes a mip level into standard uncompressed
  /// 32-bit RGBA8888 texels for software rasterization and headless testing.
  Uint8List decodeLevelToRgba8888Fallback(int level) {
    if (level < 0 || level >= levels.length) {
      throw RangeError.range(level, 0, levels.length - 1, 'level');
    }

    final Ktx2LevelEntry entry = levels[level];
    final int width = entry.width;
    final int height = entry.height;
    final Uint8List levelData = getLevelBytes(level);

    final Uint8List rgbaBuffer = Uint8List(width * height * 4);
    final ByteData view = ByteData.sublistView(levelData);

    final int blocksX = (width + 3) ~/ 4;
    final int blocksY = (height + 3) ~/ 4;

    int blockOffset = 0;
    for (int by = 0; by < blocksY; by++) {
      for (int bx = 0; bx < blocksX; bx++) {
        if (blockOffset + 16 <= levelData.lengthInBytes) {
          // UASTC 16-byte block:
          // 8 bytes endpoints (min/max RGBA)
          final int minR = view.getUint8(blockOffset);
          final int minG = view.getUint8(blockOffset + 1);
          final int minB = view.getUint8(blockOffset + 2);
          final int minA = view.getUint8(blockOffset + 3);
          final int maxR = view.getUint8(blockOffset + 4);
          final int maxG = view.getUint8(blockOffset + 5);
          final int maxB = view.getUint8(blockOffset + 6);
          final int maxA = view.getUint8(blockOffset + 7);

          // 4 bytes selector bits (16 * 2-bit weights)
          final int selectors = view.getUint32(blockOffset + 8, Endian.little);

          for (int py = 0; py < 4; py++) {
            final int y = by * 4 + py;
            if (y >= height) continue;
            for (int px = 0; px < 4; px++) {
              final int x = bx * 4 + px;
              if (x >= width) continue;

              final int texelIdx = py * 4 + px;
              final int weightIdx = (selectors >> (texelIdx * 2)) & 0x03;
              final double t = weightIdx / 3.0;

              final int r = (minR + (maxR - minR) * t).round().clamp(0, 255);
              final int g = (minG + (maxG - minG) * t).round().clamp(0, 255);
              final int b = (minB + (maxB - minB) * t).round().clamp(0, 255);
              final int a = (minA + (maxA - minA) * t).round().clamp(0, 255);

              final int outPixelOffset = (y * width + x) * 4;
              rgbaBuffer[outPixelOffset] = r;
              rgbaBuffer[outPixelOffset + 1] = g;
              rgbaBuffer[outPixelOffset + 2] = b;
              rgbaBuffer[outPixelOffset + 3] = a;
            }
          }
          blockOffset += 16;
        } else if (blockOffset + 8 <= levelData.lengthInBytes) {
          // ETC1S 8-byte block fallback: fill block with average color
          final int avgR = view.getUint8(blockOffset);
          final int avgG = view.getUint8(blockOffset + 1);
          final int avgB = view.getUint8(blockOffset + 2);
          final int avgA = view.getUint8(blockOffset + 3);

          for (int py = 0; py < 4; py++) {
            final int y = by * 4 + py;
            if (y >= height) continue;
            for (int px = 0; px < 4; px++) {
              final int x = bx * 4 + px;
              if (x >= width) continue;
              final int outPixelOffset = (y * width + x) * 4;
              rgbaBuffer[outPixelOffset] = avgR;
              rgbaBuffer[outPixelOffset + 1] = avgG;
              rgbaBuffer[outPixelOffset + 2] = avgB;
              rgbaBuffer[outPixelOffset + 3] = avgA;
            }
          }
          blockOffset += 8;
        }
      }
    }

    return rgbaBuffer;
  }

  /// Query mip levels for progressive crowd texture streaming.
  /// For instance, distant crowd VAT or impostors only load mips >= minLevel.
  List<Ktx2LevelEntry> getStreamingLevels({int minLevel = 0, int? maxLevel}) {
    final int upper = maxLevel ?? (levels.length - 1);
    return levels.where((Ktx2LevelEntry l) => l.level >= minLevel && l.level <= upper).toList();
  }
}

/// Event emitted during progressive mip level streaming.
class Ktx2StreamingMipEvent {
  final int level;
  final int width;
  final int height;
  final Uint8List levelBytes;
  final bool isBaseLevel;

  const Ktx2StreamingMipEvent({
    required this.level,
    required this.width,
    required this.height,
    required this.levelBytes,
    required this.isBaseLevel,
  });
}

/// High-level asynchronous KTX2 Loader and Streaming Service.
class Ktx2TextureLoader {
  /// Load and parse KTX2 texture from byte array.
  static Future<Ktx2Texture> loadFromBytes(Uint8List bytes) async {
    return Ktx2Texture.fromBytes(bytes);
  }

  /// Load and parse KTX2 texture from local file.
  static Future<Ktx2Texture> loadFromFile(String filePath) async {
    final io.File file = io.File(filePath);
    if (!await file.exists()) {
      throw io.FileSystemException('Texture file not found', filePath);
    }
    final Uint8List bytes = await file.readAsBytes();
    return Ktx2Texture.fromBytes(bytes);
  }

  /// Automatically select best GPU transcode target based on platform profile.
  static TranscodeTargetFormat selectBestTranscodeTarget({
    bool isApple = false,
    bool isAndroid = false,
    bool isWeb = false,
  }) {
    if (isApple) {
      // Modern Metal supports ASTC and BC7
      return TranscodeTargetFormat.astc4x4;
    }
    if (isAndroid) {
      return TranscodeTargetFormat.astc4x4;
    }
    if (isWeb) {
      return TranscodeTargetFormat.bc7;
    }
    // Desktop Vulkan / Impeller default
    return TranscodeTargetFormat.bc7;
  }

  /// Stream texture mip levels progressively:
  /// Emits smallest (lowest resolution) mip first for fast rendering, then streams
  /// up to level 0 (full resolution).
  static Stream<Ktx2StreamingMipEvent> streamTexture(Ktx2Texture texture) async* {
    // Traverse from highest mip index (smallest) down to 0 (base)
    for (int lvl = texture.levels.length - 1; lvl >= 0; lvl--) {
      final Ktx2LevelEntry entry = texture.levels[lvl];
      final Uint8List data = texture.getLevelBytes(lvl);
      yield Ktx2StreamingMipEvent(
        level: lvl,
        width: entry.width,
        height: entry.height,
        levelBytes: data,
        isBaseLevel: lvl == 0,
      );
    }
  }
}
