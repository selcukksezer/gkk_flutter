import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Character 3D GLB Models Verification', () {
    final characterFiles = [
      'assets/models/characters/mage.glb',
      'assets/models/characters/wizard.glb',
      'assets/models/characters/rogue.glb',
      'assets/models/characters/archer.glb',
      'assets/models/characters/druid.glb',
      'assets/models/characters/ranger.glb',
      'assets/models/characters/marksman.glb',
      'assets/models/characters/witch.glb',
    ];

    for (final relativePath in characterFiles) {
      test('Model $relativePath exists, is > 10KB, and has valid glTF magic bytes', () {
        final file = File(relativePath);
        expect(file.existsSync(), isTrue, reason: 'File $relativePath must exist on disk');

        final length = file.lengthSync();
        expect(length, greaterThan(10 * 1024), reason: 'File $relativePath must be larger than 10KB (got $length bytes)');

        // Read first 4 bytes and check magic header
        final raf = file.openSync(mode: FileMode.read);
        final magicBytes = raf.readSync(4);
        raf.closeSync();

        // 0x67, 0x6C, 0x54, 0x46 in ASCII is "glTF"
        expect(magicBytes, equals([0x67, 0x6C, 0x54, 0x46]), reason: 'File $relativePath must have glTF header');
      });
    }
  });
}
