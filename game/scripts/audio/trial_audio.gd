class_name TrialAudio
extends Node
## Instant semantic events: animation/contact code owns timing, never guessed timers.
## Existing play_effect, footsteps, phase and volume methods remain callable.
signal event_played(key: String, variant: int, tick_usec: int)

const Score = preload("res://scripts/audio/dynamic_score.gd")
const VOICE_COUNT := 24
const SPATIAL_COUNT := 16
const RESERVED_PRIORITY := 5
var sound_volume: float = .65
var music_volume: float = .4
var footstep_count: int = 0
var domain: int = 1
var tension: float = 0.0
# Historical capture-script handles; these are synchronized banks, no longer Ogg streams.
var music: AudioStreamPlayer
var combat_music: AudioStreamPlayer
var score: Node
var _events: Dictionary = {}
var _aliases: Dictionary = {}
var _streams: Dictionary = {}
var _voices: Array[Dictionary] = []
var _last_variant: Dictionary = {}
var _last_played: Dictionary = {}
var _loops: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _phase: String = "ready"
var _focused: bool = false
var _focus_mix: float = 0.0
var _world_rate: float = 1.0
var _tick: int = 0
var _tree_was_paused: bool = false
var _last_position := Vector3.ZERO
var _was_grounded: bool = false
var _step_distance: float = 0.0
var _step_lockout: float = 0.0
var _combat_hold_until: float = 0.0
var _move_hold_until: float = 0.0
var _boss: bool = false
var _surface: String = "stone"
var _lowpass: AudioEffectLowPassFilter
var _cut_parity: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/dark_fantasy/events.json"))
	_events = catalog["events"]
	_aliases = catalog["aliases"]
	for key: String in _events:
		var clips: Array[AudioStream] = []
		for path: String in _events[key]["clips"]:
			var stream := load(path) as AudioStreamWAV
			if bool(_events[key]["loop"]):
				stream = stream.duplicate() as AudioStreamWAV
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
			clips.append(stream)
		_streams[key] = clips
	for index in VOICE_COUNT + SPATIAL_COUNT:
		var spatial: bool = index >= VOICE_COUNT
		var speaker: Node = AudioStreamPlayer3D.new() if spatial else AudioStreamPlayer.new()
		speaker.name = "EffectVoice%d" % index
		speaker.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(speaker)
		if spatial:
			speaker.max_distance = 48.0
			speaker.unit_size = 6.0
			speaker.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		_voices.append({"player": speaker, "spatial": spatial, "key": "", "priority": -1,
			"started": 0, "base_pitch": 1.0, "world_time": false, "loop_id": ""})
	score = Score.new()
	add_child(score)
	music = score.players[0]
	combat_music = score.players[1]
	set_sound_volume(sound_volume)
	set_music_volume(music_volume)
	_tick = Time.get_ticks_usec()

func _ensure_buses() -> void:
	for pair in [["Music", "Master"], ["SFX", "Master"], ["WorldSFX", "SFX"],
		["PlayerSFX", "SFX"], ["Foley", "WorldSFX"], ["Magic", "WorldSFX"], ["Danger", "SFX"], ["UI", "SFX"]]:
		if AudioServer.get_bus_index(pair[0]) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, pair[0])
			AudioServer.set_bus_send(index, pair[1])
	var world: int = AudioServer.get_bus_index("WorldSFX")
	for index in AudioServer.get_bus_effect_count(world):
		var effect: AudioEffect = AudioServer.get_bus_effect(world, index)
		if effect is AudioEffectLowPassFilter:
			_lowpass = effect as AudioEffectLowPassFilter
	if _lowpass == null:
		_lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(world, _lowpass)
	_lowpass.cutoff_hz = 20000.0

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = minf(float(now - _tick) / 1000000.0, .10)
	_tick = now
	if get_tree().paused and not _tree_was_paused:
		stop_effects()
	_tree_was_paused = get_tree().paused
	_focus_mix = lerpf(_focus_mix, 1.0 if _focused else 0.0, 1.0 - exp(-dt * 12.0))
	_lowpass.cutoff_hz = lerpf(20000.0, 2400.0, _focus_mix)
	# Engine hit-stop must not accidentally trigger focus audio.
	for voice in _voices:
		if voice["player"].playing:
			voice["player"].pitch_scale = float(voice["base_pitch"]) * (lerpf(1.0, maxf(.45, _world_rate), _focus_mix) if voice["world_time"] else 1.0)
	if _phase == "running" and not get_tree().paused:
		_select_context()

func _canonical(key: String) -> String:
	return str(_aliases.get(key, key))

func play_effect(key: String, strength: float = 1.0) -> void:
	if key == "swing":
		key = "cut_outward" if _cut_parity % 2 == 0 else "cut_return"
		_cut_parity += 1
	play_event(key, {"strength": strength})

func play_event(key: String, context: Dictionary = {}) -> bool:
	key = _canonical(key)
	if not _events.has(key) or not _accept_events() or bool(_events[key]["loop"]):
		return false
	return _start_voice(key, _events[key], context, "")

