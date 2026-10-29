"""
Unit and Integration Tests for Texture Atlas Packer & PBR Channel Consolidator.
Tests:
- Rect geometry & intersection checks.
- MaxRects 2D bin packing algorithm logic & free rectangle splitting/pruning.
- Packing efficiency benchmark verifying > 85% efficiency requirement.
- Overlap detection ensuring zero subtexture overlap.
- Bleed padding verification (edge pixel replication & corner extrusion).
- UV coordinates boundaries [0..1] and scale/offset accuracy.
- Multi-channel PBR atlas generation (Albedo, Normal, Roughness, Metallic, ORM).
- JSON metadata schema validation.
"""

import json
import math
import os
import shutil
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

# Add scripts/opti to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scripts", "opti")))

from texture_atlas_packer import (
    FreeRectChoiceHeuristic,
    MaxRectsBinPack,
    PackedRegion,
    Rect,
    TextureAtlasPacker,
    TextureSet,
    create_procedural_pbr_set,
    scan_texture_directory,
)


class TestRectGeometry(unittest.TestCase):
    def test_rect_properties(self):
        r = Rect(10, 20, 100, 200, id="test")
        self.assertEqual(r.right, 110)
        self.assertEqual(r.bottom, 220)
        self.assertEqual(r.area, 20000)

    def test_rect_intersection(self):
        r1 = Rect(0, 0, 100, 100)
        r2 = Rect(50, 50, 100, 100)
        r3 = Rect(100, 100, 100, 100)  # Touches boundary, no overlap
        r4 = Rect(200, 200, 50, 50)

        self.assertTrue(r1.intersects(r2))
        self.assertTrue(r2.intersects(r1))
        self.assertFalse(r1.intersects(r3))
        self.assertFalse(r1.intersects(r4))

    def test_rect_containment(self):
        outer = Rect(0, 0, 500, 500)
        inner = Rect(10, 10, 100, 100)
        outside = Rect(400, 400, 200, 200)

        self.assertTrue(outer.contains(inner))
        self.assertFalse(inner.contains(outer))
        self.assertFalse(outer.contains(outside))


class TestMaxRectsPacking(unittest.TestCase):
    def test_single_item_placement(self):
        packer = MaxRectsBinPack(1024, 1024)
        placed = packer.insert(512, 512, FreeRectChoiceHeuristic.BEST_SHORT_SIDE_FIT)
        self.assertIsNotNone(placed)
        self.assertEqual(placed.x, 0)
        self.assertEqual(placed.y, 0)
        self.assertEqual(placed.width, 512)
        self.assertEqual(placed.height, 512)
        self.assertAlmostEqual(packer.efficiency, 0.25, places=4)

    def test_packing_efficiency_exceeds_85_percent(self):
        """Rigorous test verifying packing efficiency > 85% requirement on dense crowd sets."""
        packer = TextureAtlasPacker(atlas_width=2048, atlas_height=2048, padding=4)
        # High density realistic crowd texture set: 3 large bodies (1000x1000) and 4 medium props (500x500)
        items = [
            ("body_1", 1000, 1000),
            ("body_2", 1000, 1000),
            ("body_3", 1000, 1000),
            ("helm_1", 500, 500),
            ("shield_1", 500, 500),
            ("sword_1", 500, 500),
            ("boots_1", 500, 500),
        ]
        tsets = [TextureSet(name=n, width=w, height=h) for n, w, h in items]
        pages = packer.pack(tsets, auto_size=False)

        self.assertEqual(len(pages), 1, "All textures should pack into a single 2K atlas")
        bin_pack, regions = pages[0]
        content_area = sum(r.inner_rect.area for r in regions)
        total_area = bin_pack.bin_width * bin_pack.bin_height
        content_efficiency = content_area / total_area

        self.assertGreater(
            content_efficiency,
            0.85,
            f"Packing efficiency {content_efficiency * 100:.2f}% must exceed 85%",
        )
        self.assertAlmostEqual(content_efficiency, 0.9537, places=3)

    def test_non_overlapping_invariant(self):
        """Verifies that no two packed subrectangles intersect."""
        packer = TextureAtlasPacker(atlas_width=4096, atlas_height=4096, padding=4)
        items = []
        for i in range(8):
            items.append((f"large_{i}", 800, 800))
        for i in range(12):
            items.append((f"med_{i}", 400, 400))
        for i in range(16):
            items.append((f"small_{i}", 200, 200))

        tsets = [TextureSet(name=n, width=w, height=h) for n, w, h in items]
        pages = packer.pack(tsets, auto_size=False)

        for page_idx, (bin_pack, regions) in enumerate(pages):
            for i in range(len(regions)):
                for j in range(i + 1, len(regions)):
                    r1 = regions[i].outer_rect
                    r2 = regions[j].outer_rect
                    self.assertFalse(
                        r1.intersects(r2),
                        f"Region {regions[i].name} ({r1}) overlaps with {regions[j].name} ({r2})",
                    )

    def test_uv_boundaries_strictly_normalized(self):
        """Ensures all UV coordinates are strictly within [0.0, 1.0]."""
        packer = TextureAtlasPacker(atlas_width=2048, atlas_height=2048, padding=8)
        items = [
            ("t1", 512, 512),
            ("t2", 512, 512),
            ("t3", 256, 256),
            ("t4", 128, 128),
        ]
        tsets = [TextureSet(name=n, width=w, height=h) for n, w, h in items]
        pages = packer.pack(tsets, auto_size=False)

        for _, regions in pages:
            for r in regions:
                u_min, v_min = r.uv_min
                u_max, v_max = r.uv_max
                u_scale, v_scale = r.uv_scale
                u_offset, v_offset = r.uv_offset

                self.assertGreaterEqual(u_min, 0.0)
                self.assertLess(u_min, u_max)
                self.assertLessEqual(u_max, 1.0)

                self.assertGreaterEqual(v_min, 0.0)
                self.assertLess(v_min, v_max)
                self.assertLessEqual(v_max, 1.0)

                self.assertAlmostEqual(u_scale, u_max - u_min, places=6)
                self.assertAlmostEqual(v_scale, v_max - v_min, places=6)
                self.assertAlmostEqual(u_offset, u_min, places=6)
                self.assertAlmostEqual(v_offset, v_min, places=6)


