class_name EchoStep
extends StaticBody3D
## Short-lived route surface. Art is supplied independently by the selected VFX.

const SIZE := Vector3(1.7, 0.16, 1.7)
var lifetime: float = 2.5
var owner_player: ParkourPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("echo_steps")
	collision_layer = 1
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0 or not is_instance_valid(owner_player):
		collision_layer = 0
		queue_free()
