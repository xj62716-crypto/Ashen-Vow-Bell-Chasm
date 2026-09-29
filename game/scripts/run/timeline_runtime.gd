class_name TimelineRuntime
extends Node
## Runtime owner for the present/remnant route split from core-gameplay-plan-r6.
## It only changes authored timeline geometry and atmosphere; player transform,
## velocity, gravity and camera state remain owned by ParkourPlayer.

signal shifted(previous: StringName, current: StringName)
signal blocked(reason: StringName)
signal resource_changed(charges: int, maximum: int)
signal combat_window_opened(enemy: LanternAcolyte, seconds: float)

const ACTION := &"timeline_shift"
const PRESENT := &"present"
const REMNANT := &"remnant"
const CollisionSafety = preload("res://scripts/run/timeline_collision.gd")

@export_range(1, 4, 1) var maximum_charges: int = 2
@export_range(0.05, 1.0, 0.05) var cooldown_seconds: float = 0.28
@export_range(4.0, 24.0, 0.5) var combat_window_range: float = 16.0
@export_range(0.4, 3.0, 0.1) var combat_window_seconds: float = 1.4
@export_range(4.0, 14.0, 0.5) var combat_window_minimum_speed: float = 7.0
var charges: int = 2
var phase: StringName = PRESENT
var cooldown_left: float = 0.0
var player: ParkourPlayer
var room: CombatRoom
var _trial: MovementTrial
var _input_locked: bool = false
var _pending_wall_phase: StringName = &""
var _handoff_source_walls: Array[CollisionObject3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_action()
	charges = maximum_charges

func bind(owner_trial: MovementTrial, owner_player: ParkourPlayer, owner_room: CombatRoom) -> void:
	_trial = owner_trial
	player = owner_player
	room = owner_room
	if is_instance_valid(player) and not player.wall_jumped.is_connected(_on_wall_jumped):
		player.wall_jumped.connect(_on_wall_jumped)
	if is_instance_valid(room):
		_pending_wall_phase = &""
		_handoff_source_walls.clear()
		room.timeline_runtime = self
		room.apply_timeline_phase(phase)
	_emit_resource()

func set_room(owner_room: CombatRoom) -> void:
	room = owner_room
	if is_instance_valid(room):
		_pending_wall_phase = &""
		_handoff_source_walls.clear()
		room.timeline_runtime = self
		room.apply_timeline_phase(phase)

func _process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if not _handoff_source_walls.is_empty() and is_instance_valid(player) and not player.is_wall_running():
		_release_handoff_source_walls()
		_pending_wall_phase = &""
		_open_traversal_combat_window()
	elif _pending_wall_phase != &"" and _handoff_source_walls.is_empty() and is_instance_valid(player) and not player.is_wall_running():
		# An airborne kick can leave the source wall before the shift input is
		# consumed. The receiving phase is armed for one frame, then becomes the
		# sole collidable world even when no source wall needed preserving.
		room.apply_timeline_phase(_pending_wall_phase)
		_pending_wall_phase = &""
		_open_traversal_combat_window()
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
	var next_phase := REMNANT if phase == PRESENT else PRESENT
	# Respawn, grapple release and same-frame scripted movement can update the
	# CharacterBody3D before the child collision shape has flushed its transform.
	# Sync both owners before checking destination solids so a phase switch never
	# accepts a capsule that is already inside a wall.
	player.force_update_transform()
	player.body_shape.force_update_transform()
	if not CollisionSafety.can_enter(player,room.geometry,next_phase):
		blocked.emit(&"occupied")
		return false
	phase = next_phase
	charges -= 1
	cooldown_left = cooldown_seconds
	# Input is sampled in the idle tick while wall contact is updated in the
	# physics tick. A wall kick can therefore clear _wall_active one frame before
	# the shift request is consumed. Keep the phase armed through that airborne
	# handoff instead of applying it immediately and deleting the source wall
	# under the runner.
	var wall_handoff := player.is_wall_running() or (not player.is_on_floor() and player.wall_chain_count > 0 and player._wall_normal.length_squared() > .5)
	if player.is_wall_running():
		# Enable the destination world immediately, but keep the single source
		# wall physically live until the explicit kick. This gives the player a
		# continuous wall surface while the target wall is already available for
		# the airborne reattach, instead of waiting for the source wall to expire.
		_begin_wall_handoff(phase, previous)
	elif wall_handoff:
		room.prepare_timeline_phase(phase)
		_pending_wall_phase = phase
	else:
		room.apply_timeline_phase(phase)
	if _pending_wall_phase == &"":
		_open_traversal_combat_window()
	_emit_resource()
	shifted.emit(previous, phase)
	return true

func _begin_wall_handoff(target: StringName, source: StringName) -> void:
	_handoff_source_walls.clear()
	if not is_instance_valid(room): return
	for node: Node in room.geometry.find_children("*", "StaticBody3D", true, false):
		if not node.has_meta("timeline_crossing"): continue
		if StringName(node.get_meta("timeline_phase", &"")) != source: continue
		if node is CollisionObject3D: _handoff_source_walls.append(node as CollisionObject3D)
	room.apply_timeline_phase(target)
	# Restore only the authored source crossing wall. Other departed-world
	# solids remain disabled, so a phase switch cannot create air walls.
	for body: CollisionObject3D in _handoff_source_walls:
		if not is_instance_valid(body): continue
		body.collision_layer = int(body.get_meta("timeline_base_layer", 1))
		body.collision_mask = int(body.get_meta("timeline_base_mask", 1))
		body.visible = true
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			shape.disabled = false
			shape.set_deferred("disabled", false)
	_pending_wall_phase = target

func _release_handoff_source_walls() -> void:
	for body: CollisionObject3D in _handoff_source_walls:
		if not is_instance_valid(body): continue
		body.collision_layer = 0
		body.collision_mask = 0
		body.visible = false
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			shape.disabled = true
			shape.set_deferred("disabled", true)
	_handoff_source_walls.clear()

func _on_wall_jumped(_normal: Vector3) -> void:
	if _handoff_source_walls.is_empty(): return
	_release_handoff_source_walls()
	_pending_wall_phase = &""
	_open_traversal_combat_window()

func _open_traversal_combat_window() -> int:
	# The shift rewards a committed airborne route. Ground toggles and a stale
	# traversal receipt never replace an enemy's normal guard-breaking mechanic.
	# A committed wall-kick/dash can finish on the authored receiver during the
	# same traversal beat.  Requiring the capsule to still be airborne made the
	# phase shift lose its combat payoff on landing, even though the player had
	# just completed the route.  The movement receipt and speed checks below stay
	# authoritative, so a stationary ground toggle still cannot open a window.
	if not is_instance_valid(player) or not is_instance_valid(room):
		return 0
	if not player.has_recent_traversal_action() or player.horizontal_speed() < combat_window_minimum_speed:
		return 0
	var opened := 0
	var origin := player.camera.global_position
	var facing := -player.camera.global_basis.z
	for enemy: LanternAcolyte in room.enemies:
		if not is_instance_valid(enemy) or not enemy.active or enemy.health <= 0 or enemy.vulnerable:
			continue
		if enemy.threat_rank in [&"miniboss", &"boss"] or is_instance_valid(enemy.boss_controller) or not CollisionSafety.active(enemy):
			continue
		var point := enemy.get_hit_point()
		var offset := point-origin
		if offset.length() > combat_window_range or facing.dot(offset.normalized()) < .42:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, point, 1, [player.get_rid(), enemy.get_rid()])
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		enemy.break_guard(combat_window_seconds)
		if is_instance_valid(enemy.brain): enemy.brain.interrupted()
		combat_window_opened.emit(enemy, combat_window_seconds)
		opened += 1
	return opened

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
	_pending_wall_phase = &""
	_handoff_source_walls.clear()
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
