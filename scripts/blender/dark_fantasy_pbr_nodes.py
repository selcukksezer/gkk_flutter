#!/usr/bin/env python3
"""
Dark Fantasy PBR Shader Node Graph Master (Ajan-Blender 9)
==========================================================
Constructs complete, production-grade Principled BSDF node trees for AAA
dark fantasy games (Dark Souls / Elden Ring / Diablo IV aesthetic) in Blender.

Key Subsystems:
1. Micro-Roughness Detail Mapping:
   - High-frequency tiling coordinates (Mapping node)
   - Centered detail offset blend (Detail - 0.5) * intensity
   - Additive / linear light clamp onto macro roughness map
2. Clearcoat / Wetness Layers for Puddles:
   - Procedural or texture-driven puddle pooling mask
   - Porosity albedo darkening (water diffuse absorption)
   - Underwater roughness smoothing (0.02 - 0.05 mirror surface)
   - Clearcoat / Coat weight & Coat roughness dielectric layer
   - Normal map flattening inside standing puddle pools
3. Emission Pulse Nodes for Magical Weapons:
   - Dual-tone magic gradient (fiery/arcane core vs glancing rim halo)
   - Fresnel / Layer Weight (Facing) luminance modulation
   - Rhythmic breathing sine wave oscillator + chaotic micro-flicker
   - High Dynamic Range (HDR) emission strength multiplier
4. Ambient Occlusion (AO) Multiplier & Cavity Grime:
   - Procedural AO node (ShaderNodeAmbientOcclusion) or AO texture map
   - Deep crevice power curve
   - Artistic cavity color tinting (cold charcoal / mossy grime)
   - Specular cavity occlusion (attenuating reflections in cracks)

Cross-Version Compatibility:
- Blender 3.3, 3.4, 3.6 LTS, 4.0+, 4.2 LTS, 5.0+
- Dynamic socket resolution (Coat Weight vs Clearcoat, Specular IOR Level vs Specular, etc.)
- Multi-data-type ShaderNodeMix abstraction (RGBA, FLOAT, VECTOR)

Author: Ajan-Blender 9 (PBR Shader Node Graph Master)
Project: gkk_flutter / Dark Fantasy 2027 AAA Visual Pipeline
"""

from __future__ import annotations

import math
import sys
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

try:
    import bpy
    import mathutils
    HAS_BPY = True
except ImportError:
    HAS_BPY = False
    bpy = None
    mathutils = None


# ============================================================================
# Compatibility & Socket Helpers
# ============================================================================

def resolve_bsdf_socket(bsdf_node: Any, logical_name: str) -> Optional[Any]:
    """
    Resolves Principled BSDF input sockets transparently across Blender 3.x, 4.x, and 5.x.
    """
    if bsdf_node is None:
        return None

    socket_map = {
        "Base Color": ["Base Color"],
        "Metallic": ["Metallic"],
        "Roughness": ["Roughness"],
        "Coat Weight": ["Coat Weight", "Clearcoat"],
        "Coat Roughness": ["Coat Roughness", "Clearcoat Roughness"],
        "Coat Normal": ["Coat Normal", "Clearcoat Normal"],
        "Emission Color": ["Emission Color", "Emission"],
        "Emission Strength": ["Emission Strength"],
        "Specular": ["Specular IOR Level", "Specular"],
        "Specular Tint": ["Specular Tint"],
        "Normal": ["Normal"],
        "Alpha": ["Alpha"],
        "IOR": ["IOR"],
    }

    candidates = socket_map.get(logical_name, [logical_name])
    for cand in candidates:
        sock = bsdf_node.inputs.get(cand)
        if sock is not None:
            return sock
    return None


def create_mix_node(node_tree: Any, data_type: str = 'RGBA', blend_type: str = 'MIX', name: str = "Mix") -> Any:
    """
    Creates a Mix node compatible with Blender 3.4+ / 4.x / 5.x (ShaderNodeMix)
    and falls back to Blender 3.3- (ShaderNodeMixRGB).
    """
    try:
        mix = node_tree.nodes.new('ShaderNodeMix')
        mix.name = name
        mix.label = name
        mix.data_type = data_type
        mix.blend_type = blend_type
        return mix
    except Exception:
        # Legacy Blender 3.3 fallback
        mix = node_tree.nodes.new('ShaderNodeMixRGB')
        mix.name = name
        mix.label = name
        mix.blend_type = blend_type
        return mix


def get_mix_sockets(mix_node: Any) -> Tuple[Any, Any, Any, Any]:
    """
    Returns (factor_socket, a_socket, b_socket, result_socket)
    compatible with ShaderNodeMix (RGBA, FLOAT, VECTOR) and ShaderNodeMixRGB.
    """
    if mix_node.bl_idname == 'ShaderNodeMixRGB':
        return (
            mix_node.inputs['Fac'],
            mix_node.inputs['Color1'],
            mix_node.inputs['Color2'],
            mix_node.outputs['Color']
        )

    dt = getattr(mix_node, 'data_type', 'RGBA')
    if dt == 'RGBA':
        # Factor (index 0, VALUE), A (index 6, RGBA), B (index 7, RGBA), Result (index 2, RGBA)
        factor = mix_node.inputs[0]
        a = mix_node.inputs[6]
        b = mix_node.inputs[7]
        res = mix_node.outputs[2]
        return factor, a, b, res
    elif dt == 'FLOAT':
        # Factor (index 0, VALUE), A (index 2, VALUE), B (index 3, VALUE), Result (index 0, VALUE)
        factor = mix_node.inputs[0]
        a = mix_node.inputs[2]
        b = mix_node.inputs[3]
        res = mix_node.outputs[0]
        return factor, a, b, res
    elif dt == 'VECTOR':
        # Factor (index 0, VALUE), A (index 4, VECTOR), B (index 5, VECTOR), Result (index 1, VECTOR)
        factor = mix_node.inputs[0]
        a = mix_node.inputs[4]
        b = mix_node.inputs[5]
        res = mix_node.outputs[1]
        return factor, a, b, res
    else:
        # Fallback search by type
        expected = 'RGBA' if dt == 'RGBA' else 'VALUE' if dt == 'FLOAT' else 'VECTOR'
        factor = next(s for s in mix_node.inputs if s.enabled and s.type == 'VALUE' and 'Factor' in s.name)
        ins = [s for s in mix_node.inputs if s.enabled and s.type == expected]
        res = next(s for s in mix_node.outputs if s.enabled and s.type == expected)
        return factor, ins[0], ins[1], res


def add_group_socket(
    node_group: Any,
    name: str,
    socket_type: str,
    in_out: str = 'INPUT',
    default_value: Optional[Any] = None,
    min_value: Optional[float] = None,
    max_value: Optional[float] = None
) -> Any:
    """
    Creates an interface socket on a ShaderNodeTree compatible with Blender 4.0+/5.0+ and 3.x.
    """
    if hasattr(node_group, 'interface'):
        # Blender 4.0+ & 5.0+ API
        sock = node_group.interface.new_socket(name, in_out=in_out, socket_type=socket_type)
        if default_value is not None and hasattr(sock, 'default_value'):
            sock.default_value = default_value
        if min_value is not None and hasattr(sock, 'min_value'):
            sock.min_value = min_value
        if max_value is not None and hasattr(sock, 'max_value'):
            sock.max_value = max_value
        return sock
    else:
        # Blender 3.x legacy API
        if in_out == 'INPUT':
            sock = node_group.inputs.new(socket_type, name)
        else:
            sock = node_group.outputs.new(socket_type, name)
        if default_value is not None and hasattr(sock, 'default_value'):
            sock.default_value = default_value
        return sock


# ============================================================================
# Configuration Data Classes
# ============================================================================

@dataclass
class MicroRoughnessConfig:
    detail_scale: float = 16.0
    intensity: float = 0.35
    noise_detail: float = 6.0
    noise_roughness: float = 0.7
    noise_distortion: float = 0.5
    use_texture_image: bool = False
    image_filepath: Optional[str] = None


@dataclass
class PuddleWetnessConfig:
    water_darkening: float = 0.52           # 52% albedo darkening in puddles
    puddle_roughness: float = 0.03          # Smooth water surface
    clearcoat_max: float = 1.0              # Clearcoat / coat weight in full puddle
    clearcoat_roughness: float = 0.03       # Clearcoat gloss
    normal_flatten_factor: float = 0.85     # Normal flattening strength
    noise_scale: float = 3.2                # Puddle distribution scale
    noise_detail: float = 4.0
    puddle_threshold: float = 0.52          # Cutoff threshold for puddles
    wet_transition_width: float = 0.18      # Damp ring width around puddles


