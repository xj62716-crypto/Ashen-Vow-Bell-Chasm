class_name ParkourPlayer
extends CharacterBody3D
## Inspector 中的速度按米/秒计算。玩家根节点位于脚底。

signal jumped
signal dashed
signal landed(impact_speed: float)
signal fell_out
signal wall_run_started(side: int)
signal wall_run_ended
signal wall_jumped(normal: Vector3)
signal wall_bonus_triggered(bonus: StringName)
signal profile_changed(profile: ParkourProfile)
signal recovered
signal slide_started
signal slide_jumped

@export_group("Ground movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 9.0
@export_range(1.0, 150.0, 1.0) var ground_acceleration: float = 65.0
@export_range(1.0, 150.0, 1.0) var ground_braking: float = 80.0
@export_group("Jump and air control")
@export_range(0.5, 5.0, 0.1) var jump_height: float = 2.1
@export_range(5.0, 60.0, 0.5) var gravity: float = 26.0
@export_range(1.0, 80.0, 1.0) var air_acceleration: float = 24.0
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.12
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.14
@export var maximum_fall_speed: float = 40.0
@export_group("Air dash")
@export_range(10.0, 40.0, 0.5) var dash_speed: float = 24.0
@export_range(0.05, 0.4, 0.01) var dash_duration: float = 0.18
@export_range(0.0, 8.0, 0.5) var dash_exit_bonus: float = 3.0
@export_group("Wall movement")
@export var parkour_profile: ParkourProfile = preload("res://data/classes/shade.tres")
@export_range(0.4, 1.2, 0.05) var wall_probe_reach: float = 0.8
@export var wall_minimum_speed: float = 4.0
@export var wall_jump_grace: float = 0.12
@export_range(0.12, 0.6, 0.01) var wall_jump_transfer_window: float = 0.5
@export_range(2, 4, 1) var wall_chain_limit: int = 2
@export_range(15.0, 100.0, 1.0) var wall_look_limit_degrees: float = 75.0
@export_group("Camera and recovery")
@export_range(0.03, 0.3, 0.01) var mouse_sensitivity: float = 0.1
@export_range(65.0, 100.0, 1.0) var field_of_view: float = 80.0
@export var camera_feedback: bool = true
@export var fall_limit: float = -14.0
@export_group("Grapple camera feedback")
@export_range(0.0, 0.25, 0.01) var grapple_camera_lurch: float = 0.11
@export_range(0.0, 15.0, 0.5) var grapple_camera_fov: float = 7.0
@export_range(0.0, 6.0, 0.5) var grapple_camera_roll_degrees: float = 2.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var control_enabled: bool = false
var dash_available: bool = true
var jump_count: int = 0
var dash_count: int = 0
var wall_run_count: int = 0
var wall_jump_count: int = 0
var dash_refund_count: int = 0
var wall_side: int = 0
var _wall_active: bool = false
var _wall_normal := Vector3.ZERO
var _wall_tangent := Vector3.ZERO
var _blocked_wall_normal := Vector3.ZERO
var _wall_plane_offset: float = 0.0
var _blocked_wall_plane_offset: float = 0.0
var _same_wall_reattach_ready: bool = false
var _dash_origin := Vector3.ZERO
var _dash_travel: float = 0.0
var _dash_blocked: bool = false
var _dash_wall_normal := Vector3.ZERO
var _dash_wall_offset: float = 0.0
var wall_chain_count: int = 0
var _wall_time_used: float = 0.0
var _wall_look_yaw: float = 0.0
var _wall_coyote_left: float = 0.0
var _wall_jump_transfer_left: float = 0.0
var _wall_bonus_used: bool = false
var _momentum_left: float = 0.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _dash_left: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _camera_drop: float = 0.0
var _wall_kick_feedback: float = 0.0
var _wall_kick_side: float = 0.0
var _ignore_floor_once: bool = false
var _jump_held: bool = false
var sliding: bool = false
var crouched: bool = false
var slide_count: int = 0
var slide_jump_count: int = 0
var slide_boost: float = 0.0
var slide_jump_multiplier: float = 1.0
var float_capacity: float = 0.0
var float_left: float = 0.0
var floating: bool = false
var empowered_dash: bool = false
var airtime_serial: int = 0
var _slide_left: float = 0.0
var _slide_cooldown: float = 0.0
var _slide_jump_left: float = 0.0
var _slide_direction := Vector3.FORWARD
var _impact_left: float = 0.0
var _impact_strength: float = 0.0
var _stride_phase: float = 0.0
var _stride_weight: float = 0.0
## A short-lived traversal receipt used by authored encounter gates.  It is not
## a global combo counter: a route action only creates a nearby attack window.
## This prevents the main guardian from being cleared by walking up and
## holding the attack button while preserving a forgiving recovery route.
var traversal_receipt_left: float = 0.0
var last_traversal_action: StringName = &""
var _camera_recoil: float = 0.0
var _camera_recoil_velocity: float = 0.0
var grapple: ParkourGrapple
var attack_body_turn: float = 0.0
var blade_camera_angles:Vector3=Vector3.ZERO
var blade_camera_translation:Vector3=Vector3.ZERO
var blade_camera_fov:float=0.
var blade_arrival_offset:Vector3=Vector3.ZERO
var blade_arrival_left:float=0.
var blade_arrival_duration:float=.18
var _movement_camera_roll:float=0.
var blade_approach_active:bool=false
var _grapple_camera_blend: float = 0.0
var _grapple_camera_punch: float = 0.0
var _grapple_camera_direction := Vector3.FORWARD
@onready var body_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	grapple = ParkourGrapple.new()
	grapple.name = "Grapple"
	add_child(grapple)
	grapple.state_changed.connect(_grapple_camera_state)
	var avatar := PlayerAvatar.new()
	avatar.name = "CharacterBodyVisual"
	add_child(avatar)
	body_shape.shape = body_shape.shape.duplicate()
	if not InputMap.has_action("slide"):
		InputMap.add_action("slide")
		for key: int in [KEY_CTRL, KEY_C]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event("slide", event)
	camera.fov = field_of_view
	floor_snap_length = 0.25
	floor_stop_on_slope = true
	floor_constant_speed = true


func _unhandled_input(event: InputEvent) -> void:
	if not control_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var yaw_delta := deg_to_rad(-motion.screen_relative.x * mouse_sensitivity)
		if _wall_active:
			_wall_look_yaw = clampf(_wall_look_yaw+yaw_delta,deg_to_rad(-wall_look_limit_degrees),deg_to_rad(wall_look_limit_degrees))
			head.rotation.y = _wall_look_yaw
		else:
			rotate_y(yaw_delta)
		head.rotation.x = clampf(head.rotation.x - deg_to_rad(motion.screen_relative.y * mouse_sensitivity), deg_to_rad(-80.0), deg_to_rad(80.0))

func mark_traversal_action(kind: StringName, seconds: float = 2.2) -> void:
	## Gives a nearby authored guardian a fair, readable attack window. The
	## receipt expires quickly so it cannot be banked before a later room.
	last_traversal_action = kind
	traversal_receipt_left = maxf(traversal_receipt_left, seconds)

func has_recent_traversal_action() -> bool:
	return traversal_receipt_left > 0.0


func _physics_process(delta: float) -> void:
	traversal_receipt_left = maxf(0.0, traversal_receipt_left - delta)
	if not control_enabled:
		if grapple.active:grapple.cancel()
		return
	_wall_jump_transfer_left = maxf(0.0, _wall_jump_transfer_left - delta)
	if blade_approach_active:return # ProfessionArts owns the brief swept approach.
	if grapple.active:
		grapple.advance(delta)
		if is_on_floor() and not _ignore_floor_once:
			dash_available = true
			float_left = float_capacity
			_reset_wall_airtime()
		_ignore_floor_once = false
		return
	var grounded: bool = is_on_floor() and not _ignore_floor_once
	_slide_cooldown = maxf(0.0, _slide_cooldown - delta)
	_slide_jump_left = maxf(0.0, _slide_jump_left - delta)
	if grounded and Input.is_action_pressed("slide") and not crouched and _slide_cooldown <= 0.0:
		_start_slide()
	if crouched:
		_slide_left = maxf(0.0, _slide_left - delta)
		if not Input.is_action_pressed("slide") or _slide_left <= 0.0 or not grounded:
			_end_slide()
	_ignore_floor_once = false
	_wall_coyote_left = maxf(0.0, _wall_coyote_left - delta)
	_momentum_left = maxf(0.0, _momentum_left - delta)
	_coyote_left = coyote_time if grounded else maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if grounded:
		dash_available = true
		float_left = float_capacity
		_reset_wall_airtime()
	var jump_pressed: bool = Input.is_action_pressed("jump")
	if jump_pressed and not _jump_held:
		_jump_buffer_left = jump_buffer_time
	_jump_held = jump_pressed
	var did_jump: bool = false
	if _jump_buffer_left > 0.0 and not grounded and (_wall_active or _wall_coyote_left > 0.0) and not is_dashing():
		_perform_wall_jump()
		did_jump = true
	elif _jump_buffer_left > 0.0 and _coyote_left > 0.0 and (not crouched or _can_stand()):
		var jump_multiplier: float = 1.0
		if sliding or _slide_jump_left > 0.0:
			jump_multiplier = slide_jump_multiplier
			var carry_speed: float = maxf(horizontal_speed(), 13.0 + slide_boost)
			velocity.x = _slide_direction.x * carry_speed
			velocity.z = _slide_direction.z * carry_speed
			_momentum_left = 0.85
			slide_jump_count += 1
			mark_traversal_action(&"slide_jump")
			slide_jumped.emit()
			_end_slide()
			_slide_jump_left = 0.0
		did_jump = true
		velocity.y = sqrt(2.0 * gravity * jump_height) * jump_multiplier
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		grounded = false
		jump_count += 1
		jumped.emit()
	var stick: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_direction: Vector3 = global_basis * Vector3(stick.x, 0.0, stick.y)
	wish_direction.y = 0.0
	if Input.is_action_just_pressed("dash") and not grounded and dash_available and not is_dashing():
		_start_dash(wish_direction)
	if not grounded and not is_dashing() and not did_jump:
		_update_wall_contact(wish_direction, stick, delta)
	elif _wall_active:
		_stop_wall(false)
	floating = false
	if is_dashing():
		_dash_left = maxf(0.0, _dash_left - delta)
		velocity = _dash_direction * dash_speed
	elif _wall_active:
		var along_speed: float = maxf(wall_minimum_speed, velocity.dot(_wall_tangent))
		along_speed = move_toward(along_speed, parkour_profile.wall_speed, parkour_profile.wall_acceleration * delta)
		var vertical: float = maxf(-1.3, velocity.y - gravity * parkour_profile.wall_gravity_scale * delta)
		velocity = _wall_tangent * along_speed - _wall_normal * 1.8
		velocity.y = vertical
	else:
		if not grounded:
			velocity.y = maxf(velocity.y - gravity * delta, -maximum_fall_speed)
			if float_left > 0.0 and velocity.y < 0.0 and Input.is_action_pressed("jump"):
				floating = true
				float_left = maxf(0.0, float_left-delta)
				velocity.y = maxf(velocity.y, -.65)
		elif not did_jump:
			velocity.y = 0.0
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if grounded and sliding:
			flat = _slide_direction * move_toward(maxf(flat.length(), move_speed), move_speed, delta * 3.0)
		elif grounded:
			var acceleration: float = ground_acceleration if stick.length_squared() > 0.0 else ground_braking
			flat = flat.move_toward(wish_direction * (3.0 if crouched else move_speed), acceleration * delta)
		elif stick.length_squared() > 0.0:
			if _momentum_left > 0.0:
				flat = flat.move_toward(wish_direction.normalized() * maxf(move_speed, flat.length()), air_acceleration * 0.18 * delta)
			else:
				flat = flat.move_toward(wish_direction * move_speed, air_acceleration * delta)
		velocity.x = flat.x
		velocity.z = flat.z
	var impact_speed: float = -velocity.y
	var was_dashing: bool = is_dashing() or _dash_direction != Vector3.ZERO
	var before_move := global_position
	move_and_slide()
	if was_dashing:
		_dash_travel += global_position.distance_to(before_move)
	if is_on_floor():
		floating = false
		float_left = float_capacity
		if not grounded:
			airtime_serial += 1
		dash_available = true
		_reset_wall_airtime()
		if not grounded and not did_jump and impact_speed > 2.0:
			landed.emit(impact_speed)
			if camera_feedback:
				_camera_drop = minf(impact_speed * 0.004, 0.07)
	if was_dashing:
		for index in range(get_slide_collision_count()):
			if get_slide_collision(index).get_normal().dot(_dash_direction) < -0.65:
				_dash_blocked = true
			if is_on_floor() or is_on_ceiling():
				_dash_blocked = true
		if _dash_blocked:_dash_left = 0.0
	if was_dashing and not is_dashing():
		_end_dash()
	if global_position.y < fall_limit:
		fell_out.emit()


func _process(delta: float) -> void:
	var visual_delta: float = minf(delta,.033)
	var grapple_active: bool = is_instance_valid(grapple) and grapple.active
	_grapple_camera_blend = lerpf(_grapple_camera_blend,1.0 if grapple_active else 0.0,1.0-exp(-24.0*visual_delta))
	_grapple_camera_punch = move_toward(_grapple_camera_punch,0.0,visual_delta*8.5)
	if grapple_active and is_instance_valid(grapple.anchor):
		var hook_offset := grapple.anchor.global_position-camera.global_position
		if hook_offset.length_squared()>.04:
			_grapple_camera_direction = hook_offset.normalized()
	_stride_phase = fmod(_stride_phase+horizontal_speed()*delta*TAU/2.75,TAU)
	_stride_weight = lerpf(_stride_weight,minf(1.0,horizontal_speed()/move_speed) if is_on_floor() and not crouched and control_enabled else 0.0,1-exp(-12*delta))
	_camera_recoil_velocity += (-150*_camera_recoil-21*_camera_recoil_velocity)*visual_delta
	_camera_recoil += _camera_recoil_velocity*visual_delta
	_camera_drop = move_toward(_camera_drop, 0.0, delta * 0.5)
	_wall_kick_feedback = move_toward(_wall_kick_feedback, 0.0, delta * 3.2)
	head.position.y = lerpf(head.position.y, 0.72 if crouched else 1.6, 1.0-exp(-22.0*delta))
	_impact_left = maxf(0.0, _impact_left-delta)
	camera.position.y = (-_camera_drop + sin(_impact_left*95.0)*_impact_left*_impact_strength*.15) if camera_feedback else 0.0
	if camera_feedback:
		camera.position.y += sin(_stride_phase*2)*.008*_stride_weight
		camera.position.x = cos(_stride_phase)*.005*_stride_weight
		camera.position.z = _camera_recoil
	else:
		camera.position.x = 0
		camera.position.z = 0
	var target_fov: float = field_of_view + (3.0 if camera_feedback and is_dashing() else 0.0)
	if camera_feedback and _grapple_camera_blend>.001:
		var hook_local := global_basis.inverse()*_grapple_camera_direction
		camera.position.z -= grapple_camera_lurch*_grapple_camera_blend
		camera.position.x += clampf(hook_local.x,-1.0,1.0)*grapple_camera_lurch*.16*_grapple_camera_blend
		target_fov += grapple_camera_fov*_grapple_camera_blend + _grapple_camera_punch*2.0
	if blade_arrival_left>0:
		blade_arrival_left=maxf(0,blade_arrival_left-delta)
		var arrival_weight:float=smoothstep(0.,1.,blade_arrival_left/maxf(.001,blade_arrival_duration))
		camera.position+=head.global_basis.inverse()*blade_arrival_offset*arrival_weight
	if camera_feedback:
		camera.position+=blade_camera_translation
		target_fov+=blade_camera_fov
		target_fov += smoothstep(move_speed,24.0,horizontal_speed())*2.0
	if camera_feedback and _wall_active:
		target_fov += 2.0
	var wall_roll: float = deg_to_rad(-7.0 * wall_side) if camera_feedback and _wall_active else 0.0
	var kick_roll: float = deg_to_rad(5.0 * _wall_kick_side) * _wall_kick_feedback if camera_feedback else 0.0
	var target_roll: float = wall_roll + kick_roll
	if camera_feedback:
		if _grapple_camera_blend>.001:
			var hook_local := global_basis.inverse()*_grapple_camera_direction
			target_roll += deg_to_rad(clampf(hook_local.x,-1.0,1.0)*grapple_camera_roll_degrees)*_grapple_camera_blend
		target_roll += sin(_impact_left*80.0)*_impact_left*_impact_strength*.18
		target_roll += attack_body_turn*.19
		if sliding:
			target_roll += deg_to_rad(-3.0)
			target_fov += 4.0
	_movement_camera_roll=lerp_angle(_movement_camera_roll,target_roll,1.0-exp(-10.0*delta))
	camera.rotation.z = _movement_camera_roll+(blade_camera_angles.z if camera_feedback else 0.)
	camera.rotation.y = attack_body_turn*.10+blade_camera_angles.y if camera_feedback else 0.0
	var grapple_pitch: float = 0.0
	if camera_feedback and _grapple_camera_blend>.001:
		var hook_local := global_basis.inverse()*_grapple_camera_direction
		grapple_pitch = -deg_to_rad(clampf(hook_local.y,-.8,.8)*1.8)*_grapple_camera_blend
	camera.rotation.x = (blade_camera_angles.x if camera_feedback else 0.0)+grapple_pitch
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-12.0 * delta))


