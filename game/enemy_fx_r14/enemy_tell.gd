extends Node3D
## Exact windup clock and attack events, no predictive hit confirmation.
var source:WeakRef
var state:StringName=&"idle"
var kind:StringName=&""
var duration:float=1
var age:float=0
var released_age:float=-1
var guard_flash:float=0
var sigil:MeshInstance3D
var material:ShaderMaterial
var weakpoint:MeshInstance3D
var weakmat:StandardMaterial3D
var shards:MultiMeshInstance3D
var shardmat:StandardMaterial3D
var locked:bool=false
var core_offset:Vector3=Vector3.ZERO
var settings:Resource
var reaction_age:float=-1
var reaction_kind:StringName=&""
var reaction_point:Vector3
func _ready()->void:
	material=ShaderMaterial.new();material.shader=preload("res://enemy_fx_r14/threat_sigil.gdshader")
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*.48
	sigil=MeshInstance3D.new();sigil.mesh=quad;sigil.material_override=material;sigil.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(sigil)
	var ring:=TorusMesh.new();ring.inner_radius=.12;ring.outer_radius=.139;ring.rings=4;ring.ring_segments=6
	weakmat=StandardMaterial3D.new();weakmat.albedo_color=Color("cfb98a");weakmat.metallic=.55;weakmat.emission_enabled=true;weakmat.emission=Color("cbbc8b");weakmat.emission_energy_multiplier=.65
	weakpoint=MeshInstance3D.new();weakpoint.mesh=ring;weakpoint.material_override=weakmat;weakpoint.rotation.x=PI/2;weakpoint.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(weakpoint)
	var chip:=PrismMesh.new();chip.size=Vector3(.025,.09,.018)
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=chip;multi.instance_count=32;multi.visible_instance_count=0
	shards=MultiMeshInstance3D.new();shards.multimesh=multi;shards.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(shards)
	shardmat=StandardMaterial3D.new();shardmat.albedo_color=Color("ac733f");shardmat.emission_enabled=true;shardmat.emission=Color("c79753");shardmat.emission_energy_multiplier=.8;shards.material_override=shardmat
func bind(actor:LanternAcolyte)->void:source=weakref(actor)
func committed(type:StringName,seconds:float)->void:
	kind=type;duration=seconds;state=&"windup";released_age=-1
func released(type:StringName)->void:kind=type;state=&"release";released_age=0
func changed(value:StringName)->void:
	state=value
	if value in [&"idle",&"stagger",&"search",&"return"]:released_age=-1
func exposed()->void:guard_flash=.3
func reaction(point:Vector3,type:StringName)->void:
	reaction_age=0.;reaction_kind=type;reaction_point=point
func tick(delta:float,core:Vector3,emitter:Vector3=Vector3.INF)->void:
	var actor=source.get_ref()
	if not is_instance_valid(actor):return
	age+=delta;guard_flash=maxf(0,guard_flash-delta)
	global_position=emitter if emitter.is_finite() else actor.get_hit_point()
	var windup:bool=actor.windup>=0 and actor.health>0 and actor.active
	var progress:float=clampf(1.-actor.windup/maxf(.01,duration),0,1)
	locked=windup and actor.windup<=.3
	sigil.visible=windup
	var direction:Vector3=(actor.locked_target-global_position).normalized()
	sigil.position=direction*.48+Vector3.UP*.08
	if direction.length()>.001:sigil.global_basis=Basis.looking_at(-direction,Vector3.RIGHT if absf(direction.y)>.95 else Vector3.UP)
	var tint:Color=settings.metal_color if actor.role in [&"pursuer",&"heavy",&"crossbow"] else settings.ritual_color
	if locked:tint=tint.lightened(.22)
	material.set_shader_parameter("tint",tint);material.set_shader_parameter("progress",progress);material.set_shader_parameter("age",age)
	# Distinct physical shapes, not a long beam that resembles a hitscan laser.
	sigil.scale=Vector3(1.8,.36,1) if kind in [&"lunge",&"high_sweep",&"dive"] else Vector3(.5,1.35,1) if kind==&"bash" else Vector3.ONE
	sigil.scale*=settings.tell_scale
	weakpoint.global_position=core
	weakpoint.global_basis=actor._visual.global_basis*Basis(Vector3.RIGHT,PI/2)
	weakpoint.visible=actor.has_guard() and actor.vulnerable and actor.health>0 and not is_instance_valid(actor.boss_controller)
	weakmat.emission_energy_multiplier=.65+guard_flash*2.
	if released_age>=0:released_age+=delta
	if reaction_age>=0:reaction_age+=delta
	var reacting:bool=reaction_age>=0 and reaction_age<settings.reaction_duration
	var life:float=reaction_age if reacting else released_age
	var release:bool=reacting or (life>=0 and life<settings.reaction_duration and actor.health>0)
	shards.multimesh.visible_instance_count=settings.reaction_shards if release else 0
	shards.transparency=clampf(life/settings.reaction_duration,0,1) if release else 1.
	shards.global_position=reaction_point if reacting else global_position
	shardmat.emission=Color("95bfc7") if reacting and reaction_kind==&"ice" else Color("a9b3a1") if reacting and reaction_kind==&"wind" else settings.metal_color
	shardmat.emission_energy_multiplier=settings.rune_energy
	if release:
		for index in range(settings.reaction_shards):
			var a:float=index*2.39996;var spread:=Vector3(sin(a),cos(a),sin(a*1.7)).normalized()
			var position_value:Vector3=direction*life*1.8+spread*life*(2. if reacting else .9)
			shards.multimesh.set_instance_transform(index,Transform3D(Basis(Vector3.UP,a+life*4),position_value))