@dataclass
class EmissionPulseConfig:
    core_color: Tuple[float, float, float, float] = (0.1, 0.95, 1.0, 1.0)       # Arcane cyan core
    glancing_color: Tuple[float, float, float, float] = (0.65, 0.08, 0.9, 1.0)  # Ethereal violet rim
    pulse_speed: float = 2.4                                                   # Breathing rate (rad/s)
    pulse_amplitude: float = 0.65                                              # Dynamic modulation
    min_glow: float = 0.25                                                     # Idle baseline glow
    flicker_speed: float = 12.7                                                # High-frequency jitter
    flicker_strength: float = 0.22                                             # Instability amplitude
    base_strength: float = 20.0                                                # HDR emission strength
    use_fresnel: bool = True
    fresnel_ior: float = 1.45
    facing_blend: float = 0.62


@dataclass
class AmbientOcclusionConfig:
    use_procedural_ao: bool = True
    ao_distance: float = 0.65               # Search radius in meters
    ao_power: float = 1.6                   # Deepen crevices
    ao_strength: float = 1.0                # Global multiplier
    cavity_tint: Tuple[float, float, float, float] = (0.02, 0.025, 0.04, 1.0) # Deep cold charcoal
    cavity_tint_strength: float = 0.68      # Tint blend in cracks
    specular_occlusion: float = 0.80        # Specular suppression in cavities


@dataclass
class BasePBRConfig:
    base_color: Tuple[float, float, float, float] = (0.15, 0.14, 0.13, 1.0) # Weathered dark iron
    metallic: float = 0.90
    base_roughness: float = 0.55
    specular: float = 0.50
    normal_strength: float = 1.0
    uv_scale: float = 1.0


# ============================================================================
# Dark Fantasy PBR Shader Node Graph Builder
# ============================================================================

