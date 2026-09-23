class_name BossPhaseController
extends Node
## Three damage gates, not three larger HP bars. State is authoritative even
## when a legacy seal, parry, elemental stagger or multi-hit calls break_guard.
signal phase_changed(stage: int, state: StringName)
signal objective_broken(kind: StringName, remaining: int)
signal shield_changed(closed: bool, seconds: float)
signal mechanic_event(event: StringName, point: Vector3, seconds: float)
const FORGE_COUNTS := [3,4,5]
const WINDOWS := [9.0,7.5,6.0]
## Snapshot from the level's validated mechanism Resource; stages keep their ratios.
var exposure_window_seconds: float = 9.0
var actor: LanternAcolyte
var kind: StringName = &"forge"
var state: StringName = &"dormant"
var stage: int = 1
var state_left: float = 0.0
var arena: BossArena
var objectives: Array[BossObjective] = []
var effects: Array[Node3D] = []
var origin := Vector3.ZERO
var aerial: bool = false
var activated: bool = false
var _grace_left: float = 0.0
var _disposed: bool = false
var _control_lock: float = 0.0
var _route_target := Vector3.INF
var _route_reposition_left: float = 0.0
var _route_cursor: int = -1

static func install(enemy: LanternAcolyte, type: StringName, floor_body: StaticBody3D = null) -> BossPhaseController:
	if is_instance_valid(enemy.boss_controller): return enemy.boss_controller
	var controller := BossPhaseController.new()
	controller.name = "BossPhaseController"
	controller.actor = enemy
	controller.kind = type
	controller.origin = enemy.global_position
	enemy.boss_controller = controller
	enemy.add_child(controller)
	controller.arena = BossArena.new()
	controller.arena.controller = controller
	controller.arena.origin = controller.origin-Vector3.UP*.04
	enemy.get_parent().add_child(controller.arena)
	if type == &"priest":
		if floor_body == null: floor_body = controller.find_spawn_floor()
		if floor_body != null: controller.arena.bind_floor(floor_body)
	controller.reset_encounter()
	return controller

func find_spawn_floor() -> StaticBody3D:
	# Legacy and Resource-authored rooms both bind only the broad platform
	# directly under the final spawn, not an arbitrary nearby piece of scenery.
	for body in actor.get_parent().get_children():
		if not body is StaticBody3D: continue
		for child in body.get_children():
			if not child is CollisionShape3D or not child.shape is BoxShape3D: continue
			var size: Vector3 = child.shape.size
			var foot: Vector3 = child.to_local(actor.global_position)
			if size.x >= 8 and size.z >= 8 and size.y < 2 and absf(foot.x)<size.x*.5 and absf(foot.z)<size.z*.5 and absf(foot.y-size.y*.5)<.25:
				return body
	return null

func sync_spawn_transform() -> void:
	if state != &"dormant" or activated or actor.global_position.is_equal_approx(origin): return
	origin = actor.global_position
	arena.origin = origin-Vector3.UP*.04
	actor.brain.home = origin
	actor.brain.last_known = origin
	if kind == &"priest":
		arena.unbind_floor()
		var floor_body := find_spawn_floor()
		if floor_body != null: arena.bind_floor(floor_body)

func is_running() -> bool:
	return not _disposed and is_instance_valid(actor) and actor.active and actor.health > 0 and is_instance_valid(actor.player) and actor.player.control_enabled and not get_tree().paused

func _set_state(next: StringName, seconds: float = 0.0) -> void:
	state = next
	state_left = seconds
	actor.vulnerable = next == &"exposed"
	actor.guard_broken = actor.vulnerable
	actor._guard_time = 0
	phase_changed.emit(stage,state)
	shield_changed.emit(not actor.vulnerable,seconds)

func reset_encounter() -> void:
	_disposed = false
	_clear_objectives()
	_clear_effects()
	arena.clear_route()
	actor.global_position = origin
	actor.velocity = Vector3.ZERO
	actor.maximum_health = 3
	actor.health = 3
	aerial = false
	activated = false
	stage = 1
	_grace_left = 0
	_control_lock = 0
	_route_target = Vector3.INF
	_route_reposition_left = 0.0
	_route_cursor = -1
	if is_instance_valid(actor.brain): actor.brain.reset_state()
	_set_state(&"dormant")

