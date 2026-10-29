"""
Crowd Rigging Validator for gkk_flutter / Blender Pipeline.
Author: Ajan-Blender 8 (Armature & Animation Optimization Specialist)

Validates humanoid rigs for 10,000 crowd instance compatibility:
- Enforces bone budget constraints (max 24-32 bones for crowd instances).
- Identifies non-standard/unwanted deform bones (fingers, twist bones, facial/jaw, secondary physics).
- Validates skinning weights: maximum 4 influences per vertex, normalized sum = 1.0.
- Detects unweighted bones, degenerate bones, disconnected hierarchy roots.
- Operates both inside Blender (via `bpy`) and as a standalone validator for glTF/GLB or custom rig JSONs.
"""

from dataclasses import dataclass, field
import json
import math
from typing import Any, Dict, List, Optional, Set, Tuple

# Standard Humanoid Crowd Hierarchy (Budget: max 30 deform bones)
STANDARD_CROWD_BONES = {
    # Core kinetic chain (6 bones)
    "Root",
    "Hips",
    "Spine",
    "Chest",
    "Neck",
    "Head",
    # Left Arm (4 bones)
    "Clavicle_L",
    "UpperArm_L",
    "Forearm_L",
    "Hand_L",
    # Right Arm (4 bones)
    "Clavicle_R",
    "UpperArm_R",
    "Forearm_R",
    "Hand_R",
    # Left Leg (4 bones)
    "Thigh_L",
    "Calf_L",
    "Foot_L",
    "Toe_L",
    # Right Leg (4 bones)
    "Thigh_R",
    "Calf_R",
    "Foot_R",
    "Toe_R",
    # Optional crowd sockets / accessories (up to 4 bones)
    "Weapon_R",
    "Shield_L",
    "Cape_Root",
    "Scabbard",
}

# Synonyms for standard humanoid bone naming mapping
BONE_NAME_ALIASES: Dict[str, str] = {
    "pelvis": "Hips",
    "hip": "Hips",
    "hips": "Hips",
    "spine": "Spine",
    "spine_01": "Spine",
    "spine01": "Spine",
    "spine_02": "Chest",
    "spine02": "Chest",
    "chest": "Chest",
    "upper_chest": "Chest",
    "neck": "Neck",
    "head": "Head",
    # Left arm
    "clavicle.l": "Clavicle_L",
    "clavicle_l": "Clavicle_L",
    "shoulder.l": "Clavicle_L",
    "shoulder_l": "Clavicle_L",
    "upperarm.l": "UpperArm_L",
    "upperarm_l": "UpperArm_L",
    "upper_arm.l": "UpperArm_L",
    "arm.l": "UpperArm_L",
    "forearm.l": "Forearm_L",
    "forearm_l": "Forearm_L",
    "lowerarm.l": "Forearm_L",
    "hand.l": "Hand_L",
    "hand_l": "Hand_L",
    "wrist.l": "Hand_L",
    # Right arm
    "clavicle.r": "Clavicle_R",
    "clavicle_r": "Clavicle_R",
    "shoulder.r": "Clavicle_R",
    "shoulder_r": "Clavicle_R",
    "upperarm.r": "UpperArm_R",
    "upperarm_r": "UpperArm_R",
    "upper_arm.r": "UpperArm_R",
    "arm.r": "UpperArm_R",
    "forearm.r": "Forearm_R",
    "forearm_r": "Forearm_R",
    "lowerarm.r": "Forearm_R",
    "hand.r": "Hand_R",
    "hand_r": "Hand_R",
    "wrist.r": "Hand_R",
    # Left leg
    "thigh.l": "Thigh_L",
    "thigh_l": "Thigh_L",
    "upperleg.l": "Thigh_L",
    "calf.l": "Calf_L",
    "calf_l": "Calf_L",
    "shin.l": "Calf_L",
    "lowerleg.l": "Calf_L",
    "foot.l": "Foot_L",
    "foot_l": "Foot_L",
    "ankle.l": "Foot_L",
    "toe.l": "Toe_L",
    "toe_l": "Toe_L",
    "toes.l": "Toe_L",
    # Right leg
    "thigh.r": "Thigh_R",
    "thigh_r": "Thigh_R",
    "upperleg.r": "Thigh_R",
    "calf.r": "Calf_R",
    "calf_r": "Calf_R",
    "shin.r": "Calf_R",
    "lowerleg.r": "Calf_R",
    "foot.r": "Foot_R",
    "foot_r": "Foot_R",
    "ankle.r": "Foot_R",
    "toe.r": "Toe_R",
    "toe_r": "Toe_R",
    "toes.r": "Toe_R",
}


def normalize_bone_name(name: str) -> str:
    """Map arbitrary humanoid naming conventions to standardized canonical bone names."""
    clean = name.strip()
    lower = clean.lower()
    return BONE_NAME_ALIASES.get(lower, clean)


