class_name EnemyBrain
extends Node
## Six roles share perception and commitment rules, not one shooting routine.
signal state_changed(previous: StringName, current: StringName)
signal attack_committed(kind: StringName, point: Vector3, seconds: float)
signal attack_released(kind: StringName, point: Vector3)
signal target_changed(target: Node3D)
const ROLES := [&"pursuer", &"heavy", &"crossbow", &"caster", &"bell", &"sentinel"]
var actor: LanternAcolyte
var role: StringName = &"crossbow"
var rank: StringName = &"normal"
var state: StringName = &"idle"
var target: Node3D
var attack_target: Node3D
var last_known := Vector3.ZERO
var home := Vector3.ZERO
var memory_left: float = 0.0
var recovery_left: float = 0.0
var search_left: float = 0.0
var attack_kind: StringName = &"bolt"
var attack_duration: float = .85
var director: EncounterDirector
var anchor: BellAnchor
var anchor_cooldown: float = 0
var _sound_clock: float = 0
var _pattern: int = 0
var pending_effects: Array[Node3D] = []

func _ready() -> void:
	actor = get_parent() as LanternAcolyte
	home = actor.global_position
	last_known = home
	director = EncounterDirector.obtain(get_tree().current_scene if get_tree().current_scene != null else get_tree().root)
	configure(actor.role, actor.threat_rank)

func configure(new_role: StringName, new_rank: StringName) -> void:
	role = new_role if new_role in ROLES else &"crossbow"
	rank = new_rank
	reset_state()

func reset_state() -> void:
	for effect in pending_effects:
		if is_instance_valid(effect):
			effect.set_physics_process(false)
			effect.queue_free()
	pending_effects.clear()
	target = null
	attack_target = null
	memory_left = 0
	recovery_left = 0
	search_left = 0
	_pattern = 0
	anchor_cooldown = .2
	if is_instance_valid(anchor): anchor.queue_free()
	anchor = null
	if is_instance_valid(director): director.release(actor)
	_set_state(&"idle")

func _set_state(next: StringName) -> void:
	if state == next: return
	var before := state
	state = next
	state_changed.emit(before, state)

func point_of(body: Node3D) -> Vector3:
	return body.get_hit_point() if body.has_method("get_hit_point") else body.global_position+Vector3.UP*1.15

