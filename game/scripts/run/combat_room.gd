class_name CombatRoom
extends Node3D
signal cleared
signal enemy_fired
signal mechanism_used
signal altar_requested(altar: RunAltar)
signal guard_broken
signal configuration_rejected(errors: PackedStringArray)
signal checkpoint_reached(id: StringName, pose: Transform3D, index: int)

@export var run_configuration: LevelRunConfiguration=preload("res://scenes/levels/config/default_run.tres")
var last_configuration_errors := PackedStringArray()
var _configuration: LevelRunConfiguration

var enemies: Array[LanternAcolyte] = []
var defeated_count: int = 0
var spawn: Marker3D
var exit_area: Area3D
var stage_title: String = "断桥外墙"
var stage: int = 1
var enabled: bool = false
var geometry: Node3D
var mechanisms: Array[RunMechanism] = []
var altar: RunAltar
var altars: Array[RunAltar]=[]
var terrain_devices: Array[TerrainDevice]=[]
var static_anchors: Array[RiftConstruct]=[]
var checkpoint_areas: Array[Area3D]=[]
var reached_checkpoints: Dictionary={}
var route_nodes: Array[Vector3]=[]
var branch_nodes: Array[Vector3]=[]
var shape_landings: Array[Vector3]=[]
var return_landings: Array[Vector3]=[]
var platform_extents: Dictionary={}
## Named, inspectable sections used by route tests and later encounter tuning.
## These are runtime facts about formal geometry, not separate preview cells.
var signature_sections: Dictionary={}
## Built connection graph, including intermediate rest platforms. Coordinates
## are room-local floor points; runtime/editor inspection shares this record.
var route_links: Array[Dictionary]=[]
var exit_unlocked: bool = false
var _required_enemies: Array[LanternAcolyte] = []
var _bridge_open: bool = false
var _exit_title: Label3D
var _gate: Node3D
var _gate_shape: CollisionShape3D
var _bridge: Node3D
var _suspended_shapes: Dictionary = {}
var _collisions_suspended: bool = false
var _stone: Material = preload("res://assets/materials/pbr/stone.tres")
var _floor: Material = preload("res://assets/materials/pbr/floor.tres")
var _iron: Material = preload("res://assets/materials/pbr/iron.tres")
var _accent: Material

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	if not _build(1):push_error("CombatRoom configuration: "+str(last_configuration_errors))
	set_enabled(false)
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event("interact", key)

func set_next_configuration(candidate: LevelRunConfiguration) -> PackedStringArray:
	var errors := candidate.validation_errors() if candidate!=null else PackedStringArray(["configuration: required resource is missing"])
	if errors.is_empty():run_configuration=candidate
	else:configuration_rejected.emit(errors)
	last_configuration_errors=errors
	return errors

func configuration_id() -> StringName:
	return _configuration.id if _configuration!=null else &""

func _build(number: int) -> bool:
	last_configuration_errors=run_configuration.validation_errors() if run_configuration!=null else PackedStringArray(["configuration: required resource is missing"])
	if number<1 or number>3:last_configuration_errors.append("stage: expected 1..3")
	if not last_configuration_errors.is_empty():
		configuration_rejected.emit(last_configuration_errors)
		return false
	_configuration=run_configuration.snapshot()
	_suspended_shapes.clear()
	_collisions_suspended = false
	if is_instance_valid(geometry):
		remove_child(geometry)
		geometry.queue_free()
	enemies.clear()
	_required_enemies.clear()
	exit_unlocked = false
	_bridge_open = false
	mechanisms.clear()
	altars.clear()
	terrain_devices.clear()
	static_anchors.clear()
	checkpoint_areas.clear()
	reached_checkpoints.clear()
	route_nodes.clear()
	branch_nodes.clear()
	shape_landings.clear()
	return_landings.clear()
	platform_extents.clear()
	route_links.clear()
	signature_sections.clear()
	_bridge = null
	geometry = Node3D.new()
	geometry.name = "StageGeometry"
	add_child(geometry)
	stage = number
	stage_title = ["断桥外墙", "熔炉升降井", "悬空封印塔"][clampi(stage-1,0,2)]
	_accent = DemoGeometry.material([Color("#b9c2ad"),Color("#c58e60"),Color("#acc4c1")][stage-1],.12)
	spawn = Marker3D.new()
	geometry.add_child(spawn)
	if stage==1:
		RefinedCauseway.build(self)
	else:
		match stage:
			2: _forge()
			3: _tower()
		CitadelExpansion.build(self)
	_spawn_configured_encounters()
	_build_checkpoints()
	altar = RunAltar.new()
	altar.position = Vector3(2.4,0,5.0) if stage == 1 else Vector3(-1.6,0,4.5)
	geometry.add_child(altar)
	altar.requested.connect(func(device: RunAltar): altar_requested.emit(device))
	altars.push_front(altar)
	_scenery()
	if stage!=1:CitadelDressing.build(geometry,stage)
	IntegratedEnvironmentDressing.decorate(self)
	CitadelDressing.batch_static(geometry)
	CitadelDressing.batch_primitives(geometry)
	var environment: Environment = get_tree().current_scene.get_node("WorldEnvironment").environment if get_tree().current_scene != null else null
	if environment != null:
		var sky := Sky.new()
		var sky_material := ShaderMaterial.new()
		sky_material.shader = preload("res://assets/shaders/citadel_sky.gdshader")
		sky.sky_material = sky_material
		environment.sky = sky
		environment.background_mode = Environment.BG_SKY
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.ambient_light_energy = .14
		environment.fog_density = .0027
		environment.volumetric_fog_density = .0032
		environment.fog_light_color = Color("#17282c")
		environment.fog_aerial_perspective = .5
		environment.tonemap_exposure = 1.0
		environment.glow_intensity = .34
	return true

