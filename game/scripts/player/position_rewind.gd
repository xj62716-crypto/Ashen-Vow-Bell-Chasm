class_name PositionRewind
extends Node
## Local player history only. No world state or resource is ever snapshotted.

signal state_changed(state: Dictionary)
signal rewound(origin: Vector3, destination: Vector3, path: PackedVector3Array)
signal rejected(reason: StringName)
signal decoy_created(decoy: EchoDecoy)
signal step_created(step: EchoStep)

@export var target_age: float = 1.5
@export var minimum_age: float = 1.2
@export var maximum_age: float = 1.8
@export var cooldown_seconds: float = 3.5
@export var maximum_speed: float = 40.0
@export var protection_seconds: float = 0.1
var cooldown_left: float = 0.0
var protection_left: float = 0.0
var last_result: StringName = &"empty"
var history: Array[Dictionary] = []
var decoys: Array[EchoDecoy] = []
var steps: Array[EchoStep] = []
var _last_tick: int = 0
var _release_required: bool = false
var _suspended: bool = true
var _transition_serial: int = 0
var _last_signature: String = ""
var _last_validation_tick: int = 0
var _cached_validation: Dictionary = {"valid": false, "reason": &"empty"}
@onready var player: ParkourPlayer = get_parent() as ParkourPlayer
@onready var combat: PlayerCombat = player.get_node("Combat") as PlayerCombat


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 20


func _ready() -> void:
	TemporalBindings.ensure_actions()
	player.recovered.connect(reset_state)
	player.profile_changed.connect(func(_profile: ParkourProfile): reset_state())
	combat.temporal_reset_requested.connect(reset_state)
	combat.died.connect(func(): clear_history(&"dead"))
	_last_tick = Time.get_ticks_usec()
	reset_state()


func unlocked() -> bool:
	return player.parkour_profile.id == &"shade" and &"shade_echo" in combat.runes


func _can_run() -> bool:
	return player.control_enabled and combat.enabled and combat.health > 0 and not get_tree().paused


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := maxf(0.0, float(now - _last_tick) / 1000000.0)
	_last_tick = now
	var held := Input.is_action_pressed("rewind")
	if not _can_run() or not unlocked():
		if not _suspended:
			clear_history(&"paused" if get_tree().paused else &"unavailable")
		_suspended = true
		_release_required = held
	else:
		_suspended = false
		cooldown_left = maxf(0.0, cooldown_left - real_delta)
		protection_left = maxf(0.0, protection_left - real_delta)
		if held and not _release_required:
			_release_required = true
			try_rewind()
	if not held: _release_required = false
	_publish()


func _physics_process(_delta: float) -> void:
	if _can_run() and unlocked():
		record_sample()


func record_sample() -> void:
	var now := Time.get_ticks_usec()
	if not _can_run() or not unlocked() or not player.global_position.is_finite() or not player.velocity.is_finite():
		return
	if player.global_position.y <= player.fall_limit:
		return
	if not history.is_empty():
		var previous: Dictionary = history.back()
		var age := float(now - int(previous.time)) / 1000000.0
		if age < 1.0 / 60.0: return
		if age > 0.2 or player.global_position.distance_to(previous.position) > maximum_speed * age + 0.5:
			history.clear()
			last_result = &"discontinuity"
	history.append({"time": now, "position": player.global_position,
		"velocity": player.velocity.limit_length(maximum_speed), "crouched": player.crouched})
	while not history.is_empty() and float(now - int(history[0].time)) / 1000000.0 > maximum_age:
		history.pop_front()
	while history.size() > 120: history.pop_front()


func _anchor_index(now: int) -> int:
	var chosen := -1
	var error := INF
	for i in range(history.size()):
		var age := float(now - int(history[i].time)) / 1000000.0
		if age < minimum_age or age > maximum_age: continue
		if absf(age - target_age) < error:
			error = absf(age - target_age)
			chosen = i
	return chosen


