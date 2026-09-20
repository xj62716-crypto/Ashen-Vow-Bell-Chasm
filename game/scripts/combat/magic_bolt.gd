class_name MagicBolt
extends Node3D
## Swept collision catches thin walls and player bodies even at high speed.
signal contacted(point: Vector3, collider: Node)
var _contact_reported: bool = false
var direction := Vector3.FORWARD
var speed: float = 10.0
var lifetime: float = 5.0
var damage: int = 25
var friendly: bool = false
var owner_combat: PlayerCombat
var chain_allowed: bool = true
var guard_piercing: bool = false
var charged: bool = false
var airtime_serial: int = -1
var ignore_target: CollisionObject3D
var source_enemy: LanternAcolyte
var cast: ShapeCast3D
var _glow: MeshInstance3D
var _trail := ImmediateMesh.new()
var _points: Array[Vector3] = []
var _tint: Color
var element: StringName = &"arcane"
var blast_radius: float = 0.0
var frost_duration: float = 0.0
var frost_nova: bool = false
var fire_shatter: bool = false
var wind_force: bool = false
var visual_offset := Vector3.ZERO
var _visual: Node3D
var _visual_age: float=0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("friendly_projectiles" if friendly else "hostile_projectiles")
	cast = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.14
	cast.shape = sphere
	cast.collision_mask = 5 if friendly else 3
	cast.max_results = 1
	add_child(cast)
	if is_instance_valid(ignore_target):
		cast.add_exception(ignore_target)
	var tint := Color("#5ce7c2") if friendly else Color("#ff6b36")
	if friendly:
		tint = {&"fire":Color("#ef8749"),&"ice":Color("#87d6fa"),&"wind":Color("#b9e4ac"),&"blade":Color("#c7d6ea")}.get(element,tint)
	_tint = tint
	_visual=Node3D.new()
	add_child(_visual)
	if friendly and element in [&"ice",&"blade"]:
		var shard := PrismMesh.new()
		shard.size = Vector3(.10,.12,.5) if element==&"ice" else Vector3(.8,.025,.12)
		var mesh := DemoGeometry.mesh(_visual,shard,Vector3.ZERO,DemoGeometry.material(tint,.8))
		mesh.basis = Basis.looking_at(direction)
	else:
		DemoGeometry.sphere(_visual, Vector3.ZERO, (.075 if element==&"fire" else .035) if friendly else .085, DemoGeometry.material(tint.lightened(.6), 1.2))
	_glow = FxMaterials.sprite(_visual,(.42 if charged else .26) if friendly else .65,FxMaterials.glow(tint,.9 if friendly else 1.4))
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = _trail
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 1.2
	light.omni_range = 2.5
	_visual.add_child(light)

func _physics_process(delta: float) -> void:
	if _contact_reported or is_queued_for_deletion(): return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var travel: Vector3 = direction.normalized() * speed * delta
	cast.target_position = global_basis.inverse() * travel
	cast.force_shapecast_update()
	if cast.is_colliding():
		var body := cast.get_collider(0) as Node
		var point := cast.get_collision_point(0)
		# Capture the actual contact before damage can clear a target's collision
		# or free it. Natural expiry/cancellation never enters this notification.
		_contact_reported = true
		contacted.emit(point,body)
		if friendly and blast_radius>0:
			_explode(point-direction.normalized()*.04,body as LanternAcolyte)
		elif friendly and body is LanternAcolyte:
			_strike(body,point)
		if friendly and body is RunMechanism:
			body.receive_hit(damage,direction)
		elif friendly and (body is TerrainDevice or body is RiftConstruct):
			body.receive_hit(damage,direction)
		elif not friendly and body is ParkourPlayer:
			var combat := body.get_node("Combat") as PlayerCombat
			if combat.parry_left>0.0 and is_instance_valid(source_enemy):
				combat.confirm_parry(source_enemy)
				var reflected := MagicBolt.new()
				reflected.friendly = true
				reflected.owner_combat = combat
				reflected.damage = 1
				reflected.speed = maxf(26.0, speed * 1.6)
				reflected.direction = (source_enemy.get_hit_point()-point).normalized()
				reflected.guard_piercing = &"shade_parry" in combat.runes
				reflected.chain_allowed = false
				get_parent().add_child(reflected)
				reflected.global_position = point + reflected.direction*.18
			else:
				combat.receive_damage(damage)
		elif not friendly and body is EchoDecoy:
			body.receive_hit(damage, direction)
		elif friendly and body != null and body.has_method("receive_hit") and not (body is LanternAcolyte or body is RunMechanism or body is TerrainDevice or body is RiftConstruct):
			body.receive_hit(damage, direction)
		ImpactBurst.spawn(get_parent(),point,_tint,1.0 if blast_radius<=0 else 1.7,element,-direction)
		if friendly and is_instance_valid(owner_combat):owner_combat.spell_contact.emit(element)
		queue_free()
		return
	global_position += travel

