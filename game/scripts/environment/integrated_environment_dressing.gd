class_name IntegratedEnvironmentDressing
extends RefCounted
## Runtime dressing uses reviewed Blender geometry without owning traversal collision.
## Floor skins sit on existing solid platforms; gates inherit the existing gate body.
const MODULE_ROOT := "res://environment_live/modules/"
const MODULES := {
	&"wall": "C01_ashlar_wall.scn",
	&"arch": "C02_pointed_arch.scn",
	&"floor": "C03_flagstone.scn",
	&"buttress": "C04_buttress.scn",
	&"banner": "C06_embroidered_banner.scn",
	&"lantern": "C07_lantern.scn",
	&"altar": "C08_covenant_altar.scn",
	&"gate": "C12_iron_gate.scn",
	&"bridge": "C05_rope_bridge.scn",
	&"bell": "C09_bronze_bell.scn",
	&"low_arch": "C10_low_arch.scn",
	&"roof": "C11_roof.scn",
	&"bell_frame": "C13_bell_frame.scn",
	&"window": "C14_window_bay.scn",
	&"broken_end": "C15_broken_bridge_end.scn",
	&"lift": "C16_chain_lift.scn",
	&"winch": "C17_hand_winch.scn",
	&"oak": "C18_breakable_oak.scn",
	&"anchor": "C19_ritual_anchor.scn",
}

static func _scene(kind:StringName)->PackedScene:
	return load(MODULE_ROOT+MODULES[kind]) as PackedScene

static func _root(parent: Node3D, role: StringName) -> Node3D:
	var node := Node3D.new()
	node.name = "R6_"+str(role)
	node.set_meta("environment_role",role)
	node.add_to_group("integrated_environment")
	parent.add_child(node)
	return node

static func _module(parent: Node3D, kind: StringName, point: Vector3, scale_value := Vector3.ONE, yaw := 0.0) -> Node3D:
	var holder := _root(parent,kind)
	var model := _scene(kind).instantiate() as Node3D
	holder.add_child(model)
	holder.set_meta("asset_id",String(MODULES[kind]).get_basename())
	holder.position=point;holder.scale=scale_value;holder.rotation.y=yaw
	return holder

static func _box_collision(parent:Node3D,point:Vector3,size:Vector3)->CollisionShape3D:
	var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=size
	shape.shape=bounds;shape.position=point;parent.add_child(shape);return shape

static func platform_skin(parent: Node3D, center: Vector3, size: Vector2, stage: int) -> void:
	var template := _scene(&"floor").instantiate() as Node3D
	var holder := _root(parent,&"platform_skin")
	holder.set_meta("asset_id","C03_flagstone")
	holder.position=center+Vector3.UP*.022
	var nx := maxi(1,ceili(size.x/4.0));var nz := maxi(1,ceili(size.y/4.0))
	var cell := Vector2(size.x/nx,size.y/nz)
	for source: MeshInstance3D in template.find_children("*","MeshInstance3D",true,false):
		var multi := MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=source.mesh;multi.instance_count=nx*nz
		for x in nx:
			for z in nz:
				var point:=Vector3((x+.5)*cell.x-size.x*.5,0,(z+.5)*cell.y-size.y*.5)
				multi.set_instance_transform(x*nz+z,Transform3D(Basis.IDENTITY.scaled(Vector3(cell.x/4.0,1,cell.y/4.0)),point))
		var instance:=MultiMeshInstance3D.new();instance.multimesh=multi
		holder.add_child(instance)
	template.free()

static func altar_skin(altar: RunAltar) -> void:
	for child: Node in altar.get_children():
		if child is Node3D and child.name!="R6_altar" and child.find_children("*","MeshInstance3D",true,false).size()>0:
			for mesh: MeshInstance3D in child.find_children("*","MeshInstance3D",true,false):mesh.hide()
	var skin:=_module(altar,&"altar",Vector3.ZERO)
	skin.set_meta("collision_owner",altar.get_path())

static func gate_skin(gate_body: Node3D) -> void:
	for mesh: MeshInstance3D in gate_body.find_children("*","MeshInstance3D",true,false):mesh.hide()
	var skin:=_module(gate_body,&"gate",Vector3(0,-1.6,0),Vector3(.92,1.06,1))
	skin.set_meta("collision_owner",gate_body.get_path())

static func _has_foundation(point:Vector3)->bool:
	for node:Node in Engine.get_main_loop().get_nodes_in_group("structural_foundation"):
		if node is Node3D and Vector3(node.get_meta("platform_center",Vector3.INF)).distance_to(point)<.08:return true
	return false

static func _ensure_foundations(room:CombatRoom)->void:
	# Older entrance quarters predate the expanded-route foundation helper. Fill
	# only those gaps so every playable slab visibly transfers load downward.
	for point:Vector3 in room.platform_extents:
		if _has_foundation(point):continue
		var size:Vector2=room.platform_extents[point]
		var foundation:=DemoGeometry.box(room.geometry,point-Vector3.UP*7,Vector3(maxf(1,size.x-1),13,maxf(1,size.y-1)),room._stone)
		foundation.add_to_group("structural_foundation")
		foundation.set_meta("platform_center",point)
		foundation.set_meta("platform_size",size)

