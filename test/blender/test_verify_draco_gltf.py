"""
Unit and Integration Test Suite for Draco Compression & GLTF/GLB Verification Pipeline
======================================================================================
Tests verify:
1. Binary GLB header parsing (12-byte magic, version, lengths).
2. Binary chunk extraction (JSON chunk 0x4E4F534A, BIN chunk 0x004E4942, 4-byte alignment).
3. Draco bitstream header validation (DRACO magic, version, TriangularMesh, Edgebreaker).
4. Mesh uncompressed byte calculation & compression ratio precision.
5. 5-Channel PBR texture set validation (Albedo, Normal, Roughness, Metallic, Emission).
6. 4-Tier LOD hierarchy inspection (LOD0, LOD1, LOD2, Impostor) across intra-GLB and multi-file.
7. End-to-end verification across real assets in assets/models/props/.
"""

import json
import os
import struct
import sys
import unittest
from pathlib import Path

# Add scripts directory to path
SCRIPTS_DIR = Path(__file__).resolve().parent.parent.parent / "scripts" / "blender"
sys.path.insert(0, str(SCRIPTS_DIR))

from verify_draco_gltf import (
    DracoGLTFVerifier,
    GLB_MAGIC,
    GLB_VERSION_2,
    CHUNK_TYPE_JSON,
    CHUNK_TYPE_BIN,
    DRACO_MAGIC,
    DRACO_ENCODER_TRIANGULAR_MESH,
    DRACO_METHOD_EDGEBREAKER,
    GLBChunk,
    AssetReport,
)


