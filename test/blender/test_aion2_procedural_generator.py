#!/usr/bin/env python3
"""
Unit Test Suite for Aion 2 Procedural 3D Model & PBR Synthesis Engine
====================================================================
Author: aion2_3_blender_mcp_synth
Standard: AAA 2027 Aion 2 Dark / High-Fantasy Visual Architecture

Verifies:
1. PBR Texture Baker (5 channels: Albedo, Normal, Roughness, Metallic, Emission).
2. Mesh Geometry & Topology for all 3 procedural models:
   - Aion 2 Archon / Daeva Ethereal Wings
   - Gothic Stone Dungeon Pillar
   - Ornate Dark Fantasy Sword
3. 4-Tier LOD Hierarchy (LOD0, LOD1, LOD2, Impostor) with monotonic polygon reduction.
4. Smooth shading, edge bevel modifiers, and weighted normals.
5. Draco-compressed glTF/GLB binary package integrity.
"""

import os
import struct
import sys
import unittest

# Ensure project root in sys.path
proj_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if proj_root not in sys.path:
    sys.path.insert(0, proj_root)

import bpy
from scripts.blender.aion2_procedural_generator import (
    PBRTextureBaker,
    Aion2MaterialFactory,
    Aion2ArchonWingsGenerator,
    Aion2GothicPillarGenerator,
    Aion2DarkFantasySwordGenerator,
    Aion2ProceduralPipeline,
    clean_blender_scene,
)


class TestAion2PBRTextureBaker(unittest.TestCase):
    """Verifies automated 5-channel PBR texture baking."""

    def setUp(self):
        self.test_dir = os.path.abspath("assets/models/aion2/textures")
        os.makedirs(self.test_dir, exist_ok=True)

    def test_wings_texture_set(self):
        tex_paths = PBRTextureBaker.create_pbr_image_set(
            base_name="test_wings",
            output_dir=self.test_dir,
            albedo_rgb=(0.10, 0.09, 0.18),
            roughness_val=0.32,
            metallic_val=0.15,
            emission_rgb=(0.0, 0.90, 1.0),
            pattern_type="feathers",
            width=256,
            height=256,
        )
        self.assertEqual(len(tex_paths), 5)
        for channel in ("Albedo", "Normal", "Roughness", "Metallic", "Emission"):
            self.assertIn(channel, tex_paths)
            fpath = tex_paths[channel]
            self.assertTrue(os.path.exists(fpath), f"Missing {channel} map: {fpath}")
            self.assertGreater(os.path.getsize(fpath), 1000)

            # Check PNG magic bytes
            with open(fpath, "rb") as f:
                header = f.read(8)
                self.assertEqual(header, b"\x89PNG\r\n\x1a\n")

    def test_stone_pillar_texture_set(self):
        tex_paths = PBRTextureBaker.create_pbr_image_set(
            base_name="test_pillar",
            output_dir=self.test_dir,
            albedo_rgb=(0.14, 0.14, 0.13),
            roughness_val=0.84,
            metallic_val=0.02,
            emission_rgb=(0.0, 0.80, 1.0),
            pattern_type="stone",
            width=256,
            height=256,
        )
        for channel in ("Albedo", "Normal", "Roughness", "Metallic", "Emission"):
            self.assertTrue(os.path.exists(tex_paths[channel]))


