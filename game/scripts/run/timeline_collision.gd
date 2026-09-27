extends RefCounted
## Query destination-phase solids without enabling them, advancing time, or
## moving the player. Disabled bodies are absent from direct-space queries.

static func phase_of(node: Node) -> StringName:
	var cursor := node
	while cursor != null:
		if cursor.has_meta("timeline_phase"):
			return StringName(cursor.get_meta("timeline_phase"))
		cursor = cursor.get_parent()
	return &""

static func active(node: Node) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree(): return false
	var required: Array[StringName] = []
	var cursor := node
	var room: CombatRoom
	while cursor != null:
		if cursor.has_meta("timeline_phase"): required.append(StringName(cursor.get_meta("timeline_phase")))
		if cursor is CombatRoom:
			room = cursor
			break
		cursor = cursor.get_parent()
	if room == null:
		var scene := node.get_tree().current_scene
		if scene is MovementTrial: room = scene.combat_room
	if room == null: return required.is_empty()
	if not room.enabled: return false
	for phase in required:
		if phase != room.timeline_phase: return false
	return true

static func capture_phase(effect: Node, source: Node = null) -> void:
	# A projectile keeps the world in which it was committed, even when its
	# caster later crosses over. Shared enemies also fire into their current world.
	if effect.has_meta("timeline_phase"): return
	var phase := phase_of(source) if is_instance_valid(source) else &""
	if phase == &"" and effect.is_inside_tree():
		var scene := effect.get_tree().current_scene
		if scene is MovementTrial and is_instance_valid(scene.combat_room):phase=scene.combat_room.timeline_phase
	if phase != &"":effect.set_meta("timeline_phase",phase)

static func cancel_if_inactive(effect: Node3D) -> bool:
	if active(effect):return false
	effect.hide()
	effect.set_physics_process(false)
	effect.queue_free()
	return true

static func can_enter(player: ParkourPlayer, geometry: Node3D, target: StringName) -> bool:
	var capsule := player.body_shape.shape as CapsuleShape3D
	if capsule == null: return false
	var transform := player.body_shape.global_transform
	var radius := capsule.radius * maxf(transform.basis.x.length(),transform.basis.z.length())
	var half_axis := maxf(0.0,capsule.height*.5-capsule.radius)
	var a := transform*Vector3(0,-half_axis,0)
	var b := transform*Vector3(0,half_axis,0)
	for shape: CollisionShape3D in geometry.find_children("*","CollisionShape3D",true,false):
		if shape.shape == null or phase_of(shape) != target: continue
		var body := shape.get_parent() as CollisionObject3D
		if body == null or body is Area3D or not (body.collision_layer & player.collision_mask): continue
		# Already active collision is handled by ordinary movement. Only reject
		# a solid which this transaction would introduce around the capsule.
		if not shape.disabled: continue
		var bounds: AABB
		if shape.shape is BoxShape3D:
			var size: Vector3 = shape.shape.size
			bounds = AABB(-size*.5,size)
		elif shape.shape is SphereShape3D:
			var size: Vector3 = Vector3.ONE*shape.shape.radius*2.0
			bounds = AABB(-size*.5,size)
		else:
			# Authored timeline terrain is boxed masonry; other shapes receive a
			# conservative rejection rather than permitting an unverified overlap.
			bounds = shape.shape.get_debug_mesh().get_aabb()
		var inverse := shape.global_transform.affine_inverse()
		var local_a := inverse*a
		var local_b := inverse*b
		var scale_value := shape.global_basis.get_scale().abs()
		var local_radius := maxf(0.0,radius-.025)/minf(scale_value.x,minf(scale_value.y,scale_value.z))
		if _segment_box_distance_squared(local_a,local_b,bounds) < local_radius*local_radius:
			return false
	return true

static func _point_box_distance_squared(point: Vector3, box: AABB) -> float:
	return point.distance_squared_to(point.clamp(box.position,box.end))

static func _segment_box_distance_squared(a: Vector3, b: Vector3, box: AABB) -> float:
	# Squared distance to a convex set is convex along a line segment. This
	# bounded search handles tilted masonry as well as upright walls/floors.
	var low := 0.0
	var high := 1.0
	for iteration in 24:
		var left := lerpf(low,high,1.0/3.0)
		var right := lerpf(low,high,2.0/3.0)
		if _point_box_distance_squared(a.lerp(b,left),box) < _point_box_distance_squared(a.lerp(b,right),box):
			high = right
		else:
			low = left
	return minf(_point_box_distance_squared(a,box),minf(_point_box_distance_squared(b,box),_point_box_distance_squared(a.lerp(b,(low+high)*.5),box)))