class TestDracoGLTFVerifier(unittest.TestCase):
    """Test suite for DracoGLTFVerifier."""

    def setUp(self):
        self.verifier = DracoGLTFVerifier(verbose=False)
        self.props_dir = Path("assets/models/props")

    def create_mock_glb(
        self,
        json_obj: dict,
        bin_payload: bytes = b"",
        corrupt_magic: bool = False
    ) -> bytes:
        """Helper to construct a valid binary GLB byte array."""
        json_bytes = json.dumps(json_obj).encode("utf-8")
        # Align JSON to 4 bytes with spaces
        json_pad = (4 - (len(json_bytes) % 4)) % 4
        json_bytes += b" " * json_pad

        # Align BIN to 4 bytes with zeros
        bin_pad = (4 - (len(bin_payload) % 4)) % 4
        bin_bytes = bin_payload + b"\x00" * bin_pad

        total_length = 12 + 8 + len(json_bytes)
        if bin_bytes:
            total_length += 8 + len(bin_bytes)

        magic = b"XXXX" if corrupt_magic else GLB_MAGIC
        header = struct.pack("<4sII", magic, GLB_VERSION_2, total_length)

        # Chunk 0: JSON
        c0_hdr = struct.pack("<II", len(json_bytes), CHUNK_TYPE_JSON)
        glb_data = header + c0_hdr + json_bytes

        # Chunk 1: BIN
        if bin_bytes:
            c1_hdr = struct.pack("<II", len(bin_bytes), CHUNK_TYPE_BIN)
            glb_data += c1_hdr + bin_bytes

        return glb_data

    # ========================================================================
    # 1. Binary GLB Parsing Tests
    # ========================================================================

    def test_parse_valid_glb_header_and_chunks(self):
        """Test parsing valid 12-byte header and both JSON and BIN chunks."""
        json_obj = {"asset": {"version": "2.0"}}
        bin_payload = b"\x01\x02\x03\x04"
        glb_bytes = self.create_mock_glb(json_obj, bin_payload)

        version, length, chunks = self.verifier.parse_glb_header_and_chunks(glb_bytes, "test.glb")
        self.assertEqual(version, 2)
        self.assertEqual(length, len(glb_bytes))
        self.assertEqual(len(chunks), 2)
        self.assertEqual(chunks[0].chunk_type_int, CHUNK_TYPE_JSON)
        self.assertEqual(chunks[0].chunk_type_str, "JSON")
        self.assertEqual(chunks[1].chunk_type_int, CHUNK_TYPE_BIN)
        self.assertEqual(chunks[1].chunk_type_str, "BIN")
        self.assertEqual(chunks[0].offset % 4, 0)
        self.assertEqual(chunks[1].offset % 4, 0)

    def test_parse_corrupt_magic_raises_error(self):
        """Test rejection of files with invalid GLB magic header."""
        glb_bytes = self.create_mock_glb({"asset": {"version": "2.0"}}, corrupt_magic=True)
        with self.assertRaises(ValueError) as ctx:
            self.verifier.parse_glb_header_and_chunks(glb_bytes, "test.glb")
        self.assertIn("Invalid GLB magic", str(ctx.exception))

    def test_parse_truncated_file_raises_error(self):
        """Test rejection of truncated or undersized GLB files."""
        with self.assertRaises(ValueError) as ctx:
            self.verifier.parse_glb_header_and_chunks(b"glTF\x02\x00\x00\x00", "test.glb")
        self.assertIn("File too small", str(ctx.exception))

    # ========================================================================
    # 2. Draco Bitstream Inspection Tests
    # ========================================================================

    def test_inspect_draco_bitstream_header(self):
        """Test decoding valid Draco 11-byte bitstream header."""
        # DRACO (5 bytes), major=2, minor=2, enc_type=1 (mesh), enc_method=1 (edgebreaker), flags=0
        draco_header = b"DRACO\x02\x02\x01\x01\x00\x00" + b"\xFF" * 20
        info = self.verifier.inspect_draco_bitstream(draco_header)

        self.assertIsNotNone(info)
        self.assertEqual(info.magic, DRACO_MAGIC)
        self.assertEqual(info.major_version, 2)
        self.assertEqual(info.minor_version, 2)
        self.assertEqual(info.encoder_type, DRACO_ENCODER_TRIANGULAR_MESH)
        self.assertEqual(info.encoder_type_name, "TriangularMesh")
        self.assertEqual(info.encoder_method, DRACO_METHOD_EDGEBREAKER)
        self.assertEqual(info.encoder_method_name, "Edgebreaker")
        self.assertEqual(info.flags, 0)

    def test_inspect_invalid_draco_header_returns_none(self):
        """Test that non-Draco payload returns None."""
        invalid_bytes = b"NOT_DRACO_HEADER_DATA"
        info = self.verifier.inspect_draco_bitstream(invalid_bytes)
        self.assertIsNone(info)

    # ========================================================================
    # 3. Uncompressed Size & Compression Ratio Math Tests
    # ========================================================================

    def test_calculate_uncompressed_mesh_size(self):
        """Test accurate calculation of uncompressed vertex attribute and index buffers."""
        gltf_json = {
            "accessors": [
                {"count": 100, "componentType": 5126, "type": "VEC3"},  # POSITION: 100*4*3 = 1200 B
                {"count": 100, "componentType": 5126, "type": "VEC3"},  # NORMAL: 100*4*3 = 1200 B
                {"count": 100, "componentType": 5126, "type": "VEC2"},  # TEXCOORD: 100*4*2 = 800 B
                {"count": 300, "componentType": 5123, "type": "SCALAR"}, # INDICES: 300*2*1 = 600 B
            ]
        }
        primitive = {
            "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
            "indices": 3,
        }
        uncompressed = self.verifier.calculate_uncompressed_mesh_size(gltf_json, primitive)
        expected = 1200 + 1200 + 800 + 600  # 3800 bytes
        self.assertEqual(uncompressed, expected)

    def test_compression_ratio_accuracy(self):
        """Test compression ratio and space savings calculation."""
        uncompressed = 10000
        compressed = 2500
        ratio = uncompressed / compressed
        savings = (1.0 - compressed / uncompressed) * 100.0

        self.assertAlmostEqual(ratio, 4.0, places=2)
        self.assertAlmostEqual(savings, 75.0, places=1)

    # ========================================================================
    # 4. PBR Material Inspection Tests
    # ========================================================================

    def test_pbr_material_channels_detection(self):
        """Test validation of Albedo, Normal, Roughness, Metallic, and Emission channels."""
        gltf_json = {
            "textures": [{"source": 0}, {"source": 1}, {"source": 2}, {"source": 3}],
            "images": [
                {"name": "Albedo_Map", "uri": "albedo.png"},
                {"name": "Normal_Map", "uri": "normal.png"},
                {"name": "MR_Map", "uri": "mr.png"},
                {"name": "Emiss_Map", "uri": "emiss.png"},
            ],
            "materials": [
                {
                    "name": "M_HeroDarkFantasy",
                    "pbrMetallicRoughness": {
                        "baseColorTexture": {"index": 0},
                        "metallicRoughnessTexture": {"index": 2},
                        "roughnessFactor": 0.85,
                        "metallicFactor": 0.1,
                    },
                    "normalTexture": {"index": 1, "scale": 1.0},
                    "emissiveTexture": {"index": 3},
                    "extensions": {
                        "KHR_materials_emissive_strength": {"emissiveStrength": 10.0}
                    },
                    "doubleSided": True,
                }
            ],
        }

        reports = self.verifier.inspect_pbr_materials(gltf_json, Path("."), "Hero")
        self.assertEqual(len(reports), 1)
        mat = reports[0]
        self.assertEqual(mat.name, "M_HeroDarkFantasy")
        self.assertTrue(mat.all_5_channels_supported)
        self.assertEqual(mat.channels["Albedo"].status, "PASS_MAP")
        self.assertEqual(mat.channels["Normal"].status, "PASS_MAP")
        self.assertEqual(mat.channels["Roughness"].status, "PASS_MAP")
        self.assertEqual(mat.channels["Metallic"].status, "PASS_MAP")
        self.assertEqual(mat.channels["Emission"].status, "PASS_MAP")
        self.assertEqual(mat.emissive_strength, 10.0)

    # ========================================================================
    # 5. LOD Hierarchy Inspection Tests
    # ========================================================================

    def test_lod_hierarchy_intra_glb(self):
        """Test detection of 4-tier LOD hierarchy in intra-GLB nodes."""
        gltf_json = {
            "nodes": [
                {"name": "Gargoyle_LOD0"},
                {"name": "Gargoyle_LOD1"},
                {"name": "Gargoyle_LOD2"},
                {"name": "Gargoyle_Impostor"},
            ],
            "meshes": [{"name": "Mesh_LOD0"}],
        }
        lod_report = self.verifier.inspect_lod_hierarchy(gltf_json, Path("Gargoyle_MultiLOD.glb"))
        self.assertTrue(lod_report.lod0_found)
        self.assertTrue(lod_report.lod1_found)
        self.assertTrue(lod_report.lod2_found)
        self.assertTrue(lod_report.impostor_found)
        self.assertTrue(lod_report.is_complete_4_tier)
        self.assertEqual(lod_report.hierarchy_type, "intra_glb")

    # ========================================================================
    # 6. Real Assets End-to-End Verification Tests
    # ========================================================================

    def test_verify_real_asset_gargoyle(self):
        """Test verification on real exported asset: Gargoyle_DarkStone_LOD0.glb."""
        gargoyle_path = self.props_dir / "Gargoyle_DarkStone_LOD0.glb"
        if not gargoyle_path.exists():
            self.skipTest(f"Asset file not found: {gargoyle_path}")

        report = self.verifier.verify_asset(gargoyle_path)
        self.assertTrue(report.is_valid_glb)
        self.assertTrue(report.draco_in_extensions_used)
        self.assertTrue(report.draco_in_extensions_required)
        self.assertGreater(len(report.draco_buffers), 0)
        self.assertTrue(all(b.is_valid_draco for b in report.draco_buffers))
        self.assertGreater(report.compression.compression_ratio, 3.0)
        self.assertTrue(report.pbr_complete)
        self.assertTrue(report.lod.is_complete_4_tier)
        self.assertEqual(report.verdict, "PASS")

    def test_verify_all_models_in_props_directory(self):
        """Audits all GLB models in assets/models/props and validates full pass rate."""
        if not self.props_dir.exists():
            self.skipTest(f"Props directory not found: {self.props_dir}")

        reports = self.verifier.verify_directory(self.props_dir)
        self.assertGreaterEqual(len(reports), 6)

        # All models must possess valid Draco compression
        for r in reports:
            self.assertTrue(r.is_valid_glb, f"{r.filename} is not valid GLB")
            self.assertTrue(r.draco_in_extensions_used, f"{r.filename} missing draco used")
            self.assertTrue(
                all(b.is_valid_draco for b in r.draco_buffers),
                f"{r.filename} has invalid Draco buffer"
            )
            self.assertGreater(r.compression.compression_ratio, 0.7)

        # Markdown report generation must succeed
        report_md = self.verifier.generate_markdown_report(reports)
        self.assertIn("# Draco Compression & GLTF/GLB Verification Report", report_md)
        self.assertIn("Global Mesh Compression Ratio", report_md)
        self.assertIn("Executive Summary", report_md)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