func advance(delta: float) -> void:
	if not is_running(): return
	_control_lock = maxf(0,_control_lock-delta)
	_route_reposition_left = maxf(0.0,_route_reposition_left-delta)
	if state == &"dormant":
		# No arena-wide attacks or targets before a player actually approaches.
		if actor.player.global_position.distance_to(origin)>18 or not actor.brain.can_see(actor.player,false): return
		activated = true
		_enter_shield()
	if state == &"exposed":
		state_left = maxf(0,state_left-delta)
		actor._title.text = "%s · 核心暴露 %.1fs" % [actor._name(),state_left]
		if state_left <= 0: _enter_shield()
	elif state == &"terrain_warning":
		state_left = maxf(0,state_left-delta)
		actor._title.text = "地台即将崩塌 %.1fs · 跃入风井 / 牵引浮墙" % state_left
		if state_left <= 0:
			if not arena.collapse():
				# An externally removed floor is a configuration failure. Cancel the
				# encounter for retry rather than loop countdowns or delete other ground.
				mechanic_event.emit(&"arena_binding_failed",origin,0)
				cancel_encounter()
				return
			aerial = true
			stage = 2
			_grace_left = 1.8
			_enter_shield()
	elif state == &"shielded":
		actor._title.text = "%s · %d 阶段 · %s %d" % [actor._name(),stage,"熔炉核心" if kind==&"forge" else "束缚锁链",objectives.size()]
		_grace_left = maxf(0,_grace_left-delta)
	if state == &"shielded":
		_advance_route_motion(delta)

func _choose_route_target() -> void:
	if not is_instance_valid(arena) or arena.surfaces.is_empty() or not is_instance_valid(actor.player): return
	var player_position := actor.player.global_position
	var best_score := -INF
	var selected: BossOrbitSurface
	for index in range(arena.surfaces.size()):
		var surface := arena.surfaces[index]
		if not is_instance_valid(surface): continue
		# Prefer a route on the opposite side of the player. This makes the boss
		# contest the next traversal node instead of orbiting at the spawn point.
		var away := (surface.global_position-player_position).normalized()
		var score := surface.global_position.distance_to(player_position) + absf(surface.global_position.y-player_position.y)*.35
		if index == _route_cursor: score -= 3.0
		if away.dot((surface.global_position-origin).normalized()) < .15: score -= 1.0
		if score > best_score:
			best_score = score
			selected = surface
	if not is_instance_valid(selected): return
	_route_cursor = selected.route_index
	var inward := (origin-selected.global_position).normalized()
	_route_target = selected.global_position + inward*2.8 + Vector3.UP*.75
	_route_reposition_left = 2.6
	mechanic_event.emit(&"boss_reposition",_route_target,.35)

func _advance_route_motion(delta: float) -> void:
	# Isolated mechanics fixtures disable the actor's physics process and advance
	# the controller manually. Keep those API probes spatially deterministic;
	# live gameplay uses the actor process and therefore receives the full AI
	# relocation behaviour.
	if not actor.is_physics_processing(): return
	# The first shield teaches the high-wall contract with the boss readable in
	# the central bay. Later shields use the outer route as the boss's own
	# relocation language; this prevents the AI from stealing the first lesson's
	# only safe sightline while still making stage two and three dynamic.
	if stage == 1 and not aerial: return
	var brain := actor.brain as EnemyBrain
	# The attack windup belongs to the LanternAcolyte actor; recovery belongs to
	# its EnemyBrain. Keeping the ownership explicit avoids silently treating a
	# missing property as null and moving the boss during a committed attack.
	if not is_instance_valid(brain) or actor.windup >= 0.0 or brain.recovery_left > 0.0 or _grace_left > 0.0: return
	if not _route_target.is_finite() or _route_reposition_left <= 0.0:
		_choose_route_target()
	if not _route_target.is_finite(): return
	var destination := _route_target
	if aerial:
		# The aerial phase stays above the collapsed floor while still moving
		# between route nodes; it is not a teleport or a fixed hover in the centre.
		destination.y = maxf(destination.y,origin.y+2.4)
	var offset := destination-actor.global_position
	actor.velocity = offset.limit_length(5.2 if aerial else 3.8)
	actor.move_and_slide()

func may_attack() -> bool:
	return state == &"shielded" and _grace_left <= 0

func apply_control(seconds: float) -> bool:
	if not is_running() or _control_lock > 0 or state not in [&"shielded",&"exposed"]: return false
	_control_lock = 3.0
	actor.frozen_left = minf(.22,seconds)
	actor._stagger = .25
	actor.brain.interrupted()
	mechanic_event.emit(&"boss_stagger",actor.get_hit_point(),.25)
	return true

func objective_text() -> String:
	if state == &"terrain_warning": return "地台崩塌 · 借风井和符文锚转移至浮墙"
	if state == &"exposed": return "%s · 护盾已破，攻击本体" % actor._name()
	if state == &"defeated": return "%s · 已击败" % actor._name()
	return "%s · %d / 3 · 剩余%s %d" % [actor._name(),stage,"核心" if kind==&"forge" else "锁链",objectives.size()]

