extends Node
## Four phase-locked stems per suite; two banks crossfade between regions.
## Beats follow mixed PCM frames; fade/duck envelopes use real time, not world time.
signal state_changed(state: String)

const STATES := {"explore": [1.0, 0.0, 0.0, 0.0], "movement": [.85, .85, 0.0, 0.0],
	"combat": [.72, .8, 1.0, 0.0], "boss": [.65, .8, 1.0, 1.0]}
var players: Array[AudioStreamPlayer] = []
var domain: int = 1
var state: String = "explore"
var pending_state: String = "explore"
var phase: String = "ready"
var focused: bool = false
var _suites: Array = []
var _banks: Array[AudioStreamSynchronized] = []
var _weights: Array[float] = [1.0, 0.0, 0.0, 0.0]
var _active: int = 0
var _fade: float = 1.0
var _queued_domain: int = 1
var _clock: float = 0.0
var _pending_at: float = 0.0
var _last_tick: int = 0
var _duck_until: float = 0.0
var _duck_depth: float = 1.0
var _duck_gain: float = 1.0
var _phase_gain: float = 0.0
var _paused: bool = false
var _library: Array[Array] = []
var _transport_capture: AudioEffectCapture
var _transport_index: int = -1
var _last_audio_frames: int = 0
var _music_clock: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/dark_fantasy/music.json"))
	_suites = data["suites"]
	# Synchronized streams do not report playback position in Godot 4.7. Count
	# mixed frames on Music instead; the bounded ring need not be copied/read.
	_transport_capture = AudioEffectCapture.new()
	_transport_capture.buffer_length = .08
	var bus: int = AudioServer.get_bus_index("Music")
	AudioServer.add_bus_effect(bus, _transport_capture)
	_transport_index = AudioServer.get_bus_effect_count(bus) - 1
	# Cache compressed resources at startup to avoid synchronous file IO at region boundaries.
	for suite: Dictionary in _suites:
		var clips: Array[AudioStreamOggVorbis] = []
		for path: String in suite["stems"]:
			clips.append(load(path) as AudioStreamOggVorbis)
		_library.append(clips)
	for index in 2:
		var speaker := AudioStreamPlayer.new()
		speaker.name = "ScoreBank%d" % index
		speaker.bus = "Music"
		speaker.volume_db = -80.0
		add_child(speaker)
		players.append(speaker)
		_banks.append(null)
	_load_bank(0, 1)
	players[0].play()
	_last_tick = Time.get_ticks_usec()

func _load_bank(index: int, suite_number: int) -> void:
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = 4
	for layer in 4:
		var clip := _library[suite_number - 1][layer].duplicate() as AudioStreamOggVorbis
		clip.loop = true
		sync.set_sync_stream(layer, clip)
		sync.set_sync_stream_volume(layer, linear_to_db(maxf(.0001, _weights[layer])))
	_banks[index] = sync
	players[index].stream = sync

func set_domain(number: int) -> void:
	_queued_domain = clampi(number, 1, _suites.size())
	if _queued_domain != domain and _fade >= 1.0 and not _paused:
		_begin_domain()

func _begin_domain() -> void:
	domain = _queued_domain
	_active = 1 - _active
	_load_bank(_active, domain)
	players[_active].volume_db = -80.0
	players[_active].play()
	_fade = 0.0
	_clock = 0.0
	_music_clock = 0.0
	_pending_at = 0.0
	clear_duck()

func request_state(value: String) -> void:
	if not STATES.has(value) or value == pending_state:
		return
	pending_state = value
	var beat: float = 60.0 / float(_suites[domain - 1]["bpm"])
	_pending_at = (floorf(_music_clock / beat) + 1.0) * beat

func set_phase(value: String) -> void:
	phase = value
	if value in ["ready", "finished", "dead", "retry"]:
		state = "explore"
		pending_state = "explore"
		focused = false
		clear_duck()

func clear_duck() -> void:
	_duck_until = 0.0
	_duck_gain = 1.0
	_duck_depth = 1.0

func duck(priority: int) -> void:
	_duck_depth = minf(_duck_depth if _clock < _duck_until else 1.0, .36 if priority >= 6 else .58)
	_duck_until = maxf(_duck_until, _clock + (.55 if priority >= 6 else .22))

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = minf(float(now - _last_tick) / 1000000.0, .10)
	_last_tick = now
	_paused = get_tree().paused or phase == "paused"
	var mixed_frames: int = _transport_capture.get_frames_available() + _transport_capture.get_discarded_frames()
	var mixed_delta: float = maxf(0.0, float(mixed_frames - _last_audio_frames) / AudioServer.get_mix_rate())
	_last_audio_frames = mixed_frames
	for speaker in players:
		if speaker.stream_paused != _paused:
			speaker.stream_paused = _paused
	if _paused:
		return
	_clock += dt
	_music_clock += mixed_delta
	if pending_state != state and _music_clock >= _pending_at:
		state = pending_state
		state_changed.emit(state)
	for layer in 4:
		_weights[layer] = lerpf(_weights[layer], float(STATES[state][layer]), 1.0 - exp(-dt * 3.0))
		for bank in _banks:
			if bank != null:
				bank.set_sync_stream_volume(layer, linear_to_db(maxf(.0001, _weights[layer])))
	var target: float = 1.0 if phase == "running" else (.18 if phase == "dead" else .55)
	_phase_gain = lerpf(_phase_gain, target, 1.0 - exp(-dt * 3.0))
	var duck_target: float = _duck_depth if _clock < _duck_until else 1.0
	_duck_gain = lerpf(_duck_gain, duck_target, 1.0 - exp(-dt * (40.0 if duck_target < _duck_gain else 3.5)))
	_fade = minf(1.0, _fade + dt / 1.8)
	var base: float = _phase_gain * _duck_gain * (.65 if focused else 1.0)
	players[_active].volume_db = linear_to_db(maxf(.0001, base * sin(_fade * PI / 2.0)))
	players[1 - _active].volume_db = linear_to_db(maxf(.0001, base * cos(_fade * PI / 2.0)))
	if _fade >= 1.0:
		players[1 - _active].stop()
		if _queued_domain != domain:
			_begin_domain()

func snapshot() -> Dictionary:
	return {"domain": domain, "state": state, "pending": pending_state, "phase": phase,
		"weights": _weights.duplicate(), "duck": _duck_gain, "focused": focused,
		"crossfade": _fade, "paused": _paused, "clock": _clock, "music_clock": _music_clock,
		"banks_playing": int(players[0].playing) + int(players[1].playing)}

func stop() -> void:
	set_process(false)
	for speaker in players:
		if speaker.has_stream_playback():
			speaker.get_stream_playback().stop()
		speaker.stream_paused = false
		speaker.stop()
		speaker.stream = null
	_banks.clear()
	if _transport_capture != null:
		AudioServer.remove_bus_effect(AudioServer.get_bus_index("Music"), _transport_index)
		_transport_capture = null

func _exit_tree() -> void:
	stop()
	for speaker in players:
		speaker.stream = null
	_banks.clear()
	_library.clear()
