import os
import unittest
import numpy as np
from PIL import Image

TARGET_DIR = r'assets/images/portraits/asmodian'
EXPECTED_FILES = [
    'asmodian_gladiator.png',
    'asmodian_templar.png',
    'asmodian_sorcerer.png',
    'asmodian_spiritmaster.png',
    'asmodian_cleric.png',
    'asmodian_chanter.png',
    'asmodian_ranger.png',
    'asmodian_assassin.png',
]

class TestAsmodianPortraits(unittest.TestCase):
    def test_all_files_exist(self):
        for fname in EXPECTED_FILES:
            fpath = os.path.join(TARGET_DIR, fname)
            self.assertTrue(os.path.exists(fpath), f'Missing portrait: {fname}')

    def test_images_valid_and_high_res(self):
        for fname in EXPECTED_FILES:
            fpath = os.path.join(TARGET_DIR, fname)
            with Image.open(fpath) as img:
                self.assertEqual(img.format, 'PNG', f'{fname} format is not PNG')
                w, h = img.size
                self.assertGreaterEqual(w, 512, f'{fname} width {w} < 512')
                self.assertGreaterEqual(h, 512, f'{fname} height {h} < 512')
                self.assertIn(img.mode, ('RGB', 'RGBA'), f'{fname} mode {img.mode} invalid')
                
                # Check data integrity / variance
                arr = np.array(img)
                std_dev = np.std(arr)
                self.assertGreater(std_dev, 20.0, f'{fname} pixel variance too low ({std_dev}), looks blank')
                
                # Check file size (> 100 KB)
                fsize = os.path.getsize(fpath)
                self.assertGreater(fsize, 100 * 1024, f'{fname} file size too small: {fsize} bytes')
                print(f'[PASS] {fname}: {w}x{h}, mode={img.mode}, std_dev={std_dev:.2f}, size={fsize//1024} KB')

if __name__ == '__main__':
    unittest.main()
