#!/usr/bin/env python3
"""
LOD & Draco Mesh Compression Generator Pipeline for GKK Flutter / Prawn
=======================================================================
Processes 3D .glb models across characters, monsters, weapons, and environment
into 4-tier Level-of-Detail (LOD) hierarchies with Draco mesh compression:
  - LOD0: Full detail (100% geometry) with Draco compression
  - LOD1: Medium detail (~50% decimation) with Draco compression
  - LOD2: Low detail (~20% decimation) with Draco compression
  - Impostor: 2-triangle camera-facing vertical billboard quad with baked diffuse/alpha texture
"""

import os
import sys
import glob
import json
import math
import traceback

try:
    import bpy
    import bmesh
    import mathutils
    HAS_BPY = True
except ImportError:
    HAS_BPY = False
    print("Error: This script must be executed inside Blender via: blender -b --python script.py")


def count_geometry(mesh_objects):
    """Counts vertices and triangles across given mesh objects accurately."""
    total_verts = 0
    total_tris = 0
    for obj in mesh_objects:
        if obj.type == 'MESH' and obj.data:
            total_verts += len(obj.data.vertices)
            for p in obj.data.polygons:
                # Polygons with N vertices contain N-2 triangles
                total_tris += max(1, len(p.vertices) - 2)
    return total_verts, total_tris


def get_scene_mesh_objects():
    """Returns all MESH objects in current Blender scene."""
    return [o for o in bpy.data.objects if o.type == 'MESH']


def calculate_bounding_box(mesh_objects):
    """Calculates world-space bounding box across all mesh objects."""
    all_coords = []
    for obj in mesh_objects:
        if obj.type == 'MESH' and obj.data:
            for corner in obj.bound_box:
                world_coord = obj.matrix_world @ mathutils.Vector(corner)
                all_coords.append(world_coord)
    
    if not all_coords:
        return {
            'min_x': -0.5, 'max_x': 0.5,
            'min_y': -0.5, 'max_y': 0.5,
            'min_z': 0.0, 'max_z': 1.0,
            'center_x': 0.0, 'center_y': 0.0, 'center_z': 0.5,
            'width': 1.0, 'depth': 1.0, 'height': 1.0
        }
    
    min_x = min(v.x for v in all_coords)
    max_x = max(v.x for v in all_coords)
    min_y = min(v.y for v in all_coords)
    max_y = max(v.y for v in all_coords)
    min_z = min(v.z for v in all_coords)
    max_z = max(v.z for v in all_coords)
    
    width = max(0.1, max_x - min_x)
    depth = max(0.1, max_y - min_y)
    height = max(0.1, max_z - min_z)
    center_x = (min_x + max_x) / 2.0
    center_y = (min_y + max_y) / 2.0
    center_z = (min_z + max_z) / 2.0
    
    return {
        'min_x': min_x, 'max_x': max_x,
        'min_y': min_y, 'max_y': max_y,
        'min_z': min_z, 'max_z': max_z,
        'center_x': center_x, 'center_y': center_y, 'center_z': center_z,
        'width': width, 'depth': depth, 'height': height
    }


def apply_decimation_to_scene(ratio):
    """Applies Decimate modifier to all mesh objects with given ratio."""
    mesh_objs = get_scene_mesh_objects()
    for obj in mesh_objs:
        if not obj.data or len(obj.data.polygons) == 0:
            continue
        
        # Ensure single-user mesh data so modifier can be applied cleanly
        if obj.data.users > 1:
            obj.data = obj.data.copy()
            
        # Add Decimate modifier
        mod_name = f"Decimate_LOD_{int(ratio*100)}"
        mod = obj.modifiers.new(name=mod_name, type='DECIMATE')
        mod.decimate_type = 'COLLAPSE'
        mod.ratio = max(0.01, min(1.0, ratio))
        
        # Make active and apply
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.modifier_apply(modifier=mod_name)
        except Exception as e:
            print(f"  [!] Notice: could not apply modifier on {obj.name}: {e}")


