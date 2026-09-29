class_name CombatRoom
extends Node3D
signal cleared
signal enemy_fired
signal mechanism_used
signal altar_requested(altar: RunAltar)
signal guard_broken
signal configuration_rejected(errors: PackedStringArray)
signal checkpoint_reached(id: StringName, pose: Transform3D, index: int)

@export var run_configuration: LevelRunConfiguration=preload("res://scenes/levels/config/default_run.tres")
var last_configuration_errors := PackedStringArray()
var _configuration: LevelRunConfiguration

var enemies: Array[LanternAcolyte] = []
var defeated_count: int = 0
var spawn: Marker3D
var exit_area: Area3D
var stage_title: String = "断桥外墙"
var stage: int = 1
var enabled: bool = false
var geometry: Node3D
var mechanisms: Array[RunMechanism] = []
var altar: RunAltar
var altars: Array[RunAltar]=[]
var terrain_devices: Array[TerrainDevice]=[]
var static_anchors: Array[RiftConstruct]=[]
var checkpoint_areas: Array[Area3D]=[]
var reached_checkpoints: Dictionary={}
var route_nodes: Array[Vector3]=[]
var branch_nodes: Array[Vector3]=[]
var shape_landings: Array[Vector3]=[]
var return_landings: Array[Vector3]=[]
var platform_extents: Dictionary={}
## Named, inspectable sections used by route tests and later encounter tuning.
## These are runtime facts about formal geometry, not separate preview cells.
var signature_sections: Dictionary={}
## Explicit authored route contracts used by route checks and encounter tuning.
var timeline_contracts: Array[Dictionary]=[]
## Set by MovementTrial; kept here so authored phase geometry and collision
## share the same room lifecycle as enemies, altars and checkpoints.
var timeline_runtime: TimelineRuntime
var timeline_phase: StringName = &"present"
## Built connection graph, including intermediate rest platforms. Coordinates
## are room-local floor points; runtime/editor inspection shares this record.
var route_links: Array[Dictionary]=[]
var _timeline_nodes: Array[Node] = []
var _timeline_shapes: Array[CollisionShape3D] = []
var _timeline_collision_owners: Array[CollisionObject3D] = []
var _timeline_owner_shapes: Dictionary = {}
var _presentation_collision_owners: Array[CollisionObject3D] = []
var _presentation_collision_shapes: Array[CollisionShape3D] = []
var _timeline_graph_dirty: bool = false
var exit_unlocked: bool = false
var _required_enemies: Array[LanternAcolyte] = []
var _bridge_open: bool = false
var _exit_title: Label3D
var _gate: Node3D
var _gate_shape: CollisionShape3D
var _bridge: Node3D
var _suspended_shapes: Dictionary = {}
var _collisions_suspended: bool = false
var _stone: Material = preload("res://assets/materials/pbr/stone.tres")
var _floor: Material = preload("res://assets/materials/pbr/floor.tres")
var _iron: Material = preload("res://assets/materials/pbr/iron.tres")
var _accent: Material
## Imported environment dressing is deliberately dense for close shots. Keep
## only the nearby authored presentation live during play so the route remains
## responsive on the target machine; route collision is never part of this set.
const PRESENTATION_CULL_RADIUS_M := 92.0
const PRESENTATION_CULL_INTERVAL_S := 0.20
var _presentation_cull_clock := 0.0
var _presentation_cull_nodes: Array[Node3D] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	get_tree().node_added.connect(_mark_timeline_graph_dirty)
	get_tree().node_removed.connect(_timeline_collision_removed)
	if not _build(1):push_error("CombatRoom configuration: "+str(last_configuration_errors))
	set_enabled(false)
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event("interact", key)

func _physics_process(_delta: float) -> void:
	# Reconcile cached collision owners. A full recursive scene scan here costs
	# several milliseconds on every one of the 120 physics ticks per second.
	if _timeline_graph_dirty:
		_cache_timeline_graph()
	_sync_timeline_collision_owners()
	_presentation_cull_clock -= _delta
	if _presentation_cull_clock <= 0.0:
		_presentation_cull_clock = PRESENTATION_CULL_INTERVAL_S
		_update_presentation_culling()
	# A player can complete an altar choice while already inside its trigger.
	# In that case body_entered fired before the altar became used, so relying on
	# the signal alone would silently skip the checkpoint.  Poll only the small
	# set of real altar areas and feed the same authoritative callback; the
	# reached-checkpoint guard keeps this idempotent.
	if not enabled:
		return
	for area: Area3D in checkpoint_areas:
		if not is_instance_valid(area) or not area.monitoring:
			continue
		for body: Node3D in area.get_overlapping_bodies():
			if body is ParkourPlayer:
				_checkpoint_body_entered(body,area)

func _cache_presentation_cull_nodes() -> void:
	_presentation_cull_nodes.clear()
	if not is_instance_valid(geometry):
		return
	for candidate: Node in geometry.get_tree().get_nodes_in_group("integrated_environment"):
		if candidate is Node3D and geometry.is_ancestor_of(candidate):
			var node := candidate as Node3D
			if not node.has_meta("cull_base_visible"):
				node.set_meta("cull_base_visible", node.visible)
			_presentation_cull_nodes.append(node)

func _update_presentation_culling() -> void:
	if not enabled or not is_instance_valid(geometry):
		return
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") as Node3D if scene != null else null
	if player == null:
		return
	if _presentation_cull_nodes.is_empty():
		_cache_presentation_cull_nodes()
	var radius_sq := PRESENTATION_CULL_RADIUS_M * PRESENTATION_CULL_RADIUS_M
	for node: Node3D in _presentation_cull_nodes:
		if not is_instance_valid(node):
			continue
		var distance_sq := node.global_position.distance_squared_to(player.global_position)
		var should_cull := distance_sq > radius_sq
		if should_cull:
			if not node.has_meta("distance_culled"):
				node.set_meta("distance_culled", true)
				node.set_meta("distance_visible_before", node.visible)
			if node.visible:
				node.visible = false
			continue
		if not node.has_meta("distance_culled"):
			continue
		node.remove_meta("distance_culled")
		var restore := bool(node.get_meta("cull_base_visible", true))
		var phase := StringName(node.get_meta("timeline_phase", &""))
		if phase in [&"present", &"remnant"]:
			restore = phase == timeline_phase
		if node.get_meta("gameplay_hidden", false) or node.get_meta("presentation_replaced", false):
			restore = false
		node.visible = restore

func set_next_configuration(candidate: LevelRunConfiguration) -> PackedStringArray:
	var errors := candidate.validation_errors() if candidate!=null else PackedStringArray(["configuration: required resource is missing"])
	if errors.is_empty():run_configuration=candidate
	else:configuration_rejected.emit(errors)
	last_configuration_errors=errors
	return errors

func configuration_id() -> StringName:
	return _configuration.id if _configuration!=null else &""