func can_see(body: Node3D, fov: bool = true) -> bool:
	if not is_instance_valid(body) or body.is_queued_for_deletion(): return false
	if body is EchoDecoy and not body.is_targetable(actor): return false
	var offset := point_of(body)-actor.get_hit_point()
	if offset.length() > actor.attack_range+8: return false
	if fov and offset.length() > 3 and memory_left <= 0 and offset.normalized().dot(actor._visual.global_basis.z) < -.15: return false
	var ray := PhysicsRayQueryParameters3D.create(actor.get_hit_point(),point_of(body),3,[actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.get("collider") == body

func hear(point: Vector3, loudness: float = 9) -> void:
	if actor.global_position.distance_to(point) > loudness or is_instance_valid(target): return
	last_known = point
	memory_left = 2.0
	_set_state(&"search")

func _perceive(delta: float) -> void:
	memory_left = maxf(0, memory_left-delta)
	var seen: Node3D
	# A visible decoy is plausible and deliberately steals *new* targeting. A
	# committed attack keeps its original target and stops turning near release.
	for decoy: Node in get_tree().get_nodes_in_group("echo_decoys"):
		if decoy.owner_player == actor.player and can_see(decoy):
			seen = decoy
			break
	if seen == null and can_see(actor.player): seen = actor.player
	if seen != target:
		target = seen
		target_changed.emit(target)
	if target != null:
		last_known = target.global_position
		memory_left = 2.5
	_sound_clock -= delta
	if _sound_clock <= 0:
		_sound_clock = .4
		var combat := actor.player.get_node("Combat") as PlayerCombat
		if actor.player.horizontal_speed() > 7 or combat.attacking: hear(actor.player.global_position, 11 if combat.attacking else 7)

func advance(delta: float) -> void:
	_perceive(delta)
	anchor_cooldown = maxf(0,anchor_cooldown-delta)
	if role == &"bell" and anchor_cooldown <= 0 and not is_instance_valid(anchor) and actor._guard_time <= 0:
		_spawn_anchor()
	if recovery_left > 0:
		recovery_left = maxf(0,recovery_left-delta)
		_set_state(&"recovery")
		_move(Vector3.ZERO,delta)
		# Keep the lease until its world-time expiry: a projectile or ritual may
		# still be travelling after the shooter's own recovery has finished.
		return
	if actor.windup >= 0:
		_advance_attack(delta)
		return
	actor.cooldown -= delta
	if target == null:
		_set_state(&"search" if memory_left > 0 else &"return")
		var destination := last_known if memory_left > 0 else home
		_steer(destination,delta,2.3)
		return
	_set_state(&"alert")
	var delta_target := point_of(target)-actor.get_hit_point()
	var distance := delta_target.length()
	actor._visual.rotation.y = rotate_toward(actor._visual.rotation.y,atan2(delta_target.x,delta_target.z),delta*(1.8 if role == &"heavy" else 3.0))
	var reach := 3.8 if role in [&"pursuer",&"heavy"] else actor.attack_range
	if role == &"sentinel": reach = 16
	if distance <= reach and actor.cooldown <= 0:
		if _begin_attack(): return
	if role in [&"pursuer",&"heavy"]:
		# Ground units defend a supported landing when the player is well above
		# them. They neither climb the player's wall nor collect under its centre.
		var intercept := target.global_position
		if absf(target.global_position.y-actor.global_position.y)>2.4:
			var side := -1.0 if actor.get_instance_id()%2==0 else 1.0
			intercept=home+Vector3(side*1.4,0,1.4)
			if not _supported(intercept):intercept=home
		_steer(intercept,delta,4.5 if role==&"pursuer" else 2.3)
	elif role == &"sentinel":
		var perch := home+Vector3(sin(float(_pattern)*1.7)*2,1.6,0)
		_move((perch-actor.global_position).limit_length(3.5),delta)
	elif distance < 5 and role in [&"crossbow",&"caster"]:
		_steer(actor.global_position-delta_target.normalized()*2,delta,2.0)
	else: _move(Vector3.ZERO,delta)

func _begin_attack() -> bool:
	if not is_instance_valid(target): return false
	if is_instance_valid(actor.boss_controller) and not actor.boss_controller.may_attack(): return false
	var major := role != &"crossbow"
	attack_duration = .75 if role == &"pursuer" else 1.0
	var threat_tail:=maxf(1.0,point_of(target).distance_to(actor.get_hit_point())/10.0+.25) if role==&"crossbow" else 1.3
	if is_instance_valid(actor.boss_controller):
		var profile := actor.boss_controller.attack_profile(_pattern)
		attack_duration = profile.windup
		threat_tail = profile.tail
		major = true
	if not director.claim(actor,major,attack_duration+threat_tail): return false
	attack_target = target
	actor.locked_target = point_of(target)
	actor.windup = attack_duration
	attack_kind = {&"pursuer":&"lunge",&"heavy":&"high_sweep",&"crossbow":&"bolt",&"caster":&"ritual",&"bell":&"seal_lane",&"sentinel":&"dive"}[role]
	if role == &"heavy" and _pattern%2 == 1: attack_kind=&"bash"
	if role == &"caster" and _pattern%2 == 1: attack_kind=&"fan"
	if role == &"sentinel" and _pattern%2 == 1: attack_kind=&"bolt"
	if rank==&"elite" and _pattern%2==1:
		if role==&"crossbow":attack_kind=&"fan"
		elif role==&"pursuer":attack_kind=&"high_sweep"
		elif role==&"bell":attack_kind=&"fan"
	if rank in [&"miniboss",&"boss"]:
		attack_kind = [&"ritual",&"low_wave",&"fan",&"high_wave"][posmod(_pattern+(actor.maximum_health-actor.health),4)]
	if is_instance_valid(actor.boss_controller): attack_kind = actor.boss_controller.attack_profile(_pattern).kind
	_set_state(&"windup")
	attack_committed.emit(attack_kind,actor.locked_target,attack_duration)
	return true

func _advance_attack(delta: float) -> void:
	actor.windup -= delta
	if actor.windup > .30 and is_instance_valid(attack_target) and can_see(attack_target,false):
		actor.locked_target = point_of(attack_target)
	var line := actor.locked_target-actor.get_hit_point()
	if line.length() > .01:
		actor._beam.visible = true
		actor._beam.global_transform = Transform3D(Basis.looking_at(line.normalized()).scaled(Vector3(.018,.018,line.length())),actor.get_hit_point()+line*.5)
	var title: String = {&"lunge":"突进斩",&"bash":"盾击",&"high_sweep":"高位横扫",&"bolt":"弩矢",&"ritual":"焚火法阵",&"seal_lane":"缚路铃阵",&"dive":"俯冲",&"fan":"扇形咒火",&"low_wave":"地脉波",&"high_wave":"高环",&"forge_ground":"熔火地印",&"forge_air":"焚空咒球",&"forge_crossfire":"天地交焚",&"priest_ground":"枯亡地印",&"priest_air":"空域葬印"}.get(attack_kind,"攻击")
	actor._title.text = title+(" · 蓄势" if actor.windup > .30 else " · 已锁定")
	# Tracking ends for the final 0.30 world seconds, including during focus.
	if actor.windup > .30:
		actor._visual.rotation.y = rotate_toward(actor._visual.rotation.y,atan2(line.x,line.z),delta*2.5)
	if attack_kind==&"dive" and actor.windup<=.30 and line.length()>1.8:
		_move(line.normalized()*18,delta)
	else:
		_move(Vector3.ZERO,delta)
	if actor.windup > 0: return
	_release_attack()

func _release_attack() -> void:
	_pattern += 1
	actor._volleys += 1
	actor.windup = -1
	actor._beam.hide()
	attack_released.emit(attack_kind,actor.locked_target)
	match attack_kind:
		&"forge_ground",&"forge_air",&"forge_crossfire",&"priest_ground",&"priest_air":
			if is_instance_valid(actor.boss_controller): actor.boss_controller.release_attack(attack_kind,actor.locked_target)
		&"lunge", &"bash", &"high_sweep", &"dive": _melee()
		&"ritual", &"seal_lane":
			var hazard := EnemyHazard.new()
			hazard.player = actor.player
			hazard.radius = 2.1 if attack_kind==&"ritual" else 1.7
			hazard.position = actor.get_parent().to_local(actor.locked_target-Vector3.UP*1.15)
			actor.get_parent().add_child(hazard)
			_track_effect(hazard)
		&"low_wave",&"high_wave":
			var wave := SweepWave.new()
			wave.player=actor.player
			wave.high=attack_kind==&"high_wave"
			wave.position=actor.position
			actor.get_parent().add_child(wave)
			_track_effect(wave)
		_:
			var spread: Array = [-16.0,0.0,16.0] if attack_kind==&"fan" else [0.0]
			for angle: float in spread:
				var bolt := MagicBolt.new()
				bolt.source_enemy=actor
				bolt.damage=1
				bolt.direction=(actor.locked_target-actor.get_hit_point()).normalized().rotated(Vector3.UP,deg_to_rad(angle))
				actor.get_parent().add_child(bolt)
				bolt.global_position=actor.get_hit_point()
				_track_effect(bolt)
	recovery_left = 1.1 if role in [&"heavy",&"sentinel"] else .8
	actor.cooldown = .35 if rank==&"elite" else actor.shot_cooldown
	if role in [&"heavy",&"caster",&"sentinel"] or rank==&"elite": actor.break_guard(recovery_left+.25)
	if rank in [&"miniboss",&"boss"] and _pattern%2==0: actor.break_guard(2.5)
	if is_instance_valid(actor.boss_controller):
		var profile := actor.boss_controller.attack_profile(_pattern)
		recovery_left = profile.recovery
		actor.cooldown = profile.cooldown
	actor.fired.emit()
	_set_state(&"recovery")

func _melee() -> void:
	var offset := actor.locked_target-actor.get_hit_point()
	var flat := Vector3(offset.x,0,offset.z).normalized()
	if attack_kind in [&"lunge",&"dive"]:
		# Collision-tested committed advance; no teleport through walls or ledges.
		var advance := flat*minf(2.2,maxf(0,offset.length()-1.3))
		if _supported(actor.global_position+advance): actor.move_and_collide(advance)
	if not is_instance_valid(attack_target): return
	var actual := point_of(attack_target)-actor.get_hit_point()
	if actual.length() > (3.5 if attack_kind==&"high_sweep" else 2.8) or actual.normalized().dot(flat) < .45 or not can_see(attack_target,false): return
	if attack_target is ParkourPlayer:
		if attack_kind==&"high_sweep" and attack_target.crouched: return
		var combat := attack_target.get_node("Combat") as PlayerCombat
		if combat.parry_left>0: combat.confirm_parry(actor)
		else: combat.receive_damage(1)
	elif attack_target is EchoDecoy: attack_target.receive_hit(1,flat)

func _supported(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.6,point-Vector3.UP*1.2,1,[actor.get_rid()])
	return not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _steer(destination: Vector3, delta: float, speed: float) -> void:
	var offset := destination-actor.global_position
	offset.y=0
	var direction := offset.normalized() if offset.length() > 1.6 else Vector3.ZERO
	# Local avoidance only: use supported alternate steps around nearby cover and
	# actors. Never invent a cross-platform navigation route or track through cover.
	if direction != Vector3.ZERO:
		var desired := direction
		direction = Vector3.ZERO
		var best := -INF
		for angle in [0.0,.65,-.65,1.2,-1.2]:
			var candidate: Vector3 = desired.rotated(Vector3.UP,angle)
			if not _supported(actor.global_position+candidate*1.25): continue
			var query := PhysicsShapeQueryParameters3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = .48*actor._size
			capsule.height = 1.8*actor._size
			query.shape = capsule
			query.transform.origin = actor.global_position+candidate*1.0+Vector3.UP*(.96*actor._size)
			query.collision_mask = 5
			query.exclude = [actor.get_rid()]
			if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
			var score := candidate.dot(desired)
			if score > best:
				best = score
				direction = candidate
	_move(direction*speed,delta)

func _move(wish: Vector3, delta: float) -> void:
	if is_instance_valid(actor.boss_controller):
		# Boss locomotion belongs to the encounter controller, including hovering.
		return
	actor.velocity.x=move_toward(actor.velocity.x,wish.x,delta*18)
	actor.velocity.z=move_toward(actor.velocity.z,wish.z,delta*18)
	actor.velocity.y=move_toward(actor.velocity.y,wish.y,delta*8) if role==&"sentinel" else actor.velocity.y-26*delta
	actor.move_and_slide()

func _spawn_anchor() -> void:
	anchor_cooldown=8
	anchor=BellAnchor.new()
	anchor.owner_enemy=actor
	actor.get_parent().add_child(anchor)
	anchor.global_position=actor.global_position+Vector3(1.5,1.0,0)

func interrupted() -> void:
	actor.windup=-1
	actor._beam.hide()
	attack_target=null
	recovery_left=maxf(recovery_left,.65)
	_prune_effects()
	if is_instance_valid(director) and pending_effects.is_empty(): director.release(actor)
	_set_state(&"stagger")

func _track_effect(effect: Node3D) -> void:
	_prune_effects()
	pending_effects.append(effect)
	if is_instance_valid(actor.boss_controller): actor.boss_controller.track_effect(effect)

func _prune_effects() -> void:
	for index in range(pending_effects.size()-1,-1,-1):
		if not is_instance_valid(pending_effects[index]) or pending_effects[index].is_queued_for_deletion(): pending_effects.remove_at(index)

func _exit_tree() -> void:
	for effect in pending_effects:
		if is_instance_valid(effect):
			effect.set_physics_process(false)
			effect.queue_free()
	if is_instance_valid(director) and is_instance_valid(actor): director.release(actor)
	if is_instance_valid(anchor): anchor.queue_free()
