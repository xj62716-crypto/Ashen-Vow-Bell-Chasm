extends FirstPersonArms
## Opt-in R15/R12 art adapter. Preserves equipment and authoritative combat.
const TUNING = preload("res://viewmodel_r16/default.tres")
const BLADE_MODEL: PackedScene = preload("res://viewmodel_refit/blade.glb")
const STAFF_MODEL: PackedScene = preload("res://viewmodel_r3_staff/staff.glb")
var tuning:Resource = TUNING.duplicate(true)
var rigs:Dictionary = {}
var active_kind:String = ""
var active_rig:Node3D
var sockets:Dictionary = {}
var clip_name:String = ""
var clip_time:float = 0.0
var transition_age:float = 0.0
var source_pose:Array[Transform3D] = []
var event_map:Dictionary = {}
var events:Array[Dictionary] = []
var motion_clock:float = 0.0
var transient:String = ""
var transient_age:float = 0.0
var ability_kind:String = ""
var ability_age:float = 0.0
var parry_age:float = 0.0
var previous_parry:bool = false
var previous_attack_id:int = -1
var previous_attack_end:float = -10.0
var combo_return:bool = false
var was_attacking:bool = false
var new_trail:MeshInstance3D
var trail_shader:ShaderMaterial
var trail_samples:Array[Dictionary] = []
var blade_active:bool = false
var release_samples:Array[Dictionary] = []
var blade_grips:Dictionary = {}
var refit_meshes:Dictionary = {}
var left_meshes:Dictionary = {}
var rune_materials:Array[ShaderMaterial] = []
var inherited_emission:Array[Dictionary] = []
var left_weight:float = 0.0
var left_hold:float = 0.0
var interaction_left:float = 0.0
var unmoved_pose:Array[Transform3D] = []
var weapon_effects_enabled:bool = true
var weapon_release:float = 0.0
var weapon_hit:float = 0.0
var weapon_readiness:float = 0.0
var refit_signature:String = ""
var last_motion_state:String = "idle"
var rewind_ready:bool = false
var blade_echo_shader:ShaderMaterial
var blade_environment:Environment
var blade_powered:bool=false
var previous_edge_tip:Vector3=Vector3.ZERO
var blade_contact_direction:Vector3=Vector3.RIGHT
var prime_powered_trail:bool=false
var r3_arc_shader:ShaderMaterial
var r3_hit_age:float=1.
var r3_hit_sign:float=1.

func _ready() -> void:
	super._ready()
	for node in viewport.get_children():
		if node is WorldEnvironment:blade_environment=node.environment
	process_priority = 20
	_deform_rig.hide()
	_staff_glow.hide();_staff_ring.hide();_staff_light.hide()
	for wrist in _custom_arms.values():wrist.hide()
	for kind in ["blade","staff"]:
		var source:PackedScene=STAFF_MODEL if kind=="staff" else BLADE_MODEL
		var rig:=source.instantiate() as Node3D
		assert(rig != null)
		model.add_child(rig);rig.hide();rigs[kind]=rig
		refit_meshes[kind]=rig.find_children("*","MeshInstance3D",true,false)
		left_meshes[kind]=[]
		for part:MeshInstance3D in refit_meshes[kind]:
			if str(part.name).begins_with("Left__"):
				left_meshes[kind].append(part);part.hide()
			if "Rune_" in str(part.name):
				var original:=part.get_active_material(0) as StandardMaterial3D
				var etched:=ShaderMaterial.new();etched.shader=preload("res://viewmodel_refit/etched_rune.gdshader")
				etched.set_shader_parameter("inlay_color",original.albedo_color if original else Color("90734b"))
				etched.set_shader_parameter("flow_direction",-1.0 if "echo" in str(part.name) else 1.0)
				part.material_override=etched;rune_materials.append(etched)
			elif str(part.name).contains("focus") or str(part.name).contains("quartz") or str(part.name).contains("blackglass"):
				if str(part.name).begins_with("Crown_") or str(part.name).begins_with("Build_"):
					var original:=part.get_active_material(0) as StandardMaterial3D
					var quartz:=ShaderMaterial.new();quartz.shader=preload("res://viewmodel_refit/quartz.gdshader")
					quartz.set_shader_parameter("mineral",original.albedo_color if original else Color("6e878c"))
					part.material_override=quartz;rune_materials.append(quartz)
			elif str(part.name).begins_with("Crown_") or str(part.name).begins_with("Base__"):
				var original:=part.get_active_material(0) as StandardMaterial3D
				if original and "Refit" in original.resource_name:
					var finish:=original.duplicate() as StandardMaterial3D
					if "iron" in original.resource_name or "silver" in original.resource_name or "bronze" in original.resource_name:
						finish.roughness_texture=load("res://viewmodel_r16/models/blade_guard-roughness.png")
						finish.normal_enabled=true;finish.normal_texture=load("res://viewmodel_r16/models/blade_guard-normal.png");finish.normal_scale=.25
						finish.uv1_triplanar=true;finish.uv1_scale=Vector3.ONE*14
					part.material_override=finish
			# Preserved heritage materials must obey the same effects-off switch
			# as the new inlays, including the R12 crystal's buried ember.
			for surface in part.mesh.get_surface_count():
				var surface_material:Material=part.get_active_material(surface)
				if surface_material is StandardMaterial3D and surface_material.emission_enabled:
					var material:StandardMaterial3D=surface_material.duplicate()
					part.set_surface_override_material(surface,material)
					inherited_emission.append({"material":material,"energy":material.emission_energy_multiplier})
	var blade_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://viewmodel_r16/blade-events.json"))
	for row in blade_data.events:event_map[row.clip]=row
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://viewmodel_r16/staff-events.json")):event_map[row.clip]=row
	new_trail=MeshInstance3D.new();new_trail.mesh=ImmediateMesh.new()
	trail_shader=ShaderMaterial.new();trail_shader.shader=preload("res://viewmodel_r16/blade_trail.gdshader")
	r3_arc_shader=ShaderMaterial.new();r3_arc_shader.shader=preload("res://viewmodel_r16/blade_arc_r3.gdshader")
	blade_echo_shader=trail_shader.duplicate();blade_echo_shader.set_shader_parameter("ghost",1.0)
	new_trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(new_trail)
	player.slide_jumped.connect(func():set_transient("slide_jump"))
	player.wall_run_started.connect(func(_side:int):
		# Reattachment is the current wall state, never a replay of the authored demo chain.
		_wall_jump=0;_dash=0;transient="")
	player.ready.connect(bind_combat,CONNECT_ONE_SHOT)
	select_rig()

