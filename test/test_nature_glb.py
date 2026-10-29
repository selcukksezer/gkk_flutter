#!/usr/bin/env python3
"""
test_nature_glb.py — Verification test suite for CC0 environment nature models.
Verifies file existence, GLB binary headers, >10KB size constraints, and real mesh data.
"""

import os
import sys
import json
import struct
import hashlib
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from scripts.harvest_nature_glb import parse_glb_metadata, CURATED_NATURE_MODELS


class TestNatureGlbAssets(unittest.TestCase):
    def setUp(self):
        self.env_dir = PROJECT_ROOT / "assets" / "models" / "environment"
        self.required_models = [
            "pine_tree.glb",
            "oak_tree.glb",
            "rock_boulder.glb",
            "cliff.glb",
            "grass_clump.glb",
        ]

    def test_all_target_models_exist(self):
        """Verify all 5 required environment nature models exist in assets/models/environment/."""
        for filename in self.required_models:
            model_path = self.env_dir / filename
            self.assertTrue(
                model_path.exists(),
                f"Missing required model: {filename} at {model_path}"
            )
            self.assertTrue(
                model_path.is_file(),
                f"Path is not a regular file: {model_path}"
            )

    def test_model_file_sizes_exceed_10kb(self):
        """Verify each model exceeds 10KB (>10,240 bytes) and is not empty or truncated."""
        for filename in self.required_models:
            model_path = self.env_dir / filename
            size = model_path.stat().st_size
            self.assertGreater(
                size,
                10240,
                f"Model {filename} size ({size} bytes) is not > 10KB"
            )

    def test_glb_binary_magic_and_version(self):
        """Verify GLB file structure conforms to glTF 2.0 binary standard."""
        for filename in self.required_models:
            model_path = self.env_dir / filename
            with open(model_path, "rb") as f:
                data = f.read()

            self.assertGreaterEqual(len(data), 12, f"{filename} header too short")
            magic, version, length = struct.unpack("<4sII", data[:12])
            self.assertEqual(magic, b"glTF", f"{filename} does not have 'glTF' magic bytes")
            self.assertEqual(version, 2, f"{filename} is not glTF version 2")
            self.assertEqual(length, len(data), f"{filename} length header does not match file size")

    def test_real_mesh_geometry_presence(self):
        """Verify models contain genuine non-zero vertex counts and triangle faces."""
        for filename in self.required_models:
            model_path = self.env_dir / filename
            with open(model_path, "rb") as f:
                data = f.read()

            version, verts, tris, meta = parse_glb_metadata(data)
            self.assertGreater(verts, 100, f"{filename} has insufficient vertices ({verts})")
            self.assertGreater(tris, 50, f"{filename} has insufficient triangles ({tris})")
            self.assertIn("meshes", meta, f"{filename} missing meshes property")
            self.assertGreaterEqual(len(meta["meshes"]), 1, f"{filename} has no meshes")

    def test_not_html_or_error_page(self):
        """Verify models are not accidentally downloaded HTML 404 or error pages."""
        for filename in self.required_models:
            model_path = self.env_dir / filename
            with open(model_path, "rb") as f:
                lead_bytes = f.read(64).lower()

            self.assertNotIn(b"<!doctype html>", lead_bytes)
            self.assertNotIn(b"<html", lead_bytes)
            self.assertNotIn(b"404: not found", lead_bytes)
            self.assertNotIn(b"rate limit", lead_bytes)

    def test_sha256_checksum_validity(self):
        """Verify all models produce valid, non-trivial SHA-256 checksums."""
        hashes = set()
        for filename in self.required_models:
            model_path = self.env_dir / filename
            with open(model_path, "rb") as f:
                digest = hashlib.sha256(f.read()).hexdigest()
            self.assertEqual(len(digest), 64)
            hashes.add(digest)
        # Verify all 5 models are distinct unique assets
        self.assertEqual(len(hashes), 5, "Expected 5 distinct models with unique SHA-256 hashes")


if __name__ == "__main__":
    unittest.main()