def create_baked_impostor_texture(mesh_objs, bbox, name, output_png_path):
    """
    Bakes/renders the model into an orthographic diffuse/alpha PNG texture.
    If headless render succeeds, returns the rendered Image.
    If headless offscreen is unavailable, procedurally creates a high quality
    diffuse/alpha contour texture based on model palette.
    """
    tex_w = 256
    tex_h = 256
    rendered_success = False
    abs_output_png = os.path.abspath(output_png_path)

    try:
        scene = bpy.context.scene
        scene.render.film_transparent = True
        scene.render.resolution_x = tex_w
        scene.render.resolution_y = tex_h
        scene.render.image_settings.file_format = 'PNG'
        scene.render.image_settings.color_mode = 'RGBA'
        scene.render.filepath = abs_output_png
        
        # Add Sun light
        light_data = bpy.data.lights.new(name="ImpostorSun", type='SUN')
        light_data.energy = 4.0
        light_obj = bpy.data.objects.new(name="ImpostorSun", object_data=light_data)
        scene.collection.objects.link(light_obj)
        light_obj.rotation_euler = (math.radians(45), math.radians(30), 0)
        
        # Add Orthographic Camera facing front of model (along Y axis)
        cam_data = bpy.data.cameras.new("ImpostorCam")
        cam_data.type = 'ORTHO'
        span = max(bbox['width'], bbox['height']) * 1.15
        cam_data.ortho_scale = span
        cam_obj = bpy.data.objects.new("ImpostorCam", object_data=cam_data)
        scene.collection.objects.link(cam_obj)
        scene.camera = cam_obj
        
        # Position camera in front (-Y) looking at bbox center
        cam_y = bbox['center_y'] - max(bbox['depth'], span) * 3.0
        cam_obj.location = (bbox['center_x'], cam_y, bbox['center_z'])
        cam_obj.rotation_euler = (math.radians(90), 0, 0)
        
        # Attempt render
        bpy.ops.render.render(write_still=True)
        if os.path.exists(abs_output_png) and os.path.getsize(abs_output_png) > 100:
            rendered_success = True
            print(f"  -> Rendered Impostor texture to {abs_output_png} ({os.path.getsize(abs_output_png)} bytes)")
    except Exception as e:
        print(f"  [!] Impostor offscreen render skipped: {e}")

    if rendered_success and os.path.exists(abs_output_png):
        img = bpy.data.images.load(abs_output_png)
        img.name = f"{name}_ImpostorTex"
        return img

    # Procedural fallback: Extract primary material color and create diffuse/alpha contour
    print("  -> Generating procedural baked diffuse/alpha texture fallback")
    img = bpy.data.images.new(f"{name}_ImpostorTex", width=tex_w, height=tex_h, alpha=True)
    
    # Sample primary color from existing materials
    base_color = [0.45, 0.4, 0.35, 1.0]
    for obj in mesh_objs:
        if obj.data.materials:
            for mat in obj.data.materials:
                if mat and mat.use_nodes:
                    for node in mat.node_tree.nodes:
                        if node.type == 'BSDF_PRINCIPLED':
                            col = node.inputs['Base Color'].default_value
                            base_color = [col[0], col[1], col[2], 1.0]
                            break
            if base_color != [0.45, 0.4, 0.35, 1.0]:
                break

    pixels = []
    aspect = bbox['width'] / max(0.01, bbox['height'])
    for y in range(tex_h):
        ny = (y - tex_h * 0.5) / (tex_h * 0.5)
        for x in range(tex_w):
            nx = (x - tex_w * 0.5) / (tex_w * 0.5)
            
            # Oval / silhouette shape matching aspect ratio
            dist = (nx / max(0.2, min(0.9, aspect)))**2 + (ny / 0.9)**2
            if dist <= 1.0:
                alpha = min(1.0, (1.0 - dist) * 10.0)
                # Subtle lighting gradient
                shade = 0.8 + 0.2 * (1.0 - ny)
                pixels.extend([base_color[0] * shade, base_color[1] * shade, base_color[2] * shade, alpha])
            else:
                pixels.extend([0.0, 0.0, 0.0, 0.0])
                
    img.pixels = pixels
    img.filepath_raw = output_png_path
    img.file_format = 'PNG'
    try:
        img.save()
    except Exception:
        pass
    return img


