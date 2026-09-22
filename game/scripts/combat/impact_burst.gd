class_name ImpactBurst
extends Node3D
## Contact-specific fragments; melee stays compact, magic carries an element.
var lifetime: float = .62
var _age: float = 0.0
var _flash: MeshInstance3D
var _ring: MeshInstance3D
var _blood_cloud: MeshInstance3D
var _blood_core: MeshInstance3D
var _blood_cloud_material: ShaderMaterial
var _blood_core_material: ShaderMaterial
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
	sparks.amount = 30 if style==&"blade" else 18
	sparks.lifetime = .34 if style==&"blade" else .46
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
	if style == &"blade":
		# A short, desaturated oxblood cloud separates flesh feedback from the
		# pale blade trail without turning the hit into a glowing red overlay.
		var blood := CPUParticles3D.new()
		blood.amount = 46
		blood.lifetime = 1.05
		blood.one_shot = true
		blood.explosiveness = .92
		blood.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		blood.emission_sphere_radius = .10*power
		blood.direction = direction.normalized()
		blood.spread = 82.0
		blood.gravity = Vector3(0,-2.2,0)
		blood.initial_velocity_min = 1.0*power
		blood.initial_velocity_max = 3.8*power
		blood.damping_min = 1.2
		blood.damping_max = 2.5
		blood.scale_amount_min = .15*power
		blood.scale_amount_max = .32*power
		var blood_gradient := Gradient.new()
		blood_gradient.set_color(0,Color(0.34,0.075,0.055,0.82))
		blood_gradient.set_color(1,Color(0.08,0.018,0.014,0.0))
		blood.color_ramp = blood_gradient
		var blood_mesh := SphereMesh.new()
		blood_mesh.radius = .055
		blood_mesh.height = .11
		blood_mesh.radial_segments = 6
		blood_mesh.rings = 3
		var blood_material := StandardMaterial3D.new()
		blood_material.albedo_color = Color("#4e211d")
		blood_material.emission_enabled = true
		blood_material.emission = Color("#1b0908")
		blood_material.emission_energy_multiplier = .28
		blood_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		blood_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blood_mesh.material = blood_material
		blood.mesh = blood_mesh
		blood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.add_child(blood)
		blood.emitting = true
		# A billboarded cloud gives the hit a readable silhouette at gameplay
		# distance; the particles above remain the fine spray and residue.
		burst._blood_cloud_material = FxMaterials.glow(Color("#5d2726", 0.78), .46)
		burst._blood_cloud = FxMaterials.sprite(burst, .78 * power, burst._blood_cloud_material)
		burst._blood_cloud.scale = Vector3.ONE * .55
		burst._blood_core_material = FxMaterials.glow(Color("#7b3b35", 0.85), .62)
		burst._blood_core = FxMaterials.sprite(burst, .30 * power, burst._blood_core_material)
		burst._blood_core.scale = Vector3.ONE * .45
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
	if is_instance_valid(_blood_cloud):
		FxMaterials.face_camera(_blood_cloud)
		var cloud_t: float = clampf(_age / .48, 0.0, 1.0)
		_blood_cloud.scale = Vector3.ONE * lerpf(.55, 1.35, smoothstep(0.0, 1.0, cloud_t))
		_blood_cloud_material.set_shader_parameter("strength", maxf(0.0, 1.0 - cloud_t) * .46)
	if is_instance_valid(_blood_core):
		FxMaterials.face_camera(_blood_core)
		var core_t: float = clampf(_age / .20, 0.0, 1.0)
		_blood_core.scale = Vector3.ONE * lerpf(.45, .82, core_t)
		_blood_core_material.set_shader_parameter("strength", maxf(0.0, 1.0 - core_t) * .62)
	(_flash.material_override as ShaderMaterial).set_shader_parameter("strength",maxf(0,1-_age/.055)*1.3)
	_ring.scale = Vector3.ONE*(1+_age*4)
	(_ring.material_override as ShaderMaterial).set_shader_parameter("strength",maxf(0,1-_age/.18)*.25)
	_light.light_energy = maxf(0,1-_age/.08)*1.1
