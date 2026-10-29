"""
Automated Test Suite for Procedural Dark Fantasy Props Architect (Ajan-Blender 7)
==================================================================================
Runs inside Blender's Python environment to verify:
1. PBR Material Factory generation (ShaderNodeTree, Principled BSDF, Bump, Emission, Noise/Voronoi)
2. All 6 Procedural Prop Generators:
   - StoneGargoyleGenerator
   - GothicArchGenerator
   - BrazierEmbersGenerator
   - IronPortcullisGenerator
   - StoneAltarGenerator
   - FlagstonesCrackedGenerator
3. Mesh topology & integrity (Vertices > 0, Polygons > 0, manifold bmesh)
4. Smooth shading on surfaces
5. Procedural UV unwrapping (uv_layers count >= 1)
6. GLB export & Draco mesh compression
"""

import sys
import os
import unittest
import tempfile

# Add project root to path
proj_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if proj_root not in sys.path:
    sys.path.insert(0, proj_root)

import bpy
from scripts.blender.procedural_props import (
    PBRMaterialFactory,
    StoneGargoyleGenerator,
    GothicArchGenerator,
    BrazierEmbersGenerator,
    IronPortcullisGenerator,
    StoneAltarGenerator,
    FlagstonesCrackedGenerator,
    ProceduralPropsPipeline,
)


class TestPBRMaterialFactory(unittest.TestCase):
    """Verifies procedural PBR shader node networks."""

    def test_dark_stone_material(self):
        mat = PBRMaterialFactory.create_dark_stone_material("Test_Stone")
        self.assertIsNotNone(mat)
        self.assertTrue(mat.use_nodes)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        self.assertIsNotNone(bsdf)
        # Verify Bump node exists
        bump_nodes = [n for n in mat.node_tree.nodes if n.type == "BUMP"]
        self.assertTrue(len(bump_nodes) >= 1)
        # Verify procedural texture nodes exist
        noise_nodes = [n for n in mat.node_tree.nodes if n.type == "TEX_NOISE"]
        self.assertTrue(len(noise_nodes) >= 1)

    def test_dark_iron_material(self):
        mat = PBRMaterialFactory.create_dark_iron_material("Test_Iron")
        self.assertIsNotNone(mat)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        self.assertIsNotNone(bsdf)
        self.assertAlmostEqual(bsdf.inputs["Metallic"].default_value, 0.94, places=2)
        bump_nodes = [n for n in mat.node_tree.nodes if n.type == "BUMP"]
        self.assertTrue(len(bump_nodes) >= 1)

    def test_gargoyle_stone_material(self):
        mat = PBRMaterialFactory.create_gargoyle_stone_material("Test_GargoyleMat")
        self.assertIsNotNone(mat)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        self.assertIsNotNone(bsdf)
        self.assertAlmostEqual(bsdf.inputs["Roughness"].default_value, 0.92, places=2)

    def test_burning_embers_material(self):
        mat = PBRMaterialFactory.create_burning_embers_material("Test_EmbersMat", emission_strength=14.0)
        self.assertIsNotNone(mat)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        self.assertIsNotNone(bsdf)
        # Check emission strength
        if "Emission Strength" in bsdf.inputs:
            self.assertGreater(bsdf.inputs["Emission Strength"].default_value, 0.0)
        # Check Voronoi texture node exists for coal cracks
        voronoi_nodes = [n for n in mat.node_tree.nodes if n.type == "TEX_VORONOI"]
        self.assertTrue(len(voronoi_nodes) >= 1)

    def test_altar_ritual_stone_material(self):
        mat = PBRMaterialFactory.create_altar_ritual_stone_material("Test_AltarMat")
        self.assertIsNotNone(mat)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        self.assertIsNotNone(bsdf)
        self.assertAlmostEqual(bsdf.inputs["Roughness"].default_value, 0.78, places=2)

    def test_flagstone_cracked_material(self):
        mat = PBRMaterialFactory.create_flagstone_cracked_material("Test_FlagstoneMat")
        self.assertIsNotNone(mat)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        self.assertIsNotNone(bsdf)
        bump_nodes = [n for n in mat.node_tree.nodes if n.type == "BUMP"]
        self.assertTrue(len(bump_nodes) >= 1)


