class_name ProfessionArts
extends Node

signal performed(kind: StringName)
signal mark_changed(target: Node3D, point: Vector3, marked: bool, reason: StringName)
signal seal_detonated(target: Node3D, point: Vector3)
var _mark_points: Dictionary = {}
var combat: PlayerCombat
var player: ParkourPlayer
var mana: float=80
var edge: float=0
var cooldown: float=0
var locked: LanternAcolyte
var lock_left: float=0
var counter_target: LanternAcolyte
var counter_left: float=0
var slide_window: float=0
var skill_index: int=0
var action_clip: String=""
var action_left: float=0
var action_age: float=0
var constructs: Array[RiftConstruct]=[]
var marks: Array[Node3D]=[]
var mark_times: Dictionary={}
var _icons: Dictionary={}
var _lock_icon: Label3D
var _held: float=0
var _preview: MeshInstance3D
var _preview_pose := Transform3D.IDENTITY
var _preview_valid: bool=false
var _last_storm_attack: int=-1
var _skill_intent: StringName = &""
var _storm_refunds: Dictionary = {}
var release_required: bool = false
var soul_nodes: Array[RiftConstruct] = []
var _storm_airtime: int = -1
var _storm_targets: Dictionary = {}
var _tempest_used: bool = false
var execution_active:bool=false
var execution_age:float=0.
var execution_seconds:float=.18
var execution_start_sample:float=.075
var _execution_target:LanternAcolyte
var _execution_start:Vector3
var _execution_end:Vector3
var _execution_outward:Vector3

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	combat=get_parent() as PlayerCombat
	player=combat.player
	for setup in [["profession_skill",KEY_Q],["cycle_skill",KEY_Z]]:
		if not InputMap.has_action(setup[0]):
			InputMap.add_action(setup[0])
			var event := InputEventKey.new()
			event.physical_keycode=setup[1]
			InputMap.action_add_event(setup[0],event)
	player.wall_jumped.connect(_wall_kicked)
	player.slide_jumped.connect(func():
		if has(&"shade_slide"): slide_window=2.5)
	combat.parried.connect(_parried)
	combat.hit_confirmed.connect(_hit)
	combat.swing_started.connect(_swing)

func has(id: StringName) -> bool:
	return id in combat.runes

func reset_state() -> void:
	cancel_execution()
	mana=80
	edge=0
	cooldown=0
	lock_left=0
	counter_left=0
	slide_window=0
	skill_index=0
	_held=0
	_last_storm_attack=-1
	_skill_intent=&""
	release_required=Input.is_action_pressed("profession_skill")
	_storm_refunds.clear()
	_storm_airtime=-1
	_storm_targets.clear()
	_tempest_used=false
	action_left=0
	locked=null
	counter_target=null
	for construct in constructs:
		if is_instance_valid(construct):construct.queue_free()
	constructs.clear()
	for node in soul_nodes:
		if is_instance_valid(node): node.queue_free()
	soul_nodes.clear()
	for target in marks.duplicate(): _remove_mark(target,&"cleared")
	for icon in _icons.values():
		if is_instance_valid(icon):icon.queue_free()
	_icons.clear()
	marks.clear()
	mark_times.clear()
	_mark_points.clear()
	if is_instance_valid(_lock_icon):_lock_icon.queue_free()
	if is_instance_valid(_preview):_preview.queue_free()
	_preview=null

func modes() -> Array[StringName]:
	var result: Array[StringName]=[]
	if player.parkour_profile.id==&"shade":
		if has(&"shade_wall"):result.append(&"hunt")
		if has(&"shade_parry"):result.append(&"counter")
		if has(&"shade_slide"):result.append(&"sweep")
	else:
		if has(&"arcane_shape"):result.append_array([&"wall",&"well",&"anchor"])
		if has(&"arcane_seal"):result.append(&"seal")
		if has(&"arcane_storm"):result.append(&"storm")
	return result

