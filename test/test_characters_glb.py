import struct
import json
from pathlib import Path
import pytest

CHARACTERS = [
    {
        "id": "mage",
        "file": "mage.glb",
        "min_size": 10000,
        "min_verts": 1000,
        "min_tris": 1000,
    },
    {
        "id": "wizard",
        "file": "wizard.glb",
        "min_size": 10000,
        "min_verts": 1000,
        "min_tris": 1000,
    },
    {
        "id": "rogue",
        "file": "rogue.glb",
        "min_size": 10000,
        "min_verts": 1000,
        "min_tris": 1000,
    },
    {
        "id": "archer",
        "file": "archer.glb",
        "min_size": 10000,
        "min_verts": 1000,
        "min_tris": 1000,
    },
]

CHAR_DIR = Path("assets/models/characters")

@pytest.mark.parametrize("char", CHARACTERS, ids=lambda c: c["id"])
def test_character_glb_model_validity(char):
    file_path = CHAR_DIR / char["file"]
    assert file_path.exists(), f"File {file_path} must exist on disk"
    
    size = file_path.stat().st_size
    assert size >= char["min_size"], f"File {file_path} size {size} < {char['min_size']}"
    
    with open(file_path, "rb") as f:
        data = f.read()
    
    # Check glTF magic bytes
    assert data[:4] == b"glTF", "Magic header must be 'glTF'"
    
    magic, version, total_length = struct.unpack("<III", data[:12])
    assert total_length == len(data), "GLB total_length must match file length"
    
    chunk_len, chunk_type = struct.unpack("<II", data[12:20])
    assert chunk_type == 0x4E4F534A, "First chunk must be JSON"
    
    json_bytes = data[20 : 20 + chunk_len]
    gltf = json.loads(json_bytes.decode("utf-8"))
    
    accessors = gltf.get("accessors", [])
    meshes = gltf.get("meshes", [])
    assert len(meshes) > 0, "GLB must contain at least one mesh"
    
    verts = 0
    tris = 0
    for m in meshes:
        for p in m.get("primitives", []):
            attrs = p.get("attributes", {})
            pos = attrs.get("POSITION")
            if pos is not None and pos < len(accessors):
                verts += accessors[pos].get("count", 0)
            idx = p.get("indices")
            if idx is not None and idx < len(accessors):
                tris += accessors[idx].get("count", 0) // 3
            elif pos is not None and pos < len(accessors):
                tris += accessors[pos].get("count", 0) // 3
                
    assert verts >= char["min_verts"], f"Vertices {verts} must be >= {char['min_verts']}"
    assert tris >= char["min_tris"], f"Triangles {tris} must be >= {char['min_tris']}"
