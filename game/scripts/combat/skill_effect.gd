class_name SkillEffect
extends Node3D

var style: StringName=&"slash"
var tint := Color("#eecb87")
var radius: float=2.0
var endpoint := Vector3.ZERO
var age: float=0
var duration: float=.32
var _mesh := ImmediateMesh.new()

static func spawn(parent: Node3D, pose: Transform3D, kind: StringName, color: Color, size: float=2.0, end: Vector3=Vector3.ZERO) -> SkillEffect:
	var effect := SkillEffect.new()
	effect.style=kind
	effect.tint=color
	effect.radius=size
	effect.endpoint=end
	parent.add_child(effect)
	effect.global_transform=pose
	return effect

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	add_to_group("transient_effects")
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var visual := MeshInstance3D.new()
	visual.mesh=_mesh
	visual.material_override=material
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func _process(delta: float) -> void:
	age+=delta
	if age>=duration:
		queue_free()
		return
	_mesh.clear_surfaces()
	var fade: float=pow(1-age/duration,1.5)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if style in [&"blink",&"storm","hook"]:
		var end := to_local(endpoint)
		var side := end.cross(Vector3.UP).normalized()*(.055 if style==&"hook" else .08)
		for j in range(16 if style==&"hook" else 12):
			var a := end*(j/(16.0 if style==&"hook" else 12.0))+Vector3.UP*sin(j*2.7)*(.06 if style==&"hook" else .10)
			var b := end*((j+1)/(16.0 if style==&"hook" else 12.0))+Vector3.UP*sin((j+1)*2.7)*(.06 if style==&"hook" else .10)
			_quad(a-side,a+side,b+side,b-side,fade*(1.0 if style==&"hook" else .75))
		if style==&"hook":
			var tip := end.normalized()
			var head := end-tip*.18
			_quad(end-side*2,end+side*2,head+side,head-side,fade)
	else:
		var ring_count: int=1 if style==&"slash" else 3
		for band in range(ring_count):
			var r: float=radius*(.85+age*.7) if style==&"slash" else radius*(.3+age/duration)*(.6+band*.18)
			for j in range(48):
				var a: float=lerpf(-2.4,.55,j/48.0) if style==&"slash" else j*TAU/48
				var b: float=lerpf(-2.4,.55,(j+1)/48.0) if style==&"slash" else (j+1)*TAU/48
				var width: float=.025 if style!=&"slash" else .035*sin(j*PI/48)
				var p := Vector3(cos(a),sin(a),0)
				var q := Vector3(cos(b),sin(b),0)
				_quad(p*(r-width),p*(r+width),q*(r+width),q*(r-width),fade*.45)
	_mesh.surface_end()

func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,alpha: float) -> void:
	for p in [a,b,c,a,c,d]:
		_mesh.surface_set_color(Color(tint.r,tint.g,tint.b,alpha))
		_mesh.surface_add_vertex(p)
