#!/usr/bin/env python3
"""
harvest_nature_glb.py
Downloads and verifies genuine CC0 environment nature models for assets/models/environment/.
Extracts GLB binary headers, vertex counts, triangle counts, and SHA-256 checksums.
"""

import os
import sys
import json
import struct
import hashlib
import urllib.request
from pathlib import Path

# Paths
WORKSPACE = Path(__file__).resolve().parent.parent
TARGET_DIR = WORKSPACE / "assets" / "models" / "environment"

# Curated genuine CC0 sources for target models (>10KB, verified mesh data)
CURATED_NATURE_MODELS = {
    "pine_tree.glb": {
        "url": "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/public/glb/nature_pack/PineTree_1.glb",
        "creator": "Quaternius (CC0 Nature Pack)",
        "description": "Dense evergreen coniferous pine tree with tiered needle canopy and wooden trunk.",
    },
    "oak_tree.glb": {
        "url": "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/public/glb/nature_pack/CommonTree_1.glb",
        "creator": "Quaternius (CC0 Nature Pack)",
        "description": "Mature deciduous oak tree with broad branching foliage canopy and bark trunk.",
    },
    "rock_boulder.glb": {
        "url": "https://raw.githubusercontent.com/shorepine/kenney/main/3d/tower-defense/detail-rocks-large.glb",
        "creator": "Kenney (CC0 Game Assets)",
        "description": "Cluster of large natural weathered rock boulders with multifaceted stony planar faces.",
    },
    "cliff.glb": {
        "url": "https://raw.githubusercontent.com/shorepine/kenney/main/3d/graveyard/rocks-tall.glb",
        "creator": "Kenney (CC0 Game Assets)",
        "description": "Towering vertical rocky cliff formation with stratified stone outcrops and crags.",
    },
    "grass_clump.glb": {
        "url": "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/public/glb/nature_pack/Grass.glb",
        "creator": "Quaternius (CC0 Nature Pack)",
        "description": "Tufted cluster of wild green grass blades arranged for terrain ground foliage.",
    },
}


def parse_glb_metadata(data: bytes):
    """Parses binary GLB and returns (version, total_verts, total_triangles, json_meta)."""
    if len(data) < 12:
        raise ValueError("Data too short for GLB header")
    magic, version, length = struct.unpack("<4sII", data[:12])
    if magic != b"glTF":
        raise ValueError(f"Invalid magic: {magic}")
    
    offset = 12
    json_chunk_data = None
    bin_chunk_data = None

    while offset < len(data):
        chunk_len, chunk_type = struct.unpack("<I4s", data[offset:offset+8])
        chunk_data = data[offset+8:offset+8+chunk_len]
        if chunk_type == b"JSON":
            json_chunk_data = chunk_data
        elif chunk_type == b"BIN\x00":
            bin_chunk_data = chunk_data
        offset += 8 + chunk_len

    if not json_chunk_data:
        raise ValueError("No JSON chunk in GLB")

    meta = json.loads(json_chunk_data.decode("utf-8"))
    accessors = meta.get("accessors", [])
    meshes = meta.get("meshes", [])

    total_vertices = 0
    total_triangles = 0

    for mesh in meshes:
        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            if "POSITION" in attrs:
                pos_acc_idx = attrs["POSITION"]
                if pos_acc_idx < len(accessors):
                    total_vertices += accessors[pos_acc_idx].get("count", 0)
            
            if "indices" in prim:
                idx_acc_idx = prim["indices"]
                if idx_acc_idx < len(accessors):
                    count = accessors[idx_acc_idx].get("count", 0)
                    total_triangles += count // 3
            elif "POSITION" in attrs:
                pos_acc_idx = attrs["POSITION"]
                if pos_acc_idx < len(accessors):
                    count = accessors[pos_acc_idx].get("count", 0)
                    total_triangles += count // 3

    return version, total_vertices, total_triangles, meta


def harvest_nature_models():
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    manifest_results = []

    for filename, info in CURATED_NATURE_MODELS.items():
        url = info["url"]
        print(f"Fetching {filename} from {url}...")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = resp.read()

        size = len(data)
        version, verts, tris, meta = parse_glb_metadata(data)
        sha256 = hashlib.sha256(data).hexdigest()

        if size <= 10240:
            raise ValueError(f"Model {filename} size {size} is not > 10KB")
        if verts <= 0:
            raise ValueError(f"Model {filename} has 0 vertices")

        dest_path = TARGET_DIR / filename
        with open(dest_path, "wb") as f:
            f.write(data)

        entry = {
            "filename": filename,
            "path": str(dest_path.relative_to(WORKSPACE)),
            "size_bytes": size,
            "version": version,
            "vertices": verts,
            "triangles": tris,
            "sha256": sha256,
            "url": url,
            "creator": info["creator"],
            "description": info["description"],
        }
        manifest_results.append(entry)
        print(f"  [OK] Saved {filename} ({size} bytes, {verts} verts, {tris} tris, v{version})")

    return manifest_results


if __name__ == "__main__":
    results = harvest_nature_models()
    print("\n--- NATURE ASSETS HARVEST COMPLETE ---")
    print(json.dumps(results, indent=2))
