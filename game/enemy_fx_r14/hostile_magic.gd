extends "res://fx_live_r13/live_magic.gd"
## Hostile variants reuse the already verified true-flight/contact lifecycle.
var crossbow:bool=false
var arrow:Node3D
func _ready()->void:
	super._ready()
	if not crossbow:return
	arrow=Node3D.new();add_child(arrow)
	var iron:=StandardMaterial3D.new();iron.albedo_color=Color("5d5547");iron.metallic=.7;iron.roughness=.35
	var wood:=StandardMaterial3D.new();wood.albedo_color=Color("605039");wood.roughness=.8
	var shaft:=CylinderMesh.new();shaft.top_radius=.01;shaft.bottom_radius=.012;shaft.height=.4;shaft.radial_segments=7
	var m:=MeshInstance3D.new();m.mesh=shaft;m.rotation.x=PI/2;m.material_override=wood;arrow.add_child(m)
	var point:=PrismMesh.new();point.size=Vector3(.065,.12,.012)
	m=MeshInstance3D.new();m.mesh=point;m.rotation.x=-PI/2;m.position.z=-.23;m.material_override=iron;arrow.add_child(m)
	for i in range(3):
		var fin:=BoxMesh.new();fin.size=Vector3(.07,.008,.085)
		m=MeshInstance3D.new();m.mesh=fin;m.rotation.z=i*TAU/3;m.position.z=.15;m.material_override=iron;arrow.add_child(m)
func flight(point:Vector3,direction:Vector3,delta:float)->void:
	super.flight(point,direction,delta)
	if crossbow:
		missile.hide();arrow.global_position=point
		arrow.global_basis=Basis.looking_at(direction,Vector3.RIGHT if absf(direction.y)>.95 else Vector3.UP)
func fade_contact(delta:float)->bool:
	if arrow:arrow.hide()
	return super.fade_contact(delta)
