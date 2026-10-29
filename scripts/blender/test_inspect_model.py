import bpy
import os

model_path = r"assets/models/characters/KnightCharacter.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=model_path)

mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
armatures = [o for o in bpy.data.objects if o.type == 'ARMATURE']
print(f'Mesh objects: {[o.name for o in mesh_objs]}')
print(f'Armatures: {[o.name for o in armatures]}')

total_verts = sum(len(o.data.vertices) for o in mesh_objs)
total_polys = sum(len(o.data.polygons) for o in mesh_objs)
print(f'Total vertices: {total_verts}, Total polygons: {total_polys}')
