extends Node3D
## A historical sword stroke, placed only by EchoSlash.sweep_replayed.
## This is visual-only: no overlap queries and no invented damage events.
var lifetime:float=.24
var width:float=.042
var strength:float=.6
var elapsed:float=0.
var ribbon:MeshInstance3D
var shader:ShaderMaterial

func _init()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE

func _ready()->void:
	add_to_group("transient_effects")
	ribbon=MeshInstance3D.new();ribbon.mesh=ImmediateMesh.new()
	ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ribbon)
	shader=ShaderMaterial.new();shader.shader=preload("res://viewmodel_r16/blade_trail.gdshader")
	shader.set_shader_parameter("ghost",.45);shader.set_shader_parameter("tint",Color("44324e"))
	shader.set_shader_parameter("core_color",Color("a99abb"));shader.set_shader_parameter("brightness",.65)
	shader.set_shader_parameter("strength",strength);shader.set_shader_parameter("style",1)
	_process(0.)

func _process(delta:float)->void:
	elapsed+=delta
	if elapsed>=lifetime:queue_free();return
	var progress:float=elapsed/lifetime
	shader.set_shader_parameter("age",elapsed)
	var mesh:ImmediateMesh=ribbon.mesh;mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,shader)
	# Open contracting crescent at the old committed cut, never a complete ring.
	for i in range(40):
		for uv:Vector2 in [Vector2(i/40.,0),Vector2((i+1)/40.,0),Vector2((i+1)/40.,1),Vector2(i/40.,0),Vector2((i+1)/40.,1),Vector2(i/40.,1)]:
			var angle:float=lerpf(-1.05,1.05,uv.x)
			var radius:float=lerpf(1.65,1.25,progress)+(uv.y-.5)*width*sin(uv.x*PI)
			mesh.surface_set_uv(Vector2((1.-progress)*sin(uv.x*PI),uv.y))
			mesh.surface_add_vertex(Vector3(sin(angle)*radius,-.10+sin(angle)*.12,-cos(angle)*radius))
	mesh.surface_end()
