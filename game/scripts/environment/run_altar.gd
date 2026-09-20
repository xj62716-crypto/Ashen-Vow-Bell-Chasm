class_name RunAltar
extends StaticBody3D

signal requested(altar: RunAltar)
var used: bool = false
var player: ParkourPlayer
var _light: OmniLight3D
var _inscription: Label3D

func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var bounds := CylinderShape3D.new()
	bounds.height = 1.8
	bounds.radius = .8
	shape.shape = bounds
	shape.position.y = .9
	add_child(shape)
	var model := (load("res://assets/models/blender/run_altar.glb") as PackedScene).instantiate()
	add_child(model)
	var stone := (load("res://assets/materials/pbr/rock.tres") as StandardMaterial3D).duplicate() as StandardMaterial3D
	stone.uv1_scale = Vector3.ONE*1.7
	stone.albedo_color = Color("#626a63")
	stone.normal_scale = .45
	stone.roughness = .88
	for part in model.find_children("*", "MeshInstance3D", true, false):
		if str(part.name).begins_with("Octagonal") or str(part.name).begins_with("Plinth") or str(part.name).begins_with("Carved") or str(part.name).begins_with("Offering"):
			part.material_override = stone
	_light = OmniLight3D.new()
	_light.position.y = 1.7
	_light.light_color = Color("#b8ddd0")
	_light.light_energy = 2.5
	_light.omni_range = 5.0
	add_child(_light)
	_inscription = DemoGeometry.label(self, Vector3(0,2.25,0), "契印祭坛", 27)

func request() -> bool:
	if used or not is_instance_valid(player) or not player.control_enabled or get_tree().paused:
		return false
	if player.global_position.distance_to(global_position) > 3.5:
		return false
	requested.emit(self)
	return true

func consume() -> void:
	used = true
	_light.light_energy = .45
	_inscription.text = "契印已铭刻"

func _process(_delta: float) -> void:
	if not used and is_instance_valid(player):
		var close: bool = player.global_position.distance_to(global_position) < 3.5
		_inscription.modulate.a = 1.0 if close else .65
