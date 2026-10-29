import bpy, math, random, os, json
from mathutils import Vector
random.seed(9)
R='/Users/selcuk/Documents/gkk-web/gkk_flutter'; bpy.ops.wm.open_mainfile(filepath=R+'/maradon_hub.blend')
s=bpy.context.scene
# Retain original prototype as a separate file. Refine a new scene file.
def mat(n,c,metal=0,rough=.7):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True; b=m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=(*c,1); b.inputs['Metallic'].default_value=metal; b.inputs['Roughness'].default_value=rough; return m
def cube(n,l,d,m,bev=.04):
 bpy.ops.mesh.primitive_cube_add(size=1,location=l); o=bpy.context.object; o.name=n; o.dimensions=d; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(m)
 if bev: b=o.modifiers.new('Worn corners','BEVEL'); b.width=bev; b.segments=2
 return o
def cyl(n,l,r,dep,m,vertices=16):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=dep,location=l); o=bpy.context.object; o.name=n; o.data.materials.append(m); return o
def cone(n,l,r1,r2,dep,m):
 bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=r1,radius2=r2,depth=dep,location=l); o=bpy.context.object; o.name=n; o.data.materials.append(m); return o
def beam(n,a,b,r,m):
 d=Vector(b)-Vector(a); o=cyl(n,(Vector(a)+Vector(b))/2,r,d.length,m,8); o.rotation_euler=d.to_track_quat('Z','Y').to_euler(); return o
def text(t,l,size,m):
 c=bpy.data.curves.new(t,'FONT'); c.body=t; c.size=size; c.align_x='CENTER'; c.extrude=.008; o=bpy.data.objects.new(t,c); s.collection.objects.link(o); o.location=l; o.rotation_euler=(math.pi/2,0,0); o.data.materials.append(m); return o
sand=mat('Warm limestone',(.38,.32,.23)); pale=mat('Carved limestone',(.60,.51,.36)); timber=mat('Dark oak',(.105,.052,.025)); wood=mat('Honey oak',(.28,.13,.047)); roof=mat('Patinated slate',(.045,.17,.18),.15); cloth=mat('Indigo canvas',(.03,.12,.23)); cream=mat('Linen',(.7,.6,.38)); brass=mat('Old brass',(.55,.29,.07),.7); leaf=mat('Cypress foliage',(.045,.15,.075)); skin=mat('Skin',(.52,.3,.17)); steel=mat('Armor',(.18,.23,.26),.7); burg=mat('Burgundy',(.24,.035,.025)); water=mat('Fountain water',(.035,.24,.28),.55,.16)
for name in ['Royal Gold','Arcane Blue']:
 m=bpy.data.materials[name]; m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=0
for n in ['Stone','Edge']:
 m=bpy.data.materials[n]; b=m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=(*((.32,.28,.22) if n=='Stone' else (.48,.43,.33)),1)
# Keep luminous materials only on portal and small interaction details.
for o in list(bpy.data.objects):
 if o.type=='FONT' or 'Roof' in o.name or o.name in ['GateL','GateR','GateTop','WallS'] or 'Player' in o.name or o.name in ['Core','Orb','Orb.001','Obelisk','Obelisk.001']:
  bpy.data.objects.remove(o,do_unlink=True)
# Lower billboard assets into relief signs; replace characters with 3D scale figures.
for o in list(bpy.data.objects):
 if o.name in ['KNIGHT','SHADOW','ALCHEMIST']: bpy.data.objects.remove(o,do_unlink=True)
# Repair paths sitting under plaza; add individual paving stones as joined mesh.
verts=[]; faces=[]; mids=[]
for ix in range(-23,24):
 for iy in range(-18,19):
  x=ix*.91; y=iy*.91; z=.235+random.uniform(-.012,.012)
  if abs(x)>21 or abs(y)>15: continue
  if x*x+y*y<26: continue
  k=len(verts); w=.43; h=.43
  verts.extend([(x-w,y-h,z),(x+w,y-h,z),(x+w,y+h,z),(x-w,y+h,z)])
  faces.append((k,k+1,k+2,k+3)); mids.append(random.randrange(5))
me=bpy.data.meshes.new('Paving mesh'); me.from_pydata(verts,[],faces); ob=bpy.data.objects.new('Hand laid stone paving',me); s.collection.objects.link(ob)
for c in [(.28,.27,.23),(.35,.33,.28),(.41,.38,.3),(.31,.3,.27),(.46,.42,.34)]: ob.data.materials.append(mat('Paving tone',c))
for p,i in zip(me.polygons,mids): p.material_index=i
# True south entrance: side wall segments only.
for x in [-14.5,14.5]: cube('South curtain wall',(x,-17,2),(17,1.6,4),sand,.1)
for x in [-5.8,5.8]:
 cube('Gate pier',(x,-16.6,3.7),(2.1,2.8,7.4),pale,.12)
 cube('Gate footing',(x,-16.6,.7),(2.6,3.2,1.2),sand,.12)
