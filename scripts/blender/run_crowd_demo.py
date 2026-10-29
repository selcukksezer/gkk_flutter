"""
Demonstration & Benchmark Runner for Crowd Rig Reduction, Keyframe Decimation, and VAT Baking.
Author: Ajan-Blender 8 (Armature & Animation Optimization Specialist)
"""

import json
import math
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from crowd_pipeline import CrowdCharacterPipeline


def generate_benchmark_crowd_soldier():
    """Generates realistic 72-bone soldier with marching animation and waving mesh."""
    # Bones
    bones = [
        {"name": "Root", "parent": None, "use_deform": True, "length": 0.1},
        {"name": "Hips", "parent": "Root", "use_deform": True, "length": 0.2},
        {"name": "Spine", "parent": "Hips", "use_deform": True, "length": 0.25},
        {"name": "Chest", "parent": "Spine", "use_deform": True, "length": 0.3},
        {"name": "Neck", "parent": "Chest", "use_deform": True, "length": 0.1},
        {"name": "Head", "parent": "Neck", "use_deform": True, "length": 0.2},
        # Face
        {"name": "Jaw", "parent": "Head", "use_deform": True, "length": 0.08},
        {"name": "Eye_L", "parent": "Head", "use_deform": True, "length": 0.04},
        {"name": "Eye_R", "parent": "Head", "use_deform": True, "length": 0.04},
        # Left Arm & Twists
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
        # Right Arm & Twists
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
        # Legs
        {"name": "Thigh_L", "parent": "Hips", "use_deform": True, "length": 0.45},
        {"name": "Thigh_Twist_L", "parent": "Thigh_L", "use_deform": True, "length": 0.2},
        {"name": "Calf_L", "parent": "Thigh_L", "use_deform": True, "length": 0.42},
        {"name": "Calf_Twist_L", "parent": "Calf_L", "use_deform": True, "length": 0.2},
        {"name": "Foot_L", "parent": "Calf_L", "use_deform": True, "length": 0.15},
        {"name": "Toe_L", "parent": "Foot_L", "use_deform": True, "length": 0.08},
        {"name": "Thigh_R", "parent": "Hips", "use_deform": True, "length": 0.45},
        {"name": "Thigh_Twist_R", "parent": "Thigh_R", "use_deform": True, "length": 0.2},
        {"name": "Calf_R", "parent": "Thigh_R", "use_deform": True, "length": 0.42},
        {"name": "Calf_Twist_R", "parent": "Calf_R", "use_deform": True, "length": 0.2},
        {"name": "Foot_R", "parent": "Calf_R", "use_deform": True, "length": 0.15},
        {"name": "Toe_R", "parent": "Foot_R", "use_deform": True, "length": 0.08},
        # Equipment
        {"name": "Weapon_R", "parent": "Hand_R", "use_deform": True, "length": 0.2},
        {"name": "Shield_L", "parent": "Forearm_L", "use_deform": True, "length": 0.2},
    ]

    # Skinned vertex weights for 50 mesh sample vertices
    vertex_weights = []
    for i in range(50):
        if i < 15:
            # Finger vertices
            vertex_weights.append([("Index1_L", 0.6), ("Index2_L", 0.2), ("Hand_L", 0.2)])
        elif i < 25:
            # Arm twist vertices
            vertex_weights.append([("UpperArm_Twist_L", 0.5), ("UpperArm_L", 0.5)])
        elif i < 35:
            # Face vertices
            vertex_weights.append([("Jaw", 0.5), ("Head", 0.5)])
        else:
            # Core torso/leg vertices
            vertex_weights.append([("Spine", 0.7), ("Chest", 0.3)])

    # Animation: 60 FPS walk cycle over 60 frames
    frames = 60
    anim_tracks = {
        "Hips/translation": {
            "type": "translation",
            "keys": [(float(t), (0.0, 0.95 + 0.05 * math.sin(t * 0.2), 0.0)) for t in range(frames)],
        },
        "Root/translation": {
            "type": "translation",
            "keys": [(float(t), (0.0, 0.0, float(t) * 0.05)) for t in range(frames)],  # Linear forward motion
        },
        "Weapon_R/scale": {
            "type": "scale",
            "keys": [(float(t), (1.0, 1.0, 1.0)) for t in range(frames)],  # Static invariant channel
        },
        "UpperArm_L/rotation": {
            "type": "rotation",
            "keys": [
                (float(t), (math.sin(t * 0.1) * 0.2, 0.0, 0.0, math.cos(t * 0.1)))
                for t in range(frames)
            ],
        },
    }

    # Deformed mesh frames for VAT: 60 frames of 120 vertices
    num_verts = 120
    mesh_pos = []
    mesh_norm = []
    for f in range(frames):
        p = np.zeros((num_verts, 3), dtype=np.float32)
        n = np.zeros((num_verts, 3), dtype=np.float32)
        for v in range(num_verts):
            theta = (v / num_verts) * 2 * math.pi
            r = 0.5 + 0.1 * math.sin(f * 0.1)
            p[v] = [r * math.cos(theta), float(v) * 0.015, r * math.sin(theta)]
            n[v] = [math.cos(theta), 0.0, math.sin(theta)]
        mesh_pos.append(p)
        mesh_norm.append(n)

    return bones, vertex_weights, anim_tracks, mesh_pos, mesh_norm


def run():
    out_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "reports",
        "crowd_rig_demo",
    )
    bones, weights, tracks, mesh_pos, mesh_norm = generate_benchmark_crowd_soldier()

    pipeline = CrowdCharacterPipeline()
    summary = pipeline.run_full_pipeline(
        bones_data=bones,
        vertex_weights=weights,
        animation_tracks=tracks,
        mesh_frames_pos=mesh_pos,
        mesh_frames_norm=mesh_norm,
        output_dir=out_dir,
        base_name="soldier_standard_crowd",
    )

    print("=== Pipeline Benchmark Execution Finished ===")
    print(json.dumps(summary, indent=2))
    return summary


if __name__ == "__main__":
    run()
