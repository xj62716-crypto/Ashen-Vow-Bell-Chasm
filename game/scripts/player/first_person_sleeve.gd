class_name FirstPersonSleeve
extends MeshInstance3D
## A continuous sleeve from inside the bracer to a shoulder behind the camera.
## Its elbow follows the posed forearm; its shoulder stays attached to the body.
const RINGS: int = 14
const SIDES: int = 20
var _surface := ImmediateMesh.new()


func _init() -> void:
	mesh = _surface
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func fit_to_arm(forearm: Transform3D, shoulder: Vector3) -> void:
	var start: Vector3 = forearm * Vector3(0, -.025, 0)
	var cuff_exit: Vector3 = forearm * Vector3(0, -.29, 0)
	var axis: Vector3 = forearm.basis.y.normalized()
	var control_a: Vector3 = cuff_exit - axis * 0.09
	var control_b: Vector3 = forearm.origin.lerp(shoulder, 0.65)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for ring in range(RINGS + 1):
		var t: float = float(ring) / RINGS
		# Stay coaxial and narrow until clear of the rigid metal cuff.
		var bend: float = maxf(0.0, (t - 0.24) / 0.76)
		var center: Vector3 = start.lerp(cuff_exit, t / 0.24) if t < 0.24 else cuff_exit.bezier_interpolate(control_a, control_b, shoulder, bend)
		var tangent: Vector3 = -axis if t < 0.24 else cuff_exit.bezier_derivative(control_a, control_b, shoulder, bend).normalized()
		var right: Vector3 = forearm.basis.x.normalized()
		right = (right - tangent * right.dot(tangent)).normalized()
		var across: Vector3 = tangent.cross(right).normalized()
		var radius: float = lerpf(.029,.049,t/.24) if t<.24 else lerpf(.049,.075,smoothstep(0.0,1.0,bend))
		for side in range(SIDES + 1):
			var angle: float = TAU * float(side) / SIDES
			var normal: Vector3 = right * cos(angle) + across * sin(angle)
			vertices.append(center + normal * radius)
			normals.append(normal)
	_surface.clear_surfaces()
	_surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(RINGS):
		for side in range(SIDES):
			var a: int = ring * (SIDES + 1) + side
			var b: int = a + SIDES + 1
			for index: int in [a, b, a + 1, a + 1, b, b + 1]:
				_surface.surface_set_normal(normals[index])
				_surface.surface_set_uv(Vector2(float(index % (SIDES + 1)) / SIDES, float(index / (SIDES + 1)) / RINGS))
				_surface.surface_add_vertex(vertices[index])
	_surface.surface_end()
