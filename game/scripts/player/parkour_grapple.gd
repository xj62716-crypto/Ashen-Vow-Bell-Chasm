class_name ParkourGrapple
extends Node3D

signal arrived(anchor: Node3D)
signal traversed(anchor: Node3D)
signal released
signal state_changed(phase: StringName, reason: StringName)
const RANGE: float = 34.0
const LAUNCH_TIME: float = .04
const DEFAULT_ROUTE_EXIT_DISTANCE: float = 2.8
const MIN_ROUTE_EXIT_DISTANCE: float = 1.5
const MAX_ROUTE_EXIT_DISTANCE: float = 6.0
const MAX_DURATION: float = .95
const REGRAB_DELAY: float = .35
var phase: StringName = &"idle"
var exit_reason: StringName = &""
var progress: float = 0.0
var _exit_forward := Vector3.FORWARD
var _initial_distance: float = 0.0
var _last_anchor_id: int = 0
var _regrab_left: float = 0.0
var player: ParkourPlayer
var anchor: Node3D
var active: bool = false
var age: float = 0.0
var speed: float = 0.0
var rope_length: float = 0.0
var tension: float = 0.0
var peak_speed: float = 0.0
var _start_position := Vector3.ZERO
var _traversed: bool = false
var route_exit_distance: float = DEFAULT_ROUTE_EXIT_DISTANCE
var _entry_tangent := Vector3.ZERO
var _cable := ImmediateMesh.new()
var _visual: MeshInstance3D
var _hook: MeshInstance3D

func _ready() -> void:
	player = get_parent() as ParkourPlayer
	_visual = MeshInstance3D.new()
	_visual.mesh = _cable
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#879e9b")
	material.metallic = .35
	material.roughness = .38
	material.emission_enabled=true
	material.emission=Color("#273634")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_visual.material_override = material
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	_hook = MeshInstance3D.new()
	var tip := PrismMesh.new()
	tip.size = Vector3(.16,.26,.10)
	_hook.mesh = tip
	_hook.material_override = material
	add_child(_hook)
	_hook.hide()
	player.recovered.connect(cancel)

func can_begin(target: Node3D) -> bool:
	if active or not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion() or not player.control_enabled or get_tree().paused:
		return false
	if _regrab_left > 0 and target.get_instance_id() == _last_anchor_id: return false
	var distance := target.global_position.distance_to(player.camera.global_position)
	return distance >= 2.0 and distance <= RANGE and not _cable_blocked(player.camera.global_position,target)

## Small aim tolerance for high-speed acquisition. The room keeps nearby altar /
## device priority and calls this only when its exact interaction ray missed.
func best_anchor() -> RiftConstruct:
	if active or not player.control_enabled or get_tree().paused: return null
	var best: RiftConstruct
	var best_score: float = INF
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z
	for node in get_tree().get_nodes_in_group("parkour_constructs"):
		if not node is RiftConstruct or node.kind != &"anchor": continue
		var offset: Vector3 = node.global_position-origin
		var distance := offset.length()
		if distance < 2 or distance > RANGE: continue
		var alignment := forward.dot(offset/distance)
		# 4.5 degrees, capped at a 1.2 m lateral cone; no through-wall selection.
		if alignment < cos(deg_to_rad(4.5)) or offset.cross(forward).length() > 1.2: continue
		var score := (1.0-alignment)*100 + distance*.0005
		if score < best_score and can_begin(node):
			best = node
			best_score = score
	return best