static func _edge_landmark(room: CombatRoom, point: Vector3, size: Vector2, index: int) -> void:
	# Place both piers on the existing platform edge. Matching pier-only collision
	# leaves the opening usable and never invents an invisible full arch wall.
	# Orient each arch across the authored arrival line. Side-edge arches ran
	# parallel to traversal and could close the narrow space between a route wall
	# and a pier even though each prop was individually supported.
	var route: Array[Vector3]=room.route_nodes
	var travel:=Vector3.FORWARD
	if index>0:travel=(point-route[index-1])*Vector3(1,0,1)
	elif route.size()>1:travel=(route[1]-point)*Vector3(1,0,1)
	travel=travel.normalized()
	var edge_distance:=minf(size.x*.5/maxf(.001,absf(travel.x)),size.y*.5/maxf(.001,absf(travel.z)))
	var edge:=point-travel*(edge_distance-.55)
	var rotation:=atan2(-travel.x,-travel.z)
	var arch:=_module(room.geometry,&"arch",edge,Vector3(1.1,1.25,1.1),rotation)
	var body:=StaticBody3D.new();body.name="ArchPiers";body.collision_layer=1;body.collision_mask=0;arch.add_child(body)
	_box_collision(body,Vector3(-2.13,2.1,0),Vector3(.62,4.2,.72))
	_box_collision(body,Vector3(2.13,2.1,0),Vector3(.62,4.2,.72))
	body.add_to_group("integrated_environment_collision")
	arch.set_meta("support_points",[Vector3(-2.13,.08,0),Vector3(2.13,.08,0)])
	# A visible forged crossbar is the banner attachment, rather than an implied
	# floating pivot. Holder scaling places this at roughly 5.15 m world height.
	DemoGeometry.box(arch,Vector3(0,4.12,0),Vector3(2.05,.12,.22),room._iron)
	# Buttresses extend below the platform edge and visually transfer arch load
	# into the already-authored platform foundation.
	var buttress:=_module(room.geometry,&"buttress",edge+Vector3(0,-5.3,0),Vector3(.72,1.0,.72),rotation)
	buttress.set_meta("attached_to",arch.get_path())
	if room.stage!=2 or index%2==0:
		# Baked banner origin is at cloth bottom; its rod is 2.857 m above.
		var banner:=_module(room.geometry,&"banner",edge+Vector3(0,2.12,0),Vector3(1.05,1.05,1.05),rotation)
		banner.set_meta("attached_to",arch.get_path())
		banner.set_meta("rod_local",Vector3(0,2.857,0))
		banner.set_meta("attachment_world",edge+Vector3(0,5.12,0))

static func _route_lantern(room: CombatRoom, point: Vector3, tint: Color) -> void:
	var lantern:=_module(room.geometry,&"lantern",point,Vector3(1.15,1.15,1.15))
	var body:=StaticBody3D.new();body.name="LanternBody";body.collision_layer=1;body.collision_mask=0;lantern.add_child(body)
	_box_collision(body,Vector3(0,.52,0),Vector3(.56,1.04,.56));body.add_to_group("integrated_environment_collision")
	lantern.set_meta("support_points",[Vector3(0,.05,0)])
	var light:=OmniLight3D.new();light.position=Vector3(0,.55,0);light.light_color=tint
	light.light_energy=1.8;light.omni_range=7.5;light.shadow_enabled=true
	light.distance_fade_enabled=true;light.distance_fade_begin=22;light.distance_fade_length=7
	lantern.add_child(light)

static func decorate(room: CombatRoom) -> void:
	_ensure_foundations(room)
	for point: Vector3 in room.platform_extents:
		platform_skin(room.geometry,point,room.platform_extents[point],room.stage)
	var points:=room.route_nodes if not room.route_nodes.is_empty() else room.platform_extents.keys()
	for index in points.size():
		var point:Vector3=points[index]
		var size:Vector2=room.platform_extents.get(point,Vector2(8,8))
		if index%2==0:_edge_landmark(room,point,size,index)
		if index%2==1 or index==0:
			var tint:Color=[Color("e0a170"),Color("ef784c"),Color("9abcb4")][room.stage-1]
			_route_lantern(room,point+Vector3(size.x*.5-.65,.05,size.y*.25),tint)
	for device:RunAltar in room.altars:altar_skin(device)
	if is_instance_valid(room._gate):gate_skin(room._gate)
	_selected_route_assets(room)
	_selected_city(room)

static func _hide_direct_meshes(node:Node3D)->void:
	for child in node.get_children():
		if child is MeshInstance3D:child.hide()

