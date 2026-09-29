class_name TimelineArchitecture
extends RefCounted
## Authored spatial contrast for the present/remnant split.
##
## The timeline is deliberately more than a post-process change.  Present
## keeps the masonry, service bridges and working light network intact.  The
## remnant removes selected route decks and replaces them with offset,
## fractured high-line surfaces, wall faces and broken structural silhouettes.
## Every replacement is real geometry with a phase tag, so collision and
## visibility change together.

const PRESENT := &"present"
const REMNANT := &"remnant"
const LOCKED_DECKS := {1: [5,8], 2: [1,3], 3: [1,4]}
const MODULE_ROOT := "res://environment_live/modules/"
const MODULES := {
	&"wall": "C01_ashlar_wall.scn",
	&"arch": "C02_pointed_arch.scn",
	&"flagstone": "C03_flagstone.scn",
	&"buttress": "C04_buttress.scn",
	&"bridge": "C05_rope_bridge.scn",
	&"lantern": "C07_lantern.scn",
	&"bell_frame": "C13_bell_frame.scn",
	&"window": "C14_window_bay.scn",
	&"broken_end": "C15_broken_bridge_end.scn",
	&"anchor": "C19_ritual_anchor.scn",
	&"roof": "C11_roof.scn",
}

static func build(room: CombatRoom) -> void:
	var present := Node3D.new()
	present.name = "TimelinePresentArchitecture"
	room.geometry.add_child(present)
	var remnant := Node3D.new()
	remnant.name = "TimelineRemnantArchitecture"
	room.geometry.add_child(remnant)
	_build_present(room, present)
	_build_remnant(room, remnant)
	_lock_selected_decks(room)
	_bind_phase_traversal(room)
	room.signature_sections[&"timeline_architecture"] = {
		"present": "working masonry, grounded service bridges, warm light",
		"remnant": "offset high line, fractured walls, broken decks, cold rift light",
		"locked_decks": 2,
		"stages": 3,
	}

static func _phase(node: Node3D, phase: StringName) -> Node3D:
	node.set_meta("timeline_phase", phase)
	node.set_meta("timeline_authored", true)
	return node

