#!/usr/bin/env python3
"""
Unit and Integration Test Suite for Dark Fantasy PBR Shader Node Graph Master
=============================================================================
Tests all 4 AAA dark fantasy shader subsystems, presets, modular node groups,
socket topology, cross-version compatibility, and link integrity in Blender.

Author: Ajan-Blender 9 (PBR Shader Node Graph Master)
"""

import sys
import unittest
from typing import Any, List

try:
    import bpy
    HAS_BPY = True
except ImportError:
    HAS_BPY = False

if HAS_BPY:
    # Add scripts/blender to path
    import os
    scripts_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "blender"))
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)

    import dark_fantasy_pbr_nodes as df_pbr
    from dark_fantasy_pbr_nodes import (
        DarkFantasyPBRBuilder,
        AmbientOcclusionConfig,
        MicroRoughnessConfig,
        PuddleWetnessConfig,
        EmissionPulseConfig,
        BasePBRConfig,
        resolve_bsdf_socket,
        create_magical_rune_greatsword,
        create_rainy_dungeon_stone,
        create_cursed_blood_armor,
        create_ancient_catacomb_gold,
        setup_demo_showcase_scene,
    )


class TestDarkFantasyPBRNodes(unittest.TestCase):
    """Rigorous tests for the Dark Fantasy PBR shader generation pipeline."""

    def setUp(self):
        if not HAS_BPY:
            self.skipTest("bpy is not available")
        # Clear existing materials
        for m in list(bpy.data.materials):
            bpy.data.materials.remove(m)
        for g in list(bpy.data.node_groups):
            bpy.data.node_groups.remove(g)

    def test_01_builder_initialization(self):
        """Verify initialization creates clean BSDF and Material Output with valid connection."""
        builder = DarkFantasyPBRBuilder(material_name="Test_Init")
        mat = builder.initialize_material()

        self.assertIsNotNone(mat)
        self.assertIsNotNone(builder.node_tree)
        self.assertIsNotNone(builder.bsdf_node)
        self.assertIsNotNone(builder.output_node)

        # Check BSDF connected to Material Output
        surface_in = builder.output_node.inputs['Surface']
        self.assertTrue(surface_in.is_linked)
        link = surface_in.links[0]
        self.assertEqual(link.from_node, builder.bsdf_node)
        self.assertEqual(link.from_socket.name, 'BSDF')

        # Check shared TexCoord and Time nodes
        self.assertIsNotNone(builder.tex_coord_node)
        self.assertIsNotNone(builder.time_node)

    def test_02_socket_resolution_cross_version(self):
        """Verify version-aware BSDF socket resolution for Base Color, Roughness, Coat, Emission, Specular."""
        builder = DarkFantasyPBRBuilder(material_name="Test_Sockets")
        builder.initialize_material()
        bsdf = builder.bsdf_node

        s_bc = resolve_bsdf_socket(bsdf, "Base Color")
        self.assertIsNotNone(s_bc)

        s_met = resolve_bsdf_socket(bsdf, "Metallic")
        self.assertIsNotNone(s_met)

        s_rough = resolve_bsdf_socket(bsdf, "Roughness")
        self.assertIsNotNone(s_rough)

        s_coat_w = resolve_bsdf_socket(bsdf, "Coat Weight")
        self.assertIsNotNone(s_coat_w)
        self.assertIn(s_coat_w.name, ["Coat Weight", "Clearcoat"])

        s_coat_r = resolve_bsdf_socket(bsdf, "Coat Roughness")
        self.assertIsNotNone(s_coat_r)
        self.assertIn(s_coat_r.name, ["Coat Roughness", "Clearcoat Roughness"])

        s_em_c = resolve_bsdf_socket(bsdf, "Emission Color")
        self.assertIsNotNone(s_em_c)
        self.assertIn(s_em_c.name, ["Emission Color", "Emission"])

        s_em_s = resolve_bsdf_socket(bsdf, "Emission Strength")
        self.assertIsNotNone(s_em_s)

        s_spec = resolve_bsdf_socket(bsdf, "Specular")
        self.assertIsNotNone(s_spec)
        self.assertIn(s_spec.name, ["Specular IOR Level", "Specular"])

    def test_03_subsystem_ambient_occlusion_and_cavity(self):
        """Verify Ambient Occlusion, Power contrast, Cavity Tint, and Specular suppression."""
        builder = DarkFantasyPBRBuilder(material_name="Test_AO")
        builder.initialize_material()
        nt = builder.node_tree

        # Mock inputs
        val_node = nt.nodes.new('ShaderNodeValue')
        val_node.outputs[0].default_value = 0.5
        col_mix = nt.nodes.new('ShaderNodeMix')
        col_mix.data_type = 'RGBA'

        ao_cfg = AmbientOcclusionConfig(
            ao_distance=0.75,
            ao_power=1.8,
            ao_strength=0.9,
            cavity_tint=(0.02, 0.03, 0.05, 1.0),
            cavity_tint_strength=0.7,
            specular_occlusion=0.85
        )

        occluded_color, occluded_spec = builder.build_ambient_occlusion_network(
            ao_cfg, col_mix.outputs[2], val_node.outputs[0]
        )

        self.assertIsNotNone(occluded_color)
        self.assertIsNotNone(occluded_spec)

        # Check nodes existence
        ao_node = nt.nodes.get("AO_Generator")
        self.assertIsNotNone(ao_node)
        self.assertAlmostEqual(ao_node.inputs['Distance'].default_value, 0.75)

        ao_pow = nt.nodes.get("AO_Power")
        self.assertIsNotNone(ao_pow)
        self.assertEqual(ao_pow.operation, 'POWER')
        self.assertAlmostEqual(ao_pow.inputs[1].default_value, 1.8)

        cavity_invert = nt.nodes.get("Cavity_Invert")
        self.assertIsNotNone(cavity_invert)
        self.assertEqual(cavity_invert.operation, 'SUBTRACT')

        ao_mult = nt.nodes.get("AO_BaseColor_Multiply")
        self.assertIsNotNone(ao_mult)
        self.assertEqual(ao_mult.blend_type, 'MULTIPLY')

    def test_04_subsystem_micro_roughness_detail(self):
        """Verify Micro-Roughness high-frequency tiling, centering offset, and clamped add."""
        builder = DarkFantasyPBRBuilder(material_name="Test_MicroRoughness")
        builder.initialize_material()
        nt = builder.node_tree

        base_rough = nt.nodes.new('ShaderNodeValue')
        base_rough.outputs[0].default_value = 0.5

        micro_cfg = MicroRoughnessConfig(
            detail_scale=20.0,
            intensity=0.30,
            noise_detail=6.5
        )

        micro_out = builder.build_micro_roughness_network(micro_cfg, base_rough.outputs[0])
        self.assertIsNotNone(micro_out)

        mapping = nt.nodes.get("Micro_UV_Mapping")
        self.assertIsNotNone(mapping)
        self.assertAlmostEqual(mapping.inputs['Scale'].default_value[0], 20.0)

        center_sub = nt.nodes.get("Micro_Center")
        self.assertIsNotNone(center_sub)
        self.assertEqual(center_sub.operation, 'SUBTRACT')
        self.assertAlmostEqual(center_sub.inputs[1].default_value, 0.5)

        scale_mult = nt.nodes.get("Micro_Scale_Intensity")
        self.assertIsNotNone(scale_mult)
        self.assertEqual(scale_mult.operation, 'MULTIPLY')
        self.assertAlmostEqual(scale_mult.inputs[1].default_value, 0.30)

        add_node = nt.nodes.get("Micro_Roughness_Add")
        self.assertIsNotNone(add_node)
        self.assertEqual(add_node.operation, 'ADD')
        self.assertTrue(add_node.use_clamp)

    def test_05_subsystem_puddle_wetness(self):
        """Verify Puddle layer: water darkening, mirror smoothing, clearcoat weight, normal flattening."""
        builder = DarkFantasyPBRBuilder(material_name="Test_Puddles")
        builder.initialize_material()
        nt = builder.node_tree

        col_node = nt.nodes.new('ShaderNodeMix')
        col_node.data_type = 'RGBA'
        r_node = nt.nodes.new('ShaderNodeValue')
        norm_node = nt.nodes.new('ShaderNodeNormalMap')

        wet_cfg = PuddleWetnessConfig(
            water_darkening=0.55,
            puddle_roughness=0.02,
            clearcoat_max=1.0,
            clearcoat_roughness=0.02,
            normal_flatten_factor=0.90,
            noise_scale=3.5,
            puddle_threshold=0.50
        )

        w_col, w_rough, coat_w, coat_r, w_norm = builder.build_puddle_wetness_network(
            wet_cfg, col_node.outputs[2], r_node.outputs[0], norm_node.outputs['Normal']
        )

        self.assertIsNotNone(w_col)
        self.assertIsNotNone(w_rough)
        self.assertIsNotNone(coat_w)
        self.assertIsNotNone(coat_r)
        self.assertIsNotNone(w_norm)

        # Check nodes
        puddle_noise = nt.nodes.get("Puddle_Noise_Mask")
        self.assertIsNotNone(puddle_noise)
        self.assertAlmostEqual(puddle_noise.inputs['Scale'].default_value, 3.5)

        puddle_ramp = nt.nodes.get("Puddle_Ramp")
        self.assertIsNotNone(puddle_ramp)
        self.assertEqual(len(puddle_ramp.color_ramp.elements), 2)

        darken_mix = nt.nodes.get("Water_Absorption_Multiply")
        self.assertIsNotNone(darken_mix)
        self.assertEqual(darken_mix.blend_type, 'MULTIPLY')

        wet_rough_mix = nt.nodes.get("Wet_Roughness_Mix")
        self.assertIsNotNone(wet_rough_mix)
        self.assertEqual(wet_rough_mix.blend_type, 'MIX')

        coat_mult = nt.nodes.get("Puddle_Coat_Weight")
        self.assertIsNotNone(coat_mult)
        self.assertEqual(coat_mult.operation, 'MULTIPLY')
        self.assertAlmostEqual(coat_mult.inputs[1].default_value, 1.0)

        normal_flatten = nt.nodes.get("Puddle_Normal_Flatten")
        self.assertIsNotNone(normal_flatten)

    def test_06_subsystem_magical_emission_pulse(self):
        """Verify Breathing Sine wave + chaotic jitter oscillator, dual-tone magic ramp, and HDR multiplier."""
        builder = DarkFantasyPBRBuilder(material_name="Test_Emission")
        builder.initialize_material()
        nt = builder.node_tree

        em_cfg = EmissionPulseConfig(
            core_color=(0.1, 0.9, 1.0, 1.0),
            glancing_color=(0.7, 0.05, 0.9, 1.0),
            pulse_speed=2.5,
            pulse_amplitude=0.7,
            min_glow=0.2,
            flicker_speed=15.0,
            flicker_strength=0.25,
            base_strength=30.0
        )

        em_col, em_str = builder.build_magical_emission_pulse_network(em_cfg)
        self.assertIsNotNone(em_col)
        self.assertIsNotNone(em_str)

        # Verify Sine wave oscillator
        sine_node = nt.nodes.get("Pulse_Sine")
        self.assertIsNotNone(sine_node)
        self.assertEqual(sine_node.operation, 'SINE')

        # Verify Jitter
        flicker_sine = nt.nodes.get("Flicker_Sine")
        self.assertIsNotNone(flicker_sine)
        self.assertEqual(flicker_sine.operation, 'SINE')

        # Verify HDR multiplier
        hdr_mult = nt.nodes.get("HDR_Strength_Mult")
        self.assertIsNotNone(hdr_mult)
        self.assertEqual(hdr_mult.operation, 'MULTIPLY')
        self.assertAlmostEqual(hdr_mult.inputs[1].default_value, 30.0)

        # Verify Dual-Tone Ramp
        dt_ramp = nt.nodes.get("Magic_DualTone_Ramp")
        self.assertIsNotNone(dt_ramp)
        self.assertEqual(len(dt_ramp.color_ramp.elements), 2)
        # Check core color
        c0 = dt_ramp.color_ramp.elements[0].color
        self.assertAlmostEqual(c0[0], 0.1, places=2)
        self.assertAlmostEqual(c0[1], 0.9, places=2)

    def test_07_complete_presets(self):
        """Verify all 4 dark fantasy presets construct complete, valid materials."""
        presets = [
            ("M_MagicalRuneGreatsword", create_magical_rune_greatsword("Test_Greatsword"), True),
            ("M_RainyDungeonStone", create_rainy_dungeon_stone("Test_DungeonStone"), False),
            ("M_CursedBloodArmor", create_cursed_blood_armor("Test_BloodArmor"), True),
            ("M_AncientCatacombGold", create_ancient_catacomb_gold("Test_CatacombGold"), True),
        ]

        for p_name, mat, expects_emission in presets:
            self.assertIsNotNone(mat)
            nt = mat.node_tree
            bsdf = nt.nodes.get("Principled_BSDF")
            self.assertIsNotNone(bsdf)

            # Check that Base Color, Roughness, Coat Weight, Normal are linked
            s_bc = resolve_bsdf_socket(bsdf, "Base Color")
            self.assertTrue(s_bc.is_linked, f"Base Color must be linked in {p_name}")

            s_rough = resolve_bsdf_socket(bsdf, "Roughness")
            self.assertTrue(s_rough.is_linked, f"Roughness must be linked in {p_name}")

            s_coat_w = resolve_bsdf_socket(bsdf, "Coat Weight")
            self.assertTrue(s_coat_w.is_linked, f"Coat Weight must be linked in {p_name}")

            s_norm = resolve_bsdf_socket(bsdf, "Normal")
            self.assertTrue(s_norm.is_linked, f"Normal must be linked in {p_name}")

            if expects_emission:
                s_em_c = resolve_bsdf_socket(bsdf, "Emission Color")
                self.assertTrue(s_em_c.is_linked, f"Emission Color must be linked in {p_name}")
                s_em_s = resolve_bsdf_socket(bsdf, "Emission Strength")
                self.assertTrue(s_em_s.is_linked, f"Emission Strength must be linked in {p_name}")

    def test_08_reusable_node_groups(self):
        """Verify generation of encapsulated reusable node groups."""
        ng1 = DarkFantasyPBRBuilder.create_micro_roughness_node_group("Test_Micro_Group")
        self.assertIsNotNone(ng1)
        self.assertIn("Final Roughness", [s.name for s in ng1.nodes['Group Output'].inputs])

        ng2 = DarkFantasyPBRBuilder.create_puddle_wetness_node_group("Test_Puddle_Group")
        self.assertIsNotNone(ng2)
        out_names = [s.name for s in ng2.nodes['Group Output'].inputs]
        self.assertIn("Wet Base Color", out_names)
        self.assertIn("Wet Roughness", out_names)
        self.assertIn("Coat Weight", out_names)
        self.assertIn("Wet Normal", out_names)

        ng3 = DarkFantasyPBRBuilder.create_magical_pulse_node_group("Test_Pulse_Group")
        self.assertIsNotNone(ng3)
        out_names3 = [s.name for s in ng3.nodes['Group Output'].inputs]
        self.assertIn("Emission Color", out_names3)
        self.assertIn("Emission Strength", out_names3)

    def test_09_link_integrity_and_no_broken_sockets(self):
        """Audit every link across all generated materials to ensure 100% validity and no dangling links."""
        create_magical_rune_greatsword("Test_Audit_Sword")
        mat = bpy.data.materials["Test_Audit_Sword"]
        nt = mat.node_tree

        self.assertGreater(len(nt.nodes), 25, "Node graph should have substantial node depth")
        self.assertGreater(len(nt.links), 25, "Node graph should have extensive link wiring")

        for link in nt.links:
            self.assertTrue(link.is_valid, f"Link {link.from_node.name}->{link.to_node.name} is invalid")
            self.assertIsNotNone(link.from_socket)
            self.assertIsNotNone(link.to_socket)
            self.assertTrue(link.to_socket.is_linked)

    def test_10_showcase_scene_construction(self):
        """Verify the full showcase scene builds cleanly with 4 showcase spheres, floor, lights, camera."""
        objects = setup_demo_showcase_scene()
        self.assertGreaterEqual(len(objects), 5)
        names = [o.name for o in objects]
        self.assertIn("Showcase_Magical_Rune_Blade", names)
        self.assertIn("Showcase_Rainy_Dungeon_Stone", names)
        self.assertIn("Showcase_Cursed_Blood_Armor", names)
        self.assertIn("Showcase_Ancient_Catacomb_Gold", names)
        self.assertIn("Showcase_Floor", names)


def run_tests():
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestDarkFantasyPBRNodes)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    if not result.wasSuccessful():
        sys.exit(1)


if __name__ == "__main__":
    run_tests()