static func _wall_skin(body:Node3D,room:CombatRoom)->void:
	var size:Vector3=body.get_meta("route_wall_size")
	_hide_direct_meshes(body)
	# Original wall collision remains authoritative. Each relief tile stays inside
	# that volume, so the wall-running contact plane does not move.
	var nx:=maxi(1,ceili(size.z/4.16));var ny:=maxi(1,ceili(size.y/4.01))
	for x in nx:
		for y in ny:
			var tile:=_module(body,&"wall",Vector3(0,-size.y*.5+y*size.y/ny,(x+.5)*size.z/nx-size.z*.5),Vector3(size.z/nx/4.16,size.y/ny/4.01,size.x/.62),PI/2)
			tile.set_meta("static_dressing",true)
	var lower:float=body.position.y-size.y*.5
	if lower> -24:
		var height:float=lower+24
		var support:=DemoGeometry.box(body,Vector3(0,-size.y*.5-height*.5,0),Vector3(size.x,height,size.z),room._stone)
		support.set_meta("static_dressing",true)

static func _selected_route_assets(room:CombatRoom)->void:
	for node in room.geometry.get_children():
		if node is Node3D and node.has_meta("route_wall_size"):_wall_skin(node,room)
	for device:TerrainDevice in room.terrain_devices:
		if device.kind==&"breakable" and is_instance_valid(device._barrier):
			_hide_direct_meshes(device._barrier)
			_module(device._barrier,&"oak",Vector3(0,-1.5,-.08),Vector3(3.2/2.6,3./2.4,.7))
		if device.kind in [&"lift",&"bridge"]:
			_hide_direct_meshes(device)
			_module(device,&"winch",Vector3(0,-1.05,0),Vector3.ONE*.7)
		if device.kind==&"lift" and is_instance_valid(device.moving_body):
			_hide_direct_meshes(device.moving_body)
			var cage:=_module(device.moving_body,&"lift",Vector3(0,-.225,0),Vector3(5./3.142816,1,5./3.15))
			cage.set_meta("collision_owner",device.moving_body.get_path())
	# Source courtyard composition is rebuilt around actual altars: nothing
	# replaces the authored route or invents a landing over its empty space.
	var court:Vector3=room.route_nodes[-1] if not room.route_nodes.is_empty() else Vector3.ZERO
	var extent:Vector2=room.platform_extents.get(court,Vector2(16,16))
	var bell_base:=court+Vector3(-extent.x*.5+2.4,0,-extent.y*.5+2)
	var frame:=_module(room.geometry,&"bell_frame",bell_base)
	var bell:=_module(frame,&"bell",Vector3(0,1.25,0),Vector3.ONE*.82)
	bell.set_meta("attached_to",frame.get_path())
	# Beam, yoke and bell are physically overlapping. Two wall bays carry roof.
	for side:float in [-1,1]:
		var bay:=court+Vector3(side*(extent.x*.5-.45),0,extent.y*.28)
		_module(room.geometry,&"window",bay,Vector3(1,1,1),PI/2)
		_module(room.geometry,&"roof",bay+Vector3(0,3.82,0),Vector3(.9,.55,.9),PI/2)
	if room.stage==1:
		# The overhead traction beam is carried into the lower city at both ends.
		for side:float in [-1,1]:
			var pier:=Vector3(-3+side*13,-24,-132)
			_module(room.geometry,&"buttress",pier,Vector3(1.2,44./5.34,1.2))
		# Arch crown wraps the solid roof of the real slide duct; no collision added.
		_module(room.geometry,&"low_arch",Vector3(-3,1.78,-89),Vector3(1.35,.70,1))
		for p:Vector3 in [Vector3(0,0,-1),Vector3(0,0,-45)]:
			# Broken masonry projects downward from a real takeoff/landing lip.
			_module(room.geometry,&"broken_end",p+Vector3(0,-3.1,0),Vector3(1.1,1,1),PI if p.z < -20 else 0.)
	# Wooden suspended decking is attached only to already-solid link segments.
	for link:Dictionary in room.route_links:
		if link.get("mechanic",&"")==&"wall_run":continue
		var ends:Array=link.get("segments",[])
		if ends.size()<2 or ends[0].distance_to(ends[1])<2:continue
		var a:Vector3=ends[0];var b:Vector3=ends[1]
		var holder:=_root(room.geometry,&"bridge_span")
		holder.position=a.lerp(b,.5);holder.basis=Basis.looking_at((b-a).normalized())
		_module(holder,&"bridge",Vector3(0,-.64,0),Vector3(3.2/4.25,1,a.distance_to(b)/6.))
		break

static func _selected_city(room:CombatRoom)->void:
	if room.stage!=1:return
	var city:=_root(room.geometry,&"selected_district")
	city.add_child(load(MODULE_ROOT+"selected_district.scn").instantiate())
	city.position=Vector3(-175,-25,-15)
	city.set_meta("asset_id","D00-D05")
	city.set_meta("visual_only",true)
