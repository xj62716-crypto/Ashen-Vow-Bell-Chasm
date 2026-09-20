extends Node3D
## Open geometry leaves the body/weak point readable. No collision or immunity.
var rings:Array[MeshInstance3D]=[]
var material:StandardMaterial3D
var age:float=0
var state:StringName=&"dormant"
var closed:bool=false

func _ready()->void:
	material=StandardMaterial3D.new();material.albedo_color=Color("78654e");material.metallic=.7;material.roughness=.5
	material.emission_enabled=true;material.emission=Color("936636");material.emission_energy_multiplier=.5
	for index in range(3):
		var mesh:=TorusMesh.new();mesh.inner_radius=1.0+index*.08;mesh.outer_radius=mesh.inner_radius+.014;mesh.rings=64;mesh.ring_segments=6
		var ring:=MeshInstance3D.new();ring.mesh=mesh;ring.material_override=material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring);ring.rotation=Vector3(PI/2,index*PI/3,.2);rings.append(ring)

func update_state(value:StringName,type:StringName)->void:
	state=value;closed=value==&"shielded";visible=value in [&"shielded",&"exposed"]
	material.emission=Color("9f7140") if type==&"forge" else Color("8d749c")
	if value==&"exposed":material.emission=Color("d6bc7d")

func tick(delta:float)->void:
	age+=delta
	for index in range(rings.size()):
		rings[index].visible=closed or index==0
		rings[index].rotate_y(delta*(.22+index*.08))
		rings[index].scale=Vector3.ONE*(1.0 if closed else .28)
	material.emission_energy_multiplier=.35 if closed else .8+.15*sin(age*4.)
