class_name TimelineRuntime
extends Node
## Runtime owner for the present/remnant route split from core-gameplay-plan-r6.
## It only changes authored timeline geometry and atmosphere; player transform,
## velocity, gravity and camera state remain owned by ParkourPlayer.

signal shifted(previous: StringName, current: StringName)
signal blocked(reason: StringName)
signal resource_changed(charges: int, maximum: int)

const ACTION := &"timeline_shift"
const PRESENT := &"present"
const REMNANT := &"remnant"

@export_range(1, 4, 1) var maximum_charges: int = 2
@export_range(0.05, 1.0, 0.05) var cooldown_seconds: float = 0.28
var charges: int = 2
var phase: StringName = PRESENT
var cooldown_left: float = 0.0
var player: ParkourPlayer
var room: CombatRoom
var _trial: MovementTrial
var _input_locked: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_action()
	charges = maximum_charges

func bind(owner_trial: MovementTrial, owner_player: ParkourPlayer, owner_room: CombatRoom) -> void:
	_trial = owner_trial
	player = owner_player
	room = owner_room
	if is_instance_valid(room):
		room.timeline_runtime = self
		room.apply_timeline_phase(phase)
	_emit_resource()

func set_room(owner_room: CombatRoom) -> void:
	room = owner_room
	if is_instance_valid(room):
		room.timeline_runtime = self
		room.apply_timeline_phase(phase)

func _process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if _trial == null or _trial.phase != MovementTrial.Phase.RUNNING:
		return
	if Input.is_action_just_pressed(ACTION):
		try_shift()

func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_V
	InputMap.action_add_event(ACTION, event)

func try_shift() -> bool:
	if cooldown_left > 0.0:
		blocked.emit(&"cooldown")
		return false
	if not is_instance_valid(player) or not player.control_enabled:
		blocked.emit(&"unavailable")
		return false
	if charges <= 0:
		blocked.emit(&"empty")
		return false
	if not is_instance_valid(room) or not room.enabled:
		blocked.emit(&"unavailable")
		return false
	var previous := phase
	phase = REMNANT if phase == PRESENT else PRESENT
	charges -= 1
	cooldown_left = cooldown_seconds
	room.apply_timeline_phase(phase)
	_emit_resource()
	shifted.emit(previous, phase)
	return true

func refund(amount: int = 1, reason: StringName = &"movement") -> void:
	if amount <= 0:
		return
	var before := charges
	charges = mini(maximum_charges, charges + amount)
	if charges != before:
		_emit_resource()

func refill() -> void:
	var before := charges
	charges = maximum_charges
	if charges != before:
		_emit_resource()

func reset_state() -> void:
	phase = PRESENT
	charges = maximum_charges
	cooldown_left = 0.0
	_input_locked = false
	if is_instance_valid(room):
		room.apply_timeline_phase(phase)
	_emit_resource()

func status() -> Dictionary:
	return {
		"phase": phase,
		"charges": charges,
		"maximum": maximum_charges,
		"cooldown": cooldown_left,
		"ready": charges > 0 and cooldown_left <= 0.0,
		"action": ACTION,
		"binding": TemporalBindings.label(ACTION),
	}

func _emit_resource() -> void:
	resource_changed.emit(charges, maximum_charges)
