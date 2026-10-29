#!/usr/bin/env python3
"""
test_monsters_undead_glb.py — Verification & Quality Assurance Suite for Undead Monster 3D Models.
Validates genuine CC0 GLB assets for skeleton_warrior, skeleton_archer, skeleton_mage, zombie, and ghost.
Strict veto on primitive geometry (cubes, spheres, cylinders).
"""

import hashlib
import json
import os
import struct
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MONSTERS_DIR = PROJECT_ROOT / "assets" / "models" / "monsters"

EXPECTED_UNDEAD_MODELS = {
    "skeleton_warrior.glb": {
        "min_size": 1_000_000,
        "min_verts": 5000,
        "min_tris": 5000,
        "expected_sha256": "178b6fda810b814c250d8a2010c24dfd9b458b9006dd323353e620b7ff118bbe",
        "creator": "Kay Lousberg (KayKit)",
        "license": "CC0 1.0 Universal",
    },
    "skeleton_archer.glb": {
        "min_size": 1_000_000,
        "min_verts": 5000,
        "min_tris": 5000,
        "expected_sha256": "4003f2b77891bb56f7e0de7d555abcb497aebbcaee35b614211f16275f9ccae3",
        "creator": "Kay Lousberg (KayKit)",
        "license": "CC0 1.0 Universal",
    },
    "skeleton_mage.glb": {
        "min_size": 1_000_000,
        "min_verts": 4000,
        "min_tris": 4000,
        "expected_sha256": "e05b0f5cfa395271c9f75fd07c0a0613c56f401ece4ab644e080001a79971075",
        "creator": "Kay Lousberg (KayKit)",
        "license": "CC0 1.0 Universal",
    },
    "zombie.glb": {
        "min_size": 50_000,
        "min_verts": 1000,
        "min_tris": 1000,
        "expected_sha256": "1a49bedce8647de542bfaaa796a3b533ab2a0d2567122bd08b16b2741fa62693",
        "creator": "Kenney",
        "license": "CC0 1.0 Universal",
    },
    "ghost.glb": {
        "min_size": 50_000,
        "min_verts": 500,
        "min_tris": 400,
        "expected_sha256": "d4334bc0c7c0ca27924e238b47fe5b0984f4f6bbaeaa55f7e75d0287e8935895",
        "creator": "Kenney",
        "license": "CC0 1.0 Universal",
    },
}


class TestUndeadMonstersGlb(unittest.TestCase):
    def test_all_models_exist(self):
        """Verify that all target undead monster models exist on disk."""
        for filename in EXPECTED_UNDEAD_MODELS:
            path = MONSTERS_DIR / filename
            self.assertTrue(path.exists(), f"Missing undead model: {path}")
            self.assertGreater(path.stat().st_size, 10_000, f"Model file suspiciously small: {filename}")

    def test_glb_headers_and_checksums(self):
        """Verify binary GLB magic header, version 2, and SHA-256 integrity."""
        for filename, info in EXPECTED_UNDEAD_MODELS.items():
            path = MONSTERS_DIR / filename
            with open(path, "rb") as f:
                data = f.read()

            # Magic header & version
            self.assertEqual(data[:4], b"glTF", f"{filename} does not start with b'glTF'")
            magic, version, length = struct.unpack("<III", data[:12])
            self.assertEqual(version, 2, f"{filename} glTF version must be 2")
            self.assertEqual(length, len(data), f"{filename} container length mismatch")

            # SHA-256 check
            calculated_hash = hashlib.sha256(data).hexdigest()
            self.assertEqual(
                calculated_hash,
                info["expected_sha256"],
                f"SHA-256 checksum mismatch for {filename}",
            )

    def test_mesh_complexity_and_primitive_veto(self):
        """Ensure genuine high-quality 3D geometry with strict veto on primitives."""
        for filename, info in EXPECTED_UNDEAD_MODELS.items():
            path = MONSTERS_DIR / filename
            with open(path, "rb") as f:
                data = f.read()

            chunk_len, chunk_type = struct.unpack("<II", data[12:20])
            self.assertEqual(chunk_type, 0x4E4F534A, f"{filename} first chunk is not JSON")
            gltf = json.loads(data[20 : 20 + chunk_len].decode("utf-8"))

            accessors = gltf.get("accessors", [])
            meshes = gltf.get("meshes", [])
            self.assertGreater(len(meshes), 0, f"{filename} has no meshes")

            total_verts = 0
            total_tris = 0
            for m in meshes:
                for p in m.get("primitives", []):
                    pos_idx = p.get("attributes", {}).get("POSITION")
                    if pos_idx is not None and pos_idx < len(accessors):
                        total_verts += accessors[pos_idx].get("count", 0)

                    idx_accessor = p.get("indices")
                    if idx_accessor is not None and idx_accessor < len(accessors):
                        total_tris += accessors[idx_accessor].get("count", 0) // 3
                    elif pos_idx is not None and pos_idx < len(accessors):
                        total_tris += accessors[pos_idx].get("count", 0) // 3

            self.assertGreaterEqual(
                total_verts,
                info["min_verts"],
                f"{filename} vertices ({total_verts}) below minimum threshold ({info['min_verts']})",
            )
            self.assertGreaterEqual(
                total_tris,
                info["min_tris"],
                f"{filename} triangles ({total_tris}) below minimum threshold ({info['min_tris']})",
            )

            # Strict veto: Primitive cubes have only 8-36 vertices and 12 triangles.
            # Undead models must exceed standard primitive thresholds by orders of magnitude.
            self.assertGreater(total_verts, 100, f"{filename} resembles primitive geometry!")
            self.assertGreater(total_tris, 100, f"{filename} resembles primitive geometry!")

    def test_animations_and_materials_present(self):
        """Verify models contain authentic animation tracks and textured materials."""
        for filename in EXPECTED_UNDEAD_MODELS:
            path = MONSTERS_DIR / filename
            with open(path, "rb") as f:
                data = f.read()
            chunk_len, _ = struct.unpack("<II", data[12:20])
            gltf = json.loads(data[20 : 20 + chunk_len].decode("utf-8"))

            animations = gltf.get("animations", [])
            materials = gltf.get("materials", [])

            self.assertGreater(len(materials), 0, f"{filename} must have at least one PBR material")
            self.assertGreater(len(animations), 0, f"{filename} must include rigged character animations")


if __name__ == "__main__":
    unittest.main()