func _build(number: int) -> bool:
	last_configuration_errors=run_configuration.validation_errors() if run_configuration!=null else PackedStringArray(["configuration: required resource is missing"])
	if number<1 or number>3:last_configuration_errors.append("stage: expected 1..3")
	if not last_configuration_errors.is_empty():
		configuration_rejected.emit(last_configuration_errors)
		return false
	_configuration=run_configuration.snapshot()
	_suspended_shapes.clear()
	_collisions_suspended = false
	if is_instance_valid(geometry):
		remove_child(geometry)
		# A queued free leaves the previous room's StaticBody3D instances in the
		# physics broadphase until the next frame. During a retry or stage rebuild
		# that stale timeline wall can block the new route and overlap the player.
		# The room owns this subtree exclusively, so release it synchronously before
		# constructing the replacement geometry.
		geometry.free()
	enemies.clear()
	_required_enemies.clear()
	exit_unlocked = false
	_bridge_open = false
	mechanisms.clear()
	altars.clear()
	terrain_devices.clear()
	static_anchors.clear()
	checkpoint_areas.clear()
	reached_checkpoints.clear()
	route_nodes.clear()
	branch_nodes.clear()
	shape_landings.clear()
	return_landings.clear()
	platform_extents.clear()
	route_links.clear()
	signature_sections.clear()
	timeline_contracts.clear()
	_timeline_nodes.clear()
	_timeline_shapes.clear()
	_timeline_collision_owners.clear()
	_timeline_owner_shapes.clear()
	_presentation_collision_owners.clear()
	_presentation_collision_shapes.clear()
	_bridge = null
	geometry = Node3D.new()
	geometry.name = "StageGeometry"
	add_child(geometry)
	stage = number
	stage_title = ["断桥外墙", "熔炉升降井", "悬空封印塔"][clampi(stage-1,0,2)]
	_accent = DemoGeometry.material([Color("#b9c2ad"),Color("#c58e60"),Color("#acc4c1")][stage-1],.12)
	spawn = Marker3D.new()
	geometry.add_child(spawn)
	if stage==1:
		RefinedCauseway.build(self)
	else:
		match stage:
			2: _forge()
			3: _tower()
		CitadelExpansion.build(self)
	_spawn_configured_encounters()
	altar = RunAltar.new()
	# Every altar is a real checkpoint and must sit on an authored walkable
	# surface.  Keeping the placement in this room builder prevents a mesh pivot
	# change or a route extension from leaving the checkpoint over the void.
	altar.position = _grounded_platform_point(Vector3(2.4,0,5.0) if stage == 1 else Vector3(-1.6,0,4.5))
	geometry.add_child(altar)
	_add_shared_altar_support(altar)
	altar.requested.connect(func(device: RunAltar): altar_requested.emit(device))
	altars.push_front(altar)
	# Formal recovery is owned by the same altar objects that award runes. The
	# old free-standing marker route is intentionally not generated.
	_build_checkpoints()
	_scenery()
	if stage!=1:CitadelDressing.build(geometry,stage)
	IntegratedEnvironmentDressing.decorate(self)
	# Phase ownership must exist BEFORE static batching. Otherwise a hidden
	# platform leaves its baked paving visible after its collision is removed.
	TimelineArchitecture.build(self)
	_sync_grounded_installation_phases()
	_cache_timeline_graph()
	# Headless physics suites repeatedly rebuild all three dressed rooms. Keep
	# their authored meshes and collision intact while avoiding a costly render
	# batching pass that has no effect on collision or route reachability. The
	# normal windowed game still batches the same assets for the shipped visual.
	if not OS.has_feature("headless"):
		CitadelDressing.batch_static(geometry)
		CitadelDressing.batch_primitives(geometry)
	var environment: Environment = get_tree().current_scene.get_node("WorldEnvironment").environment if get_tree().current_scene != null else null
	if environment != null:
		var sky := Sky.new()
		var sky_material := ShaderMaterial.new()
		sky_material.shader = preload("res://assets/shaders/citadel_sky.gdshader")
		sky.sky_material = sky_material
		environment.sky = sky
		environment.background_mode = Environment.BG_SKY
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.ambient_light_energy = .14
		environment.fog_density = .0027
		environment.volumetric_fog_density = .0032
		environment.fog_light_color = Color("#17282c")
		environment.fog_aerial_perspective = .5
		environment.tonemap_exposure = 1.0
		environment.glow_intensity = .34
	apply_timeline_phase(timeline_phase)
	return true

func apply_timeline_phase(next_phase: StringName) -> void:
	## Timeline-tagged geometry is real authored route geometry. Toggling a phase
	## disables its collision shapes as well as its visible mesh, so the player
	## never receives an invisible wall or a visual-only shortcut.
	timeline_phase = next_phase if next_phase in [&"present", &"remnant"] else &"present"
	if _timeline_graph_dirty:
		_cache_timeline_graph()
	# Remove attacks from the departed world in the same transaction. Waiting
	# for their physics callbacks leaves one-frame invisible/visible threats.
	for group in ["friendly_projectiles","hostile_projectiles"]:
		for effect in get_tree().get_nodes_in_group(group):
			if effect is Node3D and effect.has_meta("timeline_phase") and StringName(effect.get_meta("timeline_phase"))!=timeline_phase:
				effect.hide();effect.set_physics_process(false);effect.queue_free()
	if is_instance_valid(geometry):
		var tagged_nodes: Array[Node] = _timeline_nodes if not _timeline_nodes.is_empty() else geometry.find_children("*", "Node", true, false)
		for node: Node in tagged_nodes:
			if not is_instance_valid(node):
				_timeline_graph_dirty = true
				continue
			if not node.has_meta("timeline_phase"):
				continue
			var active := StringName(node.get_meta("timeline_phase")) == timeline_phase
			if node is LanternAcolyte: active = active and node.health > 0
			# Shape disabling is authoritative for queries, while the layer toggle
			# also removes an already-broadphase body in the same transaction. This
			# prevents a just-departed timeline wall from stealing the player's
			# momentum for one or more physics frames after a route handoff.
			if node is CollisionObject3D and node.has_meta("timeline_phase"):
				if not node.has_meta("timeline_base_layer"):
					node.set_meta("timeline_base_layer",node.collision_layer)
					node.set_meta("timeline_base_mask",node.collision_mask)
				node.collision_layer = int(node.get_meta("timeline_base_layer")) if active else 0
				node.collision_mask = int(node.get_meta("timeline_base_mask")) if active else 0
			if node is CanvasItem or node is Node3D:
				node.visible = active and not node.get_meta("presentation_replaced",false) and not node.get_meta("gameplay_hidden",false)
			if node is LanternAcolyte:
				node.active = active and enabled
		var tagged_shapes: Array[CollisionShape3D] = _timeline_shapes if not _timeline_shapes.is_empty() else geometry.find_children("*", "CollisionShape3D", true, false)
		for shape: CollisionShape3D in tagged_shapes:
			if not is_instance_valid(shape):
				_timeline_graph_dirty = true
				continue
			var shape_phase := preload("res://scripts/run/timeline_collision.gd").phase_of(shape)
			if shape_phase not in [&"present", &"remnant"]:
				continue
			if not shape.has_meta("timeline_initial_disabled"):shape.set_meta("timeline_initial_disabled",shape.disabled)
			var gameplay_disabled:bool=shape.get_meta("gameplay_disabled",shape.get_meta("timeline_initial_disabled",false))
			var should_disable := not preload("res://scripts/run/timeline_collision.gd").active(shape) or gameplay_disabled
			# Update the authoritative flag immediately after a room rebuild.  The
			# deferred write remains for the physics-safe end-of-frame sync, but
			# relying on it alone can leave a freshly rebuilt phase wall collidable
			# for the first route frames.
			shape.disabled = should_disable
			shape.set_deferred("disabled", should_disable)
		# Imported modules can contain a nested CollisionObject3D below a phase
		# holder.  Propagate the phase to that owner as well as the shape; relying
		# only on the holder's visibility leaves a stale body in the broadphase.
		_sync_timeline_collision_owners()
	var scene: Node = get_tree().current_scene
	var environment: Environment = null
	if scene != null:
		var world_environment := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if world_environment != null:
			environment = world_environment.environment
	if environment != null:
		if timeline_phase == &"remnant":
			# The remnant is darker and colder, but its architecture must remain
			# readable during a fast traversal. Keep enough fill for stone edges,
			# enemy silhouettes and the next wall surface to separate from the void.
			environment.ambient_light_energy = .16
			environment.ambient_light_color = Color("#78658c")
			environment.ambient_light_sky_contribution = .34
			environment.fog_light_color = Color("#302442")
			environment.fog_density = .0046
			environment.volumetric_fog_density = .0052
			environment.fog_aerial_perspective = .65
			environment.glow_intensity = .48
			environment.adjustment_enabled = true
			environment.adjustment_brightness = .95
			environment.adjustment_contrast = 1.08
			environment.adjustment_saturation = .86
		else:
			environment.ambient_light_energy = .14
			environment.ambient_light_color = Color("#b3c0bd")
			environment.ambient_light_sky_contribution = .65
			environment.fog_light_color = Color("#17282c")
			environment.fog_density = .0027
			environment.volumetric_fog_density = .0032
			environment.fog_aerial_perspective = .5
			environment.glow_intensity = .34
			environment.adjustment_enabled = true
			environment.adjustment_brightness = 1.0
			environment.adjustment_contrast = 1.0
			environment.adjustment_saturation = .92
		var sky := environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			var sky_material := sky.sky_material as ShaderMaterial
			if timeline_phase == &"remnant":
				sky_material.set_shader_parameter("zenith", Vector3(.018,.014,.032))
				sky_material.set_shader_parameter("horizon", Vector3(.22,.07,.20))
			else:
				sky_material.set_shader_parameter("zenith", Vector3(.025,.055,.082))
				sky_material.set_shader_parameter("horizon", Vector3(.19,.25,.26))
	# Existing lights are the stable-line network. In the remnant they become
	# emergency embers; the phase-specific cold lights above provide the new
	# illumination pattern. Cache the authored energy on first application.
	if is_instance_valid(geometry):
		for light: Light3D in geometry.find_children("*", "Light3D", true, false):
			if light.has_meta("timeline_authored"):
				continue
			if not light.has_meta("present_energy"):
				light.set_meta("present_energy", light.light_energy)
			var base_energy := float(light.get_meta("present_energy"))
			light.light_energy = base_energy * (.50 if timeline_phase == &"remnant" else 1.0)

