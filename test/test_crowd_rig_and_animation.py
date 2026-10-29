"""
Automated Unit and Integration Test Suite for Crowd Character Rigging & Animation.
Tests:
- Crowd Rigging Validator: topology checks, bone budgets, skin weight constraints.
- Crowd Bone Reducer: hierarchy collapsing, weight remapping, and normalization.
- Crowd Keyframe Reducer: RDP linear decimation, quaternion SLERP decimation, static pruning.
- Crowd VAT Baker: position/normal image generation, bounding box calculation, GLSL shader generation, decode verification.
- End-to-End Pipeline: full automated optimization flow.
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

# Add scripts directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scripts", "blender")))

from crowd_rig_validator import CrowdRigValidator, STANDARD_CROWD_BONES
from crowd_bone_reducer import CrowdBoneReducer, BoneNode
from crowd_keyframe_reducer import CrowdKeyframeReducer, quat_slerp, quat_angular_distance
from crowd_vat_baker import CrowdVATBaker
from crowd_pipeline import CrowdCharacterPipeline


def create_mock_hero_rig():
    """Generates a realistic 74-bone hero character rig with fingers, twist, and face bones."""
    bones = [
        # Root & Core Spine
        {"name": "Root", "parent": None, "use_deform": True, "length": 0.1},
        {"name": "Hips", "parent": "Root", "use_deform": True, "length": 0.2},
        {"name": "Spine", "parent": "Hips", "use_deform": True, "length": 0.25},
        {"name": "Chest", "parent": "Spine", "use_deform": True, "length": 0.3},
        {"name": "Neck", "parent": "Chest", "use_deform": True, "length": 0.1},
        {"name": "Head", "parent": "Neck", "use_deform": True, "length": 0.2},
        # Face bones (attached to Head)
        {"name": "Jaw", "parent": "Head", "use_deform": True, "length": 0.08},
        {"name": "Eye_L", "parent": "Head", "use_deform": True, "length": 0.04},
        {"name": "Eye_R", "parent": "Head", "use_deform": True, "length": 0.04},
        {"name": "Eyebrow_L", "parent": "Head", "use_deform": True, "length": 0.05},
        {"name": "Eyebrow_R", "parent": "Head", "use_deform": True, "length": 0.05},
        # Left Arm & Twist
        {"name": "Clavicle_L", "parent": "Chest", "use_deform": True, "length": 0.15},
        {"name": "UpperArm_L", "parent": "Clavicle_L", "use_deform": True, "length": 0.3},
        {"name": "UpperArm_Twist_L", "parent": "UpperArm_L", "use_deform": True, "length": 0.15},
        {"name": "Forearm_L", "parent": "UpperArm_L", "use_deform": True, "length": 0.28},
        {"name": "Forearm_Twist_L", "parent": "Forearm_L", "use_deform": True, "length": 0.14},
        {"name": "Hand_L", "parent": "Forearm_L", "use_deform": True, "length": 0.1},
        # Left Fingers (15 bones)
        {"name": "Thumb1_L", "parent": "Hand_L", "use_deform": True, "length": 0.03},
        {"name": "Thumb2_L", "parent": "Thumb1_L", "use_deform": True, "length": 0.03},
        {"name": "Thumb3_L", "parent": "Thumb2_L", "use_deform": True, "length": 0.02},
        {"name": "Index1_L", "parent": "Hand_L", "use_deform": True, "length": 0.04},
        {"name": "Index2_L", "parent": "Index1_L", "use_deform": True, "length": 0.03},
        {"name": "Index3_L", "parent": "Index2_L", "use_deform": True, "length": 0.02},
        {"name": "Middle1_L", "parent": "Hand_L", "use_deform": True, "length": 0.04},
        {"name": "Middle2_L", "parent": "Middle1_L", "use_deform": True, "length": 0.03},
        {"name": "Middle3_L", "parent": "Middle2_L", "use_deform": True, "length": 0.02},
        {"name": "Ring1_L", "parent": "Hand_L", "use_deform": True, "length": 0.04},
        {"name": "Ring2_L", "parent": "Ring1_L", "use_deform": True, "length": 0.03},
        {"name": "Ring3_L", "parent": "Ring2_L", "use_deform": True, "length": 0.02},
        {"name": "Pinky1_L", "parent": "Hand_L", "use_deform": True, "length": 0.03},
        {"name": "Pinky2_L", "parent": "Pinky1_L", "use_deform": True, "length": 0.02},
        {"name": "Pinky3_L", "parent": "Pinky2_L", "use_deform": True, "length": 0.02},
        # Right Arm & Twist
        {"name": "Clavicle_R", "parent": "Chest", "use_deform": True, "length": 0.15},
        {"name": "UpperArm_R", "parent": "Clavicle_R", "use_deform": True, "length": 0.3},
        {"name": "UpperArm_Twist_R", "parent": "UpperArm_R", "use_deform": True, "length": 0.15},
        {"name": "Forearm_R", "parent": "UpperArm_R", "use_deform": True, "length": 0.28},
        {"name": "Forearm_Twist_R", "parent": "Forearm_R", "use_deform": True, "length": 0.14},
        {"name": "Hand_R", "parent": "Forearm_R", "use_deform": True, "length": 0.1},
        # Right Fingers (15 bones)
        {"name": "Thumb1_R", "parent": "Hand_R", "use_deform": True, "length": 0.03},
        {"name": "Thumb2_R", "parent": "Thumb1_R", "use_deform": True, "length": 0.03},
        {"name": "Thumb3_R", "parent": "Thumb2_R", "use_deform": True, "length": 0.02},
        {"name": "Index1_R", "parent": "Hand_R", "use_deform": True, "length": 0.04},
        {"name": "Index2_R", "parent": "Index1_R", "use_deform": True, "length": 0.03},
        {"name": "Index3_R", "parent": "Index2_R", "use_deform": True, "length": 0.02},
        {"name": "Middle1_R", "parent": "Hand_R", "use_deform": True, "length": 0.04},
        {"name": "Middle2_R", "parent": "Middle1_R", "use_deform": True, "length": 0.03},
        {"name": "Middle3_R", "parent": "Middle2_R", "use_deform": True, "length": 0.02},
        {"name": "Ring1_R", "parent": "Hand_R", "use_deform": True, "length": 0.04},
        {"name": "Ring2_R", "parent": "Ring1_R", "use_deform": True, "length": 0.03},
        {"name": "Ring3_R", "parent": "Ring2_R", "use_deform": True, "length": 0.02},
        {"name": "Pinky1_R", "parent": "Hand_R", "use_deform": True, "length": 0.03},
        {"name": "Pinky2_R", "parent": "Pinky1_R", "use_deform": True, "length": 0.02},
        {"name": "Pinky3_R", "parent": "Pinky2_R", "use_deform": True, "length": 0.02},
        # Left Leg
        {"name": "Thigh_L", "parent": "Hips", "use_deform": True, "length": 0.45},
        {"name": "Thigh_Twist_L", "parent": "Thigh_L", "use_deform": True, "length": 0.2},
        {"name": "Calf_L", "parent": "Thigh_L", "use_deform": True, "length": 0.42},
        {"name": "Calf_Twist_L", "parent": "Calf_L", "use_deform": True, "length": 0.2},
        {"name": "Foot_L", "parent": "Calf_L", "use_deform": True, "length": 0.15},
        {"name": "Toe_L", "parent": "Foot_L", "use_deform": True, "length": 0.08},
        # Right Leg
        {"name": "Thigh_R", "parent": "Hips", "use_deform": True, "length": 0.45},
        {"name": "Thigh_Twist_R", "parent": "Thigh_R", "use_deform": True, "length": 0.2},
        {"name": "Calf_R", "parent": "Thigh_R", "use_deform": True, "length": 0.42},
        {"name": "Calf_Twist_R", "parent": "Calf_R", "use_deform": True, "length": 0.2},
        {"name": "Foot_R", "parent": "Calf_R", "use_deform": True, "length": 0.15},
        {"name": "Toe_R", "parent": "Foot_R", "use_deform": True, "length": 0.08},
        # Sockets
        {"name": "Weapon_R", "parent": "Hand_R", "use_deform": True, "length": 0.2},
        {"name": "Shield_L", "parent": "Forearm_L", "use_deform": True, "length": 0.2},
    ]
    return bones


class TestCrowdRigAndAnimation(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp(prefix="crowd_test_")

    def tearDown(self):
        if os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)

    def test_rig_validator_flags_hero_rig(self):
        """Validator must flag a 68-bone hero rig with EXCESSIVE_BONE_COUNT and finger/face warnings."""
        bones = create_mock_hero_rig()
        validator = CrowdRigValidator(max_crowd_bones=30)
        report = validator.validate_rig_data(bones)

        self.assertFalse(report.is_valid_for_crowd)
        self.assertGreater(report.deform_bone_count, 30)

        codes = [i.code for i in report.issues]
        self.assertIn("EXCESSIVE_BONE_COUNT", codes)
        self.assertIn("CROWD_UNFRIENDLY_FINGERS", codes)
        self.assertIn("CROWD_UNFRIENDLY_FACIAL", codes)
        self.assertIn("CROWD_UNFRIENDLY_TWIST", codes)

    def test_rig_validator_passes_compliant_crowd_rig(self):
        """Validator must approve an armature conforming to standard 24-28 bone crowd skeleton."""
        bones = [
            {"name": "Root", "parent": None, "use_deform": True, "length": 0.1},
            {"name": "Hips", "parent": "Root", "use_deform": True, "length": 0.2},
            {"name": "Spine", "parent": "Hips", "use_deform": True, "length": 0.25},
            {"name": "Chest", "parent": "Spine", "use_deform": True, "length": 0.3},
            {"name": "Neck", "parent": "Chest", "use_deform": True, "length": 0.1},
            {"name": "Head", "parent": "Neck", "use_deform": True, "length": 0.2},
            {"name": "Clavicle_L", "parent": "Chest", "use_deform": True, "length": 0.15},
            {"name": "UpperArm_L", "parent": "Clavicle_L", "use_deform": True, "length": 0.3},
            {"name": "Forearm_L", "parent": "UpperArm_L", "use_deform": True, "length": 0.28},
            {"name": "Hand_L", "parent": "Forearm_L", "use_deform": True, "length": 0.1},
            {"name": "Clavicle_R", "parent": "Chest", "use_deform": True, "length": 0.15},
            {"name": "UpperArm_R", "parent": "Clavicle_R", "use_deform": True, "length": 0.3},
            {"name": "Forearm_R", "parent": "UpperArm_R", "use_deform": True, "length": 0.28},
            {"name": "Hand_R", "parent": "Forearm_R", "use_deform": True, "length": 0.1},
            {"name": "Thigh_L", "parent": "Hips", "use_deform": True, "length": 0.45},
            {"name": "Calf_L", "parent": "Thigh_L", "use_deform": True, "length": 0.42},
            {"name": "Foot_L", "parent": "Calf_L", "use_deform": True, "length": 0.15},
            {"name": "Toe_L", "parent": "Foot_L", "use_deform": True, "length": 0.08},
            {"name": "Thigh_R", "parent": "Hips", "use_deform": True, "length": 0.45},
            {"name": "Calf_R", "parent": "Thigh_R", "use_deform": True, "length": 0.42},
            {"name": "Foot_R", "parent": "Calf_R", "use_deform": True, "length": 0.15},
            {"name": "Toe_R", "parent": "Foot_R", "use_deform": True, "length": 0.08},
            {"name": "Weapon_R", "parent": "Hand_R", "use_deform": True, "length": 0.2},
            {"name": "Shield_L", "parent": "Forearm_L", "use_deform": True, "length": 0.2},
        ]
        validator = CrowdRigValidator(max_crowd_bones=30)
        report = validator.validate_rig_data(bones)
        self.assertTrue(report.is_valid_for_crowd)
        self.assertEqual(report.deform_bone_count, 24)

    def test_bone_reduction_and_weight_remapping(self):
        """CrowdBoneReducer must collapse >60 bones to <=26 bones, remapping fingers and twists."""
        bones_data = create_mock_hero_rig()
        bone_nodes = [
            BoneNode(
                name=b["name"],
                parent=b["parent"],
                use_deform=b["use_deform"],
                length=b["length"],
            )
            for b in bones_data
        ]

        # Create test vertex weights containing finger, twist, and face influences
        vertex_weights = [
            # Vertex on index finger
            [("Index1_L", 0.6), ("Index2_L", 0.3), ("Hand_L", 0.1)],
            # Vertex on forearm with twist influence
            [("Forearm_L", 0.5), ("Forearm_Twist_L", 0.5)],
            # Vertex on jaw/face
            [("Jaw", 0.7), ("Head", 0.3)],
            # Vertex on thigh with twist influence
            [("Thigh_R", 0.4), ("Thigh_Twist_R", 0.4), ("Hips", 0.2)],
        ]

        reducer = CrowdBoneReducer()
        res = reducer.reduce_armature(bone_nodes, vertex_weights)

        # Assert bone count was drastically reduced
        self.assertLessEqual(res.reduced_bone_count, 26)
        self.assertGreater(res.reduction_percentage, 50.0)

        # Assert specific ancestry remappings
        self.assertEqual(res.bone_remapping_table["Index1_L"], "Hand_L")
        self.assertEqual(res.bone_remapping_table["Index2_L"], "Hand_L")
        self.assertEqual(res.bone_remapping_table["Forearm_Twist_L"], "Forearm_L")
        self.assertEqual(res.bone_remapping_table["Jaw"], "Head")
        self.assertEqual(res.bone_remapping_table["Thigh_Twist_R"], "Thigh_R")

        # Assert all remapped vertex weights sum to 1.0
        for v_idx, v_weights in enumerate(res.remapped_vertex_weights):
            weight_sum = sum(w for _, w in v_weights)
            self.assertAlmostEqual(weight_sum, 1.0, places=4, msg=f"Vertex {v_idx} unnormalized")
            # Assert influences are <= 4
            self.assertLessEqual(len(v_weights), 4)

        # Vertex 0 (fingers) should now only influence Hand_L with weight 1.0
        v0 = res.remapped_vertex_weights[0]
        self.assertEqual(len(v0), 1)
        self.assertEqual(v0[0][0], "Hand_L")
        self.assertAlmostEqual(v0[0][1], 1.0, places=4)

        # Vertex 1 (forearm + twist) should now be 100% Forearm_L
        v1 = res.remapped_vertex_weights[1]
        self.assertEqual(len(v1), 1)
        self.assertEqual(v1[0][0], "Forearm_L")

    def test_keyframe_reducer_rdp_linear(self):
        """RDP decimation must drop redundant collinear points."""
        reducer = CrowdKeyframeReducer(pos_tolerance=0.01)

        # Linear ramp from t=0, v=0 to t=10, v=10 with 50 redundant points
        times = np.linspace(0, 10, 50)
        keys = [(float(t), float(t)) for t in times]

        reduced = reducer.rdp_decimate_scalar(keys, tolerance=0.01)
        # Perfect line should collapse strictly to 2 endpoints
        self.assertEqual(len(reduced), 2)
        self.assertEqual(reduced[0], (0.0, 0.0))
        self.assertEqual(reduced[-1], (10.0, 10.0))

    def test_keyframe_reducer_slerp_quaternion(self):
        """Quaternion curve decimation must simplify smooth rotation arc within angular tolerance."""
        reducer = CrowdKeyframeReducer(rot_tolerance_rad=0.02)

        # 60 frames of a 90-degree yaw rotation around Y-axis
        q_start = (0.0, 0.0, 0.0, 1.0)
        angle_max = math.pi / 2.0  # 90 degrees
        q_end = (0.0, math.sin(angle_max / 2), 0.0, math.cos(angle_max / 2))

        frames = 60
        quat_keys = []
        for i in range(frames):
            t = i / (frames - 1)
            q = quat_slerp(q_start, q_end, t)
            quat_keys.append((float(i), q))

        reduced = reducer.slerp_decimate_quaternions(quat_keys, tolerance_rad=0.02)
        # Smooth constant-velocity SLERP arc matches linear interpolation in SO(3)
        self.assertLessEqual(len(reduced), 4)
        self.assertGreater(len(quat_keys), len(reduced))

    def test_vat_baker_generation_and_numerical_accuracy(self):
        """VAT Baker must create valid PNGs, metadata, and allow accurate vertex decoding."""
        baker = CrowdVATBaker()

        num_verts = 50
        num_frames = 20

        # Create animated wave: vertices moving along Z axis
        positions = []
        normals = []
        for f in range(num_frames):
            phase = (f / num_frames) * 2.0 * math.pi
            pos_frame = np.zeros((num_verts, 3), dtype=np.float32)
            norm_frame = np.zeros((num_verts, 3), dtype=np.float32)
            for v in range(num_verts):
                pos_frame[v, 0] = float(v) * 0.1
                pos_frame[v, 1] = 0.0
                pos_frame[v, 2] = math.sin(phase + v * 0.2) * 1.5
                norm_frame[v] = [0.0, 0.0, 1.0]
            positions.append(pos_frame)
            normals.append(norm_frame)

        res = baker.bake_frames(
            positions_by_frame=positions,
            normals_by_frame=normals,
            output_dir=self.temp_dir,
            base_name="hero_crowd",
            fps=30.0,
        )

        # Verify files created
        self.assertTrue(os.path.isfile(res.pos_texture_path))
        self.assertTrue(os.path.isfile(res.norm_texture_path))
        self.assertTrue(os.path.isfile(res.metadata_path))
        self.assertTrue(os.path.isfile(res.glsl_shader_path))

        # Check metadata contents
        with open(res.metadata_path, "r", encoding="utf-8") as f:
            meta = json.load(f)
        self.assertEqual(meta["vertex_count"], num_verts)
        self.assertEqual(meta["total_frames"], num_frames)

        # Read back position texture and verify decoding
        pos_img = Image.open(res.pos_texture_path)
        self.assertEqual(pos_img.size, (num_verts, num_frames))
        pos_pixels = np.array(pos_img, dtype=np.float32) / 255.0

        scale = np.array(res.scale, dtype=np.float32)
        offset = np.array(res.offset, dtype=np.float32)
        decoded_positions = pos_pixels * scale + offset

        # Compare decoded vertex positions with ground truth
        gt_positions = np.stack(positions, axis=0)  # (F, N, 3)
        max_err = np.max(np.abs(decoded_positions - gt_positions))
        # 8-bit quantization error bound: scale / 255
        expected_quant_bound = np.max(scale) / 255.0 * 1.5
        self.assertLess(max_err, expected_quant_bound)

        # Verify GLSL shader contains proper uniforms and texture lookups
        with open(res.glsl_shader_path, "r", encoding="utf-8") as f:
            shader_text = f.read()
        self.assertIn("uPosMap", shader_text)
        self.assertIn("uNormMap", shader_text)
        self.assertIn("aInstanceModelMatrix", shader_text)
        self.assertIn("VAT_SCALE", shader_text)

    def test_full_pipeline_run(self):
        """Master pipeline executes pre-validation, reduction, post-validation, keyframe decimation, and VAT baking."""
        pipeline = CrowdCharacterPipeline()
        hero_bones = create_mock_hero_rig()

        # Vertex weights on fingers and body
        vertex_weights = [
            [("Index1_L", 0.7), ("Hand_L", 0.3)],
            [("Thumb1_R", 0.8), ("Hand_R", 0.2)],
            [("Head", 0.5), ("Jaw", 0.5)],
            [("Chest", 0.6), ("Spine", 0.4)],
        ]

        # Animation tracks with redundant keyframes
        anim_tracks = {
            "Spine/translation": {
                "type": "translation",
                "keys": [(float(t), (0.0, 1.0, 0.0)) for t in range(30)],  # Static
            },
            "Hand_R/translation": {
                "type": "translation",
                "keys": [(float(t), (float(t) * 0.1, 0.5, 0.0)) for t in range(30)],  # Linear
            },
        }

        # Mock 4-vertex mesh across 5 frames
        pos_frames = [np.ones((4, 3), dtype=np.float32) * f for f in range(5)]
        norm_frames = [np.tile([0.0, 1.0, 0.0], (4, 1)).astype(np.float32) for _ in range(5)]

        summary = pipeline.run_full_pipeline(
            bones_data=hero_bones,
            vertex_weights=vertex_weights,
            animation_tracks=anim_tracks,
            mesh_frames_pos=pos_frames,
            mesh_frames_norm=norm_frames,
            output_dir=self.temp_dir,
            base_name="soldier_crowd",
        )

        self.assertEqual(summary["status"], "SUCCESS")
        self.assertFalse(summary["initial_rig"]["is_valid"])
        self.assertTrue(summary["reduced_rig"]["is_valid"])
        self.assertLessEqual(summary["reduced_rig"]["bone_count"], 26)
        self.assertGreater(summary["animation_optimization"]["keyframe_reduction_pct"], 50.0)
        self.assertTrue(summary["vat_generation"]["enabled"])


if __name__ == "__main__":
    unittest.main()
