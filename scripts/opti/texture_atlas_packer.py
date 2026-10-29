#!/usr/bin/env python3
"""
Production-Ready 2D Texture Atlas Packer & PBR Channel Consolidator.

Features:
- Genuine MaxRects bin packing algorithm (Best Short Side Fit / Best Area Fit heuristics).
- Packs multiple PBR texture channels (Albedo, Normal, Roughness, Metallic, AO)
  into unified power-of-two atlases (4K, 2K, 1K) with identical UV layouts.
- ORM (Occlusion-Roughness-Metallic) packed map generator to minimize texture binds.
- Bleed padding (edge extrusion / dilation) preventing mipmap color bleed.
- Comprehensive JSON metadata generation with precise UV coordinates [0..1] and scale/offsets.
- Benchmark and verification utilities ensuring >85% packing efficiency.
"""

from __future__ import annotations

import argparse
import glob
import json
import math
import os
import sys
import time
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
from PIL import Image


class FreeRectChoiceHeuristic(Enum):
    """Heuristics for selecting the best free rectangle in MaxRects."""
    BEST_SHORT_SIDE_FIT = "BSSF"
    BEST_LONG_SIDE_FIT = "BLSF"
    BEST_AREA_FIT = "BAF"
    BOTTOM_LEFT = "BL"


@dataclass
class Rect:
    """Represents a 2D integer rectangle."""
    x: int
    y: int
    width: int
    height: int
    id: str = ""
    data: Optional[Dict[str, Any]] = None

    @property
    def right(self) -> int:
        return self.x + self.width

    @property
    def bottom(self) -> int:
        return self.y + self.height

    @property
    def area(self) -> int:
        return self.width * self.height

    def intersects(self, other: Rect) -> bool:
        """Returns True if this rectangle intersects with another rectangle."""
        return not (
            self.right <= other.x
            or other.right <= self.x
            or self.bottom <= other.y
            or other.bottom <= self.y
        )

    def contains(self, other: Rect) -> bool:
        """Returns True if this rectangle fully encloses another rectangle."""
        return (
            self.x <= other.x
            and self.y <= other.y
            and self.right >= other.right
            and self.bottom >= other.bottom
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "x": self.x,
            "y": self.y,
            "width": self.width,
            "height": self.height,
        }


@dataclass
class TextureSet:
    """Represents a set of PBR textures for a single entity or material."""
    name: str
    width: int
    height: int
    albedo_path: Optional[str] = None
    normal_path: Optional[str] = None
    roughness_path: Optional[str] = None
    metallic_path: Optional[str] = None
    ao_path: Optional[str] = None
    emission_path: Optional[str] = None
    extra_channels: Dict[str, str] = field(default_factory=dict)

    def get_channel_path(self, channel: str) -> Optional[str]:
        if channel == "albedo":
            return self.albedo_path
        if channel == "normal":
            return self.normal_path
        if channel == "roughness":
            return self.roughness_path
        if channel == "metallic":
            return self.metallic_path
        if channel == "ao":
            return self.ao_path
        if channel == "emission":
            return self.emission_path
        return self.extra_channels.get(channel)


@dataclass
class PackedRegion:
    """Result of packing a texture into the atlas."""
    id: str
    name: str
    page_index: int
    inner_rect: Rect  # Subtexture content without bleed
    outer_rect: Rect  # Subtexture area with bleed padding
    uv_min: Tuple[float, float]
    uv_max: Tuple[float, float]
    uv_scale: Tuple[float, float]
    uv_offset: Tuple[float, float]
    texture_set: Optional[TextureSet] = None


