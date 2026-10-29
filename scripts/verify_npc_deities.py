"""
Verification script for Aion-2 Empyrean Lord deity portraits.
Verifies existence, format, dimensions, channels, non-trivial entropy/size.
"""

import os
import sys
from PIL import Image
import numpy as np

TARGET_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "images", "portraits", "npcs"))

EXPECTED_FILES = [
    "lord_ariel.png",
    "lord_azphel.png",
    "lord_nezekan.png",
    "lord_zikel.png",
    "lord_kaisinel.png",
    "lord_marchutan.png"
]

def verify():
    print(f"Inspecting directory: {TARGET_DIR}")
    if not os.path.exists(TARGET_DIR):
        print(f"ERROR: Target directory does not exist: {TARGET_DIR}")
        return False
        
    all_ok = True
    for filename in EXPECTED_FILES:
        path = os.path.join(TARGET_DIR, filename)
        if not os.path.exists(path):
            print(f"FAIL: Missing file {filename}")
            all_ok = False
            continue
            
        size_bytes = os.path.getsize(path)
        if size_bytes < 50 * 1024:
            print(f"FAIL: File size too small ({size_bytes} bytes) for {filename}")
            all_ok = False
            continue
            
        try:
            with Image.open(path) as img:
                img.verify()
            with Image.open(path) as img:
                w, h = img.size
                mode = img.mode
                if w < 512 or h < 512:
                    print(f"FAIL: Dimensions {w}x{h} < 512x512 for {filename}")
                    all_ok = False
                    continue
                arr = np.array(img)
                std_dev = np.std(arr)
                if std_dev < 15.0:
                    print(f"FAIL: Flat/dummy image detected (std dev {std_dev:.2f}) for {filename}")
                    all_ok = False
                    continue
                print(f"PASS: {filename:20s} | Size: {size_bytes/1024:6.1f} KB | Dims: {w}x{h} | Mode: {mode} | StdDev: {std_dev:.2f}")
        except Exception as e:
            print(f"FAIL: Corrupt image {filename}: {e}")
            all_ok = False
            
    if all_ok:
        print("\nAll 6 Aion-2 Empyrean Lord portraits passed verification!")
    return all_ok

if __name__ == "__main__":
    if not verify():
        sys.exit(1)