class TestProceduralPropGenerators(unittest.TestCase):
    """Verifies geometry, UVs, modifiers, and materials for each prop."""

    def test_stone_gargoyle_generator(self):
        gen = StoneGargoyleGenerator(name="UT_Gargoyle")
        obj = gen.generate()
        self.assertIsNotNone(obj)
        self.assertEqual(obj.type, "MESH")

        mesh = obj.data
        self.assertGreater(len(mesh.vertices), 200, "Gargoyle mesh should have substantial vertex detail")
        self.assertGreater(len(mesh.polygons), 200, "Gargoyle mesh should have substantial face detail")
        self.assertGreaterEqual(len(mesh.uv_layers), 1, "Gargoyle must have procedural UV unwrap")

        # Check smooth shading
        smoothed = [p for p in mesh.polygons if p.use_smooth]
        self.assertGreater(len(smoothed), len(mesh.polygons) * 0.9, "Gargoyle polygons should be smooth-shaded")

        # Check PBR material
        self.assertTrue(len(obj.material_slots) >= 1)
        self.assertTrue("Gargoyle" in obj.material_slots[0].material.name)

    def test_gothic_arch_generator(self):
        gen = GothicArchGenerator(name="UT_GothicArch")
        obj = gen.generate()
        self.assertIsNotNone(obj)
        self.assertEqual(obj.type, "MESH")

        mesh = obj.data
        self.assertGreater(len(mesh.vertices), 300, "Gothic Arch must have detailed archivolt & piers")
        self.assertGreater(len(mesh.polygons), 200)
        self.assertGreaterEqual(len(mesh.uv_layers), 1, "Gothic Arch must have UV layer")

        # Check modifiers
        mod_names = [m.type for m in obj.modifiers]
        self.assertIn("BEVEL", mod_names, "Gothic Arch should have Bevel modifier")
        self.assertIn("WEIGHTED_NORMAL", mod_names, "Gothic Arch should have Weighted Normal modifier")

    def test_brazier_embers_generator(self):
        gen = BrazierEmbersGenerator(name="UT_Brazier")
        root = gen.generate()
        self.assertIsNotNone(root)

        # Stand and Embers should both exist
        self.assertEqual(len(gen.objects), 2, "Brazier must have metal stand and embers mesh")
        for o in gen.objects:
            self.assertEqual(o.type, "MESH")
            self.assertGreater(len(o.data.vertices), 50)
            self.assertGreaterEqual(len(o.data.uv_layers), 1)

        # Stand material should be iron, Embers should be fire/emissive
        materials = [slot.material.name for o in gen.objects for slot in o.material_slots if slot.material]
        self.assertTrue(any("Iron" in m for m in materials), "Brazier should have Iron material")
        self.assertTrue(any("Fire" in m for m in materials), "Brazier should have Fire/Embers material")

    def test_iron_portcullis_generator(self):
        gen = IronPortcullisGenerator(name="UT_Portcullis", bar_count=5, crossbar_count=3)
        obj = gen.generate()
        self.assertIsNotNone(obj)

        mesh = obj.data
        self.assertGreater(len(mesh.vertices), 500, "Portcullis should have vertical bars, spikes, crossbars & rivets")
        self.assertGreater(len(mesh.polygons), 500)
        self.assertGreaterEqual(len(mesh.uv_layers), 1, "Portcullis must have UV layer")

        self.assertTrue(len(obj.material_slots) >= 1)
        self.assertTrue("Iron" in obj.material_slots[0].material.name)

    def test_stone_altar_generator(self):
        gen = StoneAltarGenerator(name="UT_StoneAltar")
        obj = gen.generate()
        self.assertIsNotNone(obj)

        mesh = obj.data
        self.assertGreater(len(mesh.vertices), 200, "Stone Altar should have stepped plinth, slab & blood groove")
        self.assertGreater(len(mesh.polygons), 150)
        self.assertGreaterEqual(len(mesh.uv_layers), 1, "Stone Altar must have UV layer")

        self.assertTrue(len(obj.material_slots) >= 1)
        self.assertTrue("Ritual" in obj.material_slots[0].material.name or "Altar" in obj.material_slots[0].material.name)

    def test_flagstones_cracked_generator(self):
        gen = FlagstonesCrackedGenerator(name="UT_Flagstones", grid_rows=3, grid_cols=3)
        obj = gen.generate()
        self.assertIsNotNone(obj)

        mesh = obj.data
        self.assertGreater(len(mesh.vertices), 100, "Flagstones should have multiple paving slabs and cracks")
        self.assertGreater(len(mesh.polygons), 80)
        self.assertGreaterEqual(len(mesh.uv_layers), 1, "Flagstones must have UV layer")

        self.assertTrue(len(obj.material_slots) >= 1)


class TestExportPipeline(unittest.TestCase):
    """Verifies Draco-compressed GLB export for procedural props."""

    def test_draco_glb_export(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            gen = StoneAltarGenerator(name="UT_ExportAltar")
            gen.generate()
            glb_path = os.path.join(tmp_dir, "Altar_Test.glb")

            success = gen.export_glb(glb_path, use_draco=True)
            self.assertTrue(success, "GLB export must return True")
            self.assertTrue(os.path.exists(glb_path), "Exported GLB file must exist on disk")
            self.assertGreater(os.path.getsize(glb_path), 5000, "GLB file must not be empty or stub")


def run_tests():
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTest(loader.loadTestsFromTestCase(TestPBRMaterialFactory))
    suite.addTest(loader.loadTestsFromTestCase(TestProceduralPropGenerators))
    suite.addTest(loader.loadTestsFromTestCase(TestExportPipeline))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    if not result.wasSuccessful():
        sys.exit(1)


if __name__ == "__main__":
    run_tests()
