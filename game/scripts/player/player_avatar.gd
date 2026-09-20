class_name PlayerAvatar
extends Node3D

var _model: Node3D
var _animation: AnimationPlayer
var _clock: float = 0.0
var player: ParkourPlayer
var _skeleton: Skeleton3D
var _shadow_item: Node3D
var _arm_skeleton: Skeleton3D
var _body_meshes:Array[MeshInstance3D]=[]

func _ready() -> void:
	# Consume the foreground rig only after its final animation/visibility pass.
	process_priority = 30 # R16 foreground rig evaluates at priority 20.
	player = get_parent() as ParkourPlayer
	player.profile_changed.connect(_equip)
	_equip(player.parkour_profile)

func _equip(profile: ParkourProfile) -> void:
	if is_instance_valid(_shadow_item):
		remove_child(_shadow_item)
		_shadow_item.queue_free()
		_shadow_item=null
	if is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
	var file: String = "staff" if profile.id==&"arcanist" else "blade"
	_model = (load("res://player_body_live/"+file+".glb") as PackedScene).instantiate() as Node3D
	_model.set_meta("asset_id","body_"+file)
	_model.rotation.y = PI
	_model.scale = Vector3.ONE*.9
	add_child(_model)
	_body_meshes.clear()
	for mesh:MeshInstance3D in _model.find_children("*","MeshInstance3D",true,false):
		_body_meshes.append(mesh)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_animation = _model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	_skeleton = _model.find_child("Skeleton3D",true,false) as Skeleton3D
	_arm_skeleton=null
	for skeleton:Skeleton3D in _model.find_children("*","Skeleton3D",true,false):
		if skeleton.find_bone("upper_arm.R")>=0:_arm_skeleton=skeleton
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# The previous shadow weapon came from an obsolete low-detail equipment GLB.
	# Current first-person weapon/arms remain authoritative; no legacy item shown.

func _process(delta: float) -> void:
	if _animation == null:
		return
	var moving: bool = player.horizontal_speed()>1.0 and player.is_on_floor()
	var clip:StringName=&""
	var suffix:String="_run" if moving else "_idle"
	for name in _animation.get_animation_list():
		if str(name).ends_with(suffix):clip=name
	if clip==&"":return
	_clock = fmod(_clock+delta*(player.horizontal_speed()*.16 if moving else .6),1.0)
	if _animation.current_animation != clip:
		_animation.play(clip)
	_animation.seek(_clock,true)
	var combat := player.get_node_or_null("Combat") as PlayerCombat
	var turn: float = 0.0
	if combat!=null and combat.attacking and player.parkour_profile.id==&"shade":
		var t := combat.attack_age
		var sign_value: float = -1.0 if combat.swing_return else 1.0
		if t<.083:turn=-.10*smoothstep(0,.083,t)
		elif t<.218:turn=-.10+.23*smoothstep(.083,.218,t)
		else:turn=.13*(1-smoothstep(.218,.44,t))
		turn*=sign_value
	player.attack_body_turn = lerpf(player.attack_body_turn,turn,1-exp(-delta*24))
	_model.rotation.y = PI+player.attack_body_turn
	_model.position.x = player.attack_body_turn*.15
	if _skeleton!=null:
		for name in ["spine","spine.001","chest"]:
			var index := _skeleton.find_bone(name)
			if index>=0:
				_skeleton.set_bone_pose_rotation(index,_skeleton.get_bone_pose_rotation(index)*Quaternion(Vector3.UP,player.attack_body_turn*.5))
	var view = player.get_node_or_null("FirstPersonArms")
	if view!=null and _arm_skeleton!=null and is_instance_valid(view.motion_skeleton):
		# Match upper-arm and forearm directions to the actual foreground rig.
		# This carries attacks, wall braces and grapple reaches into the body shadow.
		for index in _arm_skeleton.get_bone_count():
			var source:int=view.motion_skeleton.find_bone(_arm_skeleton.get_bone_name(index))
			if source>=0:_arm_skeleton.set_bone_pose(index,view.motion_skeleton.get_bone_pose(source))
		var render_left:bool=view.left_hand_state().visible_meshes>0
		for mesh in _body_meshes:
			if str(mesh.name).begins_with("Left__"):mesh.visible=render_left
		if is_instance_valid(_shadow_item) and view.get_equipped_item(&"right")!=null:
			_shadow_item.global_transform=player.camera.global_transform*view.get_equipped_item(&"right").global_transform
	_model.position.z = .1
	_model.position.y = -.65 if player.crouched else 0.0
	_model.visible = true
	for mesh in _model.find_children("LegsSurface*","MeshInstance3D",true,false):mesh.visible=not player.crouched