static func _material(color: Color, emission: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
	var material := DemoGeometry.material(color, emission)
	material.metallic = metallic
	material.roughness = .64 if metallic < .2 else .42
	return material

static func _rift_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/rift_surface.gdshader")
	material.set_shader_parameter("tint", Color(color, 1.0))
	material.set_shader_parameter("warning", .72)
	return material

static func _box(parent: Node3D, point: Vector3, size: Vector3, surface: Material, phase: StringName, solid := false, rotation := Basis.IDENTITY) -> Node3D:
	var node := DemoGeometry.box(parent, point, size, surface, solid)
	node.basis = rotation
	_phase(node, phase)
	return node

static func _mesh(parent: Node3D, mesh: Mesh, point: Vector3, surface: Material, phase: StringName) -> MeshInstance3D:
	var node := DemoGeometry.mesh(parent, mesh, point, surface)
	_phase(node, phase)
	return node

static func _asset(parent: Node3D, kind: StringName, point: Vector3, scale_value: Vector3, phase: StringName, yaw := 0.0) -> Node3D:
	if OS.has_feature("headless"):
		var placeholder := Node3D.new()
		placeholder.name = "HeadlessTimeline_%s" % str(kind)
		placeholder.position = point
		placeholder.scale = scale_value
		placeholder.rotation.y = yaw
		placeholder.set_meta("environment_role", kind)
		placeholder.set_meta("asset_id", MODULES[kind].get_basename())
		parent.add_child(placeholder)
		_phase(placeholder, phase)
		return placeholder
	var scene := load(MODULE_ROOT + MODULES[kind]) as PackedScene
	if scene == null:
		push_error("TimelineArchitecture missing module: " + str(kind))
		return Node3D.new()
	var holder := Node3D.new()
	holder.name = "Timeline_%s" % str(kind)
	holder.position = point
	holder.scale = scale_value
	holder.rotation.y = yaw
	holder.set_meta("environment_role", kind)
	holder.set_meta("asset_id", MODULES[kind].get_basename())
	if kind in [&"arch", &"window", &"buttress"]:
		holder.set_meta("attached_to_route", true)
	parent.add_child(holder)
	var instance := scene.instantiate() as Node3D
	holder.add_child(instance)
	# These modules are presentation-only. A Blender export may contain a
	# convenience collider for authoring, but formal route geometry owns gameplay
	# collision. Leaving that collider live creates an invisible blocker when the
	# phase holder is hidden and makes a decorative arch behave like a wall.
	for collider: CollisionObject3D in instance.find_children("*", "CollisionObject3D", true, false):
		collider.set_meta("presentation_only", true)
		collider.collision_layer = 0
		collider.collision_mask = 0
		for shape: CollisionShape3D in collider.find_children("*", "CollisionShape3D", true, false):
			shape.set_meta("presentation_only", true)
			shape.disabled = true
	_phase(holder, phase)
	return holder

static func _structure(parent: Node3D, label: String, point: Vector3, basis: Basis, phase: StringName) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	holder.position = point
	holder.basis = basis
	parent.add_child(holder)
	_phase(holder, phase)
	return holder

static func _asset_basis(parent: Node3D, kind: StringName, point: Vector3, scale_value: Vector3, phase: StringName, basis: Basis) -> Node3D:
	var holder := _asset(parent, kind, point, Vector3.ONE, phase)
	holder.basis = basis * Basis.IDENTITY.scaled(scale_value)
	return holder

static func _collision_box(parent: Node3D, point: Vector3, size: Vector3, phase: StringName, basis := Basis.IDENTITY) -> StaticBody3D:
	# Collision volumes are deliberately invisible. The authored environment
	# module placed beside them is the visible surface the player reads.
	var body := DemoGeometry.box(parent, point, size, DemoGeometry.material(Color.BLACK), true) as StaticBody3D
	body.basis = basis
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = false
	_phase(body, phase)
	return body

static func _walkable_surface(parent: Node3D, point: Vector3, size: Vector3, surface: Material, phase: StringName, basis := Basis.IDENTITY) -> StaticBody3D:
	# The visible slab and its collision are the same body and share the same
	# transform. Decorative masonry may sit on top, but can never advertise a
	# larger walkable footprint than the authoritative support below it.
	var body := DemoGeometry.box(parent, point, size, surface, true) as StaticBody3D
	body.basis = basis
	body.set_meta("timeline_support", true)
	body.set_meta("timeline_support_size", size)
	_phase(body, phase)
	var nx := maxi(1, ceili(size.x / 4.0))
	var nz := maxi(1, ceili(size.z / 4.0))
	for x in nx:
		for z in nz:
			var tile_size := Vector3(size.x/nx,.08,size.z/nz)
			var tile_center := Vector3((x+.5)*tile_size.x-size.x*.5,size.y*.5-.02,(z+.5)*tile_size.z-size.z*.5)
			_fit_module(body,&"flagstone",AABB(tile_center-tile_size*.5,tile_size),phase)
	return body

static func _fit_module(parent: Node3D, kind: StringName, bounds: AABB, phase: StringName, yaw := 0.0) -> Node3D:
	# Measure the actual imported model including pivots and nested transforms.
	# Fitting a module never changes the authoritative collision owner.
	var holder := _asset(parent,kind,Vector3.ZERO,Vector3.ONE,phase,yaw)
	var measured := AABB()
	var first := true
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		var local := parent.global_transform.affine_inverse()*part.global_transform
		var box := local*part.get_aabb()
		measured = box if first else measured.merge(box)
		first = false
	if first or measured.size.x < .001 or measured.size.y < .001 or measured.size.z < .001:
		push_error("Timeline module has no usable bounds: " + str(kind))
		return holder
	var ratio := bounds.size / measured.size
	holder.transform = Transform3D(Basis.IDENTITY.scaled(ratio), bounds.position-measured.position*ratio)*holder.transform
	return holder

static func _masonry_wall(parent: Node3D, point: Vector3, size: Vector3, surface: Material, phase: StringName, basis := Basis.IDENTITY) -> StaticBody3D:
	var body := DemoGeometry.box(parent,point,size,surface,true) as StaticBody3D
	body.basis = basis
	body.set_meta("route_wall_size",size)
	body.set_meta("timeline_wall",true)
	_phase(body,phase)
	var nz := maxi(1,ceili(size.z/4.16))
	var ny := maxi(1,ceili(size.y/4.01))
	for z in nz:
		for y in ny:
			var tile := Vector3(size.x+.016,size.y/ny,size.z/nz)
			var center := Vector3(0,(y+.5)*tile.y-size.y*.5,(z+.5)*tile.z-size.z*.5)
			_fit_module(body,&"wall",AABB(center-tile*.5,tile),phase,PI*.5)
	return body

static func _light(parent: Node3D, point: Vector3, color: Color, energy: float, phase: StringName) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = point
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 13.0
	light.shadow_enabled = true
	parent.add_child(light)
	_phase(light, phase)
	return light

static func _broken_span(parent: Node3D, center: Vector3, span: float, width: float, height: float, surface: Material, phase: StringName, yaw: float, tilt: float) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, tilt)
	_masonry_wall(parent,center,Vector3(width,height,span),surface,phase,basis)