func prepare_timeline_phase(next_phase: StringName) -> void:
	## Arms the destination world during a wall-run handoff. The current world
	## remains visible and collidable until the player leaves its surface; this
	## prevents a phase switch from deleting the wall under the player's hands
	## while still making the receiving platform physically real before the kick.
	var target := next_phase if next_phase in [&"present", &"remnant"] else &"present"
	if not is_instance_valid(geometry) or target == timeline_phase:
		return
	if _timeline_graph_dirty:
		_cache_timeline_graph()
	var tagged_nodes: Array[Node] = _timeline_nodes if not _timeline_nodes.is_empty() else geometry.find_children("*", "Node", true, false)
	for node: Node in tagged_nodes:
		if not is_instance_valid(node):
			_timeline_graph_dirty = true
			continue
		if not node.has_meta("timeline_phase"):
			continue
		if StringName(node.get_meta("timeline_phase")) != target:
			continue
		if node is CollisionObject3D:
			if not node.has_meta("timeline_base_layer"):
				node.set_meta("timeline_base_layer",node.collision_layer)
				node.set_meta("timeline_base_mask",node.collision_mask)
			node.collision_layer = int(node.get_meta("timeline_base_layer"))
			node.collision_mask = int(node.get_meta("timeline_base_mask"))
		if node is CanvasItem or node is Node3D:
			node.visible = not node.get_meta("presentation_replaced", false) and not node.get_meta("gameplay_hidden", false)
		if node is LanternAcolyte:
			node.active = enabled
	var tagged_shapes: Array[CollisionShape3D] = _timeline_shapes if not _timeline_shapes.is_empty() else geometry.find_children("*", "CollisionShape3D", true, false)
	for shape: CollisionShape3D in tagged_shapes:
		if not is_instance_valid(shape):
			_timeline_graph_dirty = true
			continue
		if preload("res://scripts/run/timeline_collision.gd").phase_of(shape) == target:
			# A phase holder may contain an imported StaticBody3D several levels
			# below it.  Enabling only the shape leaves that owner on layer zero,
			# so the receiving wall looks present but cannot be touched during the
			# wall-run handoff.  Arm the owner and the shape together; apply_phase()
			# will atomically retire the old phase after the player leaves the wall.
			var owner := _collision_owner(shape)
			if owner != null:
				if not owner.has_meta("timeline_base_layer"):
					owner.set_meta("timeline_base_layer",owner.collision_layer)
					owner.set_meta("timeline_base_mask",owner.collision_mask)
				owner.collision_layer = int(owner.get_meta("timeline_base_layer"))
				owner.collision_mask = int(owner.get_meta("timeline_base_mask"))
			shape.set_deferred("disabled", false)

func _platform(center: Vector3, size: Vector2) -> Node3D:
	platform_extents[center]=size
	var body := DemoGeometry.box(geometry,center-Vector3.UP*0.6,Vector3(size.x,1.2,size.y),_floor,true)
	body.set_meta("route_platform_center", center)
	body.set_meta("route_platform_size", size)
	CitadelDressing.paving(body,Vector3.UP*.6,size)
	for end: float in [-1,1]:
		DemoGeometry.box(body,Vector3(0,.655,end*(size.y/2-.07)),Vector3(size.x,.025,.055),_accent)
	return body

func _grounded_platform_point(point: Vector3, margin: float = .95) -> Vector3:
	## Clamp a gameplay prop to the nearest authored platform.  Props are placed
	## during room construction, before physics has a reliable broadphase, so a
	## data-driven platform lookup is the authoritative grounding source.
	var best_center := Vector3.INF
	var best_size := Vector2.ZERO
	var best_score := INF
	for candidate_variant in platform_extents.keys():
		var candidate := Vector3(candidate_variant)
		var size: Vector2 = platform_extents[candidate_variant]
		var dx := absf(point.x-candidate.x)
		var dz := absf(point.z-candidate.z)
		var inside := dx <= maxf(.2,size.x*.5-margin) and dz <= maxf(.2,size.y*.5-margin)
		var score := Vector2(maxf(0.0,dx-size.x*.5),maxf(0.0,dz-size.y*.5)).length_squared()+pow(point.y-candidate.y,2.0)
		if inside:
			score = point.distance_squared_to(candidate)-10000.0
		if score < best_score:
			best_score=score
			best_center=candidate
			best_size=size
	if not best_center.is_finite():
		return point
	var inset_x := maxf(.2,best_size.x*.5-margin)
	var inset_z := maxf(.2,best_size.y*.5-margin)
	return Vector3(clampf(point.x,best_center.x-inset_x,best_center.x+inset_x),best_center.y,clampf(point.z,best_center.z-inset_z,best_center.z+inset_z))

func platform_at(center: Vector3) -> Node3D:
	for node: Node in geometry.find_children("*", "Node3D", true, false):
		if node.has_meta("route_platform_center") and Vector3(node.get_meta("route_platform_center")).is_equal_approx(center):
			return node as Node3D
	return null

func _platform_phase_at(point: Vector3) -> StringName:
	# Timeline ownership comes from the authored support footprint, never from a
	# decorative prop's stale world-space position.
	var best := Vector3.INF
	var best_distance := INF
	for candidate_variant in platform_extents.keys():
		var candidate := Vector3(candidate_variant)
		var size: Vector2 = platform_extents[candidate_variant]
		var inside := absf(point.x-candidate.x) <= size.x*.5 and absf(point.z-candidate.z) <= size.y*.5
		var distance := point.distance_squared_to(candidate)
		if inside:
			distance -= 10000.0
		if distance < best_distance:
			best_distance = distance
			best = candidate
	if not best.is_finite():
		return &""
	var owner := platform_at(best)
	return preload("res://scripts/run/timeline_collision.gd").phase_of(owner) if owner != null else &""

