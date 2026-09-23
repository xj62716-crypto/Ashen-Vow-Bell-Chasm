class_name BossArena
extends Node3D
## Owns only boss mechanics and an explicitly bound collapsible floor.
signal terrain_warning(seconds: float)
signal terrain_changed(collapsed: bool)
signal surfaces_expiring(seconds: float)
var controller: BossPhaseController
var origin := Vector3.ZERO
var floor_body: StaticBody3D
var floor_wrapper: AnimatableBody3D
var floor_layer: int = 1
var floor_visible: bool = true
var collapsed: bool = false
var surfaces: Array[BossOrbitSurface] = []
var anchors: Array[RiftConstruct] = []
var wells: Array[RiftConstruct] = []
var _foundation_parts: Array[Node3D] = []

# The boss route alternates low broken decks and higher wall faces. Keeping the
# recipe here makes both boss types consume the same parkour language instead
# of falling back to flat orbiting targets around the actor.
## The arena is deliberately wider than the old six-metre ring.  The boss
## body owns the centre while the player needs readable high/mid/low lanes,
## not six overlapping pieces at the actor's feet.
const ROUTE_ELEVATIONS := [0.35, 3.2, 0.95, 4.35, 0.65, 3.7]
const ROUTE_RADIUS := 10.5

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group("boss_arenas")

func bind_floor(body: StaticBody3D) -> void:
	floor_body = body
	floor_layer = body.collision_layer
	floor_visible = body.visible
	# Do this during enemy _ready, before room mesh batching. Keeping this subtree
	# under an animatable owner prevents a visible baked floor over an empty pit.
	floor_wrapper = AnimatableBody3D.new()
	floor_wrapper.name = "BossCollapseOwner"
	floor_wrapper.collision_layer = 0
	floor_wrapper.collision_mask = 0
	floor_wrapper.sync_to_physics = false
	body.get_parent().add_child(floor_wrapper)
	body.reparent(floor_wrapper,true)
	# Expanded districts have a non-colliding stone foundation directly below
	# their platform. Collapse that owned volume too; leaving its roof visible
	# would make the real hole look like solid ground. Identify authored geometry
	# by dimensions/offsets before batching, never alter shared mesh resources.
	var size := Vector3.ZERO
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D: size=child.shape.size
	for node in floor_wrapper.get_parent().get_children():
		if not node is Node3D or node==floor_wrapper: continue
		var local: Vector3=body.to_local(node.global_position)
		var foundation := false
		if node is MeshInstance3D and node.mesh is BoxMesh:
			var dimensions: Vector3=node.mesh.size
			foundation = is_equal_approx(dimensions.y,13) and is_equal_approx(dimensions.x,size.x-1) and is_equal_approx(dimensions.z,size.z-1) and Vector2(local.x,local.z).length()<.01 and absf(local.y-(size.y*.5-7))<.01
		elif node.has_meta("static_dressing"):
			foundation = absf(local.y-(size.y*.5-13))<.01 and absf(local.z)<.01 and absf(absf(local.x)-(size.x*.5-.8))<.01
		if foundation:
			node.reparent(body,true)
			node.set_meta("boss_foundation",true)
			_foundation_parts.append(node)

func unbind_floor() -> void:
	restore_floor()
	if is_instance_valid(floor_wrapper):
		for node in _foundation_parts:
			if is_instance_valid(node): node.reparent(floor_wrapper.get_parent(),true)
		if is_instance_valid(floor_body): floor_body.reparent(floor_wrapper.get_parent(),true)
		floor_wrapper.queue_free()
	floor_body = null
	floor_wrapper = null
	_foundation_parts.clear()

func prepare_air_route() -> void:
	if not surfaces.is_empty(): return
	for index in range(6):
		var wall := BossOrbitSurface.new()
		wall.controller = controller
		wall.center = origin+Vector3.UP*1.6
		wall.angle = TAU*index/6.0
		wall.vertical_offset = ROUTE_ELEVATIONS[index]
		wall.radius = ROUTE_RADIUS
		wall.route_role = &"broken_deck" if index%2==0 else &"wall_face"
		wall.route_index = index
		wall.player = controller.actor.player
		add_child(wall)
		surfaces.append(wall)
		var anchor := RiftConstruct.new()
		anchor.kind = &"anchor"
		anchor.permanent = true
		# The anchor is suspended just off the moving wall face. Keep a compact
		# exit shell so the automatic release hands the player into that real
		# collision surface, while still staying outside the old 1.65 m face hit.
		anchor.grapple_release_distance = 2.25
		anchor.player = controller.actor.player
		wall.add_child(anchor)
		# Low broken decks expose a lower wall face; hang their anchor at the
		# upper edge so a half-second zip intersects the usable surface instead
		# of releasing above it.  Full wall faces keep the higher handoff.
		anchor.position = Vector3(0,2.9 if wall.route_role == &"broken_deck" else 3.6,-1.4)
		anchors.append(anchor)
	for index in range(3):
		var well := RiftConstruct.new()
		well.kind = &"well"
		well.permanent = true
		well.player = controller.actor.player
		add_child(well)
		var angle := TAU*index/3
		well.global_position = origin+Vector3(sin(angle)*3.4,-.12,cos(angle)*3.4)
		wells.append(well)

func warn_collapse(seconds: float) -> void:
	prepare_air_route()
	terrain_warning.emit(seconds)

func collapse() -> bool:
	if not is_instance_valid(floor_body) or surfaces.size() < 6: return false
	floor_body.collision_layer = 0
	floor_body.hide()
	collapsed = true
	# These are evacuation aids, not permanent ground islands for the aerial
	# phase. Existing construct warning/support grace gives time to leave them.
	for well in wells:
		well.permanent = false
		well.timer = 3.0
		well.lifetime = 3.0
	terrain_changed.emit(true)
	return true

func restore_floor() -> void:
	if is_instance_valid(floor_body):
		floor_body.collision_layer = floor_layer
		floor_body.visible = floor_visible
	if collapsed: terrain_changed.emit(false)
	collapsed = false

func clear_route() -> void:
	# Restore landing BEFORE removing attached walls/anchors. Cancellation never
	# leaves a tether to freed geometry; retry can safely rebuild the whole room.
	restore_floor()
	var player := controller.actor.player if is_instance_valid(controller) and is_instance_valid(controller.actor) else null
	if is_instance_valid(player) and player.grapple.active and player.grapple.anchor in anchors: player.grapple.release()
	for node in surfaces:
		if is_instance_valid(node):
			node.collision_layer = 0
			node.queue_free()
	for node in wells:
		if is_instance_valid(node):
			node.collision_layer = 0
			node.queue_free()
	surfaces.clear()
	anchors.clear()
	wells.clear()

func _exit_tree() -> void:
	restore_floor()