for i in range(13):
 a=i*math.pi/12; o=cube('Gate arch voussoir',(5*math.cos(a),-16.6,5+5*math.sin(a)),(1.2,2.6,1.25),sand,.06); o.rotation_euler[1]=-a
# wall buttresses, stone courses, tower roofs
for x in range(-20,21,5):
 cube('North buttress',(x,16,2.8),(.8,1,5.6),pale,.08)
 for z in [1,2.2,3.4]: cube('Masonry course',(x,16.16,z),(4.9,.1,.07),timber,0)
for y in range(-12,14,5):
 for x in [-22.15,22.15]: cube('Side buttress',(x,y,2.5),(1,.8,5),pale,.1)
for x,y in [(-21,-15),(21,-15),(-21,15),(21,15)]:
 cone('Tower slate roof',(x,y,8.3),3.7,.45,3.2,roof); cyl('Tower finial',(x,y,10.3),.12,1,brass)
 for a in range(8):
  theta=a*math.tau/8; cube('Tower merlon',(x+2.8*math.cos(theta),y+2.8*math.sin(theta),6.8),(.65,.65,.9),sand,.06)
# fountain: stone rim, bronze spire, crystal
bpy.data.objects['Water'].data.materials.clear(); bpy.data.objects['Water'].data.materials.append(water)
for i in range(32):
 a=i*math.tau/32; o=cube('Pool coping',(4.65*math.cos(a),4.65*math.sin(a),1.05),(.96,.55,.38),pale,.06); o.rotation_euler[2]=a+math.pi/2
cyl('Monument plinth',(0,0,1.4),1.45,.8,pale); cyl('Monument base',(0,0,1.9),1,.25,brass)
cone('Monument column',(0,0,3.25),.75,.42,2.6,sand); cyl('Monument crown',(0,0,4.6),.8,.3,brass)
cone('Crystal lower',(0,0,5.15),0,.55,.9,bpy.data.materials['Portal Cyan']); cone('Crystal upper',(0,0,6.05),.55,0,.9,bpy.data.materials['Portal Cyan'])
# Warm lanterns.
lampmat=mat('Lantern glow',(1,.42,.08)); bb=lampmat.node_tree.nodes['Principled BSDF']; bb.inputs['Emission Color'].default_value=(1,.35,.06,1); bb.inputs['Emission Strength'].default_value=4
for x,y in [(-7,-10),(7,-10),(-7,10),(7,10),(-19,-5),(19,-5),(-19,6),(19,6)]:
 cyl('Lamp post',(x,y,1.9),.085,3.4,timber,8); cube('Lamp base',(x,y,.4),(.55,.55,.5),sand); cube('Lantern light',(x,y,3.65),(.32,.32,.48),lampmat,.02); cone('Lantern cap',(x,y,4),.35,.02,.3,brass)
# Rounded barrel props.
def barrel(x,y):
 cyl('Barrel',(x,y,.8),.43,1.1,wood,12)
 for z in [.35,.8,1.22]: cyl('Barrel hoop',(x,y,z),.445,.08,steel,12)
# Proper 3D market stalls with striped pitched canvas and timber framing.
for index,y in enumerate([-8,-1,6]):
 x=12.5
 # existing images shifted to hanging service board behind the stall
 for o in bpy.data.objects:
  if o.name in ['MARKET','MARKET.001','BANK'] and abs(o.location.y-y)<1.1:
   o.location=(x,y+1.15,2.65); o.scale=(1.1,1.1,1.1)
 for dx in [-2.65,2.65]:
  for dy in [-1.7,1.7]: cube('Stall oak post',(x+dx,y+dy,2.15),(.15,.15,3.9),timber)
 cube('Stall counter',(x,y-1.25,1.3),(5.4,1.05,.25),wood)
 for j in range(9):
  sx=x-2.8+j*.7
  for sign in [-1,1]:
   mesh=bpy.data.meshes.new('Canvas'); mesh.from_pydata([(sx,y,4.6),(sx+.69,y,4.6),(sx+.69,y+sign*2.15,3.8),(sx,y+sign*2.15,3.8)],[],[(0,1,2,3)]); o=bpy.data.objects.new('Striped canopy',mesh); s.collection.objects.link(o); o.data.materials.append(cloth if j%2==0 else cream)
 for j in range(6):
  cyl('Potion bottle',(x-2+j*.72,y-1.3,1.7),.12,.45,cyan if False else (water if j%2 else brass),12); cyl('Bottle cork',(x-2+j*.72,y-1.3,1.97),.06,.1,timber,8)
 barrel(x+3.1,y+1); barrel(x+3.1,y-.2)
 cube('Stall sign',(x,y-1.85,3.1),(2.5,.12,.5),timber); text(['PAZAR / 01','PAZAR / 02','BANKA'][index],(x,y-1.93,2.96),.22,cream)