static func _build_present(room: CombatRoom, root: Node3D) -> void:
	var steel := _material(Color("#343d3b"), .03, .55)
	var brass := _material(Color("#9e7145"), .38, .72)
	var phase_light: Color = [Color("#d99d61"), Color("#e7784e"), Color("#b4d3bd")][room.stage-1]
	# Working infrastructure frames the route in the present: each beam has
	# visible support and sits beside the actual deck rather than floating over it.
	for index in range(3):
		var z := -28.0 - index * 58.0
		var side := -1.0 if index % 2 == 0 else 1.0
		var support := Vector3(side*7.5, 3.2 + index*.4, z)
		# These frames establish silhouette and lighting only. The former hidden
		# box beam crossed the critical grapple flight at z=-144 and stopped the
		# player in mid-air despite no matching visible obstruction.
		_asset(root, &"buttress", Vector3(side*7.1, .0, z), Vector3(.82,1.35,.82), PRESENT, side*.5)
		_asset(root, &"arch", Vector3(0, 1.0 + index*.4, z), Vector3(.72,.82,.72), PRESENT, PI*.5)
		_asset(root, &"window", Vector3(side*7.5, 2.2 + index*.4, z), Vector3(.56,.76,.56), PRESENT, side*.5)
		_light(root, Vector3(side*6.7, 5.0 + index*.4, z-.8), phase_light, 1.7, PRESENT)
	# A grounded service bridge is visible only in the stable line. It makes the
	# same location read as a maintained citadel before the decks fracture.
	# Service decks are dressed on their actual platform owners. Do not add
	# independent bridge skins across the authored void or slide approach.
	# Warm vertical signal columns make the present readable without changing
	# the authored collision route.
	for point: Vector3 in [Vector3(-10, 4, -72), Vector3(10, 6, -142), Vector3(-10, 8, -216)]:
		_asset(root, &"bell_frame", point + Vector3(0, .8, 0), Vector3(.42, .72, .42), PRESENT)
		_asset(root, &"lantern", point + Vector3(0,2.25,0), Vector3(.8,.8,.8), PRESENT)
		_light(root, point + Vector3.UP*2.1, phase_light, 1.1, PRESENT)

