class_name PlayerCombat
extends Node
## Combat advances on physics time; impact hold affects the weapon, never movement.
signal chain_launched(origin: Vector3, target: Node3D, bolt: MagicBolt)
signal swing_started
signal hit_confirmed(target: Node3D, point: Vector3, defeated: bool)
signal hurt(amount: int)
signal died
signal ability_used
signal parried
signal blocked_hit
signal spell_contact(element: StringName)
signal temporal_reset_requested
signal rune_applied(id: StringName)
signal runes_reset
signal flow_changed(value: float, capacity: float)

@export var maximum_health: int = 2
@export var reach: float = 2.7
@export var windup: float = 0.09
@export var active_time: float = 0.12
@export var recovery_time: float = 0.23
var health: int = 2
var enabled: bool = false
var attacking: bool = false
var swing_return: bool = false
var _blade_sequence: int = 0
var attack_age: float = 0.0
var impact_hold: float = 0.0
var invulnerability: float = 0.0
var attacks: int = 0
var hits: int = 0
var kills: int = 0
var damage_taken: int = 0
var _hit_ids: Dictionary = {}
var _wait_release: bool = true
var _weapon: Node3D
var _damage: int = 0
var _swing_emitted: bool = false
var _projectile_fired: bool = false
var damage_multiplier: float = 1.0
var next_attack_multiplier: float = 1.0
var runes: Array[StringName] = []
var shield: bool = false
var _wall_buff_left: float = 0.0
var _tide_used: bool = false
var ability_cooldown: float = 0.0
var parry_left: float = 0.0
var attack_buffer: float = 0.0
var _chain_range: float = 5.0
var _slide_buff_left: float = 0.0
var charge_progress: float = 0.0
var charge_ready: bool = false
var _charge_spent: bool = false
var _counter_left: float = 0.0
var _attack_break_guard: bool = false
var _attack_charged: bool = false
var _attack_slide: bool = false
var _airtime_serial: int = -1
var _attack_airtime: int = -1
var arts: ProfessionArts
var last_parried_enemy: LanternAcolyte
var _primary_element: StringName = &"arcane"
@export_range(20.0, 100.0, 1.0) var flow_capacity: float = 100.0
@export_range(0.0, 100.0, 1.0) var flow_decay_per_second: float = 28.0
var flow: float = 0.0
var echo_cuts: Array[Dictionary] = []
var _confirmed_defeats: Dictionary = {}
var riposte_ready: bool = false
var _sweep_kills: int = 0
var _return_scheduled: bool = false
@onready var player: ParkourPlayer = get_parent() as ParkourPlayer
@onready var arms: FirstPersonArms = player.get_node("FirstPersonArms")


func _ready() -> void:
	arts=ProfessionArts.new()
	arts.name="ProfessionArts"
	add_child(arts)
	if not InputMap.has_action("ability"):
		InputMap.add_action("ability")
		var key := InputEventMouseButton.new()
		key.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("ability",key)
	player.recovered.connect(reset_state)
	player.profile_changed.connect(func(_profile: ParkourProfile): reset_run())
	arms.item_unequipped.connect(func(_hand: StringName): cancel_attack())
	player.wall_jumped.connect(func(_normal: Vector3):
		if &"shade_wall" in runes or &"arcane_stride" in runes:
			_wall_buff_left = 3.0
			)
	player.landed.connect(func(_impact: float): _tide_used = false)
	player.slide_started.connect(func(): _slide_buff_left=2.0)
	player.slide_jumped.connect(func():
		if &"shade_slide_chain" in runes:
			player.dash_available = true)
	player.wall_run_started.connect(func(_side: int): add_flow(18.0))
	player.slide_jumped.connect(func(): add_flow(22.0))
	player.dashed.connect(func(): add_flow(12.0))
	player.landed.connect(func(_impact: float): flow = maxf(0.0, flow - 8.0); _emit_flow())
	hit_confirmed.connect(func(_target: Node3D, _point: Vector3, defeated: bool): add_flow(25.0 if defeated else 12.0))