func bind_combat() -> void:
	var combat:=player.get_node("Combat") as PlayerCombat
	combat.swing_started.connect(on_release)
	combat.arts.performed.connect(on_ability)
	combat.parried.connect(func():set_transient("parry_hit"))
	combat.parried.connect(func():weapon_hit=1.0)
	combat.hit_confirmed.connect(func(_target:Node3D,_point:Vector3,_defeated:bool):weapon_hit=1.0)
	combat.hit_confirmed.connect(blade_contact_accent)
	combat.spell_contact.connect(func(_element:StringName):weapon_hit=1.0)
	combat.ability_used.connect(func():
		if active_kind=="staff":on_ability(&"quick_cast"))
	combat.temporal_reset_requested.connect(reset_motion)
	combat.died.connect(reset_motion)
	player.grapple.released.connect(func():set_transient("grapple_release"))
	var rewind:=player.get_node_or_null("PositionRewind")
	if rewind:
		rewind.rewound.connect(func(_a:Vector3,_b:Vector3,_c:PackedVector3Array):set_transient("rewind"))
		rewind.state_changed.connect(func(value:Dictionary):rewind_ready=value.ready)

func _unhandled_input(event:InputEvent) -> void:
	if event.is_action_pressed("interact") and player.control_enabled:interaction_left=.28

func set_transient(value:String) -> void:
	transient=value;transient_age=0

func apply_motion_profile(candidate:Resource) -> bool:
	if candidate==null or candidate.get_script()!=tuning.get_script() or not candidate.validation_errors().is_empty():return false
	tuning=candidate.duplicate(true)
	return true

func select_rig() -> void:
	var kind:String="staff" if player.parkour_profile.id==&"arcanist" else "blade"
	if kind==active_kind:return
	active_kind=kind
	for key in rigs:rigs[key].visible=key==kind
	active_rig=rigs[kind]
	left_weight=0;left_hold=0;unmoved_pose.clear();refit_signature=""
	animation_player=active_rig.find_child("AnimationPlayer",true,false)
	motion_skeleton=active_rig.find_child("Skeleton3D",true,false)
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sockets.clear()
	for key in ["edge_root","edge_tip","cast_palm","spell_origin","left_palm_contact","grip_left_contact"]:
		sockets[key]=active_rig.find_child(key,true,false)
	_evolution_signature=""
	_refresh_weapon_evolution()
	clip_name="";source_pose.clear();trail_samples.clear();previous_attack_id=-1
	prime_powered_trail=false;previous_edge_tip=Vector3.ZERO;blade_powered=false
	if is_instance_valid(player):
		player.blade_camera_angles=Vector3.ZERO;player.blade_camera_translation=Vector3.ZERO;player.blade_camera_fov=0.
		player.blade_arrival_left=0.;player.blade_arrival_offset=Vector3.ZERO
	if kind=="blade" and blade_grips.is_empty():
		animation_player.play("blade_ready");animation_player.advance(0);animation_player.seek(1.0/120.0,true)
		motion_skeleton.force_update_all_bone_transforms()
		var weapon:Transform3D=motion_skeleton.get_bone_global_pose(motion_skeleton.find_bone("weapon.R"))
		for side in ["L","R"]:
			var hand:Transform3D=motion_skeleton.get_bone_global_pose(motion_skeleton.find_bone("hand."+side))
			blade_grips[side]=weapon.affine_inverse()*(hand*Vector3(0,.097,.024))

func weapon_evolution_host() -> Node3D:
	if not is_instance_valid(motion_skeleton):return super.weapon_evolution_host()
	if active_kind=="staff":
		var grip:=active_rig.find_child("grip_primary",true,false) as Node3D
		if grip!=null:return grip
	var bone_name:StringName=&"weapon.R"
	if motion_skeleton.find_bone(bone_name)<0:return super.weapon_evolution_host()
	var socket:=motion_skeleton.get_node_or_null("BuildEvolutionSocket") as BoneAttachment3D
	if socket==null:
		socket=BoneAttachment3D.new();socket.name="BuildEvolutionSocket";socket.bone_name=bone_name
		motion_skeleton.add_child(socket)
	else:socket.bone_name=bone_name
	return socket

func configure_weapon_evolution_root(root: Node3D) -> void:
	root.scale=Vector3.ONE

func weapon_evolution_state() -> Dictionary:
	var state:Dictionary=super.weapon_evolution_state()
	var names:Array[String]=[]
	for part:MeshInstance3D in refit_meshes.get(active_kind,[]):
		var label:=str(part.name)
		if part.visible and (label.begins_with("Build_") or (label.begins_with("Crown_") and not label.begins_with("Crown_base"))):names.append(label)
	state.geometry=names.size();state.parts=names
	return state

func _refresh_weapon_evolution() -> void:
	# Replaces the rejected runtime primitive attachments. All variants are authored
	# in Blender and skin-bound to the same bone as the original physical weapon.
	if active_kind=="" or not refit_meshes.has(active_kind):return
	var combat:=player.get_node_or_null("Combat") as PlayerCombat
	if combat==null:return
	var state:Dictionary=super.weapon_evolution_state()
	var signature:="%s:%d:%s"%[state.branch,state.tier,combat.spell_element()]
	if signature==refit_signature:return
	refit_signature=signature
	var key:=str(state.branch)
	if key=="arcane_element":key+="_"+str(combat.spell_element())
	for part:MeshInstance3D in refit_meshes[active_kind]:
		var label:=str(part.name)
		if label.begins_with("Build_"):
			part.visible=label.begins_with("Build_"+key+"_1__") or (state.tier==2 and label.begins_with("Build_"+key+"_2__"))
		elif label.begins_with("Crown_"):
			part.visible=(state.tier==0 and label.begins_with("Crown_base__")) or label.begins_with("Crown_"+key+"_1__") or (state.tier==2 and label.begins_with("Crown_"+key+"_2__"))

