class_name ImpactBurst
extends Node3D
## Contact-specific fragments; melee stays compact, magic carries an element.
var lifetime: float = .62
var _age: float = 0.0
var _flash: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D
var _style: StringName = &"arcane"

static func spawn(parent: Node3D, point: Vector3, tint: Color, power: float = 1.0, style: StringName = &"arcane", direction: Vector3 = Vector3.UP) -> void:
	var burst := ImpactBurst.new()
	burst._style=style
	burst.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(burst)
	burst.global_position = point
	burst._flash = FxMaterials.sprite(burst,(.42 if style==&"blade" else .5)*power,FxMaterials.glow(tint.lightened(.5),1.6))
	burst._ring = FxMaterials.sprite(burst,.35*power,FxMaterials.glow(tint,.25,true))
	burst._ring.visible=style in [&"arcane",&"wind","blade"]
	var sparks := CPUParticles3D.new()
	sparks.amount = 18 if style==&"blade" else 18
	sparks.lifetime = .28 if style==&"blade" else .46
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = direction.normalized()
	sparks.spread = 55.0 if style==&"blade" else 110.0
	sparks.gravity = Vector3(0, 1.5 if style==&"fire" else -5.0, 0)
	sparks.initial_velocity_min = .8*power
	sparks.initial_velocity_max = 3.2*power
	sparks.damping_min = 2
	sparks.damping_max = 5
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.2
	var size := Curve.new()
	size.add_point(Vector2(0,1))
	size.add_point(Vector2(.35,.65))
	size.add_point(Vector2(1,0))
	sparks.scale_amount_curve = size
	var colors := Gradient.new()
	colors.set_color(0,tint.lightened(.65))
	colors.set_color(1,Color(tint.r,tint.g,tint.b,0))
	sparks.color_ramp = colors
	var shape := PrismMesh.new()
	shape.size = Vector3(.009,.10,.009) if style==&"blade" else (Vector3(.035,.12,.025) if style==&"ice" else Vector3(.025,.04,.025))
	var material := DemoGeometry.material(tint,1)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shape.material = material
	sparks.mesh = shape
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.add_child(sparks)
	sparks.emitting = true
	burst._light = OmniLight3D.new()
	burst._light.light_color = tint
	burst._light.light_energy = 1.1*power
	burst._light.omni_range = 1.6*power
	burst.add_child(burst._light)

func _process(delta: float) -> void:
	lifetime -= delta
	_age += delta
	if lifetime <= 0.0:
		queue_free()
		return
	if _flash == null:
		return
	FxMaterials.face_camera(_flash)
	FxMaterials.face_camera(_ring)
	(_flash.material_override as ShaderMaterial).set_shader_parameter("strength",maxf(0,1-_age/.055)*1.3)
	_ring.scale = Vector3.ONE*(1+_age*4)
	(_ring.material_override as ShaderMaterial).set_shader_parameter("strength",maxf(0,1-_age/.18)*.25)
	_light.light_energy = maxf(0,1-_age/.08)*1.1
