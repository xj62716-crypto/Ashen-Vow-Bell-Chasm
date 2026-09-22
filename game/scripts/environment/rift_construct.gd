class_name RiftConstruct
extends StaticBody3D

var kind: StringName=&"wall"
var lifetime: float=12
var owner_arts: ProfessionArts
var player: ParkourPlayer
var timer: float=0
var _title: Label3D
var _surface: ShaderMaterial
var _pulse: float=0
var _launch_lock: float=0
# Optional authored traction exit caps. Defaults retain forward continuation
# while leaving braking room on the receiving platform.
@export_range(8.0,24.0,.5) var grapple_exit_speed: float = 24.0
@export_range(0.0,6.0,.5) var grapple_exit_lift: float = 6.0
## Distance from the anchor at which the automatic route handoff happens.
## This is deliberately a route-entry shell, rather than the old anchor-center
## release. It leaves room for the player to carry speed into a landing, wall,
## slide or construct continuation.
@export_range(1.5,6.0,.25) var grapple_release_distance: float = 2.8
var permanent: bool=false
var _used: bool=false
signal expiring(construct: RiftConstruct)
signal expired(construct: RiftConstruct)
var _warning_sent: bool = false
var _grace_left: float = 1.5

static func dimensions(type: StringName) -> Vector3:
	return Vector3(.4,4.6,9) if type==&"wall" else (Vector3(4,.28,4) if type==&"platform" else Vector3(2.2,.28,2.2))

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	add_to_group("parkour_constructs")
	timer=lifetime
	_surface=ShaderMaterial.new()
	_surface.shader=preload("res://assets/shaders/rift_surface.gdshader")
	var collision := CollisionShape3D.new()
	if kind==&"anchor":
		collision_layer=4
		var sphere := SphereShape3D.new()
		sphere.radius=.48
		collision.shape=sphere
		DemoGeometry.sphere(self,Vector3.ZERO,.13,_surface)
		var iron := DemoGeometry.material(Color("#566b69"),.35)
		var ring := TorusMesh.new()
		ring.inner_radius=.25
		ring.outer_radius=.34
		var hoop := DemoGeometry.mesh(self,ring,Vector3.ZERO,iron)
		hoop.rotation.x=PI/2
		for side in [-1.0,1.0]:
			DemoGeometry.cylinder(self,Vector3(side*.30,-.22,0),.045,.55,iron)
	else:
		collision_layer=1
		var box := BoxShape3D.new()
		box.size=dimensions(kind)
		collision.shape=box
		DemoGeometry.box(self,Vector3.ZERO,box.size,_surface)
	add_child(collision)
	if kind==&"well":
		for i in range(5):
			var ring := TorusMesh.new()
			ring.inner_radius=.6+i*.06
			ring.outer_radius=ring.inner_radius+.035
			DemoGeometry.mesh(self,ring,Vector3.UP*(.3+i*.38),DemoGeometry.material(Color("#8ee6bf"),.7))
	_title=DemoGeometry.label(self,Vector3.UP*(2.6 if kind==&"wall" else 1.25),"",22)

func _hook_arrived(target: Node3D) -> void:
	if target!=self:return
	if not is_instance_valid(player):return
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	var arts: ProfessionArts = null
	if combat != null:
		arts = combat.arts as ProfessionArts
	if not _used and arts != null and arts.has(&"arcane_shape_refund"):arts.mana=minf(100,arts.mana+15)
	# Authored anchors can hand off to a real wall. The follow-up is expressed
	# as world-space plane data so it remains valid when a route section is
	# rotated or moved by the level builder.
	var followup: Variant = get_meta("followup_wall", {})
	if followup is Dictionary and followup.has("normal") and followup.has("point"):
		var normal: Vector3 = (followup["normal"] as Vector3).normalized()
		var point: Vector3 = followup["point"] as Vector3
		if normal.length_squared() > 0.5:
			player._same_wall_reattach_ready = true
			player._blocked_wall_normal = normal
			player._blocked_wall_plane_offset = normal.dot(point)
			player._wall_coyote_left = maxf(player._wall_coyote_left, player.wall_jump_grace)
			player._momentum_left = maxf(player._momentum_left, 0.65)
	_used=true

func get_hit_point() -> Vector3:
	return global_position

func receive_hit(_damage: int,_direction: Vector3) -> bool:
	return activate()

func activate() -> bool:
	if not is_instance_valid(player) or not player.control_enabled or get_tree().paused:
		return false
	if kind==&"anchor":
		if not player.grapple.traversed.is_connected(_hook_arrived):player.grapple.traversed.connect(_hook_arrived)
		return player.grapple.begin(self)
	return false

func _physics_process(delta: float) -> void:
	if not permanent:
		timer-=delta
		if timer <= 2.5 and not _warning_sent:
			_warning_sent = true
			expiring.emit(self)
		if timer<=0:
			if supporting_player() and _grace_left > 0:
				_grace_left -= delta
				return
			collision_layer = 0
			expired.emit(self)
			queue_free()
			return
	_launch_lock=maxf(0,_launch_lock-delta)
	if kind==&"wall" and not _used and is_instance_valid(player) and player.is_wall_running() and supporting_player():
		_used=true
		if is_instance_valid(owner_arts) and owner_arts.has(&"arcane_shape_refund"):owner_arts.mana=minf(100,owner_arts.mana+15)
	if kind==&"well" and is_instance_valid(player) and player.control_enabled and _launch_lock<=0:
		var offset := player.global_position-global_position
		if Vector2(offset.x,offset.z).length()<1.25 and offset.y>-.1 and offset.y<1.7:
			player.velocity=Vector3(player.velocity.x,15,player.velocity.z)
			player._ignore_floor_once=true
			player._momentum_left=1.0
			if not _used: player.dash_available=true
			_launch_lock=.8
			if not _used and is_instance_valid(owner_arts):owner_arts.mana=minf(100,owner_arts.mana+(15 if owner_arts.has(&"arcane_shape_refund") else 8))
			_used = true
	var word: String={&"wall":"裂隙壁",&"well":"上升风井",&"anchor":"E · 钩锁",&"platform":"悬空符台"}.get(kind,"构造")
	_title.text=word+("" if permanent else "  %.0fs" % timer)
	_surface.set_shader_parameter("warning",0.0 if permanent else float(timer<2.5)*(.5+.5*sin(timer*12)))

func supporting_player() -> bool:
	if not is_instance_valid(player): return false
	if kind == &"anchor": return player.grapple.active and player.grapple.anchor == self
	for index in range(player.get_slide_collision_count()):
		if player.get_slide_collision(index).get_collider() == self: return true
	return false