func _sync_grounded_installation_phases() -> void:
	# TimelineArchitecture assigns phase tags after rooms and props are built.
	# Apply that owner phase to every grounded gameplay installation so an
	# inactive world cannot leave an altar, checkpoint, mechanism or route shell.
	for device: Node3D in altars + terrain_devices + mechanisms:
		if not is_instance_valid(device):
			continue
		# Altars are shared save/reward nodes.  They must survive a phase shift at
		# the same world coordinate; their small untagged support is the only floor
		# they rely on.  A phase tag here was the source of respawns over a hidden
		# deck in the remnant.
		if device is RunAltar or device.get_meta("timeline_shared", false):
			device.remove_meta("timeline_phase")
			continue
		var phase := _platform_phase_at(to_local(device.global_position))
		if phase in [&"present", &"remnant"]:
			device.set_meta("timeline_phase", phase)
	for node: Node in geometry.find_children("*", "Node3D", true, false):
		if not node.get_meta("static_dressing", false) or node.get_meta("hanging", false) or node.get_meta("visual_only", false):
			continue
		if not node.get_meta("attached_to_route", false):
			continue
		var phase := _platform_phase_at(to_local((node as Node3D).global_position))
		if phase in [&"present", &"remnant"]:
			node.set_meta("timeline_phase", phase)

func _cache_timeline_graph() -> void:
	_timeline_graph_dirty = false
	_timeline_nodes.clear()
	_timeline_shapes.clear()
	_timeline_collision_owners.clear()
	_timeline_owner_shapes.clear()
	_presentation_collision_owners.clear()
	_presentation_collision_shapes.clear()
	if not is_instance_valid(geometry):
		return
	for node: Node in geometry.find_children("*", "Node", true, false):
		if node.has_meta("timeline_phase"):
			_timeline_nodes.append(node)
		if node is CollisionObject3D:
			var owner := node as CollisionObject3D
			if owner.get_meta("presentation_only", false):
				_presentation_collision_owners.append(owner)
			elif preload("res://scripts/run/timeline_collision.gd").phase_of(owner) in [&"present", &"remnant"]:
				_timeline_collision_owners.append(owner)
	for shape: CollisionShape3D in geometry.find_children("*", "CollisionShape3D", true, false):
		var phase := preload("res://scripts/run/timeline_collision.gd").phase_of(shape)
		var shape_owner := _collision_owner(shape)
		if shape.get_meta("presentation_only", false) or (shape_owner != null and shape_owner.get_meta("presentation_only", false)):
			_presentation_collision_shapes.append(shape)
			continue
		if phase in [&"present", &"remnant"]:
			_timeline_shapes.append(shape)
			shape.set_meta("timeline_phase", phase)
			var owner := shape_owner
			if owner != null:
				owner.set_meta("timeline_phase", phase)
				if not _timeline_nodes.has(owner):
					_timeline_nodes.append(owner)
				if not _timeline_collision_owners.has(owner):
					_timeline_collision_owners.append(owner)
				var records: Array = _timeline_owner_shapes.get(owner, [])
				records.append({"shape": shape, "phase": phase})
				_timeline_owner_shapes[owner] = records

func _mark_timeline_graph_dirty(node: Node) -> void:
	if (node is CollisionObject3D or node is CollisionShape3D) and is_instance_valid(geometry) and geometry.is_ancestor_of(node):
		_timeline_graph_dirty = true

func _timeline_collision_removed(node: Node) -> void:
	if node is CollisionObject3D and (_timeline_owner_shapes.has(node) or _presentation_collision_owners.has(node)):
		_timeline_graph_dirty = true
	elif node is CollisionShape3D and (_timeline_shapes.has(node) or _presentation_collision_shapes.has(node)):
		_timeline_graph_dirty = true

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_mark_timeline_graph_dirty):
		get_tree().node_added.disconnect(_mark_timeline_graph_dirty)
	if get_tree().node_removed.is_connected(_timeline_collision_removed):
		get_tree().node_removed.disconnect(_timeline_collision_removed)

func _collision_owner(node: Node) -> CollisionObject3D:
	var cursor := node.get_parent()
	while cursor != null and not cursor is CollisionObject3D:
		cursor = cursor.get_parent()
	return cursor as CollisionObject3D

func _sync_timeline_collision_owners() -> void:
	if not is_instance_valid(geometry):
		return
	for presentation: CollisionObject3D in _presentation_collision_owners:
		if not is_instance_valid(presentation):
			continue
		if presentation.collision_layer != 0:
			presentation.collision_layer = 0
		if presentation.collision_mask != 0:
			presentation.collision_mask = 0
	for shape: CollisionShape3D in _presentation_collision_shapes:
		if is_instance_valid(shape) and not shape.disabled:
			shape.disabled = true
			shape.set_deferred("disabled", true)
	for owner: CollisionObject3D in _timeline_collision_owners:
		if not is_instance_valid(owner):
			continue
		if not owner.has_meta("timeline_base_layer"):
			owner.set_meta("timeline_base_layer", owner.collision_layer)
			owner.set_meta("timeline_base_mask", owner.collision_mask)
		var owner_active := false
		var records: Array = _timeline_owner_shapes.get(owner, [])
		for record: Dictionary in records:
			var shape := record["shape"] as CollisionShape3D
			if not is_instance_valid(shape):
				continue
			var active: bool = StringName(record["phase"]) == timeline_phase and enabled and not bool(owner.get_meta("gameplay_hidden", false)) and not bool(shape.get_meta("gameplay_disabled", false))
			owner_active = owner_active or active
			var should_disable := not active
			if shape.disabled != should_disable:
				shape.disabled = should_disable
				shape.set_deferred("disabled", should_disable)
		var layer := int(owner.get_meta("timeline_base_layer")) if owner_active else 0
		var mask := int(owner.get_meta("timeline_base_mask")) if owner_active else 0
		if owner.collision_layer != layer:
			owner.collision_layer = layer
		if owner.collision_mask != mask:
			owner.collision_mask = mask
		if owner.visible != owner_active:
			owner.visible = owner_active

func _wall(center: Vector3, size: Vector3, solid: bool = true) -> void:
	var body:=DemoGeometry.box(geometry,center,size,_stone,solid)
	body.set_meta("route_wall_size",size)
	if not solid:
		body.set_meta("presentation_only",true)
	var side: float = -1.0 if center.x>0 else 1.0
	for z in range(int(center.z-size.z/2)+1,int(center.z+size.z/2),2):
		DemoGeometry.box(geometry,Vector3(center.x+side*(size.x/2+.015),1.3,z),Vector3(.025,.035,.45),_accent)
	for z in range(int(center.z-size.z/2),int(center.z+size.z/2)+1,4):
		DemoGeometry.box(geometry,Vector3(center.x-side*.32,center.y,z),Vector3(.23,size.y+.35,.3),_iron)

func _timeline_wall(center: Vector3, size: Vector3, material: Material = null) -> Node3D:
	## A phase-exclusive surface still uses a real StaticBody3D and therefore
	## participates in wall probes, grapples and collision queries normally.
	var surface: Material = material if material != null else _stone
	var body := DemoGeometry.box(geometry, center, size, surface, true)
	body.set_meta("timeline_phase", &"remnant")
	return body

