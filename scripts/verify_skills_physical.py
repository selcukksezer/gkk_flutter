"""
Verification script for generated physical & divine skill icons.
"""

import os
import glob
from PIL import Image
import numpy as np

# Cleanup any stray code files in .agents directory to satisfy layout compliance
agent_dir = r".agents\teamwork\worker_art_6_skill_icons_physical_divine"
for f in glob.glob(os.path.join(agent_dir, "*.py")):
    try:
        os.remove(f)
        print(f"Removed stray file in .agents: {f}")
    except Exception as e:
        pass

OUTPUT_DIR = r"assets\images\icons\skills_physical"
REQUIRED_ICONS = [
    "skill_righteous_punishment.png",
    "skill_shield_bastion.png",
    "skill_ankle_snare.png",
    "skill_shadow_step.png",
    "skill_executioners_cleave.png",
    "skill_divine_grace.png",
    "skill_holy_aegis.png",
    "skill_venomous_strike.png",
    "skill_sniper_arrow.png",
    "skill_mantra_of_wrath.png",
    "skill_berserker_rage.png",
    "skill_whirlwind_slash.png",
    "skill_smite_evil.png",
    "skill_smoke_bomb.png",
    "skill_resurrection_light.png",
    "skill_blade_flurry.png",
]

def verify_all():
    all_ok = True
    print(f"Verifying {len(REQUIRED_ICONS)} icons in {OUTPUT_DIR}...")
    for name in REQUIRED_ICONS:
        path = os.path.join(OUTPUT_DIR, name)
        if not os.path.exists(path):
            print(f"[FAIL] Missing file: {name}")
            all_ok = False
            continue
        try:
            with Image.open(path) as img:
                img.verify()
            with Image.open(path) as img:
                w, h = img.size
                fmt = img.format
                mode = img.mode
                arr = np.array(img)
                std_dev = np.std(arr)
                min_val = np.min(arr)
                max_val = np.max(arr)

                if (w, h) != (256, 256):
                    print(f"[FAIL] {name}: incorrect dimensions {w}x{h}")
                    all_ok = False
                elif fmt != "PNG":
                    print(f"[FAIL] {name}: unexpected format {fmt}")
                    all_ok = False
                elif std_dev < 10.0:
                    print(f"[FAIL] {name}: low visual variance (std_dev={std_dev:.2f})")
                    all_ok = False
                else:
                    print(f"[PASS] {name}: {w}x{h} {fmt} {mode}, std_dev={std_dev:.2f}, range=[{min_val},{max_val}], size={os.path.getsize(path)} bytes")
        except Exception as e:
            print(f"[FAIL] {name}: corrupted image ({e})")
            all_ok = False

    if all_ok:
        print("\nALL 16 ICONS VERIFIED SUCCESSFULLY!")
    else:
        print("\nSOME ICONS FAILED VERIFICATION.")
        exit(1)

if __name__ == "__main__":
    verify_all()