func can_break_objective(objective: BossObjective) -> bool:
	return is_running() and state == &"shielded" and objective in objectives

func _enter_shield() -> void:
	_clear_objectives()
	actor.cooldown = 1.25
	var count: int = FORGE_COUNTS[stage-1] if kind == &"forge" else (4 if stage==3 else 3)
	# Every shield phase is now a traversal phase. The targets live on moving
	# wall faces and broken decks at different elevations; the boss body remains
	# sealed until the player has physically reached and shattered all of them.
	arena.prepare_air_route()
	if arena.surfaces.size() < 6:
		mechanic_event.emit(&"arena_binding_failed",origin,0)
		cancel_encounter()
		return
	var route_heights := [1.05, 1.75, 1.2, 2.15, 1.35]
	for index in range(count):
		var objective := BossObjective.new()
		objective.controller = self
		objective.kind = &"core" if kind==&"forge" else &"chain"
		objective.ordinal = index
		var wall: BossOrbitSurface = arena.surfaces[index*6/count]
		objective.route_role = wall.route_role
		objective.route_index = wall.route_index
		wall.add_child(objective)
		# Keep each target on the readable attack face of its wall.  The extra
		# stand-off is deliberate: the wider wall must not occlude the projectile
		# or blade sweep before it reaches the core.
		objective.position = Vector3(0,route_heights[index%route_heights.size()],-.38)
		objective.set_meta("route_role",wall.route_role)
		objective.set_meta("route_index",wall.route_index)
		objectives.append(objective)
		objective.shattered.connect(_objective_shattered)
	_set_state(&"shielded")
	mechanic_event.emit(&"shield_raised",actor.get_hit_point(),0)

func _objective_position(index: int, count: int) -> Vector3:
	var nominal := TAU*index/count+float(stage-1)*.35
	var space := actor.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = .65
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 5
	for radius: float in [3.8,4.5,3.0]:
		for turn: float in [0.0,.18,-.18,.4,-.4,.65,-.65]:
			var angle := nominal+turn
			var point := origin+Vector3(sin(angle)*radius,1.05,cos(angle)*radius)
			var crowded := false
			for previous in objectives:
				if point.distance_to(previous.global_position)<1.5: crowded=true
			if crowded or not _supported_at(point-Vector3.UP*1.05): continue
			query.transform.origin = point
			if not space.intersect_shape(query,1).is_empty(): continue
			# A ranged ray alone is insufficient: an unupgraded blade must have at
			# least one supported, capsule-sized approach beside every objective.
			for side: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
				var foot := point-Vector3.UP*1.05+side*1.3
				if not _supported_at(foot): continue
				var capsule := CapsuleShape3D.new()
				capsule.radius = .4
				capsule.height = 1.8
				var approach := PhysicsShapeQueryParameters3D.new()
				approach.shape = capsule
				approach.transform.origin = foot+Vector3.UP*.96
				approach.collision_mask = 5
				if not space.intersect_shape(approach,1).is_empty(): continue
				var ray := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*1.4,point,1)
				if space.intersect_ray(ray).is_empty(): return point
	return Vector3.INF