func update_left_hand(delta:float,state:String,combat:PlayerCombat) -> void:
	interaction_left=maxf(0,interaction_left-delta)
	var required:bool=combat.attacking or combat.parry_left>0 or interaction_left>0 or (player.grapple and player.grapple.active)
	required=required or state in ["parry_hit","parry_exit","grapple_release","shape","seal","detonate","storm","charge","execute","blink","rewind"]
	required=required or (ability_kind!="" and ability_age<.4 and state==ability_kind)
	# During a wall-run the left hand is only visible when the character is
	# actually bracing against the left-side wall. A right-side wall-run keeps
	# the support hand stowed, matching the first-person movement silhouette.
	if tuning.left_special_parkour:
		required=required or state=="wall_left"
		required=required or state in ["kick_left","kick_right","slide","slide_jump"]
	# Withdraw during the end of recovery so pure locomotion does not inherit a
	# hand parked on the lower screen edge. A buffered next cut retains its grip.
	var recovering:bool=combat.attacking and combat.attack_buffer<=0 and combat.attack_age>=combat.duration()-tuning.left_exit_seconds
	if recovering:required=false;left_hold=0
	if active_kind=="blade" and tuning.blade_sample_r3 and state in ["attack","execute"] and clip_time>(.18 if state=="attack" else .23):
		required=false;left_hold=0
	if active_kind=="blade" and authored_grip(state) and clip_time>float(event_map["blade_"+state].get("support_release_s",.25)):
		required=false;left_hold=0
	if required:left_hold=tuning.left_action_hold_seconds
	else:left_hold=maxf(0,left_hold-delta)
	var duration:float=tuning.left_enter_seconds if required or left_hold>0 else tuning.left_exit_seconds
	if active_kind=="blade" and tuning.blade_sample_r3 and not required and state in ["attack","execute"]:duration=tuning.blade_left_release_seconds
	left_weight=move_toward(left_weight,1.0 if required or left_hold>0 else 0.0,delta/maxf(.001,duration))
	var blend:float=smoothstep(0,1,left_weight)*tuning.left_action_weight
	var bone:int=motion_skeleton.find_bone("upper_arm.L")
	if bone>=0:
		var pose:Transform3D=motion_skeleton.get_bone_global_pose(bone)
		pose.origin+=tuning.left_stow_offset*(1-blend)+tuning.left_action_offset*blend
		motion_skeleton.set_bone_global_pose(bone,pose)
	for part:MeshInstance3D in left_meshes[active_kind]:part.visible=blend>.001
	sync_attachments()

func update_weapon_inlays(delta:float,combat:PlayerCombat) -> void:
	weapon_release=maxf(0,weapon_release-delta*6.0);weapon_hit=maxf(0,weapon_hit-delta*4.0)
	var ready:float=0.0
	if active_kind=="blade":ready=maxf(combat.arts.edge,float(combat.riposte_ready))
	else:ready=maxf(float(combat.charge_ready),combat.charge_progress/maxf(.01,combat.charge_duration()))
	var branch:StringName=super.weapon_evolution_state().branch
	match branch:
		&"shade_parry":ready=maxf(ready,float(combat.arts.counter_left>0))
		&"shade_slide":ready=maxf(ready,float(combat.arts.slide_window>0))
		&"shade_echo":ready=maxf(ready,float(rewind_ready))
		&"arcane_shape":ready=maxf(ready,float(combat.arts._preview_valid and combat.arts._held>0))
		&"arcane_seal":ready=maxf(ready,float(not combat.arts.marks.is_empty()))
		&"arcane_storm":ready=maxf(ready,float(not player.is_on_floor() and combat.arts.mana>=12))
	weapon_readiness=clampf(ready,0,1)
	for shader in rune_materials:
		shader.set_shader_parameter("clock_seconds",motion_clock)
		shader.set_shader_parameter("readiness",weapon_readiness)
		shader.set_shader_parameter("release_strength",maxf(weapon_release,weapon_hit))
		shader.set_shader_parameter("effect_weight",1.0 if weapon_effects_enabled else 0.0)
	for entry in inherited_emission:
		entry.material.emission_energy_multiplier=entry.energy if weapon_effects_enabled else 0.0

func left_hand_state() -> Dictionary:
	return {"state":last_motion_state,"weight":left_weight,"visible_meshes":left_meshes.get(active_kind,[]).filter(func(part):return part.visible).size(),"mesh_count":left_meshes.get(active_kind,[]).size()}

func reset_motion() -> void:
	super.reset_motion()
	if is_instance_valid(motion_skeleton) and unmoved_pose.size()==motion_skeleton.get_bone_count():
		for bone in range(unmoved_pose.size()):motion_skeleton.set_bone_pose(bone,unmoved_pose[bone])
	transient="";ability_kind="";previous_parry=false;parry_age=0
	clip_name="";source_pose.clear();trail_samples.clear();blade_active=false
	prime_powered_trail=false;previous_edge_tip=Vector3.ZERO;blade_powered=false
	blade_contact_direction=Vector3.RIGHT
	was_attacking=false;previous_attack_id=-1;previous_attack_end=-10;combo_return=false
	left_weight=0;left_hold=0;interaction_left=0;unmoved_pose.clear();weapon_release=0;weapon_hit=0;rewind_ready=false
	for parts:Array in left_meshes.values():
		for part:MeshInstance3D in parts:part.hide()
	if is_instance_valid(new_trail):(new_trail.mesh as ImmediateMesh).clear_surfaces()
	if is_instance_valid(player):
		player.attack_body_turn=0;player.blade_camera_angles=Vector3.ZERO
		player.blade_camera_translation=Vector3.ZERO;player.blade_camera_fov=0.
		player.blade_arrival_left=0.;player.blade_arrival_offset=Vector3.ZERO
	r3_hit_age=1.

func on_ability(kind:StringName) -> void:
	var aliases:Dictionary={"mark":"seal","shape_wall":"shape","shape_well":"shape","shape_anchor":"shape","shape_platform":"shape","tempest":"storm","sweep_return":"rewind"}
	ability_kind=aliases.get(str(kind),str(kind));ability_age=0
	prime_powered_trail=active_kind=="blade" and ability_kind in ["execute","blink"]
	weapon_release=1.0

func on_release() -> void:
	# Called synchronously before a spell is spawned. Refresh the animated muzzle now.
	_process_rig(0.0)
	weapon_release=1.0
	release_samples.append({"clip":clip_name,"time":clip_time,"muzzle":str(muzzle_world_position())})
	while release_samples.size()>32:release_samples.pop_front()

func to_world(point:Vector3) -> Vector3:
	var pixel:=camera.unproject_position(point)
	pixel*=Vector2(player.get_viewport().get_visible_rect().size)/Vector2(viewport.size)
	return player.camera.project_position(pixel,maxf(.1,-camera.to_local(point).z))

func muzzle_world_position() -> Vector3:
	if is_instance_valid(sockets.get("spell_origin")):return to_world(sockets.spell_origin.global_position)
	return super.muzzle_world_position()

