"""
Crowd Bone Reducer & Vertex Weight Remapper for gkk_flutter / Blender Pipeline.
Author: Ajan-Blender 8 (Armature & Animation Optimization Specialist)

Collapses high-density hero humanoid rigs (>60-150 bones) down to optimized
crowd humanoid skeletons (max 24-32 bones).

Features:
- Kinetic ancestry traversal: Remaps collapsed bones (fingers, facial, twist, helpers)
  to their nearest surviving kinetic parent bone.
- Seamless skin weight accumulation: All vertex weights assigned to deleted bones
  are transferred to the surviving ancestor, preventing mesh tearing or collapsed geometry.
- Top-4 influence pruning & normalization: Clamps vertex influences to GPU mobile standard (<=4)
  and normalizes sum of weights strictly to 1.0.
- Armature hierarchy re-linking: Re-parents surviving children across collapsed gaps.
- Dual-mode execution: Works seamlessly inside Blender (`bpy`) and standalone on rig/weight buffers.
"""

from dataclasses import dataclass, field
import math
from typing import Any, Dict, List, Optional, Set, Tuple

from crowd_rig_validator import normalize_bone_name, STANDARD_CROWD_BONES

# Canonical 26-Bone Minimal Humanoid Skeleton for Crowd Instances
DEFAULT_CROWD_ALLOWED_BONES: Set[str] = {
    "Root",
    "Hips",
    "Spine",
    "Chest",
    "Neck",
    "Head",
    "Clavicle_L",
    "UpperArm_L",
    "Forearm_L",
    "Hand_L",
    "Clavicle_R",
    "UpperArm_R",
    "Forearm_R",
    "Hand_R",
    "Thigh_L",
    "Calf_L",
    "Foot_L",
    "Toe_L",
    "Thigh_R",
    "Calf_R",
    "Foot_R",
    "Toe_R",
    "Weapon_R",
    "Shield_L",
    "Cape_Root",
    "Scabbard",
}


@dataclass
class BoneNode:
    name: str
    parent: Optional[str] = None
    use_deform: bool = True
    length: float = 1.0
    head: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    tail: Tuple[float, float, float] = (0.0, 1.0, 0.0)


@dataclass
class ReductionResult:
    original_bone_count: int
    reduced_bone_count: int
    removed_bones: List[str]
    bone_remapping_table: Dict[str, str]  # removed_bone -> surviving_ancestor
    reduced_bones: List[BoneNode]
    remapped_vertex_weights: List[List[Tuple[str, float]]]
    reduction_percentage: float


