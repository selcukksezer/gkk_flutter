#!/usr/bin/env python3
"""
Cycles PBR Texture Baking Pipeline
==================================
Production-grade automated PBR texture baking pipeline for Blender 5.0+ / Cycles.
Automates baking of:
- Albedo / Base Color (pure unlit reflectance)
- Tangent-space Normal map
- Roughness map
- Metallic map
- Emission map
- Ambient Occlusion (AO) map
- Packed ORM map (Occlusion = R, Roughness = G, Metallic = B)

Features:
- Standalone CLI execution:
    blender --background --python scripts/blender/cycles_pbr_baker.py -- [options]
    or
    python scripts/blender/cycles_pbr_baker.py [options]
- Smart UV projection & UV validation
- Multi-material collapsing to single-drawcall PBR atlas
- Automated re-assembly of baked textures into clean Principled BSDF
- GLB export with embedded PBR textures (glTF 2.0 PBR standard)
- Texture verification and validation metrics

Author: Worker 12 (b8_worker_12_blender_bake)
Battalion: battalion_8_real_glb_blender_harvest
"""

from __future__ import annotations

import argparse
import math
import os
import subprocess
import sys
import time
from typing import Dict, List, Optional, Tuple, Any

# Detect if running inside Blender
IN_BLENDER = False
try:
    import bpy
    import mathutils
    IN_BLENDER = True
except ImportError:
    pass


# ============================================================================
# Standalone Runner (Outside Blender)
# ============================================================================

def find_blender_executable() -> Optional[str]:
    """Find Blender 5.0+ binary on system."""
    known_paths = [
        r"F:\blender\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender\blender.exe",
    ]
    for p in known_paths:
        if os.path.isfile(p):
            return p
    # Try PATH
    import shutil
    which_blender = shutil.which("blender")
    if which_blender:
        return which_blender
    return None


def run_via_blender_cli(args: list[str]) -> int:
    """Spawns Blender in headless mode passing this script and arguments."""
    blender_exe = find_blender_executable()
    if not blender_exe:
        print("[ERROR] Blender executable not found on system!", file=sys.stderr)
        return 1
    
    script_path = os.path.abspath(__file__)
    cmd = [blender_exe, "--background", "--python", script_path, "--"] + args
    print(f"[LAUNCH] Executing Blender background runner: {' '.join(cmd[:4])} ...")
    proc = subprocess.run(cmd)
    return proc.returncode


# ============================================================================
# Blender Internal Baking Engine
# ============================================================================