func grapple_world_position() -> Vector3:
	if is_instance_valid(sockets.get("cast_palm")):return to_world(sockets.cast_palm.global_position)
	return super.grapple_world_position()

func phase_map(age:float,from:PackedFloat32Array,to:PackedFloat32Array) -> float:
	for i in range(1,from.size()):
		if age<=from[i]:return lerpf(to[i-1],to[i],clampf((age-from[i-1])/maxf(.0001,from[i]-from[i-1]),0,1))
	return to[-1]

func attack_sample(combat:PlayerCombat,clip:String) -> float:
	var row:Dictionary=event_map[clip]
	if active_kind=="staff":
		return phase_map(combat.attack_age,PackedFloat32Array([0,combat.windup,combat.duration()]),PackedFloat32Array([0,row.release_s,row.end_s]))
	var cut:Dictionary=row.cuts[1 if clip=="blade_combo" else 0]
	var offset:float=float(row.get("return_start_s",.4)) if clip=="blade_combo" else 0.0
	# Melee's first actual overlap check is windup + .05 in this pinned combat version.
	return phase_map(combat.attack_age,PackedFloat32Array([0,combat.windup,combat.windup+minf(.05,combat.active_time*.8),combat.windup+combat.active_time,combat.duration()]),PackedFloat32Array([offset,cut.active_start_s,cut.nominal_contact_s,cut.active_end_s,row.duration_s]))

func authored_grip(state:String)->bool:
	return bool(event_map.get("blade_"+state,{}).get("authored_grip",false))

