extends Node3D
## Measured moving collision remains gameplay-owned. This is a replaceable skin.
const STONE=preload("res://enemy_fx_r14/construct_skin.gd")
var sections:Array=[]
func bind(source:BossOrbitSurface)->void:
	for collider in source.get_children():
		if not collider is CollisionShape3D or not collider.shape is BoxShape3D:continue
		var size_value:Vector3=collider.shape.size
		var stone=STONE.new();stone.kind=&"wall" if size_value.y>1 else &"platform"
		stone.dimensions=Vector3(size_value.z,size_value.y,size_value.x) if stone.kind==&"wall" else size_value
		add_child(stone);stone.transform=collider.transform
		if stone.kind==&"wall":stone.rotate_y(PI/2)
		stone.born=1.;stone.material.albedo_color=Color("74766d");stone.rune_material.emission=Color("8b779d")
		sections.append(stone)
func tick(delta:float)->void:
	for stone in sections:stone.tick(delta)