func _platform(center: Vector3, size: Vector2) -> Node3D:
	platform_extents[center]=size
	var body := DemoGeometry.box(geometry,center-Vector3.UP*0.6,Vector3(size.x,1.2,size.y),_floor,true)
	CitadelDressing.paving(body,Vector3.UP*.6,size)
	for end: float in [-1,1]:
		DemoGeometry.box(geometry,center+Vector3(0,.055,end*(size.y/2-.07)),Vector3(size.x,.025,.055),_accent)
	return body

func _wall(center: Vector3, size: Vector3) -> void:
	var body:=DemoGeometry.box(geometry,center,size,_stone,true)
	body.set_meta("route_wall_size",size)
	var side: float = -1.0 if center.x>0 else 1.0
	for z in range(int(center.z-size.z/2)+1,int(center.z+size.z/2),2):
		DemoGeometry.box(geometry,Vector3(center.x+side*(size.x/2+.015),1.3,z),Vector3(.025,.035,.45),_accent)
	for z in range(int(center.z-size.z/2),int(center.z+size.z/2)+1,4):
		DemoGeometry.box(geometry,Vector3(center.x-side*.32,center.y,z),Vector3(.23,size.y+.35,.3),_iron)

func _outer_wall() -> void:
	spawn.position = Vector3(3.8,.08,7)
	_platform(Vector3(0,0,4),Vector2(10,10))
	_platform(Vector3(0,0,-15),Vector2(10,10))
	_platform(Vector3(-3,0,-29),Vector2(6,10))
	_platform(Vector3(0,0,-44),Vector2(12,12))
	_wall(Vector3(5.4,2.4,-6),Vector3(.8,6,24))
	for z: float in [-5.5,-6.0]:
		DemoGeometry.box(geometry,Vector3(4.97,2.2,z),Vector3(.04,2,.16),DemoGeometry.material(Color("#ffcd79"),1.1))
	_wall(Vector3(-6.4,2.4,-20),Vector3(.8,6,12))
	_wall(Vector3(-6.4,2.4,-35.5),Vector3(.8,6,5))
	DemoGeometry.box(geometry,Vector3(-6.4,5.3,-29.5),Vector3(.8,.65,7),_stone,true)
	# A low passage runs outside the wall route, ending in a slide-jump gap.
	_platform(Vector3(-6.8,0,5),Vector2(5.6,4))
	_platform(Vector3(-9,0,-3),Vector2(3,16))
	DemoGeometry.box(geometry,Vector3(-9,2.05,-3),Vector3(3,1.9,9),_iron,true)
	_platform(Vector3(-9,0,-27),Vector2(3.5,8))
	_platform(Vector3(-6.3,0,-29),Vector2(6,3))
	# Raised landings reward stronger wall kicks and sustained airborne movement.
	_platform(Vector3(2,4.4,-13),Vector2(3.8,5))
	_platform(Vector3(1,2.4,-27),Vector2(4,6))
	_route_marker(Vector3(-9,.08,2),Color("#e3bd72"),&"slide")
	_route_marker(Vector3(4.5,.08,0),Color("#dd987d"),&"wall")
	_route_marker(Vector3(2,4.48,-13),Color("#75c5de"),&"air")
	_enemy(Vector3(0,.04,-12),&"normal",&"crossbow")
	_enemy(Vector3(-3,.04,-28),&"shield",&"heavy")
	_enemy(Vector3(0,.04,-44),&"elite",&"pursuer",true)
	_enemy(Vector3(-4.7,.04,-30.5),&"normal",&"caster")
	_mechanism(Vector3(-2,1.1,-15),&"bridge")
	_bridge = _platform(Vector3(-3,0,-21),Vector2(3,6))
	_set_bridge(false)
	_exit(Vector3(0,0,-48))