func _outer_wall() -> void:
	spawn.position = Vector3(3.8,.08,7)
	_platform(Vector3(0,0,4),Vector2(10,10))
	_platform(Vector3(0,0,-15),Vector2(10,10))
	_platform(Vector3(-3,0,-29),Vector2(6,10))
	_platform(Vector3(0,0,-44),Vector2(12,12))
	_wall(Vector3(5.4,2.4,-6),Vector3(.8,6,24))
	for z: float in [-5.5,-6.0]:
		DemoGeometry.box(geometry,Vector3(4.97,2.2,z),Vector3(.04,2,.16),DemoGeometry.material(Color("#ffcd79"),1.1))
	_wall(Vector3(-6.4,2.4,-20),Vector3(.8,6,12))
	_wall(Vector3(-6.4,2.4,-35.5),Vector3(.8,6,5))
	DemoGeometry.box(geometry,Vector3(-6.4,5.3,-29.5),Vector3(.8,.65,7),_stone,true)
	# A low passage runs outside the wall route, ending in a slide-jump gap.
	_platform(Vector3(-6.8,0,5),Vector2(5.6,4))
	_platform(Vector3(-9,0,-3),Vector2(3,16))
	DemoGeometry.box(geometry,Vector3(-9,2.05,-3),Vector3(3,1.9,9),_iron,true)
	_platform(Vector3(-9,0,-27),Vector2(3.5,8))
	_platform(Vector3(-6.3,0,-29),Vector2(6,3))
	# Raised landings reward stronger wall kicks and sustained airborne movement.
	_platform(Vector3(2,4.4,-13),Vector2(3.8,5))
	_platform(Vector3(1,2.4,-27),Vector2(4,6))
	# R7 arcanist crossing: the lower lane remains readable, while this high
	# landing and its sentinel are intentionally separated from the opening
	# deck. A temporary wall/well created in the first altar segment gives the
	# arcanist a real combat-and-route payoff instead of a decorative construct.
	_platform(Vector3(3.2,3.2,-6.0),Vector2(3.2,3.6))
	_enemy(Vector3(3.2,3.28,-6.0),&"normal",&"caster")
	_route_marker(Vector3(3.2,3.28,-5.2),Color("#78dfbf"),&"rift")
	signature_sections[&"rift_crossing"]={
		"from":Vector3(2.4,0,5),"gap":Vector3(0,0,-1),
		"landing":Vector3(3.2,3.2,-6),"mechanics":[&"arcane_shape",&"wall_run",&"wind_well"]}
	_route_marker(Vector3(-9,.08,2),Color("#e3bd72"),&"slide")
	_route_marker(Vector3(4.5,.08,0),Color("#dd987d"),&"wall")
	_route_marker(Vector3(2,4.48,-13),Color("#75c5de"),&"air")
	_enemy(Vector3(0,.04,-12),&"normal",&"crossbow")
	_enemy(Vector3(-3,.04,-28),&"shield",&"heavy")
	_enemy(Vector3(0,.04,-44),&"elite",&"pursuer",true)
	_enemy(Vector3(-4.7,.04,-30.5),&"normal",&"caster")
	_mechanism(Vector3(-2,1.1,-15),&"bridge")
	_bridge = _platform(Vector3(-3,0,-21),Vector2(3,6))
	_set_bridge(false)
	_exit(Vector3(0,0,-48))

func _forge() -> void:
	spawn.position = Vector3(0,.08,6)
	_platform(Vector3(0,0,3),Vector2(8,10))
	_platform(Vector3(0,0,-9),Vector2(4,10))
	_platform(Vector3(4,0,-19),Vector2(7,8))
	# The upper forge deck keeps a rear lane behind the furnace cheek. The extra
	# depth is deliberate traversal space for circling the caster, not a flat
	# shortcut across the wall-run route.
	# Keep the raised landing physically present without putting a vertical front
	# face across the wind-well launch arc.  The previous 28 m slab began at
	# z=-18 and caught the player below its top surface, so the launch read as a
	# collision with an invisible wall instead of a route transfer.
	# Leave a capsule-width braking margin on both sides of the entry wall.
	# The wall exit is intentionally close to this deck edge; a 16 m slab let
	# the faster profession miss the real floor by a few centimetres while
	# descending from the wall.
	_platform(Vector3(0,3,-32),Vector2(12,20))
	# Separate the caster from the wind-well launch and protect its arrival.
	# A furnace cheek breaks both firing lines; the centre lane and the rear
	# approach at z=-37.5 remain open to either base profession.
	# Keep the furnace cheek beside the tutorial wall, outside the player's
	# two-metre wall probe. Its earlier x=2 placement was read as the first
	# runnable surface and pulled the runner into a dead-end cap before the
	# authored entrance face.
	# The caster must be shielded from the launch and upper-deck approach, but
	# the cover cannot occupy the player's centre lane. This offset cheek sits
	# between the caster and both protected sight lines while the rear approach
	# remains exposed and physically walkable.
	_wall(Vector3(3.0,4.4,-34),Vector3(.55,2.4,3.6))
	_wall(Vector3(5.0,4.5,-34),Vector3(.65,3,4))
	_wall(Vector3(7.0,4.5,-33),Vector3(3.4,3,.65))
	# The low service throat commits the player to a slide and releases them at
	# the first broken deck. Its 1.2 m clearance rejects the standing capsule.
	DemoGeometry.box(geometry,Vector3(0,2.05,1),Vector3(6,1.7,3),_iron,true)
	DemoGeometry.box(geometry,Vector3(-3.35,1.5,1),Vector3(.7,3,3),_stone,true)
	DemoGeometry.box(geometry,Vector3(3.35,1.5,1),Vector3(.7,3,3),_stone,true)
	# Keep the throat's exit readable under normal-input timing. The old two metre
	# seam between the entry slab and the first deck turned a valid slide-jump
	# into an accidental fall when the jump was buffered a few frames early.
	_platform(Vector3(0,-.02,-3),Vector2(5.5,2.2))
	_route_marker(Vector3(0,.08,4),Color("#d48f63"),&"slide")
	_wall(Vector3(8,2,-16),Vector3(.7,6,23))
	_timeline_wall(Vector3(-4.8,4.2,-20),Vector3(.7,7.0,11),DemoGeometry.material(Color("#40344e"),.35))
	# Place the wind well inside the real lower landing so a player arriving
	# from the slide-jump can trigger it without an edge-perfect interaction.
	# Keep the wind well beside the approach lane instead of under the upper
	# deck's front lip.  The player reaches it from the lower landing and
	# commits with the interaction key; the smaller auto radius prevents the
	# approach from consuming the launch before the player has lined up.
	_mechanism(Vector3(4.4,1.0,-20.6),&"launch")
	_mechanism(Vector3(-3,4.1,-29),&"seal")
	_platform(Vector3(-6,0,1),Vector2(5,3))
	_platform(Vector3(-7,1.8,-13),Vector2(3,5))
	_platform(Vector3(-5,3,-27),Vector2(3,5))
	_wall(Vector3(-9,3,-12),Vector3(.8,8,28))
	_route_marker(Vector3(-6,.08,1),Color("#75c5de"),&"air")
	for z: float in [-4,-16,-29]:
		DemoGeometry.box(geometry,Vector3(0,9,z),Vector3(24,.7,.8),_iron)
		for side: float in [-1,1]:
			DemoGeometry.box(geometry,Vector3(side*10,1,z),Vector3(.7,18,.8),_iron)
	var melt := ShaderMaterial.new()
	melt.shader = preload("res://assets/shaders/forge_melt.gdshader")
	DemoGeometry.box(geometry,Vector3(0,-9,-20),Vector3(27,.2,58),melt)
	signature_sections[&"chain_well"]={
		"start":Vector3(0,.08,6),"slide_exit":Vector3(0,.08,-.5),
		"wind":Vector3(4.4,1,-20.6),"upper_landing":Vector3(0,3,-32),
		"standing_clearance_m":1.2,"mechanics":[&"slide",&"slide_jump",&"launch"]}
	# The formal expansion appends the full forge route and installs its only
	# playable exit at the final landing. Do not create an early provisional gate
	# here; it would sit in the middle of the finished route for one physics frame
	# during a rebuild and read as a blocked doorway.

