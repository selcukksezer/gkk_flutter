import os
import struct
import json
import pytest

WEAPONS_DIR = os.path.join("assets", "models", "weapons")
REQUIRED_MODELS = ["sword.glb", "broadsword.glb", "shield.glb", "battleaxe.glb"]

def test_weapons_directory_exists():
    assert os.path.isdir(WEAPONS_DIR), f"Weapons directory {WEAPONS_DIR} does not exist"

@pytest.mark.parametrize("model_name", REQUIRED_MODELS)
def test_required_weapon_models_exist_and_valid(model_name):
    path = os.path.join(WEAPONS_DIR, model_name)
    assert os.path.isfile(path), f"File {model_name} missing from {WEAPONS_DIR}"
    
    file_size = os.path.getsize(path)
    assert file_size > 10240, f"File {model_name} is too small ({file_size} bytes, expected > 10KB)"
    
    with open(path, "rb") as f:
        magic, version, length = struct.unpack("<4sII", f.read(12))
        assert magic == b"glTF", f"{model_name} magic header is not glTF: {magic}"
        assert version == 2, f"{model_name} glTF version is {version}, expected 2"
        assert length == file_size, f"{model_name} declared length {length} != actual size {file_size}"
        
        chunk_len, chunk_type = struct.unpack("<I4s", f.read(8))
        assert chunk_type == b"JSON", f"{model_name} first chunk is {chunk_type}, expected JSON"
        
        gltf = json.loads(f.read(chunk_len).decode("utf-8"))
        assert "meshes" in gltf and len(gltf["meshes"]) > 0, f"{model_name} has no meshes"
        
        accessors = gltf.get("accessors", [])
        total_verts = 0
        for mesh in gltf["meshes"]:
            for prim in mesh.get("primitives", []):
                attrs = prim.get("attributes", {})
                pos = attrs.get("POSITION")
                if pos is not None and pos < len(accessors):
                    total_verts += accessors[pos].get("count", 0)
        assert total_verts > 100, f"{model_name} vertex count ({total_verts}) is too low (not genuine mesh)"

def test_pubspec_registration():
    with open("pubspec.yaml", "r", encoding="utf-8") as f:
        content = f.read()
    assert "assets/models/weapons/" in content, "assets/models/weapons/ not declared in pubspec.yaml"