func _query(feet: Vector3, crouch: bool) -> PhysicsShapeQueryParameters3D:
	var shape := CapsuleShape3D.new()
	shape.radius = (player.body_shape.shape as CapsuleShape3D).radius
	shape.height = 0.9 if crouch else 1.8
	# Inset by 2 mm on each end, matching contact tolerance. A capsule resting
	# on the floor is valid; real penetration or a new overhead blocker is not.
	shape.radius -= .002
	shape.height -= .004
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (0.45 if crouch else 0.9))
	query.collision_mask = player.collision_mask | 4
	query.exclude = [player.get_rid()]
	query.margin = 0.0
	return query


func _space_clear(feet: Vector3, crouch: bool) -> bool:
	return player.get_world_3d().direct_space_state.intersect_shape(_query(feet, crouch), 1).is_empty()


func _segment_clear(start: Vector3, finish: Vector3, crouch: bool) -> bool:
	var query := _query(start, crouch)
	if not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return false
	query.motion = finish - start
	var travel := player.get_world_3d().direct_space_state.cast_motion(query)
	return travel.size() == 2 and travel[0] >= 0.99999 and _space_clear(finish, crouch)


func validate_path(index: int) -> Dictionary:
	if index < 0 or index >= history.size(): return {"valid": false, "reason": &"empty"}
	var anchor: Dictionary = history[index]
	if not _space_clear(anchor.position, bool(anchor.crouched)):
		return {"valid": false, "reason": &"occupied_anchor"}
	var path := PackedVector3Array([player.global_position])
	var previous := player.global_position
	var previous_crouch := player.crouched
	for i in range(history.size() - 1, index - 1, -1):
		var sample: Dictionary = history[i]
		var next: Vector3 = sample.position
		if not next.is_finite() or next.y <= player.fall_limit:
			return {"valid": false, "reason": &"invalid_anchor"}
		# Use the taller of adjacent recorded postures across each swept segment.
		if not _segment_clear(previous, next, previous_crouch and bool(sample.crouched)):
			return {"valid": false, "reason": &"blocked_path"}
		path.append(next)
		previous = next
		previous_crouch = bool(sample.crouched)
	return {"valid": true, "reason": &"ready", "path": path}


func try_rewind() -> bool:
	if not _can_run(): return _reject(&"unavailable")
	if not unlocked(): return _reject(&"locked")
	if not TemporalBindings.conflicts(&"rewind").is_empty(): return _reject(&"binding_conflict")
	if cooldown_left > 0.0: return _reject(&"cooldown")
	var now := Time.get_ticks_usec()
	var index := _anchor_index(now)
	if index < 0: return _reject(&"recording")
	if history.is_empty() or now - int(history.back().time) > 200000:
		return _reject(&"stale_history")
	var validated := validate_path(index)
	if not validated.valid: return _reject(validated.reason)
	var anchor: Dictionary = history[index].duplicate()
	var origin := player.global_position
	var was_airborne := not player.is_on_floor()
	if origin.distance_to(anchor.position) < 0.2: return _reject(&"no_displacement")
	var focus := player.get_node_or_null("TemporalFocus") as TemporalFocus
	if focus != null: focus.interrupt(&"rewind")
	combat.cancel_attack()
	player.apply_rewind_state(anchor.position, (anchor.velocity as Vector3).limit_length(maximum_speed), anchor.crouched)
	cooldown_left = cooldown_seconds
	protection_left = clampf(protection_seconds, 0.0, 0.15)
	history.clear()
	last_result = &"returned"
	_transition_serial += 1
	if &"shade_echo_decoy" in combat.runes: _spawn_decoy(origin)
	if &"shade_echo_step" in combat.runes and was_airborne: _spawn_step(origin)
	if &"shade_echo_cut" in combat.runes:
		var echo := EchoSlash.new()
		echo.owner_combat = combat
		for sweep in combat.echo_cuts:
			if now-int(sweep.time) <= 1800000: echo.sweeps.append(sweep.duplicate())
		combat.echo_cuts.clear()
		if not echo.sweeps.is_empty(): get_tree().current_scene.add_child(echo)
		else: echo.free()
	rewound.emit(origin, player.global_position, validated.path)
	_publish(true)
	return true


