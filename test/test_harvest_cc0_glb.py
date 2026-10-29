#!/usr/bin/env python3
"""
test_harvest_cc0_glb.py — Unit & Integration tests for harvest_cc0_glb.py.
Verifies GLB binary parsing, SHA-256 hashing, catalog generation, and real harvested assets integrity.
"""

import os
import sys
import json
import struct
import hashlib
import unittest
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from scripts.assets.harvest_cc0_glb import (
    compute_sha256,
    parse_glb_metadata,
    CURATED_MANIFEST,
    ASSETS_MODELS_DIR,
    CATALOG_REPORT_PATH,
)


class TestHarvestCc0Glb(unittest.TestCase):
    def setUp(self):
        self.test_assets_dir = PROJECT_ROOT / "assets" / "models"
        self.catalog_path = CATALOG_REPORT_PATH

    def test_manifest_entries_coverage(self):
        """Ensure manifest covers all 4 required Aion 2 categories."""
        categories = {item["category"] for item in CURATED_MANIFEST}
        self.assertIn("characters", categories, "Missing characters category")
        self.assertIn("monsters", categories, "Missing monsters category")
        self.assertIn("weapons", categories, "Missing weapons category")
        self.assertIn("environment", categories, "Missing environment category")
        self.assertGreaterEqual(len(CURATED_MANIFEST), 30, "Manifest must contain at least 30 models")

    def test_compute_sha256(self):
        """Verify compute_sha256 computes correct checksums."""
        # Create a dummy temporary file
        temp_file = PROJECT_ROOT / "temp_sha256_test.bin"
        try:
            sample_bytes = b"glTF_Aion2_DarkFantasy_AAA_Asset_Validation_2027"
            expected_hash = hashlib.sha256(sample_bytes).hexdigest()
            with open(temp_file, "wb") as f:
                f.write(sample_bytes)
            computed_hash = compute_sha256(temp_file)
            self.assertEqual(computed_hash, expected_hash)
        finally:
            if temp_file.exists():
                temp_file.unlink()

    def test_parse_glb_metadata_synthesized(self):
        """Verify parse_glb_metadata on a synthesized binary GLB container."""
        json_content = {
            "asset": {"version": "2.0", "generator": "TestSynthesizer"},
            "accessors": [
                {"count": 36, "type": "VEC3", "componentType": 5126}, # POSITION
                {"count": 36, "type": "SCALAR", "componentType": 5123}, # INDICES
            ],
            "materials": [
                {
                    "name": "M_Obsidian_PBR",
                    "pbrMetallicRoughness": {
                        "baseColorFactor": [0.1, 0.1, 0.1, 1.0],
                        "metallicFactor": 0.9,
                        "roughnessFactor": 0.2,
                    },
                }
            ],
            "meshes": [
                {
                    "name": "CubeMesh",
                    "primitives": [
                        {
                            "attributes": {"POSITION": 0},
                            "indices": 1,
                            "material": 0,
                        }
                    ],
                }
            ],
        }
        json_bytes = json.dumps(json_content).encode("utf-8")
        # Pad JSON to 4-byte boundary
        pad = (4 - (len(json_bytes) % 4)) % 4
        json_bytes += b" " * pad

        header_len = 12
        chunk0_len = 8 + len(json_bytes)
        total_len = header_len + chunk0_len

        glb_bytes = bytearray()
        glb_bytes.extend(struct.pack("<III", 0x46546C67, 2, total_len))
        glb_bytes.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        glb_bytes.extend(json_bytes)

        temp_glb = PROJECT_ROOT / "temp_synth_test.glb"
        try:
            with open(temp_glb, "wb") as f:
                f.write(glb_bytes)

            meta = parse_glb_metadata(temp_glb)
            self.assertEqual(meta["vertex_count"], 36)
            self.assertEqual(meta["triangle_count"], 12)
            self.assertEqual(meta["material_count"], 1)
            self.assertIn("M_Obsidian_PBR", meta["material_names"])
        finally:
            if temp_glb.exists():
                temp_glb.unlink()

    def test_real_harvested_assets_exist_and_valid(self):
        """Verify that all manifest assets exist in assets/models and are valid GLB files."""
        for entry in CURATED_MANIFEST:
            target_path = self.test_assets_dir / entry["local_subpath"]
            self.assertTrue(target_path.exists(), f"Asset file missing: {target_path}")
            self.assertGreater(target_path.stat().st_size, 0, f"Asset file empty: {target_path}")

            with open(target_path, "rb") as f:
                magic = f.read(4)
            self.assertEqual(magic, b"glTF", f"Invalid glTF magic in {target_path}")

            meta = parse_glb_metadata(target_path)
            self.assertGreater(meta["vertex_count"], 0, f"Vertex count must be > 0 for {target_path.name}")
            self.assertGreater(meta["triangle_count"], 0, f"Triangle count must be > 0 for {target_path.name}")

    def test_catalog_report_completeness(self):
        """Verify that reports/assets/harvested_glb_catalog.md exists and contains required sections."""
        self.assertTrue(self.catalog_path.exists(), f"Catalog report missing: {self.catalog_path}")
        content = self.catalog_path.read_text(encoding="utf-8")

        self.assertIn("Aion 2 Dark/High-Fantasy 3D Model Catalog", content)
        self.assertIn("Winged Fantasy Warrior & Knight Characters", content)
        self.assertIn("Dragon Boss & Gargoyle Monsters", content)
        self.assertIn("High-Fantasy Weapons", content)
        self.assertIn("Gothic Stone Ruins, Dungeon Braziers & Ornate Treasure Chests", content)
        self.assertIn("Cryptographic Verification Manifest (SHA-256)", content)
        self.assertIn("100% CC0 / Commercial Free", content)
        self.assertIn("DragonAttenuation.glb", content)
        self.assertIn("KnightCharacter.glb", content)
        self.assertIn("Claymore.glb", content)
        self.assertIn("dungeon_warkarma.glb", content)


if __name__ == "__main__":
    unittest.main()
