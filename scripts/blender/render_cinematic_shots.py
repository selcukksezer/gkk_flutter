#!/usr/bin/env python3
"""
Aion 2 Dark Fantasy 2027 Cinematic Beauty Shot Renderer
======================================================
Generates high-resolution mobile portrait (1080x2400) cinematic renders
of the Main Hub and Dungeon scenes using Blender's Cycles engine with
hardware-accelerated OptiX ray tracing, volumetric fog, and dynamic PBR lighting.

Outputs:
- reports/screenshots/blender_renders/hub_beauty_shot.png
- reports/screenshots/blender_renders/hub_wings_sword_closeup.png
- reports/screenshots/blender_renders/dungeon_beauty_shot.png
- reports/screenshots/blender_renders/dungeon_altar_brazier_closeup.png

Author: screenshot_1_blender_renderer
"""

import os
import sys
import math
import time
from typing import Optional, List, Tuple, Dict, Any

try:
    import bpy
    import mathutils
    from mathutils import Vector, Euler, Matrix
    HAS_BPY = True
except ImportError:
    HAS_BPY = False


class CinematicRenderer:
    """Production Cycles renderer for dark fantasy mobile beauty shots."""

    def __init__(self, workspace_root: str):
        self.workspace_root = os.path.abspath(workspace_root)
        self.output_dir = os.path.join(self.workspace_root, "reports", "screenshots", "blender_renders")
        os.makedirs(self.output_dir, exist_ok=True)

        self.assets_dir = os.path.join(self.workspace_root, "assets", "models")
        self.asset_paths = {
            "sword": os.path.join(self.assets_dir, "aion2", "aion2_dark_fantasy_sword.glb"),
            "wings": os.path.join(self.assets_dir, "aion2", "aion2_ethereal_wings.glb"),
            "pillar": os.path.join(self.assets_dir, "aion2", "aion2_gothic_dungeon_pillar.glb"),
            "brazier": os.path.join(self.assets_dir, "props", "Brazier_IronEmbers.glb"),
            "flagstones": os.path.join(self.assets_dir, "props", "Flagstones_CrackedTile.glb"),
            "gargoyle": os.path.join(self.assets_dir, "props", "Gargoyle_DarkStone.glb"),
            "arch": os.path.join(self.assets_dir, "props", "GothicArch_Lancet.glb"),
            "portcullis": os.path.join(self.assets_dir, "props", "Portcullis_HeavyIron.glb"),
            "altar": os.path.join(self.assets_dir, "props", "StoneAltar_Ritual.glb"),
        }

    def clean_scene(self) -> bpy.types.Scene:
        """Cleans objects in the scene safely without closing Blender or wiping context."""
        scene = bpy.context.scene
        for obj in list(scene.objects):
            bpy.data.objects.remove(obj, do_unlink=True)

        # Remove unreferenced datablocks
        for block in [bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras]:
            for item in list(block):
                if item.users == 0:
                    block.remove(item)

        return scene

    def configure_cycles(
        self,
        scene: bpy.types.Scene,
        width: int = 1080,
        height: int = 2400,
        samples: int = 256,
        use_optix: bool = True
    ):
        """Configures Cycles with hardware OptiX acceleration and AgX tonemapping."""
        scene.render.engine = 'CYCLES'
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = 'PNG'
        scene.render.image_settings.color_mode = 'RGBA'
        scene.render.image_settings.color_depth = '8'
        scene.render.image_settings.compression = 15

        # Cycles Performance Settings
        scene.cycles.samples = samples
        scene.cycles.preview_samples = 32
        scene.cycles.use_adaptive_sampling = True
        scene.cycles.adaptive_threshold = 0.015
        scene.cycles.max_bounces = 8
        scene.cycles.diffuse_bounces = 4
        scene.cycles.glossy_bounces = 4
        scene.cycles.transmission_bounces = 6
        scene.cycles.volume_bounces = 3
        scene.cycles.transparent_max_bounces = 8

        # GPU Compute & OptiX Denoising
        if use_optix:
            try:
                cycles_prefs = bpy.context.preferences.addons['cycles'].preferences
                cycles_prefs.compute_device_type = 'OPTIX'
                cycles_prefs.get_devices()
                has_gpu = False
                for device in cycles_prefs.devices:
                    if device.type == 'OPTIX':
                        device.use = True
                        has_gpu = True
                        print(f"  [Renderer] Enabled OptiX device: {device.name}")
                    else:
                        device.use = False

                if has_gpu:
                    scene.cycles.device = 'GPU'
                else:
                    scene.cycles.device = 'CPU'

                scene.cycles.use_denoising = True
                scene.cycles.denoiser = 'OPTIX'
            except Exception as e:
                print(f"  [Renderer] OptiX config warning: {e}, falling back to OPENIMAGEDENOISE")
                scene.cycles.use_denoising = True
                scene.cycles.denoiser = 'OPENIMAGEDENOISE'

        # Color Management / Tonemapping
        scene.view_settings.view_transform = 'AgX'
        try:
            scene.view_settings.look = 'AgX - High Contrast'
        except Exception:
            try:
                scene.view_settings.look = 'AgX - Punchy'
            except Exception:
                pass
        scene.view_settings.exposure = 0.15
        scene.view_settings.gamma = 1.0

    def setup_world_volumetrics(
        self,
        scene: bpy.types.Scene,
        bg_color: Tuple[float, float, float] = (0.004, 0.007, 0.015),
        bg_strength: float = 0.35,
        vol_color: Tuple[float, float, float] = (0.68, 0.80, 0.98),
        vol_density: float = 0.012,
        vol_anisotropy: float = 0.72
    ):
        """Constructs an atmospheric World Shader with volumetric mist for god-rays."""
        world = bpy.data.worlds.new("Aion2_CinematicWorld")
        scene.world = world
        world.use_nodes = True
        nodes = world.node_tree.nodes
        links = world.node_tree.links
        nodes.clear()

        out_node = nodes.new(type="ShaderNodeOutputWorld")
        out_node.location = (400, 0)

        # Ambient celestial background
        bg = nodes.new(type="ShaderNodeBackground")
        bg.location = (100, 120)
        bg.inputs["Color"].default_value = (*bg_color, 1.0)
        bg.inputs["Strength"].default_value = bg_strength
        links.new(bg.outputs["Background"], out_node.inputs["Surface"])

        # Volumetric mist scatter
        vol = nodes.new(type="ShaderNodeVolumeScatter")
        vol.location = (100, -100)
        vol.inputs["Color"].default_value = (*vol_color, 1.0)
        vol.inputs["Density"].default_value = vol_density
        vol.inputs["Anisotropy"].default_value = vol_anisotropy
        links.new(vol.outputs["Volume"], out_node.inputs["Volume"])

    def create_light(
        self,
        name: str,
        light_type: str,
        location: Tuple[float, float, float],
        energy: float,
        color: Tuple[float, float, float],
        shadow_soft_size: float = 0.25,
        rotation_euler_deg: Tuple[float, float, float] = (0, 0, 0),
        spot_size_deg: float = 65.0,
        spot_blend: float = 0.5
    ) -> bpy.types.Object:
        """Creates a light source safely using data blocks (independent of operators)."""
        light_data = bpy.data.lights.new(name=f"{name}_Data", type=light_type)
        light_data.energy = energy
        light_data.color = color
        if hasattr(light_data, "shadow_soft_size"):
            light_data.shadow_soft_size = shadow_soft_size
        if light_type == 'SPOT':
            light_data.spot_size = math.radians(spot_size_deg)
            light_data.spot_blend = spot_blend

        light_obj = bpy.data.objects.new(name=name, object_data=light_data)
        light_obj.location = Vector(location)
        light_obj.rotation_euler = Euler((
            math.radians(rotation_euler_deg[0]),
            math.radians(rotation_euler_deg[1]),
            math.radians(rotation_euler_deg[2])
        ))
        bpy.context.collection.objects.link(light_obj)
        return light_obj

    def create_camera(
        self,
        name: str,
        location: Tuple[float, float, float],
        rotation_euler_deg: Tuple[float, float, float],
        lens: float = 38.0,
        dof_distance: Optional[float] = None,
        fstop: float = 2.8
    ) -> bpy.types.Object:
        """Creates a camera safely using data blocks."""
        cam_data = bpy.data.cameras.new(name=f"{name}_Data")
        cam_data.lens = lens
        if dof_distance is not None:
            cam_data.dof.use_dof = True
            cam_data.dof.focus_distance = dof_distance
            cam_data.dof.aperture_fstop = fstop

        cam_obj = bpy.data.objects.new(name=name, object_data=cam_data)
        cam_obj.location = Vector(location)
        cam_obj.rotation_euler = Euler((
            math.radians(rotation_euler_deg[0]),
            math.radians(rotation_euler_deg[1]),
            math.radians(rotation_euler_deg[2])
        ))
        bpy.context.collection.objects.link(cam_obj)
        bpy.context.scene.camera = cam_obj
        return cam_obj

    def import_lod0_mesh(
        self,
        asset_key: str,
        name_prefix: str,
        location: Tuple[float, float, float] = (0, 0, 0),
        rotation_euler_deg: Tuple[float, float, float] = (0, 0, 0),
        scale: Tuple[float, float, float] = (1, 1, 1)
    ) -> Optional[bpy.types.Object]:
        """Imports a glTF asset, isolates the LOD0 mesh, and hides or removes lower LODs."""
        filepath = self.asset_paths.get(asset_key)
        if not filepath or not os.path.exists(filepath):
            print(f"  [Error] Asset not found: {asset_key} ({filepath})")
            return None

        # Track existing objects before import
        before_names = set(bpy.data.objects.keys())

        bpy.ops.import_scene.gltf(filepath=filepath)

        new_objs = [obj for name, obj in bpy.data.objects.items() if name not in before_names]
        if not new_objs:
            return None

        # Find LOD0 or primary mesh
        lod0_obj = None
        for obj in new_objs:
            if "LOD0" in obj.name and obj.type == "MESH":
                lod0_obj = obj
                break

        if not lod0_obj:
            meshes = [o for o in new_objs if o.type == "MESH"]
            if meshes:
                lod0_obj = max(meshes, key=lambda m: len(m.data.polygons))

        # Hide or delete other LODs (LOD1, LOD2, Impostor, Empties)
        for obj in new_objs:
            if obj != lod0_obj:
                if any(tag in obj.name for tag in ["LOD1", "LOD2", "Impostor"]):
                    obj.hide_render = True
                    obj.hide_viewport = True
                    bpy.data.objects.remove(obj, do_unlink=True)

        if not lod0_obj:
            return None

        lod0_obj.name = f"{name_prefix}_{lod0_obj.name}"
        lod0_obj.location = Vector(location)
        lod0_obj.rotation_euler = Euler((
            math.radians(rotation_euler_deg[0]),
            math.radians(rotation_euler_deg[1]),
            math.radians(rotation_euler_deg[2])
        ))
        lod0_obj.scale = Vector(scale)

        # Shade Smooth
        for poly in lod0_obj.data.polygons:
            poly.use_smooth = True

        return lod0_obj

    def duplicate_mesh(
        self,
        source_obj: bpy.types.Object,
        new_name: str,
        location: Tuple[float, float, float],
        rotation_euler_deg: Tuple[float, float, float] = (0, 0, 0),
        scale: Tuple[float, float, float] = (1, 1, 1)
    ) -> bpy.types.Object:
        """Creates a linked duplicate of an existing mesh object."""
        new_obj = source_obj.copy()
        new_obj.name = new_name
        new_obj.location = Vector(location)
        new_obj.rotation_euler = Euler((
            math.radians(rotation_euler_deg[0]),
            math.radians(rotation_euler_deg[1]),
            math.radians(rotation_euler_deg[2])
        ))
        new_obj.scale = Vector(scale)
        bpy.context.collection.objects.link(new_obj)
        return new_obj

    def enhance_emissive_materials(self, obj: bpy.types.Object, boost_factor: float = 3.0):
        """Boosts emissive nodes on weapon runes and wings for intense bloom."""
        for slot in obj.material_slots:
            mat = slot.material
            if not mat or not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    em_str_sock = node.inputs.get("Emission Strength")
                    if em_str_sock and em_str_sock.default_value > 0.1:
                        em_str_sock.default_value *= boost_factor

    def create_wet_floor(self, size: float = 40.0) -> bpy.types.Object:
        """Creates a dark reflective stone floor with wet puddle clearcoat."""
        mesh = bpy.data.meshes.new("Wet_Floor_Mesh")
        half = size / 2.0
        verts = [(-half, -half, 0.0), (half, -half, 0.0), (half, half, 0.0), (-half, half, 0.0)]
        faces = [(0, 1, 2, 3)]
        mesh.from_pydata(verts, [], faces)
        mesh.update()

        floor = bpy.data.objects.new("Wet_Dungeon_Sanctuary_Floor", mesh)
        bpy.context.collection.objects.link(floor)

        mat = bpy.data.materials.new("M_WetReflectiveFlagstones")
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        nodes.clear()

        out_node = nodes.new(type="ShaderNodeOutputMaterial")
        out_node.location = (600, 0)

        bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
        bsdf.location = (200, 0)
        # Deep dark basalt flagstone base color
        bsdf.inputs["Base Color"].default_value = (0.045, 0.048, 0.055, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.28
        bsdf.inputs["Metallic"].default_value = 0.08
        # Clearcoat / Coat for wet puddle sheen
        coat_sock = bsdf.inputs.get("Coat Weight") or bsdf.inputs.get("Clearcoat")
        if coat_sock:
            coat_sock.default_value = 0.85
        coat_rough = bsdf.inputs.get("Coat Roughness") or bsdf.inputs.get("Clearcoat Roughness")
        if coat_rough:
            coat_rough.default_value = 0.04

        # Procedural Voronoi crack texture for stone tiles
        tex_coord = nodes.new(type="ShaderNodeTexCoord")
        tex_coord.location = (-600, 0)
        mapping = nodes.new(type="ShaderNodeMapping")
        mapping.location = (-400, 0)
        mapping.inputs["Scale"].default_value = (8.0, 8.0, 8.0)
        links.new(tex_coord.outputs["Generated"], mapping.inputs["Vector"])

        voronoi = nodes.new(type="ShaderNodeTexVoronoi")
        voronoi.location = (-200, 100)
        voronoi.inputs["Scale"].default_value = 6.0
        links.new(mapping.outputs["Vector"], voronoi.inputs["Vector"])

        # Bump node for tile relief
        bump = nodes.new(type="ShaderNodeBump")
        bump.location = (0, -100)
        bump.inputs["Strength"].default_value = 0.35
        bump.inputs["Distance"].default_value = 0.1
        links.new(voronoi.outputs["Distance"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

        links.new(bsdf.outputs["BSDF"], out_node.inputs["Surface"])
        floor.data.materials.append(mat)
        return floor

    # =========================================================================
    # SCENE 1: MAIN HUB CINEMATIC BEAUTY SHOT
    # =========================================================================
    def build_hub_scene(self) -> bpy.types.Scene:
        """Constructs the Aion 2 Main Hub 'Citadel of Eternity' scene."""
        print("[*] Building Scene 1: Main Hub (Citadel of Eternity)...")
        scene = self.clean_scene()
        scene.name = "Aion2_MainHub_Sanctuary"

        # 1. Cycles Configuration (Mobile aspect ratio 1080x2400)
        self.configure_cycles(scene, width=1080, height=2400, samples=256)

        # 2. World Volumetric Fog (Cold celestial moonlight atmosphere)
        self.setup_world_volumetrics(
            scene,
            bg_color=(0.003, 0.006, 0.015),
            bg_strength=0.35,
            vol_color=(0.65, 0.78, 0.98),
            vol_density=0.014,
            vol_anisotropy=0.74
        )

        # 3. Ground Plane
        self.create_wet_floor(size=40.0)

        # 4. Centerpiece: Stone Altar
        self.import_lod0_mesh("altar", "Hub", location=(0.0, 1.2, 0.0), scale=(1.2, 1.2, 1.2))

        # 5. Centerpiece: Aion 2 Dark Fantasy Greatsword embedded in the altar
        sword = self.import_lod0_mesh(
            "sword",
            "Hub",
            location=(0.0, 1.1, 1.15),
            rotation_euler_deg=(180.0, 0.0, 15.0),
            scale=(1.4, 1.4, 1.4)
        )
        if sword:
            self.enhance_emissive_materials(sword, boost_factor=4.0)

        # 6. Centerpiece: Luminous Ethereal Archon Wings hovering behind the altar
        wings = self.import_lod0_mesh(
            "wings",
            "Hub",
            location=(0.0, 2.2, 2.4),
            rotation_euler_deg=(0.0, 0.0, 0.0),
            scale=(1.8, 1.8, 1.8)
        )
        if wings:
            self.enhance_emissive_materials(wings, boost_factor=3.5)

        # 7. Architecture: Gothic Pillars Colonnade flanking the central aisle
        pillar_positions = [
            (-3.2, -3.0, 0.0), (-3.2, 0.5, 0.0), (-3.2, 4.0, 0.0),
            (3.2, -3.0, 0.0), (3.2, 0.5, 0.0), (3.2, 4.0, 0.0)
        ]
        base_pillar = self.import_lod0_mesh("pillar", "Hub_Colonnade", location=pillar_positions[0], scale=(1.1, 1.1, 1.1))
        if base_pillar:
            for i, pos in enumerate(pillar_positions[1:], start=1):
                self.duplicate_mesh(base_pillar, f"Hub_Pillar_{i}", pos, scale=(1.1, 1.1, 1.1))

        # 8. Architecture: Grand Gothic Arch framing the background portal
        self.import_lod0_mesh("arch", "Hub", location=(0.0, 5.8, 0.0), scale=(1.6, 1.6, 1.8))

        # 9. Brooding Stone Gargoyles overlooking the sanctuary
        gargoyle_l = self.import_lod0_mesh(
            "gargoyle",
            "Hub_Left",
            location=(-2.8, -1.0, 2.6),
            rotation_euler_deg=(0.0, 0.0, -35.0),
            scale=(0.9, 0.9, 0.9)
        )
        if gargoyle_l:
            self.duplicate_mesh(
                gargoyle_l,
                "Hub_Gargoyle_Right",
                (2.8, -1.0, 2.6),
                rotation_euler_deg=(0.0, 0.0, 35.0),
                scale=(0.9, 0.9, 0.9)
            )

        # 10. Props: Iron Braziers with dynamic glowing flame
        brazier_l = self.import_lod0_mesh(
            "brazier",
            "Hub_Left",
            location=(-1.8, -1.8, 0.0),
            scale=(1.1, 1.1, 1.1)
        )
        if brazier_l:
            self.duplicate_mesh(
                brazier_l,
                "Hub_Brazier_Right",
                (1.8, -1.8, 0.0),
                scale=(1.1, 1.1, 1.1)
            )

        # 11. Lighting Systems
        # A. Cold Moonlight Key Sun (creating dramatic volumetric god-rays)
        self.create_light(
            name="Key_Moonlight_Sun",
            light_type='SUN',
            location=(12.0, -10.0, 18.0),
            energy=5.5,
            color=(0.58, 0.74, 1.0),
            rotation_euler_deg=(52.0, 22.0, -38.0)
        )

        # B. Warm Torchlight Fill (Left Brazier)
        self.create_light(
            name="Brazier_Flame_Left",
            light_type='POINT',
            location=(-1.8, -1.8, 1.25),
            energy=220.0,
            color=(1.0, 0.48, 0.12),
            shadow_soft_size=0.25
        )

        # C. Warm Torchlight Fill (Right Brazier)
        self.create_light(
            name="Brazier_Flame_Right",
            light_type='POINT',
            location=(1.8, -1.8, 1.25),
            energy=220.0,
            color=(1.0, 0.48, 0.12),
            shadow_soft_size=0.25
        )

        # D. Celestial Arcane Glow (from the wings & sword)
        self.create_light(
            name="Arcane_Relic_Light",
            light_type='POINT',
            location=(0.0, 1.8, 2.5),
            energy=160.0,
            color=(0.2, 0.85, 1.0),
            shadow_soft_size=0.4
        )

        # 12. Cinematic Mobile Portrait Camera
        self.create_camera(
            name="Cinematic_Hub_Camera",
            location=(0.0, -6.6, 1.45),
            rotation_euler_deg=(78.5, 0.0, 0.0),
            lens=38.0,
            dof_distance=7.2,
            fstop=2.8
        )

        return scene

    # =========================================================================
    # SCENE 2: DUNGEON CINEMATIC BEAUTY SHOT
    # =========================================================================
    def build_dungeon_scene(self) -> bpy.types.Scene:
        """Constructs the Aion 2 Dungeon 'Catacombs of the Abyss' scene."""
        print("[*] Building Scene 2: Dungeon (Catacombs of the Abyss)...")
        scene = self.clean_scene()
        scene.name = "Aion2_Dungeon_Catacombs"

        # 1. Cycles Configuration (Mobile aspect ratio 1080x2400)
        self.configure_cycles(scene, width=1080, height=2400, samples=256)

        # 2. World Volumetric Fog (Dense damp subterranean mist)
        self.setup_world_volumetrics(
            scene,
            bg_color=(0.002, 0.003, 0.006),
            bg_strength=0.2,
            vol_color=(0.55, 0.65, 0.80),
            vol_density=0.024,
            vol_anisotropy=0.68
        )

        # 3. Wet Dungeon Stone Floor
        self.create_wet_floor(size=35.0)

        # 4. Vaulted Gothic Dungeon Corridor (Pillars flanking aisle)
        left_pillars = [(-2.6, -4.5, 0.0), (-2.6, -1.0, 0.0), (-2.6, 2.5, 0.0)]
        right_pillars = [(2.6, -4.5, 0.0), (2.6, -1.0, 0.0), (2.6, 2.5, 0.0)]

        base_pillar = self.import_lod0_mesh("pillar", "Dungeon_Left", location=left_pillars[0], scale=(1.15, 1.15, 1.15))
        if base_pillar:
            for i, pos in enumerate(left_pillars[1:], start=1):
                self.duplicate_mesh(base_pillar, f"Dungeon_Pillar_L{i}", pos, scale=(1.15, 1.15, 1.15))
            for i, pos in enumerate(right_pillars, start=0):
                self.duplicate_mesh(base_pillar, f"Dungeon_Pillar_R{i}", pos, scale=(1.15, 1.15, 1.15))

        # 5. Heavy Spiked Iron Portcullis at the deep arch
        self.import_lod0_mesh(
            "portcullis",
            "Dungeon",
            location=(0.0, 5.2, 0.0),
            scale=(1.4, 1.4, 1.4)
        )

        # 6. Gothic Arches along the corridor vault
        base_arch = self.import_lod0_mesh("arch", "Dungeon", location=(0.0, 5.0, 0.0), scale=(1.4, 1.4, 1.5))
        if base_arch:
            self.duplicate_mesh(base_arch, "Dungeon_Arch_Mid", (0.0, 1.5, 0.0), scale=(1.4, 1.4, 1.5))
            self.duplicate_mesh(base_arch, "Dungeon_Arch_Front", (0.0, -2.0, 0.0), scale=(1.4, 1.4, 1.5))

        # 7. Ancient Blood Altar in Midground
        self.import_lod0_mesh(
            "altar",
            "Dungeon",
            location=(0.0, 1.0, 0.0),
            rotation_euler_deg=(0.0, 0.0, 0.0),
            scale=(1.1, 1.1, 1.1)
        )

        # 8. Cursed Blood Gargoyles flanking the altar
        gargoyle = self.import_lod0_mesh(
            "gargoyle",
            "Dungeon_Altar_L",
            location=(-1.6, 1.2, 0.0),
            rotation_euler_deg=(0.0, 0.0, 45.0),
            scale=(0.75, 0.75, 0.75)
        )
        if gargoyle:
            self.duplicate_mesh(
                gargoyle,
                "Dungeon_Altar_Gargoyle_R",
                (1.6, 1.2, 0.0),
                rotation_euler_deg=(0.0, 0.0, -45.0),
                scale=(0.75, 0.75, 0.75)
            )

        # 9. Burning Braziers casting long shadows down the hallway
        brazier_f_l = self.import_lod0_mesh(
            "brazier",
            "Dungeon_Brazier_FL",
            location=(-1.9, -2.8, 0.0),
            scale=(1.05, 1.05, 1.05)
        )
        if brazier_f_l:
            self.duplicate_mesh(brazier_f_l, "Dungeon_Brazier_FR", (1.9, -2.8, 0.0), scale=(1.05, 1.05, 1.05))
            self.duplicate_mesh(brazier_f_l, "Dungeon_Brazier_BL", (-1.9, 3.2, 0.0), scale=(1.05, 1.05, 1.05))
            self.duplicate_mesh(brazier_f_l, "Dungeon_Brazier_BR", (1.9, 3.2, 0.0), scale=(1.05, 1.05, 1.05))

        # 10. Dynamic Lighting
        # A. Front Left Torch
        self.create_light("Dungeon_Torch_FL", 'POINT', (-1.9, -2.8, 1.2), energy=240.0, color=(1.0, 0.42, 0.08), shadow_soft_size=0.22)
        # B. Front Right Torch
        self.create_light("Dungeon_Torch_FR", 'POINT', (1.9, -2.8, 1.2), energy=240.0, color=(1.0, 0.42, 0.08), shadow_soft_size=0.22)
        # C. Back Left Torch
        self.create_light("Dungeon_Torch_BL", 'POINT', (-1.9, 3.2, 1.2), energy=180.0, color=(1.0, 0.45, 0.10), shadow_soft_size=0.22)
        # D. Back Right Torch
        self.create_light("Dungeon_Torch_BR", 'POINT', (1.9, 3.2, 1.2), energy=180.0, color=(1.0, 0.45, 0.10), shadow_soft_size=0.22)

        # E. Abyssal Portal Rim Light (cold eerie magenta/violet backlight behind the portcullis)
        self.create_light(
            name="Abyssal_Backlight",
            light_type='SPOT',
            location=(0.0, 7.5, 3.5),
            energy=850.0,
            color=(0.75, 0.15, 0.95),
            rotation_euler_deg=(160.0, 0.0, 0.0),
            spot_size_deg=65.0,
            spot_blend=0.5
        )

        # F. Crimson Altar Glow
        self.create_light("BloodAltar_RuneLight", 'POINT', (0.0, 1.0, 1.1), energy=80.0, color=(1.0, 0.08, 0.15), shadow_soft_size=0.35)

        # 11. Cinematic Dungeon Camera (Low angle looking down corridor)
        self.create_camera(
            name="Cinematic_Dungeon_Camera",
            location=(0.0, -7.2, 1.3),
            rotation_euler_deg=(80.0, 0.0, 0.0),
            lens=32.0,
            dof_distance=8.0,
            fstop=3.2
        )

        return scene

    def render_to_file(self, filename: str) -> str:
        """Executes the render and writes the output PNG file."""
        filepath = os.path.join(self.output_dir, filename)
        bpy.context.scene.render.filepath = filepath

        t0 = time.time()
        print(f"[*] Rendering beauty shot: {filename} ({bpy.context.scene.render.resolution_x}x{bpy.context.scene.render.resolution_y})...")
        bpy.ops.render.render(write_still=True)
        elapsed = time.time() - t0

        if os.path.exists(filepath):
            size_kb = os.path.getsize(filepath) / 1024.0
            print(f"[+] Render complete: {filepath} ({size_kb:.1f} KB in {elapsed:.2f}s)")
        else:
            print(f"[!] Warning: Render output file not found at {filepath}")

        return filepath


def run_pipeline(
    workspace_root: str,
    render_hub: bool = True,
    render_dungeon: bool = True,
    samples: int = 256,
    resolution: Tuple[int, int] = (1080, 2400)
) -> Dict[str, Any]:
    """Executes the full cinematic beauty shot rendering pipeline."""
    renderer = CinematicRenderer(workspace_root)
    reports = {}

    print("=" * 70)
    print("Aion 2 Dark Fantasy Cinematic Beauty Shot Renderer (Blender Cycles)")
    print(f"Target Resolution: {resolution[0]}x{resolution[1]} (Mobile 9:20 Portrait)")
    print(f"Samples: {samples} (Adaptive + OptiX AI Denoising)")
    print(f"Output Directory: {renderer.output_dir}")
    print("=" * 70)

    # 1. Main Hub Scene
    if render_hub:
        scene = renderer.build_hub_scene()
        renderer.configure_cycles(scene, width=resolution[0], height=resolution[1], samples=samples)
        hub_shot = renderer.render_to_file("hub_beauty_shot.png")

        # Detail close-up: Sword & Wings hero pedestal
        cam = scene.camera
        cam.location = Vector((0.0, -1.8, 1.45))
        cam.rotation_euler = Euler((math.radians(72.0), 0.0, 0.0))
        cam.data.lens = 55.0
        cam.data.dof.focus_distance = 2.9
        cam.data.dof.aperture_fstop = 2.0
        hub_closeup = renderer.render_to_file("hub_wings_sword_closeup.png")

        reports["hub"] = {
            "main_shot": hub_shot,
            "closeup_shot": hub_closeup,
            "resolution": resolution,
            "samples": samples
        }

    # 2. Dungeon Scene
    if render_dungeon:
        scene = renderer.build_dungeon_scene()
        renderer.configure_cycles(scene, width=resolution[0], height=resolution[1], samples=samples)
        dungeon_shot = renderer.render_to_file("dungeon_beauty_shot.png")

        # Detail close-up: Altar & Torch brazier
        cam = scene.camera
        cam.location = Vector((-0.8, -1.4, 0.95))
        cam.rotation_euler = Euler((math.radians(75.0), 0.0, math.radians(-18.0)))
        cam.data.lens = 48.0
        cam.data.dof.focus_distance = 2.6
        cam.data.dof.aperture_fstop = 2.2
        dungeon_closeup = renderer.render_to_file("dungeon_altar_brazier_closeup.png")

        reports["dungeon"] = {
            "main_shot": dungeon_shot,
            "closeup_shot": dungeon_closeup,
            "resolution": resolution,
            "samples": samples
        }

    print("=" * 70)
    print("All Cinematic Beauty Shots Rendered Successfully!")
    print("=" * 70)
    return reports


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Aion 2 Dark Fantasy Cinematic Renderer")
    parser.add_argument("--hub-only", action="store_true", help="Render only Main Hub")
    parser.add_argument("--dungeon-only", action="store_true", help="Render only Dungeon")
    parser.add_argument("--samples", type=int, default=256, help="Cycles render samples")
    parser.add_argument("--width", type=int, default=1080, help="Image width")
    parser.add_argument("--height", type=int, default=2400, help="Image height")
    parser.add_argument("--workspace", type=str, default=os.getcwd(), help="Workspace root path")

    args_list = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = parser.parse_args(args_list)

    render_hub = not args.dungeon_only
    render_dungeon = not args.hub_only

    run_pipeline(
        workspace_root=args.workspace,
        render_hub=render_hub,
        render_dungeon=render_dungeon,
        samples=args.samples,
        resolution=(args.width, args.height)
    )


if __name__ == "__main__":
    main()
