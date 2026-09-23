class_name TemporalFocus
extends Node

signal started
signal ended
signal state_changed(previous: StringName, current: StringName, reason: StringName)

@export_range(0.1, 1.5, 0.05) var capacity: float = 0.6
@export_range(0.1, 0.9, 0.05) var world_speed: float = 0.35
var active: bool = false
var reserve: float = 0.6
var _release_required: bool = false
var _activation_left: float = 0.0
var _last_tick: int = 0
var _airtime: int = -1
var _parry_refunds: int = 0
var _kill_refunds: int = 0
var _wall_refunds: int = 0
## `wall_chain_count` is intentionally reset when a route transfers to a new
## surface.  Focus refunds need the airborne traversal serial instead of that
## local chain number, otherwise the first segment on the second wall is
## mistaken for a duplicate of the first segment.
var _last_wall_run_count: int = 0
var _observed_wall_run_count: int = 0
var _defeated_ids: Dictionary = {}
var _last_parry_tick: int = -1000000
var phase: StringName = &"idle"
var exit_reason: StringName = &""
var _phase_age: float = 0.0
var _transition_serial: int = 0
var _air_hit_refunds: int = 0
var _air_hit_ids: Dictionary = {}
@onready var player: ParkourPlayer = get_parent() as ParkourPlayer
@onready var combat: PlayerCombat = player.get_node("Combat") as PlayerCombat


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	TemporalBindings.ensure_actions()
	player.recovered.connect(reset_state)
	player.profile_changed.connect(_profile_changed)
	player.wall_run_started.connect(_wall_started)
	combat.parried.connect(_parried)
	combat.hit_confirmed.connect(_hit_confirmed)
	combat.died.connect(_interrupted)
	combat.temporal_reset_requested.connect(reset_state)
	reset_state()


func _process(_delta: float) -> void:
	var tick := Time.get_ticks_usec()
	var real_delta := maxf(0.0, (tick - _last_tick) / 1000000.0)
	_last_tick = tick
	_phase_age += real_delta
	if phase == &"entering" and _phase_age >= 0.06:
		_set_phase(&"active")
	elif phase == &"exiting" and _phase_age >= 0.10:
		_set_phase(&"idle", exit_reason)
	# The contact signal is emitted from the player's physics callback. Poll the
	# monotonic counter too so the refund is visible in the same frame as a
	# route handoff to systems sampling focus after physics.
	_sync_airtime()
	if _can_refund() and player.wall_run_count > _observed_wall_run_count:
		_observed_wall_run_count = player.wall_run_count
		if player.wall_run_count > _last_wall_run_count and _wall_refunds < 2:
			_last_wall_run_count = player.wall_run_count
			_wall_refunds += 1
			reserve = minf(capacity, reserve + 0.12)
	var held := Input.is_action_pressed("focus")
	if not held:
		_release_required = false
		_stop(&"released")
		return
	if not _can_use():
		interrupt(_blocked_reason())
		return
	_sync_airtime()
	if active:
		reserve = maxf(0.0, reserve - real_delta)
		_activation_left = maxf(0.0, _activation_left - real_delta)
		if reserve <= 0.0 or _activation_left <= 0.0:
			_release_required = true
			_stop(&"depleted" if reserve <= 0.0 else &"duration_limit")
	elif not _release_required and reserve > 0.0:
		active = true
		_activation_left = capacity
		TimeScaleAuthority.request(self, world_speed)
		_set_phase(&"entering", &"pressed")
		started.emit()


func _can_use() -> bool:
	return _blocked_reason() == &""


func _blocked_reason() -> StringName:
	if not is_instance_valid(player) or not is_instance_valid(combat): return &"unavailable"
	if combat.health <= 0: return &"dead"
	if get_tree().paused: return &"paused"
	if not player.control_enabled or not combat.enabled: return &"controls_disabled"
	if player.is_on_floor(): return &"grounded"
	if not TemporalBindings.conflicts(&"focus").is_empty(): return &"binding_conflict"
	return &""


func _can_refund() -> bool:
	return is_instance_valid(player) and is_instance_valid(combat) and player.control_enabled and combat.enabled and combat.health > 0 and not get_tree().paused