func _process_rig(delta:float) -> void:
	if rigs.is_empty():return
	select_rig()
	var combat:=player.get_node_or_null("Combat") as PlayerCombat
	if combat==null:return
	motion_clock+=delta;transient_age+=delta;ability_age+=delta
	r3_hit_age+=delta
	camera.fov=tuning.blade_viewmodel_fov if active_kind=="blade" else tuning.viewmodel_fov
	if blade_environment:
		blade_environment.glow_enabled=active_kind=="blade" and weapon_effects_enabled and tuning.blade_bloom_contribution>0
		blade_environment.glow_intensity=tuning.blade_bloom_contribution
	active_rig.visible=combat.health>0
	if combat.health<=0:
		trail_samples.clear();(new_trail.mesh as ImmediateMesh).clear_surfaces();return
	var state:String="idle";var sample:float=0.0
	var running:bool=player.is_on_floor() and player.horizontal_speed()>1.0
	if running:state="run";sample=fmod(motion_clock*clampf(player.horizontal_speed()/player.move_speed,.5,1.5),.8)
	elif not player.is_on_floor():state="air";sample=.22
	if _land>.05:state="land";sample=(1.0-_land)*.3
	if player.is_dashing():state="dash";sample=(1.0-_dash)*.25
	if player.is_wall_running():state="wall_left" if player.wall_side<0 else "wall_right";sample=fmod(motion_clock,.7)
	if _wall_jump>0:
		state="kick_left" if _wall_jump_side<0 else "kick_right";sample=(1.0-_wall_jump)*.38
	if player.crouched:state="slide";sample=.2
	if player.grapple and player.grapple.active:state="grapple";sample=minf(player.grapple.age,.35)
	var transient_end:float=float(event_map.get("blade_rewind",{}).get("duration_s",.6)) if transient=="rewind" else .32
	if transient!="" and transient_age<transient_end:
		state=transient;sample=transient_age
	var parrying:bool=active_kind=="blade" and combat.parry_left>0
	if parrying:
		parry_age=parry_age+delta if previous_parry else 0.0
		state="parry" if parry_age<.13 else "parry_hold";sample=parry_age if parry_age<.13 else .1
	elif previous_parry:set_transient("parry_exit");state="parry_exit";sample=0
	previous_parry=parrying
	if transient=="parry_hit" and transient_age<.24:state=transient;sample=transient_age
	if active_kind=="staff" and combat.arts._held>0 and combat.arts.selected() in [&"wall",&"well",&"anchor",&"platform"]:
		state="shape";sample=minf(combat.arts._held,.3)
	elif active_kind=="staff" and combat.charge_progress>0 and not combat.charge_ready:
		state="charge";sample=minf(.3,combat.charge_progress)
	if active_kind=="blade" and combat.arts._held>0 and combat.arts.selected() in [&"hunt",&"counter"]:
		state="execute" if combat.arts.selected()==&"hunt" else "blink"
		sample=minf(combat.arts._held,.152)
	if ability_kind!="" and ability_age<.4 and animation_player.has_animation(active_kind+"_"+ability_kind):
		state=ability_kind
		var row:Dictionary=event_map.get(active_kind+"_"+state,{})
		# Arts currently report success after committing gameplay. Show release/recovery;
		# do not invent a windup after the spell or execution already happened.
		var release:float=row.get("release_s",.205)
		sample=release+ability_age
		if active_kind=="blade" and row.has("cuts"):
			sample=float(row.cuts[0].nominal_contact_s)+ability_age
	if active_kind=="blade" and combat.arts.execution_active:
		state="execute"
		var cut:Dictionary=event_map["blade_execute"].cuts[0]
		sample=phase_map(combat.arts.execution_age,PackedFloat32Array([0.,combat.arts.execution_seconds*.55,combat.arts.execution_seconds]),PackedFloat32Array([combat.arts.execution_start_sample,float(cut.active_start_s),float(cut.nominal_contact_s)]))
	if combat.attacking:
		if combat.attacks!=previous_attack_id:
			combo_return=active_kind=="blade" and combat.swing_return and motion_clock-previous_attack_end<.12
			previous_attack_id=combat.attacks
		state="attack_return" if combat.swing_return else "attack"
		if active_kind=="staff":state="cast_"+str(combat.spell_element()) if combat.spell_element()!=&"arcane" else "quick_cast"
		elif combo_return:state="combo"
		elif combat._attack_slide and not combat.swing_return:state="sweep"
		elif combat.arts.action_clip=="sweep" and combat.arts.action_left>0:state="sweep"
		sample=attack_sample(combat,active_kind+"_"+state)
		if active_kind=="blade" and not combat.swing_return and combat.attack_buffer>0 and combat.attack_age>combat.windup+combat.active_time:
			state="combo"
			var combo_row:Dictionary=event_map["blade_combo"]
			sample=lerpf(float(combo_row.cuts[0].active_end_s),float(combo_row.get("return_start_s",.4)),clampf((combat.attack_age-combat.windup-combat.active_time)/maxf(.001,combat.recovery_time),0,1))
		previous_attack_end=motion_clock
	if interaction_left>0 and not combat.attacking and state in ["idle","run","air"]:state="grapple";sample=minf(.28,.28-interaction_left)
	was_attacking=combat.attacking
	var chosen:String=active_kind+"_"+state
	if not animation_player.has_animation(chosen):chosen=active_kind+"_idle";sample=0
	if prime_powered_trail and state in ["execute","blink"] and weapon_effects_enabled:
		# Instant travel/contact is authoritative on skill release. Fill the swept
		# visual from this clip's real edge sockets, without additional hit checks.
		trail_samples.clear()
		var contact:float=event_map[chosen].cuts[0].nominal_contact_s
		var start:float=event_map[chosen].cuts[0].active_start_s
		for index in range(6):
			pose_at(chosen,lerpf(start,contact,index/5.),1.,true)
			trail_samples.append({"a":sockets.edge_root.global_position,"b":sockets.edge_tip.global_position,"age":(5-index)*.009,"speed":35.,"powered":true})
		prime_powered_trail=false
	if not weapon_effects_enabled:prime_powered_trail=false
	pose_at(chosen,sample,delta,combat.attacking)
	if active_kind=="blade" and combat.attacking and not authored_grip(state) and not (tuning.blade_sample_r3 and state in ["attack","execute"]):
		# Independent quaternion interpolation can open a closed two-hand chain.
		# Re-solve the authored upper/forearm lengths against the weapon's grip frame.
		# The sampled elbow remains the pole; no new twist or invented grip offset.
		var weapon:Transform3D=motion_skeleton.get_bone_global_pose(motion_skeleton.find_bone("weapon.R"))
		var weight:float=smoothstep(0.0,minf(.06,combat.windup*.8),combat.attack_age)*tuning.blade_grip_weight
		for side in ["R","L"]:
			var current:Transform3D=motion_skeleton.get_bone_global_pose(motion_skeleton.find_bone("hand."+side))
			var target:Transform3D=current
			# Preserve the independently authored wrist pronation. Only close the palm contact.
			var adjustment:Vector3=tuning.blade_grip_right_offset if side=="R" else tuning.blade_grip_left_offset
			target.origin=weapon*(blade_grips[side]+adjustment)-current.basis*Vector3(0,.097,.024)
			solve_arm(side,current.interpolate_with(target,weight))
		sync_attachments()
	elif active_kind=="blade" and (authored_grip(state) or (tuning.blade_sample_r3 and state in ["attack","execute"])):
		# R3 already closes its two grips in Blender. Old ready-pose IK would
		# override the newly authored support grip and its release trajectory.
		var weapon:Transform3D=motion_skeleton.get_bone_global_pose(motion_skeleton.find_bone("weapon.R"))
		for side:String in ["R","L"]:
			var offset:Vector3=tuning.blade_grip_right_offset if side=="R" else tuning.blade_grip_left_offset
			if offset.length_squared()>.0000001:
				var target:Transform3D=motion_skeleton.get_bone_global_pose(motion_skeleton.find_bone("hand."+side))
				target.origin+=weapon.basis*offset*tuning.blade_grip_weight
				solve_arm(side,target)
		sync_attachments()
	unmoved_pose.clear()
	for bone in range(motion_skeleton.get_bone_count()):unmoved_pose.append(motion_skeleton.get_bone_pose(bone))
	last_motion_state=state
	update_left_hand(delta,state,combat)
	_refresh_weapon_evolution()
	update_weapon_inlays(delta,combat)
	model.position=tuning.carry_offset+Vector3(-_sway.x,_sway.y,0)*tuning.sway_strength
	for hand:StringName in [&"left",&"right"]:
		var bone:int=motion_skeleton.find_bone("hand.L" if hand==&"left" else "hand.R")
		_custom_arms[hand].global_transform=motion_skeleton.global_transform*motion_skeleton.get_bone_global_pose(bone)
		_custom_arms[hand].hide()
	if active_kind=="staff" and is_instance_valid(sockets.get("cast_palm")):
		_sockets[&"left"].global_transform=sockets.cast_palm.global_transform
	var torso:int=motion_skeleton.find_bone("upper_arm.R")
	var body_turn:float=0.0
	if torso>=0 and combat.attacking and not authored_grip(state) and not (tuning.blade_sample_r3 and state in ["attack","execute"]):
		var pose_basis:Basis=motion_skeleton.get_bone_global_pose(torso).basis
		var rest_basis:Basis=motion_skeleton.get_bone_global_rest(torso).basis
		# Rest-relative order matters: the authored clavicle turn is local to its rest frame.
		var relative:Basis=rest_basis.inverse()*pose_basis
		body_turn=clampf(relative.get_euler().y,-.6,.6)*tuning.body_camera_strength
	player.attack_body_turn=body_turn
	blade_active=active_kind=="blade" and combat.attacking and combat.attack_age>=combat.windup and combat.attack_age<combat.windup+combat.active_time
	blade_powered=active_kind=="blade" and (state in ["execute","blink"] or (state=="sweep" and combat.arts.action_clip=="sweep" and combat.arts.action_left>0))
	if active_kind=="blade" and not combat.attacking and state in ["execute","blink","rewind"]:
		var action_row:Dictionary=event_map.get(chosen,{})
		for cut:Dictionary in action_row.get("cuts",[]):
			blade_active=blade_active or (sample>=float(cut.active_start_s) and sample<=float(cut.active_end_s))
	var camera_goal:=Vector3.ZERO
	if active_kind=="blade" and (combat.attacking or blade_powered):
		var reverse:bool=state in ["attack_return","blink"] or state=="combo"
		var local_age:float=sample-(.4 if state=="combo" else 0.)
		var strike:float=smoothstep(.12,.27,local_age)*2.-1.
		var pulse:float=smoothstep(.02,.12,local_age)*(1.-smoothstep(.30,.55,local_age))
		var sign_value:float=-1. if reverse else 1.
		camera_goal=Vector3(deg_to_rad(tuning.blade_camera_pitch_degrees)*strike,deg_to_rad(tuning.blade_camera_yaw_degrees)*strike*sign_value,deg_to_rad(tuning.blade_camera_roll_degrees)*strike*sign_value)*pulse
	player.blade_camera_angles=player.blade_camera_angles.lerp(camera_goal,1.-exp(-tuning.blade_camera_settle*delta))
	if active_kind=="blade" and tuning.blade_sample_r3:
		update_sample_camera(state,sample,delta)
	update_blade_trail(delta,combat)

