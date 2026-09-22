class_name CitadelDressing
extends RefCounted
const MeshSanitizer=preload("res://scripts/environment/environment_mesh_sanitizer.gd")

static var _assets: Dictionary = {}

static func asset(parent: Node3D, name: String, position: Vector3, scale_value: Vector3 = Vector3.ONE, yaw: float = 0.0) -> Node3D:
	if not _assets.has(name):
		# The chosen dark stone arch replaces the older bright, foil-like bay.
		_assets[name] = load("res://environment_live/modules/C02_pointed_arch.scn" if name=="gothic_bay" else "res://assets/models/blender/"+name+".glb")
	var model := (_assets[name] as PackedScene).instantiate() as Node3D
	model.position = position
	model.scale = scale_value
	model.rotation.y = yaw
	parent.add_child(model)
	model.set_meta("static_dressing",true)
	return model

static func batch_static(parent: Node3D) -> void:
	# Share repeated Blender mesh parts in local city blocks; leave moving and
	# currently hidden route geometry attached to its original gameplay parent.
	var groups: Dictionary={}
	for node in parent.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh==null:continue
		var ancestor: Node=mesh
		var authored: bool=false
		var dynamic: bool=false
		while ancestor!=parent and ancestor!=null:
			authored=authored or ancestor.has_meta("static_dressing")
			dynamic=dynamic or ancestor is AnimatableBody3D or ancestor is LanternAcolyte or ancestor is TerrainDevice
			if ancestor is Node3D and not ancestor.visible:dynamic=true
			ancestor=ancestor.get_parent()
		if not authored or dynamic:continue
		var key := "%d/%d/%d" % [mesh.mesh.get_instance_id(),mesh.material_override.get_instance_id() if mesh.material_override else 0,floori(parent.to_local(mesh.global_position).z/32)]
		if not groups.has(key):groups[key]=[]
		groups[key].append(mesh)
	for parts: Array in groups.values():
		if parts.size()<2:continue
		var multi := MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=MeshSanitizer.sanitize_mesh(parts[0].mesh) if parts[0].mesh is ArrayMesh else parts[0].mesh
		multi.instance_count=parts.size()
		for i in range(parts.size()):
			multi.set_instance_transform(i,parent.global_transform.affine_inverse()*parts[i].global_transform)
			parts[i].hide()
		var batch := MultiMeshInstance3D.new()
		batch.multimesh=multi
		batch.material_override=parts[0].material_override
		parent.add_child(batch)

static func paving(parent: Node3D, center: Vector3, size: Vector2) -> void:
	var nx: int = maxi(1,ceili(size.x/2))
	var nz: int = maxi(1,ceili(size.y/2))
	var tile := Vector2(size.x/nx,size.y/nz)
	var source := asset(parent,"paving_tile",Vector3.ZERO)
	for part in source.find_children("*","MeshInstance3D",true,false):
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = part.mesh
		instances.instance_count = nx*nz
		var local: Transform3D = source.global_transform.affine_inverse()*part.global_transform
		for x in range(nx):
			for z in range(nz):
				var point := center+Vector3((x+.5)*tile.x-size.x/2,.025,(z+.5)*tile.y-size.y/2)
				instances.set_instance_transform(x*nz+z,Transform3D(Basis.IDENTITY.scaled(Vector3(tile.x/2,1,tile.y/2)),point)*local)
		var tiles := MultiMeshInstance3D.new()
		tiles.multimesh = instances
		parent.add_child(tiles)
	parent.remove_child(source)
	source.queue_free()
	for side: float in [-1,1]:
		var stone := load("res://assets/materials/pbr/rock.tres") as Material
		DemoGeometry.box(parent,center+Vector3(side*(size.x/2-.09),-.15,0),Vector3(.18,.28,size.y),stone)
		if size.x>=6:
			asset(parent,"hanging_chain",center+Vector3(side*(size.x/2-.5),-4.6,size.y/2-.5))

static func batch_primitives(parent: Node3D) -> void:
	var groups: Dictionary={}
	for node in parent.find_children("*","MeshInstance3D",true,false):
		var part := node as MeshInstance3D
		if not part.visible or not part.mesh is PrimitiveMesh or not part.material_override is StandardMaterial3D:continue
		var ancestor: Node=part
		var dynamic: bool=false
		while ancestor!=null and ancestor!=parent:
			dynamic=dynamic or ancestor is LanternAcolyte or ancestor is RunAltar or ancestor is RunMechanism or ancestor is TerrainDevice or ancestor is RiftConstruct or ancestor is AnimatableBody3D or ancestor.has_meta("interactive_visual")
			if ancestor is Node3D and not ancestor.visible:dynamic=true
			ancestor=ancestor.get_parent()
		if dynamic:continue
		var p := parent.to_local(part.global_position)
		var key := "%d/%d/%d" % [part.material_override.get_instance_id(),floori(p.x/24),floori(p.z/24)]
		if not groups.has(key):groups[key]=[]
		groups[key].append(part)
	for parts: Array in groups.values():
		if parts.size()<3:continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in parts:
			surface.append_from(MeshSanitizer.sanitize_surface(part.mesh,0),0,parent.global_transform.affine_inverse()*part.global_transform)
			part.hide()
		var batch := MeshInstance3D.new()
		batch.mesh=surface.commit()
		batch.material_override=parts[0].material_override
		parent.add_child(batch)

