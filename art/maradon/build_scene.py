import bpy, math, os
from mathutils import Vector
R='/Users/selcuk/Documents/gkk-web/gkk_flutter'; OUT=R+'/maradon_hub.blend'; PNG=R+'/maradon_hub_preview.png'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def M(n,c,metal=0,rough=.6,emit=None):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True; b=m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=(*c,1); b.inputs['Metallic'].default_value=metal; b.inputs['Roughness'].default_value=rough
 if emit: b.inputs['Emission Color'].default_value=(*emit,1); b.inputs['Emission Strength'].default_value=3
 return m
stone=M('Stone',(.12,.15,.20),.15,.82); edge=M('Edge',(.27,.30,.36),.1,.65); road=M('Road',(.055,.07,.10),0,.92); gold=M('Royal Gold',(.72,.4,.08),.8,.22,(.7,.25,.03)); blue=M('Arcane Blue',(.03,.18,.34),.4,.3,(.02,.2,.7)); cyan=M('Portal Cyan',(.01,.4,.55),.2,.2,(.01,.5,1)); red=M('Banner',(.32,.025,.05),.1,.5); grass=M('Grass',(.04,.1,.06),0,1)
def cube(n,l,s,m,b=0):
 bpy.ops.mesh.primitive_cube_add(location=l); o=bpy.context.object; o.name=n; o.scale=s; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(m)
 if b: q=o.modifiers.new('Bevel','BEVEL'); q.width=b; q.segments=3
 return o
def cyl(n,l,r,d,m):
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=d,location=l); o=bpy.context.object; o.name=n; o.data.materials.append(m); return o
def tor(n,l,maj,minr,m,rot=(0,0,0)):
 bpy.ops.mesh.primitive_torus_add(major_radius=maj,minor_radius=minr,major_segments=48,minor_segments=12,location=l,rotation=rot); o=bpy.context.object; o.data.materials.append(m); return o
def text(t,l,sz=1,m=gold):
 c=bpy.data.curves.new(t,'FONT'); c.body=t; c.align_x='CENTER'; c.size=sz; c.extrude=.035; o=bpy.data.objects.new(t,c); bpy.context.collection.objects.link(o); o.location=l; o.rotation_euler=(math.radians(78),0,0); o.data.materials.append(m)
def image(n,path,l,sc):
 bpy.ops.mesh.primitive_plane_add(size=2,location=l,rotation=(math.radians(90),0,0)); o=bpy.context.object; o.name=n; o.scale=(sc,sc,sc); m=bpy.data.materials.new(n+'Mat'); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear(); out=nt.nodes.new('ShaderNodeOutputMaterial'); sh=nt.nodes.new('ShaderNodeBsdfPrincipled'); tx=nt.nodes.new('ShaderNodeTexImage')
 try: tx.image=bpy.data.images.load(path,check_existing=True)
 except: return o
 sh.inputs['Roughness'].default_value=.7; sh.inputs['Emission Strength'].default_value=.25; nt.links.new(tx.outputs['Color'],sh.inputs['Base Color']); nt.links.new(tx.outputs['Color'],sh.inputs['Emission Color']); nt.links.new(tx.outputs['Alpha'],sh.inputs['Alpha']); nt.links.new(sh.outputs[0],out.inputs[0]); m.surface_render_method='DITHERED'; o.data.materials.append(m); return o