class DarkFantasyPBRBuilder:
    """
    Production-grade node graph builder constructing AAA dark fantasy materials.
    """

    def __init__(self, material_name: str = "M_DarkFantasy_PBR"):
        if not HAS_BPY:
            raise RuntimeError("bpy is not available in the current Python environment.")
        self.material_name = material_name
        self.material: Optional[Any] = None
        self.node_tree: Optional[Any] = None
        self.bsdf_node: Optional[Any] = None
        self.output_node: Optional[Any] = None
        self.tex_coord_node: Optional[Any] = None
        self.time_node: Optional[Any] = None

    def initialize_material(self) -> Any:
        """Creates or resets the target material with clean node tree."""
        # Find or create material
        mat = bpy.data.materials.get(self.material_name)
        if mat is None:
            mat = bpy.data.materials.new(name=self.material_name)

        mat.use_nodes = True
        self.material = mat
        self.node_tree = mat.node_tree
        nodes = self.node_tree.nodes
        links = self.node_tree.links

        # Clear existing nodes
        nodes.clear()

        # Create Principled BSDF & Material Output
        self.bsdf_node = nodes.new('ShaderNodeBsdfPrincipled')
        self.bsdf_node.name = "Principled_BSDF"
        self.bsdf_node.label = "AAA Dark Fantasy BSDF"
        self.bsdf_node.location = (200, 0)

        self.output_node = nodes.new('ShaderNodeOutputMaterial')
        self.output_node.name = "Material_Output"
        self.output_node.location = (550, 0)

        # Connect BSDF to Output
        links.new(self.bsdf_node.outputs['BSDF'], self.output_node.inputs['Surface'])

        # Shared Texture Coordinate & Time driver
        self.tex_coord_node = nodes.new('ShaderNodeTexCoord')
        self.tex_coord_node.name = "TexCoord_Shared"
        self.tex_coord_node.label = "Shared Texture Coordinate"
        self.tex_coord_node.location = (-1900, -200)

        self.time_node = nodes.new('ShaderNodeValue')
        self.time_node.name = "Time_Driver"
        self.time_node.label = "Time / Frame Oscillator"
        self.time_node.outputs[0].default_value = 1.0
        self.time_node.location = (-1900, -800)

        # Optional driver on time node: #frame / 24.0 for seamless animated pulse
        try:
            drv = self.time_node.outputs[0].driver_add("default_value")
            drv.driver.expression = "frame / 24.0"
        except Exception:
            pass

        return self.material

    def create_frame(self, label: str, color: Tuple[float, float, float] = (0.2, 0.2, 0.25)) -> Any:
        """Creates a visual frame container in the shader editor."""
        frame = self.node_tree.nodes.new('NodeFrame')
        frame.label = label
        frame.use_custom_color = True
        frame.color = color
        return frame

    # ------------------------------------------------------------------------
    # Subsystem 1: Ambient Occlusion (AO) Multiplier & Cavity Grime
    # ------------------------------------------------------------------------
    def build_ambient_occlusion_network(
        self,
        config: AmbientOcclusionConfig,
        base_color_socket: Any,
        specular_socket: Any,
        x_base: float = -1400,
        y_base: float = 600
    ) -> Tuple[Any, Any]:
        """
        Constructs AO multiplier and cavity color tinting node network.
        Returns: (occluded_base_color_socket, occluded_specular_socket)
        """
        nt = self.node_tree
        links = nt.links
        frame = self.create_frame("AO & Cavity Tinting (Grim Crevices)", (0.15, 0.18, 0.25))

        # 1. AO Generator (Procedural Ambient Occlusion node or fallback)
        ao_node = nt.nodes.new('ShaderNodeAmbientOcclusion')
        ao_node.name = "AO_Generator"
        ao_node.label = "Crevice AO Generator"
        ao_node.parent = frame
        ao_node.location = (x_base, y_base)
        ao_node.inputs['Distance'].default_value = config.ao_distance

        # 2. AO Power Curve (deeper crevices)
        ao_pow = nt.nodes.new('ShaderNodeMath')
        ao_pow.name = "AO_Power"
        ao_pow.label = "AO Crevice Contrast"
        ao_pow.operation = 'POWER'
        ao_pow.parent = frame
        ao_pow.location = (x_base + 260, y_base)
        links.new(ao_node.outputs['AO'], ao_pow.inputs[0])
        ao_pow.inputs[1].default_value = config.ao_power

        # 3. AO Intensity Scaler
        ao_scale = create_mix_node(nt, data_type='FLOAT', blend_type='MIX', name="AO_Strength_Mix")
        ao_scale.label = "AO Strength Blend"
        ao_scale.parent = frame
        ao_scale.location = (x_base + 500, y_base)
        f_sock, a_sock, b_sock, ao_final_sock = get_mix_sockets(ao_scale)
        f_sock.default_value = config.ao_strength
        a_sock.default_value = 1.0  # Dry / un-occluded
        links.new(ao_pow.outputs['Value'], b_sock)

        # 4. Cavity Mask (1.0 - AO)
        cavity_invert = nt.nodes.new('ShaderNodeMath')
        cavity_invert.name = "Cavity_Invert"
        cavity_invert.label = "Crevice Cavity Mask"
        cavity_invert.operation = 'SUBTRACT'
        cavity_invert.parent = frame
        cavity_invert.location = (x_base + 500, y_base - 180)
        cavity_invert.inputs[0].default_value = 1.0
        links.new(ao_final_sock, cavity_invert.inputs[1])

        # 5. Cavity Tint Blend
        cavity_mix = create_mix_node(nt, data_type='RGBA', blend_type='MIX', name="Cavity_Tint_Mix")
        cavity_mix.label = "Cavity Tint (Grim Dirt/Cold Shadow)"
        cavity_mix.parent = frame
        cavity_mix.location = (x_base + 780, y_base - 100)
        c_f, c_a, c_b, cavity_color_sock = get_mix_sockets(cavity_mix)

        # Factor = cavity_invert * cavity_tint_strength
        cavity_fac = nt.nodes.new('ShaderNodeMath')
        cavity_fac.name = "Cavity_Fac_Scale"
        cavity_fac.operation = 'MULTIPLY'
        cavity_fac.parent = frame
        cavity_fac.location = (x_base + 640, y_base - 320)
        links.new(cavity_invert.outputs['Value'], cavity_fac.inputs[0])
        cavity_fac.inputs[1].default_value = config.cavity_tint_strength
        links.new(cavity_fac.outputs['Value'], c_f)

        links.new(base_color_socket, c_a)
        c_b.default_value = config.cavity_tint

        # 6. Direct AO Multiplication
        ao_mult = create_mix_node(nt, data_type='RGBA', blend_type='MULTIPLY', name="AO_BaseColor_Multiply")
        ao_mult.label = "AO * Cavity Albedo"
        ao_mult.parent = frame
        ao_mult.location = (x_base + 1060, y_base)
        m_f, m_a, m_b, occluded_base_color = get_mix_sockets(ao_mult)
        m_f.default_value = 1.0
        links.new(cavity_color_sock, m_a)
        links.new(ao_final_sock, m_b)

        # 7. Specular Cavity Occlusion
        spec_mix = create_mix_node(nt, data_type='FLOAT', blend_type='MIX', name="Specular_AO_Occlusion")
        spec_mix.label = "Cavity Specular Occlusion"
        spec_mix.parent = frame
        spec_mix.location = (x_base + 1060, y_base - 220)
        s_f, s_a, s_b, occluded_specular = get_mix_sockets(spec_mix)
        s_f.default_value = config.specular_occlusion
        links.new(specular_socket, s_a)

        spec_mult = nt.nodes.new('ShaderNodeMath')
        spec_mult.name = "Spec_AO_Mult"
        spec_mult.operation = 'MULTIPLY'
        spec_mult.parent = frame
        spec_mult.location = (x_base + 880, y_base - 260)
        links.new(specular_socket, spec_mult.inputs[0])
        links.new(ao_final_sock, spec_mult.inputs[1])
        links.new(spec_mult.outputs['Value'], s_b)

        return occluded_base_color, occluded_specular

    # ------------------------------------------------------------------------
    # Subsystem 2: Micro-Roughness Detail Mapping
    # ------------------------------------------------------------------------
    def build_micro_roughness_network(
        self,
        config: MicroRoughnessConfig,
        base_roughness_socket: Any,
        x_base: float = -1400,
        y_base: float = 0
    ) -> Any:
        """
        Constructs micro-roughness detail mapping with high-frequency UV tiling,
        centered detail offset, and additive clamped blending.
        Returns: micro_roughness_output_socket
        """
        nt = self.node_tree
        links = nt.links
        frame = self.create_frame("Micro-Roughness Detail Mapping (Pores & Scratches)", (0.25, 0.18, 0.15))

        # 1. Micro Detail UV Mapping
        micro_mapping = nt.nodes.new('ShaderNodeMapping')
        micro_mapping.name = "Micro_UV_Mapping"
        micro_mapping.label = f"Micro UV Tiling ({config.detail_scale:.1f}x)"
        micro_mapping.parent = frame
        micro_mapping.location = (x_base, y_base)
        links.new(self.tex_coord_node.outputs['UV'], micro_mapping.inputs['Vector'])
        micro_mapping.inputs['Scale'].default_value = (
            config.detail_scale, config.detail_scale, config.detail_scale
        )

        # 2. High-Frequency Micro Noise Generator (or Image Texture)
        micro_noise = nt.nodes.new('ShaderNodeTexNoise')
        micro_noise.name = "Micro_Noise_Texture"
        micro_noise.label = "Micro Surface Noise"
        micro_noise.parent = frame
        micro_noise.location = (x_base + 260, y_base)
        links.new(micro_mapping.outputs['Vector'], micro_noise.inputs['Vector'])
        micro_noise.inputs['Scale'].default_value = 14.0
        micro_noise.inputs['Detail'].default_value = config.noise_detail
        micro_noise.inputs['Roughness'].default_value = config.noise_roughness
        micro_noise.inputs['Distortion'].default_value = config.noise_distortion

        # 3. Center Detail: (Detail - 0.5)
        center_sub = nt.nodes.new('ShaderNodeMath')
        center_sub.name = "Micro_Center"
        center_sub.label = "Detail Center (-0.5)"
        center_sub.operation = 'SUBTRACT'
        center_sub.parent = frame
        center_sub.location = (x_base + 500, y_base)
        links.new(micro_noise.outputs['Fac'], center_sub.inputs[0])
        center_sub.inputs[1].default_value = 0.5

        # 4. Scale Detail Intensity
        scale_mult = nt.nodes.new('ShaderNodeMath')
        scale_mult.name = "Micro_Scale_Intensity"
        scale_mult.label = "Scale Micro Intensity"
        scale_mult.operation = 'MULTIPLY'
        scale_mult.parent = frame
        scale_mult.location = (x_base + 720, y_base)
        links.new(center_sub.outputs['Value'], scale_mult.inputs[0])
        scale_mult.inputs[1].default_value = config.intensity

        # 5. Additive Blend onto Macro Base Roughness with clamp
        roughness_add = nt.nodes.new('ShaderNodeMath')
        roughness_add.name = "Micro_Roughness_Add"
        roughness_add.label = "Combine Base + Micro Detail"
        roughness_add.operation = 'ADD'
        roughness_add.use_clamp = True
        roughness_add.parent = frame
        roughness_add.location = (x_base + 960, y_base)
        links.new(base_roughness_socket, roughness_add.inputs[0])
        links.new(scale_mult.outputs['Value'], roughness_add.inputs[1])

        return roughness_add.outputs['Value']

    # ------------------------------------------------------------------------
    # Subsystem 3: Clearcoat / Wetness Layers for Puddles
    # ------------------------------------------------------------------------
    def build_puddle_wetness_network(
        self,
        config: PuddleWetnessConfig,
        albedo_socket: Any,
        roughness_socket: Any,
        normal_socket: Any,
        x_base: float = -1400,
        y_base: float = -450
    ) -> Tuple[Any, Any, Any, Any, Any]:
        """
        Constructs procedural puddle pools, water absorption albedo darkening,
        mirror roughness smoothing, clearcoat water film, and normal flattening.
        Returns: (wet_albedo, wet_roughness, coat_weight, coat_roughness, wet_normal)
        """
        nt = self.node_tree
        links = nt.links
        frame = self.create_frame("Puddle & Wetness Layer (Water Pores & Reflections)", (0.12, 0.22, 0.28))

        # 1. Puddle Noise Generator
        puddle_noise = nt.nodes.new('ShaderNodeTexNoise')
        puddle_noise.name = "Puddle_Noise_Mask"
        puddle_noise.label = "Procedural Puddle Noise"
        puddle_noise.parent = frame
        puddle_noise.location = (x_base, y_base)
        links.new(self.tex_coord_node.outputs['UV'], puddle_noise.inputs['Vector'])
        puddle_noise.inputs['Scale'].default_value = config.noise_scale
        puddle_noise.inputs['Detail'].default_value = config.noise_detail
        puddle_noise.inputs['Roughness'].default_value = 0.5

        # 2. Puddle Threshold Ramp / Smoothstep
        puddle_ramp = nt.nodes.new('ShaderNodeValToRGB')
        puddle_ramp.name = "Puddle_Ramp"
        puddle_ramp.label = "Puddle Water Edge Transition"
        puddle_ramp.parent = frame
        puddle_ramp.location = (x_base + 260, y_base)
        links.new(puddle_noise.outputs['Fac'], puddle_ramp.inputs['Fac'])

        # Configure ramp: 0.0 dry ground, smooth transition ring, 1.0 full puddle
        t_low = max(0.0, config.puddle_threshold - config.wet_transition_width)
        t_high = min(1.0, config.puddle_threshold + config.wet_transition_width)
        puddle_ramp.color_ramp.elements[0].position = t_low
        puddle_ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
        puddle_ramp.color_ramp.elements[1].position = t_high
        puddle_ramp.color_ramp.elements[1].color = (1, 1, 1, 1)

        puddle_mask_sock = puddle_ramp.outputs['Color']

        # 3. Water Absorption: Albedo Darkening
        darken_mix = create_mix_node(nt, data_type='RGBA', blend_type='MULTIPLY', name="Water_Absorption_Multiply")
        darken_mix.label = "Water Absorption Darkening"
        darken_mix.parent = frame
        darken_mix.location = (x_base + 580, y_base + 120)
        d_f, d_a, d_b, darkened_albedo = get_mix_sockets(darken_mix)
        links.new(puddle_mask_sock, d_f)
        links.new(albedo_socket, d_a)
        # Absorption factor: dry * (1 - water_darkening)
        d_b.default_value = (
            1.0 - config.water_darkening,
            1.0 - config.water_darkening,
            1.0 - config.water_darkening,
            1.0
        )

        # 4. Roughness Smoothing: Wet puddle becomes glass-smooth
        roughness_mix = create_mix_node(nt, data_type='FLOAT', blend_type='MIX', name="Wet_Roughness_Mix")
        roughness_mix.label = "Puddle Mirror Smoothing"
        roughness_mix.parent = frame
        roughness_mix.location = (x_base + 580, y_base - 80)
        r_f, r_a, r_b, wet_roughness = get_mix_sockets(roughness_mix)
        links.new(puddle_mask_sock, r_f)
        links.new(roughness_socket, r_a)
        r_b.default_value = config.puddle_roughness

        # 5. Clearcoat / Coat Weight: Full dielectric water film in puddles
        coat_mult = nt.nodes.new('ShaderNodeMath')
        coat_mult.name = "Puddle_Coat_Weight"
        coat_mult.label = "Puddle Coat Weight"
        coat_mult.operation = 'MULTIPLY'
        coat_mult.parent = frame
        coat_mult.location = (x_base + 840, y_base - 180)
        links.new(puddle_mask_sock, coat_mult.inputs[0])
        coat_mult.inputs[1].default_value = config.clearcoat_max
        coat_weight = coat_mult.outputs['Value']

        # 6. Coat Roughness constant
        coat_roughness_node = nt.nodes.new('ShaderNodeValue')
        coat_roughness_node.name = "Puddle_Coat_Roughness"
        coat_roughness_node.label = "Puddle Coat Gloss"
        coat_roughness_node.parent = frame
        coat_roughness_node.location = (x_base + 840, y_base - 320)
        coat_roughness_node.outputs['Value'].default_value = config.clearcoat_roughness
        coat_roughness = coat_roughness_node.outputs['Value']

        # 7. Normal Map Flattening: Standing water has smooth planar normal
        normal_mix = create_mix_node(nt, data_type='VECTOR', blend_type='MIX', name="Puddle_Normal_Flatten")
        normal_mix.label = "Puddle Normal Flatten"
        normal_mix.parent = frame
        normal_mix.location = (x_base + 840, y_base - 460)
        n_f, n_a, n_b, wet_normal = get_mix_sockets(normal_mix)

        # Flattening factor = puddle_mask * normal_flatten_factor
        norm_fac = nt.nodes.new('ShaderNodeMath')
        norm_fac.name = "Normal_Flatten_Scale"
        norm_fac.operation = 'MULTIPLY'
        norm_fac.parent = frame
        norm_fac.location = (x_base + 660, y_base - 460)
        links.new(puddle_mask_sock, norm_fac.inputs[0])
        norm_fac.inputs[1].default_value = config.normal_flatten_factor
        links.new(norm_fac.outputs['Value'], n_f)

        links.new(normal_socket, n_a)
        # Flat normal = geometry normal from TexCoord
        links.new(self.tex_coord_node.outputs['Normal'], n_b)

        return darkened_albedo, wet_roughness, coat_weight, coat_roughness, wet_normal

    # ------------------------------------------------------------------------
    # Subsystem 4: Emission Pulse Nodes for Magical Weapons
    # ------------------------------------------------------------------------
    def build_magical_emission_pulse_network(
        self,
        config: EmissionPulseConfig,
        rune_mask_socket: Optional[Any] = None,
        x_base: float = -1400,
        y_base: float = -1100
    ) -> Tuple[Any, Any]:
        """
        Constructs animated magical emission pulse oscillator, dual-tone fresnel
        gradient, chaotic micro-flicker, and HDR bloom multiplier.
        Returns: (emission_color_socket, emission_strength_socket)
        """
        nt = self.node_tree
        links = nt.links
        frame = self.create_frame("Magical Weapon Emission Pulse (Arcane / Soul Aura)", (0.28, 0.12, 0.28))

        # 1. Primary Pulse Oscillator: Time * pulse_speed
        time_scaled = nt.nodes.new('ShaderNodeMath')
        time_scaled.name = "Pulse_Time_Scaled"
        time_scaled.label = "Pulse Speed Multiplier"
        time_scaled.operation = 'MULTIPLY'
        time_scaled.parent = frame
        time_scaled.location = (x_base, y_base)
        links.new(self.time_node.outputs['Value'], time_scaled.inputs[0])
        time_scaled.inputs[1].default_value = config.pulse_speed

        # Sine wave: [-1, +1]
        sine_node = nt.nodes.new('ShaderNodeMath')
        sine_node.name = "Pulse_Sine"
        sine_node.label = "Breathing Sine Wave"
        sine_node.operation = 'SINE'
        sine_node.parent = frame
        sine_node.location = (x_base + 200, y_base)
        links.new(time_scaled.outputs['Value'], sine_node.inputs[0])

        # Normalize to [0, 1]: (sin + 1) * 0.5
        sine_add = nt.nodes.new('ShaderNodeMath')
        sine_add.name = "Pulse_Sine_Offset"
        sine_add.operation = 'ADD'
        sine_add.parent = frame
        sine_add.location = (x_base + 380, y_base)
        links.new(sine_node.outputs['Value'], sine_add.inputs[0])
        sine_add.inputs[1].default_value = 1.0

        sine_norm = nt.nodes.new('ShaderNodeMath')
        sine_norm.name = "Pulse_Sine_Norm"
        sine_norm.operation = 'MULTIPLY'
        sine_norm.parent = frame
        sine_norm.location = (x_base + 560, y_base)
        links.new(sine_add.outputs['Value'], sine_norm.inputs[0])
        sine_norm.inputs[1].default_value = 0.5

        # 2. High-Frequency Chaotic Jitter / Flicker: Time * flicker_speed
        flicker_time = nt.nodes.new('ShaderNodeMath')
        flicker_time.name = "Flicker_Time_Scaled"
        flicker_time.label = "Chaotic Jitter Speed"
        flicker_time.operation = 'MULTIPLY'
        flicker_time.parent = frame
        flicker_time.location = (x_base, y_base - 180)
        links.new(self.time_node.outputs['Value'], flicker_time.inputs[0])
        flicker_time.inputs[1].default_value = config.flicker_speed

        flicker_sine = nt.nodes.new('ShaderNodeMath')
        flicker_sine.name = "Flicker_Sine"
        flicker_sine.operation = 'SINE'
        flicker_sine.parent = frame
        flicker_sine.location = (x_base + 200, y_base - 180)
        links.new(flicker_time.outputs['Value'], flicker_sine.inputs[0])

        flicker_norm = nt.nodes.new('ShaderNodeMath')
        flicker_norm.name = "Flicker_Norm"
        flicker_norm.operation = 'MULTIPLY'
        flicker_norm.parent = frame
        flicker_norm.location = (x_base + 380, y_base - 180)
        links.new(flicker_sine.outputs['Value'], flicker_norm.inputs[0])
        flicker_norm.inputs[1].default_value = config.flicker_strength

        # 3. Combine Breathing + Jitter
        pulse_combine = nt.nodes.new('ShaderNodeMath')
        pulse_combine.name = "Pulse_Combine_Jitter"
        pulse_combine.label = "Breathing + Jitter Sum"
        pulse_combine.operation = 'ADD'
        pulse_combine.use_clamp = True
        pulse_combine.parent = frame
        pulse_combine.location = (x_base + 740, y_base)
        links.new(sine_norm.outputs['Value'], pulse_combine.inputs[0])
        links.new(flicker_norm.outputs['Value'], pulse_combine.inputs[1])

        # Scale amplitude + baseline glow
        pulse_amp = nt.nodes.new('ShaderNodeMath')
        pulse_amp.name = "Pulse_Scale_Amp"
        pulse_amp.operation = 'MULTIPLY'
        pulse_amp.parent = frame
        pulse_amp.location = (x_base + 920, y_base)
        links.new(pulse_combine.outputs['Value'], pulse_amp.inputs[0])
        pulse_amp.inputs[1].default_value = config.pulse_amplitude

        pulse_baseline = nt.nodes.new('ShaderNodeMath')
        pulse_baseline.name = "Pulse_Add_Baseline"
        pulse_baseline.label = "Pulse + Baseline Glow"
        pulse_baseline.operation = 'ADD'
        pulse_baseline.parent = frame
        pulse_baseline.location = (x_base + 1100, y_base)
        links.new(pulse_amp.outputs['Value'], pulse_baseline.inputs[0])
        pulse_baseline.inputs[1].default_value = config.min_glow

        # 4. Dual-Tone Magic Color Gradient via Fresnel / Facing
        layer_weight = nt.nodes.new('ShaderNodeLayerWeight')
        layer_weight.name = "Magic_Layer_Weight"
        layer_weight.label = "Rim Glow Layer Weight"
        layer_weight.parent = frame
        layer_weight.location = (x_base, y_base - 380)
        layer_weight.inputs['Blend'].default_value = config.facing_blend

        color_ramp = nt.nodes.new('ShaderNodeValToRGB')
        color_ramp.name = "Magic_DualTone_Ramp"
        color_ramp.label = "Dual-Tone Magic Gradient"
        color_ramp.parent = frame
        color_ramp.location = (x_base + 240, y_base - 380)
        links.new(layer_weight.outputs['Facing'], color_ramp.inputs['Fac'])

        # Ramp: Core (Pos 0.0) -> Glancing Rim (Pos 1.0)
        color_ramp.color_ramp.elements[0].position = 0.0
        color_ramp.color_ramp.elements[0].color = config.core_color
        color_ramp.color_ramp.elements[1].position = 1.0
        color_ramp.color_ramp.elements[1].color = config.glancing_color

        emission_color = color_ramp.outputs['Color']

        # 5. Final HDR Emission Strength Multiplier
        strength_mult = nt.nodes.new('ShaderNodeMath')
        strength_mult.name = "HDR_Strength_Mult"
        strength_mult.label = f"HDR Strength ({config.base_strength:.1f})"
        strength_mult.operation = 'MULTIPLY'
        strength_mult.parent = frame
        strength_mult.location = (x_base + 1280, y_base)
        links.new(pulse_baseline.outputs['Value'], strength_mult.inputs[0])
        strength_mult.inputs[1].default_value = config.base_strength

        # If a rune / emission mask is provided, multiply it
        if rune_mask_socket is not None:
            mask_mult = nt.nodes.new('ShaderNodeMath')
            mask_mult.name = "Rune_Mask_Mult"
            mask_mult.label = "Rune Mask * Pulse"
            mask_mult.operation = 'MULTIPLY'
            mask_mult.parent = frame
            mask_mult.location = (x_base + 1460, y_base)
            links.new(strength_mult.outputs['Value'], mask_mult.inputs[0])
            links.new(rune_mask_socket, mask_mult.inputs[1])
            emission_strength = mask_mult.outputs['Value']
        else:
            emission_strength = strength_mult.outputs['Value']

        return emission_color, emission_strength

    # ------------------------------------------------------------------------
    # Complete Integrated Dark Fantasy PBR Shader Construction
    # ------------------------------------------------------------------------
    def build_complete_material(
        self,
        base_cfg: BasePBRConfig,
        ao_cfg: AmbientOcclusionConfig,
        micro_cfg: MicroRoughnessConfig,
        wetness_cfg: PuddleWetnessConfig,
        emission_cfg: Optional[EmissionPulseConfig] = None,
        use_procedural_rune_mask: bool = True
    ) -> Any:
        """
        Assembles all 4 subsystems into a unified, AAA dark fantasy Principled BSDF node graph.
        """
        self.initialize_material()
        nt = self.node_tree
        links = nt.links
        bsdf = self.bsdf_node

        # 1. Base PBR Texture / Value Setup
        base_color_node = nt.nodes.new('ShaderNodeMix')
        base_color_node.name = "Base_Color_Value"
        base_color_node.label = "Base Macro Albedo"
        base_color_node.data_type = 'RGBA'
        base_color_node.location = (-1700, 400)
        _, bc_a, bc_b, base_color_sock = get_mix_sockets(base_color_node)
        bc_a.default_value = base_cfg.base_color
        bc_b.default_value = base_cfg.base_color

        base_roughness_node = nt.nodes.new('ShaderNodeValue')
        base_roughness_node.name = "Base_Roughness_Value"
        base_roughness_node.label = "Base Macro Roughness"
        base_roughness_node.location = (-1700, 0)
        base_roughness_node.outputs['Value'].default_value = base_cfg.base_roughness
        base_roughness_sock = base_roughness_node.outputs['Value']

        base_specular_node = nt.nodes.new('ShaderNodeValue')
        base_specular_node.name = "Base_Specular_Value"
        base_specular_node.label = "Base Specular"
        base_specular_node.location = (-1700, 200)
        base_specular_node.outputs['Value'].default_value = base_cfg.specular
        base_specular_sock = base_specular_node.outputs['Value']

        # Normal Map setup
        normal_map_node = nt.nodes.new('ShaderNodeNormalMap')
        normal_map_node.name = "Normal_Map"
        normal_map_node.label = "Base Normal Map"
        normal_map_node.location = (-1700, -500)
        normal_map_node.inputs['Strength'].default_value = base_cfg.normal_strength
        # Procedural bump noise for default normal perturbation
        bump_noise = nt.nodes.new('ShaderNodeTexNoise')
        bump_noise.name = "Bump_Noise_Tex"
        bump_noise.label = "Procedural Surface Bump"
        bump_noise.location = (-1900, -500)
        links.new(self.tex_coord_node.outputs['UV'], bump_noise.inputs['Vector'])
        bump_noise.inputs['Scale'].default_value = 8.0
        bump_noise.inputs['Detail'].default_value = 5.0
        links.new(bump_noise.outputs['Fac'], normal_map_node.inputs['Color'])
        base_normal_sock = normal_map_node.outputs['Normal']

        # 2. Build Subsystem 1: Ambient Occlusion & Cavity Tinting
        occluded_albedo, occluded_specular = self.build_ambient_occlusion_network(
            ao_cfg,
            base_color_sock,
            base_specular_sock,
            x_base=-1400,
            y_base=700
        )

        # 3. Build Subsystem 2: Micro-Roughness Detail Mapping
        micro_roughness_sock = self.build_micro_roughness_network(
            micro_cfg,
            base_roughness_sock,
            x_base=-1400,
            y_base=100
        )

        # 4. Build Subsystem 3: Clearcoat / Wetness Layers for Puddles
        wet_albedo, wet_roughness, coat_weight, coat_roughness, wet_normal = self.build_puddle_wetness_network(
            wetness_cfg,
            occluded_albedo,
            micro_roughness_sock,
            base_normal_sock,
            x_base=-1400,
            y_base=-400
        )

        # 5. Build Subsystem 4: Emission Pulse Nodes for Magical Weapons
        if emission_cfg is not None:
            # Procedural rune crack mask
            if use_procedural_rune_mask:
                rune_voronoi = nt.nodes.new('ShaderNodeTexVoronoi')
                rune_voronoi.name = "Rune_Voronoi_Veins"
                rune_voronoi.label = "Arcane Rune Veins"
                rune_voronoi.feature = 'F1'
                rune_voronoi.distance = 'MANHATTAN'
                rune_voronoi.location = (-1650, -1100)
                links.new(self.tex_coord_node.outputs['UV'], rune_voronoi.inputs['Vector'])
                rune_voronoi.inputs['Scale'].default_value = 6.0

                rune_contrast = nt.nodes.new('ShaderNodeMath')
                rune_contrast.name = "Rune_Vein_Contrast"
                rune_contrast.operation = 'LESS_THAN'
                rune_contrast.location = (-1450, -1100)
                links.new(rune_voronoi.outputs['Distance'], rune_contrast.inputs[0])
                rune_contrast.inputs[1].default_value = 0.28
                rune_mask_sock = rune_contrast.outputs['Value']
            else:
                rune_mask_sock = None

            emission_color_sock, emission_strength_sock = self.build_magical_emission_pulse_network(
                emission_cfg,
                rune_mask_socket=rune_mask_sock,
                x_base=-1200,
                y_base=-1100
            )
        else:
            emission_color_sock = None
            emission_strength_sock = None

        # --------------------------------------------------------------------
        # Wire Final Sockets to Principled BSDF
        # --------------------------------------------------------------------
        # Base Color
        s_bc = resolve_bsdf_socket(bsdf, "Base Color")
        if s_bc:
            links.new(wet_albedo, s_bc)

        # Metallic
        s_met = resolve_bsdf_socket(bsdf, "Metallic")
        if s_met:
            s_met.default_value = base_cfg.metallic

        # Roughness
        s_rough = resolve_bsdf_socket(bsdf, "Roughness")
        if s_rough:
            links.new(wet_roughness, s_rough)

        # Specular
        s_spec = resolve_bsdf_socket(bsdf, "Specular")
        if s_spec:
            links.new(occluded_specular, s_spec)

        # Clearcoat / Coat Weight
        s_coat_w = resolve_bsdf_socket(bsdf, "Coat Weight")
        if s_coat_w:
            links.new(coat_weight, s_coat_w)

        # Clearcoat Roughness / Coat Roughness
        s_coat_r = resolve_bsdf_socket(bsdf, "Coat Roughness")
        if s_coat_r:
            links.new(coat_roughness, s_coat_r)

        # Normal
        s_norm = resolve_bsdf_socket(bsdf, "Normal")
        if s_norm:
            links.new(wet_normal, s_norm)

        # Emission
        if emission_cfg is not None:
            s_em_c = resolve_bsdf_socket(bsdf, "Emission Color")
            if s_em_c and emission_color_sock:
                links.new(emission_color_sock, s_em_c)

            s_em_s = resolve_bsdf_socket(bsdf, "Emission Strength")
            if s_em_s and emission_strength_sock:
                links.new(emission_strength_sock, s_em_s)

        return self.material

    # ------------------------------------------------------------------------
    # Modular Node Group Generators (Encapsulated Reusable Components)
    # ------------------------------------------------------------------------
    @staticmethod
    def create_micro_roughness_node_group(group_name: str = "PBR_MicroRoughness_Group") -> Any:
        """
        Creates an encapsulated, reusable NodeGroup for Micro-Roughness detail mapping.
        """
        ng = bpy.data.node_groups.get(group_name)
        if ng:
            bpy.data.node_groups.remove(ng)

        ng = bpy.data.node_groups.new(group_name, 'ShaderNodeTree')
        nodes = ng.nodes
        links = ng.links

        # Sockets
        add_group_socket(ng, "UV", "NodeSocketVector", 'INPUT')
        add_group_socket(ng, "Base Roughness", "NodeSocketFloat", 'INPUT', default_value=0.5, min_value=0.0, max_value=1.0)
        add_group_socket(ng, "Detail Scale", "NodeSocketFloat", 'INPUT', default_value=16.0, min_value=1.0, max_value=128.0)
        add_group_socket(ng, "Detail Intensity", "NodeSocketFloat", 'INPUT', default_value=0.35, min_value=0.0, max_value=2.0)
        add_group_socket(ng, "Detail Mask", "NodeSocketFloat", 'INPUT', default_value=1.0, min_value=0.0, max_value=1.0)
        add_group_socket(ng, "Final Roughness", "NodeSocketFloat", 'OUTPUT')

        in_node = nodes.new('NodeGroupInput')
        in_node.location = (-600, 0)
        out_node = nodes.new('NodeGroupOutput')
        out_node.location = (600, 0)

        mapping = nodes.new('ShaderNodeMapping')
        mapping.location = (-400, 0)
        links.new(in_node.outputs['UV'], mapping.inputs['Vector'])

        # Scale UV
        vec_mult = nodes.new('ShaderNodeVectorMath')
        vec_mult.operation = 'SCALE'
        vec_mult.location = (-400, 180)
        links.new(in_node.outputs['UV'], vec_mult.inputs['Vector'])
        links.new(in_node.outputs['Detail Scale'], vec_mult.inputs['Scale'])

        noise = nodes.new('ShaderNodeTexNoise')
        noise.location = (-180, 0)
        links.new(vec_mult.outputs['Vector'], noise.inputs['Vector'])
        noise.inputs['Scale'].default_value = 14.0
        noise.inputs['Detail'].default_value = 6.0

        sub = nodes.new('ShaderNodeMath')
        sub.operation = 'SUBTRACT'
        sub.location = (40, 0)
        links.new(noise.outputs['Fac'], sub.inputs[0])
        sub.inputs[1].default_value = 0.5

        scale_mult = nodes.new('ShaderNodeMath')
        scale_mult.operation = 'MULTIPLY'
        scale_mult.location = (200, 0)
        links.new(sub.outputs['Value'], scale_mult.inputs[0])
        links.new(in_node.outputs['Detail Intensity'], scale_mult.inputs[1])

        mask_mult = nodes.new('ShaderNodeMath')
        mask_mult.operation = 'MULTIPLY'
        mask_mult.location = (360, 0)
        links.new(scale_mult.outputs['Value'], mask_mult.inputs[0])
        links.new(in_node.outputs['Detail Mask'], mask_mult.inputs[1])

        add_node = nodes.new('ShaderNodeMath')
        add_node.operation = 'ADD'
        add_node.use_clamp = True
        add_node.location = (520, 0)
        links.new(in_node.outputs['Base Roughness'], add_node.inputs[0])
        links.new(mask_mult.outputs['Value'], add_node.inputs[1])

        links.new(add_node.outputs['Value'], out_node.inputs['Final Roughness'])
        return ng

    @staticmethod
    def create_puddle_wetness_node_group(group_name: str = "PBR_PuddleWetness_Group") -> Any:
        """
        Creates an encapsulated, reusable NodeGroup for Puddle / Wetness layers.
        """
        ng = bpy.data.node_groups.get(group_name)
        if ng:
            bpy.data.node_groups.remove(ng)

        ng = bpy.data.node_groups.new(group_name, 'ShaderNodeTree')
        nodes = ng.nodes
        links = ng.links

        # Sockets
        add_group_socket(ng, "Base Color", "NodeSocketColor", 'INPUT')
        add_group_socket(ng, "Roughness", "NodeSocketFloat", 'INPUT', default_value=0.5)
        add_group_socket(ng, "Normal", "NodeSocketVector", 'INPUT')
        add_group_socket(ng, "Puddle Mask", "NodeSocketFloat", 'INPUT', default_value=0.0, min_value=0.0, max_value=1.0)
        add_group_socket(ng, "Water Absorption", "NodeSocketFloat", 'INPUT', default_value=0.5, min_value=0.0, max_value=1.0)
        add_group_socket(ng, "Puddle Roughness", "NodeSocketFloat", 'INPUT', default_value=0.03, min_value=0.0, max_value=1.0)
        add_group_socket(ng, "Clearcoat Max", "NodeSocketFloat", 'INPUT', default_value=1.0, min_value=0.0, max_value=1.0)

        add_group_socket(ng, "Wet Base Color", "NodeSocketColor", 'OUTPUT')
        add_group_socket(ng, "Wet Roughness", "NodeSocketFloat", 'OUTPUT')
        add_group_socket(ng, "Coat Weight", "NodeSocketFloat", 'OUTPUT')
        add_group_socket(ng, "Coat Roughness", "NodeSocketFloat", 'OUTPUT')
        add_group_socket(ng, "Wet Normal", "NodeSocketVector", 'OUTPUT')

        in_node = nodes.new('NodeGroupInput')
        in_node.location = (-600, 0)
        out_node = nodes.new('NodeGroupOutput')
        out_node.location = (600, 0)

        # 1. Darken Base Color
        darken_mix = create_mix_node(ng, data_type='RGBA', blend_type='MULTIPLY', name="Grp_Water_Darken")
        darken_mix.location = (-200, 200)
        d_f, d_a, d_b, res_color = get_mix_sockets(darken_mix)
        links.new(in_node.outputs['Puddle Mask'], d_f)
        links.new(in_node.outputs['Base Color'], d_a)

        sub_one = nodes.new('ShaderNodeMath')
        sub_one.operation = 'SUBTRACT'
        sub_one.location = (-400, 100)
        sub_one.inputs[0].default_value = 1.0
        links.new(in_node.outputs['Water Absorption'], sub_one.inputs[1])

        # Color from absorption float
        to_col = nodes.new('ShaderNodeCombineColor')
        to_col.location = (-300, 100)
        links.new(sub_one.outputs['Value'], to_col.inputs[0])
        links.new(sub_one.outputs['Value'], to_col.inputs[1])
        links.new(sub_one.outputs['Value'], to_col.inputs[2])
        links.new(to_col.outputs['Color'], d_b)
        links.new(res_color, out_node.inputs['Wet Base Color'])

        # 2. Roughness Smoothing
        r_mix = create_mix_node(ng, data_type='FLOAT', blend_type='MIX', name="Grp_Rough_Mix")
        r_mix.location = (-200, 0)
        rf, ra, rb, res_r = get_mix_sockets(r_mix)
        links.new(in_node.outputs['Puddle Mask'], rf)
        links.new(in_node.outputs['Roughness'], ra)
        links.new(in_node.outputs['Puddle Roughness'], rb)
        links.new(res_r, out_node.inputs['Wet Roughness'])

        # 3. Coat Weight
        c_mult = nodes.new('ShaderNodeMath')
        c_mult.operation = 'MULTIPLY'
        c_mult.location = (-200, -180)
        links.new(in_node.outputs['Puddle Mask'], c_mult.inputs[0])
        links.new(in_node.outputs['Clearcoat Max'], c_mult.inputs[1])
        links.new(c_mult.outputs['Value'], out_node.inputs['Coat Weight'])

        # Coat roughness constant
        coat_r_val = nodes.new('ShaderNodeValue')
        coat_r_val.outputs['Value'].default_value = 0.03
        coat_r_val.location = (-200, -320)
        links.new(coat_r_val.outputs['Value'], out_node.inputs['Coat Roughness'])

        # 4. Normal Flattening
        n_mix = create_mix_node(ng, data_type='VECTOR', blend_type='MIX', name="Grp_Norm_Mix")
        n_mix.location = (-200, -450)
        nf, na, nb, res_n = get_mix_sockets(n_mix)
        links.new(in_node.outputs['Puddle Mask'], nf)
        links.new(in_node.outputs['Normal'], na)
        nb.default_value = (0.0, 0.0, 1.0)
        links.new(res_n, out_node.inputs['Wet Normal'])

        return ng

    @staticmethod
    def create_magical_pulse_node_group(group_name: str = "PBR_MagicalPulse_Group") -> Any:
        """
        Creates an encapsulated, reusable NodeGroup for magical weapon emission pulsing.
        """
        ng = bpy.data.node_groups.get(group_name)
        if ng:
            bpy.data.node_groups.remove(ng)

        ng = bpy.data.node_groups.new(group_name, 'ShaderNodeTree')
        nodes = ng.nodes
        links = ng.links

        # Sockets
        add_group_socket(ng, "Time", "NodeSocketFloat", 'INPUT', default_value=1.0)
        add_group_socket(ng, "Rune Mask", "NodeSocketFloat", 'INPUT', default_value=1.0, min_value=0.0, max_value=1.0)
        add_group_socket(ng, "Core Color", "NodeSocketColor", 'INPUT', default_value=(0.1, 0.95, 1.0, 1.0))
        add_group_socket(ng, "Glancing Color", "NodeSocketColor", 'INPUT', default_value=(0.65, 0.08, 0.9, 1.0))
        add_group_socket(ng, "Pulse Speed", "NodeSocketFloat", 'INPUT', default_value=2.4)
        add_group_socket(ng, "Pulse Amplitude", "NodeSocketFloat", 'INPUT', default_value=0.65)
        add_group_socket(ng, "Flicker Speed", "NodeSocketFloat", 'INPUT', default_value=12.7)
        add_group_socket(ng, "Flicker Strength", "NodeSocketFloat", 'INPUT', default_value=0.22)
        add_group_socket(ng, "Base Strength", "NodeSocketFloat", 'INPUT', default_value=25.0)

        add_group_socket(ng, "Emission Color", "NodeSocketColor", 'OUTPUT')
        add_group_socket(ng, "Emission Strength", "NodeSocketFloat", 'OUTPUT')

        in_node = nodes.new('NodeGroupInput')
        in_node.location = (-600, 0)
        out_node = nodes.new('NodeGroupOutput')
        out_node.location = (600, 0)

        # Pulse breathing sine
        t_mult = nodes.new('ShaderNodeMath')
        t_mult.operation = 'MULTIPLY'
        t_mult.location = (-400, 100)
        links.new(in_node.outputs['Time'], t_mult.inputs[0])
        links.new(in_node.outputs['Pulse Speed'], t_mult.inputs[1])

        sine = nodes.new('ShaderNodeMath')
        sine.operation = 'SINE'
        sine.location = (-240, 100)
        links.new(t_mult.outputs['Value'], sine.inputs[0])

        s_add = nodes.new('ShaderNodeMath')
        s_add.operation = 'ADD'
        s_add.location = (-80, 100)
        links.new(sine.outputs['Value'], s_add.inputs[0])
        s_add.inputs[1].default_value = 1.0

        s_norm = nodes.new('ShaderNodeMath')
        s_norm.operation = 'MULTIPLY'
        s_norm.location = (80, 100)
        links.new(s_add.outputs['Value'], s_norm.inputs[0])
        s_norm.inputs[1].default_value = 0.5

        # Jitter
        f_mult = nodes.new('ShaderNodeMath')
        f_mult.operation = 'MULTIPLY'
        f_mult.location = (-400, -100)
        links.new(in_node.outputs['Time'], f_mult.inputs[0])
        links.new(in_node.outputs['Flicker Speed'], f_mult.inputs[1])

        f_sine = nodes.new('ShaderNodeMath')
        f_sine.operation = 'SINE'
        f_sine.location = (-240, -100)
        links.new(f_mult.outputs['Value'], f_sine.inputs[0])

        f_scale = nodes.new('ShaderNodeMath')
        f_scale.operation = 'MULTIPLY'
        f_scale.location = (-80, -100)
        links.new(f_sine.outputs['Value'], f_scale.inputs[0])
        links.new(in_node.outputs['Flicker Strength'], f_scale.inputs[1])

        # Combine
        comb = nodes.new('ShaderNodeMath')
        comb.operation = 'ADD'
        comb.use_clamp = True
        comb.location = (240, 100)
        links.new(s_norm.outputs['Value'], comb.inputs[0])
        links.new(f_scale.outputs['Value'], comb.inputs[1])

        amp_mult = nodes.new('ShaderNodeMath')
        amp_mult.operation = 'MULTIPLY'
        amp_mult.location = (380, 100)
        links.new(comb.outputs['Value'], amp_mult.inputs[0])
        links.new(in_node.outputs['Pulse Amplitude'], amp_mult.inputs[1])

        str_mult = nodes.new('ShaderNodeMath')
        str_mult.operation = 'MULTIPLY'
        str_mult.location = (520, 100)
        links.new(amp_mult.outputs['Value'], str_mult.inputs[0])
        links.new(in_node.outputs['Base Strength'], str_mult.inputs[1])

        final_str = nodes.new('ShaderNodeMath')
        final_str.operation = 'MULTIPLY'
        final_str.location = (660, 100)
        links.new(str_mult.outputs['Value'], final_str.inputs[0])
        links.new(in_node.outputs['Rune Mask'], final_str.inputs[1])
        links.new(final_str.outputs['Value'], out_node.inputs['Emission Strength'])

        # Dual tone color mix
        layer_w = nodes.new('ShaderNodeLayerWeight')
        layer_w.location = (-200, 300)
        layer_w.inputs['Blend'].default_value = 0.55

        col_mix = create_mix_node(ng, data_type='RGBA', blend_type='MIX', name="Grp_Magic_Color_Mix")
        col_mix.location = (100, 300)
        cm_f, cm_a, cm_b, res_col = get_mix_sockets(col_mix)
        links.new(layer_w.outputs['Facing'], cm_f)
        links.new(in_node.outputs['Core Color'], cm_a)
        links.new(in_node.outputs['Glancing Color'], cm_b)
        links.new(res_col, out_node.inputs['Emission Color'])

        return ng