static func build(parent: Node3D, stage: int) -> void:
	var stone := DemoGeometry.material(Color("#252c2b"))
	for side: float in [-1,1]:
		for i in range(5):
			var z: float = 7.0-i*13
			asset(parent,"citadel_bastion",Vector3(side*(23+i%2*5),-20,z),Vector3(1,1.35,1),.12*side)
		for i in range(6):
			var z: float = 4-i*10
			asset(parent,"gothic_bay",Vector3(side*15,-2,z),Vector3(1.7,2.4,1.2),PI/2)
			if i%2==0:
				asset(parent,"hanging_standard",Vector3(side*13,7.5,z),Vector3(1.4,1.4,1.4),side*PI/2)
		DemoGeometry.box(parent,Vector3(side*20,-4,-20),Vector3(5,2,66),stone)
		DemoGeometry.box(parent,Vector3(side*17,12,-20),Vector3(1,1,66),stone)
	for i in range(6):
		asset(parent,"hanging_chain",Vector3((-1 if i%2 else 1)*11,8,-i*8),Vector3(1.5,2.2,1.5))
	if stage == 2:
		for side: float in [-1,1]:
			asset(parent,"furnace_stack",Vector3(side*13,-3,-19))
	if stage == 3:
		for side: float in [-1,1]:
			asset(parent,"seal_obelisk",Vector3(side*13,-2,-24))
		asset(parent,"gothic_bay",Vector3(0,1,-44),Vector3(2.5,2.5,1))

static func brazier(parent: Node3D, point: Vector3) -> void:
	var anchored := point
	# Props are authored next to route beats, but some beats are deliberately
	# voids. Refuse to spawn a brazier without a real collision surface below it.
	var supported := false
	for body: Node in parent.find_children("*","StaticBody3D",true,false):
		for child: Node in body.get_children():
			if not child is CollisionShape3D or not child.shape is BoxShape3D: continue
			var bounds: Vector3=(child.shape as BoxShape3D).size
			var local: Vector3=body.to_local(parent.to_global(point))
			if absf(local.x)<=bounds.x*.5 and absf(local.z)<=bounds.z*.5 and absf(local.y-bounds.y*.5)<1.0:
				anchored.y=body.global_position.y+bounds.y*.5+.03
				supported=true
				break
		if supported: break
	if parent.is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*5.0,point-Vector3.UP*30.0,1)
		var hit := parent.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			anchored.y=float(hit.position.y)+.03
			supported=true
	if not supported: return
	# Every flame is grounded by a visible plinth and a short iron bracket.
	# The support is deliberately separate from the imported brazier origin so
	# Blender pivot changes cannot leave a floating prop in a route screenshot.
	var stone := load("res://assets/materials/pbr/rock.tres") as Material
	DemoGeometry.cylinder(parent,anchored-Vector3.UP*.48,.42,.18,stone,.34)
	DemoGeometry.cylinder(parent,anchored-Vector3.UP*.28,.18,.38,load("res://assets/materials/pbr/iron.tres"),.14)
	asset(parent,"iron_brazier",anchored)
	var light := OmniLight3D.new()
	light.position = anchored+Vector3.UP*1.5
	light.light_color = Color("#ffb371")
	light.light_energy = 2.6
	light.omni_range = 7
	light.shadow_enabled = true
	light.distance_fade_enabled=true
	light.distance_fade_begin=25
	light.distance_fade_length=8
	parent.add_child(light)
	var flame := CPUParticles3D.new()
	flame.position = light.position-Vector3.UP*.25
	flame.amount = 18
	flame.lifetime = .6
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = .16
	flame.direction = Vector3.UP
	flame.spread = 12
	flame.gravity = Vector3(0,.8,0)
	flame.initial_velocity_min = .5
	flame.initial_velocity_max = 1
	flame.scale_amount_min = .05
	flame.scale_amount_max = .14
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = DemoGeometry.material(Color("#f1b66a"),2)
	flame.mesh = mesh
	parent.add_child(flame)