func _tower() -> void:
	spawn.position = Vector3(0,.08,7)
	_platform(Vector3(0,0,4),Vector2(8,10))
	_platform(Vector3(-5,1,-11),Vector2(5,10))
	_platform(Vector3(0,1,-24),Vector2(17,14))
	# The tower entry is a short departure deck for the bidirectional wall
	# tutorial.  Its old 28m depth nearly touched the hub and created a real
	# ground shortcut around the authored entrance wall.  Keep the visible stone
	# landing, but leave the route gap open so the wall is required.
	# The bidirectional wall exits at the near edge in either direction. The
	# extra four metres are a real stone braking lane and keep the capsule from
	# falling just outside the deck when the two wall faces hand off.
	_platform(Vector3(0,1,-39),Vector2(8,18))
	_wall(Vector3(-8,3,-6),Vector3(.8,7,27))
	_wall(Vector3(9,3,-24),Vector3(.8,7,18))
	_mechanism(Vector3(-6,2.1,-20),&"seal")
	_mechanism(Vector3(6,2.1,-20),&"seal")
	_mechanism(Vector3(-2,1.0,0),&"launch")
	_platform(Vector3(4,0,2),Vector2(4,4))
	_platform(Vector3(6,1,-12),Vector2(3,6))
	_wall(Vector3(8.2,3,-7),Vector3(.8,7,21))
	_timeline_wall(Vector3(5.0,4.0,-35),Vector3(.7,7.0,12),DemoGeometry.material(Color("#40344e"),.35))
	_route_marker(Vector3(4,.08,2),Color("#b9d39b"),&"air")
	# A readable interior nave encloses the last safe platforms. Beyond z=-44
	# the roof and side arcade stop together, revealing the floating tower route.
	# This is a visual nave roof, not a hidden recovery floor. Keeping it
	# visual-only prevents the reverse wall link from landing on the roof and
	# walking around the authored void, which would defeat the wall-run beat.
	var nave_roof := DemoGeometry.box(geometry,Vector3(0,5.2,-31.5),Vector3(17,.8,25),_stone,false)
	nave_roof.set_meta("visual_only",true)
	nave_roof.set_meta("environment_role",&"archive_roof")
	for side: float in [-1,1]:
		DemoGeometry.box(geometry,Vector3(side*8.1,3.1,-31.5),Vector3(.65,4.2,25),_stone,true)
	signature_sections[&"nave_to_void"]={
		"covered_start":Vector3(0,1,-24),"threshold":Vector3(0,1,-44),
		"exposed_landing":Vector3(0,1,-68),"roof_end_z":-44.0,
		"mechanics":[&"corridor",&"wall_run",&"air_dash"]}
	for i in range(8):
		var angle: float = TAU*i/8
		var point := Vector3(cos(angle)*13,5,-24+sin(angle)*13)
		DemoGeometry.cylinder(geometry,point,1.0,18,_stone)
		DemoGeometry.cylinder(geometry,point+Vector3.UP*7.8,1.5,.5,_iron)
		var arch := (load("res://assets/models/kenney_castle/tower-square-arch.glb") as PackedScene).instantiate() as Node3D
		arch.position = point+Vector3.UP*8
		arch.scale=Vector3.ONE*2
		geometry.add_child(arch)
	for side: float in [-1,1]:
		# Keep the cover behind the authored sentries; the previous front edge
		# intersected both capsule bodies even though their feet had support.
		DemoGeometry.box(geometry,Vector3(side*3.5,2,-26),Vector3(.8,2,1.6),_stone,true)
	# The formal expansion owns the tower's final exit after the vertical route is
	# assembled. The entry blockout intentionally has no separate gate.

func _scenery() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-38,-65,0)
	key.light_color=Color("#bbcddb")
	key.light_energy=.52
	key.shadow_enabled=true
	geometry.add_child(key)
	for z: float in [5,-10,-25,-40]:
		var light := OmniLight3D.new()
		light.position = Vector3(0,6,z)
		light.light_color = Color("#d0dce4")
		light.light_energy = .10
		light.omni_range = 18
		geometry.add_child(light)
		if stage==2:
			for side: float in [-1,1]:
				DemoGeometry.cylinder(geometry,Vector3(side*12,-3,z),1.6,16,_iron)
				DemoGeometry.cylinder(geometry,Vector3(side*12,2,z),1.7,.6,_accent)
		for side: float in [-1,1]:
			DemoGeometry.box(geometry,Vector3(side*13,-6,z),Vector3(2,18,2),_stone)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(side*7,3,z)
			lamp.light_color = [Color("#62bac7"),Color("#ee8860"),Color("#c8db9b")][stage-1]
			lamp.light_energy = 2
			lamp.omni_range = 10
			geometry.add_child(lamp)
	for point: Vector3 in ([Vector3(-3.8,0,6),Vector3(3.8,0,-16),Vector3(-4.8,0,-42)] if stage==1 else ([Vector3(2.8,0,5),Vector3(5.8,0,-17),Vector3(4.6,3,-35)] if stage==2 else [Vector3(2.8,0,6),Vector3(-6.5,1,-12),Vector3(7,1,-28)])):
		var entry_brazier_offset := Vector3(0,0,-2) if stage > 1 and point.z > -5 else Vector3.ZERO
		CitadelDressing.brazier(geometry,point+entry_brazier_offset)

func _route_marker(point: Vector3, color: Color, kind: StringName) -> void:
	var surface := DemoGeometry.material(color, .7)
	for i in range(3):
		var arrow := DemoGeometry.box(geometry,point+Vector3(0,0,-i*.38),Vector3(.55,.025,.08),surface)
		if kind == &"wall":
			arrow.rotation.z = -.45
		elif kind == &"air":
			arrow.rotation.y = PI/4.0

func _build_checkpoints() -> void:
	# Checkpoint triggers are children of the actual altars. They have no
	# separate mesh, label, or location in the route, so a player can only save
	# at a real altar and never at an invisible mid-course marker.
	for index in altars.size():
		var altar_device:RunAltar=altars[index]
		var area:=Area3D.new()
		area.name="AltarCheckpoint_%d_%d"%[stage,index+1]
		area.position=Vector3.ZERO
		area.collision_layer=0
		area.collision_mask=2
		area.set_meta("checkpoint_id",StringName("stage_%d_altar_%d"%[stage,index+1]))
		area.set_meta("checkpoint_index",index+1)
		altar_device.add_child(area)
		var shape:=CollisionShape3D.new()
		var bounds:=BoxShape3D.new()
		bounds.size=Vector3(3.8,2.6,3.8)
		shape.shape=bounds
		shape.position.y=1.3
		area.add_child(shape)
		area.body_entered.connect(_checkpoint_body_entered.bind(area))
		checkpoint_areas.append(area)

func _checkpoint_body_entered(body:Node3D,area:Area3D)->void:
	if not enabled or not body is ParkourPlayer:return
	var altar_device:=area.get_parent() as RunAltar
	if not is_instance_valid(altar_device):return
	if not preload("res://scripts/run/timeline_collision.gd").active(altar_device):return
	# Reaching an unclaimed altar is not enough to create a recovery snapshot;
	# the checkpoint is committed when its rune choice is completed.
	if not altar_device.used:return
	var id:StringName=area.get_meta("checkpoint_id",&"")
	if reached_checkpoints.has(id):return
	reached_checkpoints[id]=true
	var index:int=area.get_meta("checkpoint_index",0)
	checkpoint_reached.emit(id,altar_checkpoint_pose(altar_device,body.global_position),index)

func altar_checkpoint_pose(device:RunAltar,from_position:Vector3=Vector3.ZERO)->Transform3D:
	if not is_instance_valid(device):return Transform3D(Basis.IDENTITY,global_position)
	var away:=from_position-device.global_position
	away.y=0.0
	if away.length_squared()<.04:away=Vector3.FORWARD
	away=away.normalized()
	# Respawn just outside the altar collision footprint so the player never
	# reappears inside the brazier or clips through the offering mesh. Clamp the
	# point to the shared slab rather than trusting a phase-owned platform edge.
	var target := device.global_position + away * 2.25
	for support: Node in geometry.find_children("*", "StaticBody3D", true, false):
		if not support.get_meta("timeline_shared_support", false):
			continue
		if support.get_meta("support_for_altar", NodePath()) != device.get_path():
			continue
		var support_size: Vector2 = support.get_meta("support_size", Vector2(5.2, 5.2))
		target.x = clampf(target.x, device.global_position.x - support_size.x * .5 + 1.0, device.global_position.x + support_size.x * .5 - 1.0)
		target.z = clampf(target.z, device.global_position.z - support_size.y * .5 + 1.0, device.global_position.z + support_size.y * .5 - 1.0)
		target.y = support.global_position.y + .55 + .08
		break
	return Transform3D(Basis.IDENTITY,target)

