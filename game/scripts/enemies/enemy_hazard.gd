class_name EnemyHazard
extends Node3D
## A committed location tell and one world-time strike. New cover blocks it.
signal detonated
var player: ParkourPlayer
var target: Node3D
var delay: float = .7
var radius: float = 2.0
var _ring: MeshInstance3D

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group("hostile_projectiles")
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-.07
	mesh.outer_radius = radius
	_ring = DemoGeometry.mesh(self, mesh, Vector3.UP*.06, DemoGeometry.material(Color("#d99664"), .8))

func _physics_process(delta: float) -> void:
	delay -= delta
	if delay > 0: return
	var candidates: Array[Node3D] = []
	if is_instance_valid(player): candidates.append(player)
	for decoy: Node in get_tree().get_nodes_in_group("echo_decoys"): candidates.append(decoy)
	for body in candidates:
		var point := body.global_position + Vector3.UP*.7
		if point.distance_to(global_position+Vector3.UP*.7) > radius: continue
		var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.4, point, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		if body is ParkourPlayer: (body.get_node("Combat") as PlayerCombat).receive_damage(1)
		else: body.receive_hit(1, Vector3.ZERO)
	detonated.emit()
	queue_free()
