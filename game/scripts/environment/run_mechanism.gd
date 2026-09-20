class_name RunMechanism
extends StaticBody3D
signal activated
@export var tuning: LevelMechanismTuning=preload("res://scenes/levels/config/default_mechanisms.tres")
var _tuning: LevelMechanismTuning
var kind: StringName = &"seal"
var used: bool = false
var player: ParkourPlayer
var core: MeshInstance3D
var _cooldown: float = 0.0

func _ready() -> void:
	var errors := tuning.validation_errors() if tuning!=null else PackedStringArray(["tuning: missing resource"])
	if not errors.is_empty():
		push_error("RunMechanism: "+str(errors))
		process_mode=Node.PROCESS_MODE_DISABLED
		return
	_tuning=tuning.duplicate(true) as LevelMechanismTuning
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .55
	shape.shape = sphere
	add_child(shape)
	core = DemoGeometry.sphere(self,Vector3.ZERO,.35,DemoGeometry.material(Color("#70ece1"),1.6))
	DemoGeometry.cylinder(self,Vector3(0,-.75,0),.38,.55,load("res://assets/materials/pbr/iron.tres"))
	var names := {&"seal":"封印锚",&"bridge":"吊桥绞盘",&"launch":"风井"}
	DemoGeometry.label(self,Vector3.UP*.85,names.get(kind,"机关"),25)

func get_hit_point() -> Vector3:
	return global_position

func receive_hit(amount: int, _direction: Vector3) -> bool:
	return amount > 0 and activate()

func activate() -> bool:
	if _tuning==null or used or not is_inside_tree() or not can_process() or not is_instance_valid(player) or not player.control_enabled or get_tree().paused:
		return false
	if kind == &"launch":
		if _cooldown>0.0 or player.global_position.distance_to(global_position)>_tuning.launch_interact_range_m:
			return false
		player.velocity = global_basis*_tuning.launch_velocity_local_mps
		player._momentum_left = _tuning.launch_momentum_seconds
		player._ignore_floor_once = true
		player.dash_available = true
		_cooldown = _tuning.launch_cooldown_seconds
	else:
		used = true
		core.material_override = DemoGeometry.material(Color("#4d615d"))
	ImpactBurst.spawn(get_parent(),global_position,Color("#7ffff0"))
	activated.emit()
	return true

func reset_device() -> void:
	used = false
	_cooldown = 0.0
	if is_instance_valid(core):core.material_override = DemoGeometry.material(Color("#70ece1"),1.6)

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0,_cooldown-delta)
	core.rotation.y += delta
	if kind == &"launch" and is_instance_valid(player) and player.global_position.distance_to(global_position)<_tuning.launch_auto_radius_m:
		activate()