func _stop(reason: StringName = &"interrupted", clear_visual: bool = false) -> void:
	if not active:
		if clear_visual and phase != &"idle":
			_set_phase(&"idle", reason)
		return
	active = false
	_activation_left = 0.0
	TimeScaleAuthority.release(self)
	_set_phase(&"idle" if clear_visual else &"exiting", reason)
	ended.emit()


func _interrupted() -> void:
	interrupt(&"dead" if is_instance_valid(combat) and combat.health <= 0 else &"interrupted")


func interrupt(reason: StringName = &"interrupted") -> void:
	_release_required = Input.is_action_pressed("focus")
	_stop(reason, true)
	TimeScaleAuthority.release(self)


func _set_phase(next_phase: StringName, reason: StringName = &"") -> void:
	var previous := phase
	phase = next_phase
	_phase_age = 0.0
	if reason != &"": exit_reason = reason
	_transition_serial += 1
	state_changed.emit(previous, phase, reason)


func reset_state() -> void:
	interrupt(&"reset")
	reserve = capacity
	_activation_left = 0.0
	_last_tick = Time.get_ticks_usec()
	_airtime = -1
	_defeated_ids.clear()
	_last_parry_tick = -1000000
	_sync_airtime()


func _profile_changed(_profile: ParkourProfile) -> void:
	reset_state()


func _sync_airtime() -> void:
	if _airtime == player.airtime_serial:
		return
	_airtime = player.airtime_serial
	_parry_refunds = 0
	_kill_refunds = 0
	_wall_refunds = 0
	_air_hit_refunds = 0
	_air_hit_ids.clear()
	# The first wall contact starts the traversal; the refund belongs to a
	# subsequent segment completed during the same airborne sequence.
	_last_wall_run_count = player.wall_run_count + 1
	_observed_wall_run_count = player.wall_run_count


func _parried() -> void:
	if not _can_refund():
		return
	_sync_airtime()
	var tick := Time.get_ticks_usec()
	if _parry_refunds >= 2 or tick - _last_parry_tick < 120000:
		return
	_last_parry_tick = tick
	_parry_refunds += 1
	reserve = minf(capacity, reserve + 0.18)


func _hit_confirmed(target: Node3D, _point: Vector3, defeated: bool) -> void:
	if not is_instance_valid(target) or not _can_refund():
		return
	_sync_airtime()
	var id := target.get_instance_id()
	if not defeated:
		if not player.is_on_floor() and _air_hit_refunds < 3 and not _air_hit_ids.has(id):
			_air_hit_ids[id] = true
			_air_hit_refunds += 1
			reserve = minf(capacity, reserve + 0.06)
		return
	if _kill_refunds >= 3 or _defeated_ids.has(id):
		return
	_defeated_ids[id] = true
	_kill_refunds += 1
	reserve = minf(capacity, reserve + 0.12)


func _wall_started(_side: int) -> void:
	if not _can_refund():
		return
	_sync_airtime()
	var segment := player.wall_run_count
	_observed_wall_run_count = maxi(_observed_wall_run_count, segment)
	if segment <= _last_wall_run_count or _wall_refunds >= 2:
		return
	_last_wall_run_count = segment
	_wall_refunds += 1
	reserve = minf(capacity, reserve + 0.12)


func status() -> Dictionary:
	var blocked := _blocked_reason()
	return {"active": active, "reserve": reserve, "capacity": capacity,
		"ready": reserve > 0.0 and not _release_required and blocked == &"",
		"release_required": _release_required, "phase": phase, "phase_age": _phase_age,
		"exit_reason": exit_reason, "blocked_reason": blocked, "transition_serial": _transition_serial,
		"remaining_real_seconds": minf(reserve, _activation_left) if active else 0.0,
		"world_speed": Engine.time_scale, "action": &"focus", "binding": TemporalBindings.label(&"focus")}


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT] and is_node_ready():
		interrupt(&"window_focus_lost")


func _exit_tree() -> void:
	_stop(&"scene_exit", true)
	TimeScaleAuthority.release(self)