func update_sample_camera(state:String,sample:float,delta:float)->void:
	if not state in ["attack","execute"]:
		player.blade_camera_translation=player.blade_camera_translation.lerp(Vector3.ZERO,1.-exp(-24.*delta))
		player.blade_camera_fov=lerpf(player.blade_camera_fov,0.,1.-exp(-24.*delta))
		return
	var angles:=Vector3.ZERO;var shift:=Vector3.ZERO;var fov:float=0.
	if state in ["attack","execute"]:
		var powered:bool=state=="execute"
		var start:float=.16 if powered else .11
		var contact:float=.222 if powered else .172
		var end:float=.30 if powered else .26
		var load:float=smoothstep(0.,start,sample)
		var strike:float=smoothstep(start,contact+.025,sample)
		var recover:float=1.-smoothstep(end,end+.14,sample)
		var body:float=(-.32*load+strike)*recover
		var strength:float=1.35 if powered else 1.
		angles=Vector3(deg_to_rad(1.6)*body,deg_to_rad(-tuning.blade_cut_yaw)*body,deg_to_rad(-tuning.blade_cut_roll)*body)*strength
		shift=Vector3(-.4*body,0.,-sin(strike*PI)*recover)*tuning.blade_cut_camera_travel*strength
		fov=sin(strike*PI)*recover*tuning.blade_cut_fov*strength
	var hit:float=exp(-r3_hit_age*27.)*sin(r3_hit_age*72.)*tuning.blade_contact_recoil
	angles+=Vector3(-.008*hit,.014*hit*r3_hit_sign,.009*hit*r3_hit_sign)
	shift.z+=.025*exp(-r3_hit_age*32.)*tuning.blade_contact_recoil
	player.blade_camera_angles=angles
	player.blade_camera_translation=shift
	player.blade_camera_fov=fov

func pose_at(clip:String,time:float,delta:float,attack:bool) -> void:
	# glTF omits constant translation channels. Restore the previous clean sample
	# before AnimationPlayer evaluates, otherwise the stow offset accumulates on
	# an unkeyed upper-arm translation even while visibility is switched back on.
	if unmoved_pose.size()==motion_skeleton.get_bone_count():
		for bone in range(unmoved_pose.size()):motion_skeleton.set_bone_pose(bone,unmoved_pose[bone])
	if clip_name!=clip:
		source_pose.clear()
		if not unmoved_pose.is_empty():source_pose.assign(unmoved_pose)
		clip_name=clip;transition_age=0
		animation_player.play(clip);animation_player.advance(0)
		var row:Dictionary={"clip":clip,"world_time":motion_clock};events.append(row)
		while events.size()>128:events.pop_front()
	clip_time=clampf(time,0,animation_player.current_animation_length)
	# Blender's frame 1 is exported at 1/120 s; event tables start at zero.
	animation_player.seek(minf(clip_time+1.0/120.0,animation_player.current_animation_length),true)
	transition_age+=delta
	var duration:float=tuning.attack_blend_seconds if attack else tuning.movement_blend_seconds
	if clip.ends_with("_idle") or clip.ends_with("_run"):duration=tuning.recovery_blend_seconds
	if duration>0 and transition_age<duration and source_pose.size()==motion_skeleton.get_bone_count():
		var weight:float=smoothstep(0,1,transition_age/duration)
		for bone in range(source_pose.size()):motion_skeleton.set_bone_pose(bone,source_pose[bone].interpolate_with(motion_skeleton.get_bone_pose(bone),weight))
	sync_attachments()

func sync_attachments() -> void:
	motion_skeleton.force_update_all_bone_transforms()
	for child in motion_skeleton.get_children():
		if child is BoneAttachment3D:
			var bone:int=motion_skeleton.find_bone(child.bone_name)
			if bone>=0:child.transform=motion_skeleton.get_bone_global_pose(bone)

func solve_arm(side:String,target:Transform3D) -> void:
	var upper:int=motion_skeleton.find_bone("upper_arm."+side)
	var fore:int=motion_skeleton.find_bone("forearm."+side)
	var hand:int=motion_skeleton.find_bone("hand."+side)
	var u:Transform3D=motion_skeleton.get_bone_global_pose(upper)
	var f:Transform3D=motion_skeleton.get_bone_global_pose(fore)
	var h:Transform3D=motion_skeleton.get_bone_global_pose(hand)
	var a:float=u.origin.distance_to(f.origin);var b:float=f.origin.distance_to(h.origin)
	var offset:Vector3=target.origin-u.origin
	var distance:float=clampf(offset.length(),absf(a-b)+.0001,a+b-.0001)
	var direction:Vector3=offset.normalized()
	var pole:Vector3=(f.origin-u.origin)-direction*(f.origin-u.origin).dot(direction)
	if pole.length_squared()<.000001:pole=direction.cross(Vector3.FORWARD)
	pole=pole.normalized()
	var along:float=(a*a-b*b+distance*distance)/(2.0*distance)
	var elbow:Vector3=u.origin+direction*along+pole*sqrt(maxf(0,a*a-along*along))
	u.basis=Basis(Quaternion((f.origin-u.origin).normalized(),(elbow-u.origin).normalized()))*u.basis
	motion_skeleton.set_bone_global_pose(upper,u)
	motion_skeleton.force_update_all_bone_transforms()
	f=motion_skeleton.get_bone_global_pose(fore);h=motion_skeleton.get_bone_global_pose(hand)
	f.basis=Basis(Quaternion((h.origin-f.origin).normalized(),(target.origin-f.origin).normalized()))*f.basis
	motion_skeleton.set_bone_global_pose(fore,f)
	motion_skeleton.force_update_all_bone_transforms()
	h=motion_skeleton.get_bone_global_pose(hand);h.basis=target.basis
	motion_skeleton.set_bone_global_pose(hand,h)

