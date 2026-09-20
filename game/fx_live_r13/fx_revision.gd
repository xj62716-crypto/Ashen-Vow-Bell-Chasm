extends "res://fx_live_r13/fx_base.gd"
const ECHO_SCENE=preload("res://fx_live_r13/echo.glb")

var chain_mesh: MeshInstance3D
var line_anchor: Node3D
var echo_materials: Array[ShaderMaterial]=[]
var echo_origins: Array[Vector3]=[]
var echo_animations: Array[AnimationPlayer]=[]
var line_start:=Vector3(-.8,-.45,1.0)
var line_end:=Vector3(.7,1.4,-1.4)
var line_slack:=.5

func _ready() -> void:
	super._ready()
	if kind=="grapple":duration=1.8
	if kind in ["afterimage","rewind"]:duration=1.5

func stone_surface() -> StandardMaterial3D:
	var m:=material(Color("#5a5a50"));m.roughness=.88
	m.albedo_texture=load("res://fx_live_r13/stone_color.jpg")
	m.normal_enabled=true;m.normal_texture=load("res://fx_live_r13/stone_normal.jpg");m.normal_scale=.25
	m.roughness_texture=load("res://fx_live_r13/stone_roughness.jpg")
	return m

func character_echo() -> void:
	for i in range(3):
		var node:Node3D=ECHO_SCENE.instantiate()
		add_child(node);node.position=Vector3((i-1)*.60,-1.25,i*.42)
		var m:=ShaderMaterial.new();m.shader=load("res://fx_live_r13/ghost.gdshader")
		ghost_meshes(node,m);ghost_roots.append(node);echo_materials.append(m);echo_origins.append(node.position)
		var players:=node.find_children("*","AnimationPlayer",true,false)
		if not players.is_empty():
			var player:=players[0] as AnimationPlayer
			if player.has_animation("body_run"):
				player.play("body_run");player.seek((.12+i*.23)*player.get_animation("body_run").length,true);player.pause()
				echo_animations.append(player)

func _build() -> void:
	if kind in ["afterimage","rewind"]:
		glow=Color("9584ad");character_echo()
		plume(Vector3(0,.25,0),Vector2(.75,.65),Color("46354f"),Color("756887"),1)
	elif kind=="grapple":
		glow=Color("#c9b48b")
		chain_mesh=MeshInstance3D.new();chain_mesh.material_override=material(Color("#aa9d78"),.65,.9);add_child(chain_mesh)
		line_anchor=Node3D.new();line_anchor.position=line_end;add_child(line_anchor)
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		if doc.append_from_file("res://fx_live_r13/anchor.glb",state)==OK:
			var anchor:=doc.generate_scene(state) as Node3D;line_anchor.add_child(anchor);anchor.scale=Vector3.ONE*.52;anchor.position=Vector3(0,-.50,0)
		light=OmniLight3D.new();light.position=line_end;light.light_color=glow;light.omni_range=4;add_child(light)
	elif kind=="blood":
		glow=Color("#711a23")
		for i in range(50):
			var sphere:=SphereMesh.new();sphere.radius=.004+rng.randf()*.008;sphere.height=sphere.radius*rng.randf_range(3.0,7.0)
			sphere.radial_segments=8;sphere.rings=4
			var velocity:=Vector3(rng.randf_range(.3,2.9),rng.randf_range(-.7,1.0),rng.randf_range(-.7,.7))
			var drop:=piece(sphere,Vector3(-.6,.22,0),material(glow,0,.9),velocity,"blood")
			drop.quaternion=Quaternion(Vector3.UP,velocity.normalized());pieces.back().rotation=drop.rotation
		var quad:=QuadMesh.new();quad.size=Vector2(2.1,.95)
		var m:=ShaderMaterial.new();m.shader=load("res://fx_live_r13/blood_mist.gdshader")
		piece(quad,Vector3(.25,.3,0),m,Vector3.ZERO,"plume")
	else:
		super._build()

func set_line_endpoints(start: Vector3,finish: Vector3,slack: float) -> void:
	line_start=start;line_end=finish;line_slack=maxf(0,slack)
	if is_instance_valid(line_anchor):line_anchor.position=finish
	if is_instance_valid(light):light.position=finish

func seek(t: float) -> void:
	super.seek(t)
	var fade:=smoothstep(0,.12,t)*(1.0-smoothstep(.64,1.,t))
	for i in range(ghost_roots.size()):
		ghost_roots[i].scale=Vector3.ONE
		ghost_roots[i].position=echo_origins[i]
		if kind=="rewind":ghost_roots[i].position+=Vector3(0,0,-smoothstep(.24,.72,t)*float(i)*.28)
		echo_materials[i].set_shader_parameter("strength",fade*(.85-float(i)*.18))
		echo_materials[i].set_shader_parameter("age",t*2+float(i)*.2)
	if kind=="rewind":
		for i in range(echo_animations.size()):
			var player:=echo_animations[i]
			player.seek(fposmod(.12+i*.23-t*.5,1.0)*player.get_animation("body_run").length,true)
	if kind=="grapple" and is_instance_valid(chain_mesh):
		var reach:=smoothstep(0,.18,t)*(1.-smoothstep(.83,1.,t))
		var finish:=line_start.lerp(line_end,reach)
		var sag:=(line_slack*(1.-smoothstep(.24,.56,t))+.08)*reach
		_make_chain(finish,sag)

func _make_chain(finish: Vector3,sag: float) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var delta:=finish-line_start
	if delta.length()<.07:chain_mesh.visible=false;return
	chain_mesh.visible=true
	# Sample arc length so the links keep their spacing while slack changes.
	var distances:=PackedFloat32Array([0.0]);var previous:=line_start
	for sample in range(1,65):
		var u:=float(sample)/64.0
		var point:=line_start.lerp(finish,u)+Vector3.DOWN*(sin(u*PI)*sag)
		distances.append(distances[-1]+point.distance_to(previous));previous=point
	var links:=maxi(1,int(distances[-1]/.097));var segment:=1
	for link in range(links):
		var distance_along:=(float(link)+.5)*distances[-1]/float(links)
		while segment<64 and distances[segment]<distance_along:segment+=1
		var u:=(float(segment-1)+inverse_lerp(distances[segment-1],distances[segment],distance_along))/64.0
		var center:=line_start.lerp(finish,u)+Vector3.DOWN*(sin(u*PI)*sag)
		var axis:=(delta+Vector3.DOWN*cos(u*PI)*PI*sag).normalized()
		var reference:=Vector3.RIGHT if absf(axis.dot(Vector3.UP))>.98 else Vector3.UP
		var side:=axis.cross(reference).normalized();var up:=side.cross(axis).normalized()
		var width:=side if link%2==0 else up
		var normal:=axis.cross(width).normalized()
		var verts:Array[Vector3]=[]
		for j in range(12):
			var a:=j*TAU/12
			var local:=axis*cos(a)*.063+width*sin(a)*.040
			var radial:=(axis*cos(a)+width*sin(a)).normalized()
			for k in range(5):
				var b:=k*TAU/5
				verts.append(center+local+.008*(radial*cos(b)+normal*sin(b)))
		for j in range(12):
			for k in range(5):
				var a:=j*5+k;var b:=j*5+(k+1)%5;var c:=((j+1)%12)*5+k;var d:=((j+1)%12)*5+(k+1)%5
				for index in [a,b,c,c,b,d]:st.add_vertex(verts[index])
	st.generate_normals();chain_mesh.mesh=st.commit()