# ============================================================================
# AAA Dark Fantasy Presets
# ============================================================================

def create_magical_rune_greatsword(mat_name: str = "M_MagicalRuneGreatsword") -> Any:
    """
    Preset: Arcane Dark Fantasy Greatsword (Frost / Sorcery Rune Blade).
    - Dark weathered damascus steel (metallic 0.92, roughness 0.45)
    - Fine micro-roughness scratches (scale 24.0, intensity 0.28)
    - Deep cavity grimy AO in fuller & crossguard grooves
    - Pulsing ethereal cyan/violet arcane runes with high-speed magic flicker (strength 28.0)
    """
    builder = DarkFantasyPBRBuilder(material_name=mat_name)
    base_cfg = BasePBRConfig(
        base_color=(0.11, 0.12, 0.13, 1.0),
        metallic=0.92,
        base_roughness=0.45,
        specular=0.58,
        normal_strength=1.2
    )
    ao_cfg = AmbientOcclusionConfig(
        use_procedural_ao=True,
        ao_distance=0.40,
        ao_power=1.8,
        ao_strength=1.0,
        cavity_tint=(0.015, 0.02, 0.035, 1.0),
        cavity_tint_strength=0.75,
        specular_occlusion=0.85
    )
    micro_cfg = MicroRoughnessConfig(
        detail_scale=24.0,
        intensity=0.28,
        noise_detail=7.0,
        noise_roughness=0.75
    )
    wetness_cfg = PuddleWetnessConfig(
        water_darkening=0.35,
        puddle_roughness=0.04,
        clearcoat_max=0.6,
        clearcoat_roughness=0.03,
        puddle_threshold=0.75  # subtle dampness on blade
    )
    emission_cfg = EmissionPulseConfig(
        core_color=(0.08, 0.95, 1.0, 1.0),       # Intense frost cyan
        glancing_color=(0.68, 0.05, 0.92, 1.0),   # Arcane violet
        pulse_speed=2.6,
        pulse_amplitude=0.70,
        min_glow=0.30,
        flicker_speed=14.5,
        flicker_strength=0.25,
        base_strength=28.0
    )
    return builder.build_complete_material(base_cfg, ao_cfg, micro_cfg, wetness_cfg, emission_cfg)


