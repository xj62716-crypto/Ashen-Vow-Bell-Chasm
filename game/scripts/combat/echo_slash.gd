class_name EchoSlash
extends Node3D
## Replays actual committed blade sweeps; it never invents a hit along a route.
signal sweep_replayed(origin: Vector3, direction: Vector3)
var owner_combat: PlayerCombat
var sweeps: Array[Dictionary] = []
var _clock: float = 0.0
var _hits: Dictionary = {}

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group("transient_effects")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_combat) or not owner_combat.enabled or owner_combat.health <= 0 or not owner_combat.player.control_enabled:
		queue_free()
		return
	_clock -= delta
	if _clock > 0: return
	if sweeps.is_empty():
		queue_free()
		return
	var sweep: Dictionary = sweeps.pop_front()
	_clock = .12
	sweep_replayed.emit(sweep.origin, sweep.forward)
	for node: Node in get_tree().get_nodes_in_group("acolytes"):
		var enemy := node as LanternAcolyte
		if enemy.health <= 0 or not enemy.active or _hits.has(enemy.get_instance_id()): continue
		var offset: Vector3 = enemy.get_hit_point() - sweep.origin
		if offset.length() > float(sweep.reach) or offset.normalized().dot(sweep.forward) < cos(deg_to_rad(85 if sweep.wide else 42)): continue
		var ray := PhysicsRayQueryParameters3D.create(sweep.origin, enemy.get_hit_point(), 5)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.get("collider") != enemy: continue
		_hits[enemy.get_instance_id()] = true
		if enemy.receive_hit(1, sweep.forward): owner_combat.confirm_hit(enemy, enemy.get_hit_point(), enemy.health <= 0)