func _strike(enemy: LanternAcolyte, point: Vector3) -> void:
	if not enemy.active or enemy.health<=0:
		return
	var frozen: bool = enemy.frozen_left>0
	if is_instance_valid(owner_combat) and &"arcane_seal" in owner_combat.runes:
		owner_combat.arts.mark(enemy, true)
	if (guard_piercing or fire_shatter) and enemy.threat_rank not in [&"miniboss",&"boss"]:
		enemy.break_guard(1.0)
	# Ice gives a readable two-shot sequence against a closed guard.
	if frost_duration>0 and not enemy.vulnerable and enemy.apply_frost(frost_duration):
		return
	if wind_force and not enemy.vulnerable:
		enemy.apply_wind(direction)
	var accepted: bool = enemy.receive_hit(damage,direction.normalized())
	if accepted and is_instance_valid(owner_combat):
		owner_combat.confirm_hit(enemy,point,enemy.health<=0,chain_allowed,charged,airtime_serial)
		if frozen and frost_nova and enemy.health<=0:
			for target: Node in get_tree().get_nodes_in_group("acolytes"):
				if target!=enemy and target.get_hit_point().distance_to(point)<=3.0 and _visible(point,target,enemy):
					target.apply_frost(frost_duration)
			ImpactBurst.spawn(get_parent(),point,Color("#87d6fa"),1.5)
	elif not accepted and is_instance_valid(owner_combat):
		owner_combat.blocked_hit.emit()

func _visible(point: Vector3, enemy: LanternAcolyte, excluded: LanternAcolyte) -> bool:
	var exclusions: Array[RID] = []
	if is_instance_valid(excluded): exclusions.append(excluded.get_rid())
	# Cover blocks blast and freeze propagation. Actors do not occlude an explosion.
	var ray := PhysicsRayQueryParameters3D.create(point,enemy.get_hit_point(),1,exclusions)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _explode(point: Vector3, direct: LanternAcolyte) -> void:
	for node: Node in get_tree().get_nodes_in_group("acolytes"):
		var enemy := node as LanternAcolyte
		if not enemy.active or enemy.health<=0:
			continue
		if enemy==direct or (enemy.get_hit_point().distance_to(point)<=blast_radius and _visible(point,enemy,direct)):
			_strike(enemy,enemy.get_hit_point())
	var wave := SpellBlast.new()
	wave.radius = blast_radius
	wave.tint = _tint
	get_parent().add_child(wave)
	wave.global_position = point

func _process(delta: float) -> void:
	_visual_age+=delta
	_visual.position=global_basis.inverse()*visual_offset*pow(maxf(0,1-_visual_age/.16),2)
	FxMaterials.face_camera(_glow)
	_points.append(_visual.global_position)
	while _points.size()>9:
		_points.pop_front()
	_trail.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if _points.size()<2 or camera == null:
		return
	_trail.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(_points.size()):
		var fraction: float = float(i)/(_points.size()-1)
		var toward := camera.global_position-_points[i]
		var side := direction.cross(toward).normalized()*(.045 if friendly else .07)*fraction
		_trail.surface_set_color(Color(_tint.r,_tint.g,_tint.b,fraction*.65))
		_trail.surface_add_vertex(to_local(_points[i]-side))
		_trail.surface_set_color(Color(_tint.r,_tint.g,_tint.b,fraction*.65))
		_trail.surface_add_vertex(to_local(_points[i]+side))
	_trail.surface_end()