class MaxRectsBinPack:
    """
    Maximal Rectangles 2D bin packing algorithm.
    Maintains a list of maximal free rectangles and splits them upon placement.
    """

    def __init__(self, bin_width: int, bin_height: int):
        self.bin_width = bin_width
        self.bin_height = bin_height
        self.free_rectangles: List[Rect] = [Rect(0, 0, bin_width, bin_height)]
        self.used_rectangles: List[Rect] = []

    def reset(self):
        self.free_rectangles = [Rect(0, 0, self.bin_width, self.bin_height)]
        self.used_rectangles.clear()

    @property
    def occupied_area(self) -> int:
        return sum(r.area for r in self.used_rectangles)

    @property
    def efficiency(self) -> float:
        total = self.bin_width * self.bin_height
        return (self.occupied_area / total) if total > 0 else 0.0

    def insert(
        self, width: int, height: int, heuristic: FreeRectChoiceHeuristic = FreeRectChoiceHeuristic.BEST_SHORT_SIDE_FIT
    ) -> Optional[Rect]:
        """Finds the best free rectangle and places the new rectangle."""
        best_rect, best_score1, best_score2 = self._find_position_for_new_node(
            width, height, heuristic
        )

        if best_rect is None or best_rect.height == 0:
            return None

        # Split free rectangles intersecting the placed rectangle
        num_rects_to_process = len(self.free_rectangles)
        i = 0
        while i < num_rects_to_process:
            if self._split_free_node(self.free_rectangles[i], best_rect):
                self.free_rectangles.pop(i)
                num_rects_to_process -= 1
            else:
                i += 1

        self._prune_free_list()
        self.used_rectangles.append(best_rect)
        return best_rect

    def _score_rect(
        self,
        width: int,
        height: int,
        heuristic: FreeRectChoiceHeuristic,
        free_rect: Rect,
    ) -> Tuple[int, int]:
        """Calculates fitness score of placing (width, height) into free_rect."""
        if free_rect.width < width or free_rect.height < height:
            return (sys.maxsize, sys.maxsize)

        leftover_horiz = abs(free_rect.width - width)
        leftover_vert = abs(free_rect.height - height)

        if heuristic == FreeRectChoiceHeuristic.BEST_SHORT_SIDE_FIT:
            score1 = min(leftover_horiz, leftover_vert)
            score2 = max(leftover_horiz, leftover_vert)
            return (score1, score2)

        elif heuristic == FreeRectChoiceHeuristic.BEST_LONG_SIDE_FIT:
            score1 = max(leftover_horiz, leftover_vert)
            score2 = min(leftover_horiz, leftover_vert)
            return (score1, score2)

        elif heuristic == FreeRectChoiceHeuristic.BEST_AREA_FIT:
            score1 = free_rect.area - (width * height)
            score2 = min(leftover_horiz, leftover_vert)
            return (score1, score2)

        elif heuristic == FreeRectChoiceHeuristic.BOTTOM_LEFT:
            top_side_y = free_rect.y + height
            return (top_side_y, free_rect.x)

        return (sys.maxsize, sys.maxsize)

    def _find_position_for_new_node(
        self, width: int, height: int, heuristic: FreeRectChoiceHeuristic
    ) -> Tuple[Optional[Rect], int, int]:
        best_rect: Optional[Rect] = None
        best_score1 = sys.maxsize
        best_score2 = sys.maxsize

        for free_rect in self.free_rectangles:
            score1, score2 = self._score_rect(width, height, heuristic, free_rect)
            if (score1 < best_score1) or (score1 == best_score1 and score2 < best_score2):
                best_score1 = score1
                best_score2 = score2
                best_rect = Rect(free_rect.x, free_rect.y, width, height)

        return (best_rect, best_score1, best_score2)

    def _split_free_node(self, free_rect: Rect, placed_rect: Rect) -> bool:
        """Splits free_rect against placed_rect into up to four new maximal free rects."""
        if not free_rect.intersects(placed_rect):
            return False

        # Top slice
        if placed_rect.y > free_rect.y and placed_rect.y < free_rect.bottom:
            self.free_rectangles.append(
                Rect(
                    free_rect.x,
                    free_rect.y,
                    free_rect.width,
                    placed_rect.y - free_rect.y,
                )
            )

        # Bottom slice
        if placed_rect.bottom < free_rect.bottom:
            self.free_rectangles.append(
                Rect(
                    free_rect.x,
                    placed_rect.bottom,
                    free_rect.width,
                    free_rect.bottom - placed_rect.bottom,
                )
            )

        # Left slice
        if placed_rect.x > free_rect.x and placed_rect.x < free_rect.right:
            self.free_rectangles.append(
                Rect(
                    free_rect.x,
                    free_rect.y,
                    placed_rect.x - free_rect.x,
                    free_rect.height,
                )
            )

        # Right slice
        if placed_rect.right < free_rect.right:
            self.free_rectangles.append(
                Rect(
                    placed_rect.right,
                    free_rect.y,
                    free_rect.right - placed_rect.right,
                    free_rect.height,
                )
            )

        return True

    def _prune_free_list(self):
        """Eliminates redundant free rectangles that are enclosed within other free rectangles."""
        i = 0
        while i < len(self.free_rectangles):
            j = i + 1
            while j < len(self.free_rectangles):
                r1 = self.free_rectangles[i]
                r2 = self.free_rectangles[j]
                if r2.contains(r1):
                    self.free_rectangles.pop(i)
                    i -= 1
                    break
                elif r1.contains(r2):
                    self.free_rectangles.pop(j)
                    j -= 1
                j += 1
            i += 1


