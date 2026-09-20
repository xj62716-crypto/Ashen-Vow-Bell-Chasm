extends OmniLight3D
var _time: float = 0.0
var _base_energy: float = 3.2

func _ready() -> void:
	_base_energy = light_energy
	_time = position.x + get_parent().position.z * 0.3

func _process(delta: float) -> void:
	_time += delta
	light_energy = _base_energy * (1.0 + 0.035 * sin(_time * 8.1) + 0.025 * sin(_time * 13.7))