def create_rainy_dungeon_stone(mat_name: str = "M_RainyDungeonStone") -> Any:
    """
    Preset: Rainy Gothic Dungeon Flagstones.
    - Weathered dark slate flagstones (metallic 0.0, roughness 0.78)
    - High-frequency micro-chisel roughness (scale 18.0, intensity 0.38)
    - Deep mortar crevices with damp mossy grime AO tint (0.03, 0.04, 0.02)
    - Standing water puddles with 52% water absorption darkening, mirror gloss 0.02,
      clearcoat 1.0, and flattened normals in water pools.
    """
    builder = DarkFantasyPBRBuilder(material_name=mat_name)
    base_cfg = BasePBRConfig(
        base_color=(0.20, 0.18, 0.16, 1.0),
        metallic=0.0,
        base_roughness=0.78,
        specular=0.45,
        normal_strength=1.4
    )
    ao_cfg = AmbientOcclusionConfig(
        use_procedural_ao=True,
        ao_distance=0.85,
        ao_power=1.7,
        ao_strength=1.0,
        cavity_tint=(0.025, 0.035, 0.02, 1.0),  # Mossy crypt dampness
        cavity_tint_strength=0.70,
        specular_occlusion=0.90
    )
    micro_cfg = MicroRoughnessConfig(
        detail_scale=18.0,
        intensity=0.38,
        noise_detail=6.0,
        noise_roughness=0.72
    )
    wetness_cfg = PuddleWetnessConfig(
        water_darkening=0.55,
        puddle_roughness=0.02,
        clearcoat_max=1.0,
        clearcoat_roughness=0.02,
        normal_flatten_factor=0.92,
        noise_scale=2.8,
        puddle_threshold=0.50,
        wet_transition_width=0.22
    )
    return builder.build_complete_material(base_cfg, ao_cfg, micro_cfg, wetness_cfg, emission_cfg=None)


