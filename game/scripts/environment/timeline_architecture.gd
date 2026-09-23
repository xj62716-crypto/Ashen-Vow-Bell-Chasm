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
	parent.add_child(holder)
	holder.add_child(scene.instantiate())
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
	# The box is collision-only. The silhouette is built from authored masonry
	# pieces so a fractured span still has believable load paths and material
	# breakup at close range.
	_collision_box(parent, center, Vector3(width, height, span), phase, basis)
	var frame := _structure(parent, "Timeline_FracturedSpan", center, basis, phase)
	_asset(frame, &"window", Vector3(0, 0, 0), Vector3(.92, 1.25, .92), phase)
	for fraction: float in [-.38, .38]:
		_asset(frame, &"buttress", Vector3(-width*.22, -.12, fraction*span), Vector3(.72, .92, .72), phase)
		_asset(frame, &"broken_end", Vector3(width*.16, -.08, fraction*span), Vector3(.74, .66, .78), phase)
	for fraction: float in [-.5, .5]:
		_asset(frame, &"wall", Vector3(0, -.34, fraction*span), Vector3(.78, .82, .62), phase)
	# A narrow coping stone is kept as a physical edge cue, never as a floating
	# debug strip. It sits inside the fractured frame and follows its tilt.
	_asset(frame, &"flagstone", Vector3(0, height*.34, 0), Vector3(.54, .18, 1.05), phase)

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
		_collision_box(root, support, Vector3(.48, 6.4, 2.2), PRESENT)
		_collision_box(root, Vector3(side*7.5, 6.35 + index*.4, z), Vector3(15.0, .38, .58), PRESENT)
		_asset(root, &"buttress", Vector3(side*7.1, .0, z), Vector3(.82,1.35,.82), PRESENT, side*.5)
		_asset(root, &"arch", Vector3(0, 1.0 + index*.4, z), Vector3(.72,.82,.72), PRESENT, PI*.5)
		_asset(root, &"window", Vector3(side*7.5, 2.2 + index*.4, z), Vector3(.56,.76,.56), PRESENT, side*.5)
		_light(root, Vector3(side*6.7, 5.0 + index*.4, z-.8), phase_light, 1.7, PRESENT)
	# A grounded service bridge is visible only in the stable line. It makes the
	# same location read as a maintained citadel before the decks fracture.
	for index in range(2):
		var z := -84.0 - index*72.0
		_asset(root, &"bridge", Vector3(0, 1.0 + index*1.5, z), Vector3(.82, .72, 1.1), PRESENT)
		_collision_box(root, Vector3(0, 0.42 + index*1.5, z), Vector3(3.2,.42,10.0), PRESENT)
	# Warm vertical signal columns make the present readable without changing
	# the authored collision route.
	for point: Vector3 in [Vector3(-10, 4, -72), Vector3(10, 6, -142), Vector3(-10, 8, -216)]:
		_collision_box(root, point, Vector3(.16, 5.0, .16), PRESENT)
		_asset(root, &"bell_frame", point + Vector3(0, .8, 0), Vector3(.42, .72, .42), PRESENT)
		_asset(root, &"lantern", point + Vector3(0,2.25,0), Vector3(.8,.8,.8), PRESENT)
		_light(root, point + Vector3.UP*2.1, phase_light, 1.1, PRESENT)

