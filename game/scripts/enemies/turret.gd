class_name LanternAcolyte
extends CharacterBody3D
signal defeated(enemy: LanternAcolyte)
signal fired
signal seal_requested
signal guard_opened
signal hit_resolved(enemy: LanternAcolyte, point: Vector3, accepted: bool, reason: StringName)
signal control_applied(enemy: LanternAcolyte, point: Vector3, element: StringName, seconds: float)

@export var archetype: StringName = &"normal"
@export var role: StringName = &""
@export var threat_rank: StringName = &""
var brain: EnemyBrain
var boss_controller: BossPhaseController
var control_pressure: float = 0.0
@export var maximum_health: int = 1
@export var attack_range: float = 18.0
var health: int = 1
var active: bool = false
var player: ParkourPlayer
var cooldown: float = 1.2
var shot_cooldown: float = 1.6
var windup: float = -1.0
var locked_target := Vector3.ZERO
var guard_broken: bool = true
var vulnerable: bool = true
var _guard_time: float = 0.0
var _flash: float = 0.0
var _stagger: float = 0.0
var _death_time: float = 0.0
var _recoil: float = 0.0
var _visual: Node3D
var _core: MeshInstance3D
var _beam: MeshInstance3D
var _title: Label3D
var _flash_material: ShaderMaterial
var _volleys: int = 0
var _size: float = 1.0
var _guard_visual: MeshInstance3D
var _animation: AnimationPlayer
var _animation_clock: float = 0.0
var _mesh_parts: Array[Node] = []
var _tell: MeshInstance3D
var frozen_left: float = 0.0
var _frost_material: ShaderMaterial

func _ready() -> void:
	if role == &"": role = &"heavy" if archetype == &"shield" else (&"pursuer" if archetype == &"elite" else &"crossbow")
	if threat_rank == &"": threat_rank = archetype if archetype in [&"elite",&"miniboss",&"boss"] else &"normal"
	add_to_group("acolytes")
	collision_layer = 4
	collision_mask = 1
	_size = (1.4 if archetype==&"miniboss" else (1.65 if archetype==&"boss" else 1.0))*1.12
	var collider := CollisionShape3D.new()
	var bounds := CapsuleShape3D.new()
	bounds.radius = 0.43*_size
	bounds.height = 1.9*_size
	collider.shape = bounds
	collider.position.y = 0.95*_size
	add_child(collider)
	_visual = Node3D.new()
	add_child(_visual)
	var model := (load("res://assets/models/blender/%s_enemy.glb" % archetype) as PackedScene).instantiate()
	_visual.add_child(model)
	model.scale*=1.12
	_animation = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_mesh_parts = _visual.find_children("*","MeshInstance3D",true,false)
	for part: MeshInstance3D in _mesh_parts:
		part.visibility_range_end=60
		part.visibility_range_end_margin=5
	_core = model.find_child("Core*",true,false) as MeshInstance3D
	var torus := TorusMesh.new()
	torus.inner_radius=.25*_size
	torus.outer_radius=.262*_size
	_guard_visual = DemoGeometry.mesh(_visual,torus,Vector3(0,1.22*_size,.33*_size),DemoGeometry.material(_core_color(),.7))
	_guard_visual.rotation.x=PI/2
	_title = DemoGeometry.label(self,Vector3(0,2.25*_size,0),_name(),28)
	_title.visibility_range_end=26
	_beam = DemoGeometry.box(self,Vector3.ZERO,Vector3.ONE,DemoGeometry.material(Color("#d56835"),1.0)) as MeshInstance3D
	_beam.top_level = true
	_beam.visible = false
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = preload("res://assets/shaders/hit_rim.gdshader")
	_frost_material = ShaderMaterial.new()
	_frost_material.shader = preload("res://assets/shaders/frozen_shell.gdshader")
	_setup_stats()
	_tell = FxMaterials.sprite(self,.7,FxMaterials.glow(_core_color(),0))
	_tell.position = Vector3(0,1.25*_size,.03)
	brain = EnemyBrain.new()
	brain.name = "EnemyBrain"
	add_child(brain)
	if archetype in [&"miniboss",&"boss"]:
		BossPhaseController.install(self,&"forge" if archetype==&"miniboss" else &"priest")
		set_notify_local_transform(true)

func _notification(what: int) -> void:
	# The legacy expansion places its guardian after _ready but before static
	# batching. Local notifications are immediate, so bind the FINAL platform
	# while it can still be excluded from that batch. Resource spawns need no move.
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and is_instance_valid(boss_controller):
		boss_controller.sync_spawn_transform()

func _core_color() -> Color:
	return {&"normal":Color("#d77525"),&"shield":Color("#54c8cf"),&"elite":Color("#d04f9f"),&"miniboss":Color("#ed9249"),&"boss":Color("#d74f6d")}.get(archetype,Color("#d77525"))