func safe_respawn_pose(pose: Transform3D) -> Transform3D:
	# Validate the saved point against the currently active world. If a stale
	# checkpoint points into a retired deck, use a real upward-facing surface
	# under it, then fall back to the room spawn instead of spawning in air.
	var target := pose.origin
	if is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 2.5, target - Vector3.UP * 8.0, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and Vector3(hit.normal).y > .72:
			return Transform3D(pose.basis, Vector3(hit.position) + Vector3.UP * .08)
	for candidate_variant in platform_extents.keys():
		var center := Vector3(candidate_variant)
		var owner := platform_at(center)
		var owner_phase := preload("res://scripts/run/timeline_collision.gd").phase_of(owner) if owner != null else &""
		if owner_phase not in [&"", timeline_phase]:
			continue
		var size: Vector2 = platform_extents[candidate_variant]
		if absf(target.x - center.x) <= size.x * .5 and absf(target.z - center.z) <= size.y * .5:
			var safe := Vector3(clampf(target.x, center.x - size.x * .5 + 1.0, center.x + size.x * .5 - 1.0), center.y + .08, clampf(target.z, center.z - size.y * .5 + 1.0, center.z + size.y * .5 - 1.0))
			return Transform3D(pose.basis, safe)
	return spawn.global_transform if is_instance_valid(spawn) else pose

func altar_checkpoint_index(device:RunAltar)->int:
	return altars.find(device)+1 if is_instance_valid(device) else 0

func checkpoint_defeated_ids()->Array[StringName]:
	var ids:Array[StringName]=[]
	for enemy in enemies:
		if enemy.health<=0:ids.append(enemy.get_meta("encounter_id",StringName(enemy.name)))
	return ids

func restore_checkpoint(defeated_ids:Array[StringName])->Array[LanternAcolyte]:
	clear_effects()
	var defeated_lookup:Dictionary={}
	for id in defeated_ids:defeated_lookup[id]=true
	var revived:Array[LanternAcolyte]=[]
	defeated_count=0
	for enemy in enemies:
		var id:StringName=enemy.get_meta("encounter_id",StringName(enemy.name))
		if defeated_lookup.has(id):
			defeated_count+=1
			enemy.active=false
			continue
		if is_instance_valid(enemy.brain):enemy.global_position=enemy.brain.home
		enemy.reset_enemy()
		enemy.active=enabled
		revived.append(enemy)
	exit_unlocked=false
	if is_instance_valid(_gate):_gate.visible=true
	if is_instance_valid(_gate_shape):_gate_shape.set_deferred("disabled",not enabled)
	if is_instance_valid(_exit_title):_exit_title.text=stage_title
	_refresh_exit()
	return revived

func _spawn_configured_encounters() -> void:
	for entry: LevelEncounterEntry in _configuration.encounters:
		if entry.stage!=stage:continue
		var enemy := _enemy(entry.position_m,StringName(entry.archetype),StringName(entry.role),entry.required_guardian,entry)
		# The first route's high sentinel belongs to the remnant timeline. Keeping
		# this authored phase tag in the same data entry as its spawn position
		# prevents a second hand-built enemy from diverging during room rebuilds.
		if entry.timeline_phase in ["present","remnant"]:
			enemy.set_meta("timeline_phase",StringName(entry.timeline_phase))
			enemy.set_meta("phase_route_node",true)
		if entry.route_contract != "shared":
			enemy.set_meta("route_contract",StringName(entry.route_contract))

func _enemy(point: Vector3, kind: StringName, role: StringName = &"crossbow", required: bool = false, entry: LevelEncounterEntry = null) -> LanternAcolyte:
	var enemy := LanternAcolyte.new()
	enemy.archetype = kind
	enemy.position = point
	enemy.gameplay_role = role
	enemy.required_guardian = required
	# Set the authored role before _ready; the gameplay adapter consumes it.
	enemy.set_meta("gameplay_role",role)
	enemy.set_meta("required_guardian",required)
	if entry!=null:
		enemy.encounter_id = entry.id
		enemy.initial_delay_seconds = entry.initial_delay_seconds
		enemy.set_meta("encounter_id",entry.id)
		enemy.set_meta("initial_delay_seconds",entry.initial_delay_seconds)
		enemy.attack_range=entry.attack_range_m
	geometry.add_child(enemy)
	if is_instance_valid(enemy.boss_controller):
		enemy.boss_controller.exposure_window_seconds = _configuration.mechanisms.seal_exposure_seconds
	enemies.append(enemy)
	if required:_required_enemies.append(enemy)
	enemy.defeated.connect(_enemy_defeated)
	enemy.fired.connect(func(): enemy_fired.emit())
	enemy.seal_requested.connect(_rearm_seals)
	enemy.guard_opened.connect(func(): guard_broken.emit())
	return enemy

func register_timeline_contract(id: StringName, phases: Array[StringName], nodes: Array[Vector3], mechanics: Array[StringName]) -> void:
	var contract := {
		"id": id,
		"phases": phases.duplicate(),
		"nodes": nodes.duplicate(),
		"mechanics": mechanics.duplicate(),
		"requires_air_shift": phases.size() > 1 and phases[0] != phases[1],
	}
	timeline_contracts.append(contract)
	signature_sections[id] = contract

func _rearm_seals() -> void:
	for device in mechanisms:
		if device.kind == &"seal":
			device.reset_device()

func _mechanism(point: Vector3, kind: StringName) -> void:
	var device := RunMechanism.new()
	device.kind = kind
	device.position = point
	device.tuning=_configuration.mechanisms
	geometry.add_child(device)
	mechanisms.append(device)
	device.activated.connect(_mechanism_activated.bind(device))

func _mechanism_activated(device: RunMechanism) -> void:
	mechanism_used.emit()
	if device.kind == &"bridge":
		_set_bridge(true)
	elif device.kind == &"seal":
		for other in mechanisms:
			if other.kind == &"seal" and not other.used:
				return
		for enemy in enemies:
			if enemy.archetype in [&"miniboss",&"boss"]:
				enemy.break_guard(_configuration.mechanisms.seal_exposure_seconds)
	_refresh_exit()

func _set_bridge(value: bool) -> void:
	_bridge_open = value
	if is_instance_valid(_bridge):
		_bridge.visible = value
		for shape in _bridge.find_children("*","CollisionShape3D",true,false):
			shape.set_deferred("disabled",not value or not enabled)

