extends Node3D
## Fits the real 0.55 m objective collision radius. Visual geometry only.
var kind:StringName=&"core"
var rings:Array[MeshInstance3D]=[]
var parts:Array[Dictionary]=[]
var core:MeshInstance3D
var glow:StandardMaterial3D
var age:float=0
var breaking:bool=false
var break_age:float=0

func mat(color:Color,metal:float=0.0,energy:float=0.0)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=.46;m.emission_enabled=energy>0;m.emission=color;m.emission_energy_multiplier=energy;return m

func mesh(geometry:Mesh,position_value:Vector3,material:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=geometry;node.position=position_value;node.material_override=material;add_child(node)
	parts.append({"node":node,"origin":position_value});return node

func _ready()->void:
	var iron:=mat(Color("343832"),.86);var trim:=mat(Color("8e7550"),.7)
	glow=mat(Color("c8662d") if kind==&"core" else Color("9683aa"),.15,.9)
	var crystal:=SphereMesh.new();crystal.radius=.155;crystal.height=.60;crystal.radial_segments=6;crystal.rings=2
	core=mesh(crystal,Vector3.ZERO,glow);core.rotation.z=.12
	for index in range(3):
		var ring:=TorusMesh.new();ring.inner_radius=.32+index*.034;ring.outer_radius=ring.inner_radius+.027;ring.rings=40;ring.ring_segments=8
		var node=mesh(ring,Vector3.ZERO,trim if index==1 else iron);node.rotation=Vector3(index*.8,.2,index*.58);rings.append(node)
	for index in range(6):
		var angle:float=index*TAU/6.;var shard:=PrismMesh.new();shard.size=Vector3(.105,.24,.12)
		var node=mesh(shard,Vector3(sin(angle)*.40,cos(angle)*.40,0),iron);node.rotation.z=-angle
	var seal:=QuadMesh.new();seal.size=Vector2(.28,.28)
	var ink:=ShaderMaterial.new();ink.shader=preload("res://enemy_fx_r14/threat_sigil.gdshader");ink.set_shader_parameter("tint",glow.albedo_color)
	mesh(seal,Vector3(0,0,.17),ink)

func shatter()->void:
	breaking=true

func tick(delta:float)->bool:
	age+=delta
	for index in range(rings.size()):rings[index].rotate_y(delta*(.27+index*.1))
	core.rotate_y(delta*.45);glow.emission_energy_multiplier=.65+.18*sin(age*3.)
	if breaking:
		break_age+=delta;var fade:=clampf(break_age/.48,0,1)
		for index in range(parts.size()):
			var p:Vector3=parts[index].origin;var direction:=Vector3(sin(index*2.39),cos(index*2.39),sin(index*4.9)).normalized()
			parts[index].node.position=p+direction*break_age*.9+Vector3.DOWN*break_age*break_age
			parts[index].node.transparency=fade
	return break_age<.48
