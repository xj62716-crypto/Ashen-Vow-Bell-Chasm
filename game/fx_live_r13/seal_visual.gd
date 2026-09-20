extends Node3D
## Persistent spell mark follows its real target; rupture only comes from detonation.
var plane:MeshInstance3D
var material:ShaderMaterial
var age:float=0.0
var release_age:float=0.0
var releasing:bool=false
var detonated:bool=false
var shards:MultiMeshInstance3D
var samples:Array[Vector3]=[]

func _ready() -> void:
	material=ShaderMaterial.new();material.shader=preload("res://fx_live_r13/seal_sigil.gdshader")
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*.82
	plane=MeshInstance3D.new();plane.mesh=quad;plane.material_override=material;plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(plane)
	# Place the sign just in front of the torso; retain depth testing against cover.
	plane.position.z=.5
	var shard:=PrismMesh.new();shard.size=Vector3(.018,.055,.013)
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=shard;multi.instance_count=18;multi.visible_instance_count=0
	shards=MultiMeshInstance3D.new();shards.multimesh=multi;shards.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var metal:=StandardMaterial3D.new();metal.albedo_color=Color("baa875");metal.emission_enabled=true;metal.emission=Color("8c7758");metal.emission_energy_multiplier=.75;metal.metallic=.35
	shards.material_override=metal;add_child(shards)
	for index in range(18):samples.append(Vector3(sin(index*2.39996),cos(index*2.39996),sin(index*4.17)*.25).normalized())

func release(explode:bool=false) -> void:
	if releasing and (not explode or detonated):return
	releasing=true;detonated=explode;release_age=0
	if explode:shards.multimesh.visible_instance_count=18

func tick(delta:float,camera:Camera3D) -> bool:
	age+=delta
	if is_instance_valid(camera):global_basis=camera.global_basis
	if releasing:release_age+=delta
	var fade:float=1.0-smoothstep(0,.32,release_age)
	material.set_shader_parameter("age",age);material.set_shader_parameter("strength",smoothstep(0,.10,age)*fade)
	material.set_shader_parameter("rupture",clampf(release_age/.26,0,1) if detonated else 0.0)
	plane.scale=Vector3.ONE*(1.0+release_age*1.8 if detonated else 1.0)
	if detonated:
		for index in range(samples.size()):
			var p:Vector3=samples[index]*(.12+release_age*2.4)+Vector3.DOWN*release_age*release_age
			shards.multimesh.set_instance_transform(index,Transform3D(Basis(Quaternion(Vector3.UP,samples[index])).scaled(Vector3.ONE*maxf(.001,fade)),p))
	return release_age<.34
