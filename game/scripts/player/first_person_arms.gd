class_name FirstPersonArms
extends CanvasLayer
## A fixed-FOV foreground keeps the reference carry line stable across world FOVs.
signal item_equipped(hand: StringName, item: Node3D)
signal item_unequipped(hand: StringName)

@export var motion_amount: float = 1.0
var viewport: SubViewport
var model: Node3D
var camera: Camera3D
var player: ParkourPlayer
var _phase: float = 0.0
var _jump: float = 0.0
var _land: float = 0.0
var _dash: float = 0.0
var _wall_jump: float = 0.0
var _wall_jump_side: int = 0
var _wall_blend: float = 0.0
var _running_blend: float = 0.0
var _last_look := Vector2.ZERO
var _sway := Vector2.ZERO
var _custom_arms: Dictionary = {}
var _sockets: Dictionary = {}
var _items: Dictionary = {}
var _definitions: Dictionary = {}
var animation_player: AnimationPlayer
var motion_skeleton: Skeleton3D
var _trail_mesh := ImmediateMesh.new()
var _trail_points: Array[Vector3] = []
var _trail_ages: Array[float] = []
var _edge_base: Node3D
var _edge_tip: Node3D
var _cast_flash: float = 0.0
var _pulse_left: float = 0.0
var _staff_glow: MeshInstance3D
var _staff_ring: MeshInstance3D
var _staff_light: OmniLight3D
var _staff_crystal_material: StandardMaterial3D
var _deform_rig: Node3D
var _rig_clip: StringName = &""
var _rig_blend: float = 1.0
var _previous_bones: Array[Transform3D] = []
var _evolution_root: Node3D
var _evolution_signature: String = ""

const EVOLUTION_LINKS := {
	&"shade_parry": &"shade_duel_riposte",
	&"shade_wall": &"shade_hunt_chain",
	&"shade_slide": &"shade_slide_return",
	&"shade_echo": &"shade_echo_cut",
	&"arcane_storm": &"arcane_storm_tempest",
	&"arcane_shape": &"arcane_shape_recall",
	&"arcane_seal": &"arcane_seal_gate",
	&"arcane_element": &"arcane_fire_shatter",
}


