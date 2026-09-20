class_name DemoGeometry
extends RefCounted

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.8
	if glow > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result

static func mesh(parent: Node3D, shape: Mesh, position: Vector3, surface: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = position
	instance.material_override = surface
	parent.add_child(instance)
	return instance

static func box(parent: Node3D, position: Vector3, size: Vector3, surface: Material, solid: bool = false) -> Node3D:
	var shape := BoxMesh.new()
	shape.size = size
	if not solid:
		return mesh(parent, shape, position, surface)
	var body := StaticBody3D.new()
	body.position = position
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	collision.shape = bounds
	body.add_child(collision)
	mesh(body, shape, Vector3.ZERO, surface)
	return body

static func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, surface: Material, top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0.0 else top
	shape.height = height
	shape.radial_segments = 16
	return mesh(parent, shape, position, surface)

static func sphere(parent: Node3D, position: Vector3, radius: float, surface: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 16
	shape.rings = 8
	return mesh(parent, shape, position, surface)

static func label(parent: Node3D, position: Vector3, words: String, size: int = 34) -> Label3D:
	var result := Label3D.new()
	result.position = position
	result.text = words
	result.font = load("res://assets/materials/trial_font.tres")
	result.font_size = size
	result.pixel_size = 0.004
	result.outline_size = 5
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result.no_depth_test = false
	parent.add_child(result)
	return result