func selected() -> StringName:
	# Context determines the single profession action; mixing cores never adds a
	# mode wheel between a player and the action that is already ready.
	if player.parkour_profile.id == &"shade":
		if has(&"shade_parry") and counter_left > 0 and is_instance_valid(counter_target): return &"counter"
		if has(&"shade_wall") and lock_left > 0 and not player.is_on_floor() and is_instance_valid(locked) and locked.health > 0: return &"hunt"
		if has(&"shade_slide") and slide_window > 0: return &"sweep"
		return &""
	if has(&"arcane_seal") and not marks.is_empty(): return &"seal"
	if has(&"arcane_shape"): return contextual_shape()
	if has(&"arcane_seal"): return &"seal"
	if has(&"arcane_storm"): return &"storm"
	return &""

func contextual_shape() -> StringName:
	var hit := aimed(18, 1)
	if not hit.is_empty():
		return &"well" if (hit.normal as Vector3).y > 0.65 else &"wall"
	return &"platform" if (-player.camera.global_basis.z).y < -0.20 else &"anchor"

func _physics_process(delta: float) -> void:
	if not combat.enabled or not player.control_enabled or combat.health<=0:
		cancel_execution()
		_held=0
		if is_instance_valid(_preview):_preview.hide()
		return
	if execution_active:
		advance_execution(delta)
		return
	if release_required:
		if not Input.is_action_pressed("profession_skill"): release_required=false
		return
	cooldown=maxf(0,cooldown-delta)
	action_left=maxf(0,action_left-delta)
	action_age+=delta
	lock_left=maxf(0,lock_left-delta)
	counter_left=maxf(0,counter_left-delta)
	slide_window=maxf(0,slide_window-delta)
	if has(&"shade_wall"):
		edge=clampf(edge+(delta*(1.3 if has(&"shade_edge_fast") else 1.0) if player.is_wall_running() else -delta*.12),0,1)
	if player.parkour_profile.id==&"arcanist":
		var generating: bool=player.horizontal_speed()>4 and (player.is_wall_running() or not player.is_on_floor())
		mana=minf(100,mana+delta*((23 if has(&"arcane_storm_capacity") else 17) if generating else 3))
	for target in marks.duplicate():
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			_remove_mark(target,&"invalid")
			continue
		_mark_points[target]=target.get_hit_point()
		mark_times[target]-=delta
		if mark_times[target]<=0:
			_remove_mark(target,&"expired")
		elif player.horizontal_speed()>5 and target.get_hit_point().distance_to(player.camera.global_position)<(8 if has(&"arcane_seal_proximity") else 5):
			detonate(target)
	if is_instance_valid(_lock_icon):
		_lock_icon.visible=lock_left>0 and is_instance_valid(locked) and locked.health>0
	if Input.is_action_pressed("profession_skill"):
		if _held == 0: _skill_intent = selected()
		_held+=delta
		# A hold always previews shaping when mixed with seals; a quick tap keeps
		# the ready detonation. No persistent mode switch is required.
		if has(&"arcane_shape") and (_held > .22 or marks.is_empty()):
			_skill_intent = contextual_shape()
			_show_preview()
	elif _held>0:
		activate_skill(_held)
		_held=0
		_skill_intent=&""
		if is_instance_valid(_preview):_preview.hide()

func aimed(distance: float,mask: int=5) -> Dictionary:
	var p := player.camera.global_position
	return player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p,p-player.camera.global_basis.z*distance,mask,[player.get_rid()]))