func begin(target: Node3D) -> bool:
	if not can_begin(target): return false
	if player.crouched:
		player._end_slide()
		if player.crouched: return false
	anchor = target
	active = true
	age = 0.0
	progress = 0.0
	speed = maxf(10.0,minf(player.parkour_profile.grapple_pull_speed,player.velocity.length()))
	_initial_distance = target.global_position.distance_to(player.global_position+Vector3.UP*1.1)
	rope_length = _initial_distance
	route_exit_distance = _authored_route_exit_distance(target)
	peak_speed = player.velocity.length()
	tension = 0.0
	_start_position = player.global_position
	_traversed = false
	var approach := target.global_position-player.global_position
	approach.y = 0
	var incoming := Vector3(player.velocity.x,0,player.velocity.z)
	_exit_forward = incoming.normalized() if incoming.length() > 4.0 else (approach.normalized() if approach.length() > .2 else incoming.normalized())
	if _exit_forward.length_squared() < .5: _exit_forward = -player.global_basis.z
	_entry_tangent = incoming - approach.normalized() * incoming.dot(approach.normalized()) if approach.length_squared() > .04 else Vector3.ZERO
	player._stop_wall(false)
	player._same_wall_reattach_ready = false
	player._dash_wall_normal = Vector3.ZERO
	player._dash_left = 0.0
	player._dash_direction = Vector3.ZERO
	player._coyote_left = 0.0
	player._wall_coyote_left = 0.0
	player._jump_buffer_left = 0.0
	player._slide_jump_left = 0.0
	player.floating = false
	player._ignore_floor_once = true
	_hook.show()
	_set_phase(&"launch")
	return true

func _set_phase(value: StringName, reason: StringName = &"") -> void:
	phase = value
	exit_reason = reason
	state_changed.emit(phase,reason)

func status() -> Dictionary:
	return {"phase":phase,"reason":exit_reason,"progress":progress,"elapsed":age,"active":active,"speed":speed,"peak_speed":peak_speed,"route_exit_distance":route_exit_distance,"automatic_release":true}

func cancel() -> void:
	var changed := active or phase != &"idle"
	_clear()
	_regrab_left = 0.0
	_last_anchor_id = 0
	if changed: _set_phase(&"idle",&"cancelled")

func _clear() -> void:
	active = false
	anchor = null
	tension = 0.0
	_cable.clear_surfaces()
	if is_instance_valid(_hook): _hook.hide()

func release() -> void:
	_finish(&"manual")

func _finish(reason: StringName) -> void:
	if not active: return
	var target := anchor
	var useful := reason in [&"arrived",&"manual",&"jump",&"dash"] and player.global_position.distance_to(_start_position) >= 6 and progress*_initial_distance >= 4
	# Every exit is bounded. Manual release keeps the player's chosen timing and
	# tangent, while automatic arrival guarantees enough forward speed to reach
	# the authored landing without retaining the high pull velocity.
	var flat := Vector3(player.velocity.x,0,player.velocity.z)
	var direction := flat.normalized() if flat.length() > 2 else _exit_forward
	if reason == &"arrived":
		# Looking around during the pull never rotates the authored route. The
		# locked approach heading is the base; only a real tangent can bias it.
		direction = _exit_forward
	if reason == &"arrived":
		var route_direction := _authored_route_direction(target)
		if route_direction.length_squared() > .25:
			direction = route_direction
	var speed_cap := player.parkour_profile.grapple_exit_speed
	var lift_cap := player.parkour_profile.grapple_exit_lift
	if is_instance_valid(target) and target is RiftConstruct:
		speed_cap = minf(speed_cap,target.grapple_exit_speed)
		lift_cap = minf(lift_cap,target.grapple_exit_lift)
	if reason == &"manual":
		# Manual release is reserved for system teardown and keeps the exact
		# velocity already produced by the pull. Gameplay never asks the player
		# to use this path; the authored route handoff below is automatic.
		speed = player.velocity.length()
		player._momentum_left = player.parkour_profile.grapple_exit_momentum_seconds
		player._coyote_left = 0.0
		player._jump_buffer_left = 0.0
		player._jump_held = Input.is_action_pressed("jump")
		player._ignore_floor_once = not player.is_on_floor()
		if is_instance_valid(target): _last_anchor_id = target.get_instance_id()
		_regrab_left = REGRAB_DELAY
		_clear()
		_set_phase(&"detached",reason)
		released.emit()
		return
	var exit_speed := minf(flat.length(),speed_cap)
	if reason == &"arrived":
		# High anchors become nearly vertical inside the release shell, so their
		# instantaneous flat pull speed cannot define the landing trajectory.
		exit_speed = speed_cap
		progress = 1.0
	player.velocity = direction*exit_speed+Vector3.UP*clampf(player.velocity.y,-8.0,lift_cap)
	speed = player.velocity.length()
	player._momentum_left = player.parkour_profile.grapple_exit_momentum_seconds
	player._coyote_left = 0.0
	player._jump_buffer_left = 0.0
	player._jump_held = Input.is_action_pressed("jump")
	player._ignore_floor_once = not player.is_on_floor()
	if is_instance_valid(target): _last_anchor_id = target.get_instance_id()
	_regrab_left = REGRAB_DELAY
	_clear()
	_set_phase(&"detached",reason)
	# Notifications happen after release so listeners see consistent state and
	# can safely delete constructs / transition the room.
	if useful and not _traversed and is_instance_valid(target) and not target.is_queued_for_deletion():
		_traversed = true
		traversed.emit(target)
	if reason == &"arrived" and is_instance_valid(target) and not target.is_queued_for_deletion(): arrived.emit(target)
	released.emit()