func play_at(key: String, position_value: Vector3, strength: float = 1.0, emitter_id: String = "") -> bool:
	return play_event(key, {"position": position_value, "strength": strength, "emitter_id": emitter_id})

func begin_loop(token: String, key: String, context: Dictionary = {}) -> bool:
	key = _canonical(key)
	if not _accept_events() or not _events.has(key) or not bool(_events[key]["loop"]) or token.is_empty():
		return false
	if _loops.has(token):
		var existing: Dictionary = _voices[int(_loops[token])]
		if existing["player"].playing and existing["key"] == key:
			return true
		end_loop(token)
	return _start_voice(key, _events[key], context, token)

func end_loop(token: String) -> void:
	if _loops.has(token):
		var voice: Dictionary = _voices[int(_loops[token])]
		voice["player"].stop()
		voice["loop_id"] = ""
		_loops.erase(token)

func _accept_events() -> bool:
	return not get_tree().paused and _phase not in ["paused", "dead"] and sound_volume > 0.0

func _start_voice(key: String, spec: Dictionary, context: Dictionary, token: String) -> bool:
	var now: int = Time.get_ticks_usec()
	var throttle: String = key + ":" + str(context.get("emitter_id", token if not token.is_empty() else "local"))
	if float(now - int(_last_played.get(throttle, -10000000))) / 1000000.0 < float(spec["cooldown"]):
		return false
	var strength: float = clampf(float(context.get("strength", 1.0)), 0.0, 1.5)
	if strength <= 0.0 or not is_finite(strength):
		return false
	var spatial: bool = context.has("position")
	var priority: int = int(spec["priority"])
	var candidate: int = -1
	var active_count: int = 0
	var same_indices: Array[int] = []
	for index in _voices.size():
		var voice: Dictionary = _voices[index]
		if bool(voice["spatial"]) != spatial:
			continue
		if voice["player"].playing and voice["key"] == key:
			same_indices.append(index)
		if voice["player"].playing:
			active_count += 1
		elif candidate < 0:
			candidate = index
	# Keep four slots per pool for parries / fatal danger feedback.
	var capacity: int = SPATIAL_COUNT if spatial else VOICE_COUNT
	if priority < RESERVED_PRIORITY and active_count >= capacity - 4:
		candidate = -1
	if same_indices.size() >= int(spec["max_voices"]):
		candidate = -1
		for index in same_indices:
			if _voices[index]["loop_id"] == "" and (candidate < 0 or int(_voices[index]["started"]) < int(_voices[candidate]["started"])):
				candidate = index
	if candidate < 0:
		for index in _voices.size():
			var voice: Dictionary = _voices[index]
			if bool(voice["spatial"]) != spatial or voice["loop_id"] != "" or int(voice["priority"]) >= priority:
				continue
			if not voice["player"].playing:
				continue
			if candidate < 0 or int(voice["priority"]) < int(_voices[candidate]["priority"]):
				candidate = index
	if candidate < 0:
		return false
	# A sustained owner is never stolen; bound count without leaking an obsolete token.
	if bool(spec["loop"]) and same_indices.size() >= int(spec["max_voices"]):
		return false
	var clips: Array = _streams[key]
	var previous: int = int(_last_variant.get(key, -1))
	var variant: int = _rng.randi_range(0, clips.size() - 1)
	if clips.size() > 1 and variant == previous:
		variant = (variant + 1) % clips.size()
	var chosen: Dictionary = _voices[candidate]
	var speaker: Node = chosen["player"]
	speaker.stop()
	speaker.stream = clips[variant]
	speaker.bus = str(spec["bus"])
	var pitch: float = _rng.randf_range(.985, 1.015) if token.is_empty() else 1.0
	speaker.pitch_scale = pitch * (maxf(.45, _world_rate) if _focused and spec["world_time"] else 1.0)
	speaker.volume_db = float(spec["gain_db"]) + linear_to_db(strength)
	if spatial:
		speaker.global_position = context["position"]
		speaker.max_distance = 70.0 if priority >= 6 else 48.0
		speaker.unit_size = 12.0 if priority >= 6 else 6.0
	chosen.merge({"key": key, "priority": priority, "started": now, "base_pitch": pitch,
		"world_time": bool(spec["world_time"]), "loop_id": token}, true)
	if not token.is_empty():
		_loops[token] = candidate
	_last_played[throttle] = now
	_last_variant[key] = variant
	if _last_played.size() > 512:
		for old: String in _last_played.keys():
			if now - int(_last_played[old]) > 2000000:
				_last_played.erase(old)
	speaker.play()
	if priority >= 4:
		score.duck(priority)
	if key in ["jump", "land", "wall_kick", "slide_jump"]:
		_step_lockout = .18
		_step_distance = 0.0
	event_played.emit(key, variant, now)
	return true

func set_focus(active: bool, world_scale: float = .25) -> void:
	if active and (_phase != "running" or get_tree().paused):
		return
	_world_rate = clampf(world_scale, .05, 1.0) if active else 1.0
	if active == _focused:
		return
	_focused = active
	score.focused = active
	if active:
		play_effect("focus_enter")
		begin_loop("focus", "focus_loop")
	else:
		end_loop("focus")
		play_effect("focus_exit")