func _forge() -> void:
	spawn.position = Vector3(0,.08,6)
	_platform(Vector3(0,0,3),Vector2(8,10))
	_platform(Vector3(0,0,-9),Vector2(4,10))
	_platform(Vector3(4,0,-19),Vector2(7,8))
	_platform(Vector3(0,3,-32),Vector2(12,14))
	# Separate the caster from the wind-well launch and protect its arrival.
	# A furnace cheek breaks both firing lines; the centre lane and the rear
	# approach at z=-37.5 remain open to either base profession.
	_wall(Vector3(2,4.5,-34),Vector3(.65,3,4))
	_wall(Vector3(4,4.5,-33),Vector3(3.4,3,.65))
	# The low service throat commits the player to a slide and releases them at
	# the first broken deck. Its 1.2 m clearance rejects the standing capsule.
	DemoGeometry.box(geometry,Vector3(0,2.05,1),Vector3(6,1.7,3),_iron,true)
	DemoGeometry.box(geometry,Vector3(-3.35,1.5,1),Vector3(.7,3,3),_stone,true)
	DemoGeometry.box(geometry,Vector3(3.35,1.5,1),Vector3(.7,3,3),_stone,true)
	# Keep the throat's exit readable under normal-input timing. The old two metre
	# seam between the entry slab and the first deck turned a valid slide-jump
	# into an accidental fall when the jump was buffered a few frames early.
	_platform(Vector3(0,-.02,-3),Vector2(5.5,2.2))
	_route_marker(Vector3(0,.08,4),Color("#d48f63"),&"slide")
	_wall(Vector3(8,2,-16),Vector3(.7,6,23))
	_mechanism(Vector3(4,1.0,-20),&"launch")
	_mechanism(Vector3(-3,4.1,-29),&"seal")
	_platform(Vector3(-6,0,1),Vector2(5,3))
	_platform(Vector3(-7,1.8,-13),Vector2(3,5))
	_platform(Vector3(-5,3,-27),Vector2(3,5))
	_wall(Vector3(-9,3,-12),Vector3(.8,8,28))
	_route_marker(Vector3(-6,.08,1),Color("#75c5de"),&"air")
	for z: float in [-4,-16,-29]:
		DemoGeometry.box(geometry,Vector3(0,9,z),Vector3(24,.7,.8),_iron)
		for side: float in [-1,1]:
			DemoGeometry.box(geometry,Vector3(side*10,1,z),Vector3(.7,18,.8),_iron)
	var melt := ShaderMaterial.new()
	melt.shader = preload("res://assets/shaders/forge_melt.gdshader")
	DemoGeometry.box(geometry,Vector3(0,-9,-20),Vector3(27,.2,58),melt)
	signature_sections[&"chain_well"]={
		"start":Vector3(0,.08,6),"slide_exit":Vector3(0,.08,-.5),
		"wind":Vector3(4,1,-20),"upper_landing":Vector3(0,3,-32),
		"standing_clearance_m":1.2,"mechanics":[&"slide",&"slide_jump",&"launch"]}
	_exit(Vector3(0,3,-37))

