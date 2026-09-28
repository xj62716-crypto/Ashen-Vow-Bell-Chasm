extends SceneTree
## r6 source-level integration contract: phase shifting changes authored route
## collision and atmosphere while preserving player motion state.

var checks := 0
var failures := 0
var trial: MovementTrial

func _initialize() -> void:
	_run.call_deferred()

func step(count: int = 1) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("PASS " if value else "FAIL ", label)

func _timeline_root() -> Node:
	for node: Node in trial.combat_room.geometry.find_children("*", "Node", true, false):
		if node.has_meta("timeline_phase") and StringName(node.get_meta("timeline_phase")) == &"remnant":
			return node
	return null

func _run() -> void:
	trial = load("res://scenes/levels/causeway.tscn").instantiate() as MovementTrial
	root.add_child(trial)
	current_scene = trial
	await step(8)
	trial.start_run()
	await step(8)
	var runtime := trial.timeline_runtime
	check(is_instance_valid(runtime), "formal scene owns one timeline runtime")
	check(runtime.phase == &"present" and runtime.charges == runtime.maximum_charges, "fresh run starts in present with full phase charges")
	var remnant := _timeline_root()
	check(is_instance_valid(remnant) and not remnant.visible, "remnant route surface is hidden in present")
	var remnant_shapes := remnant.find_children("*", "CollisionShape3D", true, false)
	check(remnant_shapes.size() > 0 and (remnant_shapes[0] as CollisionShape3D).disabled, "hidden remnant route has no active collision")
	var remnant_anchor: RiftConstruct = null
	for candidate: RiftConstruct in trial.combat_room.static_anchors:
		if candidate.has_meta("timeline_phase") and candidate.get_meta("timeline_phase") == &"remnant":
			remnant_anchor = candidate
			break
	check(is_instance_valid(remnant_anchor) and not trial.player.grapple.target_phase_active(remnant_anchor), "present phase rejects only the explicitly inactive remnant anchor")
	var player := trial.player
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 5.0)))
	player.velocity = Vector3(3.0, 7.0, -11.0)
	player._ignore_floor_once = true
	await step(1)
	var before_position := player.global_position
	var before_velocity := player.velocity
	check(runtime.try_shift(), "airborne player can shift timeline with one press")
	check(player.global_position.distance_to(before_position) < 0.001 and player.velocity.distance_to(before_velocity) < 0.001, "timeline shift preserves position and velocity at handoff")
	await step(2)
	check(runtime.phase == &"remnant" and runtime.charges == runtime.maximum_charges - 1, "shift consumes only phase resource")
	# Two physics frames advance the runner under the authored velocity. The
	# contract rejects a teleport or velocity replacement while allowing that
	# bounded physical travel.
	check(player.global_position.distance_to(before_position) < 2.0 and player.velocity.distance_to(before_velocity) < 8.0, "timeline shift does not teleport or replace player motion")
	check(remnant.visible and not (remnant_shapes[0] as CollisionShape3D).disabled, "remnant route surface becomes visible and collidable")
	check(trial.player.grapple.target_phase_active(remnant_anchor), "remnant shift activates its authored grapple anchor")
	var enemy: Node = null
	for node: Node in trial.combat_room.enemies:
		if node.has_meta("phase_route_node"):
			enemy = node
			break
	check(enemy != null and enemy.visible, "remnant route enemy appears with its timeline")
	runtime.refund(1)
	await step(2)
	check(runtime.charges == runtime.maximum_charges, "movement/kill refund can restore phase charge without exceeding cap")
	# Keep the second half focused on the phase contract even if the first
	# authored launch has reached its recovery line in a headless run.
	trial.phase = MovementTrial.Phase.RUNNING
	player.control_enabled = true
	player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(0,2.0,-50)))
	player.velocity = Vector3(-2.0, 0.0, 9.0)
	runtime.cooldown_left = 0.0
	await step(1)
	check(runtime.try_shift(), "second shift returns to present after cooldown")
	await step(2)
	check(runtime.phase == &"present" and not remnant.visible and (remnant_shapes[0] as CollisionShape3D).disabled, "returning to present removes remnant collision")
	await collision_cache_regressions()
	trial.queue_free()
	await step(3)
	print("RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func collision_cache_regressions() -> void:
	var room := trial.combat_room
	var holder := Node3D.new()
	holder.set_meta("timeline_phase", &"remnant")
	holder.position = Vector3(0, 200, 0)
	room.geometry.add_child(holder)
	var body := StaticBody3D.new()
	holder.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	await step(2)
	check(shape.disabled and body.collision_layer == 0, "cached reconciliation registers newly spawned nested inactive collision")
	room.apply_timeline_phase(&"remnant")
	await step(2)
	check(not shape.disabled and body.collision_layer == 1, "spawned nested wall becomes solid in its owning phase")
	body.set_meta("gameplay_hidden", true)
	await step(2)
	check(shape.disabled and body.collision_layer == 0 and not body.visible, "cached owner respects dynamic collapse without restoring an invisible floor")
	body.set_meta("gameplay_hidden", false)
	await step(2)
	check(not shape.disabled and body.collision_layer == 1 and body.visible, "restored floor updates cached collision on the next physics tick")
	shape.set_meta("gameplay_disabled", true)
	await step(2)
	check(shape.disabled and body.collision_layer == 0, "opened mechanism remains collision-free during cached reconciliation")
	shape.set_meta("gameplay_disabled", false)
	await step(2)
	var present_shape := CollisionShape3D.new()
	present_shape.shape = BoxShape3D.new()
	present_shape.position = Vector3(3, 0, 0)
	present_shape.set_meta("timeline_phase", &"present")
	body.add_child(present_shape)
	room.apply_timeline_phase(&"present")
	await step(2)
	check(shape.disabled and not present_shape.disabled and body.collision_layer == 1, "multi-shape owner stays active for its present shape while remnant shape is disabled")
	room.apply_timeline_phase(&"remnant")
	await step(2)
	check(not shape.disabled and present_shape.disabled and body.collision_layer == 1, "multi-shape owner swaps active collision without traversal-order dependency")
	var body_id := body.get_instance_id()
	holder.free()
	await step(2)
	var evicted := true
	for cached: CollisionObject3D in room._timeline_collision_owners:
		if not is_instance_valid(cached) or cached.get_instance_id() == body_id:
			evicted = false
	check(evicted, "removed collision owner is evicted from cached reconciliation")
	room.apply_timeline_phase(&"present")