func reset_state() -> void:
	temporal_reset_requested.emit()
	if is_instance_valid(arts):arts.reset_state()
	cancel_attack()
	health = clampi(maximum_health,1,2)
	invulnerability = 0.0
	_wait_release = true
	next_attack_multiplier = 1.0
	_wall_buff_left = 0.0
	_tide_used = false
	parry_left = 0.0
	attack_buffer = 0.0
	ability_cooldown = 0.0
	_slide_buff_left = 0.0
	_counter_left = 0.0
	charge_progress = 0.0
	charge_ready = false
	_charge_spent = false
	flow = 0.0
	_emit_flow()
	echo_cuts.clear()
	riposte_ready=false
	last_parried_enemy = null
	_airtime_serial = player.airtime_serial


func reset_run() -> void:
	reset_state()
	attacks = 0
	_blade_sequence = 0
	swing_return = false
	hits = 0
	kills = 0
	damage_taken = 0
	runes.clear()
	_primary_element = &"arcane"
	_confirmed_defeats.clear()
	flow = 0.0
	_emit_flow()
	damage_multiplier = 1.0
	shield = false
	ability_cooldown = 0.0
	reach = 2.7
	_chain_range = 5.0
	runes_reset.emit()

func add_flow(amount: float) -> void:
	if amount <= 0.0 or not enabled:
		return
	var before := flow
	flow = clampf(flow + amount, 0.0, flow_capacity)
	if not is_equal_approx(before, flow):
		_emit_flow()

func movement_advantage() -> bool:
	return flow >= 20.0 or player.has_recent_traversal_action()

func _emit_flow() -> void:
	flow_changed.emit(flow, flow_capacity)

func allow_repeat_defeat(target:Node)->void:
	if is_instance_valid(target):_confirmed_defeats.erase(target.get_instance_id())


func apply_rune(id: StringName) -> bool:
	if id in runes:
		return false
	var rune := RuneCatalog.definition(id)
	if rune.is_empty() or rune["class"] != player.parkour_profile.id:
		return false
	if rune.get("requires", &"") != &"" and rune.requires not in runes:
		return false
	runes.append(id)
	if id == &"shade_wall_chain": player.wall_chain_limit=3
	if id == &"shade_wall_master": player.wall_chain_limit=4
	if id == &"arcane_element": _primary_element = &"fire"
	if rune.has("element"): _primary_element = rune.element
	if id == &"arcane_charge": _primary_element = &"lightning"
	if id == &"shade_slide":
		player.slide_boost = 4.0
		player.slide_jump_multiplier = 1.18
	if id == &"shade_wall":
		player.parkour_profile.wall_jump_height += 1.25
	if id == &"shade_rush":
		player.dash_exit_bonus = 7.0
	if id == &"shade_surge":
		player.slide_boost += 2.0
	if id == &"arcane_updraft":
		player.parkour_profile.wall_jump_height += 1.1
	if id == &"arcane_stride":
		player.parkour_profile.wall_speed += 3.0
		player.parkour_profile.wall_duration += .8
	if id == &"arcane_float" or id == &"arcane_suspend":
		player.float_capacity = maxf(player.float_capacity, 2.2 if id == &"arcane_suspend" else 1.4)
		player.float_left = player.float_capacity
	if id == &"shade_reach":
		reach = maxf(reach,3.6)
	if id == &"shade_cleave_reach":
		reach = maxf(reach,3.8)
	if id == &"arcane_network":
		_chain_range = 9.0
	if id==&"arcane_storm":
		player.float_capacity=maxf(player.float_capacity,.9)
		player.float_left=player.float_capacity
	if id==&"arcane_storm_chain":_chain_range=10
	rune_applied.emit(id)
	return true


func cancel_attack() -> void:
	attacking = false
	attack_age = 0.0
	impact_hold = 0.0
	_hit_ids.clear()
	_weapon = null
	_projectile_fired = false
	_attack_break_guard = false
	_attack_charged = false
	_attack_slide = false