func _physics_process(delta: float) -> void:
	_regrab_left = maxf(0.0,_regrab_left-delta)

func advance(delta: float) -> void:
	if not active or delta <= 0.0 or get_tree().paused: return
	if not player.control_enabled:
		cancel()
		return
	if not is_instance_valid(anchor) or not anchor.is_inside_tree() or anchor.is_queued_for_deletion():
		_finish(&"anchor_lost")
		return
	var harness := player.global_position+Vector3.UP*1.1
	var offset := anchor.global_position-harness
	if offset.length() > RANGE+2.0:
		_finish(&"out_of_range")
		return
	if _cable_blocked(harness,anchor):
		_finish(&"blocked")
		return
	age += delta
	# A grapple is committed on the single interaction press. Jump, dash and
	# releasing E are movement inputs during the flight; they must not turn a
	# route traversal into a second timing task. System-level calls to release()
	# remain available for respawn, room teardown and authored interrupts.
	if age > MAX_DURATION:
		_finish(&"timeout")
		return
	if age >= LAUNCH_TIME:
		if phase != &"pull": _set_phase(&"pull")
		var route_distance := Vector2(offset.x,offset.z).length()
		var vertical_ready := absf(offset.y) <= player.parkour_profile.grapple_vertical_exit_gap
		if (route_distance <= route_exit_distance and vertical_ready) or offset.length() <= route_exit_distance:
			_finish(&"arrived")
			return
		speed = move_toward(speed,player.parkour_profile.grapple_pull_speed,player.parkour_profile.grapple_pull_acceleration*delta)
		# Capping this step at the route exit shell prevents low-FPS overshoot.
		# The pull is a short, authored zip rather than a pendulum: no gravity is
		# accumulated along the cable and the incoming tangent fades within a few
		# frames.
		var tether_direction := offset.normalized()
		var pull_step := minf(speed,maxf(0,offset.length()-route_exit_distance+.02)/delta)
		var pull_velocity := tether_direction*pull_step
		pull_velocity.y = clampf(pull_velocity.y*player.parkour_profile.grapple_vertical_scale,-player.parkour_profile.grapple_vertical_speed,player.parkour_profile.grapple_vertical_speed)
		var tangent_velocity := player.velocity-tether_direction*player.velocity.dot(tether_direction)
		# Preserve only a small amount of the entry line. This keeps a lateral
		# hook readable without turning the route into a long swing.
		tangent_velocity += _entry_tangent * minf(1.0, delta * 8.0)
		tangent_velocity *= exp(-12.0*delta)
		var stick := Input.get_vector("move_left","move_right","move_forward","move_backward")
		var steer_world := player.global_basis*Vector3(stick.x,0,stick.y)
		var steer_tangent := steer_world-tether_direction*steer_world.dot(tether_direction)
		if steer_tangent.length_squared()>.001:
			tangent_velocity += steer_tangent.normalized()*player.parkour_profile.grapple_steer_acceleration*delta
		tangent_velocity=tangent_velocity.limit_length(6.0)
		player.velocity=(pull_velocity+tangent_velocity).limit_length(player.parkour_profile.grapple_max_speed)
		player.velocity.y=clampf(player.velocity.y,-player.parkour_profile.grapple_vertical_speed,player.parkour_profile.grapple_vertical_speed)
	else:
		player.velocity.y -= player.gravity*delta
	var before := player.global_position
	var commanded := player.velocity
	player.move_and_slide()
	peak_speed = maxf(peak_speed,player.velocity.length())
	harness = player.global_position+Vector3.UP*1.1
	rope_length = harness.distance_to(anchor.global_position) # compatibility telemetry only
	progress = clampf(1.0-rope_length/maxf(_initial_distance,.01),0.0,1.0)
	if player.global_position.y < player.fall_limit:
		cancel()
		player.fell_out.emit()
		return
	if _cable_blocked(harness,anchor):
		_finish(&"blocked")
		return
	if age < LAUNCH_TIME: return
	for index in range(player.get_slide_collision_count()):
		if player.get_slide_collision(index).get_normal().dot(commanded.normalized()) < -.45:
			_finish(&"blocked")
			return
	var route_distance := Vector2(offset.x,offset.z).length()
	var vertical_ready := absf(offset.y) <= player.parkour_profile.grapple_vertical_exit_gap + .05
	if (route_distance <= route_exit_distance+.025 and vertical_ready) or rope_length <= route_exit_distance+.025:
		# Restore the approach velocity after the final fractional physical step.
		player.velocity = commanded.normalized()*speed
		_finish(&"arrived")
	elif age > LAUNCH_TIME+.12 and player.global_position.distance_to(before) < .015:
		_finish(&"blocked")