# land + roads
cube('Ground',(0,0,-.7),(25,19,.7),grass,.3); cube('Royal Plaza',(0,0,0),(17,13,.22),road,.12)
for n,l,s in [('North Road',(0,10,.05),(3,8.5,.06)),('South Road',(0,-10,.05),(3,8.5,.06)),('East Road',(10,0,.05),(8.5,3,.06)),('West Road',(-10,0,.05),(8.5,3,.06))]: cube(n,l,s,edge,.04)
# walls
for n,l,s in [('WallN',(0,17,2.2),(24,.8,2.2)),('WallS',(0,-17,2.2),(24,.8,2.2)),('WallE',(23,0,2.2),(.8,17,2.2)),('WallW',(-23,0,2.2),(.8,17,2.2))]: cube(n,l,s,stone,.35)
for x in range(-21,22,4): cube('Crenel',(x,16.2,5),(1,.9,.65),edge,.1); cube('Crenel',(x,-16.2,5),(1,.9,.65),edge,.1)
for y in range(-13,14,4): cube('Crenel',(22.2,y,5),(.9,1,.65),edge,.1); cube('Crenel',(-22.2,y,5),(.9,1,.65),edge,.1)
for x,y in [(-21,-15),(21,-15),(-21,15),(21,15)]: cyl('Tower',(x,y,3.3),3.1,6.6,edge); cyl('Tower Cap',(x,y,6.8),3.5,.5,gold)
# center
cyl('Fountain Base',(0,0,.55),5.2,.7,edge); cyl('Water',(0,0,.96),4.5,.16,cyan); cyl('Core',(0,0,2.3),1,2.6,gold); tor('Fountain Ring',(0,0,1.2),3.7,.18,gold); text('ROYAL PLAZA',(0,0,4),.85)
# portal + gate
for x in (-12,12): cyl('Obelisk',(x,10,2.5),1.1,5,blue); cyl('Orb',(x,10,5.3),.95,1,cyan)
tor('North Portal',(0,14,4.2),3,.35,cyan,(math.radians(90),0,0)); text('NORTH GATE',(0,13.2,7.7),.75,cyan)
cube('GateL',(-5,-16.2,3),(3,1.1,3),edge,.2); cube('GateR',(5,-16.2,3),(3,1.1,3),edge,.2); cube('GateTop',(0,-16.2,7),(8,1.1,1),gold,.2); text('MARADON',(0,-15.0,7.1),1.0)
# market / npc buildings
items=[('MARKET','pazar.png',(13,-7,3.1),blue),('MARKET','pazar.png',(13,-1,3.1),blue),('UPGRADE','itemupgrade.png',(-13,-7,3),red),('CRAFT','zanaat.png',(-13,-1,3),red),('BANK','banka.png',(13,6,3),blue),('HOSPITAL','hastane.png',(-13,6,3),red)]
for label,f,(x,y,z),roof in items:
 cube(label+' Platform',(x,y,.5),(3,2.1,.4),edge,.2); cube(label+' Roof',(x,y,4.8),(3.3,2.3,.24),roof,.15); image(label,R+'/assets/menuitems/'+f,(x,y,z),2.2); text(label,(x,y-2.3,.65),.42)
# player/NPC markers
for x,y in [(-4,4),(4,4),(-4,-4),(4,-4),(0,-7),(8,2),(-8,2)]: cyl('Player Spot',(x,y,.18),.55,.12,gold); tor('Player Ring',(x,y,.27),.62,.06,cyan)
for label,f,l in [('KNIGHT','savasci.png',(-6,7,3.2)),('SHADOW','golge.png',(7,-5,2.8)),('ALCHEMIST','simyaci.png',(-7,-6,2.8))]: image(label,R+'/assets/characters/'+f,l,1.7); text(label,(l[0],l[1]-1.5,.3),.4,cyan)
text('MARKET DISTRICT',(14,0,7),.7); text('NPC SERVICES',(-14,0,7),.7)
# light/camera
w=bpy.context.scene.world; w.use_nodes=True; w.node_tree.nodes['Background'].inputs['Color'].default_value=(.006,.01,.025,1); w.node_tree.nodes['Background'].inputs['Strength'].default_value=.3
for loc,en,col,size in [((0,-2,28),2400,(1,1,1),20),((0,-12,10),1200,(.2,.4,1),12),((14,3,9),1000,(1,.25,.08),10)]: bpy.ops.object.light_add(type='AREA',location=loc); q=bpy.context.object; q.data.energy=en; q.data.color=col; q.data.shape='DISK'; q.data.size=size
bpy.ops.object.camera_add(location=(38,-42,34)); cam=bpy.context.object; bpy.context.scene.camera=cam; cam.rotation_euler=(Vector((0,0,1.5))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.lens=47
s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.render.resolution_x=1200; s.render.resolution_y=900; s.render.resolution_percentage=100; s.render.image_settings.file_format='PNG'; s.render.filepath=PNG; s.view_settings.look='AgX - Medium High Contrast'; s['hub_name']='Maradon Royal Plaza'; s['features']='market, NPC services, player interaction spots, portal, gate'; bpy.ops.wm.save_as_mainfile(filepath=OUT); bpy.ops.render.render(write_still=True)
