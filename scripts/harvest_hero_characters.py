import os
import sys
import json
import struct
import shutil
import urllib.request
from pathlib import Path

CHARACTERS_DIR = Path("assets/models/characters")
CHARACTERS_DIR.mkdir(parents=True, exist_ok=True)

TARGETS = [
    {
        "target_filename": "knight.glb",
        "name": "Knight",
        "creator": "Kay Lousberg (KayKit)",
        "source_url": "https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main/addons/kaykit_character_pack_adventures/Characters/gltf/Knight.glb",
        "license": "CC0 1.0 Universal",
        "local_source": "Knight.glb"
    },
    {
        "target_filename": "warrior.glb",
        "name": "Warrior (Berserker / Barbarian)",
        "creator": "Kay Lousberg (KayKit)",
        "source_url": "https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main/addons/kaykit_character_pack_adventures/Characters/gltf/Barbarian.glb",
        "license": "CC0 1.0 Universal",
        "local_source": "Barbarian.glb"
    },
    {
        "target_filename": "paladin.glb",
        "name": "Paladin (Winged Heavy Plate Crusader)",
        "creator": "Quaternius",
        "source_url": "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/public/glb/single_knight_pack/KnightCharacter.glb",
        "license": "CC0 1.0 Universal",
        "local_source": "KnightCharacter.glb"
    },
    {
        "target_filename": "hero.glb",
        "name": "Hero (Imperial Vanguard Champion)",
        "creator": "three.js / mrdoob",
        "source_url": "https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/models/gltf/Soldier.glb",
        "license": "MIT / CC0 Free Commercial",
        "local_source": "Soldier.glb"
    }
]

def parse_glb_metadata(filepath: Path):
    with open(filepath, "rb") as f:
        data = f.read()

    if len(data) < 20 or not data.startswith(b"glTF"):
        raise ValueError(f"File {filepath} is not a valid GLB container!")

    magic, version, total_length = struct.unpack("<III", data[:12])
    chunk_len, chunk_type = struct.unpack("<II", data[12:20])

    if chunk_type != 0x4E4F534A:  # 'JSON'
        raise ValueError(f"File {filepath} first chunk is not JSON")

    json_bytes = data[20 : 20 + chunk_len]
    gltf_json = json.loads(json_bytes.decode("utf-8"))

    accessors = gltf_json.get("accessors", [])
    materials = gltf_json.get("materials", [])
    meshes = gltf_json.get("meshes", [])
    animations = gltf_json.get("animations", [])
    skins = gltf_json.get("skins", [])

    total_vertices = 0
    total_triangles = 0

    for mesh in meshes:
        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            pos_idx = attrs.get("POSITION")
            if pos_idx is not None and pos_idx < len(accessors):
                total_vertices += accessors[pos_idx].get("count", 0)

            idx_accessor = prim.get("indices")
            if idx_accessor is not None and idx_accessor < len(accessors):
                total_triangles += accessors[idx_accessor].get("count", 0) // 3
            elif pos_idx is not None and pos_idx < len(accessors):
                total_triangles += accessors[pos_idx].get("count", 0) // 3

    return {
        "filesize_bytes": len(data),
        "vertex_count": total_vertices,
        "face_count": total_triangles,
        "mesh_count": len(meshes),
        "material_count": len(materials),
        "animation_count": len(animations),
        "animations": [a.get("name") or f"Anim_{i}" for i, a in enumerate(animations)],
        "skin_count": len(skins)
    }

results = []

for item in TARGETS:
    target_path = CHARACTERS_DIR / item["target_filename"]
    local_src = CHARACTERS_DIR / item["local_source"]
    
    # Check if target already exists and is valid
    need_fetch = True
    if target_path.exists() and target_path.stat().st_size > 10000:
        with open(target_path, "rb") as tf:
            if tf.read(4) == b"glTF":
                need_fetch = False
    
    if need_fetch:
        if local_src.exists() and local_src.stat().st_size > 10000:
            shutil.copyfile(local_src, target_path)
            print(f"Copied {local_src.name} to {target_path.name}")
        else:
            print(f"Downloading {item['source_url']} -> {target_path.name}")
            req = urllib.request.Request(item["source_url"], headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
            if not data.startswith(b"glTF"):
                raise ValueError(f"Downloaded file for {target_path.name} is not a valid GLB!")
            with open(target_path, "wb") as f:
                f.write(data)
            print(f"Downloaded and saved {target_path.name} ({len(data)} bytes)")
    
    meta = parse_glb_metadata(target_path)
    res = {
        "filename": item["target_filename"],
        "name": item["name"],
        "creator": item["creator"],
        "license": item["license"],
        "source_url": item["source_url"],
        "path": str(target_path).replace("\\", "/"),
        **meta
    }
    results.append(res)
    print(f"Verified {item['target_filename']}: size={meta['filesize_bytes']:,} vertices={meta['vertex_count']:,} faces={meta['face_count']:,} anims={meta['animation_count']}")

with open("scripts/harvest_hero_characters_results.json", "w") as out:
    json.dump(results, out, indent=2)
print("SUCCESS")