func _authored_route_exit_distance(target: Node3D) -> float:
	if target is RiftConstruct:
		return clampf(target.grapple_release_distance,MIN_ROUTE_EXIT_DISTANCE,MAX_ROUTE_EXIT_DISTANCE)
	return DEFAULT_ROUTE_EXIT_DISTANCE

func _authored_route_direction(target: Node3D) -> Vector3:
	if not is_instance_valid(target): return Vector3.ZERO
	var followup: Variant = target.get_meta("followup_wall", {})
	if followup is Dictionary and followup.has("point"):
		var point: Vector3 = followup["point"] as Vector3
		var direction := point-player.global_position
		direction.y = 0.0
		if direction.length_squared() > .25: return direction.normalized()
	var route_exit: Variant = target.get_meta("grapple_exit", {})
	if route_exit is Dictionary and route_exit.has("direction"):
		var authored: Vector3 = route_exit["direction"] as Vector3
		authored.y = 0.0
		if authored.length_squared() > .25: return authored.normalized()
	return Vector3.ZERO

func _cable_blocked(origin: Vector3,target: Node3D) -> bool:
	var exclusions: Array[RID] = [player.get_rid()]
	if target is CollisionObject3D:exclusions.append(target.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin,target.global_position,player.collision_mask,exclusions)
	return not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _process(_delta: float) -> void:
	_cable.clear_surfaces()
	if not active or not is_instance_valid(anchor):return
	var arms := player.get_node_or_null("FirstPersonArms") as FirstPersonArms
	var start := arms.grapple_world_position() if arms!=null else player.camera.global_transform*Vector3(-.25,-.23,-.38)
	var finish := start.lerp(anchor.global_position,minf(1.0,age/LAUNCH_TIME))
	var direction := (finish-start).normalized()
	var side := direction.cross(player.camera.global_basis.z)
	if side.length_squared()<.01:side=player.camera.global_basis.x
	side=side.normalized()*.009
	_cable.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(25):
		var t := i/24.0
		var point := start.lerp(finish,t)+Vector3.DOWN*sin(t*PI)*.08*(1-minf(age*5,1))
		_cable.surface_add_vertex(to_local(point-side))
		_cable.surface_add_vertex(to_local(point+side))
	_cable.surface_end()
	_hook.global_position=finish
	if direction.length_squared()>.1:_hook.global_basis=Basis.looking_at(direction)