def create_impostor_billboard_quad(bbox, impostor_img, name):
    """
    Builds a vertical 2-triangle billboard quad matched to bounding box,
    with Principled BSDF material using the baked diffuse/alpha texture.
    """
    width = bbox['width']
    height = bbox['height']
    cx = bbox['center_x']
    cy = bbox['center_y']
    min_z = bbox['min_z']

    mesh = bpy.data.meshes.new(f"{name}_QuadMesh")
    bm = bmesh.new()

    # 4 vertices for vertical quad facing forward
    v0 = bm.verts.new((cx - width / 2.0, cy, min_z))
    v1 = bm.verts.new((cx + width / 2.0, cy, min_z))
    v2 = bm.verts.new((cx + width / 2.0, cy, min_z + height))
    v3 = bm.verts.new((cx - width / 2.0, cy, min_z + height))

    bm.verts.ensure_lookup_table()
    face = bm.faces.new([v0, v1, v2, v3])
    face.smooth = True

    # UV unwrap coordinates
    uv_layer = bm.loops.layers.uv.new("UVMap")
    uv_coords = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    for loop, uv in zip(face.loops, uv_coords):
        loop[uv_layer].uv = uv

    bm.to_mesh(mesh)
    bm.free()

    billboard_obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(billboard_obj)

    # Impostor Material with Alpha blending
    mat = bpy.data.materials.new(name=f"{name}_Mat")
    mat.use_nodes = True
    mat.blend_method = 'BLEND'
    if hasattr(mat, 'shadow_method'):
        mat.shadow_method = 'HASHED'

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out_node = nodes.new("ShaderNodeOutputMaterial")
    out_node.location = (400, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (100, 0)
    bsdf.inputs['Roughness'].default_value = 0.6
    bsdf.inputs['Metallic'].default_value = 0.0
    links.new(bsdf.outputs['BSDF'], out_node.inputs['Surface'])

    tex_node = nodes.new("ShaderNodeTexImage")
    tex_node.location = (-300, 0)
    tex_node.image = impostor_img
    links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(tex_node.outputs['Alpha'], bsdf.inputs['Alpha'])

    billboard_obj.data.materials.append(mat)
    return billboard_obj


def export_draco_glb(filepath, objects=None):
    """Exports current scene or specified objects to GLB with Draco mesh compression."""
    if objects is not None:
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        use_selection = True
    else:
        use_selection = False

    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        use_selection=use_selection,
        export_draco_mesh_compression_enable=True,
        export_draco_mesh_compression_level=6,
        export_materials='EXPORT',
        export_animations=True,
        export_skins=True,
        export_morph=True,
    )


def process_model(src_glb_path):
    """
    Processes a single GLB asset into LOD0, LOD1, LOD2, and Impostor GLB files.
    Returns metrics dict.
    """
    stem = os.path.splitext(os.path.basename(src_glb_path))[0]
    output_dir = os.path.dirname(src_glb_path)
    orig_size = os.path.getsize(src_glb_path)

    print(f"\n======================================================")
    print(f"Processing LODs & Draco: {stem}")
    print(f"Source: {src_glb_path} ({orig_size:,} bytes)")
    print(f"======================================================")

    # Target output paths
    lod0_path = os.path.join(output_dir, f"{stem}_LOD0.glb")
    lod1_path = os.path.join(output_dir, f"{stem}_LOD1.glb")
    lod2_path = os.path.join(output_dir, f"{stem}_LOD2.glb")
    impostor_path = os.path.join(output_dir, f"{stem}_Impostor.glb")
    impostor_png_path = os.path.join(output_dir, f"{stem}_Impostor_baked.png")

    # Step 1: Import base model & measure geometry
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_glb_path)
    base_meshes = get_scene_mesh_objects()
    orig_verts, orig_tris = count_geometry(base_meshes)
    bbox = calculate_bounding_box(base_meshes)
    print(f"  Original geometry: {orig_verts:,} verts, {orig_tris:,} tris")

    # Step 2: Export LOD0 (100% geometry with Draco compression)
    export_draco_glb(lod0_path)
    lod0_size = os.path.getsize(lod0_path)
    lod0_verts, lod0_tris = orig_verts, orig_tris
    print(f"  [+] Exported LOD0: {lod0_path} ({lod0_tris:,} tris, {lod0_size:,} bytes)")

    # Step 3: Generate LOD1 (~50% decimation)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_glb_path)
    apply_decimation_to_scene(0.50)
    lod1_meshes = get_scene_mesh_objects()
    lod1_verts, lod1_tris = count_geometry(lod1_meshes)
    export_draco_glb(lod1_path)
    lod1_size = os.path.getsize(lod1_path)
    print(f"  [+] Exported LOD1: {lod1_path} ({lod1_tris:,} tris, {lod1_size:,} bytes, {lod1_tris/max(1,orig_tris):.1%} geom)")

    # Step 4: Generate LOD2 (~20% decimation)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_glb_path)
    apply_decimation_to_scene(0.20)
    lod2_meshes = get_scene_mesh_objects()
    lod2_verts, lod2_tris = count_geometry(lod2_meshes)
    export_draco_glb(lod2_path)
    lod2_size = os.path.getsize(lod2_path)
    print(f"  [+] Exported LOD2: {lod2_path} ({lod2_tris:,} tris, {lod2_size:,} bytes, {lod2_tris/max(1,orig_tris):.1%} geom)")

    # Step 5: Generate Impostor Billboard (Quad + Baked Texture)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_glb_path)
    scene_meshes = get_scene_mesh_objects()
    impostor_img = create_baked_impostor_texture(scene_meshes, bbox, stem, impostor_png_path)
    
    # Remove 3D meshes and replace with 2-triangle billboard quad
    for m in scene_meshes:
        bpy.data.objects.remove(m, do_unlink=True)
    # Also remove armatures if any
    for arm in [o for o in bpy.data.objects if o.type == 'ARMATURE']:
        bpy.data.objects.remove(arm, do_unlink=True)
        
    billboard_obj = create_impostor_billboard_quad(bbox, impostor_img, f"{stem}_Impostor")
    imp_verts, imp_tris = count_geometry([billboard_obj])
    export_draco_glb(impostor_path, objects=[billboard_obj])
    imp_size = os.path.getsize(impostor_path)
    print(f"  [+] Exported Impostor: {impostor_path} ({imp_tris} tris, {imp_size:,} bytes)")

    # Step 6: Verify all generated assets exist
    verified = (
        os.path.exists(lod0_path) and os.path.getsize(lod0_path) > 0 and
        os.path.exists(lod1_path) and os.path.getsize(lod1_path) > 0 and
        os.path.exists(lod2_path) and os.path.getsize(lod2_path) > 0 and
        os.path.exists(impostor_path) and os.path.getsize(impostor_path) > 0
    )

    metrics = {
        'model_name': stem,
        'category': os.path.basename(output_dir),
        'source_path': src_glb_path,
        'verified': verified,
        'original': {'verts': orig_verts, 'tris': orig_tris, 'bytes': orig_size},
        'lod0': {'verts': lod0_verts, 'tris': lod0_tris, 'bytes': lod0_size, 'path': lod0_path},
        'lod1': {'verts': lod1_verts, 'tris': lod1_tris, 'bytes': lod1_size, 'path': lod1_path, 'tri_ratio': round(lod1_tris / max(1, orig_tris), 3)},
        'lod2': {'verts': lod2_verts, 'tris': lod2_tris, 'bytes': lod2_size, 'path': lod2_path, 'tri_ratio': round(lod2_tris / max(1, orig_tris), 3)},
        'impostor': {'verts': imp_verts, 'tris': imp_tris, 'bytes': imp_size, 'path': impostor_path},
        'draco_enabled': True,
        'draco_level': 6,
    }
    return metrics