func _name() -> String:
	if threat_rank in [&"miniboss",&"boss"]: return "熔炉执刑官" if threat_rank==&"miniboss" else "无面祭祀"
	return ("精英 · " if threat_rank==&"elite" else "") + str({&"pursuer":"誓刃追猎者",&"heavy":"墓门重卫",&"crossbow":"荆棘弩手",&"caster":"灯疫异端",&"bell":"缚钟师",&"sentinel":"翼骸哨兵"}.get(role,"荆棘弩手"))

func has_guard() -> bool:
	return role in [&"heavy",&"bell"] or threat_rank in [&"elite",&"miniboss",&"boss"]

func configure_behavior(new_role: StringName, rank: StringName = &"normal") -> void:
	role=new_role
	threat_rank=rank
	_setup_stats()
	if is_instance_valid(brain): brain.configure(role,threat_rank)
	if is_instance_valid(boss_controller): boss_controller.reset_encounter()

func _setup_stats() -> void:
	maximum_health = {&"miniboss":2,&"boss":3}.get(threat_rank,1)
	health = maximum_health
	guard_broken = not has_guard()
	vulnerable = guard_broken
	_title.text = _name() + ("  ·  一击处决" if archetype in [&"normal",&"shield"] else "  %d / %d" % [health,maximum_health])

func reset_enemy() -> void:
	if is_instance_valid(brain): brain.reset_state()
	control_pressure=0
	frozen_left = 0.0
	health = maximum_health
	velocity = Vector3.ZERO
	windup = -1.0
	cooldown = .8
	_guard_time = 0.0
	guard_broken = not has_guard()
	vulnerable = guard_broken
	_flash = 0.0
	_stagger = 0.0
	_recoil = 0.0
	_death_time = 0.0
	_visual.visible = true
	_visual.scale = Vector3.ONE
	_beam.visible = false
	_title.visible = true
	collision_layer = 4
	_title.text = _name() + ("  ·  一击处决" if archetype in [&"normal",&"shield"] else "  %d / %d" % [health,maximum_health])
	reset_physics_interpolation()
	if is_instance_valid(boss_controller): boss_controller.reset_encounter()

func get_hit_point() -> Vector3:
	return global_position + Vector3.UP*1.25*_size

func apply_frost(seconds: float) -> bool:
	if not active or health<=0:
		return false
	if is_instance_valid(boss_controller):
		var applied := boss_controller.apply_control(seconds)
		if applied: _report_control(&"ice",frozen_left)
		return applied
	if threat_rank in [&"boss",&"miniboss"]:
		control_pressure += .5
		frozen_left=maxf(frozen_left,minf(.22,seconds))
		if control_pressure>=1:
			control_pressure=0
			break_guard(1.4)
		if is_instance_valid(brain): brain.interrupted()
		_report_control(&"ice",frozen_left)
		return true
	if threat_rank == &"elite": seconds=minf(seconds,.8)
	frozen_left = maxf(frozen_left,seconds)
	break_guard(seconds+.15)
	windup = -1
	cooldown = maxf(cooldown,.65)
	_beam.visible = false
	_title.text = _name()+" · 冰冻"
	if is_instance_valid(brain): brain.interrupted()
	_report_control(&"ice",frozen_left)
	return true

func apply_wind(_direction: Vector3) -> void:
	if not active or health<=0:
		return
	if is_instance_valid(boss_controller):
		if boss_controller.apply_control(.15): _report_control(&"wind",_stagger)
		return
	if threat_rank in [&"boss",&"miniboss"]:
		control_pressure += .5
		if control_pressure>=1:
			control_pressure=0
			break_guard(1.2)
	else:
		velocity += Vector3(_direction.x,0,_direction.z).normalized()*6
	windup = -1
	cooldown = maxf(cooldown,.6)
	_stagger = maxf(_stagger,.35)
	_beam.visible = false
	if is_instance_valid(brain): brain.interrupted()
	_report_control(&"wind",_stagger)

func _report_control(element: StringName, seconds: float) -> void:
	# Report the duration actually applied (including elite/boss caps), not the
	# requested value. This is a success notification, not a new control rule.
	if seconds > 0: control_applied.emit(self,get_hit_point(),element,seconds)

func break_guard(seconds: float = 4.0) -> void:
	if health<=0:
		return
	if is_instance_valid(boss_controller):
		# Control/deflection still staggers the boss, but cannot skip objectives.
		return
	if not vulnerable:
		ImpactBurst.spawn(get_parent(),get_hit_point(),Color("#9ae0ec"),1.15)
		guard_opened.emit()
	guard_broken = true
	vulnerable = true
	_guard_time = seconds
	_stagger = .25
	_title.text = _name() + "  ·  处决窗口"
	_flash = .2