static func _build_remnant(room: CombatRoom, root: Node3D) -> void:
	var rift := _rift_material([Color("#694b86"), Color("#8c4c56"), Color("#416d76")][room.stage-1])
	var ruin := (room._stone as StandardMaterial3D).duplicate() as StandardMaterial3D
	ruin.albedo_color = [Color("#6d606f"), Color("#746063"), Color("#5e7177")][room.stage-1]
	ruin.metallic = .02
	var cold: Color = [Color("#bf83dc"), Color("#ea8768"), Color("#7ec5d0")][room.stage-1]
	# A large broken silhouette replaces the intact service frames. These are
	# intentionally asymmetric so the phase reads as a different place, not a
	# color grade over the same horizon.
	for index in range(4):
		var z := -36.0 - index * 54.0
		var side := -1.0 if index % 2 == 0 else 1.0
		var p := Vector3(side*(8.0 + (index%2)*2.5), 5.4 + index*.85, z)
		_broken_span(root, p, 13.0, .62, 8.0, ruin, REMNANT, side*.42, (-.12 if index%2==0 else .14))
		_asset(root, &"window", p + Vector3(0,-1.6,0), Vector3(.86,1.1,.86), REMNANT, side*.42)
		# The supporting pier shares the same visible body as its collision.
		_masonry_wall(root,p+Vector3(-side*2.3,-6.4,0),Vector3(1.1,12.8,1.2),ruin,REMNANT)
		_light(root, p + Vector3(-side*2.3, 1.2, 0), cold, 1.5, REMNANT)
	# Phase-specific high line. The two locked decks are removed from the
	# present line and replaced by these offset surfaces; a player must choose
	# wall-run/air-dash or grapple to reach them.
	for deck_index: int in LOCKED_DECKS[room.stage]:
		if deck_index >= room.route_nodes.size():
			continue
		var center: Vector3 = room.route_nodes[deck_index]
		var side := -1.0 if (deck_index + room.stage) % 2 == 0 else 1.0
		var high := center + Vector3(side*6.0, 4.2 + room.stage*.35, 1.5)
		_walkable_surface(root, high, Vector3(7.0, .48, 6.0), ruin, REMNANT)
		for r: int in range(3):
			_mesh(root, _rift_ring_mesh(.22), high + Vector3((r-1)*2.0, .32, 0), rift, REMNANT)
		# These two long faces are the actual remnant connection. They replace the
		# disabled ground deck on either side of the shifted landing and make the
		# phase choice change the required movement, not just the silhouette.
		if deck_index > 0 and room.stage == 1:
			# Aqueduct keeps its central tether lane open. The alternate wall sits
			# on the high landing's left edge instead of slicing through the launch.
			_phase_wall(root, room.route_nodes[deck_index-1], high, ruin, REMNANT,-3.6 if room.stage==1 and deck_index==5 else .72)
		if deck_index + 1 < room.route_nodes.size() and room.stage == 1:
			_phase_wall(root, high, room.route_nodes[deck_index+1], ruin, REMNANT)
		var anchor := RiftConstruct.new()
		anchor.name = "RemnantAnchor_%d" % deck_index
		anchor.kind = &"anchor"
		anchor.permanent = true
		anchor.grapple_exit_speed = 18.0
		anchor.grapple_exit_lift = 4.5
		anchor.position = high + Vector3(side*2.0, 3.3, -1.5)
		root.add_child(anchor)
		_phase(anchor, REMNANT)
		_asset(root, &"anchor", anchor.position, Vector3(.8,.8,.8), REMNANT)
		room.static_anchors.append(anchor)
		_mesh(root, _rift_ring_mesh(1.0), anchor.position, rift, REMNANT)
		_light(root, anchor.position, cold, 2.1, REMNANT)
		# A failed transfer drops to an actual narrow side station, never an
		# invisible safety floor. Its wind well returns the player to launch
		# height without teleporting or making a continuous ground bypass.
		var extent: Vector2 = room.platform_extents.get(center,Vector2(10,10))
		var recovery := center+Vector3(side*(extent.x*.5+3.4),-4.2,2.0)
		var recovery_body := room._platform(recovery,Vector2(5.0,6.0))
		# Recovery stations belong to the remnant world. They used to be added as
		# ordinary platforms after the phase build, leaving their floor active in
		# the present and their wind-well collision detached from visibility.
		_phase(recovery_body, REMNANT)
		CitadelExpansion._foundation(room,recovery,Vector2(5.0,6.0))
		IntegratedEnvironmentDressing.platform_skin(recovery_body,Vector3.UP*.6,Vector2(5.0,6.0),room.stage)
		for foundation: Node in room.get_tree().get_nodes_in_group("structural_foundation"):
			if foundation is Node3D and Vector3(foundation.get_meta("platform_center",Vector3.INF)).distance_to(recovery) < .08:
				_phase(foundation as Node3D, REMNANT)
		for child: Node in recovery_body.get_children():
			if child is Node3D and child.get_meta("environment_role", &"") == &"platform_skin":
				_phase(child as Node3D, REMNANT)
		var well := RiftConstruct.new()
		well.name = "TimelineRecoveryWell_%d" % deck_index
		well.kind = &"well"
		well.permanent = true
		room.geometry.add_child(well)
		well.position = recovery+Vector3.UP*.16
		well.set_meta("timeline_recovery",true)
		_phase(well, REMNANT)
		room.signature_sections[&"phase_recovery_%d" %deck_index]={"floor":recovery,"well":well.position,"returns_to":high}
	# A deep split in the remnant route is a visible and physical alternative
	# to the present bridge. It is made from three offset plates, not a flat
	# recolor of the existing floor.
	for index in range(3):
		var center := Vector3((-4.0 if index%2==0 else 4.0), 3.0 + index*1.8, -112.0-index*18.0)
		var plate_basis := Basis(Vector3.UP, .12 if index%2==0 else -.16)
		_walkable_surface(root, center, Vector3(3.4, .42, 5.4), ruin, REMNANT, plate_basis)
	# Three cold rift seams change the near-field read of the walls and floor.
	for point: Vector3 in [Vector3(-5.1, 2.0, -62), Vector3(5.1, 4.5, -150), Vector3(-5.1, 7.0, -238)]:
		_box(root, point, Vector3(.12, 5.6, 8.0), rift, REMNANT)
		_light(root, point + Vector3.UP*1.5, cold, 1.35, REMNANT)