func set_phase(value: String) -> void:
	if value not in ["ready", "running", "paused", "finished", "dead", "retry"]:
		return
	var changed: bool = value != _phase
	if value != "running":
		stop_effects()
	if value in ["ready", "finished", "dead", "retry"]:
		tension = 0.0
		_boss = false
		_combat_hold_until = 0.0
		_move_hold_until = 0.0
		_cut_parity = 0
	_phase = value
	score.set_phase(value)
	if changed and value in ["dead", "retry"] and sound_volume > 0.0 and not get_tree().paused:
		var cue: String = "death" if value == "dead" else "retry"
		_start_voice(cue, _events[cue], {}, "")

func update_encounter(number: int, intensity: float) -> void:
	domain = clampi(number, 1, 3)
	score.set_domain(domain)
	tension = clampf(intensity, 0.0, 1.0) if is_finite(intensity) else 0.0
	if _phase == "running" and tension >= .23:
		_combat_hold_until = Time.get_ticks_msec() / 1000.0 + 2.5

func update_context(speed: float, airborne: bool, enemies: int, boss_active: bool) -> void:
	if _phase != "running":
		return
	_boss = boss_active
	if enemies > 0:
		_combat_hold_until = Time.get_ticks_msec() / 1000.0 + 2.5
	if speed > 9.0 or airborne:
		_move_hold_until = Time.get_ticks_msec() / 1000.0 + 1.2
	_select_context()

func _select_context() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	score.request_state("boss" if _boss else ("combat" if now < _combat_hold_until else ("movement" if now < _move_hold_until else "explore")))

func set_surface(material: String) -> void:
	_surface = material if material in ["stone", "wood", "earth", "snow"] else "stone"

func update_footsteps(player: ParkourPlayer, delta: float) -> void:
	if _phase != "running" or get_tree().paused:
		return
	_step_lockout = maxf(0.0, _step_lockout - delta)
	var wall: bool = player.is_wall_running()
	var grounded: bool = (player.is_on_floor() or wall) and not player.is_dashing() and not player.sliding
	var travelled: float = (player.global_position - _last_position).length()
	_last_position = player.global_position
	if player.horizontal_speed() > 9.0:
		_move_hold_until = Time.get_ticks_msec() / 1000.0 + 1.2
	if player.sliding:
		begin_loop("slide", "slide_loop")
	else:
		end_loop("slide")
	if not grounded or not _was_grounded or travelled > 1.5 or player.horizontal_speed() < 1.0:
		_step_distance = 0.0
	elif _step_lockout <= 0.0:
		_step_distance += travelled
		var stride: float = 2.0 if wall else 2.3
		if _step_distance >= stride:
			_step_distance = fmod(_step_distance, stride)
			footstep_count += 1
			play_effect("wall_step" if wall else "step_" + _surface, clampf(player.horizontal_speed() / maxf(1.0, player.move_speed), .4, 1.0))
	_was_grounded = grounded

func reset_steps(position_value: Vector3) -> void:
	_last_position = position_value
	_step_distance = 0.0
	_step_lockout = .18
	_was_grounded = false
	_cut_parity = 0

func stop_effects() -> void:
	for voice in _voices:
		voice["player"].stop()
		voice["loop_id"] = ""
	_loops.clear()
	_last_played.clear()
	_last_variant.clear()
	_focused = false
	_focus_mix = 0.0
	_world_rate = 1.0
	if _lowpass != null:
		_lowpass.cutoff_hz = 20000.0
	if is_instance_valid(score):
		score.focused = false
		score.clear_duck()

func set_sound_volume(value: float) -> void:
	sound_volume = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	_set_bus_volume("SFX", sound_volume, -3.0)
	if sound_volume == 0.0:
		stop_effects()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	_set_bus_volume("Music", music_volume, -7.0)

func set_category_volume(category: String, value: float) -> bool:
	if category not in ["Foley", "Magic", "Danger", "PlayerSFX", "WorldSFX", "UI"]:
		return false
	_set_bus_volume(category, clampf(value, 0.0, 1.0) if is_finite(value) else 0.0, 0.0)
	return true

func _set_bus_volume(bus: String, value: float, trim: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, value <= 0.0)
		AudioServer.set_bus_volume_db(index, trim + linear_to_db(maxf(.0001, value)))

func snapshot() -> Dictionary:
	var count: int = 0
	var spatial: int = 0
	for voice in _voices:
		if voice["player"].playing:
			count += 1
			spatial += int(voice["spatial"])
	return {"voices": count, "spatial_voices": spatial, "capacity": _voices.size(), "loops": _loops.keys(),
		"focus": _focused, "lowpass_hz": _lowpass.cutoff_hz, "phase": _phase, "score": score.snapshot()}

func _exit_tree() -> void:
	stop_effects()
	for voice in _voices:
		voice["player"].stream = null
	_streams.clear()
	if is_instance_valid(score):
		score.stop()
