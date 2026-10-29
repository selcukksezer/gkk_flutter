"""
Unified Crowd Character Armature & Animation Optimization Pipeline.
Author: Ajan-Blender 8 (Armature & Animation Optimization Specialist)

Orchestrates automated rig validation, bone reduction, skeletal keyframe
optimization, and Vertex Animation Texture (VAT) baking for 10k crowd characters.
"""

import argparse
from dataclasses import asdict
import json
import os
import sys
from typing import Any, Dict, List, Optional

# Add current directory to path for local imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from crowd_rig_validator import CrowdRigValidator, RigValidationReport
from crowd_bone_reducer import CrowdBoneReducer, BoneNode, ReductionResult
from crowd_keyframe_reducer import CrowdKeyframeReducer, AnimationReductionReport
from crowd_vat_baker import CrowdVATBaker, VATBakeResult


class CrowdCharacterPipeline:
    """Master pipeline executing full crowd character optimization suite."""

    def __init__(
        self,
        max_crowd_bones: int = 30,
        pos_tolerance: float = 0.001,
        rot_tolerance_rad: float = 0.01,
    ):
        self.validator = CrowdRigValidator(max_crowd_bones=max_crowd_bones)
        self.reducer = CrowdBoneReducer()
        self.keyframe_reducer = CrowdKeyframeReducer(
            pos_tolerance=pos_tolerance,
            rot_tolerance_rad=rot_tolerance_rad,
        )
        self.vat_baker = CrowdVATBaker()

    def run_full_pipeline(
        self,
        bones_data: List[Dict[str, Any]],
        vertex_weights: List[List[tuple]],
        animation_tracks: Dict[str, Dict[str, Any]],
        mesh_frames_pos: Optional[List[Any]] = None,
        mesh_frames_norm: Optional[List[Any]] = None,
        output_dir: str = "./crowd_output",
        base_name: str = "crowd_humanoid",
    ) -> Dict[str, Any]:
        """
        Execute end-to-end optimization pipeline:
        1. Validate initial rig
        2. Reduce armature to crowd budget (<=26-30 bones) with weight remapping
        3. Validate reduced rig
        4. Decimate skeletal animation channels
        5. Bake VAT textures and generate GLSL shader
        6. Return complete audit report
        """
        os.makedirs(output_dir, exist_ok=True)

        # Step 1: Pre-validation
        initial_val_report = self.validator.validate_rig_data(
            bones_data, vertex_weights
        )

        # Step 2: Bone Reduction
        bone_nodes = [
            BoneNode(
                name=b["name"],
                parent=b.get("parent"),
                use_deform=b.get("use_deform", True),
                length=b.get("length", 1.0),
            )
            for b in bones_data
        ]
        red_result = self.reducer.reduce_armature(bone_nodes, vertex_weights)

        # Step 3: Post-validation on reduced rig
        reduced_bones_data = [
            {
                "name": b.name,
                "parent": b.parent,
                "use_deform": b.use_deform,
                "length": b.length,
            }
            for b in red_result.reduced_bones
        ]
        post_val_report = self.validator.validate_rig_data(
            reduced_bones_data, red_result.remapped_vertex_weights
        )

        # Step 4: Keyframe decimation on skeletal tracks
        anim_opt_tracks, anim_report = self.keyframe_reducer.optimize_animation(
            base_name, animation_tracks
        )

        # Step 5: VAT Baking (if frame positions & normals provided)
        vat_result = None
        if mesh_frames_pos and mesh_frames_norm:
            vat_result = self.vat_baker.bake_frames(
                positions_by_frame=mesh_frames_pos,
                normals_by_frame=mesh_frames_norm,
                output_dir=output_dir,
                base_name=base_name,
            )

        # Step 6: Compile Summary Report
        summary = {
            "character_name": base_name,
            "status": "SUCCESS" if post_val_report.is_valid_for_crowd else "FAILED_VALIDATION",
            "initial_rig": {
                "bone_count": initial_val_report.deform_bone_count,
                "is_valid": initial_val_report.is_valid_for_crowd,
                "issues_count": len(initial_val_report.issues),
            },
            "reduced_rig": {
                "bone_count": post_val_report.deform_bone_count,
                "removed_bones": red_result.removed_bones,
                "reduction_percentage": round(red_result.reduction_percentage, 2),
                "is_valid": post_val_report.is_valid_for_crowd,
            },
            "animation_optimization": {
                "total_original_keyframes": anim_report.total_original_keys,
                "total_reduced_keyframes": anim_report.total_reduced_keys,
                "keyframe_reduction_pct": round(anim_report.overall_reduction_pct, 2),
            },
            "vat_generation": {
                "enabled": vat_result is not None,
                "position_map": vat_result.pos_texture_path if vat_result else None,
                "normal_map": vat_result.norm_texture_path if vat_result else None,
                "metadata_json": vat_result.metadata_path if vat_result else None,
                "glsl_shader": vat_result.glsl_shader_path if vat_result else None,
            },
        }

        report_file = os.path.join(output_dir, f"{base_name}_optimization_report.json")
        with open(report_file, "w", encoding="utf-8") as f:
            json.dump(summary, f, indent=2)

        return summary


def main():
    parser = argparse.ArgumentParser(description="Crowd Character Armature & Animation Optimizer")
    parser.add_argument("--input", help="Path to input character JSON / glTF data")
    parser.add_argument("--output-dir", default="./output", help="Output directory")
    parser.add_argument("--max-bones", type=int, default=30, help="Maximum allowed crowd deform bones")
    args = parser.parse_args()

    print(f"Crowd Character Pipeline CLI initialized. Target max bones: {args.max_bones}")


if __name__ == "__main__":
    main()