def create_cursed_blood_armor(mat_name: str = "M_CursedBloodArmor") -> Any:
    """
    Preset: Cursed Knight Gothic Plate with Demonic Blood Veins.
    - Hammered blackened gothic iron (metallic 0.88, roughness 0.52)
    - Micro-hammered dents and abrasive pits (scale 20.0, intensity 0.32)
    - Crimson wet blood puddles & splatter (absorption 0.60, high clearcoat gloss 0.03)
    - Pulsing necrotic demon fire veins (fiery scarlet core into black-violet rim, strength 35.0)
    """
    builder = DarkFantasyPBRBuilder(material_name=mat_name)
    base_cfg = BasePBRConfig(
        base_color=(0.08, 0.07, 0.08, 1.0),
        metallic=0.88,
        base_roughness=0.52,
        specular=0.55,
        normal_strength=1.3
    )
    ao_cfg = AmbientOcclusionConfig(
        use_procedural_ao=True,
        ao_distance=0.50,
        ao_power=1.9,
        ao_strength=1.0,
        cavity_tint=(0.03, 0.01, 0.015, 1.0),  # Dried blood grime
        cavity_tint_strength=0.80,
        specular_occlusion=0.85
    )
    micro_cfg = MicroRoughnessConfig(
        detail_scale=20.0,
        intensity=0.32,
        noise_detail=6.5,
        noise_roughness=0.68
    )
    wetness_cfg = PuddleWetnessConfig(
        water_darkening=0.60,
        puddle_roughness=0.03,
        clearcoat_max=0.95,
        clearcoat_roughness=0.03,
        normal_flatten_factor=0.80,
        noise_scale=4.5,
        puddle_threshold=0.62
    )
    emission_cfg = EmissionPulseConfig(
        core_color=(1.0, 0.05, 0.02, 1.0),      # Demonic scarlet core
        glancing_color=(0.35, 0.0, 0.15, 1.0),  # Deep blood violet
        pulse_speed=3.2,
        pulse_amplitude=0.75,
        min_glow=0.20,
        flicker_speed=18.0,
        flicker_strength=0.30,
        base_strength=35.0
    )
    return builder.build_complete_material(base_cfg, ao_cfg, micro_cfg, wetness_cfg, emission_cfg)


