import os
import unittest
import numpy as np
from PIL import Image

BOSS_FILES = [
    "boss_tiamat.png",
    "boss_stormwing.png",
    "boss_beritra.png",
    "boss_ereshkigal.png",
    "boss_kromede.png",
    "boss_tahabata.png",
]

TARGET_DIR = os.path.join("assets", "images", "portraits", "bosses")

class TestBossPortraits(unittest.TestCase):
    def test_all_boss_portraits_exist(self):
        for fname in BOSS_FILES:
            fpath = os.path.join(TARGET_DIR, fname)
            self.assertTrue(os.path.exists(fpath), f"Missing boss portrait: {fpath}")

    def test_boss_portraits_validity_and_resolution(self):
        for fname in BOSS_FILES:
            fpath = os.path.join(TARGET_DIR, fname)
            with Image.open(fpath) as img:
                self.assertEqual(img.format, "PNG", f"{fname} is not PNG format")
                self.assertGreaterEqual(img.width, 512, f"{fname} width {img.width} < 512")
                self.assertGreaterEqual(img.height, 512, f"{fname} height {img.height} < 512")
                self.assertEqual((img.width, img.height), (1024, 1024), f"{fname} unexpected resolution")
                
                # Check data integrity and variance (ensure not blank dummy)
                arr = np.array(img)
                self.assertGreater(arr.size, 0)
                std_dev = np.std(arr[..., :3])
                self.assertGreater(std_dev, 15.0, f"{fname} lacks color variance (std_dev={std_dev:.2f})")
                print(f"[VERIFIED] {fname}: {img.size}, {img.mode}, {os.path.getsize(fpath)} bytes, std_dev={std_dev:.2f}")

if __name__ == "__main__":
    unittest.main()