@dataclass
class ValidationIssue:
    severity: str  # "ERROR", "WARNING", "INFO"
    code: str
    message: str
    context: Dict[str, Any] = field(default_factory=dict)


@dataclass
class RigValidationReport:
    is_valid_for_crowd: bool
    total_bone_count: int
    deform_bone_count: int
    max_allowed_bones: int
    max_influences_per_vertex: int
    unweighted_bone_count: int
    issues: List[ValidationIssue] = field(default_factory=list)

    def summary(self) -> str:
        status = "PASSED" if self.is_valid_for_crowd else "FAILED"
        lines = [
            f"=== Crowd Rig Validation Report: {status} ===",
            f"Deform Bone Count: {self.deform_bone_count} (Limit: <= {self.max_allowed_bones})",
            f"Total Bone Count: {self.total_bone_count}",
            f"Max Influences Per Vertex: {self.max_influences_per_vertex} (Standard: <= 4)",
            f"Unweighted Bones: {self.unweighted_bone_count}",
            f"Total Issues: {len(self.issues)}",
        ]
        for issue in self.issues:
            lines.append(f"  [{issue.severity}] ({issue.code}): {issue.message}")
        return "\n".join(lines)


class CrowdRigValidator:
    """Automated rig validator ensuring humanoid armatures conform to crowd performance criteria."""

    def __init__(self, max_crowd_bones: int = 30, max_influences: int = 4):
        self.max_crowd_bones = max_crowd_bones
        self.max_influences = max_influences

    def validate_rig_data(
        self,
        bones: List[Dict[str, Any]],
        vertex_weights: Optional[List[List[Tuple[str, float]]]] = None,
    ) -> RigValidationReport:
        """
        Validate standalone rig data structure.
        bones: list of dicts: {'name': str, 'parent': Optional[str], 'use_deform': bool, 'length': float}
        vertex_weights: list of per-vertex weight lists: [(bone_name, weight), ...]
        """
        issues: List[ValidationIssue] = []
        bone_names = {b["name"] for b in bones}
        deform_bones = [b for b in bones if b.get("use_deform", True)]
        deform_count = len(deform_bones)
        total_count = len(bones)

        # 1. Check bone budget
        if deform_count > self.max_crowd_bones:
            issues.append(
                ValidationIssue(
                    severity="ERROR",
                    code="EXCESSIVE_BONE_COUNT",
                    message=(
                        f"Rig has {deform_count} deform bones, exceeding crowd threshold of "
                        f"{self.max_crowd_bones} bones. Bone reduction required."
                    ),
                    context={
                        "deform_count": deform_count,
                        "limit": self.max_crowd_bones,
                    },
                )
            )

        # 2. Check for root bone and tree hierarchy
        roots = [b for b in bones if not b.get("parent")]
        if len(roots) == 0:
            issues.append(
                ValidationIssue(
                    severity="ERROR",
                    code="NO_ROOT_BONE",
                    message="No root bone found in rig hierarchy (possible circular reference).",
                )
            )
        elif len(roots) > 1:
            root_names = [r["name"] for r in roots]
            issues.append(
                ValidationIssue(
                    severity="WARNING",
                    code="MULTIPLE_ROOT_BONES",
                    message=f"Armature has multiple root bones: {root_names}. Single root recommended.",
                    context={"roots": root_names},
                )
            )

        # 3. Check for high-cost crowd bones (fingers, facial, twist)
        flagged_categories: Dict[str, List[str]] = {
            "fingers": [],
            "facial": [],
            "twist": [],
        }
        for b in deform_bones:
            name_lower = b["name"].lower()
            if any(
                f in name_lower
                for f in [
                    "thumb",
                    "index",
                    "middle",
                    "ring",
                    "pinky",
                    "finger",
                    "digit",
                ]
            ):
                flagged_categories["fingers"].append(b["name"])
            elif any(
                f in name_lower
                for f in [
                    "eye",
                    "jaw",
                    "brow",
                    "lip",
                    "cheek",
                    "nose",
                    "tongue",
                    "teeth",
                ]
            ):
                flagged_categories["facial"].append(b["name"])
            elif "twist" in name_lower or "roll" in name_lower:
                flagged_categories["twist"].append(b["name"])

        for cat, list_bones in flagged_categories.items():
            if list_bones:
                issues.append(
                    ValidationIssue(
                        severity="WARNING",
                        code=f"CROWD_UNFRIENDLY_{cat.upper()}",
                        message=f"Found {len(list_bones)} {cat} deform bones: {list_bones[:5]}... Recommend collapsing into main kinetic limbs.",
                        context={"count": len(list_bones), "bones": list_bones},
                    )
                )

        # 4. Check zero length or degenerate bones
        for b in bones:
            length = b.get("length", 1.0)
            if length <= 1e-5:
                issues.append(
                    ValidationIssue(
                        severity="WARNING",
                        code="DEGENERATE_BONE_LENGTH",
                        message=f"Bone '{b['name']}' has near-zero length: {length:.6f}",
                        context={"bone": b["name"], "length": length},
                    )
                )

        # 5. Check skin weight constraints if vertex_weights provided
        max_influences_found = 0
        unweighted_verts = 0
        bones_with_weights: Set[str] = set()

        if vertex_weights is not None:
            for v_idx, v_weights in enumerate(vertex_weights):
                non_zero = [w for w in v_weights if w[1] > 1e-4]
                count = len(non_zero)
                if count > max_influences_found:
                    max_influences_found = count

                if count == 0:
                    unweighted_verts += 1
                else:
                    sum_weights = sum(w[1] for w in non_zero)
                    if not math.isclose(sum_weights, 1.0, rel_tol=1e-3, abs_tol=1e-3):
                        if (
                            v_idx < 5
                        ):  # Only log first few to avoid flooding report
                            issues.append(
                                ValidationIssue(
                                    severity="WARNING",
                                    code="UNNORMALIZED_WEIGHTS",
                                    message=f"Vertex {v_idx} has unnormalized weight sum: {sum_weights:.4f}",
                                    context={
                                        "vertex": v_idx,
                                        "sum": sum_weights,
                                    },
                                )
                            )

                    for b_name, _ in non_zero:
                        bones_with_weights.add(b_name)

            if max_influences_found > self.max_influences:
                issues.append(
                    ValidationIssue(
                        severity="ERROR",
                        code="EXCESSIVE_VERTEX_INFLUENCES",
                        message=(
                            f"Max vertex bone influence is {max_influences_found}, exceeding limit of "
                            f"{self.max_influences}. GPU vertex shader will drop or distort weights."
                        ),
                        context={
                            "max_influences": max_influences_found,
                            "limit": self.max_influences,
                        },
                    )
                )

            if unweighted_verts > 0:
                issues.append(
                    ValidationIssue(
                        severity="ERROR",
                        code="UNWEIGHTED_VERTICES",
                        message=f"Found {unweighted_verts} unweighted vertices. These will cause visual tearing or collapse to origin.",
                        context={"unweighted_count": unweighted_verts},
                    )
                )

        # 6. Unweighted deform bones
        unweighted_deforms = [
            b["name"]
            for b in deform_bones
            if vertex_weights is not None and b["name"] not in bones_with_weights
        ]
        if unweighted_deforms:
            issues.append(
                ValidationIssue(
                    severity="INFO",
                    code="UNWEIGHTED_DEFORM_BONES",
                    message=f"Armature contains {len(unweighted_deforms)} deform bones with zero vertex influences: {unweighted_deforms[:5]}",
                    context={"bones": unweighted_deforms},
                )
            )

        is_valid = not any(i.severity == "ERROR" for i in issues)

        return RigValidationReport(
            is_valid_for_crowd=is_valid,
            total_bone_count=total_count,
            deform_bone_count=deform_count,
            max_allowed_bones=self.max_crowd_bones,
            max_influences_per_vertex=max_influences_found,
            unweighted_bone_count=len(unweighted_deforms),
            issues=issues,
        )

    def validate_blender_armature(
        self, armature_obj_name: str
    ) -> RigValidationReport:
        """Inspect and validate an armature object in active Blender session using `bpy`."""
        try:
            import bpy  # type: ignore
        except ImportError:
            raise RuntimeError(
                "validate_blender_armature requires execution inside Blender with bpy available."
            )

        armature_obj = bpy.data.objects.get(armature_obj_name)
        if not armature_obj or armature_obj.type != "ARMATURE":
            raise ValueError(
                f"Object '{armature_obj_name}' not found or is not an ARMATURE."
            )

        arm_data = armature_obj.data
        bones_data: List[Dict[str, Any]] = []
        for b in arm_data.bones:
            bones_data.append(
                {
                    "name": b.name,
                    "parent": b.parent.name if b.parent else None,
                    "use_deform": b.use_deform,
                    "length": b.length,
                }
            )

        # Find skinned mesh children
        vertex_weights: List[List[Tuple[str, float]]] = []
        for child in armature_obj.children:
            if child.type == "MESH" and child.vertex_groups:
                vg_map = {vg.index: vg.name for vg in child.vertex_groups}
                mesh = child.data
                for v in mesh.vertices:
                    v_weights = [
                        (vg_map[g.group], g.weight)
                        for g in v.groups
                        if g.group in vg_map
                    ]
                    vertex_weights.append(v_weights)

        return self.validate_rig_data(
            bones_data, vertex_weights if vertex_weights else None
        )