func _exit(point: Vector3) -> void:
	_gate = DemoGeometry.box(geometry,point+Vector3.UP*1.6,Vector3(3,3.2,.15),_accent,true)
	_gate.set_meta("interactive_visual",true)
	var veil := DemoGeometry.material(Color(.47,.67,.61,.18),.3)
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(_gate.get_child(1) as MeshInstance3D).material_override = veil
	CitadelDressing.asset(geometry,"gothic_bay",point,Vector3(.83,.86,.7))
	_gate_shape = _gate.get_child(0) as CollisionShape3D
	_exit_title = DemoGeometry.label(geometry,point+Vector3.UP*3.8,stage_title,32)
	exit_area = Area3D.new()
	exit_area.position = point+Vector3.UP
	exit_area.collision_layer = 16
	exit_area.collision_mask = 2
	geometry.add_child(exit_area)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(4,3,2)
	shape.shape = bounds
	exit_area.add_child(shape)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	process_mode = PROCESS_MODE_PAUSABLE if value else PROCESS_MODE_DISABLED
	# The exit trigger belongs to this room just like its gate and enemies. Keep
	# it out of the active physics world while another stage is loaded; otherwise
	# a player can carry an overlap from the previous room into the next stage.
	if is_instance_valid(exit_area):
		exit_area.monitoring = value
		exit_area.monitorable = value
		exit_area.collision_layer = 16 if value else 0
		exit_area.collision_mask = 2 if value else 0
	if is_instance_valid(geometry):
		if not value and not _collisions_suspended:
			for shape: CollisionShape3D in geometry.find_children("*","CollisionShape3D",true,false):
				_suspended_shapes[shape] = shape.disabled
				shape.set_deferred("disabled",true)
			_collisions_suspended = true
		elif value and _collisions_suspended:
			for shape: CollisionShape3D in _suspended_shapes:
				if is_instance_valid(shape):shape.set_deferred("disabled",_suspended_shapes[shape])
			_suspended_shapes.clear()
			_collisions_suspended = false
	for enemy in enemies:
		enemy.active = value
	# These states may change while the room is suspended. They take precedence
	# over the saved shapes; enabling a room must never close an opened route.
	if is_instance_valid(_gate_shape):_gate_shape.set_deferred("disabled",not value or exit_unlocked)
	_set_bridge(_bridge_open)
	for device in terrain_devices:device.sync_collision_state(value)
	apply_timeline_phase(timeline_phase)

func reset_room(player: ParkourPlayer, number: int = 1) -> bool:
	# Validate and snapshot before discarding the existing room or progress.
	if not _build(number):return false
	clear_effects()
	defeated_count = 0
	set_enabled(true)
	for enemy in enemies:
		enemy.player = player
		enemy.cooldown = enemy.initial_delay_seconds
	for device in mechanisms:
		device.player = player
	for device in altars:device.player=player
	for device in terrain_devices:device.player=player
	for construct: Node in geometry.find_children("*","StaticBody3D",true,false):
		if construct is RiftConstruct: construct.player=player
	return true

func _extra_altar(point: Vector3) -> void:
	var device := RunAltar.new()
	device.position=_grounded_platform_point(point)
	device.set_meta("grounded_checkpoint",true)
	device.set_meta("timeline_shared",true)
	geometry.add_child(device)
	_add_shared_altar_support(device)
	device.requested.connect(func(a: RunAltar):altar_requested.emit(a))
	altars.append(device)

func _add_shared_altar_support(device: RunAltar) -> void:
	# The altar is the same save/reward node in both timelines. Give it a compact,
	# explicit slab that is never assigned a timeline phase, even when the nearby
	# route deck is present-only or remnant-only.
	if not is_instance_valid(device) or not is_instance_valid(geometry):
		return
	var support := DemoGeometry.box(geometry, device.position - Vector3.UP * .55, Vector3(5.2, 1.1, 5.2), _floor, true)
	support.name = "SharedAltarSupport_%d" % altars.size()
	support.set_meta("timeline_shared_support", true)
	support.set_meta("support_for_altar", device.get_path())
	support.set_meta("support_size", Vector2(5.2, 5.2))
	CitadelDressing.paving(support, Vector3.UP * .55, Vector2(5.2, 5.2))

func clear_effects() -> void:
	for group in ["friendly_projectiles","hostile_projectiles","transient_effects"]:
		for projectile in get_tree().get_nodes_in_group(group):
			projectile.queue_free()

func _enemy_defeated(_enemy: LanternAcolyte) -> void:
	defeated_count += 1
	_refresh_exit()

func _refresh_exit() -> void:
	if exit_unlocked or (stage == 1 and not _bridge_open):
		return
	# Every formal route is built around a movement/combat core. The altar is
	# intentionally a hard gate: a run that skips its first build cannot clear
	# the room by flattening enemies with the base weapon alone.
	if not is_instance_valid(altar) or not altar.used:
		if is_instance_valid(_exit_title): _exit_title.text = "先在祭坛选择职业构筑"
		return
	if not _has_core_build():
		if is_instance_valid(_exit_title): _exit_title.text = "需要职业核心构筑"
		return
	for enemy in _required_enemies:
		if enemy.health > 0:
			return
	if not _required_enemies.is_empty():
		exit_unlocked = true
		_gate.visible = false
		_gate_shape.set_deferred("disabled",true)
		_exit_title.text = "封印已解"
		cleared.emit()

func _has_core_build() -> bool:
	if not is_instance_valid(altar) or not is_instance_valid(altar.player):
		return false
	var combat_node := altar.player.get_node_or_null("Combat") as PlayerCombat
	if combat_node == null or combat_node.runes.is_empty():
		return false
	for id: StringName in combat_node.runes:
		if bool(RuneCatalog.definition(id).get("core", false)):
			return true
	return false

func objective_text() -> String:
	if not altar.used:
		return "E · 祭坛"
	if not _has_core_build():
		return "祭坛 · 核心"
	if exit_unlocked:
		return "出口已开"
	var discovered: int=0
	for device in altars:
		if device.used:discovered+=1
	var guardians: int=0
	for enemy in _required_enemies:
		if enemy.health>0:guardians+=1
	var progress := " · 契印 %d/%d · 守卫 %d" % [discovered,altars.size(),guardians]
	if stage == 1:
		if is_instance_valid(altar.player):
			var z := to_local(altar.player.global_position).z
			if z> -45:return "右墙 · Shift"
			if z> -73:return "蹬墙 · 换侧"
			if z> -88:return "绕盾 · 破核"
			if z> -108:return "V 回现世 · 滑铲 → 跳" if timeline_phase == &"remnant" else "滑铲 → 跳"
			if z> -150:return "E · 牵引"
			if z> -205:return "断桥 · 高锚"
			if z> -240:return "牵引 · 上墙"
			if z> -272:return "换向 · 牵引"
		return "钟塔 · 破核"+progress
	return ("执刑官 · 破炉" if stage == 2 else "祭祀 · 破链")+progress

func interaction_target() -> Node3D:
	if not enabled or not is_instance_valid(altar.player) or not altar.player.control_enabled:
		return null
	var player := altar.player
	var origin := player.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(origin,origin-player.camera.global_basis.z*ParkourGrapple.RANGE,5,[player.get_rid()])
	var contact := player.get_world_3d().direct_space_state.intersect_ray(ray)
	var target := contact.get("collider") as Node3D
	if target is RiftConstruct and target.kind==&"anchor":
		return target if player.grapple.can_begin(target) else null
	if (target is RunAltar or target is RunMechanism or target is TerrainDevice) and not contact.is_empty() and origin.distance_to(contact.position)<=_configuration.mechanisms.interaction_range_m:
		return target
	# The altar mesh can sit behind its visible plinth or a phase-shared floor
	# edge, so a camera ray is not a reliable sole selector at close range. A
	# real unused altar within the authored interaction radius remains the
	# unambiguous nearby target and keeps the prompt actionable.
	var nearest_altar: RunAltar = null
	var nearest_distance := 3.5
	for candidate: RunAltar in altars:
		if not is_instance_valid(candidate) or candidate.used:
			continue
		var distance := player.global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_altar = candidate
	if nearest_altar != null:
		return nearest_altar
	return player.grapple.best_anchor()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not event.is_action_pressed("interact"):
		return
	if is_instance_valid(altar.player) and altar.player.grapple.active:
		# The interaction press commits the whole grapple traversal. E is not a
		# second manual-release control while the route handoff is in progress.
		return
	var target := interaction_target()
	if target is RunAltar:
		target.request()
	elif target is RunMechanism:
		target.activate()
	elif target is TerrainDevice:
		target.activate()
	elif target is RiftConstruct and target.kind == &"anchor":
		target.activate()
