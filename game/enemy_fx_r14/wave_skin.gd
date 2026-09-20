extends Node3D
## A height-preserving rune front; real wave radius and collision own all timing.
var material:ShaderMaterial
var disk:MeshInstance3D
var age:float=0
var high:bool=false
func _ready()->void:
	material=ShaderMaterial.new();material.shader=preload("res://enemy_fx_r14/threat_sigil.gdshader");material.set_shader_parameter("front_only",true);material.set_shader_parameter("tint",Color("aa7482") if high else Color("c49157"))
	var mesh:=PlaneMesh.new();mesh.size=Vector2.ONE*2
	disk=MeshInstance3D.new();disk.mesh=mesh;disk.material_override=material;disk.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(disk)
func tick(delta:float,radius:float)->bool:
	age+=delta;disk.scale=Vector3(radius,1,radius);material.set_shader_parameter("age",age);return true
