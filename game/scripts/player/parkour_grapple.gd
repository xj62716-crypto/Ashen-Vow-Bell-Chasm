class_name ParkourGrapple
extends Node3D

signal arrived(anchor: Node3D)
signal traversed(anchor: Node3D)
signal released
signal state_changed(phase: StringName, reason: StringName)
const RANGE: float = 34.0
const LAUNCH_TIME: float = .025
const DEFAULT_ROUTE_EXIT_DISTANCE: float = 2.8
const MIN_ROUTE_EXIT_DISTANCE: float = 1.5
const MAX_ROUTE_EXIT_DISTANCE: float = 6.0
## The line is a committed zip, not a swing state.  Half a second is the
## absolute safety bound for a moving or distant anchor; normal anchors arrive
## earlier and release on the authored route shell.
const MAX_DURATION: float = .50
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
	# Ghostrunner-style traversal commits to a short, high-speed zip on the
	# single press. There is no low-speed wind-up that reads as a hanging pull.
	speed = player.parkour_profile.grapple_pull_speed
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
	# Manual release keeps the player's chosen timing and tangent. Automatic
	# release carries the zip impulse through the handoff so the line never reads
	# like a brake; the profile maximum remains the only hard speed ceiling.
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
	var minimum_exit_speed := player.parkour_profile.grapple_exit_speed
	var lift_cap := player.parkour_profile.grapple_exit_lift
	if is_instance_valid(target) and target is RiftConstruct:
		# Authored pads can ask for a minimum handoff speed, but they must not
		# erase momentum generated by the pull itself.
		minimum_exit_speed = minf(minimum_exit_speed,target.grapple_exit_speed)
		# A wall-mounted anchor may sit above the player's capsule.  Its authored
		# lift is a route requirement, so it can raise the default rather than
		# being clipped by the old low-speed handoff cap.
		lift_cap = maxf(lift_cap,target.grapple_exit_lift)
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
	# A short pull can be almost vertical at the release shell, so use the
	# greater of the measured horizontal carry and the pull speed reached by the
	# zip.  This keeps the forward impulse visible after the line disappears.
	var carried_speed := maxf(flat.length(),speed)
	var exit_speed := clampf(carried_speed,minimum_exit_speed,player.parkour_profile.grapple_max_speed)
	if is_instance_valid(target) and target.get_parent() is BossOrbitSurface and (target.get_parent() as BossOrbitSurface).route_role == &"broken_deck":
		# The low broken deck has a narrow, downward receiving face.  Keep its
		# release readable, but use the authored handoff speed so the preserved
		# burst does not skip the only usable collision strip.
		exit_speed = minf(exit_speed,minimum_exit_speed)
	if reason == &"arrived":
		progress = 1.0
	var carried_vertical := clampf(player.velocity.y,-8.0,lift_cap)
	if direction.y > .08:
		# High wall faces still need the authored lift on top of the angled
		# impulse to meet the collision face from below.
		carried_vertical = lift_cap
	elif direction.y < -.08:
		# Downward route vectors already carry their full vertical impulse; do
		# not add the pre-release fall speed a second time.
		carried_vertical = 0.0
	player.velocity = direction*exit_speed+Vector3.UP*carried_vertical
	player.arm_grapple_exit_brake(direction,minimum_exit_speed,player.parkour_profile.grapple_exit_momentum_seconds)
	if is_instance_valid(target) and target.get_parent() is BossOrbitSurface:
		# A second moving-wall anchor is a legal airborne transfer.  Preserve a
		# short switched-wall window so the next face can be caught head-on after
		# this grapple, without granting a fresh dash or floor reset.
		var orbit_wall := target.get_parent() as BossOrbitSurface
		var radial := player.global_position-orbit_wall.global_position
		radial.y = 0.0
		var wall_normal := orbit_wall.global_basis.z
		wall_normal.y = 0.0
		if wall_normal.length_squared() > .25:
			wall_normal = wall_normal.normalized() * (1.0 if radial.dot(wall_normal) >= 0.0 else -1.0)
			player._blocked_wall_normal = wall_normal
			player._blocked_wall_plane_offset = player._blocked_wall_normal.dot(orbit_wall.global_position)
		player._same_wall_reattach_ready = true
		player._wall_jump_transfer_left = maxf(player._wall_jump_transfer_left,player.wall_jump_transfer_window)
		player._grapple_wall_handoff_left = maxf(player._grapple_wall_handoff_left,.18)
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
		player.mark_traversal_action(&"grapple")
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
		# The reference is a committed zip. The line pulls the body along the
		# locked aim ray immediately; there is no pendulum or spring phase.
		var tether_direction := offset.normalized()
		speed = move_toward(speed,player.parkour_profile.grapple_pull_speed,player.parkour_profile.grapple_pull_acceleration*delta)
		var pull_step := minf(speed,maxf(0.0,offset.length()-route_exit_distance+.02)/delta)
		var pull_velocity := tether_direction*pull_step
		# The old 14 m/s vertical cap belonged to the long pull prototype.  It
		# makes a half-second zip miss every elevated anchor.  Keep the profile's
		# vertical scale for tuning, but let the committed pull use its actual
		# impulse along the locked line.
		var vertical_cap := maxf(player.parkour_profile.grapple_vertical_speed,player.parkour_profile.grapple_pull_speed*player.parkour_profile.grapple_vertical_scale)
		pull_velocity.y = clampf(pull_velocity.y*player.parkour_profile.grapple_vertical_scale,-vertical_cap,vertical_cap)
		# Keep only a short trace of the entry motion so the handoff does not
		# feel like a teleport, while preventing any swing around the anchor.
		var tangent_velocity := player.velocity-tether_direction*player.velocity.dot(tether_direction)
		tangent_velocity += _entry_tangent * minf(1.0,delta*8.0)
		tangent_velocity *= exp(-20.0*delta)
		var stick := Input.get_vector("move_left","move_right","move_forward","move_backward")
		var steer_world := player.global_basis*Vector3(stick.x,0,stick.y)
		var steer_tangent := steer_world-tether_direction*steer_world.dot(tether_direction)
		if steer_tangent.length_squared()>.001:
			tangent_velocity += steer_tangent.normalized()*player.parkour_profile.grapple_steer_acceleration*delta
		tangent_velocity=tangent_velocity.limit_length(4.0)
		player.velocity=(pull_velocity+tangent_velocity).limit_length(player.parkour_profile.grapple_max_speed)
		player.velocity.y=clampf(player.velocity.y,-player.parkour_profile.grapple_vertical_speed,player.parkour_profile.grapple_vertical_speed)
	else:
		player.velocity.y -= player.gravity*delta
	var before := player.global_position
	var commanded := player.velocity
	player.move_and_slide()
	peak_speed = maxf(peak_speed,player.velocity.length())
	harness = player.global_position+Vector3.UP*1.1
	var post_offset := anchor.global_position-harness
	rope_length = post_offset.length() # compatibility telemetry only
	progress = clampf(1.0-rope_length/maxf(_initial_distance,.01),0.0,1.0)
	tension = 0.0 if phase == &"launch" else clampf(speed/maxf(player.parkour_profile.grapple_pull_speed,1.0),0.0,1.0)
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
	var route_distance := Vector2(post_offset.x,post_offset.z).length()
	var vertical_ready := absf(post_offset.y) <= player.parkour_profile.grapple_vertical_exit_gap + .05
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
	# Boss evacuation anchors are mounted just outside a moving wall. On the
	# automatic one-press release, bias toward the wall centre so the next frame
	# can acquire the physical wall-run surface as it rotates.
	if target is RiftConstruct and target.get_parent() is BossOrbitSurface:
		var wall := target.get_parent() as BossOrbitSurface
		var inward := wall.global_position-target.global_position
		inward.y = 0.0
		if inward.length_squared() > .25:
			# The moving wall is above the release shell.  Give the handoff a
			# modest upward component so the preserved burst intersects its face
			# instead of flying under it.
			var lift_ratio := clampf((wall.global_position.y-player.global_position.y)*.12,-.45,.28)
			return (inward.normalized()+Vector3.UP*lift_ratio).normalized()
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
	var finish := anchor.global_position
	var direction := (finish-start).normalized()
	var side := direction.cross(player.camera.global_basis.z)
	if side.length_squared()<.01:side=player.camera.global_basis.x
	side=side.normalized()*.009
	var slack := lerpf(.22,.035,clampf(tension,0.0,1.0)) if phase == &"launch" else .035
	_cable.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(25):
		var t := i/24.0
		var point := start.lerp(finish,t)+Vector3.DOWN*sin(t*PI)*slack
		_cable.surface_add_vertex(to_local(point-side))
		_cable.surface_add_vertex(to_local(point+side))
	_cable.surface_end()
	_hook.global_position=finish
	if direction.length_squared()>.1:_hook.global_basis=Basis.looking_at(direction)
