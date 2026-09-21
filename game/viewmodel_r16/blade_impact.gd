extends Node3D
## Short real-contact accent. World-time, pause and lifecycle follow the scene.
var flash_seconds:float=.045
var strength:float=.7
var style:int=0
var metal:bool=false
var elapsed:float=0
var pieces:Array=[]
var flash:MeshInstance3D
var tint:Color=Color("cedce0")
var cut_direction:Vector3=Vector3.RIGHT
var mist:MeshInstance3D
var mist_material:ShaderMaterial
var mist_opacity:float=.68
var mist_size:Vector2=Vector2(.62,.48)
var mist_lifetime:float=.32
var mist_speed:float=.9
var mist_expansion:float=4.8

func _init()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE

func material(colour:Color,emission:float)->StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	result.albedo_color=colour;result.emission_enabled=true;result.emission=colour
	result.emission_energy_multiplier=emission;result.cull_mode=BaseMaterial3D.CULL_DISABLED
	return result

func ribbon(a:Vector3,b:Vector3,width:float,colour:Color,emission:float)->MeshInstance3D:
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var across:Vector3=(b-a).normalized().cross(Vector3.BACK)*width
	var middle:Vector3=(a+b)*.5
	var points:Array[Vector3]=[a,middle+across,b,a,b,middle-across]
	var uvs:Array[Vector2]=[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]
	for index in points.size():
		mesh.surface_set_uv(uvs[index]);mesh.surface_add_vertex(points[index])
	mesh.surface_end()
	var part:=MeshInstance3D.new();part.mesh=mesh;part.material_override=material(colour,emission)
	part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(part);return part

func _ready()->void:
	var local_cut:Vector3=cut_direction.normalized()
	flash=ribbon(-local_cut*.16+Vector3(0,0,.025),local_cut*.21+Vector3(0,0,.025),.022,tint,2.4)
	var contact_material:=ShaderMaterial.new()
	contact_material.shader=preload("res://viewmodel_r16/blade_contact_flash.gdshader")
	contact_material.set_shader_parameter("colour",tint)
	flash.material_override=contact_material
	mist=MeshInstance3D.new();var cloud:=QuadMesh.new();cloud.size=mist_size;mist.mesh=cloud
	mist_material=ShaderMaterial.new();mist_material.shader=preload("res://viewmodel_r16/blade_contact_mist.gdshader")
	mist_material.set_shader_parameter("opacity",mist_opacity)
	mist.material_override=mist_material;mist.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mist);mist.position.z=.02;mist.rotation.z=atan2(local_cut.y,local_cut.x)
	var rng:=RandomNumberGenerator.new();rng.seed=271+style*47
	for i in range(roundi((14 if metal else 9)*strength)):
		var angle:float=rng.randf_range(-PI,PI)
		var direction:=Vector3(cos(angle),sin(angle),rng.randf_range(.1,.8))
		direction=(direction*.45+local_cut*.7).normalized()
		if style==3:direction.y=-absf(direction.y)*.6
		var colour:Color=Color("b9a079") if metal else Color("501923")
		var part:=ribbon(Vector3.ZERO,direction*(.055 if metal else .025),.0018 if metal else .004,colour,1.2 if metal else .05)
		pieces.append({"node":part,"velocity":direction*rng.randf_range(.7,2.4),"life":rng.randf_range(.09,.24)})
		if style==1:
			part.position=direction*.18;pieces.back().velocity=-direction*1.3
		elif style==4:
			pieces.back().velocity.y=absf(pieces.back().velocity.y)+.4
	# Small splinters follow the cut. No screen-spanning blood band or target ring.
	for i in range(4):
		var angle:float=rng.randf_range(-PI,PI)
		var direction:Vector3=(local_cut+Vector3(cos(angle),sin(angle),.25)*.6).normalized()
		var part:=ribbon(direction*.015,direction*rng.randf_range(.035,.065),.0015,Color("ab9979"),1.3)
		pieces.append({"node":part,"velocity":direction*1.6,"life":.14})

func _process(delta:float)->void:
	elapsed+=delta
	if elapsed>=maxf(.26,mist_lifetime):queue_free();return
	flash.visible=elapsed<flash_seconds
	if is_instance_valid(mist):
		mist_material.set_shader_parameter("progress",clampf(elapsed/mist_lifetime,0.,1.))
		mist.scale=Vector3(1.+elapsed*mist_expansion,1.+elapsed*mist_expansion*1.35,1.)
		mist.position+=cut_direction.normalized()*delta*mist_speed
	for row in pieces:
		var part:MeshInstance3D=row.node
		part.position+=row.velocity*delta;row.velocity.y-=2.5*delta
		part.visible=elapsed<row.life
		var mat:StandardMaterial3D=part.material_override
		mat.albedo_color.a=1.0-clampf(elapsed/row.life,0,1)