func _grapple_camera_state(phase: StringName, _reason: StringName) -> void:
	if phase == &"launch":
		_grapple_camera_punch = 1.0
		if is_instance_valid(grapple.anchor):
			var hook_offset := grapple.anchor.global_position-camera.global_position
			if hook_offset.length_squared()>.04:_grapple_camera_direction=hook_offset.normalized()


func _start_dash(direction: Vector3) -> void:
	_dash_origin = global_position
	_dash_travel = 0.0
	_dash_blocked = false
	var left_wall_with_free_look := _wall_active
	_stop_wall(false)
	if left_wall_with_free_look:
		var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		direction = global_basis * Vector3(stick.x,0.0,stick.y)
	_same_wall_reattach_ready = false
	_dash_wall_normal = _blocked_wall_normal
	_dash_wall_offset = _blocked_wall_plane_offset
	_wall_coyote_left = 0.0
	_dash_direction = direction.normalized() if direction.length_squared() > 0.01 else -global_basis.z
	_dash_direction.y = 0.0
	_dash_direction = _dash_direction.normalized()
	_dash_left = dash_duration
	if empowered_dash:
		_dash_left *= 1.6
		empowered_dash = false
	dash_available = false
	_coyote_left = 0.0
	dash_count += 1
	mark_traversal_action(&"air_dash")
	dashed.emit()