static func _lock_selected_decks(room: CombatRoom) -> void:
	# Every dependent skin/foundation follows the actual platform, including
	# the Boss collapse owner. Reparent before batching, preserving world pose.
	for node: Node in room.get_tree().get_nodes_in_group("structural_foundation"):
		if not node is Node3D or not room.geometry.is_ancestor_of(node): continue
		var owner := room.platform_at(node.get_meta("platform_center",Vector3.INF))
		if owner != null and node.get_parent() != owner: node.reparent(owner,true)
	# Tag the two broad expansion decks as present-only.  Their foundations are
	# visual and non-colliding; the remnant high line above is the replacement.
	for deck_index: int in LOCKED_DECKS[room.stage]:
		if deck_index >= room.route_nodes.size():
			continue
		var target: Vector3 = room.route_nodes[deck_index]
		var extent: Vector2 = room.platform_extents.get(target,Vector2.ZERO)
		# Ramps, landing lips and wall bodies are authored as independent
		# StaticBody3D nodes. If they overlap a deck that is removed in the remnant,
		# leaving them untagged produces the exact failure users see: a visible void
		# with an invisible floor/wall, or a solid body left behind the old world.
		for body: CollisionObject3D in room.geometry.find_children("*", "CollisionObject3D", true, false):
			if body.has_meta("timeline_phase") or body.get_meta("presentation_only", false):
				continue
			if not (body.has_meta("route_connector") or body.has_meta("route_wall_size") or body.has_meta("floating_route_surface")):
				continue
			var local := room.to_local(body.global_position) - target
			var horizontal := absf(local.x) <= extent.x*.5 + 1.2 and absf(local.z) <= extent.y*.5 + 1.2
			if horizontal and absf(local.y) <= 4.5:
				_phase(body, PRESENT)
		# Gameplay installations and grounded decoration use the same deck. An
		# altar/checkpoint cannot survive visually or interact over its removed floor.
		for device:Node3D in room.altars+room.terrain_devices+room.mechanisms:
			var offset:=device.position-target
			if offset.y>=-.15 and offset.y<=2.5 and absf(offset.x)<extent.x*.5 and absf(offset.z)<extent.y*.5:
				_phase(device,PRESENT)
		for prop:Node in room.geometry.get_children():
			if not prop is Node3D or not prop.get_meta("static_dressing",false):continue
			var offset:Vector3=prop.position-target
			if absf(offset.y)<.2 and absf(offset.x)<extent.x*.5 and absf(offset.z)<extent.y*.5:
				_phase(prop,PRESENT)
		for enemy: LanternAcolyte in room.enemies:
			var offset := enemy.position-target
			if absf(offset.y)<.2 and absf(offset.x)<extent.x*.5 and absf(offset.z)<extent.y*.5:
				_phase(enemy,PRESENT)
		for node: Node in room.geometry.find_children("*", "Node", true, false):
			if not node.has_meta("route_platform_center"):
				continue
			var center: Vector3 = node.get_meta("route_platform_center")
			if center.distance_to(target) < .08:
				_phase(node as Node3D, PRESENT)
		# Foundations were previously left visible after their collision-bearing
		# platform switched off. Their broad top face looked like a valid floor in
		# the remnant even though it was intentionally non-solid.
		for node: Node in room.get_tree().get_nodes_in_group("structural_foundation"):
			if not node is Node3D or not room.geometry.is_ancestor_of(node):
				continue
			var center: Vector3 = node.get_meta("platform_center", Vector3.INF)
			if center.distance_to(target) < .08:
				_phase(node as Node3D, PRESENT)
		for node: Node in room.geometry.find_children("*", "Node", true, false):
			if not node.has_meta("environment_role") or node.get_meta("environment_role") != &"platform_skin":
				continue
			if (node as Node3D).global_position.distance_to(room.to_global(target + Vector3.UP*.022)) < .12:
				_phase(node as Node3D, PRESENT)

static func _bind_phase_traversal(room: CombatRoom) -> void:
	if room.stage == 1:
		# The aqueduct has no walkable span. Its original zip position/timing are
		# retained; the remnant provides the tether, present provides the broad
		# combat landing. Staying in remnant offers the narrower high wall route.
		for anchor: RiftConstruct in room.static_anchors:
			if anchor.position.distance_to(Vector3(-3,18,-132))<.1:
				_phase(anchor,REMNANT)
				anchor.set_meta("timeline_crossing",true)
		room.signature_sections[&"aqueduct_phase_crossing"]={
			"approach":Vector3(-3,2,-113),"anchor":Vector3(-3,18,-132),
			"anchor_phase":REMNANT,"broad_landing_phase":PRESENT,
			"landing":Vector3(-3,2,-157),"alternate":"remnant high wall"}
	_author_phase_contracts(room)