func receive_hit(amount: int, direction: Vector3) -> bool:
	# This stable enemy feedback point is not a measured surface intersection.
	# Projectile VFX needing that surface already receive MagicBolt.contacted.
	var point := get_hit_point()
	if not active: return _report_hit(point,false,&"inactive")
	if health <= 0: return _report_hit(point,false,&"dead")
	if amount <= 0: return _report_hit(point,false,&"invalid_amount")
	if is_instance_valid(boss_controller):
		# Capture the gate before resolving: an accepted phase hit immediately
		# closes the shield/starts a transition, which cannot label that hit blocked.
		var rejected: StringName = &"boss_shield" if boss_controller.state == &"shielded" else &"boss_phase"
		if not boss_controller.is_running() or boss_controller.state == &"cancelled": rejected = &"boss_inactive"
		var accepted := boss_controller.receive_hit(amount,direction)
		return _report_hit(point,accepted,(&"killed" if health <= 0 else &"accepted") if accepted else rejected)
	# Attacks from behind bypass the frontal guard; the facing locks during windup.
	if not vulnerable and not threat_rank in [&"boss",&"miniboss"] and direction.dot(_visual.global_basis.z) > 0.3:
		break_guard(1.0)
	if not vulnerable and role==&"bell" and is_instance_valid(brain) and brain.state==&"windup": break_guard(1.0)
	if not vulnerable:
		ImpactBurst.spawn(get_parent(),get_hit_point(),Color("#63bbf4"))
		return _report_hit(point,false,&"guard")
	if threat_rank not in [&"miniboss",&"boss"]:
		health = 0
	else:
		health = maxi(0,health-1)
	velocity = Vector3(direction.x,0,direction.z).normalized()*4.8
	_flash = .12
	_stagger = .32
	_recoil = .24
	windup = -1.0
	_beam.visible = false
	if has_guard():
		vulnerable = false
		guard_broken = false
		_guard_time = 0.0
	if health <= 0:
		_die()
	else:
		_title.text = _name() + "  %d / %d" % [health,maximum_health]
		if is_instance_valid(brain): brain.interrupted()
		seal_requested.emit()
	return _report_hit(point,true,&"killed" if health <= 0 else &"accepted")

func _report_hit(point: Vector3, accepted: bool, reason: StringName) -> bool:
	# All damage, guard, phase and death state has committed before notification.
	# Observers must not mutate combat; this signal does not apply a second hit.
	hit_resolved.emit(self,point,accepted,reason)
	return accepted

func _die() -> void:
	if is_instance_valid(brain): brain.reset_state()
	health = 0
	collision_layer = 0
	_title.visible = false
	_death_time = .9
	defeated.emit(self)

func _physics_process(delta: float) -> void:
	if not active or health <= 0 or not is_instance_valid(player) or not player.control_enabled:
		_beam.visible = false
		return
	if is_instance_valid(boss_controller):
		boss_controller.advance(delta)
		frozen_left = maxf(0,frozen_left-delta)
		_stagger = maxf(0,_stagger-delta)
		if not boss_controller.may_attack() or frozen_left>0 or _stagger>0: return
		brain.advance(delta)
		return
	var was_open: bool = _guard_time>0.0
	_guard_time = maxf(0.0,_guard_time-delta)
	if was_open and _guard_time <= 0.0 and has_guard():
		vulnerable = false
		guard_broken = false
		seal_requested.emit()
	if frozen_left>0:
		frozen_left = maxf(0,frozen_left-delta)
		return
	_stagger = maxf(0.0,_stagger-delta)
	if _stagger>0.0:
		return
	brain.advance(delta)

func _process(delta: float) -> void:
	_flash=maxf(0.0,_flash-delta)
	_flash_material.set_shader_parameter("strength",minf(1,_flash*10))
	_recoil=move_toward(_recoil,0.0,delta*1.5)
	_visual.rotation.x=0
	if _tell != null:
		FxMaterials.face_camera(_tell)
		(_tell.material_override as ShaderMaterial).set_shader_parameter("strength",(1.0-windup)*2.0 if windup>=0 and health>0 else 0.0)
	_animation_clock = fmod(_animation_clock+(0.0 if frozen_left>0 else delta*.7),1.0)
	var clip := &"idle"
	var animation_time: float = _animation_clock
	if windup>=0.0:
		clip = &"fire"
		animation_time = 1.0-windup
	if _stagger>0:
		clip = &"stagger"
		animation_time = 1.0-_stagger/.32
	if health<=0:
		clip = &"death"
		animation_time = 1.0-_death_time/.9
	if _animation.current_animation != clip:
		_animation.play(clip)
	_animation.seek(clampf(animation_time,0,1),true)
	_guard_visual.visible = not vulnerable and health>0
	_guard_visual.rotation.y = sin(_animation_clock*TAU)*.12
	_core.scale=Vector3.ONE*(1.0+0.6*(1.0-windup/1.0) if windup>=0.0 else 1.0)
	for part in _mesh_parts:
		if part is MeshInstance3D:
			part.material_overlay=_frost_material if frozen_left>0 and health>0 else (_flash_material if _flash>0.0 else null)
	if health<=0 and _death_time>0.0:
		_death_time=maxf(0.0,_death_time-delta)
		_visual.visible=_death_time>0.0