func _end_dash() -> void:
	# Only a completed, useful airborne dash grants one return to the last plane.
	if not _dash_blocked and not is_on_floor() and _dash_travel >= 0.8 and _dash_wall_normal.length_squared() > 0.5:
		_same_wall_reattach_ready = true
		_blocked_wall_normal = _dash_wall_normal
		_blocked_wall_plane_offset = _dash_wall_offset
	_dash_direction = Vector3.ZERO
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.limit_length(move_speed + dash_exit_bonus)
	velocity.x = flat.x
	velocity.z = flat.z
	_momentum_left = maxf(_momentum_left, 0.25)


func is_dashing() -> bool:
	return _dash_left > 0.0


func is_wall_running() -> bool:
	return _wall_active


func wall_time_remaining() -> float:
	return maxf(0.0, parkour_profile.wall_duration - _wall_time_used)


func wall_segments_remaining() -> int:
	return maxi(0, wall_chain_limit - wall_chain_count)


func apply_profile(profile: ParkourProfile) -> void:
	if profile == null:
		return
	# A class swap is a hard ownership boundary. Cancel every transient
	# traversal state before the new profile exposes its weapon and VFX.
	grapple.cancel()
	_stop_wall(false)
	velocity = Vector3.ZERO
	sliding = false
	crouched = false
	_dash_left = 0.0
	_dash_direction = Vector3.ZERO
	_dash_travel = 0.0
	airtime_serial += 1
	_reset_wall_airtime()
	parkour_profile = profile
	move_speed = 10.5 if profile.id == &"shade" else 9.0
	dash_speed = 26.0 if profile.id == &"shade" else 24.0
	dash_exit_bonus = 3.0
	slide_boost = 0.0
	slide_jump_multiplier = 1.0
	float_capacity = 0.0
	float_left = 0.0
	empowered_dash = false
	wall_chain_limit = 2
	profile_changed.emit(profile)