static func _author_phase_contracts(room: CombatRoom) -> void:
	# A phase chain is an authored traversal beat, not a lighting cue. The
	# destination decks and their visible wall faces belong to alternating worlds;
	# a player must change phase while airborne to continue the critical path.
	var node_indices: Array[int]=[]
	var phases: Array[StringName]=[]
	var contract_id: StringName
	match room.stage:
		1:
			node_indices=[2,3,4]
			phases=[PRESENT,REMNANT,PRESENT]
			contract_id=&"causeway_phase_chain"
		2:
			node_indices=[1,2,3]
			phases=[PRESENT,REMNANT,PRESENT]
			contract_id=&"forge_phase_chain"
		3:
			node_indices=[1,2,3,4,5]
			phases=[PRESENT,REMNANT,PRESENT,REMNANT,PRESENT]
			contract_id=&"tower_phase_chain"
	var nodes: Array[Vector3]=[]
	for index in node_indices:
		if index < 0 or index >= room.route_nodes.size(): continue
		var point: Vector3=room.route_nodes[index]
		nodes.append(point)
		_set_route_node_phase(room,point,phases[nodes.size()-1],contract_id)
	if nodes.size() < 2: return
	_phase_chain_supports(room,nodes,phases,contract_id)
	for index in range(nodes.size()-1):
		var authored_wall := false
		var authored_link: Dictionary = {}
		for link: Dictionary in room.route_links:
			if link.get("mechanic",&"") != &"wall_run": continue
			if Vector3(link.get("from",Vector3.INF)).distance_to(nodes[index]) < .1 and Vector3(link.get("to",Vector3.INF)).distance_to(nodes[index+1]) < .1:
				authored_wall = true
				authored_link = link
				break
		if authored_wall:
			# The authored route wall is the source surface. Keep its two physical
			# faces together, then create only one clearly placed destination face.
			# The previous implementation added a second pair of long walls here;
			# their overlapping end caps were the invisible air walls players hit
			# while switching worlds.
			for wall: Node in room.geometry.find_children("*", "StaticBody3D", true, false):
				if not wall.has_meta("wall_link_from") or not wall.has_meta("wall_link_to"): continue
				var wall_from: Vector3 = wall.get_meta("wall_link_from")
				var wall_to: Vector3 = wall.get_meta("wall_link_to")
				if wall_from.distance_to(nodes[index]) < .1 and wall_to.distance_to(nodes[index+1]) < .1:
					_phase(wall, phases[index])
					wall.set_meta("timeline_crossing", true)
			var authored_segments: Array = authored_link.get("segments", [])
			var target_from: Vector3 = authored_segments[0] if authored_segments.size() >= 4 else nodes[index]
			var target_to: Vector3 = authored_segments[2] if authored_segments.size() >= 4 else nodes[index+1]
			# The second forge phase handoff climbs from the y=6 service line to
			# the y=8 receiving deck.  The destination wall is enabled while the
			# runner is still descending from the source face; starting its lower
			# edge exactly at the source takeoff height makes the lower wall probe
			# lose contact before the authored kick window.  Extend only this real
			# wall face downward into the source-side clearance.  It does not add a
			# floor or a bypass, and keeps the visible wall continuous through the
			# airborne handoff.
			if room.stage == 2 and index == 1:
				target_from.y -= 1.8
			# The authored wall link ends at the receiving deck edge so its source
			# collision cannot become a floor shortcut.  The destination timeline
			# wall is a separate side surface: carry it through the braking window
			# to just inside the receiving platform.  Without this run-out the phase
			# wall disappeared roughly 10 m before the landing, leaving a visible
			# high-line route with no surface for the required wall kick.
			var destination_direction := ((nodes[index+1]-nodes[index])*Vector3(1,0,1)).normalized()
			if destination_direction.length_squared() > .25 and target_to.distance_to(nodes[index+1]) > 4.0:
				target_to = nodes[index+1] - destination_direction*2.0
			if room.stage == 2 and index == 1 and destination_direction.length_squared() > .25:
				# The receiving ramp now carries the second kick into the deck. End
				# the phase wall at the authored node so it cannot remain active into
				# the following wall link and steal the next capture.
				target_to += destination_direction*2.0
			var target_offset := .72 if index%2==0 else -.72
			_phase_wall(room.geometry,target_from,target_to,room._stone,phases[index+1],target_offset,false)
			continue
		var side_offset := .72 if index%2==0 else -.72
		# Expansion splits long links with a real midpoint landing.  Start the
		# phase wall at that landing so the first half remains a grounded approach
		# and the second half carries the intended wall-run contract.
		var wall_from := nodes[index].lerp(nodes[index+1],.5)
		if wall_from.distance_to(nodes[index+1]) > 39.0:
			wall_from = nodes[index].lerp(nodes[index+1],.5)
		_phase_wall(room.geometry,wall_from,nodes[index+1],room._stone,phases[index],side_offset,false)
	for link: Dictionary in room.route_links:
		var source_point := Vector3(link.get("from",Vector3.INF))
		var destination_point := Vector3(link.get("to",Vector3.INF))
		var source_index := _phase_node_index(source_point,nodes)
		var destination_index := _phase_node_index(destination_point,nodes)
		if source_index < 0 and destination_index < 0: continue
		var phase_index := source_index if source_index >= 0 else destination_index
		var destination_phase := phases[destination_index] if destination_index >= 0 else phases[phase_index]
		# Long critical links are split into a real midpoint landing by the
		# expansion builder. Only those exact authored midpoint coordinates are
		# promoted here; broad segment-distance matching can capture an unrelated
		# entrance link that merely approaches the phase chain.
		if source_index >= 0 and destination_index < 0:
			var split_index := _phase_split_index(destination_point,nodes)
			if split_index == source_index:
				destination_phase = phases[source_index]
		if source_index < 0 and destination_index >= 0:
			var split_index := _phase_split_index(source_point,nodes)
			if split_index == destination_index-1:
				phase_index = split_index
				destination_phase = phases[destination_index]
		link["timeline_chain"] = contract_id
		link["phase_source"] = phases[phase_index]
		link["phase_destination"] = destination_phase
		link["phase_change_required"] = phases[phase_index] != destination_phase
		# Preserve each link's authored traversal mechanic. A long split link can
		# be a jump across a physical break even when a phase wall runs beside it.
	room.register_timeline_contract(contract_id,phases,nodes,[&"wall_run",&"wall_kick",&"air_dash",&"timeline_shift"])
	room.signature_sections[contract_id]["required"] = true
	room.signature_sections[contract_id]["route_role"] = &"critical"

