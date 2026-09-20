class_name BossHazard
extends Node3D
## A locked world-space area, a visible world-time tell, then one strike.
signal detonated(kind: StringName, point: Vector3)
var controller: BossPhaseController
var kind: StringName = &"ground"
var delay: float = 1.0
var radius: float = 2.0
var _marker: MeshInstance3D

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group("hostile_projectiles")
	var ring := TorusMesh.new()
	ring.inner_radius = radius-.08
	ring.outer_radius = radius
	_marker = DemoGeometry.mesh(self, ring, Vector3.UP*.06, DemoGeometry.material(Color("#d58050") if kind == &"ground" else Color("#9e82cb"), .8))
	if kind == &"air":
		var vertical := DemoGeometry.mesh(self, ring, Vector3.ZERO, _marker.material_override)
		vertical.rotation.x = PI/2

func threatens(body: Node3D) -> bool:
	var offset := body.global_position-global_position
	if kind == &"ground":
		return Vector2(offset.x,offset.z).length() <= radius+.3 and offset.y < 1.05 and offset.y > -.45
	var height: float = .9 if body is ParkourPlayer and body.crouched else 1.8
	var closest := body.global_position+Vector3.UP*clampf(global_position.y-body.global_position.y,.25,height-.15)
	return closest.distance_to(global_position) <= radius+.25

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not controller.is_running():
		queue_free()
		return
	delay -= delta
	if delay > 0: return
	var bodies: Array[Node3D] = [controller.actor.player]
	for decoy: Node in get_tree().get_nodes_in_group("echo_decoys"): bodies.append(decoy)
	for body in bodies:
		if not is_instance_valid(body) or not threatens(body): continue
		var point := body.global_position+Vector3.UP*.65
		var origin := global_position+Vector3.UP*.2
		var query := PhysicsRayQueryParameters3D.create(origin,point,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		if body is ParkourPlayer: (body.get_node("Combat") as PlayerCombat).receive_damage(1)
		else: body.receive_hit(1,Vector3.ZERO)
	detonated.emit(kind,global_position)
	queue_free()
