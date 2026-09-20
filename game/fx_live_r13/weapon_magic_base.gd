extends Node3D
## Layered weapon magic. The caller supplies sockets, hit point, and world time.
## Geometry is independent of the weapon: disabling this node restores the model.
var profession := "staff"
var element := "fire"
var tint := Color("dca066")
var charge: Node3D
var missile: Node3D
var burst: Node3D
var motes: MultiMeshInstance3D
var wisps: Array[Dictionary] = []
var curves: Array[Dictionary] = []
var shard_material: StandardMaterial3D
var lamp: OmniLight3D
var rng := RandomNumberGenerator.new()
var released_from := Vector3.ZERO
var shard_data: Array[Dictionary] = []
var projectile_trail: MeshInstance3D
var launch_initialized := false
var elemental_structure: Node3D
var elemental_pieces: Array[MeshInstance3D] = []
var lightning_branches: Array[MeshInstance3D] = []
var impact_core: Node3D
var impact_ribbons: Array[MeshInstance3D] = []
var ribbon_materials: Array[ShaderMaterial] = []

func set_launch_origin(origin: Vector3) -> void:
	released_from=origin
	launch_initialized=true

func crystal_mesh(length_value: float,width: float) -> ArrayMesh:
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(width*.15,length_value*.65,0)
	var bottom := Vector3(-width*.12,-length_value*.35,width*.08)
	for i in range(6):
		var a := float(i)*TAU/6;var b := float(i+1)*TAU/6
		var p := Vector3(cos(a)*width,sin(a*2)*length_value*.06,sin(a)*width*.72)
		var q := Vector3(cos(b)*width,sin(b*2)*length_value*.06,sin(b)*width*.72)
		for v in [top,p,q,bottom,q,p]:st.add_vertex(v)
	st.generate_normals();return st.commit()

