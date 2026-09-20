extends Node3D
## Candidate art playback only. No damage, resource or collision logic is claimed.

const TYPES := ["cut","return_cut","blood","armor","parry","blade_wave","fire","ice","wind","lightning","shape_wall","shape_well","shape_anchor","shape_platform","seal_mark","seal_burst","grapple","afterimage","rewind","execution","enemy_tell","guard_break","dust","collapse","dash","wall_run","wall_kick","slide","slide_jump","landing","enemy_bolt","ground_wave"]
var kind := "fire"
var age := 0.0
var pieces: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var glow := Color("#bbae88")
var duration := 1.5
var looping := true
var light: OmniLight3D
var ghost_roots: Array[Node3D] = []

func _ready() -> void:
	rng.seed=1924
	duration={"cut":.22,"return_cut":.24,"blood":.32,"armor":.26,"parry":.28,"blade_wave":.55,"fire":.85,"ice":.85,"wind":1.4,"lightning":.32,"shape_wall":1.5,"shape_platform":1.5,"seal_burst":.55,"dash":.34,"wall_kick":.34,"slide_jump":.36,"landing":.45,"execution":.4}.get(kind,1.2)
	_build()

func material(color: Color, emission: float=0.0, opacity: float=1.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=Color(color,opacity)
	m.roughness=.43
	m.emission_enabled=emission>0
	m.emission=color
	m.emission_energy_multiplier=emission*.36
	if opacity<1:
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m

func piece(mesh: Mesh, point: Vector3, mat: Material, velocity:=Vector3.ZERO, role: String="spark") -> MeshInstance3D:
	var n:=MeshInstance3D.new()
	n.mesh=mesh
	n.material_override=mat
	n.position=point
	add_child(n)
	pieces.append({"node":n,"origin":point,"velocity":velocity,"role":role,"rotation":n.rotation,"scale":n.scale})
	return n

func tube(points: PackedVector3Array, width: float, color: Color, emission: float=1.0, role: String="fixed") -> void:
	for i in range(points.size()-1):
		var offset:=points[i+1]-points[i]
		if offset.length()<.0001:continue
		var mesh:=CylinderMesh.new()
		mesh.top_radius=width
		mesh.bottom_radius=width
		mesh.height=offset.length()
		mesh.radial_segments=6
		var n:=piece(mesh,(points[i+1]+points[i])*.5,material(color,emission,.85),Vector3.ZERO,role)
		n.quaternion=Quaternion(Vector3.UP,offset.normalized())
		pieces.back().rotation=n.rotation

func ring(radius: float,y: float,color: Color,phase: float=0.0,extent: float=TAU) -> void:
	var points:=PackedVector3Array()
	for i in range(49):
		var a:=phase+extent*i/48
		points.append(Vector3(cos(a)*radius,y,sin(a)*radius))
	tube(points,.009,color,1.3)

func shards(count: int,color: Color,force: float,origin:=Vector3.ZERO,mode: String="spark") -> void:
	for i in range(count):
		var mesh:=PrismMesh.new()
		mesh.size=Vector3(.025,.11,.025)*(2.8 if mode=="ice" else 1.0)
		var d:=Vector3(rng.randf_range(-1,1),rng.randf_range(.2,1),rng.randf_range(-1,1)).normalized()
		var n:=piece(mesh,origin,material(color,1.2 if mode=="spark" else .2,.9),d*rng.randf_range(.4,force),mode)
		n.rotation=Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)
		pieces.back().rotation=n.rotation

func plume(point: Vector3, size_value: Vector2, color: Color, core_color: Color, style: int=0, seed_value: float=0.0) -> void:
	var quad:=QuadMesh.new();quad.size=size_value
	var mat:=ShaderMaterial.new();mat.shader=load("res://fx_live_r13/plume.gdshader")
	mat.set_shader_parameter("tint",color);mat.set_shader_parameter("core",core_color)
	mat.set_shader_parameter("style",style);mat.set_shader_parameter("seed",seed_value)
	piece(quad,point,mat,Vector3.ZERO,"plume")