func _ready() -> void:
	layer = 1
	player = get_parent() as ParkourPlayer
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.handle_input_locally = false
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("#adbac0")
	lighting.ambient_light_energy = 0.28
	lighting.ssao_enabled = true
	lighting.ssao_radius = .075
	lighting.ssao_intensity = 1.15
	lighting.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var reflection := ProceduralSkyMaterial.new()
	reflection.sky_top_color = Color("#6f858c")
	reflection.sky_horizon_color = Color("#555853")
	reflection.ground_bottom_color = Color("#191f20")
	reflection.ground_horizon_color = Color("#555853")
	var sky := Sky.new()
	sky.sky_material = reflection
	lighting.sky = sky
	lighting.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.environment = lighting
	viewport.add_child(environment)
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.015
	camera.fov = 65.0
	viewport.add_child(camera)
	for setup: Array in [[Vector3(-30,-35,0), Color("#f1d5a9"), 1.15], [Vector3(10,130,0), Color("#84b6c0"), 0.45]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = setup[0]
		light.light_color = setup[1]
		light.light_energy = setup[2]
		light.shadow_enabled = true
		light.directional_shadow_max_distance = 3.0
		light.shadow_bias = .025
		light.shadow_normal_bias = .03
		viewport.add_child(light)
	model = Node3D.new()
	model.name = "BlenderViewmodel"
	viewport.add_child(model)
	var trail := MeshInstance3D.new()
	trail.mesh = _trail_mesh
	var trail_material := ShaderMaterial.new()
	trail_material.shader=load("res://assets/shaders/weapon_trail.gdshader")
	trail.material_override = trail_material
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(trail)
	_staff_glow = FxMaterials.sprite(model,.35,FxMaterials.glow(Color("#8debc8"),0))
	_staff_ring = FxMaterials.sprite(model,.22,FxMaterials.glow(Color("#a5f3dd"),0,true))
	var glyph := ShaderMaterial.new()
	glyph.shader=preload("res://assets/shaders/staff_glyph.gdshader")
	_staff_ring.material_override=glyph
	_staff_light = OmniLight3D.new()
	_staff_light.light_color = Color("#69dcb4")
	_staff_light.omni_range = 1.4
	_staff_light.light_energy = 0
	model.add_child(_staff_light)
	for hand: StringName in [&"left",&"right"]:
		var arm := Node3D.new()
		arm.name = str(hand).capitalize()+"Wrist"
		model.add_child(arm)
		_custom_arms[hand] = arm
		var socket := Marker3D.new()
		socket.name = "GripSocket"
		arm.add_child(socket)
		_sockets[hand] = socket
	_deform_rig = (load("res://assets/models/blender/first_person_rig.glb") as PackedScene).instantiate() as Node3D
	model.add_child(_deform_rig)
	animation_player = _deform_rig.find_child("AnimationPlayer",true,false) as AnimationPlayer
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	motion_skeleton = _deform_rig.find_child("Skeleton3D",true,false) as Skeleton3D
	for part in _deform_rig.find_children("*","MeshInstance3D",true,false):
		if part.name == "SkinnedArms":
			var cloth := (load("res://assets/materials/pbr/glove.tres") as StandardMaterial3D).duplicate() as StandardMaterial3D
			cloth.albedo_color = Color("#384543")
			cloth.albedo_texture=load("res://assets/materials/pbr/charcoal_weave/albedo.jpg")
			cloth.normal_texture=load("res://assets/materials/pbr/charcoal_weave/normal.jpg")
			cloth.roughness_texture=null
			cloth.uv1_triplanar = false
			cloth.uv1_world_triplanar = false
			cloth.uv1_scale = Vector3.ONE*3
			cloth.normal_scale = .16
			cloth.roughness = .95
			part.set_surface_override_material(0,cloth)
			var glove_material := cloth.duplicate() as StandardMaterial3D
			glove_material.albedo_color = Color("#353731")
			glove_material.albedo_texture=load("res://assets/materials/pbr/brown_leather/albedo.jpg")
			glove_material.normal_texture=load("res://assets/materials/pbr/brown_leather/normal.jpg")
			glove_material.uv1_scale = Vector3.ONE*2
			glove_material.normal_scale = .14
			part.set_surface_override_material(1,glove_material)
		elif str(part.name).begins_with("Glove") or str(part.name).begins_with("Knuckle") or str(part.name).begins_with("Dorsal_glove"):
			var leather := StandardMaterial3D.new()
			leather.albedo_color=Color("#242b28")
			leather.roughness=.92
			leather.normal_enabled=true
			leather.normal_texture=load("res://assets/materials/pbr/brown_leather/normal.jpg")
			leather.normal_scale=.12
			leather.uv1_triplanar=true
			leather.uv1_scale=Vector3.ONE*20
			part.material_override=leather
		elif str(part.name).begins_with("Cuff") or str(part.name).begins_with("Dorsal_seam"):
			var thread := StandardMaterial3D.new()
			thread.albedo_color=Color("#34342d")
			thread.roughness=1
			part.material_override=thread
	player.profile_changed.connect(_apply_class_items)
	player.recovered.connect(reset_motion)
	player.jumped.connect(func(): _jump = 1.0)
	player.dashed.connect(func(): _dash = 1.0)
	player.landed.connect(func(impact: float): _land = clampf(impact / 18.0, 0.0, 1.0))
	player.wall_jumped.connect(_on_wall_jumped)
	_apply_class_items(player.parkour_profile)
	player.ready.connect(func():
		reset_motion()
		_process(0.0)
		var combat := player.get_node("Combat") as PlayerCombat
		combat.rune_applied.connect(func(_id: StringName): _refresh_weapon_evolution())
		combat.runes_reset.connect(_refresh_weapon_evolution)
		combat.swing_started.connect(func(): _cast_flash = 1.0)
		combat.ability_used.connect(func():
			if player.parkour_profile.id==&"arcanist":_pulse_left=.34;_cast_flash=.7)
		combat.arts.performed.connect(func(_kind: StringName): _cast_flash=.6), CONNECT_ONE_SHOT)


func get_hand_socket(hand: StringName) -> Marker3D:
	return _sockets.get(hand) as Marker3D


func muzzle_world_position() -> Vector3:
	var weapon := get_equipped_item(&"right")
	if weapon == null:return player.camera.global_position
	var point := weapon.to_global(Vector3(0,.83,0))
	var pixel := camera.unproject_position(point)
	pixel *= Vector2(player.get_viewport().get_visible_rect().size)/Vector2(viewport.size)
	return player.camera.project_position(pixel,maxf(.1,-camera.to_local(point).z))


func grapple_world_position() -> Vector3:
	var wrist: Node3D=_custom_arms[&"left"]
	var point := wrist.to_global(Vector3(0,.015,0))
	var pixel := camera.unproject_position(point)
	pixel*=Vector2(player.get_viewport().get_visible_rect().size)/Vector2(viewport.size)
	return player.camera.project_position(pixel,maxf(.1,-camera.to_local(point).z))


func get_equipped_item(hand: StringName) -> Node3D:
	return _items.get(hand) as Node3D


func get_item_definition(hand: StringName) -> HeldItemDefinition:
	return _definitions.get(hand) as HeldItemDefinition


func equip_item(hand: StringName, definition: HeldItemDefinition) -> bool:
	if not _sockets.has(hand) or definition == null or definition.scene == null:
		return false
	var instance: Node = definition.scene.instantiate()
	if not instance is Node3D:
		instance.free()
		return false
	unequip_item(hand)
	var item := instance as Node3D
	get_hand_socket(hand).add_child(item)
	item.position = definition.grip_position
	item.rotation_degrees = definition.grip_rotation_degrees
	item.scale = definition.grip_scale
	for part: Node in item.find_children("*","MeshInstance3D",true,false):
		if hand==&"right" and definition.ranged and str(part.name).begins_with("Witchglass"):
			_staff_crystal_material=(part as MeshInstance3D).get_active_material(0).duplicate() as StandardMaterial3D
			(part as MeshInstance3D).material_override=_staff_crystal_material
		elif str(part.name).begins_with("Curved"):
			(part as MeshInstance3D).set_surface_override_material(0,load("res://assets/materials/view_steel.tres"))
		elif str(part.name).begins_with("Crossed") or part.name=="Grip":
			var wrap := (load("res://assets/materials/pbr/glove.tres") as StandardMaterial3D).duplicate() as StandardMaterial3D
			wrap.uv1_triplanar = true
			wrap.uv1_scale = Vector3.ONE*12.0
			wrap.albedo_color = Color("#607876")
			(part as MeshInstance3D).material_override = wrap
	_items[hand] = item
	if hand==&"right" and not definition.ranged:
		_edge_base=item.find_child("CuttingEdgeBase",true,false) as Node3D
		_edge_tip=item.find_child("CuttingEdgeTip",true,false) as Node3D
	_definitions[hand] = definition
	if hand==&"right":
		_evolution_signature=""
		_refresh_weapon_evolution()
	item_equipped.emit(hand, item)
	return true


func unequip_item(hand: StringName) -> void:
	if hand==&"right": _staff_crystal_material=null
	if hand==&"right":_edge_base=null;_edge_tip=null
	if not _items.has(hand):
		return
	var item: Node3D = _items[hand]
	item.get_parent().remove_child(item)
	# Class swaps happen between gameplay states; free synchronously so an old
	# mesh, collision proxy, or weapon socket cannot survive into the next pose.
	item.free()
	_items.erase(hand)
	_definitions.erase(hand)
	item_unequipped.emit(hand)


func _apply_class_items(profile: ParkourProfile) -> void:
	_trail_points.clear()
	_trail_ages.clear()
	_previous_bones.clear()
	_rig_clip = &""
	_cast_flash = 0.0
	_pulse_left = 0.0
	unequip_item(&"left")
	unequip_item(&"right")
	if profile.left_hand_item != null:
		equip_item(&"left", profile.left_hand_item)
	if profile.right_hand_item != null:
		equip_item(&"right", profile.right_hand_item)
	_refresh_weapon_evolution()


func weapon_evolution_state() -> Dictionary:
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	var definition := get_item_definition(&"right")
	if combat==null or definition==null:
		return {"branch":&"", "tier":0, "geometry":0}
	var allowed: Array=[&"arcane_storm",&"arcane_shape",&"arcane_seal",&"arcane_element"] if definition.ranged else [&"shade_parry",&"shade_wall",&"shade_slide",&"shade_echo"]
	var branch: StringName=&""
	for id: StringName in combat.runes:
		if id in allowed:branch=id
	var tier: int=0 if branch==&"" else (2 if EVOLUTION_LINKS.get(branch,&"") in combat.runes else 1)
	if branch==&"arcane_element":
		var elemental_link:StringName={&"fire":&"arcane_fire_shatter",&"ice":&"arcane_ice_nova",&"wind":&"arcane_split",&"lightning":&"arcane_network"}.get(combat.spell_element(),&"")
		tier=2 if elemental_link in combat.runes else 1
	return {"branch":branch,"tier":tier,"geometry":_evolution_root.get_child_count() if is_instance_valid(_evolution_root) else 0}


func weapon_evolution_host() -> Node3D:
	return get_equipped_item(&"right")


func configure_weapon_evolution_root(_root: Node3D) -> void:
	pass


func _refresh_weapon_evolution() -> void:
	# Formal viewmodels provide skin-bound Blender variants. The rejected loose
	# primitive attachment generator is intentionally no longer a fallback.
	if is_instance_valid(_evolution_root):
		_evolution_root.queue_free()
		_evolution_root=null


func _on_wall_jumped(normal: Vector3) -> void:
	_wall_jump = 1.0
	_wall_jump_side = -1 if normal.dot(player.global_basis.x) > 0.0 else 1


func reset_motion() -> void:
	_jump = 0.0
	_land = 0.0
	_dash = 0.0
	_wall_blend = 0.0
	_wall_jump = 0.0
	_running_blend = 0.0
	_sway = Vector2.ZERO
	_rig_clip = &""
	_previous_bones.clear()
	_trail_points.clear()
	_trail_ages.clear()
	_cast_flash = 0
	_pulse_left = 0
	_last_look = Vector2(player.rotation.y, player.head.rotation.x)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_node_ready():
		return
	var look := Vector2(player.rotation.y, player.head.rotation.x)
	var difference := Vector2(wrapf(look.x-_last_look.x,-PI,PI),look.y-_last_look.y)
	_last_look = look
	_sway = _sway.lerp(difference.limit_length(.06),1.0-exp(-12.0*delta))
	var speed: float = clampf(player.horizontal_speed()/player.move_speed,0.0,1.5)
	_phase = fmod(_phase + delta * lerpf(2.0,10.0,speed),TAU)
	_jump = move_toward(_jump,0.0,delta*3.0)
	_land = move_toward(_land,0.0,delta*5.0)
	_dash = move_toward(_dash,0.0,delta*4.0)
	_wall_jump = move_toward(_wall_jump,0.0,delta/.38)
	_pulse_left = move_toward(_pulse_left,0,delta)
	_running_blend = lerpf(_running_blend,speed if player.is_on_floor() else 0.0,1.0-exp(-10.0*delta))
	_wall_blend = lerpf(_wall_blend,float(player.wall_side) if player.is_wall_running() else 0.0,1.0-exp(-10.0*delta))
	_process_rig(delta)

func _process_rig(delta: float) -> void:
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	var item := get_item_definition(&"right")
	var prefix: String = "staff_" if item != null and item.ranged else "blade_"
	var state: String = "idle"
	var sample: float = _phase/TAU
	if player.is_on_floor() and player.horizontal_speed()>1.0:
		state = "run"
	elif not player.is_on_floor():
		state = "jump"
		sample = clampf(1.0-_jump,0.0,1.0)
	if _land>.05:
		state = "land"
		sample = 1.0-_land
	if player.is_dashing():
		state = "dash"
		sample = 1.0-_dash
	if player.is_wall_running():
		state = "wall_left" if player.wall_side<0 else "wall_right"
	if _wall_jump>0.0:
		state = "kick_left" if _wall_jump_side<0 else "kick_right"
		sample = (1.0-_wall_jump)*.4
	if player.crouched:
		state = "slide"
	if player.grapple!=null and player.grapple.active:
		state="grapple"
		sample=.35
	if combat != null and combat.parry_left>0.0:
		state = "parry"
	if _pulse_left>0:
		state="parry"
		sample=.34-_pulse_left
	if combat != null and combat.attacking:
		state = "attack"
		sample = combat.attack_age
		if prefix=="blade_" and combat.swing_return:state="attack_return"
		if prefix=="staff_" and combat.spell_element() in [&"fire",&"ice",&"wind"]:
			state="cast_"+str(combat.spell_element())
		if prefix=="blade_" and combat.arts.slide_window>0 and not combat.swing_return:state="sweep"
	if combat!=null and combat.arts!=null and combat.arts.action_left>0:
		state=combat.arts.action_clip
		sample=combat.arts.action_age
	if combat!=null and combat.arts!=null and combat.arts._held>0 and combat.arts.selected() in [&"wall",&"well",&"anchor"]:
		state="shape"
		sample=.14
	var clip := StringName(prefix+state)
	if not animation_player.has_animation(clip):clip=StringName(prefix+"attack")
	if clip != _rig_clip:
		_previous_bones.clear()
		for i in range(motion_skeleton.get_bone_count()):
			_previous_bones.append(motion_skeleton.get_bone_pose(i))
		_rig_blend = 0.0 if _rig_clip != &"" else 1.0
		_rig_clip = clip
		animation_player.play(clip)
		animation_player.advance(0.0)
	animation_player.seek(clampf(sample,0,animation_player.current_animation_length),true)
	var attack_clip: bool=state in ["attack","attack_return","sweep","execute","blink","cast_fire","cast_ice","cast_wind"]
	_rig_blend = minf(1.0,_rig_blend+delta/(.032 if attack_clip else .085))
	if _rig_blend<1.0:
		for i in range(motion_skeleton.get_bone_count()):
			var pose := _previous_bones[i].interpolate_with(motion_skeleton.get_bone_pose(i),smoothstep(0,1,_rig_blend))
			motion_skeleton.set_bone_pose(i,pose)
	model.position = Vector3(-_sway.x*.30,_sway.y*.22,0)
	motion_skeleton.force_update_all_bone_transforms()
	for hand: StringName in [&"left",&"right"]:
		var index := motion_skeleton.find_bone("hand.R" if hand==&"right" else "hand.L")
		var transform := motion_skeleton.global_transform*motion_skeleton.get_bone_global_pose(index)
		(_custom_arms[hand] as Node3D).global_transform = transform
	_update_trail(combat,delta)
	_update_staff(combat,delta)

func _update_trail(combat: PlayerCombat, delta: float) -> void:
	_trail_mesh.clear_surfaces()
	var weapon := get_equipped_item(&"right")
	if combat==null or weapon==null or get_item_definition(&"right").ranged:
		_trail_points.clear()
		_trail_ages.clear()
		return
	for i in range(_trail_ages.size()):
		_trail_ages[i] += delta
	while not _trail_ages.is_empty() and (_trail_ages[0]>.22 or _trail_ages.size()>28):
		_trail_ages.pop_front()
		_trail_points.pop_front()
		_trail_points.pop_front()
	var action_cut: bool=combat.arts.action_clip in ["execute","blink"] and combat.arts.action_left>0 and combat.arts.action_age>=.075 and combat.arts.action_age<.22
	if (action_cut or (combat.attacking and combat.attack_age>=combat.windup and combat.attack_age<combat.windup+combat.active_time)) and combat.impact_hold<=0:
		if is_instance_valid(_edge_base) and is_instance_valid(_edge_tip):
			_trail_points.append(_edge_base.global_position.lerp(_edge_tip.global_position,.28))
			_trail_points.append(_edge_tip.global_position)
		else:
			_trail_points.append(weapon.to_global(Vector3(0,.52,0)))
			_trail_points.append(weapon.to_global(Vector3(0,1.09,0)))
		_trail_ages.append(0.0)
	if _trail_points.size()<4:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(_trail_points.size()):
		var alpha: float = pow(maxf(0,1-_trail_ages[int(i/2)]/.22),1.35)*.92
		var tint := Color("#d4f6ef") if combat.arts.edge>.5 else Color("#c7c5bd")
		_trail_mesh.surface_set_color(Color(tint.r,tint.g,tint.b,alpha))
		_trail_mesh.surface_set_uv(Vector2(float(i%2),float(i/2)/maxi(1,_trail_ages.size()-1)))
		_trail_mesh.surface_add_vertex(_trail_points[i])
	_trail_mesh.surface_end()

func _update_staff(combat: PlayerCombat, delta: float) -> void:
	_cast_flash = maxf(0,_cast_flash-delta*7)
	var item := get_item_definition(&"right")
	var enabled: bool = item!=null and item.ranged and combat!=null
	_staff_glow.visible = enabled
	_staff_ring.visible = enabled
	_staff_light.visible = enabled
	if not enabled:
		return
	var weapon := get_equipped_item(&"right")
	var point := weapon.to_global(Vector3(0,.83,0))
	_staff_glow.global_position = point
	_staff_ring.global_position = point
	_staff_light.global_position = point
	FxMaterials.face_camera(_staff_glow)
	FxMaterials.face_camera(_staff_ring)
	var charge: float = combat.charge_progress/combat.charge_duration()
	var windup_charge: float=sin(clampf(combat.attack_age/combat.windup,0,1)*PI*.5) if combat.attacking and combat.attack_age<combat.windup else 0.0
	var energy: float = .06+charge*.6+windup_charge*.3+_cast_flash*.85
	var tint := combat.spell_color()
	if _staff_crystal_material!=null:
		_staff_crystal_material.albedo_color=tint.darkened(.5)
		_staff_crystal_material.emission=tint
	(_staff_glow.material_override as ShaderMaterial).set_shader_parameter("tint",tint)
	(_staff_ring.material_override as ShaderMaterial).set_shader_parameter("tint",tint)
	(_staff_ring.material_override as ShaderMaterial).set_shader_parameter("element",float([&"arcane",&"fire",&"ice",&"wind"].find(combat.spell_element())))
	_staff_light.light_color = tint
	(_staff_glow.material_override as ShaderMaterial).set_shader_parameter("strength",energy)
	(_staff_ring.material_override as ShaderMaterial).set_shader_parameter("strength",windup_charge*.8+charge*.65+_cast_flash*.8)
	_staff_ring.scale = Vector3.ONE*(1.6+_cast_flash*.8)
	_staff_light.light_energy = energy*.4
