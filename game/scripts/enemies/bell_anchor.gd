class_name BellAnchor
extends StaticBody3D
## One external, directly breakable anchor opens its controller's core.
signal shattered
var owner_enemy: LanternAcolyte
var health: int = 1

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .4
	shape.shape = sphere
	add_child(shape)
	DemoGeometry.sphere(self, Vector3.ZERO, .32, DemoGeometry.material(Color("#c4a276"), .5))

func get_hit_point() -> Vector3:
	return global_position

func receive_hit(amount: int, _direction: Vector3) -> bool:
	if health <= 0 or amount <= 0: return false
	health = 0
	collision_layer = 0
	if is_instance_valid(owner_enemy): owner_enemy.break_guard(4.0)
	shattered.emit()
	queue_free()
	return true