func update_blade_trail(delta:float,combat:PlayerCombat) -> void:
	# Visual trail ownership is independent of the rejected R3 pose/camera path.
	# Every cutting clip supplies its current physical edge sockets and timing.
	if tuning.blade_compound_arc_enabled:
		update_sample_trail(delta,combat);return
	var mesh:=new_trail.mesh as ImmediateMesh;mesh.clear_surfaces()
	if active_kind!="blade" or not player.control_enabled or not weapon_effects_enabled:trail_samples.clear();return
	for row in trail_samples:row.age+=delta if combat.impact_hold<=0 else 0.0
	var style:int=blade_style()
	var lifetime:float=tuning.blade_empowered_lifetime if blade_powered else tuning.blade_trail_lifetime*(.93 if style==2 else 1.1 if style==4 else 1.)
	while not trail_samples.is_empty() and (trail_samples[0].age>lifetime or trail_samples.size()>32):trail_samples.pop_front()
	if blade_active and combat.impact_hold<=0 and is_instance_valid(sockets.get("edge_root")) and is_instance_valid(sockets.get("edge_tip")):
		var a:Vector3=sockets.edge_root.global_position;var b:Vector3=sockets.edge_tip.global_position
		var velocity:Vector3=(b-previous_edge_tip)/maxf(delta,.001) if not trail_samples.is_empty() else Vector3.ZERO
		if velocity.length()>.01:blade_contact_direction=velocity.normalized()
		if trail_samples.is_empty() or trail_samples[-1].b.distance_to(b)>.002:
			trail_samples.append({"a":a,"b":b,"age":0.,"speed":minf(velocity.length(),45.),"powered":blade_powered})
		previous_edge_tip=b
	if trail_samples.size()<2:return
	var tint:Color=[tuning.blade_duel_color,tuning.blade_echo_color,tuning.blade_duel_color,tuning.blade_slide_color,tuning.blade_hunt_color][style]
	for shader in [trail_shader,blade_echo_shader]:
		shader.set_shader_parameter("strength",tuning.trail_strength)
		shader.set_shader_parameter("age",motion_clock)
		shader.set_shader_parameter("tint",tint)
		shader.set_shader_parameter("core_color",tuning.blade_core_color)
		shader.set_shader_parameter("brightness",tuning.blade_trail_brightness)
		shader.set_shader_parameter("bloom",tuning.blade_bloom_contribution)
		shader.set_shader_parameter("breakup",tuning.blade_trail_breakup)
		shader.set_shader_parameter("style",style)
		shader.set_shader_parameter("contact",weapon_hit)
		shader.set_shader_parameter("empowered",1.0 if blade_powered else 0.0)
	# A tapered translucent wake follows the actual cutting edge in depth.
	# The shader isolates a luminous leading rim, never an opaque flat sector.
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,trail_shader)
	for i in range(1,trail_samples.size()):
		var earlier:Dictionary=trail_samples[i-1];var later:Dictionary=trail_samples[i]
		for slice_index in range(3):
			var r0:Dictionary=interpolate_blade_sample(earlier,later,slice_index/3.)
			var r1:Dictionary=interpolate_blade_sample(earlier,later,(slice_index+1)/3.)
			for j in range(4):
				var v0:float=j/4.;var v1:float=(j+1)/4.
				for item in [[r0,v0],[r1,v0],[r1,v1],[r0,v0],[r1,v1],[r0,v1]]:
					var row:Dictionary=item[0];var v:float=item[1]
					var u:float=1.-clampf(row.age/lifetime,0.,1.)
					var along:Vector3=(row.b-row.a).normalized()
					var width:float=tuning.blade_ribbon_width*(1.+row.speed/35.)*(tuning.blade_empowered_width if row.powered else 1.)
					# Keep the whole cutting edge in the ribbon. The previous offset
					# collapsed the wake toward the tip and made the blade read like a
					# glowing cursor instead of a physical cut.
					var start:Vector3=row.a
					mesh.surface_set_uv(Vector2(u,v))
					mesh.surface_set_color(Color(1,1,1,1))
					mesh.surface_add_vertex(start.lerp(row.b,v))
	mesh.surface_end()
	if style==1:
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP,blade_echo_shader)
		for row in trail_samples:
			var u:float=1.-clampf(row.age/lifetime,0.,1.)
			var tip:Vector3=row.b.lerp(row.a,(1.-u)*.16)
			mesh.surface_set_uv(Vector2(u,0));mesh.surface_add_vertex(tip-(row.b-row.a).normalized()*.035*u)
			mesh.surface_set_uv(Vector2(u,1));mesh.surface_add_vertex(tip)
		mesh.surface_end()

func interpolate_blade_sample(a:Dictionary,b:Dictionary,weight:float)->Dictionary:
	var da:Vector3=a.b-a.a;var db:Vector3=b.b-b.a
	var root:Vector3=a.a.lerp(b.a,weight)
	var direction:Vector3=da.normalized().slerp(db.normalized(),weight)
	return {"a":root,"b":root+direction*lerpf(da.length(),db.length(),weight),"age":lerpf(a.age,b.age,weight),"speed":lerpf(a.speed,b.speed,weight),"powered":a.powered or b.powered}

