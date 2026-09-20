extends Node3D
## AOE footprint is exactly the gameplay radius, timing is read from its hazard.
var kind:StringName=&"ground"
var radius:float=2.0
var duration:float=1.0
var age:float=0
var discharged:bool=false
var release_age:float=0
var material:ShaderMaterial
var shell_material:StandardMaterial3D
var glyphs:Array[MeshInstance3D]=[]
var fragments:MultiMeshInstance3D
var wisps:Array=[]

func _ready()->void:
	material=ShaderMaterial.new();material.shader=preload("res://enemy_fx_r14/threat_sigil.gdshader")
	material.set_shader_parameter("tint",Color("cf743d") if kind==&"ground" else Color("ab87b0"))
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*radius*2
	var disk:=MeshInstance3D.new();disk.mesh=quad;disk.material_override=material;disk.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(disk);glyphs.append(disk)
	if kind==&"ground":disk.rotation.x=-PI/2;disk.position.y=.045
	else:
		disk.rotation.x=PI/2
		shell_material=StandardMaterial3D.new();shell_material.albedo_color=Color("937ca0");shell_material.emission_enabled=true;shell_material.emission=shell_material.albedo_color;shell_material.emission_energy_multiplier=.45
		for index in range(3):
			var circle:=TorusMesh.new();circle.inner_radius=radius-.012;circle.outer_radius=radius;circle.rings=56;circle.ring_segments=5
			var rim:=MeshInstance3D.new();rim.mesh=circle;rim.material_override=shell_material;rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(rim);rim.rotation=Vector3(0,PI*index/3,PI/2);glyphs.append(rim)
	var chip:=PrismMesh.new();chip.size=Vector3(.055,.09,.045)
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=chip;multi.instance_count=24;multi.visible_instance_count=0
	fragments=MultiMeshInstance3D.new();fragments.multimesh=multi;fragments.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(fragments)
	var ember:=StandardMaterial3D.new();ember.albedo_color=Color("574939") if kind==&"ground" else Color("625b6c");ember.emission_enabled=true;ember.emission=Color("b37845") if kind==&"ground" else Color("9176a5");ember.emission_energy_multiplier=.45;fragments.material_override=ember
	for index in range(10):
		var plume_quad:=QuadMesh.new();plume_quad.size=Vector2(.55,.9)
		var plume:=MeshInstance3D.new();plume.mesh=plume_quad;plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var smoke:=ShaderMaterial.new();smoke.shader=load("res://fx_live_r13/magic_wisp.gdshader");smoke.set_shader_parameter("seed",index*1.79);smoke.set_shader_parameter("tint",Color("b96e37") if kind==&"ground" else Color("8a6d9e"));smoke.set_shader_parameter("strength",0.);smoke.set_shader_parameter("emission_scale",.75)
		plume.material_override=smoke;add_child(plume);wisps.append({"node":plume,"material":smoke})

func discharge()->void:discharged=true

func tick(delta:float,remaining:float)->bool:
	age+=delta
	if discharged:release_age+=delta
	var progress:float=clampf(1.0-remaining/maxf(.01,duration),0,1)
	var strength:float=1.0-clampf(release_age/.32,0,1)
	material.set_shader_parameter("age",age);material.set_shader_parameter("progress",progress);material.set_shader_parameter("strength",strength)
	if discharged:
		for index in range(wisps.size()):
			var a:float=index*2.39996;var r:float=radius*(.12+.64*float(index%5)/5.)
			wisps[index].node.position=Vector3(sin(a)*r,.22+release_age*1.4,cos(a)*r) if kind==&"ground" else Vector3(sin(a),cos(a),sin(a*1.8)).normalized()*release_age*radius*2.
			wisps[index].material.set_shader_parameter("age",age);wisps[index].material.set_shader_parameter("strength",strength*.8)
		fragments.multimesh.visible_instance_count=24;fragments.transparency=1.-strength
		for index in range(24):
			var a:float=index*2.39996;var r:float=radius*(.15+.7*float(index%7)/7.)
			var p:=Vector3(sin(a)*r,release_age*(1.5+index%4),cos(a)*r)
			if kind==&"air":p=Vector3(sin(a),cos(a),sin(a*1.8)).normalized()*release_age*radius*3.
			fragments.multimesh.set_instance_transform(index,Transform3D(Basis(Vector3.UP,a),p))
		for index in range(glyphs.size()):
			glyphs[index].transparency=1.0-strength
			if kind==&"ground":glyphs[index].position.y=.045+release_age*1.6
	return release_age<.32