def create_ancient_catacomb_gold(mat_name: str = "M_AncientCatacombGold") -> Any:
    """
    Preset: Ancient Cursed Relic / Catacomb Gilded Idol.
    - Weathered tarnished gold (metallic 0.96, roughness 0.40)
    - Micro-chisel engraving grit (scale 22.0, intensity 0.25)
    - Deep crypt dust AO shadows
    - Eerie spectral soul luminescence (spectral green core into abyssal teal rim, strength 22.0)
    """
    builder = DarkFantasyPBRBuilder(material_name=mat_name)
    base_cfg = BasePBRConfig(
        base_color=(0.68, 0.50, 0.20, 1.0),
        metallic=0.96,
        base_roughness=0.40,
        specular=0.65,
        normal_strength=1.1
    )
    ao_cfg = AmbientOcclusionConfig(
        use_procedural_ao=True,
        ao_distance=0.60,
        ao_power=1.6,
        ao_strength=1.0,
        cavity_tint=(0.04, 0.035, 0.02, 1.0),  # Tomb oxidation
        cavity_tint_strength=0.65,
        specular_occlusion=0.75
    )
    micro_cfg = MicroRoughnessConfig(
        detail_scale=22.0,
        intensity=0.25,
        noise_detail=7.0,
        noise_roughness=0.65
    )
    wetness_cfg = PuddleWetnessConfig(
        water_darkening=0.30,
        puddle_roughness=0.05,
        clearcoat_max=0.40,
        clearcoat_roughness=0.04,
        puddle_threshold=0.78
    )
    emission_cfg = EmissionPulseConfig(
        core_color=(0.15, 1.0, 0.45, 1.0),     # Soul flame green
        glancing_color=(0.02, 0.45, 0.70, 1.0), # Spectral abyssal teal
        pulse_speed=1.8,
        pulse_amplitude=0.60,
        min_glow=0.25,
        flicker_speed=9.5,
        flicker_strength=0.18,
        base_strength=22.0
    )
    return builder.build_complete_material(base_cfg, ao_cfg, micro_cfg, wetness_cfg, emission_cfg)