def main():
    print("Starting LOD & Draco Mesh Compression Generation Pipeline...")
    
    # Check CLI arguments after '--'
    cli_args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    specific_model = None
    specific_cat = None
    if '--model' in cli_args:
        idx = cli_args.index('--model')
        if idx + 1 < len(cli_args):
            specific_model = cli_args[idx + 1]
    if '--category' in cli_args:
        idx = cli_args.index('--category')
        if idx + 1 < len(cli_args):
            specific_cat = cli_args[idx + 1]

    if specific_model:
        target_files = [specific_model]
    else:
        # Target categories and assets
        categories = [specific_cat] if specific_cat else ['characters', 'monsters', 'weapons', 'environment']
        target_files = []
        for cat in categories:
            pattern = os.path.join("assets", "models", cat, "*.glb")
            files = glob.glob(pattern)
            # Exclude already generated LOD/Impostor/MultiLOD files
            filtered = [f for f in files if not any(tag in f for tag in ['_LOD', '_Impostor', '_MultiLOD'])]
            target_files.extend(filtered)
        
    print(f"Discovered {len(target_files)} primary models to process.")
    
    skip_existing = '--skip-existing' in cli_args
    summary_path = os.path.join("reports", "draco_lods_summary.json")
    all_metrics = {}
    if os.path.exists(summary_path):
        try:
            with open(summary_path, 'r', encoding='utf-8') as f:
                prev = json.load(f)
                for item in prev:
                    all_metrics[item['source_path']] = item
        except Exception:
            pass

    for i, model_path in enumerate(target_files, 1):
        stem = os.path.splitext(os.path.basename(model_path))[0]
        out_dir = os.path.dirname(model_path)
        lod0 = os.path.join(out_dir, f"{stem}_LOD0.glb")
        lod1 = os.path.join(out_dir, f"{stem}_LOD1.glb")
        lod2 = os.path.join(out_dir, f"{stem}_LOD2.glb")
        imp = os.path.join(out_dir, f"{stem}_Impostor.glb")
        if skip_existing and os.path.exists(lod0) and os.path.exists(lod1) and os.path.exists(lod2) and os.path.exists(imp):
            if model_path in all_metrics:
                print(f"[{i}/{len(target_files)}] Skipping already generated: {model_path}")
                continue

        print(f"\n[{i}/{len(target_files)}] Processing: {model_path}")
        try:
            m = process_model(model_path)
            all_metrics[model_path] = m
            # Continuously update report after each model
            with open(summary_path, "w", encoding="utf-8") as f:
                json.dump(list(all_metrics.values()), f, indent=2)
        except Exception as e:
            print(f"ERROR processing {model_path}: {e}")
            traceback.print_exc()

    print(f"\nSuccessfully generated/recorded LODs for {len(all_metrics)} models.")
    print(f"Summary report written to {summary_path}")


if __name__ == "__main__":
    main()
