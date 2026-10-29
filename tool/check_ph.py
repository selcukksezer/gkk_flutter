import urllib.request
import json

req = urllib.request.urlopen("https://api.polyhaven.com/assets?t=textures")
assets = json.loads(req.read().decode())

metal_assets = [k for k, v in assets.items() if "metal" in v.get("categories", []) or "metal" in k or "iron" in k]
print(f"Found {len(metal_assets)} metal assets.")

for name in metal_assets[:20]:
    try:
        f_req = urllib.request.urlopen(f"https://api.polyhaven.com/files/{name}")
        files = json.loads(f_req.read().decode())
        keys = list(files.keys())
        print(f"{name}: {keys}")
    except Exception as e:
        pass
