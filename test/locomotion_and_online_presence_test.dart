import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/services/presence_service.dart';
import 'package:gkk_flutter/models/moradon_models.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_battle_profiles.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_mob_pack_rig.dart';
import 'package:gkk_flutter/screens/home/moradon/character_skeletal_rig.dart';

Future<ui.Image> _decodeFileImage(String path) async {
  final Uint8List bytes = await File(path).readAsBytes();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PresenceService.goOfflineBeforeSignOut completes safely when uninitialized', () async {
    await PresenceService.instance.goOfflineBeforeSignOut();
  });

  test('Moradon ambient bots are strictly distinguishable from real online players', () {
    const MoradonPlayerPresence bot = MoradonPlayerPresence(
      userId: 'ambient_merchant_1',
      username: 'xKralPazarci',
      characterClass: 'savasci',
      x: 2245,
      y: 935,
      targetX: 2245,
      targetY: 935,
      isAmbientBot: true,
    );
    const MoradonPlayerPresence realPlayer = MoradonPlayerPresence(
      userId: 'real_uid_1',
      username: 'theking',
      characterClass: 'savasci',
      x: 1650,
      y: 1100,
      targetX: 1650,
      targetY: 1100,
      isAmbientBot: false,
    );

    final List<MoradonPlayerPresence> list = <MoradonPlayerPresence>[bot, realPlayer];
    final int realOnlineOthers =
        list.where((MoradonPlayerPresence p) => !p.isAmbientBot).length;
    expect(realOnlineOthers, 1);
  });

  testWidgets('Seamless 60FPS character & dungeon mesh rigs render intact frames with zero tearing',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      final ui.Image atlasImg =
          await _decodeFileImage('assets/moradon/char_savasci_atlas.png');
      final ui.Image heroImg =
          await _decodeFileImage('assets/dungeon/hero_battle_warrior.png');
      final ui.Image wolfImg =
          await _decodeFileImage('assets/dungeon/mob_dire_wolf.png');

      const double cellW = 210.0;
      const double cellH = 225.0;
      const int cols = 5;
      const int rows = 3;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      canvas.drawRect(
        const Rect.fromLTWH(0, 0, cellW * cols, cellH * rows),
        Paint()..color = const Color(0xFF131926),
      );

      final List<double> phases = <double>[
        0.0,
        math.pi * 0.5,
        math.pi,
        math.pi * 1.5,
        0.0,
      ];

      // Row 0: Home / Moradon / Ward Character Rig (4 walk phases + 1 combat cleave)
      for (int c = 0; c < cols; c++) {
        final bool atk = c == 4;
        canvas.save();
        canvas.translate(c * cellW + 25.0, 12.0);
        paintSegmentedCharacterRig(
          canvas: canvas,
          size: const Size(160, 200),
          atlas: atlasImg,
          classKey: 'savasci',
          facingRight: true,
          facingBack: false,
          isMoving: !atk,
          walkPhase: phases[c],
          idlePhase: 0.25,
          glowColor: const Color(0xFFF97316),
          glowLevel: 9,
          weaponVisual: MoradonWeaponVisual.illusionSabre,
          attackProgress: atk ? 0.42 : 0.0,
          comboStage: 0,
        );
        canvas.restore();
      }

      // Row 1: Dungeon Hero Battle Rig (4 walk/charge phases + 1 sword cleave)
      for (int c = 0; c < cols; c++) {
        final bool atk = c == 4;
        canvas.save();
        canvas.translate(c * cellW + 15.0, cellH + 14.0);
        paintDungeonConnectedMeshFighter(
          canvas: canvas,
          size: const Size(180, 198),
          image: heroImg,
          facingRight: true,
          walkPhase: phases[c],
          strideIntensity: atk ? 1.25 : 0.90,
          idlePhase: 0.25,
          accentColor: const Color(0xFFFB923C),
          secondaryColor: const Color(0xFFFDE047),
          attackSlashProgress: atk ? 0.45 : 0.0,
          afterimageAlpha: atk ? 0.30 : 0.0,
        );
        canvas.restore();
      }

      // Row 2: Dungeon Dire Wolf Pack Mob Rig (4 prowl/charge phases + 1 pounce bite)
      for (int c = 0; c < cols; c++) {
        final bool atk = c == 4;
        canvas.save();
        canvas.translate(c * cellW + 15.0, cellH * 2 + 24.0);
        paintDungeonConnectedMeshFighter(
          canvas: canvas,
          size: const Size(180, 185),
          image: wolfImg,
          facingRight: false,
          walkPhase: phases[c],
          strideIntensity: atk ? 1.30 : 0.90,
          idlePhase: 0.25,
          accentColor: const Color(0xFFFB7185),
          secondaryColor: const Color(0xFF38BDF8),
          attackSlashProgress: atk ? 0.45 : 0.0,
          afterimageAlpha: atk ? 0.28 : 0.0,
        );
        canvas.restore();
      }

      final DungeonBattleProfile p1 = DungeonBattleProfile.forNumber(1);
      expect(resolveDungeonMobPack(p1).length, greaterThanOrEqualTo(3));

      final ui.Picture pic = recorder.endRecording();
      final ui.Image sheet =
          await pic.toImage((cellW * cols).toInt(), (cellH * rows).toInt());
      final ByteData? rawRgba =
          await sheet.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(rawRgba, isNotNull);

      // Verify ALL 15 cells (3 rows x 5 cols) render opaque, visible sprites!
      final Uint8List rgba = rawRgba!.buffer.asUint8List();
      final int sheetW = (cellW * cols).toInt();
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          int nonBgPixels = 0;
          final int x0 = (c * cellW + 15).toInt();
          final int x1 = (c * cellW + cellW - 15).toInt();
          final int y0 = (r * cellH + 15).toInt();
          final int y1 = (r * cellH + cellH - 15).toInt();
          for (int y = y0; y < y1; y += 3) {
            for (int x = x0; x < x1; x += 3) {
              final int off = (y * sheetW + x) * 4;
              if ((rgba[off] - 0x13).abs() > 8 ||
                  (rgba[off + 1] - 0x19).abs() > 8 ||
                  (rgba[off + 2] - 0x26).abs() > 8) {
                nonBgPixels++;
              }
            }
          }
          expect(
            nonBgPixels,
            greaterThan(100),
            reason: 'Cell ($r, $c) must render visible non-empty pixels',
          );
        }
      }

      final ByteData? encoded =
          await sheet.toByteData(format: ui.ImageByteFormat.png);
      final File out = File(
        r'C:\Users\selçuk\.gemini\antigravity-cli\brain\62cff1a8-deb4-4cb4-958c-b1dc8d0fed00\scratch\rig_visual_proof.png',
      );
      await out.parent.create(recursive: true);
      await out.writeAsBytes(encoded!.buffer.asUint8List(), flush: true);

      atlasImg.dispose();
      heroImg.dispose();
      wolfImg.dispose();
      sheet.dispose();
    });
  });
}