func _tower() -> void:
	spawn.position = Vector3(0,.08,7)
	_platform(Vector3(0,0,4),Vector2(8,10))
	_platform(Vector3(-5,1,-11),Vector2(5,10))
	_platform(Vector3(0,1,-24),Vector2(17,14))
	_platform(Vector3(0,1,-39),Vector2(8,16))
	_wall(Vector3(-8,3,-6),Vector3(.8,7,27))
	_wall(Vector3(9,3,-24),Vector3(.8,7,18))
	_mechanism(Vector3(-6,2.1,-20),&"seal")
	_mechanism(Vector3(6,2.1,-20),&"seal")
	_mechanism(Vector3(-2,1.0,0),&"launch")
	_platform(Vector3(4,0,2),Vector2(4,4))
	_platform(Vector3(6,1,-12),Vector2(3,6))
	_wall(Vector3(8.2,3,-7),Vector3(.8,7,21))
	_route_marker(Vector3(4,.08,2),Color("#b9d39b"),&"air")
	# A readable interior nave encloses the last safe platforms. Beyond z=-44
	# the roof and side arcade stop together, revealing the floating tower route.
	DemoGeometry.box(geometry,Vector3(0,5.2,-31.5),Vector3(17,.8,25),_stone,true)
	for side: float in [-1,1]:
		DemoGeometry.box(geometry,Vector3(side*8.1,3.1,-31.5),Vector3(.65,4.2,25),_stone,true)
	signature_sections[&"nave_to_void"]={
		"covered_start":Vector3(0,1,-24),"threshold":Vector3(0,1,-44),
		"exposed_landing":Vector3(0,1,-68),"roof_end_z":-44.0,
		"mechanics":[&"corridor",&"wall_run",&"air_dash"]}
	for i in range(8):
		var angle: float = TAU*i/8
		var point := Vector3(cos(angle)*13,5,-24+sin(angle)*13)
		DemoGeometry.cylinder(geometry,point,1.0,18,_stone)
		DemoGeometry.cylinder(geometry,point+Vector3.UP*7.8,1.5,.5,_iron)
		var arch := (load("res://assets/models/kenney_castle/tower-square-arch.glb") as PackedScene).instantiate() as Node3D
		arch.position = point+Vector3.UP*8
		arch.scale=Vector3.ONE*2
		geometry.add_child(arch)
	for side: float in [-1,1]:
		# Keep the cover behind the authored sentries; the previous front edge
		# intersected both capsule bodies even though their feet had support.
		DemoGeometry.box(geometry,Vector3(side*3.5,2,-26),Vector3(.8,2,1.6),_stone,true)
	_exit(Vector3(0,1,-41))

func _scenery() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-38,-65,0)
	key.light_color=Color("#bbcddb")
	key.light_energy=.52
	key.shadow_enabled=true
	geometry.add_child(key)
	for z: float in [5,-10,-25,-40]:
		var light := OmniLight3D.new()
		light.position = Vector3(0,6,z)
		light.light_color = Color("#d0dce4")
		light.light_energy = .10
		light.omni_range = 18
		geometry.add_child(light)
		if stage==2:
			for side: float in [-1,1]:
				DemoGeometry.cylinder(geometry,Vector3(side*12,-3,z),1.6,16,_iron)
				DemoGeometry.cylinder(geometry,Vector3(side*12,2,z),1.7,.6,_accent)
		for side: float in [-1,1]:
			DemoGeometry.box(geometry,Vector3(side*13,-6,z),Vector3(2,18,2),_stone)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(side*7,3,z)
			lamp.light_color = [Color("#62bac7"),Color("#ee8860"),Color("#c8db9b")][stage-1]
			lamp.light_energy = 2
			lamp.omni_range = 10
			geometry.add_child(lamp)
	for point: Vector3 in ([Vector3(-3.8,0,6),Vector3(3.8,0,-16),Vector3(-4.8,0,-42)] if stage==1 else ([Vector3(2.8,0,5),Vector3(5.8,0,-17),Vector3(4.6,3,-35)] if stage==2 else [Vector3(2.8,0,6),Vector3(-6.5,1,-12),Vector3(7,1,-28)])):
		var entry_brazier_offset := Vector3(0,0,-2) if stage > 1 and point.z > -5 else Vector3.ZERO
		CitadelDressing.brazier(geometry,point+entry_brazier_offset)

func _route_marker(point: Vector3, color: Color, kind: StringName) -> void:
	var surface := DemoGeometry.material(color, .7)
	for i in range(3):
		var arrow := DemoGeometry.box(geometry,point+Vector3(0,0,-i*.38),Vector3(.55,.025,.08),surface)
		if kind == &"wall":
			arrow.rotation.z = -.45
		elif kind == &"air":
			arrow.rotation.y = PI/4.0