func try_attack() -> bool:
	if not enabled or not player.control_enabled or health <= 0 or attacking or get_tree().paused or player.blade_approach_active:
		return false
	var definition: HeldItemDefinition = arms.get_item_definition(&"right")
	if definition == null or (definition.melee_damage <= 0 and not definition.ranged):
		return false
	if not definition.ranged:
		swing_return = _blade_sequence%2==1
		_blade_sequence += 1
	_weapon = arms.get_equipped_item(&"right")
	_damage = maxi(1, roundi((definition.projectile_damage if definition.ranged else definition.melee_damage) * damage_multiplier * next_attack_multiplier))
	next_attack_multiplier = 1.0
	attacking = true
	_sweep_kills=0
	_return_scheduled=false
	attack_age = 0.0
	impact_hold = 0.0
	_hit_ids.clear()
	_swing_emitted = false
	_projectile_fired = false
	_attack_charged = definition.ranged and charge_ready
	_attack_airtime = player.airtime_serial
	_attack_slide = not definition.ranged and &"shade_slide" in runes and _slide_buff_left > 0.0
	var flow_break := not definition.ranged and flow >= 35.0
	_attack_break_guard = flow_break or _attack_slide or (not definition.ranged and &"shade_wall" in runes and _wall_buff_left > 0.0)
	if flow_break:
		flow = maxf(0.0, flow - 35.0)
		_emit_flow()
	if not definition.ranged and &"shade_cleave_break" in runes and (attacks+1)%3==0:
		_attack_break_guard = true
	if not definition.ranged:
		_wall_buff_left = 0.0
		_slide_buff_left = 0.0
	if _attack_charged:
		charge_ready = false
		_charge_spent = true
	attacks += 1
	player.impact(.25)
	return true


