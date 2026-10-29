import bpy
import glob
import os

files = glob.glob('assets/models/characters/*.glb') + glob.glob('assets/models/monsters/*.glb') + glob.glob('assets/models/weapons/*.glb')
# Filter out already generated LOD files
files = [f for f in files if not any(x in f for x in ['_LOD', '_Impostor', '_MultiLOD'])]

print(f'Found {len(files)} target assets.')
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.gltf(filepath=f)
        meshes = [o for o in bpy.data.objects if o.type == 'MESH']
        armatures = [o for o in bpy.data.objects if o.type == 'ARMATURE']
        total_tris = 0
        has_shapekeys = False
        for m in meshes:
            if m.data.shape_keys:
                has_shapekeys = True
            # count triangles: len(polygons) or sum of tri count
            for p in m.data.polygons:
                total_tris += max(1, len(p.vertices) - 2)
        print(f'{os.path.basename(f)}: meshes={len(meshes)}, armatures={len(armatures)}, tris={total_tris}, shapekeys={has_shapekeys}')
    except Exception as e:
        print(f'{os.path.basename(f)}: ERROR {e}')