func _build_checkpoints() -> void:
	var points:Array[Vector3]
	match stage:
		# The first marker sits on the mandatory same-wall chain's real landing,
		# before the opposed-wall transfer. The old platform-centre marker at
		# x=0 was four metres off the natural line and silently failed to save.
		1:points=[Vector3(4.1,.08,-46),Vector3(-3,2.08,-113),Vector3(4,7.08,-235)]
		# Place recovery before the first hard gap and before the final vertical
		# transfer. A marker after a failed gap cannot restore the intended route.
		2:points=[route_nodes[0]+Vector3.UP*.08,route_nodes[1]+Vector3.UP*.08,route_nodes[3]+Vector3.UP*.08]
		3:points=[route_nodes[0]+Vector3.UP*.08,route_nodes[1]+Vector3.UP*.08,route_nodes[4]+Vector3.UP*.08]
	for index in points.size():
		var area:=Area3D.new()
		area.name="Checkpoint_%d_%d"%[stage,index+1]
		area.position=points[index]
		area.collision_layer=0
		area.collision_mask=2
		area.set_meta("checkpoint_id",StringName("stage_%d_checkpoint_%d"%[stage,index+1]))
		area.set_meta("checkpoint_index",index+1)
		geometry.add_child(area)
		var shape:=CollisionShape3D.new()
		var bounds:=BoxShape3D.new()
		bounds.size=Vector3(4,2.6,4)
		shape.shape=bounds
		shape.position.y=1.3
		area.add_child(shape)
		var marker:=DemoGeometry.cylinder(area,Vector3(0,.035,0),1.15,.07,DemoGeometry.material(Color("#9ec8b2"),.65))
		marker.set_meta("interactive_visual",true)
		DemoGeometry.label(area,Vector3.UP*.65,"归火界标",21)
		area.body_entered.connect(_checkpoint_body_entered.bind(area))
		checkpoint_areas.append(area)

func _checkpoint_body_entered(body:Node3D,area:Area3D)->void:
	if not enabled or not body is ParkourPlayer:return
	var id:StringName=area.get_meta("checkpoint_id",&"")
	if reached_checkpoints.has(id):return
	reached_checkpoints[id]=true
	var index:int=area.get_meta("checkpoint_index",0)
	checkpoint_reached.emit(id,Transform3D(Basis.IDENTITY,area.global_position),index)

func checkpoint_defeated_ids()->Array[StringName]:
	var ids:Array[StringName]=[]
	for enemy in enemies:
		if enemy.health<=0:ids.append(enemy.get_meta("encounter_id",StringName(enemy.name)))
	return ids

func restore_checkpoint(defeated_ids:Array[StringName])->Array[LanternAcolyte]:
	clear_effects()
	var defeated_lookup:Dictionary={}
	for id in defeated_ids:defeated_lookup[id]=true
	var revived:Array[LanternAcolyte]=[]
	defeated_count=0
	for enemy in enemies:
		var id:StringName=enemy.get_meta("encounter_id",StringName(enemy.name))
		if defeated_lookup.has(id):
			defeated_count+=1
			enemy.active=false
			continue
		if is_instance_valid(enemy.brain):enemy.global_position=enemy.brain.home
		enemy.reset_enemy()
		enemy.active=enabled
		revived.append(enemy)
	exit_unlocked=false
	if is_instance_valid(_gate):_gate.visible=true
	if is_instance_valid(_gate_shape):_gate_shape.set_deferred("disabled",not enabled)
	if is_instance_valid(_exit_title):_exit_title.text=stage_title
	_refresh_exit()
	return revived

func _spawn_configured_encounters() -> void:
	for entry: LevelEncounterEntry in _configuration.encounters:
		if entry.stage!=stage:continue
		_enemy(entry.position_m,StringName(entry.archetype),StringName(entry.role),entry.required_guardian,entry)

func _enemy(point: Vector3, kind: StringName, role: StringName = &"crossbow", required: bool = false, entry: LevelEncounterEntry = null) -> LanternAcolyte:
	var enemy := LanternAcolyte.new()
	enemy.archetype = kind
	enemy.position = point
	# Set the authored role before _ready; the gameplay adapter consumes it.
	enemy.set_meta("gameplay_role",role)
	enemy.set_meta("required_guardian",required)
	if entry!=null:
		enemy.set_meta("encounter_id",entry.id)
		enemy.set_meta("initial_delay_seconds",entry.initial_delay_seconds)
		enemy.attack_range=entry.attack_range_m
	geometry.add_child(enemy)
	if is_instance_valid(enemy.boss_controller):
		enemy.boss_controller.exposure_window_seconds = _configuration.mechanisms.seal_exposure_seconds
	enemies.append(enemy)
	if required:_required_enemies.append(enemy)
	enemy.defeated.connect(_enemy_defeated)
	enemy.fired.connect(func(): enemy_fired.emit())
	enemy.seal_requested.connect(_rearm_seals)
	enemy.guard_opened.connect(func(): guard_broken.emit())
	return enemy