func _physics_process(delta: float) -> void:
	if player.is_on_floor() and flow > 0.0:
		flow = move_toward(flow, 0.0, flow_decay_per_second * delta)
		_emit_flow()
	ability_cooldown = maxf(0.0,ability_cooldown-delta)
	parry_left = maxf(0.0,parry_left-delta)
	_slide_buff_left = maxf(0.0,_slide_buff_left-delta)
	attack_buffer = maxf(0.0,attack_buffer-delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	_wall_buff_left = maxf(0.0, _wall_buff_left-delta)
	_counter_left = maxf(0.0, _counter_left-delta)
	if _wall_buff_left <= 0.0:
		next_attack_multiplier = 1.0
	if not Input.is_action_pressed("attack"):
		_wait_release = false
	if not enabled or not player.control_enabled or health <= 0:
		cancel_attack()
		return
	if player.is_on_floor() or _airtime_serial != player.airtime_serial:
		_airtime_serial = player.airtime_serial
		charge_progress = 0.0
		charge_ready = false
		_charge_spent = false
		_tide_used = false
	elif &"arcane_charge" in runes and not _charge_spent and player.horizontal_speed() > 5.0:
		charge_progress = minf(charge_duration(), charge_progress+delta)
		charge_ready = charge_progress >= charge_duration()
	if Input.is_action_just_pressed("ability"):
		try_ability()
	if Input.is_action_just_pressed("attack"):
		attack_buffer = .18
	var held_cast: bool = arms.get_item_definition(&"right") != null and arms.get_item_definition(&"right").ranged
	if not _wait_release and (attack_buffer>0.0 or (held_cast and Input.is_action_pressed("attack"))):
		if try_attack():
			attack_buffer=0.0
	if not attacking:
		return
	if not is_instance_valid(_weapon) or arms.get_equipped_item(&"right") != _weapon:
		cancel_attack()
		return
	if impact_hold > 0.0:
		impact_hold = maxf(0.0, impact_hold - delta)
		return
	attack_age += delta
	if attack_age >= windup and not _swing_emitted:
		_swing_emitted = true
		if not arms.get_item_definition(&"right").ranged:
			echo_cuts.append({"time":Time.get_ticks_usec(), "origin":player.camera.global_position, "forward":-player.camera.global_basis.z, "reach":reach, "wide":_attack_slide})
			while echo_cuts.size() > 8: echo_cuts.pop_front()
		swing_started.emit()
		if arms.get_item_definition(&"right").ranged and not _projectile_fired:
			_fire_arcane_bolt(arms.get_item_definition(&"right"))
		elif &"shade_arc" in runes or riposte_ready or (_attack_slide and &"shade_slide_wind" in runes):
			_fire_blade_arc()
			riposte_ready=false
	if attack_age >= windup and attack_age < windup + active_time:
		if not arms.get_item_definition(&"right").ranged and attack_age>=windup+.05:
			_sample_hit()
	if attack_age >= duration():
		cancel_attack()


func duration() -> float:
	return windup + active_time + recovery_time


func _fire_arcane_bolt(definition: HeldItemDefinition) -> void:
	_projectile_fired = true
	var angles := PackedFloat32Array([-7.0,0.0,7.0]) if &"arcane_split" in runes else PackedFloat32Array([0.0])
	for angle: float in angles:
		var bolt := MagicBolt.new()
		bolt.friendly = true
		bolt.damage = maxi(1,roundi(_damage*(.6 if angles.size()>1 else 1.0)))
		bolt.speed = definition.projectile_speed
		bolt.owner_combat = self
		bolt.guard_piercing = _attack_charged or player.floating
		bolt.charged = _attack_charged
		bolt.chain_allowed = _attack_charged
		bolt.airtime_serial = _attack_airtime
		bolt.direction = (-player.camera.global_basis.z).rotated(player.camera.global_basis.y,deg_to_rad(angle))
		configure_spell(bolt)
		# Start at camera depth so a near wall cannot be skipped by a muzzle offset.
		player.get_tree().current_scene.add_child(bolt)
		bolt.global_position = player.camera.global_position
		bolt.visual_offset = arms.muzzle_world_position()-bolt.global_position

func configure_spell(bolt: MagicBolt) -> void:
	bolt.element = spell_element()
	bolt.blast_radius = (4.5 if &"arcane_fire_radius" in runes else (3.0 if &"arcane_fire" in runes else 2.5)) if (&"arcane_fire" in runes or (&"arcane_element" in runes and _primary_element == &"fire")) else 0.0
	bolt.frost_duration = (2.6 if &"arcane_ice_duration" in runes else 1.6) if &"arcane_ice" in runes else 0.0
	bolt.frost_nova = &"arcane_ice_nova" in runes
	bolt.fire_shatter = &"arcane_fire_shatter" in runes
	bolt.wind_force = &"arcane_float" in runes
	if _primary_element == &"lightning": bolt.chain_allowed = true
	arts.configure_spell(bolt)

func spell_element() -> StringName:
	return _primary_element

func spell_color() -> Color:
	return {&"fire":Color("#ed8246"),&"ice":Color("#87d6fa"),&"wind":Color("#b9e4ac"),&"lightning":Color("#8dcde8"),&"arcane":Color("#8debc8")}[spell_element()]

func _fire_blade_arc() -> void:
	var angles := [-5.0,5.0] if &"shade_arc_split" in runes else [0.0]
	for angle: float in angles:
		var bolt := MagicBolt.new()
		bolt.friendly = true
		bolt.element = &"blade"
		bolt.owner_combat = self
		bolt.damage = _damage
		bolt.speed = 32
		bolt.lifetime = (24.0 if &"shade_arc_range" in runes else 14.0)/bolt.speed
		bolt.chain_allowed = false
		bolt.direction = (-player.camera.global_basis.z).rotated(player.camera.global_basis.y,deg_to_rad(angle))
		get_tree().current_scene.add_child(bolt)
		bolt.global_position = player.camera.global_position
		if _attack_slide and &"shade_slide_wind" in runes:
			bolt.global_position.y = player.global_position.y+.5
			bolt.direction.y=0


func confirm_hit(target: LanternAcolyte, point: Vector3, defeated: bool, can_chain: bool = false, charged: bool = false, shot_airtime: int = -1) -> void:
	if not is_instance_valid(target): return
	if defeated and _confirmed_defeats.has(target.get_instance_id()): return
	if defeated: _confirmed_defeats[target.get_instance_id()] = true
	hits += 1
	if defeated:
		kills += 1
		if _attack_slide and attacking:
			_sweep_kills+=1
			if _sweep_kills>=2 and not _return_scheduled and &"shade_slide_return" in runes and not echo_cuts.is_empty():
				_return_scheduled=true
				var returning:=EchoSlash.new()
				returning.owner_combat=self
				returning.sweeps.append(echo_cuts.back().duplicate())
				returning._clock=.20
				get_tree().current_scene.add_child(returning)
				arts.performed.emit(&"sweep_return")
		if &"shade_refund" in runes and not player.is_on_floor():
			player.dash_available = true
		if &"shade_counter" in runes and _counter_left > 0.0:
			ability_cooldown = 0.0
			_counter_left = 0.0
		if &"shade_slide_chain" in runes and _attack_slide:
			_slide_buff_left = 2.0
	if charged and shot_airtime == player.airtime_serial and not player.is_on_floor() and not _tide_used:
		player.dash_available = true
		_tide_used = true
	# Distant spell impacts must not freeze an unrelated new casting gesture.
	impact_hold = (.052 if defeated else .038) if player.parkour_profile.id==&"shade" else 0.0
	var camera_impulse:float=1.0 if defeated else .65
	if player.parkour_profile.id==&"shade" and arms.get("tuning")!=null:
		var visual:Resource=arms.get("tuning")
		impact_hold=visual.blade_kill_stop if defeated else visual.blade_hit_stop
		camera_impulse*=visual.blade_camera_impulse
	player.impact(camera_impulse)
	hit_confirmed.emit(target,point,defeated)
	if can_chain and (&"arcane_charge" in runes or &"arcane_storm" in runes):
		var nearest: LanternAcolyte
		var distance: float = _chain_range
		for node: Node in get_tree().get_nodes_in_group("acolytes"):
			var other := node as LanternAcolyte
			if other == target or other.health<=0 or not other.active:
				continue
			var aim: Vector3 = other.get_hit_point()
			if point.distance_to(aim) >= distance:
				continue
			var ray := PhysicsRayQueryParameters3D.create(point,aim,5,[target.get_rid()])
			var contact: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
			if not contact.is_empty() and contact.collider == other:
				nearest = other
				distance = point.distance_to(aim)
		if nearest != null:
			var arc := MagicBolt.new()
			arc.friendly = true
			arc.chain_allowed = false
			arc.damage = maxi(1,roundi(_damage*.5))
			arc.speed = 40
			arc.owner_combat = self
			arc.element = &"lightning"
			arc.direction = (nearest.get_hit_point()-point).normalized()
			arc.ignore_target = target
			get_tree().current_scene.add_child(arc)
			arc.global_position = point
			chain_launched.emit(point,nearest,arc)


func _sample_hit() -> void:
	var origin: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	var sphere := SphereShape3D.new()
	var actual_reach: float=reach+(2.0 if &"shade_slide_wave" in runes and arts.slide_window>0 else 0.0)
	sphere.radius = actual_reach
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = origin
	query.collision_mask = 4
	var space := player.get_world_3d().direct_space_state
	for overlap: Dictionary in space.intersect_shape(query, 32):
		var target := overlap["collider"] as Node3D
		if target == null or not target.has_method("receive_hit") or _hit_ids.has(target.get_instance_id()):
			continue
		var aim: Vector3 = target.get_hit_point()
		var offset: Vector3 = aim - origin
		var sweeping: bool=&"shade_cleave" in runes or (&"shade_slide" in runes and arts.slide_window>0)
		if offset.length() > actual_reach or offset.normalized().dot(forward) < cos(deg_to_rad(85.0 if sweeping else 42.0)):
			continue
		# Environment AND other enemies occlude a hit; never strike through cover.
		var ray := PhysicsRayQueryParameters3D.create(origin, aim, 5)
		var contact: Dictionary = space.intersect_ray(ray)
		if contact.is_empty() or contact["collider"] != target:
			continue
		_hit_ids[target.get_instance_id()] = true
		if target is RunMechanism:
			target.receive_hit(_damage,forward)
			continue
		if target is LanternAcolyte and _attack_break_guard and target.threat_rank not in [&"miniboss",&"boss"]:
			target.break_guard(1.0)
		if not target.receive_hit(_damage, forward):
			blocked_hit.emit()
			player.impact(.45)
			continue
		if target is LanternAcolyte:
			var defeated: bool = target.health <= 0
			confirm_hit(target,contact["position"],defeated)


func receive_damage(amount: int) -> bool:
	var rewind := player.get_node_or_null("PositionRewind")
	if rewind != null and rewind.is_protected(): return false
	if not enabled or not player.control_enabled or get_tree().paused or health <= 0 or invulnerability > 0.0:
		return false
	var applied: int = 1 if amount>0 else 0
	if applied == 0:
		return false
	health -= applied
	damage_taken += applied
	invulnerability = 0.65
	hurt.emit(applied)
	if health == 0:
		cancel_attack()
		died.emit()
	return true

func try_ability() -> bool:
	if ability_cooldown>0.0 or not enabled or not player.control_enabled or get_tree().paused:
		return false
	if player.parkour_profile.id == &"shade":
		parry_left = .34 if &"shade_parry" in runes else .22
		ability_cooldown = .7
	else:
		ability_cooldown = 2.0 if &"arcane_power" in runes else 3.0
		var pulse_range: float = 14.0 if &"arcane_stride" in runes and _wall_buff_left > 0.0 else 8.0
		_wall_buff_left = 0.0
		for node in get_tree().get_nodes_in_group("acolytes"):
			var enemy := node as LanternAcolyte
			if not enemy.active or enemy.health<=0 or enemy.threat_rank in [&"boss",&"miniboss"]:
				continue
			var offset := enemy.get_hit_point()-player.camera.global_position
			if offset.length()>pulse_range or offset.normalized().dot(-player.camera.global_basis.z)<.55:
				continue
			var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,enemy.get_hit_point(),5)
			var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider==enemy:
				enemy.break_guard(3.0)
		ImpactBurst.spawn(get_tree().current_scene,player.camera.global_position-player.camera.global_basis.z*1.5,Color("#73eee8"))
	ability_used.emit()
	return true