func ghost_meshes(node: Node, mat: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():ghost_meshes(child,mat)

func character_echo() -> void:
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	var path:="C:/Users/iridescent/Documents/FantasyParkour/source_assets/art_review/player/body-shade-fixed.glb"
	if not FileAccess.file_exists(path):path="C:/Users/iridescent/Documents/FantasyParkour/game/assets/models/blender/shade_character.glb"
	if doc.append_from_file(path,state)!=OK:return
	var base:=doc.generate_scene(state) as Node3D
	for i in range(3):
		var node:Node3D=base if i==0 else base.duplicate()
		add_child(node);node.position=Vector3((i-1)*.52,-1.25,i*.38)
		var mat:=ShaderMaterial.new();mat.shader=load("res://fx_live_r13/ghost.gdshader")
		mat.set_shader_parameter("strength",.8-float(i)*.2)
		ghost_meshes(node,mat);ghost_roots.append(node)

func stone_surface() -> StandardMaterial3D:
	var mat:=material(Color("#a4a194"));mat.roughness=.87
	var root:="C:/Users/iridescent/Documents/FantasyParkour/game/assets/materials/pbr/castle_wall_slates/"
	var img:=Image.load_from_file(root+"albedo.jpg")
	if img:mat.albedo_texture=ImageTexture.create_from_image(img)
	img=Image.load_from_file(root+"normal.jpg")
	if img:mat.normal_enabled=true;mat.normal_texture=ImageTexture.create_from_image(img);mat.normal_scale=.55
	return mat

func solid_construct() -> void:
	var mat:=stone_surface()
	for row in range(6 if kind=="shape_wall" else 1):
		for column in range(7):
			var block:=BoxMesh.new();block.size=Vector3(.33,.39,.375) if kind=="shape_wall" else Vector3(.36,.27,2.1)
			var p:=Vector3(0,(row-2.5)*.4,(column-3)*.39) if kind=="shape_wall" else Vector3((column-3)*.37,0,0)
			var n:=piece(block,p,mat,Vector3.ZERO,"construct_stone")
			n.rotation.y=rng.randf_range(-.016,.016)
			pieces.back().rotation=n.rotation
	if kind=="shape_wall":
		for side in [-1,1]:
			for row in range(3):
				var y:=(row-1)*.55
				tube(PackedVector3Array([Vector3(side*.172,y+.16,-.13),Vector3(side*.172,y+.23,0),Vector3(side*.172,y-.07,.19),Vector3(side*.172,y-.19,-.03),Vector3(side*.172,y+.16,-.13)]),.006,Color("#c0af81"),.45)

func ribbon(reverse: bool=false) -> void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint:=Color("#bb9e84") if not reverse else Color("#899cad")
	for i in range(48):
		var t:=float(i)/48
		var n:=float(i+1)/48
		var sign:= -1.0 if reverse else 1.0
		var a:=sign*lerpf(-2.7,-.3,t)
		var b:=sign*lerpf(-2.7,-.3,n)
		var vertices:=[Vector3(cos(a)*1.7,.35,sin(a)*1.7),Vector3(cos(a)*1.7*(.77+t*.15),.28,sin(a)*1.7*(.77+t*.15)),Vector3(cos(b)*1.7,.35,sin(b)*1.7),Vector3(cos(b)*1.7*(.77+n*.15),.28,sin(b)*1.7*(.77+n*.15))]
		for j in [0,1,2,2,1,3]:
			surface.set_color(Color(tint,.45+t*.5))
			surface.set_uv(Vector2(t if j<2 else n,1.0 if j in [1,3] else 0.0))
			surface.add_vertex(vertices[j])
	surface.generate_normals()
	var m:=ShaderMaterial.new();m.shader=load("res://fx_live_r13/blade_trail.gdshader");m.set_shader_parameter("tint",tint)
	piece(surface.commit(),Vector3.ZERO,m,Vector3.ZERO,"slash")

func _build() -> void:
	match kind:
		"cut","return_cut","blade_wave","execution":
			ribbon(kind=="return_cut")
			if kind=="execution":shards(22,Color("#8b3137"),2.8,Vector3(0,.35,-1.5),"blood")
			if kind=="blade_wave":plume(Vector3(0,.35,0),Vector2(2.4,1.2),Color("#617483"),Color("#a8b7b5"),2)
		"fire":
			glow=Color("#e58d3f")
			for i in range(5):
				plume(Vector3(sin(i*2.4)*.24,.26+i*.09,i*.23),Vector2(1.3,1.7-float(i)*.13),Color("#b53513"),Color("#ffdc91"),0,i*2.31)
			plume(Vector3(0,.54,.5),Vector2(2.4,2.8),Color("#572e25"),Color("#bc6025"),1,7)
			shards(46,glow,2.8,Vector3(0,.3,0))
		"ice":
			glow=Color("#9ec9d8")
			for i in range(7):
				var p:=PrismMesh.new();p.size=Vector3(.19,.8+rng.randf()*.45,.2)
				var n:=piece(p,Vector3(rng.randf_range(-.5,.5),.2,rng.randf_range(-.4,.4)),material(glow,.4,.8),Vector3.ZERO,"crystal")
				n.rotation.z=rng.randf_range(-.4,.4)
			shards(20,glow,2.2,Vector3.ZERO,"ice")
			plume(Vector3(0,.0,0),Vector2(2.4,2.1),Color("#6d9ba2"),Color("#b5ced0"),1)
		"wind","shape_well":
			glow=Color("#b4c8af")
			for strand in range(4):
				var path:=PackedVector3Array()
				for i in range(61):
					var t:=float(i)/60;var a:=t*TAU*1.6+strand*TAU/4
					path.append(Vector3(cos(a)*(.35+t*.55),t*2.5-.65,sin(a)*(.35+t*.55)))
				tube(path,.013,glow,.65,"wind")
			shards(22,Color("#998d78"),1.3,Vector3(0,-.6,0),"dust")
			plume(Vector3(0,.55,0),Vector2(2.1,2.8),Color("#728b81"),Color("#a7b99d"),1)
		"lightning":
			glow=Color("#b3b6e3")
			for branch in range(3):
				var path:=PackedVector3Array()
				for i in range(15):
					path.append(Vector3((float(i)/14-.5)*3,rng.randf_range(-.22,.22)+branch*.3,sin(i*.7+branch)*.24))
				tube(path,.013 if branch else .023,glow,2.0,"lightning")
		"shape_wall","shape_platform":
			glow=Color("#99b5a1")
			solid_construct()
			ring(1.6,-1.23,glow)
			shards(18,Color("#9c9584"),1.5,Vector3(0,-1.1,0),"dust")
		"seal_mark","seal_burst","enemy_tell","guard_break","parry":
			glow=Color("#bca3cb") if kind.begins_with("seal") else Color("#ddbc7a")
			ring(.9,0,glow);ring(.68,.015,glow,.2,5.4)
			for i in range(8):
				var a:=i*TAU/8
				tube(PackedVector3Array([Vector3(cos(a)*.70,0,sin(a)*.70),Vector3(cos(a+.07)*1.1,0,sin(a+.07)*1.1),Vector3(cos(a-.04)*1.03,0,sin(a-.04)*1.03)]),.012,glow)
			if kind!="seal_mark":shards(35,glow,2.6)
		"shape_anchor","grapple":
			glow=Color("#ceb98a")
			var jewel:=PrismMesh.new();jewel.size=Vector3(.26,.58,.26)
			piece(jewel,Vector3(0,.8,-.7),material(glow,1.2),Vector3.ZERO,"crystal")
			for i in range(20):
				var points:=PackedVector3Array()
				for j in range(17):
					var a:=j*TAU/16
					points.append(Vector3(cos(a)*.065,i*.082-.8+sin(a)*.10,sin(float(i)/20*PI)*.5-.7))
				tube(points,.012,Color("#716750"),.35,"chain")
			for a in [0.0,PI/2]:ring(.36,.8,glow,a,2.8)
		"afterimage","rewind":
			glow=Color("#a89cb9")
			character_echo()
			for i in range(3):ring(.6,-.65,glow,i,2.2)
			plume(Vector3(0,-.4,0),Vector2(2.4,2.7),Color("#584b73"),Color("#b3a4c4"),1)
		"blood":
			glow=Color("#761c24")
			shards(32,glow,3,Vector3.ZERO,"blood")
		"armor":
			shards(40,Color("#ddaa68"),3.5)
		"dust","collapse":
			glow=Color("#ad9b79")
			shards(45,glow,2.4,Vector3.ZERO,"dust")
			plume(Vector3(0,.1,0),Vector2(3.0,2.5),Color("#63523e"),Color("#b09c7f"),1)
		"dash":
			glow=Color("#a297bf")
			for i in range(9):
				var a:=i*TAU/9;var p:=PackedVector3Array()
				for j in range(16):
					var z:=float(j)/15*3.0-1.5;var r:=.26+sin(j*PI/15)*.4
					p.append(Vector3(cos(a)*r,sin(a)*r,z))
				tube(p,.007,glow,.5)
			plume(Vector3.ZERO,Vector2(1.5,2.0),Color("#5a4d75"),glow,2)
		"wall_run","wall_kick":
			glow=Color("#9b8a6b")
			var wall:=BoxMesh.new();wall.size=Vector3(.18,2.6,3)
			piece(wall,Vector3(-.6,0,0),material(Color("#343b36")),Vector3.ZERO,"wall")
			for i in range(5):
				var z:=float(i)*.34-.7
				tube(PackedVector3Array([Vector3(-.49,-.2,z),Vector3(-.46,-.17,z+.13)]),.018,Color("#867458"),0.0)
			shards(26,glow,2.4 if kind=="wall_kick" else 1.2,Vector3(-.45,-.2,0),"dust")
			plume(Vector3(-.3,-.15,0),Vector2(1.2,1.6),Color("#71654f"),glow,1)
		"slide","slide_jump","landing":
			glow=Color("#ad9874")
			var lanes:=2 if kind!="landing" else 6
			for i in range(lanes):
				var point:=Vector3((i-.5)*.5,-1.1,0) if lanes==2 else Vector3(cos(i*TAU/6)*.4,-1.1,sin(i*TAU/6)*.4)
				shards(9,glow,1.7,point,"dust")
				plume(point,Vector2(.9,1.4),Color("#6c5e47"),glow,1,i*1.7)
			if kind=="slide_jump":
				tube(PackedVector3Array([Vector3(0,-1.0,.7),Vector3(0,-.3,0),Vector3(0,.4,-.6)]),.012,Color("#a9b69a"),.4)
		"enemy_bolt":
			glow=Color("#c88573")
			var crystal:=PrismMesh.new();crystal.size=Vector3(.16,.16,.75)
			piece(crystal,Vector3.ZERO,material(Color("#412b25"),.1),Vector3.ZERO,"bolt")
			for i in range(3):plume(Vector3(0,0,i*.26),Vector2(.55,.95),Color("#8f3527"),glow,0,i*.8)
		"ground_wave":
			glow=Color("#ba7959")
			for i in range(11):
				var x:=(i-5)*.25;var m:=PrismMesh.new();m.size=Vector3(.23,.35+sin(i*.7)*.12,.30)
				piece(m,Vector3(x,-1.08,0),material(Color("#635c51")),Vector3.ZERO,"rock")
				plume(Vector3(x,-.8,0),Vector2(.5,1.2),Color("#713b25"),glow,1,i*.57)
	light=OmniLight3D.new();light.light_color=glow;light.light_energy=.8;light.omni_range=4
	add_child(light)

func _process(delta: float) -> void:
	age+=delta
	if looping:age=fmod(age,duration)
	seek(age/duration)

func seek(t: float) -> void:
	var fade:=smoothstep(0,.10,t)*(1.0-smoothstep(.58,1.0,t))
	if is_instance_valid(light):light.light_energy=fade*1.1
	for i in range(ghost_roots.size()):
		ghost_roots[i].scale=Vector3.ONE*maxf(.001,fade)
	for item in pieces:
		var n:MeshInstance3D=item.node
		var moving:bool=item.role in ["spark","ice","blood","dust"]
		n.position=item.origin+item.velocity*t*.8-(Vector3.UP*t*t*.8 if moving else Vector3.ZERO)
		n.rotation=item.rotation
		n.scale=item.scale*maxf(.001,fade)
		if item.role=="slash":n.rotation.y=t*.4;n.scale=Vector3.ONE
		if item.role=="wall":n.scale=Vector3.ONE
		if item.role=="construct_stone":
			var progress:=smoothstep(0.0,.22,t)*(1.0-smoothstep(.84,1.0,t))
			n.scale=Vector3.ONE*maxf(.001,progress)
			n.position=item.origin+Vector3.DOWN*(1.0-progress)*.65
		if item.role=="crystal":n.scale=Vector3.ONE*maxf(.001,smoothstep(0,.25,t))*(1.0-smoothstep(.8,1,t))
		if item.role=="ember":n.scale*=.8+sin(t*17+n.position.z*5)*.2
		if item.role=="lightning":n.scale.y*=.7+.3*sin(t*29)
		if n.material_override is ShaderMaterial:
			n.material_override.set_shader_parameter("age",t*2)
			n.material_override.set_shader_parameter("strength",fade)
