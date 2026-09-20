class_name EchoDecoy
extends StaticBody3D
## Gameplay target contract. Its final character/VFX representation is separate.

signal dissipated(reason: StringName)
var owner_player: ParkourPlayer
var remaining_lifetime: float = 1.6
var health: int = 1
var active: bool = true
var _expired: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("echo_decoys")
	collision_layer = 2
	collision_mask = 0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.65
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.825
	add_child(collider)


func _physics_process(delta: float) -> void:
	remaining_lifetime = maxf(0.0, remaining_lifetime - delta)
	if remaining_lifetime <= 0.0 or not is_instance_valid(owner_player):
		dissolve(&"expired")


func get_hit_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func is_targetable(_observer: Node3D = null) -> bool:
	return active and not _expired and health > 0 and remaining_lifetime > 0.0 and not is_queued_for_deletion()


func receive_hit(damage: int = 1, _direction: Vector3 = Vector3.ZERO) -> bool:
	if damage <= 0 or not is_targetable(): return false
	health = 0
	dissolve(&"hit")
	return true


func dissolve(reason: StringName = &"cleared") -> void:
	if _expired: return
	_expired = true
	active = false
	collision_layer = 0
	dissipated.emit(reason)
	queue_free()
