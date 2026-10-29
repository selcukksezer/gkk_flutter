import unittest
import struct
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent / 'scripts' / 'assets'))
from harvest_cc0_glb import parse_glb_metadata

class TestWeaponsRangedGlb(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.models_dir = Path(__file__).parent.parent / 'assets' / 'models' / 'weapons'
        cls.target_files = [
            'bow.glb',
            'crossbow.glb',
            'magic_staff.glb',
            'dagger.glb',
            'wand.glb'
        ]

    def test_files_exist_and_size_threshold(self):
        """Each ranged/magic weapon model must exist on disk and exceed 10KB."""
        for filename in self.target_files:
            file_path = self.models_dir / filename
            self.assertTrue(file_path.exists(), f'Missing weapon model: {filename}')
            size = file_path.stat().st_size
            self.assertGreater(size, 10 * 1024, f'{filename} too small: {size} bytes (minimum 10KB)')

    def test_valid_glb_binary_header(self):
        """Each model must start with glTF binary magic 0x46546C67 and version 2."""
        for filename in self.target_files:
            file_path = self.models_dir / filename
            with open(file_path, 'rb') as f:
                header = f.read(12)
                magic, version, length = struct.unpack('<4sII', header)
                self.assertEqual(magic, b'glTF', f'{filename} missing glTF magic bytes')
                self.assertEqual(version, 2, f'{filename} is not glTF version 2')
                self.assertEqual(length, file_path.stat().st_size, f'{filename} header length mismatch')

    def test_mesh_geometry_integrity_and_non_primitive(self):
        """Verify models contain real, complex mesh data (non-primitive vertices/triangles)."""
        min_triangles = {
            'bow.glb': 500,
            'crossbow.glb': 500,
            'magic_staff.glb': 300,
            'dagger.glb': 500,
            'wand.glb': 100
        }
        for filename in self.target_files:
            file_path = self.models_dir / filename
            meta = parse_glb_metadata(file_path)
            vc = meta.get('vertex_count', 0)
            tc = meta.get('triangle_count', 0)
            self.assertGreater(vc, 100, f'{filename} vertex count {vc} too low')
            self.assertGreater(tc, min_triangles[filename], f'{filename} triangle count {tc} below expected {min_triangles[filename]}')
            self.assertGreater(meta.get('material_count', 0), 0, f'{filename} has no materials')

if __name__ == '__main__':
    unittest.main()
