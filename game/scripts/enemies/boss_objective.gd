class_name BossObjective
extends StaticBody3D
## Attackable encounter objective. Never counts as a kill or an altar reward.
signal shattered(objective: BossObjective)
signal struck(objective: BossObjective)
var controller: BossPhaseController
var kind: StringName = &"core"
var health: int = 1
var ordinal: int = 0

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group("boss_objectives")
	collision_layer = 4
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .55
	collision.shape = sphere
	add_child(collision)
	# Functional markers use existing materials; final assets bind to the signals.
	var tint := Color("#dc8a42") if kind == &"core" else Color("#a38dbb")
	DemoGeometry.sphere(self, Vector3.ZERO, .38, DemoGeometry.material(tint, .65))
	DemoGeometry.label(self, Vector3.UP*.85, ("熔炉核心" if kind == &"core" else "束缚锁链")+" %d" % (ordinal+1), 22)

func get_hit_point() -> Vector3:
	return global_position

func receive_hit(amount: int, _direction: Vector3) -> bool:
	if amount <= 0 or health <= 0 or not is_instance_valid(controller) or not controller.can_break_objective(self):
		return false
	health = 0
	collision_layer = 0
	struck.emit(self)
	shattered.emit(self)
	hide()
	queue_free()
	return true