func _supported_at(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.3,point-Vector3.UP*.3,1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and Vector3(hit.normal).y>.7

func _objective_shattered(objective: BossObjective) -> void:
	if not objective in objectives or state != &"shielded": return
	objectives.erase(objective)
	objective_broken.emit(objective.kind,objectives.size())
	mechanic_event.emit(&"core_break" if kind==&"forge" else &"chain_break",objective.global_position,0)
	if not objectives.is_empty(): return
	_clear_effects()
	actor.brain.interrupted()
	_set_state(&"exposed",exposure_window_seconds * WINDOWS[stage-1] / WINDOWS[0])
	actor.guard_opened.emit()
	mechanic_event.emit(&"shield_broken",actor.get_hit_point(),state_left)

func receive_hit(amount: int, _direction: Vector3) -> bool:
	if amount <= 0 or not is_running() or state != &"exposed": return false
	# Close the gate before notifications; a shotgun, DoT or replay cannot consume
	# two phases in a frame. Arbitrarily large damage still consumes one window.
	_set_state(&"transition")
	actor.health -= 1
	actor._flash = .18
	actor._stagger = .32
	actor._recoil = .24
	actor.velocity = Vector3.ZERO
	actor.brain.interrupted()
	_clear_effects()
	mechanic_event.emit(&"phase_hit",actor.get_hit_point(),.32)
	if actor.health <= 0:
		_set_state(&"defeated")
		arena.restore_floor()
		arena.surfaces_expiring.emit(3.0)
		state_left = 3.0
		actor._die()
		return true
	if kind == &"priest" and not aerial:
		_set_state(&"terrain_warning",4.0)
		arena.warn_collapse(4.0)
		mechanic_event.emit(&"terrain_warning",origin,4.0)
	else:
		stage += 1
		_grace_left = 1.5
		_enter_shield()
	return true

func attack_profile(sequence: int) -> Dictionary:
	var patterns: Array[StringName]
	if kind == &"forge":
		patterns = [&"forge_ground",&"low_wave"]
		if stage >= 2: patterns.append(&"forge_air")
		if stage == 3: patterns.append(&"forge_crossfire")
	else:
		patterns = [&"priest_ground",&"fan"] if not aerial else [&"priest_air",&"fan",&"priest_ground"]
	var selected := patterns[posmod(sequence,patterns.size())]
	# The low-level EnemyBrain keeps the readable windup/release/recovery
	# contract; this high-level choice adapts one out of every three attacks to
	# the player's current route instead of turning the fight into homing spam.
	if sequence % 3 == 0 and is_instance_valid(actor.player):
		var high_route := not actor.player.is_on_floor() or actor.player.is_wall_running() or actor.player.global_position.y > origin.y + 1.6
		if kind == &"forge" and high_route and patterns.has(&"forge_air"):
			selected = &"forge_air"
		elif kind == &"forge" and not high_route and patterns.has(&"forge_ground"):
			selected = &"forge_ground"
		elif kind == &"priest" and high_route and patterns.has(&"priest_air"):
			selected = &"priest_air"
		elif kind == &"priest" and not high_route and patterns.has(&"priest_ground"):
			selected = &"priest_ground"
	return {"kind":selected,"windup":1.25-.12*(stage-1),"recovery":1.05-.1*(stage-1),"cooldown":1.25-.22*(stage-1),"tail":3.5}

func release_attack(attack: StringName, point: Vector3) -> bool:
	if not attack in [&"forge_ground",&"forge_air",&"forge_crossfire",&"priest_ground",&"priest_air"]: return false
	if not may_attack(): return true
	var radius := 1.55+.25*stage
	if attack in [&"forge_ground",&"priest_ground",&"forge_crossfire"]:
		_ground_hazard(point,radius,1.0)
		if stage>=2:
			# Fixed additional spots, not an unescapable carpet following the player.
			_ground_hazard(origin+Vector3(3.8,1,0),1.7,1.35)
	if attack in [&"forge_air",&"priest_air",&"forge_crossfire"]:
		var air_point := point
		air_point.y = maxf(origin.y+3.0,point.y)
		_hazard(air_point,&"air",radius,1.25 if attack==&"forge_crossfire" else .95)
	return true

func _ground_hazard(point: Vector3, radius: float, delay: float) -> void:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*9,1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and Vector3(hit.normal).y > .65:
		_hazard(hit.position+Vector3.UP*.025,&"ground",radius,delay)

func _hazard(point: Vector3, type: StringName, radius: float, delay: float) -> void:
	var hazard := BossHazard.new()
	hazard.controller = self
	hazard.kind = type
	hazard.radius = radius
	hazard.delay = delay
	arena.add_child(hazard)
	hazard.global_position = point
	track_effect(hazard)
	mechanic_event.emit(&"ground_aoe" if type==&"ground" else &"air_aoe",point,delay)

func track_effect(effect: Node3D) -> void:
	for index in range(effects.size()-1,-1,-1):
		if not is_instance_valid(effects[index]) or effects[index].is_queued_for_deletion(): effects.remove_at(index)
	effects.append(effect)

func _clear_effects() -> void:
	for effect in effects:
		if is_instance_valid(effect):
			effect.set_physics_process(false)
			effect.queue_free()
	effects.clear()
	if is_instance_valid(actor.brain) and is_instance_valid(actor.brain.director): actor.brain.director.release(actor)

func _clear_objectives() -> void:
	for objective in objectives:
		if is_instance_valid(objective):
			objective.collision_layer = 0
			objective.queue_free()
	objectives.clear()

func cancel_encounter() -> void:
	_clear_effects()
	_clear_objectives()
	arena.clear_route()
	actor.brain.interrupted()
	_set_state(&"cancelled")

func _physics_process(delta: float) -> void:
	if state != &"defeated": return
	state_left = maxf(0,state_left-delta)
	if state_left <= 0: arena.clear_route()

func _exit_tree() -> void:
	_disposed = true
	_clear_objectives()
	_clear_effects()
	if is_instance_valid(arena):
		arena.clear_route()
		arena.queue_free()