# ============================================================================
# Demo Scene Setup & CLI Runner
# ============================================================================

def setup_demo_showcase_scene(save_blend_path: Optional[str] = None) -> List[Any]:
    """
    Creates a cinematic dark fantasy showcase scene with 4 test objects
    demonstrating the 4 preset materials, cinematic lighting, and camera.
    """
    if not HAS_BPY:
        print("[Error] bpy is not available. Cannot create showcase scene.")
        return []

    # Reset scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "DarkFantasy_Showcase"

    # EEVEE / Cycles setup
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderEngine') else 'BLENDER_EEVEE'
    except Exception:
        pass

    presets = [
        ("Magical_Rune_Blade", create_magical_rune_greatsword("M_MagicalRuneGreatsword"), -4.5),
        ("Rainy_Dungeon_Stone", create_rainy_dungeon_stone("M_RainyDungeonStone"), -1.5),
        ("Cursed_Blood_Armor", create_cursed_blood_armor("M_CursedBloodArmor"), 1.5),
        ("Ancient_Catacomb_Gold", create_ancient_catacomb_gold("M_AncientCatacombGold"), 4.5),
    ]

    objects = []
    for name, mat, x_loc in presets:
        # Create UV sphere test geometry
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.0, location=(x_loc, 0, 1.0))
        obj = bpy.context.active_object
        obj.name = f"Showcase_{name}"

        # Shade Smooth
        try:
            bpy.ops.object.shade_smooth()
        except Exception:
            for poly in obj.data.polygons:
                poly.use_smooth = True

        # Assign Material
        if obj.data.materials:
            obj.data.materials[0] = mat
        else:
            obj.data.materials.append(mat)

        objects.append(obj)

    # Floor Plane (Wet Dungeon Floor)
    bpy.ops.mesh.primitive_plane_add(size=30.0, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.name = "Showcase_Floor"
    floor_mat = create_rainy_dungeon_stone("M_ShowcaseFloor")
    floor.data.materials.append(floor_mat)
    objects.append(floor)

    # Dark Fantasy Cinematic Lighting
    # 1. Key Rim Light (Cold moonlight blue)
    bpy.ops.object.light_add(type='SUN', location=(10, -10, 15))
    sun = bpy.context.active_object
    sun.name = "Moonlight_Sun"
    sun.data.energy = 3.5
    sun.data.color = (0.55, 0.70, 0.95)
    sun.rotation_euler = (math.radians(45), math.radians(20), math.radians(-35))

    # 2. Warm Torchlight Fill (Deep orange flame)
    bpy.ops.object.light_add(type='POINT', location=(-3, -4, 2.5))
    torch = bpy.context.active_object
    torch.name = "Dungeon_Torch_Fill"
    torch.data.energy = 150.0
    torch.data.color = (1.0, 0.45, 0.12)

    # 3. Camera
    bpy.ops.object.camera_add(location=(0, -8.5, 3.2), rotation=(math.radians(72), 0, 0))
    cam = bpy.context.active_object
    cam.name = "Showcase_Camera"
    scene.camera = cam

    # Build Reusable Node Groups as well
    DarkFantasyPBRBuilder.create_micro_roughness_node_group()
    DarkFantasyPBRBuilder.create_puddle_wetness_node_group()
    DarkFantasyPBRBuilder.create_magical_pulse_node_group()

    if save_blend_path:
        bpy.ops.wm.save_as_mainfile(filepath=save_blend_path)
        print(f"[Showcase] Saved showcase .blend scene to: {save_blend_path}")

    return objects


def main():
    """CLI runner and entry point."""
    import argparse
    parser = argparse.ArgumentParser(description="Dark Fantasy PBR Shader Node Graph Master")
    parser.add_argument("--preset", choices=["magical_greatsword", "rainy_stone", "blood_armor", "catacomb_gold", "all"], default="all")
    parser.add_argument("--save-blend", type=str, default=None, help="Save generated materials/scene to a .blend file")
    parser.add_argument("--showcase", action="store_true", help="Generate full showcase scene with test meshes and lighting")

    # If run through Blender, slice arguments after '--'
    args_list = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = parser.parse_args(args_list)

    if not HAS_BPY:
        print("[Error] This script must be run inside Blender or with bpy installed.")
        sys.exit(1)

    print("=================================================================")
    print("Dark Fantasy PBR Shader Node Graph Master (Ajan-Blender 9)")
    print(f"Blender Version: {bpy.app.version_string}")
    print("=================================================================")

    if args.showcase:
        setup_demo_showcase_scene(save_blend_path=args.save_blend)
        print("[Success] Dark Fantasy showcase scene constructed successfully.")
        return

    # Generate individual presets
    created_materials = []
    if args.preset in ("magical_greatsword", "all"):
        m = create_magical_rune_greatsword()
        created_materials.append(m)
        print(f"  [+] Created preset: {m.name}")

    if args.preset in ("rainy_stone", "all"):
        m = create_rainy_dungeon_stone()
        created_materials.append(m)
        print(f"  [+] Created preset: {m.name}")

    if args.preset in ("blood_armor", "all"):
        m = create_cursed_blood_armor()
        created_materials.append(m)
        print(f"  [+] Created preset: {m.name}")

    if args.preset in ("catacomb_gold", "all"):
        m = create_ancient_catacomb_gold()
        created_materials.append(m)
        print(f"  [+] Created preset: {m.name}")

    # Build modular node groups
    ng1 = DarkFantasyPBRBuilder.create_micro_roughness_node_group()
    ng2 = DarkFantasyPBRBuilder.create_puddle_wetness_node_group()
    ng3 = DarkFantasyPBRBuilder.create_magical_pulse_node_group()
    print(f"  [+] Created reusable node group: {ng1.name}")
    print(f"  [+] Created reusable node group: {ng2.name}")
    print(f"  [+] Created reusable node group: {ng3.name}")

    if args.save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.save_blend)
        print(f"[Success] Saved materials to: {args.save_blend}")

    print(f"[Done] Total {len(created_materials)} materials & 3 node groups constructed.")


if __name__ == "__main__":
    main()
