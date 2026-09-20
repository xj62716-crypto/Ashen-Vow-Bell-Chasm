extends Node
## E04 lamp visual adapter. Caller owns world time and attack events.
const FLAME=preload("res://enemy_fx_r14/lantern_flame.gdshader")
@export_range(0.0,3.0,.05) var intensity: float=1.0
@export_range(0.0,2.0,.05) var light_strength: float=.65
@export_range(.1,5.0,.1) var light_radius_m: float=1.1
var _materials: Array[ShaderMaterial]=[]
var _originals: Array[Dictionary]=[]
var _lamp: OmniLight3D
var _age: float=0.0
var _enabled: bool=true

func bind(model: Node3D) -> Error:
	reset()
	if not is_instance_valid(model):return ERR_INVALID_PARAMETER
	var first: MeshInstance3D
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):
			var material: Material=mesh.get_active_material(i)
			if not material or not material.resource_name.contains("contained ritual flame"):continue
			var shader:=ShaderMaterial.new();shader.shader=FLAME
			shader.set_shader_parameter("layer_phase",float(_materials.size())*1.71)
			_materials.append(shader)
			_originals.append({"mesh":weakref(mesh),"surface":i,"material":mesh.get_surface_override_material(i)})
			mesh.set_surface_override_material(i,shader)
			if not first:first=mesh
	if _materials.size()!=3:
		reset();return ERR_INVALID_DATA
	_lamp=OmniLight3D.new();first.add_child(_lamp)
	_lamp.position=first.get_aabb().get_center();_lamp.light_color=Color("ff9a38")
	_lamp.omni_range=light_radius_m;_lamp.shadow_enabled=false
	_age=0.;_enabled=true;_update()
	return OK

func tick(world_delta: float,enabled: bool=true,paused: bool=false) -> void:
	if not is_finite(world_delta) or world_delta<0:return
	_enabled=enabled
	if not paused and enabled:_age+=world_delta
	_update()

func _update() -> void:
	var value=clampf(intensity,0,3) if is_finite(intensity) and _enabled else 0.0
	for material in _materials:
		material.set_shader_parameter("world_age",_age)
		material.set_shader_parameter("energy",value)
	if is_instance_valid(_lamp):
		_lamp.visible=value>0
		_lamp.omni_range=clampf(light_radius_m,.1,5) if is_finite(light_radius_m) else 1.1
		_lamp.light_energy=(clampf(light_strength,0,2) if is_finite(light_strength) else .65)*value*(.86+.08*sin(_age*6.3)+.06*sin(_age*11.7))

func reset() -> void:
	for row in _originals:
		var mesh=row.mesh.get_ref()
		if is_instance_valid(mesh):mesh.set_surface_override_material(row.surface,row.material)
	_originals.clear();_materials.clear();_age=0
	if is_instance_valid(_lamp):_lamp.free()
	_lamp=null

func _exit_tree() -> void:reset()