class CyclesPBRBaker:
    """Automated Cycles PBR texture baking engine."""

    def __init__(
        self,
        resolution: int = 1024,
        samples: int = 16,
        margin: int = 16,
        unwrap_mode: str = "smart",
        device: str = "CPU",
        join_meshes: bool = True,
        export_glb: bool = True,
        pack_orm: bool = True,
    ):
        self.resolution = resolution
        self.samples = samples
        self.margin = margin
        self.unwrap_mode = unwrap_mode
        self.device = device
        self.join_meshes = join_meshes
        self.export_glb = export_glb
        self.pack_orm = pack_orm
        self.channels = ["albedo", "normal", "roughness", "metallic", "emission", "ao"]

    def setup_cycles(self, scene: bpy.types.Scene) -> None:
        """Configures Cycles rendering and baking settings."""
        scene.render.engine = 'CYCLES'
        scene.cycles.device = self.device
        scene.cycles.samples = self.samples
        scene.render.bake.margin = self.margin
        scene.render.bake.margin_type = 'EXTEND'
        scene.render.bake.use_selected_to_active = False

    def prepare_mesh(self, mesh_objs: List[bpy.types.Object]) -> bpy.types.Object:
        """Prepares mesh geometry and UV maps for baking."""
        bpy.ops.object.select_all(action='DESELECT')
        
        # If multiple meshes and joining is requested
        if len(mesh_objs) > 1 and self.join_meshes:
            print(f"[PREPARE] Joining {len(mesh_objs)} meshes into a unified model for single-atlas baking...")
            for obj in mesh_objs:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = mesh_objs[0]
            bpy.ops.object.join()
            target_obj = bpy.context.view_layer.objects.active
        else:
            target_obj = mesh_objs[0]
            target_obj.select_set(True)
            bpy.context.view_layer.objects.active = target_obj

    def check_uv_validity(self, obj: bpy.types.Object) -> bool:
        """Checks if mesh has valid UV coordinates in [0, 1] range."""
        if not obj.data.uv_layers:
            return False
        uv_layer = obj.data.uv_layers.active or obj.data.uv_layers[0]
        if not uv_layer.data:
            return False
        # Sample first 200 loop UVs
        sample_size = min(len(uv_layer.data), 200)
        sample = uv_layer.data[:sample_size]
        min_u = min(d.uv[0] for d in sample)
        max_u = max(d.uv[0] for d in sample)
        min_v = min(d.uv[1] for d in sample)
        max_v = max(d.uv[1] for d in sample)
        
        # Check for degenerate zero coordinates or negative values
        if min_u == max_u == 0.0 and min_v == max_v == 0.0:
            return False
        if min_u < -0.05 or min_v < -0.05 or max_u > 1.2 or max_v > 1.2:
            return False
        return True

    def prepare_mesh(self, mesh_objs: List[bpy.types.Object]) -> bpy.types.Object:
        """Prepares mesh geometry and UV maps for baking."""
        bpy.ops.object.select_all(action='DESELECT')
        
        # If multiple meshes and joining is requested
        if len(mesh_objs) > 1 and self.join_meshes:
            print(f"[PREPARE] Joining {len(mesh_objs)} meshes into a unified model for single-atlas baking...")
            for obj in mesh_objs:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = mesh_objs[0]
            bpy.ops.object.join()
            target_obj = bpy.context.view_layer.objects.active
        else:
            target_obj = mesh_objs[0]
            target_obj.select_set(True)
            bpy.context.view_layer.objects.active = target_obj

        # Check and handle UV coordinates
        is_uv_valid = self.check_uv_validity(target_obj)
        needs_unwrap = False
        if not is_uv_valid:
            needs_unwrap = True
            print("[PREPARE] Mesh has missing, degenerate, or out-of-bounds UV coordinates. Generating Smart UV Project...")
        elif self.unwrap_mode == "force_smart":
            needs_unwrap = True
            print("[PREPARE] Force smart unwrapping enabled. Generating clean UV layout...")

        if needs_unwrap:
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.uv.smart_project(
                angle_limit=math.radians(66.0),
                island_margin=0.02,
                area_weight=0.0,
                correct_aspect=True,
                scale_to_bounds=False
            )
            bpy.ops.object.mode_set(mode='OBJECT')
        
        # Ensure active UV layer exists
        if not target_obj.data.uv_layers.active:
            if target_obj.data.uv_layers:
                target_obj.data.uv_layers.active = target_obj.data.uv_layers[0]

        print(f"[PREPARE] Mesh '{target_obj.name}' ready with UV layer: '{target_obj.data.uv_layers.active.name}'")
        return target_obj

    def bake_channel(
        self,
        target_obj: bpy.types.Object,
        channel: str,
        out_filepath: str,
    ) -> Optional[str]:
        """Bakes a single PBR channel with Cycles."""
        scene = bpy.context.scene
        res = self.resolution
        img_name = f"__bake_{channel}_{int(time.time()*1000)}__"
        img = bpy.data.images.new(img_name, width=res, height=res, alpha=True)
        img.colorspace_settings.name = 'sRGB' if channel in ['albedo', 'emission'] else 'Non-Color'

        # Ensure object is exclusively selected and active
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = target_obj
        target_obj.select_set(True)

        # Attach image texture node to all materials (strictly deselecting other nodes)
        temp_nodes: List[Tuple[bpy.types.Material, bpy.types.Node]] = []
        for mat in target_obj.data.materials:
            if not mat or not mat.node_tree:
                continue
            nodes = mat.node_tree.nodes
            for n in nodes:
                n.select = False
            tex_node = nodes.new('ShaderNodeTexImage')
            tex_node.name = "__BAKE_TARGET__"
            tex_node.image = img
            nodes.active = tex_node
            tex_node.select = True
            temp_nodes.append((mat, tex_node))

        restore_data = []
        try:
            if channel == "albedo":
                # Temporarily neutralize metallic to capture true base color across metals & dielectrics
                for mat in target_obj.data.materials:
                    if not mat or not mat.node_tree:
                        continue
                    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
                    if bsdf:
                        met_sock = bsdf.inputs.get('Metallic')
                        if met_sock:
                            if met_sock.is_linked:
                                link = met_sock.links[0]
                                from_sock = link.from_socket
                                mat.node_tree.links.remove(link)
                                restore_data.append(('metallic_link', mat, met_sock, from_sock))
                            else:
                                restore_data.append(('metallic_val', mat, met_sock, met_sock.default_value))
                            met_sock.default_value = 0.0

                scene.cycles.bake_type = 'DIFFUSE'
                bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=self.margin)

            elif channel == "normal":
                scene.cycles.bake_type = 'NORMAL'
                bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', margin=self.margin)

            elif channel == "roughness":
                scene.cycles.bake_type = 'ROUGHNESS'
                bpy.ops.object.bake(type='ROUGHNESS', margin=self.margin)

            elif channel == "metallic":
                # Route metallic socket to emission surface for 100% accurate grayscale bake
                for mat in target_obj.data.materials:
                    if not mat or not mat.node_tree:
                        continue
                    nodes = mat.node_tree.nodes
                    links = mat.node_tree.links
                    bsdf = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
                    out_node = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None)
                    if bsdf and out_node:
                        old_link = next((l for l in links if l.to_node == out_node and l.to_socket.name == 'Surface'), None)
                        emit_node = nodes.new('ShaderNodeEmission')
                        emit_node.name = "__TEMP_EMIT_METALLIC__"
                        met_sock = bsdf.inputs.get('Metallic')
                        if met_sock and met_sock.is_linked:
                            links.new(met_sock.links[0].from_socket, emit_node.inputs['Color'])
                        elif met_sock:
                            m = met_sock.default_value
                            emit_node.inputs['Color'].default_value = (m, m, m, 1.0)
                        links.new(emit_node.outputs['Emission'], out_node.inputs['Surface'])
                        restore_data.append(('emit_metallic', mat, emit_node, old_link))

                scene.cycles.bake_type = 'EMIT'
                bpy.ops.object.bake(type='EMIT', margin=self.margin)

            elif channel == "emission":
                scene.cycles.bake_type = 'EMIT'
                bpy.ops.object.bake(type='EMIT', margin=self.margin)

            elif channel == "ao":
                scene.cycles.bake_type = 'AO'
                bpy.ops.object.bake(type='AO', margin=self.margin)

            # Save baked image to target path
            img.filepath_raw = os.path.abspath(out_filepath)
            img.file_format = 'PNG'
            img.save()
            file_size = os.path.getsize(out_filepath)
            print(f"[BAKED] Channel '{channel}' successfully saved -> {out_filepath} ({file_size:,} bytes)")
            return out_filepath

        except Exception as e:
            print(f"[ERROR] Failed to bake channel '{channel}': {e}", file=sys.stderr)
            return None

        finally:
            # Restore temporary shader modifications
            for item in restore_data:
                tag = item[0]
                if tag == 'metallic_link':
                    _, mat, met_sock, from_sock = item
                    mat.node_tree.links.new(from_sock, met_sock)
                elif tag == 'metallic_val':
                    _, mat, met_sock, old_val = item
                    met_sock.default_value = old_val
                elif tag == 'emit_metallic':
                    _, mat, emit_node, old_link = item
                    out_node = next((n for n in mat.node_tree.nodes if n.type == 'OUTPUT_MATERIAL'), None)
                    mat.node_tree.nodes.remove(emit_node)
                    if old_link and out_node:
                        mat.node_tree.links.new(old_link.from_socket, out_node.inputs['Surface'])

            # Remove temporary bake target texture nodes
            for mat, tex_node in temp_nodes:
                mat.node_tree.nodes.remove(tex_node)

    def pack_orm_texture(
        self,
        ao_path: Optional[str],
        roughness_path: str,
        metallic_path: str,
        out_orm_path: str,
    ) -> Optional[str]:
        """Packs Occlusion (R), Roughness (G), Metallic (B) into single ORM map."""
        try:
            res = self.resolution
            ao_img = bpy.data.images.load(ao_path) if (ao_path and os.path.isfile(ao_path)) else None
            rough_img = bpy.data.images.load(roughness_path) if os.path.isfile(roughness_path) else None
            met_img = bpy.data.images.load(metallic_path) if os.path.isfile(metallic_path) else None

            orm_img = bpy.data.images.new("orm_packed", width=res, height=res, alpha=False)
            orm_img.colorspace_settings.name = 'Non-Color'

            ao_pixels = list(ao_img.pixels) if ao_img else [1.0] * (res * res * 4)
            rough_pixels = list(rough_img.pixels) if rough_img else [0.5] * (res * res * 4)
            met_pixels = list(met_img.pixels) if met_img else [0.0] * (res * res * 4)

            total_px = res * res
            orm_pixels = [0.0] * (total_px * 4)
            for i in range(total_px):
                idx = i * 4
                orm_pixels[idx] = ao_pixels[idx]         # R = AO
                orm_pixels[idx + 1] = rough_pixels[idx]   # G = Roughness
                orm_pixels[idx + 2] = met_pixels[idx]     # B = Metallic
                orm_pixels[idx + 3] = 1.0                # A = 1.0

            orm_img.pixels.foreach_set(orm_pixels)
            orm_img.filepath_raw = os.path.abspath(out_orm_path)
            orm_img.file_format = 'PNG'
            orm_img.save()
            print(f"[BAKED] Packed ORM map successfully saved -> {out_orm_path} ({os.path.getsize(out_orm_path):,} bytes)")
            return out_orm_path
        except Exception as e:
            print(f"[WARN] Could not pack ORM texture: {e}", file=sys.stderr)
            return None

    def export_baked_glb(
        self,
        target_obj: bpy.types.Object,
        baked_maps: Dict[str, str],
        model_name: str,
        out_glb_path: str,
    ) -> Optional[str]:
        """Creates unified single-drawcall PBR material and exports model to GLB."""
        try:
            print(f"[EXPORT] Assembling clean single-drawcall PBR material for '{model_name}'...")
            baked_mat = bpy.data.materials.new(name=f"M_{model_name}_PBR_Baked")
            baked_mat.use_nodes = True
            nodes = baked_mat.node_tree.nodes
            links = baked_mat.node_tree.links
            nodes.clear()

            out_node = nodes.new('ShaderNodeOutputMaterial')
            out_node.location = (600, 0)
            bsdf = nodes.new('ShaderNodeBsdfPrincipled')
            bsdf.location = (200, 0)
            links.new(bsdf.outputs['BSDF'], out_node.inputs['Surface'])

            # Albedo
            if "albedo" in baked_maps and os.path.isfile(baked_maps["albedo"]):
                alb_img = bpy.data.images.load(baked_maps["albedo"])
                alb_img.colorspace_settings.name = 'sRGB'
                alb_node = nodes.new('ShaderNodeTexImage')
                alb_node.location = (-300, 300)
                alb_node.image = alb_img
                links.new(alb_node.outputs['Color'], bsdf.inputs['Base Color'])

            # Normal
            if "normal" in baked_maps and os.path.isfile(baked_maps["normal"]):
                norm_img = bpy.data.images.load(baked_maps["normal"])
                norm_img.colorspace_settings.name = 'Non-Color'
                norm_node = nodes.new('ShaderNodeTexImage')
                norm_node.location = (-600, -100)
                norm_node.image = norm_img
                norm_map = nodes.new('ShaderNodeNormalMap')
                norm_map.location = (-250, -100)
                links.new(norm_node.outputs['Color'], norm_map.inputs['Color'])
                links.new(norm_map.outputs['Normal'], bsdf.inputs['Normal'])

            # Roughness
            if "roughness" in baked_maps and os.path.isfile(baked_maps["roughness"]):
                rough_img = bpy.data.images.load(baked_maps["roughness"])
                rough_img.colorspace_settings.name = 'Non-Color'
                rough_node = nodes.new('ShaderNodeTexImage')
                rough_node.location = (-300, -400)
                rough_node.image = rough_img
                links.new(rough_node.outputs['Color'], bsdf.inputs['Roughness'])

            # Metallic
            if "metallic" in baked_maps and os.path.isfile(baked_maps["metallic"]):
                met_img = bpy.data.images.load(baked_maps["metallic"])
                met_img.colorspace_settings.name = 'Non-Color'
                met_node = nodes.new('ShaderNodeTexImage')
                met_node.location = (-300, -700)
                met_node.image = met_img
                links.new(met_node.outputs['Color'], bsdf.inputs['Metallic'])

            # Emission
            if "emission" in baked_maps and os.path.isfile(baked_maps["emission"]):
                emit_img = bpy.data.images.load(baked_maps["emission"])
                emit_img.colorspace_settings.name = 'sRGB'
                emit_node = nodes.new('ShaderNodeTexImage')
                emit_node.location = (-300, -1000)
                emit_node.image = emit_img
                links.new(emit_node.outputs['Color'], bsdf.inputs['Emission Color'])
                bsdf.inputs['Emission Strength'].default_value = 1.0

            # Assign single baked material to the target object
            target_obj.data.materials.clear()
            target_obj.data.materials.append(baked_mat)

            # Export to GLB
            out_glb_dir = os.path.dirname(os.path.abspath(out_glb_path))
            os.makedirs(out_glb_dir, exist_ok=True)
            bpy.ops.export_scene.gltf(
                filepath=os.path.abspath(out_glb_path),
                export_format='GLB',
                use_selection=False,
                export_apply=True,
                export_materials='EXPORT',
                export_image_format='AUTO',
            )
            glb_size = os.path.getsize(out_glb_path)
            print(f"[EXPORT] Successfully exported baked GLB -> {out_glb_path} ({glb_size:,} bytes)")
            return out_glb_path
        except Exception as e:
            print(f"[ERROR] Failed to export baked GLB: {e}", file=sys.stderr)
            return None

    def process_model(
        self,
        input_path: str,
        output_dir: Optional[str] = None,
        channels: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Runs the entire baking pipeline for a single 3D model."""
        start_time = time.time()
        input_path = os.path.abspath(input_path)
        base_name = os.path.splitext(os.path.basename(input_path))[0]
        
        if not output_dir:
            output_dir = os.path.join(os.path.dirname(input_path), "textures", base_name)
        output_dir = os.path.abspath(output_dir)
        os.makedirs(output_dir, exist_ok=True)

        bake_channels = channels or self.channels
        print(f"\n{'='*70}\n[PIPELINE] Processing: {base_name}\n[INPUT] {input_path}\n[OUTPUT DIR] {output_dir}\n[RESOLUTION] {self.resolution}x{self.resolution}\n{'='*70}")

        # Reset Blender scene
        bpy.ops.wm.read_factory_settings(use_empty=True)

        # Import 3D file
        ext = os.path.splitext(input_path)[1].lower()
        if ext in ['.glb', '.gltf']:
            bpy.ops.import_scene.gltf(filepath=input_path)
        elif ext == '.blend':
            bpy.ops.wm.open_mainfile(filepath=input_path)
        else:
            raise ValueError(f"Unsupported model extension: {ext}")

        # Setup Cycles
        self.setup_cycles(bpy.context.scene)

        # Find mesh objects
        mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
        if not mesh_objs:
            raise RuntimeError(f"No mesh objects found in {input_path}")

        target_obj = self.prepare_mesh(mesh_objs)

        # Bake maps
        baked_maps: Dict[str, str] = {}
        for ch in bake_channels:
            out_file = os.path.join(output_dir, f"{base_name}_{ch}.png")
            res_path = self.bake_channel(target_obj, ch, out_file)
            if res_path:
                baked_maps[ch] = res_path

        # Pack ORM if requested and channels exist
        if self.pack_orm and "roughness" in baked_maps and "metallic" in baked_maps:
            orm_path = os.path.join(output_dir, f"{base_name}_orm.png")
            ao_p = baked_maps.get("ao")
            orm_res = self.pack_orm_texture(ao_p, baked_maps["roughness"], baked_maps["metallic"], orm_path)
            if orm_res:
                baked_maps["orm"] = orm_res

        # Export self-contained GLB if requested
        out_glb = None
        if self.export_glb:
            baked_glb_path = os.path.join(os.path.dirname(input_path), f"{base_name}_baked.glb")
            out_glb = self.export_baked_glb(target_obj, baked_maps, base_name, baked_glb_path)

        duration = time.time() - start_time
        return {
            "model_name": base_name,
            "input_file": input_path,
            "output_dir": output_dir,
            "baked_maps": baked_maps,
            "baked_glb": out_glb,
            "duration_seconds": round(duration, 2),
            "resolution": self.resolution,
        }


# ============================================================================
# CLI Argument Parser & Entry Point
# ============================================================================

def parse_cli_args(args_list: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Cycles PBR Texture Baking Pipeline for Blender 5.0+"
    )
    parser.add_argument("--input", "-i", type=str, help="Path to input .glb model")
    parser.add_argument("--input-dir", type=str, help="Directory containing .glb models for batch baking")
    parser.add_argument("--output-dir", "-o", type=str, help="Directory to save baked textures")
    parser.add_argument("--resolution", "-r", type=int, default=1024, help="Texture resolution (e.g. 512, 1024, 2048)")
    parser.add_argument("--samples", "-s", type=int, default=16, help="Cycles bake sample count")
    parser.add_argument("--margin", "-m", type=int, default=16, help="UV dilation margin in pixels")
    parser.add_argument("--unwrap", choices=["smart", "keep", "force_smart"], default="smart", help="UV unwrapping policy")
    parser.add_argument("--device", choices=["CPU", "GPU"], default="CPU", help="Cycles render device")
    parser.add_argument("--no-glb", action="store_true", help="Skip exporting baked GLB model")
    parser.add_argument("--no-orm", action="store_true", help="Skip packing ORM texture map")
    parser.add_argument("--channels", type=str, default="albedo,normal,roughness,metallic,emission,ao", help="Comma-separated channels to bake")
    return parser.parse_args(args_list)


def main():
    raw_args = sys.argv
    # If run through Blender: blender --background --python script.py -- [args]
    if "--" in raw_args:
        cli_args = raw_args[raw_args.index("--") + 1:]
    else:
        cli_args = raw_args[1:]

    # If running outside Blender, launch Blender
    if not IN_BLENDER:
        sys.exit(run_via_blender_cli(cli_args))

    parsed = parse_cli_args(cli_args)
    channels_to_bake = [c.strip().lower() for c in parsed.channels.split(",") if c.strip()]

    baker = CyclesPBRBaker(
        resolution=parsed.resolution,
        samples=parsed.samples,
        margin=parsed.margin,
        unwrap_mode=parsed.unwrap,
        device=parsed.device,
        export_glb=(not parsed.no_glb),
        pack_orm=(not parsed.no_orm),
    )

    models_to_process = []
    if parsed.input:
        models_to_process.append(parsed.input)
    elif parsed.input_dir:
        for root, _, files in os.walk(parsed.input_dir):
            for f in files:
                if f.lower().endswith(".glb") and not f.lower().endswith("_baked.glb") and not f.lower().endswith("_lod1.glb") and not f.lower().endswith("_lod2.glb") and not f.lower().endswith("_impostor.glb"):
                    models_to_process.append(os.path.join(root, f))
    else:
        # Default fallback sample test
        default_model = os.path.abspath("assets/models/weapons/DamagedHelmet.glb")
        if os.path.isfile(default_model):
            models_to_process.append(default_model)

    print(f"\n[START] Starting Cycles PBR Baking Batch: {len(models_to_process)} model(s) queued.")
    results = []
    for model_path in models_to_process:
        try:
            res = baker.process_model(
                input_path=model_path,
                output_dir=parsed.output_dir,
                channels=channels_to_bake,
            )
            results.append(res)
        except Exception as e:
            print(f"[ERROR] Failed processing model {model_path}: {e}", file=sys.stderr)

    print(f"\n{'='*70}\n[COMPLETE] Baked {len(results)} of {len(models_to_process)} models successfully.\n{'='*70}")
    for r in results:
        print(f"Model: {r['model_name']} ({r['duration_seconds']}s)")
        for ch, p in r['baked_maps'].items():
            print(f"  - {ch.upper()}: {p} ({os.path.getsize(p):,} B)")
        if r['baked_glb']:
            print(f"  - BAKED GLB: {r['baked_glb']} ({os.path.getsize(r['baked_glb']):,} B)")


if __name__ == "__main__":
    main()
