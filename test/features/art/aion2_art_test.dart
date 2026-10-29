import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/features/art/aion2_art_assets.dart';
import 'package:gkk_flutter/features/art/aion2_art_gallery.dart';

void main() {
  group('Aion2ArtAssets Manifest Integrity Tests', () {
    test('Total registered assets count is exactly 126 across 14 categories', () {
      expect(Aion2ArtAssets.allAssets.length, equals(126));
    });

    test('All 14 categories have valid items registered', () {
      for (final category in Aion2AssetCategory.values) {
        final items = Aion2ArtAssets.byCategory(category);
        expect(
          items.isNotEmpty,
          isTrue,
          reason: 'Category ${category.name} has no items',
        );
      }
    });

    test('Category specific counts match the battalion specification', () {
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.portraitsElyos).length, equals(8));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.portraitsAsmodian).length, equals(8));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.bossPortraits).length, equals(6));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.empyreanLords).length, equals(6));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.skillsElemental).length, equals(16));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.skillsPhysical).length, equals(16));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.weapons).length, equals(16));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.armor).length, equals(16));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.backgroundsElysea).length, equals(4));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.backgroundsAsmodae).length, equals(4));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.backgroundsDungeons).length, equals(4));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.magicCircles).length, equals(8));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.flipbooks).length, equals(4));
      expect(Aion2ArtAssets.byCategory(Aion2AssetCategory.aion2Ui).length, equals(10));
    });

    test('Every declared asset file actually exists on the filesystem', () {
      for (final asset in Aion2ArtAssets.allAssets) {
        final file = File(asset.path);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Declared asset file does not exist on disk: ${asset.path}',
        );
      }
    });

    test('findById retrieves the exact item', () {
      final tiamat = Aion2ArtAssets.findById('boss_tiamat');
      expect(tiamat, isNotNull);
      expect(tiamat!.title, contains('Tiamat'));
      expect(tiamat.category, equals(Aion2AssetCategory.bossPortraits));
      expect(tiamat.rarity, equals('Mythic'));

      final missing = Aion2ArtAssets.findById('non_existent_asset_id');
      expect(missing, isNull);
    });

    test('Flipbook metadata specifies valid 4x4 atlas layout', () {
      final flipbooks = Aion2ArtAssets.byCategory(Aion2AssetCategory.flipbooks);
      for (final fb in flipbooks) {
        expect(fb.metadata['columns'], equals(4));
        expect(fb.metadata['rows'], equals(4));
        expect(fb.metadata['totalFrames'], equals(16));
      }
    });
  });

  group('Aion2ArtGallery Widget Tests', () {
    testWidgets('Gallery renders appbar, asset counter, search bar, and grid items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Aion2ArtGallery(),
        ),
      );
      await tester.pump();

      expect(find.text('AION-2 ART GALLERY'), findsOneWidget);
      expect(find.text('126 Assets'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Categories'), findsOneWidget);

      // Verify category chips exist
      expect(find.textContaining('Elyos Daevas'), findsOneWidget);
      expect(find.textContaining('World & Raid Bosses'), findsOneWidget);
    });

    testWidgets('Search query filters grid items dynamically', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Aion2ArtGallery(),
        ),
      );
      await tester.pump();

      // Enter search query "Tiamat"
      await tester.enterText(find.byType(TextField), 'Tiamat');
      await tester.pump();

      expect(find.textContaining('Tiamat'), findsWidgets);
      expect(find.text('Sanctum Sun Blade'), findsNothing);
    });
  });
}