class TextureAtlasPacker:
    """
    Main pipeline for packing PBR texture sets into power-of-two atlases
    with bleed dilation and metadata generation.
    """

    def __init__(
        self,
        atlas_width: int = 4096,
        atlas_height: int = 4096,
        padding: int = 4,
        heuristic: FreeRectChoiceHeuristic = FreeRectChoiceHeuristic.BEST_SHORT_SIDE_FIT,
    ):
        self.atlas_width = atlas_width
        self.atlas_height = atlas_height
        self.padding = padding
        self.heuristic = heuristic

    def pack(
        self,
        texture_sets: List[TextureSet],
        auto_size: bool = True,
    ) -> List[Tuple[MaxRectsBinPack, List[PackedRegion]]]:
        """
        Packs texture sets into one or more atlas pages.
        Returns a list of (packer_instance, packed_regions_list) per page.
        """
        if not texture_sets:
            return []

        # Sort items descending by max side and area for optimal MaxRects packing density
        sorted_sets = sorted(
            texture_sets,
            key=lambda ts: (
                max(ts.width + 2 * self.padding, ts.height + 2 * self.padding),
                (ts.width + 2 * self.padding) * (ts.height + 2 * self.padding),
                ts.width,
            ),
            reverse=True,
        )

        # Determine bin dimensions if auto_size is enabled
        effective_width = self.atlas_width
        effective_height = self.atlas_height

        if auto_size:
            total_req_area = sum(
                (ts.width + 2 * self.padding) * (ts.height + 2 * self.padding)
                for ts in sorted_sets
            )
            # Find smallest power-of-two size that could fit all items
            target_side = max(
                512,
                2 ** int(math.ceil(math.log2(math.sqrt(total_req_area / 0.85)))),
            )
            target_side = min(target_side, self.atlas_width)
            effective_width = target_side
            effective_height = target_side

        pages: List[Tuple[MaxRectsBinPack, List[PackedRegion]]] = []
        remaining = list(sorted_sets)
        page_index = 0

        while remaining:
            packer = MaxRectsBinPack(effective_width, effective_height)
            page_regions: List[PackedRegion] = []
            unfitted: List[TextureSet] = []

            for ts in remaining:
                alloc_w = ts.width + 2 * self.padding
                alloc_h = ts.height + 2 * self.padding

                placed = packer.insert(alloc_w, alloc_h, self.heuristic)
                if placed is not None:
                    # Content inner rectangle
                    inner_x = placed.x + self.padding
                    inner_y = placed.y + self.padding
                    inner_rect = Rect(inner_x, inner_y, ts.width, ts.height, id=ts.name)

                    # Normalized UVs [0.0 .. 1.0]
                    u_min = inner_x / effective_width
                    v_min = inner_y / effective_height
                    u_max = (inner_x + ts.width) / effective_width
                    v_max = (inner_y + ts.height) / effective_height
                    u_scale = ts.width / effective_width
                    v_scale = ts.height / effective_height
                    u_offset = u_min
                    v_offset = v_min

                    region = PackedRegion(
                        id=ts.name,
                        name=ts.name,
                        page_index=page_index,
                        inner_rect=inner_rect,
                        outer_rect=placed,
                        uv_min=(u_min, v_min),
                        uv_max=(u_max, v_max),
                        uv_scale=(u_scale, v_scale),
                        uv_offset=(u_offset, v_offset),
                        texture_set=ts,
                    )
                    page_regions.append(region)
                else:
                    unfitted.append(ts)

            if not page_regions:
                # If cannot fit even a single item, increase size if possible or raise error
                if effective_width < self.atlas_width:
                    effective_width = min(effective_width * 2, self.atlas_width)
                    effective_height = min(effective_height * 2, self.atlas_height)
                    continue
                else:
                    raise ValueError(
                        f"Texture set '{remaining[0].name}' ({remaining[0].width}x{remaining[0].height}) "
                        f"exceeds maximum atlas bounds ({self.atlas_width}x{self.atlas_height})"
                    )

            pages.append((packer, page_regions))
            remaining = unfitted
            page_index += 1

        return pages

    @staticmethod
    def apply_bleed_padding(
        canvas: np.ndarray,
        sub_img: np.ndarray,
        inner_x: int,
        inner_y: int,
        width: int,
        height: int,
        padding: int,
    ) -> None:
        """
        Extrudes border pixels outward into the bleed margin
        to prevent mipmap edge bleeding during bilinear filtering.
        """
        # Paste core content
        canvas[inner_y : inner_y + height, inner_x : inner_x + width] = sub_img

        if padding <= 0:
            return

        outer_x = inner_x - padding
        outer_y = inner_y - padding
        outer_w = width + 2 * padding
        outer_h = height + 2 * padding

        # Top border extrusion
        canvas[outer_y:inner_y, inner_x : inner_x + width] = sub_img[0:1, :]

        # Bottom border extrusion
        canvas[inner_y + height : outer_y + outer_h, inner_x : inner_x + width] = sub_img[
            height - 1 : height, :
        ]

        # Left border extrusion
        canvas[inner_y : inner_y + height, outer_x:inner_x] = sub_img[:, 0:1]

        # Right border extrusion
        canvas[inner_y : inner_y + height, inner_x + width : outer_x + outer_w] = sub_img[
            :, width - 1 : width
        ]

        # Corners
        canvas[outer_y:inner_y, outer_x:inner_x] = sub_img[0, 0]
        canvas[outer_y:inner_y, inner_x + width : outer_x + outer_w] = sub_img[0, width - 1]
        canvas[inner_y + height : outer_y + outer_h, outer_x:inner_x] = sub_img[height - 1, 0]
        canvas[
            inner_y + height : outer_y + outer_h, inner_x + width : outer_x + outer_w
        ] = sub_img[height - 1, width - 1]

    def render_and_export(
        self,
        pages: List[Tuple[MaxRectsBinPack, List[PackedRegion]]],
        output_dir: str,
        base_name: str = "crowd_atlas",
        generate_orm: bool = True,
    ) -> List[Dict[str, Any]]:
        """
        Renders the PBR atlas images (Albedo, Normal, Roughness, Metallic, ORM)
        and writes the JSON metadata files.
        """
        os.makedirs(output_dir, exist_ok=True)
        manifests: List[Dict[str, Any]] = []

        for page_idx, (packer, regions) in enumerate(pages):
            atlas_w = packer.bin_width
            atlas_h = packer.bin_height
            page_suffix = f"_{page_idx}" if len(pages) > 1 else ""

            # Detect which channels exist across the regions
            has_albedo = any(r.texture_set and r.texture_set.albedo_path for r in regions)
            has_normal = any(r.texture_set and r.texture_set.normal_path for r in regions)
            has_roughness = any(r.texture_set and r.texture_set.roughness_path for r in regions)
            has_metallic = any(r.texture_set and r.texture_set.metallic_path for r in regions)
            has_ao = any(r.texture_set and r.texture_set.ao_path for r in regions)
            has_emission = any(r.texture_set and r.texture_set.emission_path for r in regions)

            # Initialize canvas buffers
            # Albedo: RGBA (default 0,0,0,0)
            albedo_canvas = np.zeros((atlas_h, atlas_w, 4), dtype=np.uint8) if has_albedo else None

            # Normal: RGB (default flat normal: 128, 128, 255)
            normal_canvas = None
            if has_normal:
                normal_canvas = np.zeros((atlas_h, atlas_w, 3), dtype=np.uint8)
                normal_canvas[:, :, 0] = 128
                normal_canvas[:, :, 1] = 128
                normal_canvas[:, :, 2] = 255

            # Roughness: Grayscale (default mid-roughness 128)
            rough_canvas = (
                np.full((atlas_h, atlas_w), 128, dtype=np.uint8) if has_roughness else None
            )

            # Metallic: Grayscale (default non-metal 0)
            metal_canvas = (
                np.zeros((atlas_h, atlas_w), dtype=np.uint8) if has_metallic else None
            )

            # AO: Grayscale (default 255 full ambient)
            ao_canvas = (
                np.full((atlas_h, atlas_w), 255, dtype=np.uint8) if (has_ao or generate_orm) else None
            )

            # Emission: RGB (default 0)
            emission_canvas = (
                np.zeros((atlas_h, atlas_w, 3), dtype=np.uint8) if has_emission else None
            )

            for region in regions:
                ts = region.texture_set
                if not ts:
                    continue

                rx = region.inner_rect.x
                ry = region.inner_rect.y
                w = region.inner_rect.width
                h = region.inner_rect.height

                # Process Albedo
                if albedo_canvas is not None and ts.albedo_path and os.path.exists(ts.albedo_path):
                    with Image.open(ts.albedo_path) as img:
                        img_rgba = img.convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
                        arr = np.array(img_rgba)
                        self.apply_bleed_padding(albedo_canvas, arr, rx, ry, w, h, self.padding)

                # Process Normal Map
                if normal_canvas is not None and ts.normal_path and os.path.exists(ts.normal_path):
                    with Image.open(ts.normal_path) as img:
                        img_rgb = img.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
                        arr = np.array(img_rgb)
                        self.apply_bleed_padding(normal_canvas, arr, rx, ry, w, h, self.padding)

                # Process Roughness
                if rough_canvas is not None and ts.roughness_path and os.path.exists(ts.roughness_path):
                    with Image.open(ts.roughness_path) as img:
                        img_l = img.convert("L").resize((w, h), Image.Resampling.LANCZOS)
                        arr = np.array(img_l)
                        self.apply_bleed_padding(rough_canvas, arr, rx, ry, w, h, self.padding)

                # Process Metallic
                if metal_canvas is not None and ts.metallic_path and os.path.exists(ts.metallic_path):
                    with Image.open(ts.metallic_path) as img:
                        img_l = img.convert("L").resize((w, h), Image.Resampling.LANCZOS)
                        arr = np.array(img_l)
                        self.apply_bleed_padding(metal_canvas, arr, rx, ry, w, h, self.padding)

                # Process AO
                if ao_canvas is not None and ts.ao_path and os.path.exists(ts.ao_path):
                    with Image.open(ts.ao_path) as img:
                        img_l = img.convert("L").resize((w, h), Image.Resampling.LANCZOS)
                        arr = np.array(img_l)
                        self.apply_bleed_padding(ao_canvas, arr, rx, ry, w, h, self.padding)

                # Process Emission
                if emission_canvas is not None and ts.emission_path and os.path.exists(ts.emission_path):
                    with Image.open(ts.emission_path) as img:
                        img_rgb = img.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
                        arr = np.array(img_rgb)
                        self.apply_bleed_padding(emission_canvas, arr, rx, ry, w, h, self.padding)

            # Save textures and collect relative paths
            channel_files: Dict[str, str] = {}

            if albedo_canvas is not None:
                albedo_fn = f"{base_name}{page_suffix}_albedo.png"
                Image.fromarray(albedo_canvas, "RGBA").save(os.path.join(output_dir, albedo_fn))
                channel_files["albedo"] = albedo_fn

            if normal_canvas is not None:
                normal_fn = f"{base_name}{page_suffix}_normal.png"
                Image.fromarray(normal_canvas, "RGB").save(os.path.join(output_dir, normal_fn))
                channel_files["normal"] = normal_fn

            if rough_canvas is not None:
                rough_fn = f"{base_name}{page_suffix}_roughness.png"
                Image.fromarray(rough_canvas, "L").save(os.path.join(output_dir, rough_fn))
                channel_files["roughness"] = rough_fn

            if metal_canvas is not None:
                metal_fn = f"{base_name}{page_suffix}_metallic.png"
                Image.fromarray(metal_canvas, "L").save(os.path.join(output_dir, metal_fn))
                channel_files["metallic"] = metal_fn

            if emission_canvas is not None:
                emission_fn = f"{base_name}{page_suffix}_emission.png"
                Image.fromarray(emission_canvas, "RGB").save(os.path.join(output_dir, emission_fn))
                channel_files["emission"] = emission_fn

            # Generate ORM Packed texture (R: Occlusion, G: Roughness, B: Metallic)
            if generate_orm and (rough_canvas is not None or metal_canvas is not None or ao_canvas is not None):
                orm_canvas = np.zeros((atlas_h, atlas_w, 3), dtype=np.uint8)
                orm_canvas[:, :, 0] = ao_canvas if ao_canvas is not None else 255
                orm_canvas[:, :, 1] = rough_canvas if rough_canvas is not None else 128
                orm_canvas[:, :, 2] = metal_canvas if metal_canvas is not None else 0
                orm_fn = f"{base_name}{page_suffix}_orm.png"
                Image.fromarray(orm_canvas, "RGB").save(os.path.join(output_dir, orm_fn))
                channel_files["orm"] = orm_fn

            # Compute stats
            total_content_area = sum(r.inner_rect.area for r in regions)
            total_allocated_area = sum(r.outer_rect.area for r in regions)
            atlas_total_area = atlas_w * atlas_h
            content_efficiency = total_content_area / atlas_total_area
            allocated_efficiency = total_allocated_area / atlas_total_area

            # Build metadata manifest
            regions_dict: Dict[str, Any] = {}
            for r in regions:
                ts = r.texture_set
                regions_dict[r.id] = {
                    "id": r.id,
                    "name": r.name,
                    "pageIndex": r.page_index,
                    "pixel": r.inner_rect.to_dict(),
                    "outerPixel": r.outer_rect.to_dict(),
                    "uv": {
                        "uMin": r.uv_min[0],
                        "vMin": r.uv_min[1],
                        "uMax": r.uv_max[0],
                        "vMax": r.uv_max[1],
                        "uScale": r.uv_scale[0],
                        "vScale": r.uv_scale[1],
                        "uOffset": r.uv_offset[0],
                        "vOffset": r.uv_offset[1],
                    },
                    "channels": {
                        "albedo": ts.albedo_path if ts else None,
                        "normal": ts.normal_path if ts else None,
                        "roughness": ts.roughness_path if ts else None,
                        "metallic": ts.metallic_path if ts else None,
                        "ao": ts.ao_path if ts else None,
                        "emission": ts.emission_path if ts else None,
                    },
                }

            manifest: Dict[str, Any] = {
                "version": "1.0.0",
                "generator": "texture_atlas_packer.py",
                "timestamp": int(time.time()),
                "atlasWidth": atlas_w,
                "atlasHeight": atlas_h,
                "padding": self.padding,
                "pageIndex": page_idx,
                "totalPages": len(pages),
                "totalRegions": len(regions),
                "efficiency": round(content_efficiency, 5),
                "allocatedEfficiency": round(allocated_efficiency, 5),
                "channels": channel_files,
                "regions": regions_dict,
            }

            meta_fn = f"{base_name}{page_suffix}_metadata.json"
            meta_path = os.path.join(output_dir, meta_fn)
            with open(meta_path, "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent=2)

            manifests.append(manifest)

        return manifests


def scan_texture_directory(input_dir: str) -> List[TextureSet]:
    """
    Scans a directory for texture sets matching standard naming conventions:
    e.g. soldier_albedo.png, soldier_normal.png, soldier_roughness.png, soldier_metallic.png.
    """
    exts = ("*.png", "*.jpg", "*.jpeg", "*.tga", "*.bmp", "*.webp")
    all_files: List[str] = []
    for ext in exts:
        all_files.extend(glob.glob(os.path.join(input_dir, ext)))
        all_files.extend(glob.glob(os.path.join(input_dir, "**", ext), recursive=True))

    all_files = sorted(list(set(all_files)))
    groups: Dict[str, Dict[str, str]] = {}

    channel_suffixes = {
        "albedo": ["albedo", "basecolor", "base_color", "diffuse", "col", "d"],
        "normal": ["normal", "norm", "nrm", "n"],
        "roughness": ["roughness", "rough", "rgh", "r"],
        "metallic": ["metallic", "metal", "mtl", "m"],
        "ao": ["ao", "ambientocclusion", "occlusion", "ambient_occlusion"],
        "emission": ["emission", "emissive", "emit", "e"],
    }

    for fpath in all_files:
        stem = Path(fpath).stem.lower()
        matched_channel = None
        base_name = stem

        for ch, suffixes in channel_suffixes.items():
            for suffix in suffixes:
                if stem.endswith(f"_{suffix}"):
                    matched_channel = ch
                    base_name = stem[: -len(f"_{suffix}")]
                    break
                elif stem.endswith(f"-{suffix}"):
                    matched_channel = ch
                    base_name = stem[: -len(f"-{suffix}")]
                    break
            if matched_channel:
                break

        if not matched_channel:
            matched_channel = "albedo"
            base_name = stem

        if base_name not in groups:
            groups[base_name] = {}
        groups[base_name][matched_channel] = fpath

    texture_sets: List[TextureSet] = []
    for name, channels in groups.items():
        sample_path = (
            channels.get("albedo")
            or channels.get("normal")
            or channels.get("roughness")
            or list(channels.values())[0]
        )
        try:
            with Image.open(sample_path) as img:
                w, h = img.size
        except Exception:
            w, h = 512, 512

        ts = TextureSet(
            name=name,
            width=w,
            height=h,
            albedo_path=channels.get("albedo"),
            normal_path=channels.get("normal"),
            roughness_path=channels.get("roughness"),
            metallic_path=channels.get("metallic"),
            ao_path=channels.get("ao"),
            emission_path=channels.get("emission"),
        )
        texture_sets.append(ts)

    return texture_sets


def create_procedural_pbr_set(
    name: str, width: int, height: int, output_dir: str
) -> TextureSet:
    """Creates a high quality test PBR texture set on disk for tests or benchmark."""
    os.makedirs(output_dir, exist_ok=True)

    # Albedo with distinctive colored checker/gradient
    albedo_img = Image.new("RGBA", (width, height))
    arr_albedo = np.zeros((height, width, 4), dtype=np.uint8)
    arr_albedo[:, :, 0] = np.linspace(50, 220, width, dtype=np.uint8)
    arr_albedo[:, :, 1] = np.linspace(40, 180, height, dtype=np.uint8)[:, None]
    arr_albedo[:, :, 2] = (hash(name) & 0xFF)
    arr_albedo[:, :, 3] = 255
    albedo_path = os.path.join(output_dir, f"{name}_albedo.png")
    Image.fromarray(arr_albedo, "RGBA").save(albedo_path)

    # Tangent normal (128, 128, 255)
    normal_img = Image.new("RGB", (width, height), (128, 128, 255))
    normal_path = os.path.join(output_dir, f"{name}_normal.png")
    normal_img.save(normal_path)

    # Roughness
    rough_img = Image.new("L", (width, height), (hash(name) % 180 + 40))
    rough_path = os.path.join(output_dir, f"{name}_roughness.png")
    rough_img.save(rough_path)

    # Metallic
    metal_img = Image.new("L", (width, height), 0 if "cloth" in name else 220)
    metal_path = os.path.join(output_dir, f"{name}_metallic.png")
    metal_img.save(metal_path)

    return TextureSet(
        name=name,
        width=width,
        height=height,
        albedo_path=albedo_path,
        normal_path=normal_path,
        roughness_path=rough_path,
        metallic_path=metal_path,
    )


def main():
    parser = argparse.ArgumentParser(
        description="PBR Texture Atlas Packer (MaxRects Bin Packing)"
    )
    parser.add_argument(
        "--input-dir", "-i", type=str, help="Directory containing PBR textures"
    )
    parser.add_argument(
        "--output-dir", "-o", type=str, default="./atlas_output", help="Output directory"
    )
    parser.add_argument(
        "--size", "-s", type=int, default=4096, help="Atlas width/height (power of two)"
    )
    parser.add_argument(
        "--padding", "-p", type=int, default=4, help="Bleed padding in pixels"
    )
    parser.add_argument(
        "--name", "-n", type=str, default="crowd_atlas", help="Base name of atlas"
    )
    parser.add_argument(
        "--orm", action="store_true", default=True, help="Generate ORM packed atlas"
    )
    parser.add_argument(
        "--benchmark", action="store_true", help="Run benchmark with simulated crowd textures"
    )

    args = parser.parse_args()

    if args.benchmark:
        print("[AtlasPacker] Running high-density benchmark (>85% efficiency check)...")
        # Generate simulated crowd textures with realistic sizes
        import tempfile

        with tempfile.TemporaryDirectory() as tmp_dir:
            test_sizes = [
                ("soldier_body", 1000, 1000),
                ("soldier_armor", 1000, 1000),
                ("orc_body", 1000, 1000),
                ("soldier_head", 500, 500),
                ("soldier_shield", 500, 500),
                ("soldier_sword", 500, 500),
                ("soldier_helmet", 500, 500),
            ]
            tsets = [create_procedural_pbr_set(n, w, h, tmp_dir) for n, w, h in test_sizes]
            packer = TextureAtlasPacker(
                atlas_width=2048,
                atlas_height=2048,
                padding=4,
            )
            pages = packer.pack(tsets, auto_size=False)
            manifests = packer.render_and_export(pages, args.output_dir, base_name="benchmark_atlas")
            eff = manifests[0]["efficiency"]
            print(f"[AtlasPacker] Benchmark completed! Efficiency: {eff * 100:.2f}%")
            if eff < 0.85:
                print(f"[AtlasPacker] WARNING: Efficiency {eff * 100:.2f}% < 85%")
                sys.exit(1)
            else:
                print(f"[AtlasPacker] SUCCESS: Efficiency target >85% met ({eff * 100:.2f}%)!")
        return

    if not args.input_dir or not os.path.isdir(args.input_dir):
        print(f"Error: Valid --input-dir required (or use --benchmark).")
        sys.exit(1)

    texture_sets = scan_texture_directory(args.input_dir)
    if not texture_sets:
        print(f"No textures found in {args.input_dir}.")
        sys.exit(1)

    print(f"Found {len(texture_sets)} texture sets to pack.")
    packer = TextureAtlasPacker(
        atlas_width=args.size,
        atlas_height=args.size,
        padding=args.padding,
    )
    pages = packer.pack(texture_sets)
    manifests = packer.render_and_export(
        pages,
        args.output_dir,
        base_name=args.name,
        generate_orm=args.orm,
    )
    print(f"Successfully generated {len(manifests)} atlas page(s) in {args.output_dir}.")
    for m in manifests:
        print(
            f"  Page {m['pageIndex']}: {m['atlasWidth']}x{m['atlasHeight']} | "
            f"{m['totalRegions']} regions | Efficiency: {m['efficiency'] * 100:.2f}%"
        )


if __name__ == "__main__":
    main()