static func _phase_chain_supports(room: CombatRoom, nodes: Array[Vector3], phases: Array[StringName], contract_id: StringName) -> void:
	# Every landing and connector on the critical chain must belong to the same
	# world as the half of the link it serves. Leaving the small aprons untagged
	# created a continuous ground shortcut around an otherwise phase-gated wall.
	for candidate_variant in room.platform_extents.keys():
		var center := Vector3(candidate_variant)
		var best_distance := INF
		var best_index := -1
		var best_t := 0.0
		for index in range(nodes.size()-1):
			var flat := (nodes[index+1]-nodes[index]) * Vector3(1,0,1)
			if flat.length_squared() < .25:
				continue
			var t := clampf(((center-nodes[index]) * Vector3(1,0,1)).dot(flat) / flat.length_squared(), 0.0, 1.0)
			var closest := nodes[index].lerp(nodes[index+1], t)
			var distance := center.distance_to(closest)
			if distance < best_distance:
				best_distance = distance
				best_index = index
				best_t = t
		if best_index < 0 or best_distance > 7.0:
			continue
		var owner := room.platform_at(center)
		if owner == null or owner.get_meta("timeline_shared_support", false):
			continue
		# Explicit remnant high decks and selected present decks already carry an
		# authored phase. Never overwrite that declaration with a nearest-segment
		# guess.
		var existing := preload("res://scripts/run/timeline_collision.gd").phase_of(owner)
		if existing in [PRESENT, REMNANT]:
			continue
		var phase := phases[best_index] if best_t < .5 else phases[best_index+1]
		_phase(owner,phase)
		owner.set_meta("timeline_contract",contract_id)
		for foundation: Node in room.get_tree().get_nodes_in_group("structural_foundation"):
			if foundation is Node3D and Vector3(foundation.get_meta("platform_center",Vector3.INF)).distance_to(center) < .08:
				_phase(foundation as Node3D,phase)
		for skin: Node in room.geometry.find_children("*","Node",true,false):
			if skin.get_meta("environment_role",&"") != &"platform_skin":
				continue
			if (skin as Node3D).global_position.distance_to(room.to_global(center+Vector3.UP*.022)) < .12:
				_phase(skin as Node3D,phase)
	# Connector slabs are separate StaticBody3D nodes, so apply the same phase
	# contract to their visible collision owner. This closes the common case where
	# a ramp remained solid after its landing deck disappeared.
	for body: CollisionObject3D in room.geometry.find_children("*","CollisionObject3D",true,false):
		if not body.has_meta("route_connector"):
			continue
		var local := room.to_local(body.global_position)
		var best_distance := INF
		var best_index := -1
		var best_t := 0.0
		for index in range(nodes.size()-1):
			var flat := (nodes[index+1]-nodes[index]) * Vector3(1,0,1)
			if flat.length_squared() < .25:
				continue
			var t := clampf(((local-nodes[index]) * Vector3(1,0,1)).dot(flat) / flat.length_squared(), 0.0, 1.0)
			var closest := nodes[index].lerp(nodes[index+1],t)
			var distance := local.distance_to(closest)
			if distance < best_distance:
				best_distance=distance
				best_index=index
				best_t=t
		if best_index >= 0 and best_distance <= 6.0:
			var phase := phases[best_index] if best_t < .5 else phases[best_index+1]
			var existing_phase := preload("res://scripts/run/timeline_collision.gd").phase_of(body)
			# Locked decks can pre-tag their receiving lips before the phase chain is
			# authored. Keep that explicit ownership, but still bind the connector
			# to this contract so a wall handoff recognises it as a legal landing
			# surface during occupancy checks.
			if existing_phase in [PRESENT, REMNANT] and existing_phase != phase:
				continue
			if existing_phase != phase:
				_phase(body,phase)
			body.set_meta("timeline_contract",contract_id)