class TestBleedPadding(unittest.TestCase):
    def test_bleed_padding_dilation_math(self):
        """Verifies that border pixels are accurately extruded into bleed padding."""
        canvas = np.zeros((16, 16, 3), dtype=np.uint8)
        # Create a 4x4 subtexture with distinct colors
        sub_img = np.zeros((4, 4, 3), dtype=np.uint8)
        sub_img[0, :, 0] = 100  # Top row red = 100
        sub_img[3, :, 1] = 200  # Bottom row green = 200
        sub_img[:, 0, 2] = 250  # Left col blue = 250
        sub_img[0, 0] = [10, 20, 30]  # Top-left corner
        sub_img[0, 3] = [40, 50, 60]  # Top-right corner
        sub_img[3, 0] = [70, 80, 90]  # Bottom-left corner
        sub_img[3, 3] = [11, 22, 33]  # Bottom-right corner

        # Place with 2px padding at inner_x=4, inner_y=4
        padding = 2
        TextureAtlasPacker.apply_bleed_padding(canvas, sub_img, inner_x=4, inner_y=4, width=4, height=4, padding=padding)

        # Core content untouched
        np.testing.assert_array_equal(canvas[4:8, 4:8], sub_img)

        # Top border extrusion check (y=2, 3 must match y=4)
        for y in range(2, 4):
            np.testing.assert_array_equal(canvas[y, 4:8], sub_img[0, :])

        # Bottom border extrusion check (y=8, 9 must match y=7)
        for y in range(8, 10):
            np.testing.assert_array_equal(canvas[y, 4:8], sub_img[3, :])

        # Left border extrusion check (x=2, 3 must match x=4)
        for x in range(2, 4):
            np.testing.assert_array_equal(canvas[4:8, x], sub_img[:, 0])

        # Right border extrusion check (x=8, 9 must match x=7)
        for x in range(8, 10):
            np.testing.assert_array_equal(canvas[4:8, x], sub_img[:, 3])

        # Corner pixel replications
        np.testing.assert_array_equal(canvas[2:4, 2:4], np.full((2, 2, 3), [10, 20, 30], dtype=np.uint8))
        np.testing.assert_array_equal(canvas[2:4, 8:10], np.full((2, 2, 3), [40, 50, 60], dtype=np.uint8))
        np.testing.assert_array_equal(canvas[8:10, 2:4], np.full((2, 2, 3), [70, 80, 90], dtype=np.uint8))
        np.testing.assert_array_equal(canvas[8:10, 8:10], np.full((2, 2, 3), [11, 22, 33], dtype=np.uint8))


class TestEndToEndPBRAtlasExport(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.output_dir = os.path.join(self.temp_dir, "packed_atlas")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_pbr_export_and_orm_generation(self):
        """Full end-to-end integration test creating PBR textures, packing, and verifying files."""
        # Create test PBR sets
        tsets = [
            create_procedural_pbr_set("soldier_body", 256, 256, self.temp_dir),
            create_procedural_pbr_set("soldier_armor", 256, 256, self.temp_dir),
            create_procedural_pbr_set("soldier_sword", 128, 128, self.temp_dir),
        ]

        packer = TextureAtlasPacker(atlas_width=1024, atlas_height=1024, padding=4)
        pages = packer.pack(tsets, auto_size=False)
        manifests = packer.render_and_export(
            pages,
            self.output_dir,
            base_name="crowd_unit_test",
            generate_orm=True,
        )

        self.assertEqual(len(manifests), 1)
        meta = manifests[0]
        self.assertEqual(meta["atlasWidth"], 1024)
        self.assertEqual(meta["atlasHeight"], 1024)
        self.assertEqual(meta["totalRegions"], 3)
        self.assertIn("albedo", meta["channels"])
        self.assertIn("normal", meta["channels"])
        self.assertIn("roughness", meta["channels"])
        self.assertIn("metallic", meta["channels"])
        self.assertIn("orm", meta["channels"])

        # Verify disk images exist and have exact 1024x1024 dimensions
        for ch_key, filename in meta["channels"].items():
            fpath = os.path.join(self.output_dir, filename)
            self.assertTrue(os.path.exists(fpath), f"File {fpath} should exist")
            with Image.open(fpath) as img:
                self.assertEqual(img.size, (1024, 1024))

        # Verify JSON metadata file is valid
        meta_json_path = os.path.join(self.output_dir, "crowd_unit_test_metadata.json")
        self.assertTrue(os.path.exists(meta_json_path))
        with open(meta_json_path, "r", encoding="utf-8") as f:
            loaded_data = json.load(f)
        self.assertEqual(loaded_data["totalRegions"], 3)
        self.assertIn("soldier_body", loaded_data["regions"])
        self.assertIn("soldier_armor", loaded_data["regions"])
        self.assertIn("soldier_sword", loaded_data["regions"])


if __name__ == "__main__":
    unittest.main()
