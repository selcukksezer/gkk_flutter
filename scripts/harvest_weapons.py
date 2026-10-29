import urllib.request
import json
import os
import shutil
import struct

TARGET_DIR = os.path.join("assets", "models", "weapons")
os.makedirs(TARGET_DIR, exist_ok=True)

# 1. Fetch available files in Quaternius Medieval Weapons Pack
api_url = "https://api.github.com/repos/trebeljahr/quaternius-showcase/contents/public/glb/medieval_weapons_pack"
req = urllib.request.Request(api_url, headers={"User-Agent": "Mozilla/5.0"})

items = []
try:
    with urllib.request.urlopen(req) as resp:
        items = json.loads(resp.read().decode("utf-8"))
        print(f"Found {len(items)} items in Quaternius medieval weapons repo:")
        for it in items:
            print(f" - {it['name']}: {it['size']} bytes, {it['download_url']}")
except Exception as e:
    print(f"API query note: {e}, falling back to direct known raw URLs")

raw_base = "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/public/glb/medieval_weapons_pack"

# Key models to download
models_to_download = [
    ("Claymore.glb", f"{raw_base}/Claymore.glb"),
    ("Sword_Big.glb", f"{raw_base}/Sword_Big.glb"),
    ("Sword_Golden.glb", f"{raw_base}/Sword_Golden.glb"),
    ("Shield_Celtic_Golden.glb", f"{raw_base}/Shield_Celtic_Golden.glb"),
    ("Axe_Double.glb", f"{raw_base}/Axe_Double.glb"),
    ("Dagger.glb", f"{raw_base}/Dagger.glb"),
    ("Bow_Golden.glb", f"{raw_base}/Bow_Golden.glb"),
]

# If API returned more weapons, add any additional .glb files
for it in items:
    name = it.get("name", "")
    if name.endswith(".glb") and not any(m[0] == name for m in models_to_download):
        models_to_download.append((name, it.get("download_url") or f"{raw_base}/{name}"))

print(f"\nTotal models to download: {len(models_to_download)}")

downloaded = {}
for filename, url in models_to_download:
    dest_path = os.path.join(TARGET_DIR, filename)
    print(f"Downloading {filename} from {url}...")
    try:
        req_dl = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req_dl) as res, open(dest_path, "wb") as out:
            shutil.copyfileobj(res, out)
        sz = os.path.getsize(dest_path)
        print(f" -> Saved {dest_path} ({sz} bytes)")
        downloaded[filename] = {"path": dest_path, "size": sz, "url": url}
    except Exception as e:
        print(f" -> Error downloading {filename}: {e}")

# Target requested models: sword.glb, broadsword.glb, shield.glb, battleaxe.glb
aliases = {
    "sword.glb": "Sword_Golden.glb",
    "broadsword.glb": "Claymore.glb",
    "shield.glb": "Shield_Celtic_Golden.glb",
    "battleaxe.glb": "Axe_Double.glb",
}

for alias, src_name in aliases.items():
    src_path = os.path.join(TARGET_DIR, src_name)
    alias_path = os.path.join(TARGET_DIR, alias)
    if os.path.exists(src_path):
        shutil.copyfile(src_path, alias_path)
        alias_sz = os.path.getsize(alias_path)
        print(f"Created canonical model {alias} from {src_name} ({alias_sz} bytes)")
        downloaded[alias] = {
            "path": alias_path,
            "size": alias_sz,
            "url": downloaded.get(src_name, {}).get("url", raw_base) + f" (copied as {alias})"
        }

print("\n--- Parsing GLB Files for Vertex and Face Counts ---")
report_rows = []

for fname in sorted(os.listdir(TARGET_DIR)):
    if not fname.endswith(".glb"):
        continue
    fpath = os.path.join(TARGET_DIR, fname)
    fsize = os.path.getsize(fpath)
    
    with open(fpath, "rb") as f:
        header = f.read(12)
        if len(header) < 12:
            print(f"INVALID GLB (too small): {fname}")
            continue
        magic, version, length = struct.unpack("<4sII", header)
        if magic != b"glTF":
            print(f"INVALID GLB: {fname} magic={magic}")
            continue
        
        chunk_header = f.read(8)
        if len(chunk_header) < 8:
            print(f"INVALID GLB chunk header: {fname}")
            continue
        chunk_len, chunk_type = struct.unpack("<I4s", chunk_header)
        if chunk_type != b"JSON":
            print(f"FIRST CHUNK NOT JSON in {fname}")
            continue
            
        json_bytes = f.read(chunk_len)
        gltf = json.loads(json_bytes.decode("utf-8"))
        
        accessors = gltf.get("accessors", [])
        meshes = gltf.get("meshes", [])
        
        total_vertices = 0
        total_faces = 0
        
        for mesh in meshes:
            for prim in mesh.get("primitives", []):
                attrs = prim.get("attributes", {})
                pos_idx = attrs.get("POSITION")
                if pos_idx is not None and pos_idx < len(accessors):
                    total_vertices += accessors[pos_idx].get("count", 0)
                
                indices_idx = prim.get("indices")
                if indices_idx is not None and indices_idx < len(accessors):
                    total_faces += accessors[indices_idx].get("count", 0) // 3
                    
        source_url = downloaded.get(fname, {}).get("url", f"{raw_base}/{fname}")
        print(f"Model: {fname:25} | Size: {fsize/1024:8.2f} KB | Vertices: {total_vertices:6} | Faces: {total_faces:6}")
        report_rows.append({
            "filename": fname,
            "size_bytes": fsize,
            "vertices": total_vertices,
            "faces": total_faces,
            "source_url": source_url,
        })

print(f"\nCompleted analysis of {len(report_rows)} verified GLB weapon models.")

with open(os.path.join("assets", "models", "weapons", "weapons_manifest.json"), "w", encoding="utf-8") as mf:
    json.dump(report_rows, mf, indent=2)
print("Saved weapons_manifest.json")