class TestAion2MeshGenerators(unittest.TestCase):
    """Verifies procedural geometry generation, modifiers, and shading."""

    def setUp(self):
        clean_blender_scene()

    def test_archon_wings_generator(self):
        gen = Aion2ArchonWingsGenerator()
        gen.generate_textures("assets/models/aion2/textures")
        lod0 = gen.build_lod0_mesh()

        self.assertIsNotNone(lod0)
        self.assertEqual(lod0.type, 'MESH')
        self.assertGreater(len(lod0.data.vertices), 500)
        self.assertGreater(len(lod0.data.polygons), 500)

        # Verify smooth shading
        smooth_faces = sum(1 for p in lod0.data.polygons if p.use_smooth)
        self.assertEqual(smooth_faces, len(lod0.data.polygons))

        # Verify UV layers
        self.assertGreaterEqual(len(lod0.data.uv_layers), 1)

        # Verify modifiers
        mod_types = [m.type for m in lod0.modifiers]
        self.assertIn('WEIGHTED_NORMAL', mod_types)
        self.assertIn('BEVEL', mod_types)

        # Verify Material
        self.assertEqual(len(lod0.data.materials), 1)
        self.assertEqual(lod0.data.materials[0].name, "M_Aion2_ArchonWings_Ethereal")

    def test_gothic_pillar_generator(self):
        gen = Aion2GothicPillarGenerator()
        gen.generate_textures("assets/models/aion2/textures")
        lod0 = gen.build_lod0_mesh()

        self.assertIsNotNone(lod0)
        self.assertGreaterEqual(len(lod0.data.vertices), 700)
        self.assertGreaterEqual(len(lod0.data.polygons), 350)

        smooth_faces = sum(1 for p in lod0.data.polygons if p.use_smooth)
        self.assertEqual(smooth_faces, len(lod0.data.polygons))
        self.assertGreaterEqual(len(lod0.data.uv_layers), 1)

        mod_types = [m.type for m in lod0.modifiers]
        self.assertIn('WEIGHTED_NORMAL', mod_types)
        self.assertIn('BEVEL', mod_types)

    def test_dark_fantasy_sword_generator(self):
        gen = Aion2DarkFantasySwordGenerator()
        gen.generate_textures("assets/models/aion2/textures")
        lod0 = gen.build_lod0_mesh()

        self.assertIsNotNone(lod0)
        self.assertGreaterEqual(len(lod0.data.vertices), 300)
        self.assertGreaterEqual(len(lod0.data.polygons), 200)

        smooth_faces = sum(1 for p in lod0.data.polygons if p.use_smooth)
        self.assertEqual(smooth_faces, len(lod0.data.polygons))
        self.assertGreaterEqual(len(lod0.data.uv_layers), 1)


class TestAion2LODHierarchy(unittest.TestCase):
    """Verifies 4-tier LOD hierarchy and monotonic polygon reduction."""

    def setUp(self):
        clean_blender_scene()

    def test_sword_lod_hierarchy(self):
        gen = Aion2DarkFantasySwordGenerator()
        gen.generate_textures("assets/models/aion2/textures")
        lod0 = gen.build_lod0_mesh()
        lods = gen.create_lods_and_impostor(lod0)

        self.assertIn("root", lods)
        self.assertIn("LOD0", lods)
        self.assertIn("LOD1", lods)
        self.assertIn("LOD2", lods)
        self.assertIn("Impostor", lods)

        p0 = len(lods["LOD0"].data.polygons)
        p1 = len(lods["LOD1"].data.polygons)
        p2 = len(lods["LOD2"].data.polygons)
        p_imp = len(lods["Impostor"].data.polygons)

        # Monotonic polygon reduction
        self.assertGreater(p0, p1, f"LOD0 ({p0}) must have more polygons than LOD1 ({p1})")
        self.assertGreater(p1, p2, f"LOD1 ({p1}) must have more polygons than LOD2 ({p2})")
        self.assertGreater(p2, p_imp, f"LOD2 ({p2}) must have more polygons than Impostor ({p_imp})")
        self.assertLessEqual(p_imp, 4, "Impostor should be a lightweight billboard quad")


class TestAion2GLBBinaryIntegrity(unittest.TestCase):
    """Verifies binary GLB headers and Draco compression on exported assets."""

    def test_exported_glb_files(self):
        models = [
            "aion2_ethereal_wings",
            "aion2_gothic_dungeon_pillar",
            "aion2_dark_fantasy_sword",
        ]

        for mod in models:
            master_glb = os.path.abspath(f"assets/models/aion2/{mod}.glb")
            self.assertTrue(os.path.exists(master_glb), f"Missing master GLB: {master_glb}")
            self.assertGreater(os.path.getsize(master_glb), 50000)

            # Inspect binary GLB header
            with open(master_glb, "rb") as f:
                header = f.read(12)
                magic, version, length = struct.unpack("<4sII", header)
                self.assertEqual(magic, b"glTF")
                self.assertEqual(version, 2)
                self.assertEqual(length, os.path.getsize(master_glb))

                # Inspect JSON chunk
                c_len, c_type = struct.unpack("<II", f.read(8))
                self.assertEqual(c_type, 0x4E4F534A)  # b'JSON'
                json_bytes = f.read(c_len)
                self.assertIn(b"KHR_draco_mesh_compression", json_bytes)

            # Inspect discrete LOD files
            for lod in ("LOD0", "LOD1", "LOD2", "Impostor"):
                tier_glb = os.path.abspath(f"assets/models/aion2/{mod}_{lod}.glb")
                self.assertTrue(os.path.exists(tier_glb), f"Missing {lod} GLB: {tier_glb}")
                self.assertGreater(os.path.getsize(tier_glb), 10000)


def run_tests():
    suite = unittest.TestLoader().loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    if not result.wasSuccessful():
        sys.exit(1)


if __name__ == "__main__":
    run_tests()