func confirm_parry(enemy: LanternAcolyte) -> void:
	if not is_instance_valid(enemy) or not enabled or health <= 0: return
	last_parried_enemy=enemy
	if &"shade_duel_riposte" in runes: riposte_ready=true
	if is_instance_valid(enemy.brain): enemy.brain.interrupted()
	parry_left = 0.0
	invulnerability = .15
	if enemy.threat_rank not in [&"boss",&"miniboss"]:
		enemy.break_guard(3.0)
	if &"shade_parry" in runes:
		player.empowered_dash = true
		_counter_left = 3.0
	player.dash_available = true
	player.impact(.7)
	ImpactBurst.spawn(get_tree().current_scene,player.camera.global_position-player.camera.global_basis.z*1.2,Color("#eae0ae"),1.2)
	parried.emit()

func build_status() -> String:
	var flow_text := "流势 %.0f" % flow if flow > 0.5 else ""
	if player.floating:
		return flow_text + (" · " if not flow_text.is_empty() else "") + "漂浮 · %.1f" % player.float_left
	if charge_ready:
		return flow_text + (" · " if not flow_text.is_empty() else "") + "雷行 · 已充能"
	if &"arcane_charge" in runes and not _charge_spent:
		return "雷行 · %d%%" % roundi(charge_progress/charge_duration()*100)
	if _wall_buff_left > 0.0 and &"shade_wall" in runes:
		return "飞檐 · 破盾斩就绪"
	if _slide_buff_left > 0.0 and &"shade_slide" in runes:
		return "掠地 · 破盾斩就绪"
	if player.empowered_dash:
		return "返刃 · 突袭就绪"
	if player.float_capacity > 0.0:
		return "御风 · %.1f" % player.float_left
	if &"arcane_fire" in runes or &"arcane_ice" in runes:
		return "火 · 范围爆裂" if &"arcane_fire" in runes else "冰 · 冻结破盾"
	if &"shade_arc" in runes: return "离刃 · 远程剑气"
	if &"shade_cleave" in runes: return "断月 · 宽幅横扫"
	return flow_text

func charge_duration() -> float:
	return .45 if &"arcane_conduit" in runes else .7
