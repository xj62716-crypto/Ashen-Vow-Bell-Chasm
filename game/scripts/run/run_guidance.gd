extends Node
## Optional, event-led teaching inside the formal route. No movement locks,
## target-wall previews, forced camera or rewards for merely reading a cue.
var trial: MovementTrial
var enabled := true
var cue := ""
var completed: Dictionary = {}
var shown: Dictionary = {}
var remaining := 0.0
var _chain_started := false

func bind(manager: MovementTrial) -> void:
	trial = manager
	trial.player.wall_run_started.connect(_wall_started)
	trial.player.slide_jumped.connect(func(): completed[&"slide"] = true)
	trial.player.grapple.traversed.connect(func(_anchor: Node3D): completed[&"grapple"] = true)
	trial.timeline_runtime.shifted.connect(func(_before: StringName,_after: StringName): completed[&"phase"] = true)
	trial.combat.rune_applied.connect(func(_id: StringName): completed[&"altar"] = true)
	trial.combat.arts.performed.connect(func(kind: StringName):
		if kind in [&"shape", &"shape_attack", &"storm_shape"]: completed[&"shape"] = true)
	trial.combat.hit_confirmed.connect(func(_target: Node3D,_point: Vector3,_dead: bool):
		if trial.player.has_recent_traversal_action(): completed[&"combat"] = true)

func _wall_started(_side: int) -> void:
	if _chain_started and trial.player.wall_chain_count >= 2: completed[&"wall_chain"] = true
	_chain_started = true

func reset() -> void:
	completed.clear()
	shown.clear()
	cue = ""
	remaining = 0
	_chain_started = false

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: cue = ""; remaining = 0

func replay() -> void:
	enabled = true
	reset()
	# The pause-menu action explicitly starts a fresh formal journey. Keep
	# the selected class, and let the existing run owner reset all systems.
	trial.start_run()

func _offer(id: StringName, text: String) -> void:
	if shown.has(id) or completed.has(id) or remaining>0: return
	shown[id] = true
	cue = text
	remaining = 3.4

func _process(delta: float) -> void:
	if not is_instance_valid(trial) or not enabled or trial.phase != MovementTrial.Phase.RUNNING: return
	remaining = maxf(0,remaining-delta)
	if remaining<=0: cue = ""
	var player := trial.player
	var room := trial.combat_room
	if player.is_on_floor(): _chain_started = false
	if not room.altar.used:
		_offer(&"altar","E · 祭坛")
		return
	if room.stage == 1:
		var z := room.to_local(player.global_position).z
		if z > -12:
			if &"arcane_shape" in trial.combat.runes and not completed.has(&"shape"):
				_offer(&"shape","Q · 塑形落点")
			else:
				_offer(&"wall_chain","贴墙 · Shift")
		elif z > -73 and z < -50: _offer(&"wall_transfer","蹬墙 · 换侧")
		elif z > -104 and z < -85: _offer(&"slide","滑铲 → 跳")
		elif z > -124 and z < -104:
			if room.timeline_phase == &"present": _offer(&"phase","V · 残世")
			else: _offer(&"grapple","E · 牵引")
		elif z > -152 and z < -137 and room.timeline_phase == &"remnant":
			_offer(&"phase_landing","V · 现世")
		elif z < -168 and z > -185: _offer(&"combat","借势 · 出刃")
	if room.stage == 2 and room.signature_sections.has(&"forge_phase_crossing"):
		var entry: Vector3 = room.signature_sections[&"forge_phase_crossing"].from
		if player.global_position.distance_to(room.to_global(entry))<8:
			_offer(&"forge_transfer","蹬墙 · V · 换线")
	if player.is_wall_running() and not completed.has(&"focus"):
		var focus := player.get_node("TemporalFocus")
		if focus.status().phase in [&"entering",&"active"]: completed[&"focus"] = true
		elif player.wall_run_count>=3: _offer(&"focus","F · 专注")