func _rearm_seals() -> void:
	for device in mechanisms:
		if device.kind == &"seal":
			device.reset_device()

func _mechanism(point: Vector3, kind: StringName) -> void:
	var device := RunMechanism.new()
	device.kind = kind
	device.position = point
	device.tuning=_configuration.mechanisms
	geometry.add_child(device)
	mechanisms.append(device)
	device.activated.connect(_mechanism_activated.bind(device))

func _mechanism_activated(device: RunMechanism) -> void:
	mechanism_used.emit()
	if device.kind == &"bridge":
		_set_bridge(true)
	elif device.kind == &"seal":
		for other in mechanisms:
			if other.kind == &"seal" and not other.used:
				return
		for enemy in enemies:
			if enemy.archetype in [&"miniboss",&"boss"]:
				enemy.break_guard(_configuration.mechanisms.seal_exposure_seconds)
	_refresh_exit()

func _set_bridge(value: bool) -> void:
	_bridge_open = value
	if is_instance_valid(_bridge):
		_bridge.visible = value
		for shape in _bridge.find_children("*","CollisionShape3D",true,false):
			shape.set_deferred("disabled",not value or not enabled)

func _exit(point: Vector3) -> void:
	_gate = DemoGeometry.box(geometry,point+Vector3.UP*1.6,Vector3(3,3.2,.15),_accent,true)
	_gate.set_meta("interactive_visual",true)
	var veil := DemoGeometry.material(Color(.47,.67,.61,.18),.3)
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(_gate.get_child(1) as MeshInstance3D).material_override = veil
	CitadelDressing.asset(geometry,"gothic_bay",point,Vector3(.83,.86,.7))
	_gate_shape = _gate.get_child(0) as CollisionShape3D
	_exit_title = DemoGeometry.label(geometry,point+Vector3.UP*3.8,stage_title,32)
	exit_area = Area3D.new()
	exit_area.position = point+Vector3.UP
	exit_area.collision_layer = 16
	exit_area.collision_mask = 2
	geometry.add_child(exit_area)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(4,3,2)
	shape.shape = bounds
	exit_area.add_child(shape)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	process_mode = PROCESS_MODE_PAUSABLE if value else PROCESS_MODE_DISABLED
	if is_instance_valid(geometry):
		if not value and not _collisions_suspended:
			for shape: CollisionShape3D in geometry.find_children("*","CollisionShape3D",true,false):
				_suspended_shapes[shape] = shape.disabled
				shape.set_deferred("disabled",true)
			_collisions_suspended = true
		elif value and _collisions_suspended:
			for shape: CollisionShape3D in _suspended_shapes:
				if is_instance_valid(shape):shape.set_deferred("disabled",_suspended_shapes[shape])
			_suspended_shapes.clear()
			_collisions_suspended = false
	for enemy in enemies:
		enemy.active = value
	# These states may change while the room is suspended. They take precedence
	# over the saved shapes; enabling a room must never close an opened route.
	if is_instance_valid(_gate_shape):_gate_shape.set_deferred("disabled",not value or exit_unlocked)
	_set_bridge(_bridge_open)
	for device in terrain_devices:device.sync_collision_state(value)

func reset_room(player: ParkourPlayer, number: int = 1) -> bool:
	# Validate and snapshot before discarding the existing room or progress.
	if not _build(number):return false
	clear_effects()
	defeated_count = 0
	set_enabled(true)
	for enemy in enemies:
		enemy.player = player
		enemy.cooldown = float(enemy.get_meta("initial_delay_seconds",1.1))
	for device in mechanisms:
		device.player = player
	for device in altars:device.player=player
	for device in terrain_devices:device.player=player
	for anchor in static_anchors:anchor.player=player
	return true

func _extra_altar(point: Vector3) -> void:
	var device := RunAltar.new()
	device.position=point
	geometry.add_child(device)
	device.requested.connect(func(a: RunAltar):altar_requested.emit(a))
	altars.append(device)