class CrowdBoneReducer:
    """Collapses complex character armatures into clean crowd-budget skeletons."""

    def __init__(
        self,
        target_allowed_bones: Optional[Set[str]] = None,
        max_influences_per_vertex: int = 4,
    ):
        self.allowed_bones = (
            target_allowed_bones
            if target_allowed_bones is not None
            else DEFAULT_CROWD_ALLOWED_BONES
        )
        self.max_influences = max_influences_per_vertex

    def find_surviving_ancestor(
        self,
        bone_name: str,
        bone_parent_map: Dict[str, Optional[str]],
        surviving_set: Set[str],
    ) -> Optional[str]:
        """Traverse up the parent chain until an allowed/surviving bone is found."""
        curr = bone_parent_map.get(bone_name)
        visited = set()
        while curr is not None:
            if curr in visited:
                break  # Circular reference protection
            visited.add(curr)
            norm_curr = normalize_bone_name(curr)
            if curr in surviving_set or norm_curr in surviving_set:
                return curr
            curr = bone_parent_map.get(curr)
        return None

    def build_remapping_table(
        self, bones: List[BoneNode]
    ) -> Tuple[Set[str], Dict[str, str]]:
        """
        Build table of retained bones and mapping of dropped bones to surviving parents.
        """
        bone_parent_map = {b.name: b.parent for b in bones}
        surviving_set: Set[str] = set()

        # Phase 1: Determine which bones match the allowed crowd skeleton
        for b in bones:
            norm_name = normalize_bone_name(b.name)
            if norm_name in self.allowed_bones or b.name in self.allowed_bones:
                surviving_set.add(b.name)

        # Fallback: If no bones matched standard names (e.g. custom armature), keep root and main kinetic depth
        if not surviving_set:
            # Keep top 24 bones by hierarchy level
            for b in bones[:24]:
                surviving_set.add(b.name)

        # Phase 2: Map non-surviving bones to their closest surviving ancestor
        remapping_table: Dict[str, str] = {}
        for b in bones:
            if b.name not in surviving_set:
                ancestor = self.find_surviving_ancestor(
                    b.name, bone_parent_map, surviving_set
                )
                if ancestor is None:
                    # If bone has no surviving ancestor, collapse to first surviving root or Hips
                    fallback = next(
                        (s for s in surviving_set if "hip" in s.lower()), None
                    )
                    if fallback is None:
                        fallback = next(iter(surviving_set))
                    ancestor = fallback
                remapping_table[b.name] = ancestor

        return surviving_set, remapping_table

    def remap_vertex_weights(
        self,
        vertex_weights: List[List[Tuple[str, float]]],
        remapping_table: Dict[str, str],
        surviving_set: Set[str],
    ) -> List[List[Tuple[str, float]]]:
        """
        Remap all vertex weights from deleted bones to surviving ancestors.
        Clamp to max_influences and normalize.
        """
        new_weights: List[List[Tuple[str, float]]] = []

        for v_weights in vertex_weights:
            accumulated: Dict[str, float] = {}

            for bone_name, weight in v_weights:
                if weight <= 1e-6:
                    continue
                # Determine target bone
                target = (
                    remapping_table.get(bone_name, bone_name)
                    if bone_name not in surviving_set
                    else bone_name
                )
                accumulated[target] = accumulated.get(target, 0.0) + weight

            # Sort influences descending by weight
            sorted_influences = sorted(
                accumulated.items(), key=lambda item: item[1], reverse=True
            )

            # Clamp to max influences (e.g. 4 for crowd mobile GPU)
            clamped = sorted_influences[: self.max_influences]

            # Re-normalize
            total = sum(w for _, w in clamped)
            if total > 1e-6:
                normalized = [(b, w / total) for b, w in clamped]
            else:
                # Fallback if vertex was zero-weighted: assign 1.0 to default surviving bone
                default_bone = next(iter(surviving_set))
                normalized = [(default_bone, 1.0)]

            new_weights.append(normalized)

        return new_weights

    def reduce_armature(
        self,
        bones: List[BoneNode],
        vertex_weights: List[List[Tuple[str, float]]],
    ) -> ReductionResult:
        """
        Execute bone reduction and weight transfer on pure data representation.
        """
        orig_count = len(bones)
        surviving_set, remapping_table = self.build_remapping_table(bones)

        # Build new bone list with re-linked parents
        reduced_bones: List[BoneNode] = []
        bone_parent_map = {b.name: b.parent for b in bones}

        for b in bones:
            if b.name in surviving_set:
                # Check if original parent survived, otherwise reparent to closest ancestor
                new_parent = b.parent
                if new_parent is not None and new_parent not in surviving_set:
                    new_parent = self.find_surviving_ancestor(
                        new_parent, bone_parent_map, surviving_set
                    )

                reduced_bones.append(
                    BoneNode(
                        name=b.name,
                        parent=new_parent,
                        use_deform=b.use_deform,
                        length=b.length,
                        head=b.head,
                        tail=b.tail,
                    )
                )

        # Remap vertex weights
        remapped_weights = self.remap_vertex_weights(
            vertex_weights, remapping_table, surviving_set
        )

        removed_bones = [b.name for b in bones if b.name not in surviving_set]
        reduction_pct = (
            (orig_count - len(reduced_bones)) / orig_count * 100.0
            if orig_count > 0
            else 0.0
        )

        return ReductionResult(
            original_bone_count=orig_count,
            reduced_bone_count=len(reduced_bones),
            removed_bones=removed_bones,
            bone_remapping_table=remapping_table,
            reduced_bones=reduced_bones,
            remapped_vertex_weights=remapped_weights,
            reduction_percentage=reduction_pct,
        )

    def reduce_blender_armature(
        self,
        armature_obj_name: str,
        mesh_obj_name: Optional[str] = None,
    ) -> ReductionResult:
        """
        Execute bone reduction directly inside Blender using `bpy`.
        Operates on EditBones and Mesh VertexGroups.
        """
        try:
            import bpy  # type: ignore
        except ImportError:
            raise RuntimeError(
                "reduce_blender_armature requires execution inside Blender environment."
            )

        arm_obj = bpy.data.objects.get(armature_obj_name)
        if not arm_obj or arm_obj.type != "ARMATURE":
            raise ValueError(f"Armature '{armature_obj_name}' not found.")

        # Gather bone nodes
        bones: List[BoneNode] = []
        for b in arm_obj.data.bones:
            bones.append(
                BoneNode(
                    name=b.name,
                    parent=b.parent.name if b.parent else None,
                    use_deform=b.use_deform,
                    length=b.length,
                    head=tuple(b.head_local),
                    tail=tuple(b.tail_local),
                )
            )

        # Locate mesh
        target_mesh_obj = None
        if mesh_obj_name:
            target_mesh_obj = bpy.data.objects.get(mesh_obj_name)
        else:
            for c in arm_obj.children:
                if c.type == "MESH" and c.vertex_groups:
                    target_mesh_obj = c
                    break

        if not target_mesh_obj:
            raise ValueError(
                "No skinned mesh object found attached to armature."
            )

        vg_map = {vg.index: vg.name for vg in target_mesh_obj.vertex_groups}
        mesh_data = target_mesh_obj.data
        vertex_weights: List[List[Tuple[str, float]]] = []
        for v in mesh_data.vertices:
            v_weights = [
                (vg_map[g.group], g.weight)
                for g in v.groups
                if g.group in vg_map
            ]
            vertex_weights.append(v_weights)

        # Run reduction calculations
        result = self.reduce_armature(bones, vertex_weights)

        # Apply to Blender mesh vertex groups
        # Reconstruct vertex group influences
        for vg in list(target_mesh_obj.vertex_groups):
            if vg.name in result.bone_remapping_table:
                # Removed group
                target_name = result.bone_remapping_table[vg.name]
                target_vg = target_mesh_obj.vertex_groups.get(target_name)
                if not target_vg:
                    target_vg = target_mesh_obj.vertex_groups.new(
                        name=target_name
                    )

                # Transfer weight from removed group to target group
                for v in mesh_data.vertices:
                    try:
                        w = vg.weight(v.index)
                        if w > 0:
                            curr_target_w = 0.0
                            try:
                                curr_target_w = target_vg.weight(v.index)
                            except RuntimeError:
                                pass
                            target_vg.add(
                                [v.index], curr_target_w + w, "REPLACE"
                            )
                    except RuntimeError:
                        pass
                # Delete old vertex group
                target_mesh_obj.vertex_groups.remove(vg)

        # Normalize remaining vertex groups in Blender
        bpy.context.view_layer.objects.active = target_mesh_obj
        bpy.ops.object.vertex_group_normalize_all(
            group_select_mode="ALL", lock_active=False
        )
        bpy.ops.object.vertex_group_limit_total(
            group_select_mode="ALL", limit=self.max_influences
        )

        # Apply to Blender Armature (Edit Mode: delete removed bones and update parent links)
        bpy.context.view_layer.objects.active = arm_obj
        bpy.ops.object.mode_set(mode="EDIT")
        edit_bones = arm_obj.data.edit_bones

        for b_name in result.removed_bones:
            eb = edit_bones.get(b_name)
            if eb:
                edit_bones.remove(eb)

        # Update parents of surviving bones
        for b_node in result.reduced_bones:
            eb = edit_bones.get(b_node.name)
            if eb and b_node.parent:
                parent_eb = edit_bones.get(b_node.parent)
                if parent_eb:
                    eb.parent = parent_eb

        bpy.ops.object.mode_set(mode="OBJECT")
        return result