func update_sample_trail(delta:float,combat:PlayerCombat)->void:
	var mesh:=new_trail.mesh as ImmediateMesh;mesh.clear_surfaces()
	if active_kind!="blade" or not player.control_enabled or not weapon_effects_enabled:
		trail_samples.clear();return
	for row in trail_samples:row.age+=delta if combat.impact_hold<=0 else 0.0
	var lifetime:float=tuning.blade_arc_lifetime*(.8 if blade_powered else 1.)
	while not trail_samples.is_empty() and (trail_samples[0].age>lifetime or trail_samples.size()>24):trail_samples.pop_front()
	if blade_active and combat.impact_hold<=0 and is_instance_valid(sockets.get("edge_root")) and is_instance_valid(sockets.get("edge_tip")):
		var a:Vector3=sockets.edge_root.global_position;var b:Vector3=sockets.edge_tip.global_position
		var velocity:Vector3=(b-previous_edge_tip)/maxf(delta,.001) if not trail_samples.is_empty() else Vector3.ZERO
		if velocity.length()>.01:blade_contact_direction=velocity.normalized()
		if trail_samples.is_empty() or trail_samples[-1].b.distance_to(b)>.002:
			trail_samples.append({"a":a,"b":b,"age":0.,"speed":minf(velocity.length(),55.),"powered":blade_powered})
		previous_edge_tip=b
	if trail_samples.size()<2:return
	# The current blade branch tints the arc's outer edge while the authored
	# cutting edge stays visible. Readiness adds only a small pulse; it never
	# changes the physical ribbon width or hides the weapon.
	var style:int=blade_style()
	var rune_color:Color=tuning.blade_arc_outer
	match style:
		1:rune_color=tuning.blade_echo_color
		2:rune_color=tuning.blade_duel_color
		3:rune_color=tuning.blade_slide_color
		4:rune_color=tuning.blade_hunt_color
	var rune_strength:float=tuning.blade_arc_rune_gain if style>0 else 0.0
	rune_strength*=.55+.45*weapon_readiness
	var readiness_gain:float=1.+minf(weapon_readiness,.85)*.08
	r3_arc_shader.set_shader_parameter("core_color",tuning.blade_arc_core)
	r3_arc_shader.set_shader_parameter("outer_color",tuning.blade_arc_outer)
	r3_arc_shader.set_shader_parameter("rune_color",rune_color)
	r3_arc_shader.set_shader_parameter("rune_strength",rune_strength)
	r3_arc_shader.set_shader_parameter("emission_power",tuning.blade_arc_emission*readiness_gain)
	r3_arc_shader.set_shader_parameter("opacity",tuning.blade_arc_opacity)
	r3_arc_shader.set_shader_parameter("clock",motion_clock)
	# Sweep the real cutting edge in its 3D trajectory. Interpolate its direction
	# on the sphere so fast turns retain curvature, depth and perspective.
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,r3_arc_shader)
	for i in range(1,trail_samples.size()):
		var previous:Dictionary=trail_samples[i-1];var next:Dictionary=trail_samples[i]
		var divisions:int=tuning.blade_curve_samples
		for step_index in range(divisions):
			var t0:float=step_index/float(divisions);var t1:float=(step_index+1)/float(divisions)
			for strip in range(8):
				var v0:float=strip/8.;var v1:float=(strip+1)/8.
				for uv:Vector2 in [Vector2(t0,v0),Vector2(t1,v0),Vector2(t1,v1),Vector2(t0,v0),Vector2(t1,v1),Vector2(t0,v1)]:
					var root_point:Vector3=previous.a.lerp(next.a,uv.x)
					var tip_point:Vector3=previous.b.lerp(next.b,uv.x)
					var blade_axis:Vector3=(tip_point-root_point).normalized()
					var center:Vector3=root_point.lerp(tip_point,uv.y)
					var live:float=1.-clampf(lerpf(previous.age,next.age,uv.x)/lifetime,0.,1.)
					var speed:float=lerpf(previous.speed,next.speed,uv.x)
					# Speed should sharpen the wake, not inflate it over the weapon.
					# The old linear multiplier reached 3x at normal slash speed and
					# hid the actual blade behind a white fan.
					var speed_gain:float=1.+minf(speed,24.)*.012
					var width:float=tuning.blade_arc_width*speed_gain*(tuning.blade_empowered_width if next.powered else 1.)
					width*=(.62+.38*sin(uv.y*PI))
					width*=(1.+tuning.blade_motion_smear*.35*(1.-live))
					var arc_phase:float=(float(i-1)+uv.x)/float(trail_samples.size()-1)
					width*=pow(maxf(0.,sin(arc_phase*PI)),.65)
					var view_direction:Vector3=(camera.global_position-center).normalized()
					var across:Vector3=blade_axis.cross(view_direction)
					if across.length_squared()<.0001:across=blade_axis.cross(Vector3.UP)
					across=across.normalized()
					var normal:Vector3=blade_axis.cross(across).normalized()
					var point:Vector3=center+across*(uv.y-.5)*width
					point+=normal*sin(uv.y*PI)*width*.16*tuning.blade_motion_smear
					mesh.surface_set_uv(Vector2(live,uv.y));mesh.surface_add_vertex(point)
	# The empowered cutting edge briefly ignites along its actual length. This
	# connects the tip arc to the blade without an opaque screen-space fan.
	if blade_powered and blade_active and clip_name=="blade_execute":
		# The retained effect follows the active clip's event window, including
		# future isolated candidates; never force the rejected R3 contact times.
		var flare:float=0.
		for cut:Dictionary in event_map.get(clip_name,{}).get("cuts",[]):
			var start:float=float(cut.active_start_s);var contact:float=float(cut.nominal_contact_s);var end:float=float(cut.active_end_s)
			flare=maxf(flare,smoothstep(start,contact,clip_time)*(1.-smoothstep(contact,end,clip_time)))
		var base:Vector3=sockets.edge_root.global_position;var end:Vector3=sockets.edge_tip.global_position
		var axis:Vector3=(end-base).normalized()
		var across:Vector3=axis.cross((camera.global_position-(base+end)*.5).normalized()).normalized()
		for section in range(10):
			var u0:float=section/10.;var u1:float=(section+1)/10.
			for uv:Vector2 in [Vector2(u0,0),Vector2(u1,0),Vector2(u1,1),Vector2(u0,0),Vector2(u1,1),Vector2(u0,1)]:
				var strength:float=flare*smoothstep(0.,.18,uv.x)*(1.-smoothstep(.94,1.,uv.x))
				var point:Vector3=base.lerp(end,uv.x)+across*(uv.y-.5)*tuning.blade_arc_width*tuning.blade_empowered_width*flare
				mesh.surface_set_uv(Vector2(strength,uv.y));mesh.surface_add_vertex(point)
	mesh.surface_end()

func blade_style()->int:
	return {&"shade_echo":1,&"shade_parry":2,&"shade_slide":3,&"shade_wall":4}.get(super.weapon_evolution_state().branch,0)

func blade_contact_accent(target:Node3D,point:Vector3,defeated:bool)->void:
	r3_hit_age=0.;r3_hit_sign=-1. if clip_name in ["blade_attack_return","blade_blink"] else 1.
	if active_kind=="blade" and is_instance_valid(target):
		target.set_meta("blade_hit_visual",{"direction":player.camera.global_basis*blade_contact_direction,"defeated":defeated,"serial":int(target.get_meta("blade_hit_serial",0))+1})
		target.set_meta("blade_hit_serial",int(target.get_meta("blade_hit_serial",0))+1)
	if active_kind!="blade" or not weapon_effects_enabled or tuning.blade_impact_burst<=0:return
	var accent:=preload("res://viewmodel_r16/blade_impact.gd").new()
	accent.flash_seconds=tuning.blade_impact_flash_seconds;accent.strength=tuning.blade_impact_burst
	accent.mist_opacity=tuning.blade_contact_mist_opacity;accent.mist_size=tuning.blade_contact_mist_size
	accent.mist_lifetime=tuning.blade_contact_mist_lifetime;accent.mist_speed=tuning.blade_contact_mist_speed;accent.mist_expansion=tuning.blade_contact_mist_expansion
	accent.cut_direction=blade_contact_direction # Accent's basis is the real camera basis.
	accent.style=blade_style();accent.metal=not defeated or (is_instance_valid(target) and target.get("role")==&"heavy");accent.tint=tuning.blade_core_color
	get_tree().current_scene.add_child(accent)
	accent.global_transform=Transform3D(player.camera.global_basis,point)