func material(color: Color, energy: float = 0.0, opacity: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, opacity)
	m.roughness = .48
	m.metallic = .15
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = energy > 0
	m.emission = color
	m.emission_energy_multiplier = energy
	if opacity < 1: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func tube_mesh(points: PackedVector3Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var direction := (points[i+1]-points[i]).normalized()
		if direction.length_squared() < .1: continue
		var side := direction.cross(Vector3.UP if absf(direction.y)<.9 else Vector3.RIGHT).normalized()
		var up := side.cross(direction).normalized()
		for j in range(5):
			var a := float(j)*TAU/5
			var b := float(j+1)*TAU/5
			var r := (cos(a)*side+sin(a)*up)*width
			var s := (cos(b)*side+sin(b)*up)*width
			for p in [points[i]+r,points[i]+s,points[i+1]+r,points[i+1]+r,points[i]+s,points[i+1]+s]: st.add_vertex(p)
	st.generate_normals()
	return st.commit()

func curve(parent: Node3D, points: PackedVector3Array, width: float, color: Color, energy: float = 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = tube_mesh(points,width)
	node.material_override = material(color,energy)
	parent.add_child(node)
	return node

func ribbon(parent: Node3D,points: PackedVector3Array,width: float,color: Color,seed_value: float) -> MeshInstance3D:
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var tangent := (points[i+1]-points[i]).normalized()
		var side := tangent.cross(Vector3.FORWARD if absf(tangent.z)<.9 else Vector3.UP).normalized()
		var u := float(i)/(points.size()-1);var v := float(i+1)/(points.size()-1)
		var a := side*width*sin(u*PI);var b := side*width*sin(v*PI)
		var vertices := [points[i]-a,points[i]+a,points[i+1]-b,points[i+1]+b]
		var coords := [Vector2(u,0),Vector2(u,1),Vector2(v,0),Vector2(v,1)]
		for index in [0,1,2,2,1,3]:st.set_uv(coords[index]);st.add_vertex(vertices[index])
	var node := MeshInstance3D.new();node.mesh=st.commit()
	var shader := ShaderMaterial.new();shader.shader=load("res://fx_live_r13/magic_ribbon.gdshader");shader.set_shader_parameter("tint",color);shader.set_shader_parameter("seed",seed_value)
	node.material_override=shader;parent.add_child(node);ribbon_materials.append(shader)
	return node

func wisp(parent: Node3D, size: Vector2, color: Color, style: int, seed_value: float) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = load("res://fx_live_r13/magic_smoke.gdshader" if style==3 else "res://fx_live_r13/magic_wisp.gdshader")
	m.set_shader_parameter("tint",color)
	m.set_shader_parameter("style",style)
	m.set_shader_parameter("seed",seed_value)
	node.material_override = m
	parent.add_child(node)
	wisps.append({"node":node,"material":m,"seed":seed_value,"owner":parent})

func _ready() -> void:
	rng.seed = 7152
	charge=Node3D.new();missile=Node3D.new();burst=Node3D.new();impact_core=Node3D.new()
	add_child(charge);add_child(missile);add_child(burst);add_child(impact_core)
	# Broken calligraphic arcs and short chevrons, kept away from the aim point.
	for ring in range(2):
		var points := PackedVector3Array()
		for i in range(49):
			var a := float(i)/48*TAU*.88+ring*.6
			points.append(Vector3(cos(a),sin(a),0)*(.075+.035*ring))
		var node := curve(charge,points,.0015,tint,1.3)
		curves.append({"node":node,"rate":.45 if ring==0 else -.7})
	for i in range(7):
		var angle := i*TAU/7
		var radial := Vector3(cos(angle),sin(angle),0)
		var tangent := Vector3(-sin(angle),cos(angle),0)
		curve(charge,PackedVector3Array([radial*.093-tangent*.006,radial*.107,radial*.093+tangent*.006]),.0012,tint,1.1)
	for i in range(7): wisp(charge,Vector2(.065,.13),tint,0,float(i)*2.13)
	# Uneven inner sigils distinguish a hand-worked spell from a mechanical dial.
	for i in range(4):
		var theta := i*TAU/4+.3
		var radial := Vector3(cos(theta),sin(theta),0)
		var tangent := Vector3(-sin(theta),cos(theta),0)
		var shape := PackedVector3Array([radial*.048-tangent*.009,radial*.067,radial*.052+tangent*.010])
		if i%2==1:shape.append(radial*.044+tangent*.002)
		curve(charge,shape,.0011,tint,1.6)
	var style := 2 if element in ["wind","storm","seal_burst"] or element.begins_with("shape") else 1 if element in ["ice","lightning","parry"] else 0
	for i in range(4): wisp(missile,Vector2(.26,.40) if element=="fire" else Vector2(.15,.24),tint,style,float(i)*3.71)
	elemental_structure=Node3D.new();missile.add_child(elemental_structure)
	if element=="ice":
		# One long irregular core with smaller splinters, directed along travel.
		for i in range(5):
			var crystal := MeshInstance3D.new()
			crystal.mesh=crystal_mesh(.29 if i==0 else .17,.022 if i==0 else .012);crystal.rotation.x=PI*.5
			crystal.position=Vector3(sin(i*2.4)*.026,cos(i*2.4)*.026,.045) if i else Vector3.ZERO
			crystal.material_override=material(Color("648e9f") if i%2 else Color("aec4ce"),.12)
			elemental_structure.add_child(crystal);elemental_pieces.append(crystal)
	elif element in ["wind","storm","seal_burst"]:
		for i in range(3):
			var points := PackedVector3Array()
			for j in range(45):
				var u := float(j)/44
				var theta := u*TAU*1.35+i*TAU/3
				var radius := .12*sin(u*PI)
				points.append(Vector3(cos(theta)*radius,sin(theta)*radius,(u-.5)*.36))
			var strand := ribbon(elemental_structure,points,.038,tint,float(i))
			elemental_pieces.append(strand)
	elif element=="fire":
		for i in range(5):wisp(missile,Vector2(.18,.42),Color("e6a24c") if i%2 else Color("aa3d1c"),0,31.0+i*2.3)
	if element=="lightning":
		for i in range(4):
			var branch := MeshInstance3D.new();branch.material_override=material(tint,2.4 if i==0 else 1.1,.85 if i==0 else .5)
			add_child(branch);lightning_branches.append(branch)
	# Near-camera metal contact needs compact sparks, not metre-wide fire cards.
	var burst_size := Vector2(.11,.16) if profession=="blade" else Vector2(.65,.80) if element=="fire" else Vector2(.35,.50)
	var burst_count := 3 if profession=="blade" else 16 if element=="fire" else 2 if element=="wind" else 9
	for i in range(burst_count):
		wisp(burst,burst_size*(1+.08*(i%3)),tint,1 if profession=="blade" else style,float(i)*1.49)
	if profession=="staff":
		for i in range(5): wisp(burst,Vector2(.60,.75),Color("302b29") if element=="fire" else Color("647b7e"),3,float(i)*5.17)
		wisp(impact_core,Vector2(.85,.85) if element=="fire" else Vector2(.42,.42),tint,4,5.0)
		if element in ["wind","storm","seal_burst"]:
			for i in range(3):
				var points := PackedVector3Array()
				for j in range(33):
					var u := float(j)/32
					var angle := u*PI*.60+i*TAU/3+.2
					var radius := .20+.24*u
					points.append(Vector3(cos(angle)*radius,sin(angle)*radius,sin(angle*1.2)*.18))
				var arc := ribbon(burst,points,.048 if element=="wind" else .015,tint,float(i)*3.7)
				arc.rotation.x=(i-1)*.45;arc.rotation.y=(i-1)*.30;impact_ribbons.append(arc)
		if element=="ice":
			for i in range(6):
				var points := PackedVector3Array()
				var radial := Vector3(cos(i*TAU/6),sin(i*TAU/6),0)
				var tangent := Vector3(-radial.y,radial.x,0)
				for j in range(6):
					var u := float(j)/5
					points.append(radial*(.07+.24*u)+tangent*sin(j*5.2+i)*.035*u)
				impact_ribbons.append(ribbon(burst,points,.008,tint,float(i)*3.7))
	projectile_trail=MeshInstance3D.new()
	projectile_trail.material_override=material(tint,1.4,.45)
	add_child(projectile_trail)
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	mm.mesh=crystal_mesh(.10,.015) if element=="ice" else crystal_mesh(.025,.0018);mm.instance_count=48
	motes=MultiMeshInstance3D.new();motes.multimesh=mm
	shard_material=material(Color("ad8e68") if element=="parry" else Color("83a9bc") if element=="ice" else tint,.12 if element=="ice" else .7)
	shard_material.vertex_color_use_as_albedo=true
	motes.material_override=shard_material
	add_child(motes)
	for i in range(48):
		var direction := Vector3(rng.randf_range(-1,1),rng.randf_range(-.1,1),rng.randf_range(-1,1)).normalized()
		shard_data.append({"direction":direction,"speed":rng.randf_range(.4,1.4) if profession=="blade" else rng.randf_range(.6,2.6),"delay":rng.randf_range(0,.06),"scale":rng.randf_range(.5,1.4)})
	lamp=OmniLight3D.new();lamp.light_color=tint;lamp.omni_range=3.0
	add_child(lamp)

func animate(age: float,release: float,hit: float,palm: Vector3,origin: Vector3,target: Vector3,enabled: bool=true) -> void:
	visible=enabled
	if not enabled: return
	var preparation := smoothstep(.02,maxf(release,.03),age)
	var after := maxf(0,age-hit)
	var charge_fade := preparation*(1-smoothstep(release,release+.08,age))
	charge.visible=profession=="staff" and charge_fade>.001
	charge.global_position=palm+Vector3(0,.025,-.025)
	charge.rotation=Vector3(-.22,0,0)
	charge.scale=Vector3.ONE*(.55+.45*preparation)
	for item in curves: item.node.rotation.z=age*item.rate
	if age<=release or not launch_initialized: set_launch_origin(origin)
	var travel := clampf(inverse_lerp(release,hit,age),0,1)
	var point := released_from.lerp(target,travel)
	missile.visible=profession=="staff" and age>=release and age<hit
	missile.global_position=point
	var trajectory := target-released_from
	if trajectory.length_squared()>.00001:
		missile.global_basis=Basis.looking_at(trajectory.normalized(),Vector3.RIGHT if absf(trajectory.normalized().y)>.95 else Vector3.UP)
	elemental_structure.rotation.z=age*(2.2 if element in ["wind","storm"] else .35)
	for i in range(lightning_branches.size()):
		var branch := lightning_branches[i]
		branch.visible=age>=release and age<hit+.085
		if not branch.visible:continue
		var direction := trajectory.normalized()
		var side := direction.cross(Vector3.UP if absf(direction.y)<.95 else Vector3.RIGHT).normalized()
		var up := side.cross(direction).normalized()
		var points := PackedVector3Array()
		var seed_step := floorf(age*24)
		for j in range(19):
			var u := float(j)/18
			var end := target if i==0 else target+side*sin(i*4.1)*.28+up*cos(i*3.3)*.22
			var start := released_from if i==0 else released_from.lerp(target,.40+i*.12)
			var jitter := sin(u*PI)*(.14 if i==0 else .075)
			points.append(start.lerp(end,u)+(side*sin(j*17.3+seed_step*2.1+i)+up*cos(j*11.7+seed_step*1.6+i))*jitter)
		branch.mesh=tube_mesh(points,.0032 if i==0 else .0016)
	burst.visible=age>=hit and after<.85
	burst.global_position=target
	impact_core.visible=profession=="staff" and age>=hit and after<.15
	impact_core.global_position=target
	impact_core.scale=Vector3.ONE*(.3+minf(after/.07,1.)*1.7)
	var power := (1-smoothstep(.10,.7,after))*smoothstep(0,.018,after)
	for item in wisps:
		var seed_value: float=item.seed
		var node: MeshInstance3D=item.node
		var amount: float
		if item.owner==charge:
			var theta := seed_value+age*3
			node.position=Vector3(cos(theta),sin(theta),sin(theta*1.7)*.18)*(.045+.03*(1-preparation))
			amount=charge_fade*.7
		elif item.owner==impact_core:
			node.position=Vector3.ZERO
			amount=(1-smoothstep(.015,.15,after))*1.1
		elif item.owner==missile:
			node.position=Vector3(sin(seed_value)*.027,cos(seed_value)*.025,.025*sin(seed_value*2))
			amount=1.0
		else:
			var radial := Vector3(sin(seed_value*2.3),cos(seed_value*1.7)*.8,cos(seed_value*3.1)*.35)
			var expansion := (1-exp(-after*8.0))*(.52 if element=="fire" else .30)
			node.position=radial*(.05+expansion)+Vector3.UP*after*.35
			node.scale=Vector3.ONE*(.55+after*1.6)
			amount=power*(.48 if element=="fire" else .8 if profession=="staff" else .15)
		item.material.set_shader_parameter("age",age)
		item.material.set_shader_parameter("strength",amount)
	for i in range(impact_ribbons.size()):
		var ring := impact_ribbons[i]
		ring.scale=Vector3.ONE*(.45+(1-exp(-after*7.0))*2.1)
		ring.rotation.z=after*(2.2 if element=="wind" else .35)*(1 if i%2 else -1)
	for shader in ribbon_materials:
		shader.set_shader_parameter("age",age)
		shader.set_shader_parameter("strength",power if age>=hit else 1.0)
	# Trajectory comes from actual launch and hit positions, never screen-fixed.
	projectile_trail.visible=missile.visible and element!="lightning"
	if projectile_trail.visible:
		var points := PackedVector3Array()
		for i in range(17):
			var u := maxf(0,travel-.22+float(i)/16*.22)
			var radius := .024*sin(float(i)/16*PI)
			points.append(released_from.lerp(target,u)+Vector3(sin(u*31+age*8),cos(u*27+age*8),0)*radius)
		projectile_trail.mesh=tube_mesh(points,.007 if element!="lightning" else .010)
	motes.visible=burst.visible and element in ["parry","fire","ice","lightning"]
	motes.multimesh.visible_instance_count=24 if element=="parry" else 23 if element=="ice" else 36
	motes.global_position=target
	for i in range(shard_data.size()):
		var row: Dictionary=shard_data[i]
		var t := maxf(0,after-float(row.delay))
		var fade := 1-smoothstep(.20,.62+float(row.delay),t)
		var position_value: Vector3=row.direction*float(row.speed)*t+Vector3.DOWN*t*t*.85
		var size := float(row.scale)*fade*(1.6 if element=="ice" else 1.0)
		var direction: Vector3=row.direction
		var spin := Basis(Quaternion(Vector3.UP,direction)) if element!="ice" else Basis.from_euler(Vector3(t*4,i,t*3))
		var transform := Transform3D(spin.scaled(Vector3.ONE*maxf(.0001,size)),position_value)
		motes.multimesh.set_instance_transform(i,transform)
		motes.multimesh.set_instance_color(i,Color(1,.8+.2*fade,.55+.45*fade,1))
	lamp.global_position=target if burst.visible else origin
	lamp.light_energy=power*(.22 if profession=="blade" else 1.4) if burst.visible else charge_fade*.40
	lamp.visible=charge.visible or burst.visible

func reset() -> void:
	visible=false
	released_from=Vector3.ZERO
	launch_initialized=false
	for node in [charge,missile,burst,impact_core,motes,projectile_trail,lamp]:
		if is_instance_valid(node):node.visible=false
	for node in lightning_branches:node.visible=false