func clear_effects() -> void:
	for group in ["friendly_projectiles","hostile_projectiles","transient_effects"]:
		for projectile in get_tree().get_nodes_in_group(group):
			projectile.queue_free()

func _enemy_defeated(_enemy: LanternAcolyte) -> void:
	defeated_count += 1
	_refresh_exit()

func _refresh_exit() -> void:
	if exit_unlocked or (stage == 1 and not _bridge_open):
		return
	# Every formal route is built around a movement/combat core. The altar is
	# intentionally a hard gate: a run that skips its first build cannot clear
	# the room by flattening enemies with the base weapon alone.
	if not is_instance_valid(altar) or not altar.used:
		if is_instance_valid(_exit_title): _exit_title.text = "先在祭坛选择职业构筑"
		return
	if not _has_core_build():
		if is_instance_valid(_exit_title): _exit_title.text = "需要职业核心构筑"
		return
	for enemy in _required_enemies:
		if enemy.health > 0:
			return
	if not _required_enemies.is_empty():
		exit_unlocked = true
		_gate.visible = false
		_gate_shape.set_deferred("disabled",true)
		_exit_title.text = "封印已解"
		cleared.emit()

func _has_core_build() -> bool:
	if not is_instance_valid(altar) or not is_instance_valid(altar.player):
		return false
	var combat_node := altar.player.get_node_or_null("Combat") as PlayerCombat
	if combat_node == null or combat_node.runes.is_empty():
		return false
	for id: StringName in combat_node.runes:
		if bool(RuneCatalog.definition(id).get("core", false)):
			return true
	return false

func objective_text() -> String:
	if not altar.used:
		return "起点祭坛 · E 选择职业循环"
	if not _has_core_build():
		return "回到祭坛选择一枚职业核心构筑"
	if exit_unlocked:
		return "封印已解 · 前往出口"
	var discovered: int=0
	for device in altars:
		if device.used:discovered+=1
	var guardians: int=0
	for enemy in _required_enemies:
		if enemy.health>0:guardians+=1
	var progress := " · 契印 %d/%d · 守卫 %d" % [discovered,altars.size(),guardians]
	if stage == 1:
		if is_instance_valid(altar.player):
			var z := to_local(altar.player.global_position).z
			if z> -45:return "沿右墙前进 · 时限将尽时 SHIFT 续接同墙"
			if z> -73:return "蹬离右墙，接向另一侧墙面"
			if z> -88:return "绕开盾面，击破庭院守卫"
			if z> -108:return "滑过低拱，起跳越过断桥"
			if z> -150:return "瞄准悬锚按 E · 牵引后自动松开，飞向对岸"
			if z> -205:return "沿断桥残壁冲刺 · 抓住高处锚点"
			if z> -240:return "牵引后对准右墙 · 蹬墙接上层平台"
			if z> -272:return "换向左墙 · 钩锁后继续墙跑"
		return "抵达钟塔，处决契印守卫"+progress
	return ("执刑官 · 封印锚" if stage == 2 else "守门者 · 双封印锚")+progress

func interaction_target() -> Node3D:
	if not enabled or not is_instance_valid(altar.player) or not altar.player.control_enabled:
		return null
	var player := altar.player
	var origin := player.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(origin,origin-player.camera.global_basis.z*ParkourGrapple.RANGE,5,[player.get_rid()])
	var contact := player.get_world_3d().direct_space_state.intersect_ray(ray)
	var target := contact.get("collider") as Node3D
	if target is RiftConstruct and target.kind==&"anchor":
		return target if player.grapple.can_begin(target) else null
	if (target is RunAltar or target is RunMechanism or target is TerrainDevice) and not contact.is_empty() and origin.distance_to(contact.position)<=_configuration.mechanisms.interaction_range_m:
		return target
	return player.grapple.best_anchor()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not event.is_action_pressed("interact"):
		return
	if is_instance_valid(altar.player) and altar.player.grapple.active:
		# The interaction press commits the whole grapple traversal. E is not a
		# second manual-release control while the route handoff is in progress.
		return
	var target := interaction_target()
	if target is RunAltar:
		target.request()
	elif target is RunMechanism:
		target.activate()
	elif target is TerrainDevice:
		target.activate()
	elif target is RiftConstruct and target.kind == &"anchor":
		target.activate()