static func _build_remnant(room: CombatRoom, root: Node3D) -> void:
	var rift := _rift_material([Color("#694b86"), Color("#8c4c56"), Color("#416d76")][room.stage-1])
	var ruin := _material([Color("#3b3341"), Color("#453437"), Color("#303a46")][room.stage-1], .09, .32)
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
		_asset(root, &"buttress", p + Vector3(-side*2.3,-3.5,0), Vector3(.7,1.2,.7), REMNANT, side*.42)
		_collision_box(root, p + Vector3(-side*2.3, -4.0, 0), Vector3(1.1, 8.0, 1.2), REMNANT)
		_light(root, p + Vector3(-side*2.3, 1.2, 0), cold, 1.5, REMNANT)
	# Phase-specific high line. The two locked decks are removed from the
	# present line and replaced by these offset surfaces; a player must choose
	# wall-run/air-dash or grapple to reach them.
	var locked: Array[int] = [1, 3]
	for deck_index: int in locked:
		if deck_index >= room.route_nodes.size():
			continue
		var center: Vector3 = room.route_nodes[deck_index]
		var side := -1.0 if (deck_index + room.stage) % 2 == 0 else 1.0
		var high := center + Vector3(side*6.0, 4.2 + room.stage*.35, 1.5)
		_collision_box(root, high, Vector3(7.0, .48, 6.0), REMNANT)
		_asset(root, &"flagstone", high + Vector3(0,.08,0), Vector3(1.12,.28,1.12), REMNANT, side*.18)
		_asset(root, &"broken_end", high + Vector3(-2.0,.05,0), Vector3(.72,.68,.82), REMNANT, side*.18)
		_asset(root, &"broken_end", high + Vector3(2.0,.05,0), Vector3(.72,.68,.82), REMNANT, side*.18)
		_asset(root, &"roof", high + Vector3(0, .72, 0), Vector3(.42,.16,.42), REMNANT, side*.18)
		for r: int in range(3):
			_mesh(root, _rift_ring_mesh(.22), high + Vector3((r-1)*2.0, .32, 0), rift, REMNANT)
		var wall_center := high + Vector3(-side*3.2, 2.8, -5.2)
		_phase_wall(root, wall_center + Vector3(0, 0, -5.2), wall_center + Vector3(0, 0, 5.2), ruin, REMNANT)
		# These two long faces are the actual remnant connection. They replace the
		# disabled ground deck on either side of the shifted landing and make the
		# phase choice change the required movement, not just the silhouette.
		if deck_index > 0:
			_phase_wall(root, room.route_nodes[deck_index-1], high, ruin, REMNANT)
		if deck_index + 1 < room.route_nodes.size():
			_phase_wall(root, high, room.route_nodes[deck_index+1], ruin, REMNANT)
		_broken_span(root, center.lerp(high,.5) + Vector3(0,1.6,0), center.distance_to(high)*.72, .34, .16, rift, REMNANT, 0.0, .08)
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
	# A deep split in the remnant route is a visible and physical alternative
	# to the present bridge. It is made from three offset plates, not a flat
	# recolor of the existing floor.
	for index in range(3):
		var center := Vector3((-4.0 if index%2==0 else 4.0), 3.0 + index*1.8, -112.0-index*18.0)
		var plate_basis := Basis(Vector3.UP, .12 if index%2==0 else -.16)
		_collision_box(root, center, Vector3(3.4, .42, 5.4), REMNANT, plate_basis)
		_asset(root, &"broken_end", center + Vector3(0,.06,0), Vector3(.62,.58,.72), REMNANT, .12 if index%2==0 else -.16)
		_asset(root, &"flagstone", center + Vector3(0,.27,0), Vector3(.76,.18,.86), REMNANT, .12 if index%2==0 else -.16)
	# Three cold rift seams change the near-field read of the walls and floor.
	for point: Vector3 in [Vector3(-5.1, 2.0, -62), Vector3(5.1, 4.5, -150), Vector3(-5.1, 7.0, -238)]:
		_box(root, point, Vector3(.12, 5.6, 8.0), rift, REMNANT)
		_light(root, point + Vector3.UP*1.5, cold, 1.35, REMNANT)

static func _lock_selected_decks(room: CombatRoom) -> void:
	# Tag the two broad expansion decks as present-only.  Their foundations are
	# visual and non-colliding; the remnant high line above is the replacement.
	for deck_index: int in [1, 3]:
		if deck_index >= room.route_nodes.size():
			continue
		var target: Vector3 = room.route_nodes[deck_index]
		for node: Node in room.geometry.find_children("*", "Node", true, false):
			if not node.has_meta("route_platform_center"):
				continue
			var center: Vector3 = node.get_meta("route_platform_center")
			if center.distance_to(target) < .08:
				_phase(node as Node3D, PRESENT)
		for node: Node in room.geometry.find_children("*", "Node", true, false):
			if not node.has_meta("environment_role") or node.get_meta("environment_role") != &"platform_skin":
				continue
			if (node as Node3D).global_position.distance_to(room.to_global(target + Vector3.UP*.022)) < .12:
				_phase(node as Node3D, PRESENT)

static func _phase_wall(parent: Node3D, from_point: Vector3, to_point: Vector3, surface: Material, phase: StringName) -> StaticBody3D:
	var flat := (to_point-from_point)*Vector3(1,0,1)
	if flat.length_squared() < .25:
		return _collision_box(parent, from_point.lerp(to_point,.5)+Vector3.UP*3.0, Vector3(.5,6.0,4.0), phase)
	var direction := (to_point-from_point).normalized()
	var basis := Basis.looking_at(direction)
	var length := from_point.distance_to(to_point)
	var center := from_point.lerp(to_point,.5) + basis.x*.72 + Vector3.UP*3.4
	var wall := _collision_box(parent, center, Vector3(.46,7.2,length+1.2), phase, basis)
	# Use the reviewed ashlar wall module for the visible route face. The
	# collision volume above is the only primitive; all visible masonry comes
	# from the authored environment asset.
	var wall_asset := _asset(parent, &"wall", center, Vector3.ONE, phase)
	wall_asset.basis = basis * Basis.IDENTITY.scaled(Vector3(length/4.16, 7.2/4.01, .46/.62))
	wall_asset.set_meta("route_wall_size", Vector3(.46,7.2,length+1.2))
	return wall

static func _rift_ring_mesh(radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius*.72
	mesh.outer_radius = radius
	mesh.rings = 20
	mesh.ring_segments = 8
	return mesh