func _side_wall(side: int, reattach_hint: bool = false) -> Dictionary:
	var direction: Vector3 = -_wall_normal if _wall_active else (-_blocked_wall_normal if reattach_hint else global_basis.x * float(side))
	var result: Dictionary = {}
	# Two torso probes reject low ledges and the top of a platform.
	for height: float in [0.65, 1.25]:
		var origin: Vector3 = global_position + Vector3.UP * height
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * wall_probe_reach, 1, [get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var normal: Vector3 = hit["normal"]
		if absf(normal.y) > 0.15 or normal.dot(direction) > -0.75:
			return {}
		if not result.is_empty() and (normal.dot(result["normal"]) < 0.95 or absf(normal.dot(hit.position-result.position)) > 0.08):
			return {}
		result = hit
	return result


func _update_wall_contact(wish: Vector3, stick: Vector2, delta: float) -> void:
	if not _wall_active:
		var foot := global_position+Vector3.UP*.08
		var ground_query := PhysicsRayQueryParameters3D.create(foot,foot-Vector3.UP*.4,1,[get_rid()])
		var nearby_ground := get_world_3d().direct_space_state.intersect_ray(ground_query)
		if not nearby_ground.is_empty() and nearby_ground.normal.y>.7:
			return
	if stick.y > -0.2 or horizontal_speed() < wall_minimum_speed or parkour_profile.wall_duration <= 0.0:
		_stop_wall()
		return
	if _wall_active and wall_time_remaining() <= 0.0:
		_stop_wall()
		return
	var probes: Array = [wall_side] if _wall_active else ([0,-1,1] if _same_wall_reattach_ready else [-1,1])
	for probe: int in probes:
		var hinted := probe == 0
		var side: int = (-1 if _blocked_wall_normal.dot(global_basis.x)>0.0 else 1) if hinted else probe
		if side == 0:
			continue
		var hit: Dictionary = _side_wall(side,hinted)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		var plane_offset: float = normal.dot(hit["position"])
		var has_previous_wall: bool = _blocked_wall_normal.length_squared() > 0.5
		var same_wall_surface: bool = has_previous_wall and normal.dot(_blocked_wall_normal) > 0.95 and absf(plane_offset - _blocked_wall_plane_offset) < 0.25
		var switched_wall: bool = has_previous_wall and not same_wall_surface
		# The segment budget limits reattaching to the same wall. Crossing to a
		# different wall while airborne starts a fresh wall chain, so a route can
		# intentionally read as wall -> dash -> wall without touching the floor.
		if not _wall_active and wall_segments_remaining() <= 0 and not switched_wall:
			continue
		# Normal wall re-entry is intentionally glancing, which prevents a floor
		# jump straight into a wall from stealing control. A kick toward another
		# surface is different: preserve the short transfer window so a second
		# wall can be caught in mid-air after two segments on the first wall.
		var approach: Vector3 = Vector3(velocity.x,0,velocity.z) if hinted else wish
		var allow_wall_jump_transfer: bool = _wall_jump_transfer_left > 0.0 and switched_wall
		if not _wall_active and not allow_wall_jump_transfer:
			var approach_direction := approach.normalized()
			if approach_direction.length_squared() > 0.0 and (approach_direction.dot(normal) > 0.35 or absf(approach_direction.dot(normal)) > 0.78):
				continue
		# A parallel wall elsewhere is a new surface; coplanar modules remain one wall.
		if not _wall_active and normal.dot(_blocked_wall_normal) > 0.95 and absf(plane_offset - _blocked_wall_plane_offset) < 0.25 and not _same_wall_reattach_ready:
			continue
		if _wall_active and normal.dot(_wall_normal) < 0.95:
			continue
		var tangent: Vector3 = _wall_tangent if _wall_active else Vector3.UP.cross(normal).normalized()
		if not _wall_active and tangent.dot(approach) < 0.0:
			tangent = -tangent
		var front_origin: Vector3 = global_position + Vector3.UP
		var front_query := PhysicsRayQueryParameters3D.create(front_origin, front_origin + tangent * 0.7, 1, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(front_query).is_empty():
			continue
		_wall_normal = normal
		_wall_plane_offset = plane_offset
		_wall_tangent = tangent
		wall_side = side
		if not _wall_active:
			if switched_wall and not is_on_floor():
				wall_chain_count = 0
				_wall_time_used = 0.0
			_wall_active = true
			_wall_look_yaw = 0.0
			head.rotation.y = 0.0
			_same_wall_reattach_ready = false
			wall_chain_count += 1
			_wall_time_used = 0.0
			_coyote_left = 0.0
			_wall_coyote_left = 0.0
			velocity.y = clampf(velocity.y, -0.8, 5.0)
			wall_run_count += 1
			mark_traversal_action(&"wall_run")
			wall_run_started.emit(side)
		_wall_time_used = minf(parkour_profile.wall_duration, _wall_time_used + delta)
		return
	_stop_wall()


func _stop_wall(allow_grace: bool = true) -> void:
	if not _wall_active:
		return
	_wall_active = false
	# Wall travel remains aligned to the latched surface while the head can look
	# freely. Fold the local head yaw into the body on exit so the view never
	# snaps and a following dash uses the direction the player is watching.
	if not is_zero_approx(_wall_look_yaw):
		rotate_y(_wall_look_yaw)
		head.rotation.y = 0.0
		_wall_look_yaw = 0.0
	_same_wall_reattach_ready = false
	_blocked_wall_normal = _wall_normal
	_blocked_wall_plane_offset = _wall_plane_offset
	_wall_coyote_left = wall_jump_grace if allow_grace else 0.0
	_momentum_left = 0.4
	wall_side = 0
	wall_run_ended.emit()


func _perform_wall_jump() -> void:
	var normal: Vector3 = _wall_normal
	_wall_kick_side = -1.0 if normal.dot(global_basis.x) > 0.0 else 1.0
	var tangent: Vector3 = _wall_tangent
	var carry: float = maxf(move_speed, velocity.dot(tangent))
	_stop_wall(false)
	_wall_coyote_left = 0.0
	_momentum_left = 0.45
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	velocity = tangent * carry + normal * parkour_profile.wall_jump_push
	velocity.y = sqrt(2.0 * gravity * parkour_profile.wall_jump_height)
	# The next wall is allowed to be approached head-on. This is deliberately
	# short-lived, so ordinary jumps still require a glancing wall entry.
	_wall_jump_transfer_left = wall_jump_transfer_window
	jump_count += 1
	wall_jump_count += 1
	mark_traversal_action(&"wall_jump")
	_wall_kick_feedback = 1.0
	if parkour_profile.restore_dash_on_wall_jump and not _wall_bonus_used and not dash_available:
		dash_available = true
		_wall_bonus_used = true
		dash_refund_count += 1
		wall_bonus_triggered.emit(&"dash_restored")
	jumped.emit()
	wall_jumped.emit(normal)


func _reset_wall_airtime() -> void:
	_stop_wall(false)
	_wall_time_used = 0.0
	wall_chain_count = 0
	_wall_plane_offset = 0.0
	_blocked_wall_plane_offset = 0.0
	_blocked_wall_normal = Vector3.ZERO
	_same_wall_reattach_ready = false
	_dash_wall_normal = Vector3.ZERO
	_wall_bonus_used = false
	_wall_coyote_left = 0.0
	_wall_jump_transfer_left = 0.0
	_momentum_left = 0.0


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func respawn_at(spawn: Transform3D) -> void:
	grapple.cancel()
	global_transform = spawn
	velocity = Vector3.ZERO
	_wall_look_yaw = 0.0
	head.rotation = Vector3.ZERO
	dash_available = true
	_dash_left = 0.0
	_dash_direction = Vector3.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_camera_drop = 0.0
	_camera_recoil = 0.0
	_camera_recoil_velocity = 0.0
	_stride_weight = 0.0
	_stride_phase = 0.0
	_jump_held = Input.is_action_pressed("jump")
	camera.rotation=Vector3.ZERO
	_movement_camera_roll=0.;attack_body_turn=0.;blade_camera_angles=Vector3.ZERO
	blade_camera_translation=Vector3.ZERO;blade_camera_fov=0.
	blade_arrival_left=0.;blade_arrival_offset=Vector3.ZERO
	blade_approach_active=false
	_wall_kick_feedback = 0.0
	sliding = false
	crouched = false
	_slide_left = 0.0
	_slide_cooldown = 0.0
	_slide_jump_left = 0.0
	floating = false
	float_left = float_capacity
	empowered_dash = false
	airtime_serial += 1
	_set_crouch(false)
	_reset_wall_airtime()
	_ignore_floor_once = true
	reset_physics_interpolation()
	recovered.emit()


func impact(strength: float = 1.0) -> void:
	_impact_left = 0.16
	_impact_strength = strength
	_camera_recoil_velocity += .65*strength


func _set_crouch(value: bool) -> void:
	crouched = value
	(body_shape.shape as CapsuleShape3D).height = 0.9 if value else 1.8
	body_shape.position.y = 0.45 if value else 0.9


func _can_stand() -> bool:
	var bounds := CapsuleShape3D.new()
	bounds.radius = (body_shape.shape as CapsuleShape3D).radius
	bounds.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = bounds
	query.transform = Transform3D(global_basis, global_position + Vector3.UP*0.905)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func apply_rewind_state(destination: Vector3, restored_velocity: Vector3, restored_crouch: bool) -> void:
	# Rewind changes kinematics, never the remaining airborne resource budget.
	grapple.cancel()
	_stop_wall(false)
	_same_wall_reattach_ready = false
	_dash_wall_normal = Vector3.ZERO
	_dash_left = 0.0
	_dash_direction = Vector3.ZERO
	_dash_travel = 0.0
	_wall_coyote_left = 0.0
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_jump_held = Input.is_action_pressed("jump")
	sliding = false
	_slide_left = 0.0
	_slide_jump_left = 0.0
	floating = false
	global_position = destination
	_set_crouch(restored_crouch or not _can_stand())
	velocity = restored_velocity
	_momentum_left = 0.4
	_ignore_floor_once = true
	reset_physics_interpolation()


func _start_slide() -> void:
	_set_crouch(true)
	_slide_jump_left = 0.0
	sliding = horizontal_speed() >= 4.0
	_slide_left = 0.95
	if sliding:
		_slide_direction = Vector3(velocity.x,0,velocity.z).normalized()
		velocity = _slide_direction * maxf(horizontal_speed(), 14.0 + slide_boost)
		slide_count += 1
		slide_started.emit()


func _end_slide() -> void:
	if sliding:
		_slide_jump_left = coyote_time
		_momentum_left = maxf(_momentum_left, 0.4)
	sliding = false
	if _can_stand():
		_set_crouch(false)
		_slide_cooldown = 0.3
