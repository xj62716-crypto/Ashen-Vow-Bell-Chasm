class_name TerrainDevice
extends StaticBody3D
signal activated
signal travel_started(target: float, duration_seconds: float)
signal travel_finished(at_upper_landing: bool)
signal travel_cancelled
signal pulse_emitted
@export var tuning: LevelMechanismTuning=preload("res://scenes/levels/config/default_mechanisms.tres")
var _tuning: LevelMechanismTuning

var kind: StringName=&"bridge"
var player: ParkourPlayer
var used: bool=false
var moving_body: AnimatableBody3D
var start_point := Vector3.ZERO
var finish_point := Vector3.ZERO
var progress: float=0
var target_progress: float=0
var moving: bool=false
# Landing call stones share one controller, travel state and reward event.
var linked_device: TerrainDevice
var _timer: float=0
var _label: Label3D
var _barrier: Node3D
var _steam: CPUParticles3D
var _room_enabled: bool=true

func _ready() -> void:
	var errors := tuning.validation_errors() if tuning!=null else PackedStringArray(["tuning: missing resource"])
	if not errors.is_empty():
		push_error("TerrainDevice: "+str(errors))
		process_mode=Node.PROCESS_MODE_DISABLED
		return
	_tuning=tuning.duplicate(true) as LevelMechanismTuning
	process_mode=Node.PROCESS_MODE_INHERIT
	add_to_group("terrain_devices")
	collision_layer=4
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius=.48
	shape.shape=sphere
	add_child(shape)
	DemoGeometry.cylinder(self,Vector3(0,-.7,0),.34,1.2,load("res://assets/materials/pbr/iron.tres"))
	DemoGeometry.sphere(self,Vector3.ZERO,.26,DemoGeometry.material(Color("#7ae3d1"),.65))
	_label=DemoGeometry.label(self,Vector3.UP*.8,{&"bridge":"E / 攻击 · 转动栈桥",&"lift":"E / 攻击 · 升降机",&"vent":"E / 攻击 · 蒸汽阀",&"breakable":"击碎封板",&"pulse":"高位扫光 · 滑铲穿过"}.get(kind,"机关"),23)
	if kind==&"breakable":
		_barrier=DemoGeometry.box(self,Vector3(0,0,-.6),Vector3(3.2,3.0,.18),load("res://assets/materials/pbr/rock.tres"),true)
	if kind==&"vent":
		_barrier=DemoGeometry.box(self,Vector3(0,0,-2),Vector3(3,2.5,.3),DemoGeometry.material(Color("#dfab78"),.8),true)
		_barrier.get_child(1).hide()
		_steam=CPUParticles3D.new()
		_steam.position=Vector3(0,-1,-2)
		_steam.amount=28
		_steam.lifetime=1.0
		_steam.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
		_steam.emission_box_extents=Vector3(1.35,.05,.1)
		_steam.direction=Vector3.UP
		_steam.gravity=Vector3(0,1,0)
		_steam.initial_velocity_min=2
		_steam.initial_velocity_max=3
		_steam.scale_amount_min=.16
		_steam.scale_amount_max=.34
		var vapor := SphereMesh.new()
		vapor.radial_segments=8
		vapor.rings=4
		var fog := DemoGeometry.material(Color(.7,.76,.72,.16))
		fog.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		vapor.material=fog
		_steam.mesh=vapor
		add_child(_steam)

func get_hit_point() -> Vector3:return global_position

func receive_hit(damage: int,_direction: Vector3) -> bool:return damage>0 and activate()

func activate() -> bool:
	if _tuning==null or not is_inside_tree() or not can_process() or get_tree().paused or not is_instance_valid(player) or not player.control_enabled:return false
	if is_instance_valid(linked_device):return linked_device.activate()
	if kind==&"lift":
		if moving or not is_instance_valid(moving_body):return false
		target_progress=0.0 if progress>=.5 else 1.0
		moving=true
		travel_started.emit(target_progress,_tuning.lift_travel_seconds)
		if not used:
			used=true
			activated.emit()
		_update_label()
		return true
	if used:return false
	used=true
	activated.emit()
	if is_instance_valid(_steam):_steam.emitting=false
	if is_instance_valid(_barrier):
		_barrier.visible=false
		sync_collision_state(true)
		SkillEffect.spawn(get_tree().current_scene,global_transform,&"rift",Color("#d1c8a8"),1.5)
	_label.text="通路已打开"
	return true

func sync_collision_state(room_enabled: bool) -> void:
	_room_enabled=room_enabled
	if is_instance_valid(_barrier):
		for shape: CollisionShape3D in _barrier.find_children("*","CollisionShape3D",true,false):
			shape.set_deferred("disabled",not room_enabled or used)

func reset_device() -> void:
	if is_instance_valid(linked_device):
		linked_device.reset_device()
		return
	if moving:travel_cancelled.emit()
	used=false
	moving=false
	progress=0.0
	target_progress=0.0
	_timer=0.0
	if is_instance_valid(moving_body):
		moving_body.position=start_point
		moving_body.reset_physics_interpolation()
	if is_instance_valid(_barrier):_barrier.visible=true
	if is_instance_valid(_steam):_steam.emitting=true
	sync_collision_state(_room_enabled)
	_update_label()

func _exit_tree() -> void:
	if moving:travel_cancelled.emit()

func _update_label() -> void:
	if not is_instance_valid(_label):return
	var controller: TerrainDevice=linked_device if is_instance_valid(linked_device) else self
	if kind==&"lift":
		_label.text="升降中" if controller.moving else ("E / 攻击 · 降下升降台" if controller.progress>=.5 else "E / 攻击 · 升起升降台")
	else:
		_label.text="通路已打开" if used else {&"bridge":"E / 攻击 · 转动栈桥",&"vent":"E / 攻击 · 蒸汽阀",&"breakable":"击碎封板",&"pulse":"高位扫光 · 滑铲穿过"}.get(kind,"机关")

func _physics_process(delta: float) -> void:
	if is_instance_valid(linked_device):
		_update_label()
		return
	if moving and is_instance_valid(moving_body):
		progress=move_toward(progress,target_progress,delta/_tuning.lift_travel_seconds)
		moving_body.position=start_point.lerp(finish_point,smoothstep(0,1,progress))
		if is_equal_approx(progress,target_progress):
			moving=false
			travel_finished.emit(progress>=.5)
			_update_label()
	if kind==&"pulse" and not used and is_instance_valid(player) and player.control_enabled:
		_timer+=delta
		if _timer>_tuning.pulse_interval_seconds and player.global_position.distance_to(global_position)<_tuning.pulse_activation_radius_m:
			_timer=0
			var wave := SweepWave.new()
			wave.player=player
			wave.high=true
			wave.position=position-Vector3.UP
			get_parent().add_child(wave)
			pulse_emitted.emit()