# NPC service houses; entrance faces south, accessible off west avenue.
for index,y in enumerate([-8,-1,6]):
 x=-14
 cube('Service house',(x,y+1.0,2.3),(5.8,4.8,4.1),sand,.1)
 for dx in [-2.7,0,2.7]: cube('Half timber post',(x+dx,y-1.45,2.3),(.18,.15,4.1),timber)
 for z in [.6,2.8,4.2]: cube('Half timber beam',(x,y-1.52,z),(5.8,.15,.16),timber)
 cube('Shop door',(x,y-1.56,1.5),(1.4,.12,2.45),timber)
 for dx in [-1.9,1.9]:
  cube('Window',(x+dx,y-1.59,2.1),(1.1,.12,1.2),lampmat)
  cube('Window mullion',(x+dx,y-1.7,2.1),(.07,.1,1.2),wood)
 for sign in [-1,1]:
  o=cube('Sloped slate roof',(x+sign*1.55,y+1,4.85),(3.6,5.6,.22),roof); o.rotation_euler[1]=sign*math.radians(25)
 cube('Chimney',(x-1.8,y+1.8,5.2),(.8,.8,2.2),sand)
 cube('Shop sign',(x,y-1.85,3.4),(2.8,.18,.55),timber)
 text(['DEMIRCI','ZANAAT','SIFACI'][index],(x,y-1.98,3.24),.26,cream)
# Turn existing service art into portrait boards along the avenue.
for name in ['UPGRADE','CRAFT','HOSPITAL']:
 o=bpy.data.objects.get(name)
 if o: o.location.x=-10.65; o.location.z=1.95; o.scale=(.8,.8,.8)
# Real modeled population at 1.8m scale (not rigged).
def person(x,y,robe,npc=False):
 for dx in [-.17,.17]:
  beam('Figure leg',(x+dx,y,.4),(x+dx,y,1),.1,steel); cube('Figure boot',(x+dx,y-.09,.34),(.23,.4,.2),timber)
 cone('Figure tunic',(x,y,1.13),.3,.24,.67,robe)
 for dx in [-.35,.35]: beam('Figure arm',(x+dx,y,1.4),(x+dx*.9,y-.08,.94),.095,steel)
 cyl('Figure neck',(x,y,1.56),.09,.12,skin)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.18,location=(x,y,1.79)); bpy.context.object.name='NPC head' if npc else 'Player head'; bpy.context.object.data.materials.append(skin)
 if npc: cone('NPC hood',(x,y,1.95),.24,0,.32,robe)
for x,y in [(-7,-4),(7,-5),(6,4),(-4,6),(2,-8),(-2,-10),(9,-10),(9,-3),(9,4),(-10,-10),(-10,-3),(-10,4)]: person(x,y,burg if x<0 else cloth,x<-9)
# Trees in the north garden and side strips.
for x,y in [(-18,11),(18,11),(-17,13),(17,13),(-20,-10),(20,-10),(-20,1),(20,1)]:
 cyl('Planter',(x,y,.4),1.15,.5,sand); cyl('Cypress trunk',(x,y,1.5),.15,2.4,timber,10)
 for z,r in [(2,1.2),(3,1),(4,.65)]: cone('Cypress crown',(x,y,z),r,.06,2,leaf)
# Stone portal enclosure.
for x in [-3.9,3.9]: cube('Portal pillar',(x,14,3),(1.2,1.4,5.5),pale); cone('Portal spire',(x,14,6.3),.85,0,1.8,roof)
# Safe spawn marker, no actual networking logic.
for n,l in [('Spawn',(0,-11,.3)),('Portal trigger',(0,12,.3)),('Market zone',(12,0,.3)),('NPC services',(-10,0,.3))]:
 e=bpy.data.objects.new(n,None); s.collection.objects.link(e); e.location=l; e.empty_display_type='CIRCLE'; e.empty_display_size=1; e['purpose']=n
# More readable daylight with cool shadows and warm directional sun.
w=s.world; w.node_tree.nodes['Background'].inputs['Color'].default_value=(.22,.32,.46,1); w.node_tree.nodes['Background'].inputs['Strength'].default_value=.65
bpy.ops.object.light_add(type='SUN',location=(10,-10,20)); sun=bpy.context.object; sun.rotation_euler=(.45,-.5,-.5); sun.data.energy=2.5; sun.data.angle=.15; sun.data.color=(1,.82,.61)
for o in s.objects:
 if o.type=='LIGHT' and o.data.type=='AREA': o.data.energy*=3
cam=s.camera; cam.location=(45,-57,49); cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=67
s.render.resolution_x=1600; s.render.resolution_y=1200; s.render.filepath=R+'/art/maradon/maradon_preview.png'; s.view_settings.look='AgX - Medium High Contrast'
s['status']='Environment concept. NPC and player figures static. Runtime interactions and multiplayer not implemented.'
s['scale']='Meters. Approx 48 x 36 m hub; 6 m main circulation.'
# Default UI opens camera view in material-colored solid shading.
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.shading.color_type='MATERIAL'; area.spaces.active.overlay.show_overlays=False
bpy.ops.file.pack_all(); bpy.ops.wm.save_as_mainfile(filepath=R+'/art/maradon/maradon_hub.blend'); bpy.ops.render.render(write_still=True)
