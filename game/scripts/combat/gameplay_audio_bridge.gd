extends Node
## Owns event timing only. Audio R1 owns clips, buses, priority and voice limits.
var player: ParkourPlayer
var audio: Node
var _boss_stages: Dictionary = {}
var special_jump_frame: int = -1

func configure(body: ParkourPlayer, output: Node) -> void:
	player = body
	audio = output
	# The baseline audio has no semantic/spatial API. Keep it functional until
	# the main thread adopts the audio lane, rather than inventing fallback sounds.
	if not supported(): return
	player.grapple.state_changed.connect(_grapple_changed)
	var focus := player.get_node("TemporalFocus") as TemporalFocus
	focus.state_changed.connect(_focus_changed)
	var rewind := player.get_node("PositionRewind") as PositionRewind
	rewind.rewound.connect(_rewound)
	rewind.decoy_created.connect(_decoy_created)
	player.wall_jumped.connect(_wall_jumped)
	player.slide_jumped.connect(_slide_jumped)

func supported() -> bool:
	return is_instance_valid(audio) and audio.has_method("play_event") and audio.has_method("begin_loop") and audio.has_method("set_focus")

func _grapple_changed(phase: StringName, _reason: StringName) -> void:
	if not supported(): return
	match phase:
		&"launch": audio.play_event("grapple_cast")
		&"pull":
			if is_instance_valid(player.grapple.anchor):
				audio.play_at("grapple_attach",player.grapple.anchor.global_position,.8,"player_hook")
			# Keep the authored traction bed only for the brief committed zip. It
			# ends automatically on detach and never becomes a pendulum loop.
			audio.begin_loop("chain","grapple_swing")
		&"detached":
			audio.end_loop("chain")
			audio.play_event("grapple_release")
		&"idle": audio.end_loop("chain")

func _focus_changed(_previous: StringName, _current: StringName, _reason: StringName) -> void:
	var focus := player.get_node("TemporalFocus") as TemporalFocus
	audio.set_focus(focus.active,focus.world_speed)

func _rewound(origin: Vector3, destination: Vector3, _path: PackedVector3Array) -> void:
	# This signal exists only after path/capsule validation succeeds. Rejected
	# input has no matching arrival. No fixed timer pretends to track the path.
	audio.play_at("rewind_start",origin,.75,"rewind_origin")
	audio.play_at("rewind_arrive",destination,.9,"rewind_destination")

func _decoy_created(decoy: EchoDecoy) -> void:
	if is_instance_valid(decoy): audio.play_at("echo_spawn",decoy.global_position,.75,str(decoy.get_instance_id()))

func _wall_jumped(_normal: Vector3) -> void:
	special_jump_frame = Engine.get_physics_frames()
	audio.play_event("wall_kick")

func _slide_jumped() -> void:
	special_jump_frame = Engine.get_physics_frames()
	audio.play_event("slide_jump")

func bind_room(room: CombatRoom) -> void:
	if not supported(): return
	_boss_stages.clear()
	for enemy in room.enemies:
		if not is_instance_valid(enemy): continue
		var shot:=_enemy_fired.bind(enemy)
		if not enemy.fired.is_connected(shot):enemy.fired.connect(shot)
		var tell := _enemy_windup.bind(enemy)
		if is_instance_valid(enemy.brain) and not enemy.brain.attack_committed.is_connected(tell):
			enemy.brain.attack_committed.connect(tell)
		if is_instance_valid(enemy.boss_controller):
			var boss := enemy.boss_controller
			_boss_stages[enemy.get_instance_id()] = boss.stage
			var callback := _boss_phase.bind(enemy)
			if not boss.phase_changed.is_connected(callback): boss.phase_changed.connect(callback)
			callback = _boss_event.bind(enemy)
			if not boss.mechanic_event.is_connected(callback): boss.mechanic_event.connect(callback)

func _enemy_fired(enemy:LanternAcolyte)->void:
	if not is_instance_valid(enemy) or not enemy.active or enemy.health<=0 or not player.control_enabled:return
	audio.play_at("hostile_bolt",enemy.get_hit_point(),.45,str(enemy.get_instance_id()))

func _enemy_windup(kind: StringName, _point: Vector3, _seconds: float, enemy: LanternAcolyte) -> void:
	if not is_instance_valid(enemy) or not enemy.active or enemy.health <= 0 or not player.control_enabled: return
	var key: String = {
		&"lunge":"enemy_melee_windup", &"high_sweep":"enemy_sweep_windup",
		&"bolt":"enemy_ranged_windup", &"fan":"enemy_ranged_windup",
		&"ritual":"enemy_aoe_windup", &"seal_lane":"enemy_aoe_windup",
		&"dive":"enemy_air_windup", &"high_wave":"enemy_air_windup",
		&"low_wave":"enemy_groundwave_windup", &"forge_ground":"enemy_aoe_windup",
		&"forge_air":"enemy_air_windup", &"forge_crossfire":"enemy_aoe_windup",
		&"priest_ground":"enemy_aoe_windup", &"priest_air":"enemy_air_windup"
	}.get(kind,"enemy_ranged_windup")
	audio.play_at(key,enemy.get_hit_point(),1.0,str(enemy.get_instance_id()))

func _boss_phase(stage: int, _state: StringName, enemy: LanternAcolyte) -> void:
	if not is_instance_valid(enemy): return
	var id := enemy.get_instance_id()
	var previous: int = _boss_stages.get(id,stage)
	_boss_stages[id] = stage
	if stage > previous and enemy.active and enemy.health > 0:
		audio.play_at("boss_phase",enemy.get_hit_point(),1.0,str(id))

func _boss_event(event: StringName, point: Vector3, _seconds: float, enemy: LanternAcolyte) -> void:
	if not is_instance_valid(enemy) or not enemy.active: return
	if event == &"terrain_warning": audio.play_at("enemy_groundwave_windup",point,1.0,str(enemy.get_instance_id()))

func update_context(room: CombatRoom) -> void:
	if not supported(): return
	var nearby := 0
	var boss_active := false
	for enemy in room.enemies:
		if not is_instance_valid(enemy) or not enemy.active or enemy.health <= 0: continue
		if enemy.global_position.distance_to(player.global_position) < 23: nearby += 1
		var boss := enemy.boss_controller
		if is_instance_valid(boss) and boss.activated and boss.is_running() and boss.state not in [&"cancelled",&"defeated"]: boss_active = true
	audio.update_context(player.horizontal_speed(),not player.is_on_floor(),nearby,boss_active)

func _exit_tree() -> void:
	if supported():
		audio.end_loop("chain")
		audio.set_focus(false)
