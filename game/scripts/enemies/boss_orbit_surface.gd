class_name BossOrbitSurface
extends AnimatableBody3D
## Tangential wall and narrow recovery ledge move as one real physics body.
var center := Vector3.ZERO
var radius: float = 5.7
var angle: float = 0.0
var angular_speed: float = .09
var player: ParkourPlayer
var controller: BossPhaseController
var vertical_offset: float = 0.0
var route_role: StringName = &"wall_face"
var route_index: int = 0

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group("boss_surfaces")
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	if route_role == &"broken_deck":
		# Low route pieces stay below the wall-run line and expose the gap for a
		# slide-jump or grapple transfer into the next core.
		_part(Vector3(0,1.5,0),Vector3(4.8,3.0,.45))
	else:
		_part(Vector3(0,2.3,0),Vector3(4.8,4.6,.45))
	# Even route indices are broken decks with a visible centre gap. Odd indices
	# keep a full wall face for sustained wall running and a clear core approach.
	if route_role == &"broken_deck":
		_part(Vector3(-1.35,0,-.65),Vector3(2.0,.28,1.6))
		_part(Vector3(1.35,0,-.65),Vector3(2.0,.28,1.6))
	else:
		_part(Vector3(0,0,-.65),Vector3(4.8,.28,1.6))
	place()

func _part(point: Vector3,size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	collider.shape = bounds
	collider.position = point
	add_child(collider)
	DemoGeometry.box(self,point,size,load("res://assets/materials/pbr/stone.tres"))

func place() -> void:
	global_position = center+Vector3.UP*vertical_offset+Vector3(sin(angle)*radius,0,cos(angle)*radius)
	global_rotation.y = angle

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not controller.is_running(): return
	angle += angular_speed*delta
	place()