static func _phase_node_index(point: Vector3, nodes: Array[Vector3]) -> int:
	for index in nodes.size():
		if point.distance_to(nodes[index]) < .08: return index
	return -1

static func _phase_split_index(point: Vector3, nodes: Array[Vector3]) -> int:
	for index in range(nodes.size()-1):
		if nodes[index].distance_to(nodes[index+1]) <= 39.0: continue
		var midpoint := nodes[index].lerp(nodes[index+1],.5)
		midpoint.y = nodes[index].y + clampf(nodes[index+1].y-nodes[index].y,-1.0,1.0)
		if point.distance_to(midpoint) < .1: return index
	return -1

static func _set_route_node_phase(room: CombatRoom, point: Vector3, phase: StringName, contract_id: StringName) -> void:
	var platform := room.platform_at(point)
	if platform == null: return
	_phase(platform,phase)
	platform.set_meta("timeline_required",phase)
	platform.set_meta("timeline_contract",contract_id)
	for node: Node in room.get_tree().get_nodes_in_group("structural_foundation"):
		if not node is Node3D or not room.geometry.is_ancestor_of(node): continue
		var center: Vector3=node.get_meta("platform_center",Vector3.INF)
		if center.distance_to(point) < .08:
			_phase(node as Node3D,phase)
			node.set_meta("timeline_contract",contract_id)
	for node: Node in room.geometry.find_children("*","Node",true,false):
		if not node.has_meta("environment_role") or node.get_meta("environment_role") != &"platform_skin": continue
		if (node as Node3D).global_position.distance_to(room.to_global(point+Vector3.UP*.022)) < .12:
			_phase(node as Node3D,phase)
			node.set_meta("timeline_contract",contract_id)

static func _phase_wall(parent: Node3D, from_point: Vector3, to_point: Vector3, surface: Material, phase: StringName, side_offset:float=.72, surface_probe := true) -> StaticBody3D:
	var flat := (to_point-from_point)*Vector3(1,0,1)
	if flat.length_squared() < .25:
		return _masonry_wall(parent, from_point.lerp(to_point,.5)+Vector3.UP*3.0, Vector3(.5,6.0,4.0), surface, phase)
	var direction := flat.normalized()
	var basis := Basis.looking_at(direction)
	var length := flat.length()
	var center := from_point.lerp(to_point,.5) + basis.x*side_offset
	var height := clampf(5.8+absf(to_point.y-from_point.y),5.8,8.0)
	center.y = minf(from_point.y,to_point.y) + height*.5 - .08
	var wall := _masonry_wall(parent,center,Vector3(.46,height,length+1.2),surface,phase,basis)
	wall.set_meta("phase_chain_wall",true)
	if not surface_probe:
		# Diagonal chain walls are validated by the chain contract. The legacy
		# axis ray probe is intentionally reserved for authored wall faces.
		wall.remove_meta("timeline_wall")
	return wall

static func _rift_ring_mesh(radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius*.72
	mesh.outer_radius = radius
	mesh.rings = 20
	mesh.ring_segments = 8
	return mesh