func visible_target(target: Node3D, distance: float=30) -> bool:
	var p := player.camera.global_position
	var end: Vector3=target.get_hit_point()
	if p.distance_to(end)>distance:return false
	var ray := PhysicsRayQueryParameters3D.create(p,end,1,[player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _wall_kicked(_normal: Vector3) -> void:
	if not has(&"shade_wall"):return
	var best: float=.35
	locked=null
	for node: Node in get_tree().get_nodes_in_group("acolytes"):
		var enemy := node as LanternAcolyte
		if not enemy.active or enemy.health<=0 or enemy.threat_rank in [&"miniboss",&"boss"]:continue
		if not visible_target(enemy,22 if has(&"shade_hunt_range") else 16):continue
		var score: float=(enemy.get_hit_point()-player.camera.global_position).normalized().dot(-player.camera.global_basis.z)
		if score>best:best=score;locked=enemy
	if locked!=null:
		lock_left=3.0
		if is_instance_valid(_lock_icon):_lock_icon.queue_free()
		_lock_icon=DemoGeometry.label(locked,Vector3.UP*2.5,"◇ Q · 飞檐处决",28)

func _parried() -> void:
	if not has(&"shade_parry"):return
	counter_left=3
	# PlayerCombat records the projectile's actual shooter, independent of aim.
	counter_target=combat.last_parried_enemy

func activate_skill(held: float=.1) -> bool:
	if get_tree().paused or not combat.enabled or not player.control_enabled or cooldown>0 or execution_active:return false
	var mode := _skill_intent if _skill_intent != &"" else selected()
	match mode:
		&"hunt":
			if lock_left<=0 or player.is_on_floor() or not is_instance_valid(locked):return false
			return execute(locked,&"execute")
		&"counter":
			if counter_left<=0 or not is_instance_valid(counter_target):return false
			if counter_target.health<=0:
				var offset: Vector3=player.global_position-counter_target.global_position
				offset.y=0
				if not travel_to(counter_target.global_position+offset.normalized()*1.4+Vector3.UP*.15): return false
				counter_left=0
				cooldown=.5
				_play_action("blink")
				return true
			return execute(counter_target,&"blink")
		&"sweep":
			if slide_window<=0:return false
			combat.cancel_attack()
			if not combat.try_attack():return false
			combat._attack_break_guard=true
			slide_window=2.0
			_play_action("sweep")
			cooldown=.7
			return true
		&"wall",&"well",&"anchor",&"platform":
			var placement := placement_for(mode)
			if not placement.valid:return false
			return create_construct(mode,placement.pose)!=null
		&"seal":
			if not marks.is_empty():return detonate_all()>0
			var hit := aimed(32 if has(&"arcane_seal_range") else 26)
			return mark(hit.get("collider") as Node3D)
		&"storm":
			if mana<25:return false
			mana-=25
			player.float_left=minf(player.float_capacity,player.float_left+.7)
			player.dash_available=true
			combat.charge_ready=true
			cooldown=2
			_play_action("storm")
			SkillEffect.spawn(get_tree().current_scene,player.camera.global_transform,&"rift",Color("#a4dbea"),.7)
			return true
	return false

func can_travel_to(destination:Vector3)->bool:
	if not player.control_enabled or get_tree().paused:return false
	var origin := player.global_position
	if origin.distance_to(destination)>(34 if has(&"shade_counter_range") else 30) or origin.distance_to(destination)<.6:return false
	# Sweep the actual standing capsule, then validate arrival space. No wall skip.
	var pose := player.global_transform
	pose.origin+=Vector3.UP*.06
	var collision := KinematicCollision3D.new()
	if player.test_move(pose,destination-pose.origin,collision,.02):return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=player.body_shape.shape
	query.transform=player.body_shape.global_transform
	query.transform.origin=destination+Vector3.UP*.96
	query.collision_mask=5
	query.exclude=[player.get_rid()]
	if not player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

func travel_to(destination: Vector3, grounded_finish: bool=true) -> bool:
	if not can_travel_to(destination):return false
	var origin:=player.global_position
	var stick:=Input.get_vector("move_left","move_right","move_forward","move_backward")
	var exit_direction: Vector3=player.global_basis*Vector3(stick.x,0,stick.y) if stick.length_squared()>.05 else -player.global_basis.z
	player.apply_rewind_state(destination,exit_direction*11+Vector3.UP*(2 if grounded_finish else 5),false)
	player._momentum_left=.6
	player._ignore_floor_once=true
	SkillEffect.spawn(get_tree().current_scene,Transform3D(Basis.IDENTITY,origin+Vector3.UP),&"blink",Color("#8fdace"),1,destination+Vector3.UP)
	return true

func execute(target: LanternAcolyte, kind: StringName) -> bool:
	if target.health<=0 or not target.active or target.threat_rank in [&"boss",&"miniboss"] or not visible_target(target,32 if has(&"shade_counter_range") else 26):return false
	var toward := (player.global_position-target.global_position)
	toward.y=0
	toward=toward.normalized()
	var arms:Node=player.get_node_or_null("FirstPersonArms")
	var spacing:float=arms.tuning.blade_execution_distance if arms and arms.get("tuning") else 1.95
	var destination := target.global_position+toward*spacing+Vector3.UP*.15
	if kind==&"execute":
		if not can_travel_to(destination):return false
		combat.cancel_attack()
		_execution_target=target;_execution_start=player.global_position;_execution_end=destination;_execution_outward=toward
		execution_age=0.;execution_seconds=arms.tuning.blade_execution_camera_seconds if arms and arms.get("tuning") else .18
		execution_start_sample=minf(_held,.16)
		player.apply_rewind_state(player.global_position,Vector3.ZERO,false)
		execution_active=true;player.blade_approach_active=true;cooldown=.5
		return true
	if not travel_to(destination):return false
	return finish_execution(target,kind,toward)

func cancel_execution()->void:
	execution_active=false;_execution_target=null;execution_age=0.
	if is_instance_valid(player):player.blade_approach_active=false

func advance_execution(delta:float)->void:
	if not is_instance_valid(_execution_target) or _execution_target.health<=0 or not _execution_target.active:
		cancel_execution();return
	execution_age=minf(execution_seconds,execution_age+delta)
	var wanted:Vector3=_execution_start.lerp(_execution_end,smoothstep(0.,1.,execution_age/execution_seconds))
	# Sweep each step too: an obstacle can enter the path after the initial check.
	var collision:=player.move_and_collide(wanted-player.global_position)
	if collision:
		cancel_execution();return
	if execution_age<execution_seconds:return
	var target:LanternAcolyte=_execution_target;var outward:Vector3=_execution_outward
	cancel_execution()
	if player.global_position.distance_to(target.global_position)>2.8 or not visible_target(target,4.):return
	finish_execution(target,&"execute",outward)

func finish_execution(target:LanternAcolyte,kind:StringName,toward:Vector3)->bool:
	target.break_guard(1)
	var hit: bool=target.receive_hit(1,-toward)
	if hit:combat.confirm_hit(target,target.get_hit_point(),target.health<=0)
	# Keep departure outside the target. Preserve lateral/backward input; default
	# to a lateral leap instead of propelling the camera through a dead mesh.
	var stick:=Input.get_vector("move_left","move_right","move_forward","move_backward")
	var depart:Vector3=player.global_basis*Vector3(stick.x,0,stick.y)
	if depart.dot(toward)<0:depart-=toward*depart.dot(toward)
	if depart.length_squared()<.05:depart=toward.cross(Vector3.UP)
	player.velocity=depart.normalized()*8.+Vector3.UP*(2.+edge*3. if kind==&"execute" else 2.)
	player._momentum_left=.35;player._ignore_floor_once=true
	player.dash_available=true
	if has(&"shade_counter_guard"):combat.invulnerability=maxf(combat.invulnerability,.45)
	edge=1.0 if has(&"shade_hunt_chain") else (.5 if has(&"shade_refund") else 0.0)
	lock_left=0
	counter_left=0
	cooldown=.5
	_play_action(str(kind))
	return hit

func placement_for(kind: StringName) -> Dictionary:
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z
	var hit := aimed(18,1)
	var point: Vector3=hit.get("position",origin+forward*10)
	var flat := Vector3(forward.x,0,forward.z).normalized()
	if flat.length()<.5:flat=-player.global_basis.z
	var pose := Transform3D(Basis.looking_at(flat),point)
	if kind==&"wall":
		if not hit.is_empty() and absf((hit.normal as Vector3).y)<.15:
			var normal: Vector3=hit.normal
			pose.basis=Basis(normal,Vector3.UP,normal.cross(Vector3.UP))
			pose.origin=point+normal*.22
			var ground_ray:=PhysicsRayQueryParameters3D.create(pose.origin,pose.origin-Vector3.UP*3,1,[player.get_rid()])
			var floor_hit:=player.get_world_3d().direct_space_state.intersect_ray(ground_ray)
			if not floor_hit.is_empty() and (floor_hit.normal as Vector3).y>.7:
				pose.origin.y=maxf(pose.origin.y,float(floor_hit.position.y)+RiftConstruct.dimensions(kind).y*.5+.015)
		else:
			pose.origin=point+Vector3.UP*2.35
	elif kind==&"well" or kind==&"platform":pose.origin=point+Vector3.UP*.2
	else:pose.origin=point+(hit.normal*.8 if not hit.is_empty() else Vector3.ZERO)
	return {"pose":pose,"valid":can_place(kind,pose) and mana>=construct_cost()}

func can_place(kind: StringName,pose: Transform3D) -> bool:
	if kind not in [&"wall",&"well",&"anchor",&"platform"]:return false
	var distance := player.camera.global_position.distance_to(pose.origin)
	if distance<2.5 or distance>24 or pose.origin.y<=player.fall_limit+3:return false
	var box := BoxShape3D.new()
	box.size=RiftConstruct.dimensions(kind)-Vector3.ONE*.004 if kind!=&"anchor" else Vector3.ONE*.96
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=box
	query.transform=pose
	query.collision_mask=7
	return player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func construct_cost() -> float:
	return 20.0 if has(&"arcane_shape_economy") else 30.0

func create_construct(kind: StringName,pose: Transform3D) -> RiftConstruct:
	if not has(&"arcane_shape") or not combat.enabled or not player.control_enabled or mana<construct_cost() or get_tree().paused or not can_place(kind,pose):return null
	for index in range(constructs.size()-1,-1,-1):
		if not is_instance_valid(constructs[index]) or constructs[index].is_queued_for_deletion():constructs.remove_at(index)
	if constructs.size()>=(5 if has(&"arcane_shape_capacity") else 3):
		var replaceable: RiftConstruct
		for existing in constructs:
			if not existing.supporting_player():
				replaceable=existing
				break
		if replaceable == null: return null
		if has(&"arcane_shape_recall"):
			for enemy: Node in get_tree().get_nodes_in_group("acolytes"):
				if not enemy.active or enemy.health<=0 or enemy.get_hit_point().distance_to(replaceable.global_position)>3: continue
				var ray:=PhysicsRayQueryParameters3D.create(replaceable.global_position,enemy.get_hit_point(),1,[replaceable.get_rid()])
				if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
				enemy.apply_wind(enemy.global_position-replaceable.global_position)
			performed.emit(&"shape_recall")
		constructs.erase(replaceable)
		replaceable.collision_layer=0
		replaceable.queue_free()
	var construct := RiftConstruct.new()
	construct.kind=kind
	construct.player=player
	construct.owner_arts=self
	construct.lifetime=20 if has(&"arcane_shape_duration") else 12
	get_tree().current_scene.add_child(construct)
	construct.global_transform=pose
	mana-=construct_cost()
	for index in range(constructs.size()-1,-1,-1):
		if not is_instance_valid(constructs[index]) or constructs[index].is_queued_for_deletion():constructs.remove_at(index)
	constructs.append(construct)
	cooldown=.35
	_play_action("shape")
	SkillEffect.spawn(get_tree().current_scene,pose,&"rift",Color("#77e8cf"),1.5)
	return construct

func _show_preview() -> void:
	if not is_instance_valid(_preview):
		_preview=MeshInstance3D.new()
		_preview.mesh=BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview.material_override=material
		_preview.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child(_preview)
	var mode := _skill_intent if _skill_intent != &"" else contextual_shape()
	var placement := placement_for(mode)
	_preview_pose=placement.pose
	_preview_valid=placement.valid
	(_preview.mesh as BoxMesh).size=RiftConstruct.dimensions(mode) if mode!=&"anchor" else Vector3.ONE*.6
	_preview.global_transform=_preview_pose
	(_preview.material_override as StandardMaterial3D).albedo_color=Color(.2,.9,.7,.28) if _preview_valid else Color(1,.2,.12,.25)
	_preview.show()

func mark(target: Node3D, automatic: bool = false) -> bool:
	if not has(&"arcane_seal") or get_tree().paused or not combat.enabled or not player.control_enabled:return false
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not (target is LanternAcolyte or target is RunMechanism or target is TerrainDevice) or (not automatic and mana<10):return false
	if not visible_target(target,32 if has(&"arcane_seal_range") else 26):return false
	if target in marks:return false if automatic else detonate(target)
	if target is LanternAcolyte and (target.health<=0 or not target.active):return false
	if marks.size()>=(7 if has(&"arcane_seal_capacity") else 4):return false
	if not automatic:mana-=10
	marks.append(target)
	mark_times[target]=22 if has(&"arcane_seal_range") else 14
	_icons[target]=DemoGeometry.label(target,Vector3.UP*(2.65 if target is LanternAcolyte else 1.1),"◇ 封印",26)
	_publish_mark(target,&"automatic" if automatic else &"manual")
	if not automatic:_play_action("mark")
	if automatic and has(&"arcane_seal_spread") and is_instance_valid(target) and not target.is_queued_for_deletion():
		for other: Node in get_tree().get_nodes_in_group("acolytes"):
			if other==target or other.health<=0 or other in marks or not other.active: continue
			if other.get_hit_point().distance_to(target.get_hit_point())>4 or not visible_target(other): continue
			var ray:=PhysicsRayQueryParameters3D.create(target.get_hit_point(),other.get_hit_point(),1)
			if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
			if marks.size()>=(7 if has(&"arcane_seal_capacity") else 4): break
			marks.append(other)
			mark_times[other]=14
			_icons[other]=DemoGeometry.label(other,Vector3.UP*2.65,"◇ 封印",26)
			_publish_mark(other,&"spread")
			break
	return true

func _publish_mark(target: Node3D, reason: StringName) -> void:
	var point: Vector3 = target.get_hit_point()
	_mark_points[target] = point
	var exiting := _marked_target_exiting.bind(target)
	if not target.tree_exiting.is_connected(exiting): target.tree_exiting.connect(exiting)
	mark_changed.emit(target,point,true,reason)

func _marked_target_exiting(target: Node3D) -> void:
	_remove_mark(target,&"invalid")

func _remove_mark(target: Variant, reason: StringName = &"cleared") -> void:
	if not target in marks: return
	var valid := is_instance_valid(target)
	var point: Vector3 = target.get_hit_point() if valid else _mark_points.get(target,Vector3.ZERO)
	if valid:
		var exiting := _marked_target_exiting.bind(target)
		if target.tree_exiting.is_connected(exiting): target.tree_exiting.disconnect(exiting)
	if _icons.has(target) and is_instance_valid(_icons[target]): _icons[target].queue_free()
	_icons.erase(target)
	mark_times.erase(target)
	_mark_points.erase(target)
	marks.erase(target)
	# The set and its supporting dictionaries already match the notification.
	# A freed object cannot be emitted as Node3D; its last known point is retained.
	mark_changed.emit(target if valid else null,point,false,reason)

func detonate(target: Node3D) -> bool:
	if not has(&"arcane_seal") or get_tree().paused or not combat.enabled or not player.control_enabled:return false
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target not in marks or not visible_target(target,35):return false
	var point: Vector3=target.get_hit_point()
	if target is RunMechanism or target is TerrainDevice:
		if not target.activate(): return false
	_remove_mark(target,&"detonated")
	if target is LanternAcolyte:
		if target.threat_rank not in [&"boss",&"miniboss"]:target.break_guard(2)
		if target.receive_hit(1,(point-player.camera.global_position).normalized()):combat.confirm_hit(target,point,target.health<=0)
		for node: Node in get_tree().get_nodes_in_group("acolytes"):
			if node == target or node.health <= 0 or node.get_hit_point().distance_to(point) >= (5 if has(&"arcane_seal_radius") else 3): continue
			var query := PhysicsRayQueryParameters3D.create(point, node.get_hit_point(), 1)
			if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			var exposed: bool = node.vulnerable
			node.apply_frost(1.2)
			if exposed and node.receive_hit(1, (node.get_hit_point()-point).normalized()): combat.confirm_hit(node,node.get_hit_point(),node.health<=0)
	SkillEffect.spawn(get_tree().current_scene,Transform3D(player.camera.global_basis,point),&"rift",Color("#baa5ef"),2.0)
	mana=minf(100,mana+8)
	_play_action("detonate")
	seal_detonated.emit(target if is_instance_valid(target) else null,point)
	return true

func detonate_all() -> int:
	var count: int=0
	var kills_before:=combat.kills
	var last_point:=Vector3.ZERO
	for target in marks.duplicate():
		if not is_instance_valid(target):continue
		var point: Vector3=target.get_hit_point()
		if detonate(target):
			count+=1
			last_point=point
	if count>=2 and combat.kills-kills_before>=2 and has(&"arcane_seal_gate"):
		_spawn_soul_node(last_point+Vector3.UP*1.5)
	return count

func _spawn_soul_node(point: Vector3) -> void:
	var node:=RiftConstruct.new()
	node.kind=&"anchor"
	node.player=player
	node.lifetime=6
	get_tree().current_scene.add_child(node)
	node.global_position=point
	soul_nodes.append(node)
	while soul_nodes.size()>2:
		var old:=soul_nodes.pop_front() as RiftConstruct
		if is_instance_valid(old):old.queue_free()

func _hit(_target: Node3D,_point: Vector3,dead: bool) -> void:
	if _storm_airtime!=player.airtime_serial:
		_storm_airtime=player.airtime_serial
		_storm_targets.clear()
		_tempest_used=false
		_storm_refunds.clear()
	var event := "%d:%d" % [player.airtime_serial, _target.get_instance_id()]
	if has(&"arcane_storm") and not player.is_on_floor() and not _storm_refunds.has(event):
		_storm_refunds[event] = true
		mana=minf(100,mana+(14 if has(&"arcane_storm_return") else 8))
		player.float_left=minf(player.float_capacity,player.float_left+.28)
		player._wall_time_used=maxf(0,player._wall_time_used-.3)
		player.velocity.y = maxf(player.velocity.y, 2.0 if dead else .5)
		_storm_targets[_target.get_instance_id()]=true
		if has(&"arcane_storm_tempest") and _storm_targets.size()>=3 and not _tempest_used:
			_tempest_used=true
			player.dash_available=true
			for enemy: Node in get_tree().get_nodes_in_group("acolytes"):
				if enemy.active and enemy.health>0 and visible_target(enemy,5):enemy.apply_wind(enemy.global_position-player.global_position)
			performed.emit(&"tempest")
	if dead and has(&"shade_wall") and not player.is_on_floor():
		player.dash_available=true
		if has(&"shade_refund"):edge=minf(1,edge+.5)
		if has(&"shade_soul_node"):
			_spawn_soul_node(_target.global_position+Vector3.UP*2.8)
	if dead and has(&"shade_slide_echo") and slide_window>0:slide_window=2.5

func configure_spell(bolt: MagicBolt) -> void:
	if has(&"arcane_storm") and not player.is_on_floor() and (mana>=12 or _last_storm_attack==combat.attacks):
		if _last_storm_attack!=combat.attacks:
			mana-=12
			_last_storm_attack=combat.attacks
		bolt.chain_allowed=true
		bolt.charged=true
		bolt.airtime_serial=player.airtime_serial
		bolt.guard_piercing=true

func _swing() -> void:
	# Motion and release effects come from the animated weapon socket.
	# Restarting sweep here used to delay the cutting pose past its damage window.
	pass

func _play_action(clip: String) -> void:
	action_clip=clip
	action_left=.55
	action_age=0
	performed.emit(StringName(clip))

func status() -> String:
	var names := {&"hunt":"飞檐猎杀",&"counter":"流刃决斗",&"sweep":"掠地破阵",&"wall":"塑形 · 墙面",&"well":"塑形 · 风井",&"anchor":"塑形 · 牵引锚",&"platform":"塑形 · 浮台",&"seal":"封印术士",&"storm":"风暴行者"}
	var mode := selected()
	if mode==&"":return "G · 回溯" if has(&"shade_echo") else "职业技等待触发 · 基础攻击始终可用"
	var resource: String="法力 %d / 100" % int(mana) if player.parkour_profile.id==&"arcanist" else "锋势 %d%%" % int(edge*100)
	var hint: String="Q · 施展就绪能力"
	if mode in [&"wall",&"well",&"anchor",&"platform"]:hint="按住 Q 预览，松开塑形 · 瞄准位置决定形态"
	if mode==&"seal":hint="攻击自动刻印 · Q 引爆 · 标记 %d" % marks.size()
	if mode==&"hunt" and lock_left>0:hint="Q · 空中处决已锁定目标"
	if mode==&"counter" and counter_left>0:hint="Q · 追身处决射手"
	return str(names[mode])+"  |  "+resource+"\n"+hint
