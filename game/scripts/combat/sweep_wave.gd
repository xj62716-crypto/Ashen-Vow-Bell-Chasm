class_name SweepWave
extends Node3D
var player: ParkourPlayer
var radius: float = .5
var high: bool = false
var _hit: bool = false
var _ring: MeshInstance3D
var _halo: MeshInstance3D

func _ready() -> void:
	add_to_group("hostile_projectiles")
	var torus := TorusMesh.new()
	torus.inner_radius = .93
	torus.outer_radius = 1.0
	_ring = DemoGeometry.mesh(self,torus,Vector3.ZERO,DemoGeometry.material(Color("#ed5c5c") if high else Color("#ffa84e"),1.5))
	position.y += 1.25 if high else .25
	_halo = FxMaterials.sprite(self,2.85,FxMaterials.glow(Color("#d44e5e") if high else Color("#f3a953"),.65,true))
	_halo.rotation.x = -PI/2

func _physics_process(delta: float) -> void:
	radius += delta*7.0
	_ring.scale = Vector3(radius,1,radius)
	_halo.scale = Vector3(radius,radius,1)
	if radius>22:
		queue_free()
		return
	if not is_instance_valid(player) or not player.control_enabled or _hit:
		return
	var flat := Vector2(player.global_position.x-global_position.x,player.global_position.z-global_position.z)
	var height: float = .9 if player.crouched else 1.8
	if absf(flat.length()-radius)<.38+7.0*delta and global_position.y>player.global_position.y+.1 and global_position.y<player.global_position.y+height:
		var point := Vector3(player.global_position.x,global_position.y,player.global_position.z)
		var query := PhysicsRayQueryParameters3D.create(global_position,point,1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			_hit = true
			(player.get_node("Combat") as PlayerCombat).receive_damage(1)
