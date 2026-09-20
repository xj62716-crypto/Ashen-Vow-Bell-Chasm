extends Node3D
## Optional review adapter for approved immutable GLBs. Never edits their animation.
const ROLES=[&"pursuer",&"heavy",&"crossbow",&"caster",&"bell",&"sentinel"]
var source:WeakRef
var model:Node3D
var animator:AnimationPlayer
var clip:StringName=&""
var age:float=0
var released_age:float=-1
var death_age:float=0
var flame:Node
var surface:ShaderMaterial
var parts:Array=[]
var bound_path:String=""
var marker:Node3D
var blade_hit_serial:int=0
var blade_hit_age:float=10.
var blade_hit_direction:Vector3=Vector3.ZERO
var blade_hit_dead:bool=false
func bind(actor:LanternAcolyte)->bool:
	source=weakref(actor)
	var id:int=ROLES.find(actor.role)+1
	bound_path="res://enemy_fx_r14/models/"+("B01" if actor.threat_rank==&"miniboss" else "B02" if actor.threat_rank==&"boss" else "E%02d-%s"%[id,"elite" if actor.threat_rank==&"elite" else "ordinary"])+".glb"
	var packed=load(bound_path) as PackedScene
	if not packed:return false
	model=packed.instantiate();add_child(model)
	animator=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if animator:animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	parts=model.find_children("*","MeshInstance3D",true,false)
	surface=ShaderMaterial.new();surface.shader=preload("res://enemy_fx_r14/enemy_surface.gdshader")
	for part in parts:part.material_overlay=surface
	marker=model.find_child("FX_CORE",true,false) as Node3D
	if id==4 and actor.threat_rank==&"normal":
		flame=load("res://enemy_fx_r14/lantern_flame.gd").new();add_child(flame)
		if flame.bind(model)!=OK:flame.queue_free();flame=null
	return true
func find_clip(suffix:String)->StringName:
	if not animator:return &""
	for name in animator.get_animation_list():
		if str(name).ends_with("_"+suffix):return name
	return &""
func release_attack()->void:released_age=0
func tick(delta:float)->void:
	var actor=source.get_ref()
	if not is_instance_valid(actor):return
	global_transform=actor._visual.global_transform;age+=delta
	var hit:Dictionary=actor.get_meta("blade_hit_visual",{})
	if not hit.is_empty() and int(hit.serial)!=blade_hit_serial:
		blade_hit_serial=int(hit.serial);blade_hit_age=0.;blade_hit_direction=hit.direction;blade_hit_dead=hit.defeated
	blade_hit_age+=delta
	if blade_hit_age<.9:
		var impulse:float=sin(minf(1.,blade_hit_age/.18)*PI*.5)*exp(-blade_hit_age*(1.5 if blade_hit_dead else 9.))
		global_position+=blade_hit_direction*impulse*(.38 if blade_hit_dead else .14)
		var axis:Vector3=Vector3.UP.cross(blade_hit_direction).normalized()
		if axis.length_squared()>.01:global_basis=Basis(axis,impulse*.18)*global_basis
	if released_age>=0:released_age+=delta
	if actor.health<=0:death_age+=delta
	visible=actor.health>0 or death_age<.9
	var phase:float=fmod(age*.3,1.);var suffix:String="idle"
	if actor.health<=0:suffix="death";phase=clampf(death_age/.9,0,1)
	elif actor.frozen_left>0:suffix="ice_freeze_hold";phase=.5
	elif actor._stagger>0:suffix="wind_stagger";phase=1.-clampf(actor._stagger/.35,0,1)
	elif actor.windup>=0:
		suffix="attack_windup_release_recover";phase=(1.-clampf(actor.windup/maxf(.01,actor.brain.attack_duration),0,1))*.42
	elif released_age>=0 and actor.brain.recovery_left>0:
		suffix="attack_windup_release_recover";phase=.42+.58*clampf(released_age/(released_age+actor.brain.recovery_left),0,1)
	elif actor.velocity.length()>1.:suffix="walk"
	elif actor.has_guard() and actor.vulnerable:suffix="guard_exposure";phase=.55
	var next:=find_clip(suffix)
	if next==&"":next=find_clip("alert")
	if animator and next!=&"":
		if clip!=next:animator.play(next);clip=next
		animator.seek(phase*animator.get_animation(next).length,true)
	surface.set_shader_parameter("frost",1. if actor.frozen_left>0 and actor.health>0 else 0.)
	surface.set_shader_parameter("flash",clampf(actor._flash*5.,0,1))
	if flame:flame.tick(delta,actor.health>0,false)
func core_point(fallback:Vector3)->Vector3:
	return marker.global_position if is_instance_valid(marker) else fallback