func _spawn_decoy(point: Vector3) -> void:
	for old in decoys:
		if is_instance_valid(old): old.dissolve(&"replaced")
	decoys.clear()
	var decoy := EchoDecoy.new()
	decoy.owner_player = player
	decoy.position = point
	# A top-level root prevents a player move from dragging its decoy along.
	get_tree().root.add_child(decoy)
	decoys.append(decoy)
	decoy_created.emit(decoy)


func _spawn_step(feet: Vector3) -> void:
	for old in steps:
		if is_instance_valid(old):
			old.collision_layer = 0
			old.queue_free()
	steps.clear()
	var point := feet - Vector3.UP * (EchoStep.SIZE.y * 0.5 + 0.015)
	var shape := BoxShape3D.new()
	shape.size = EchoStep.SIZE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point
	query.collision_mask = 5
	query.exclude = [player.get_rid()]
	if not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return
	var step := EchoStep.new()
	step.owner_player = player
	step.position = point
	get_tree().root.add_child(step)
	steps.append(step)
	step_created.emit(step)


func _reject(reason: StringName) -> bool:
	last_result = reason
	_transition_serial += 1
	rejected.emit(reason)
	_publish(true)
	return false


func is_protected() -> bool:
	return protection_left > 0.0 and _can_run() and unlocked()


func clear_history(reason: StringName = &"cleared") -> void:
	history.clear()
	protection_left = 0.0
	_release_required = Input.is_action_pressed("rewind")
	for decoy in decoys:
		if is_instance_valid(decoy): decoy.dissolve(reason)
	decoys.clear()
	for step in steps:
		if is_instance_valid(step):
			step.collision_layer = 0
			step.queue_free()
	steps.clear()
	_last_validation_tick = 0
	_cached_validation = {"valid": false, "reason": reason}
	last_result = reason
	_transition_serial += 1
	_publish(true)


func reset_state() -> void:
	cooldown_left = 0.0
	clear_history(&"reset")
	_last_tick = Time.get_ticks_usec()


func status() -> Dictionary:
	var now := Time.get_ticks_usec()
	var index := _anchor_index(now)
	var enabled := unlocked() and _can_run()
	var has_anchor := index >= 0
	if has_anchor and enabled and now - _last_validation_tick > 100000:
		_cached_validation = validate_path(index)
		_last_validation_tick = now
	return {"unlocked": unlocked(), "enabled": enabled, "has_anchor": has_anchor,
		"ready": enabled and has_anchor and _cached_validation.valid and cooldown_left <= 0.0 and TemporalBindings.conflicts(&"rewind").is_empty(),
		"anchor_position": history[index].position if has_anchor else Vector3.ZERO,
		"anchor_age": float(Time.get_ticks_usec() - int(history[index].time)) / 1000000.0 if has_anchor else 0.0,
		"path_valid": has_anchor and _cached_validation.valid, "path_reason": _cached_validation.reason,
		"cooldown": cooldown_left, "protection": protection_left,
		"history_samples": history.size(), "last_result": last_result, "transition_serial": _transition_serial,
		"action": &"rewind", "binding": TemporalBindings.label(&"rewind")}


func _publish(force: bool = false) -> void:
	if not is_node_ready(): return
	var value := status()
	var signature := "%s:%s:%s:%s:%s" % [value.unlocked, value.ready, value.has_anchor, last_result, ceili(cooldown_left * 10)]
	if force or signature != _last_signature:
		_last_signature = signature
		state_changed.emit(value)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT] and is_node_ready():
		clear_history(&"window_focus_lost")


func _exit_tree() -> void:
	for decoy in decoys:
		if is_instance_valid(decoy): decoy.dissolve(&"scene_exit")
	decoys.clear()
	for step in steps:
		if is_instance_valid(step): step.queue_free()
	steps.clear()
	history.clear()
