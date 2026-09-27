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
## The priest uses an orbiting ring; the forge uses a staggered maintenance
## chain. Both remain real AnimatableBody3D surfaces for the same movement API.
var route_mode: StringName = &"orbit"
var route_point := Vector3.INF
var route_yaw: float = 0.0
var _collision_proxy: StaticBody3D

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group("boss_surfaces")
	collision_layer = 0 if route_mode == &"forge" else 1
	collision_mask = 0
	sync_to_physics = false
	if route_mode == &"forge":
		_collision_proxy = StaticBody3D.new()
		_collision_proxy.name = "ForgeSurfaceCollision"
		_collision_proxy.collision_layer = 1
		_collision_proxy.collision_mask = 0
		add_child(_collision_proxy)
	if route_role == &"broken_deck":
		# Keep the deck low, but give its broken wall face enough vertical
		# coverage for the player's two wall-run probes after a short grapple.
		_part(Vector3(0,1.5,0),Vector3(6.4,5.6,.45))
	else:
		_part(Vector3(0,2.3,0),Vector3(6.4,4.6,.45))
	if route_mode == &"forge":
		# Heavy steel braces and a heat seam distinguish the forge's supported
		# service route from the priest's pale floating stone ring.
		var iron := load("res://assets/materials/pbr/iron.tres") as Material
		var heat := DemoGeometry.material(Color("#b95f35"),1.15)
		_part(Vector3(0,-.48,0),Vector3(6.8,.22,.62),iron)
		DemoGeometry.box(self,Vector3(0,.03,-.31),Vector3(5.2,.06,.08),heat)
		for side: float in [-1.0,1.0]:
			DemoGeometry.box(self,Vector3(side*2.45,-.24,0),Vector3(.16,.72,.28),iron)
	# Even route indices are broken decks with a visible centre gap. Odd indices
	# keep a full wall face for sustained wall running and a clear core approach.
	if route_role == &"broken_deck":
		_part(Vector3(-1.8,0,-.65),Vector3(2.7,.28,1.6))
		_part(Vector3(1.8,0,-.65),Vector3(2.7,.28,1.6))
	else:
		_part(Vector3(0,0,-.65),Vector3(6.4,.28,1.6))
	place()

func _part(point: Vector3,size: Vector3,material: Material = null) -> void:
	var collider := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	collider.shape = bounds
	collider.position = point
	(_collision_proxy if is_instance_valid(_collision_proxy) else self).add_child(collider)
	if material == null: material=load("res://assets/materials/pbr/stone.tres")
	DemoGeometry.box(self,point,size,material)

func place() -> void:
	if route_mode == &"forge" and route_point.is_finite():
		global_position = center+route_point
		global_rotation.y = route_yaw
	else:
		global_position = center+Vector3.UP*vertical_offset+Vector3(sin(angle)*radius,0,cos(angle)*radius)
		global_rotation.y = angle
	# Custom forge points are authored before the body enters the physics tree.
	# Push the final transform immediately so shape queries cannot retain a stale
	# orbital broadphase position during the first shield setup.
	force_update_transform()
	if is_instance_valid(_collision_proxy): _collision_proxy.force_update_transform()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not controller.is_running(): return
	angle += angular_speed*delta
	place()
