class_name FxMaterials
extends RefCounted

static func glow(tint: Color, strength: float = 1.0, ring: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/fx_soft.gdshader")
	material.set_shader_parameter("tint",tint)
	material.set_shader_parameter("strength",strength)
	material.set_shader_parameter("ring",1.0 if ring else 0.0)
	return material

static func sprite(parent: Node3D, size: float, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

static func face_camera(node: Node3D) -> void:
	var camera := node.get_viewport().get_camera_3d()
	if camera != null:
		node.global_basis = camera.global_basis
