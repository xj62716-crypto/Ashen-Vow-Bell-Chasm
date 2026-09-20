extends Node3D
## The measured collision dimensions are authoritative. Decoration never adds collision.
var kind: StringName
var dimensions: Vector3
var pieces: Array[Dictionary]=[]
var sigils: Array[MeshInstance3D]=[]
var born: float=0.0
var released: bool=false
var release_age: float=0.0
var warning: bool=false
var material: StandardMaterial3D
var rune_material: StandardMaterial3D

func _ready() -> void:
	material=StandardMaterial3D.new(); material.albedo_color=Color("898779"); material.roughness=.9
	material.albedo_texture=load("res://fx_live_r13/stone_color.jpg");material.uv1_triplanar=true;material.uv1_world_triplanar=true;material.uv1_scale=Vector3.ONE*.65
	material.normal_enabled=true;material.normal_texture=load("res://fx_live_r13/stone_normal.jpg");material.normal_scale=.23
	rune_material=StandardMaterial3D.new();rune_material.albedo_color=Color("b9aa7e");rune_material.emission_enabled=true;rune_material.emission=Color("7f967b");rune_material.emission_energy_multiplier=.5;rune_material.roughness=.58
	if kind==&"anchor":
		var anchor:Node3D=load("res://environment_live/modules/C19_ritual_anchor.scn").instantiate()
		add_child(anchor);anchor.scale=Vector3.ONE*.65;anchor.position.y=-.47
		anchor.set_meta("asset_id","C19_ritual_anchor")
		for part:MeshInstance3D in anchor.find_children("*","MeshInstance3D",true,false):
			pieces.append({"node":part,"origin":part.position,"delay":0.0})
	else:
		var rows:=7 if kind==&"wall" else 1
		var columns:=8 if kind==&"wall" else 6
		var depth_rows:=1 if kind==&"wall" else 6
		for y in range(rows):
			var stagger:float=.5 if kind==&"wall" and y%2==1 else 0.0
			for z in range(columns+(1 if stagger>0 else 0)):
				for x in range(depth_rows):
					var cell:=dimensions/Vector3(depth_rows,rows,columns)
					var z0:float=maxf(-dimensions.z*.5,(z-stagger)*cell.z-dimensions.z*.5)
					var z1:float=minf(dimensions.z*.5,(z+1-stagger)*cell.z-dimensions.z*.5)
					var size_value:=Vector3(cell.x,cell.y,z1-z0)-Vector3.ONE*.009
					var mesh:=MeshInstance3D.new();mesh.mesh=_beveled_stone(size_value,.022 if kind==&"wall" else .012)
					var stone:StandardMaterial3D=material.duplicate();stone.albedo_color*=.91+float(posmod(y*7+z*3+x,5))*.045;mesh.material_override=stone
					var p:=(Vector3(x+.5,y+.5,z+.5)*cell)-dimensions*.5
					p.z=(z0+z1)*.5
					mesh.position=p;add_child(mesh);pieces.append({"node":mesh,"origin":p,"delay":float(posmod(x*3+y+z,7))*.012})
		if kind==&"wall":
			for side in [-1,1]:
				for column in range(5): _rune(Vector3(side*(dimensions.x*.5+.004),0,(column-2)*1.5),Vector3.RIGHT,.22)
		else:
			for index in range(4):_rune(Vector3((index%2-.5)*dimensions.x*.65,dimensions.y*.5+.004,(index/2-.5)*dimensions.z*.65),Vector3.UP,.15)
	if kind==&"well":
		for index in range(5):
			var ring:=TorusMesh.new();ring.inner_radius=.64+index*.04;ring.outer_radius=ring.inner_radius+.012;ring.rings=32;ring.ring_segments=6
			var mesh:=MeshInstance3D.new();mesh.mesh=ring;mesh.position.y=.35+index*.48;mesh.material_override=rune_material;add_child(mesh);sigils.append(mesh)

func _face(tool:SurfaceTool,vertices:Array[Vector3]) -> void:
	var normal:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
	var center:=Vector3.ZERO
	for vertex in vertices:center+=vertex
	if normal.dot(center)<0:vertices.reverse();normal=-normal
	for index in range(1,vertices.size()-1):
		# Godot front faces are clockwise; retain the outward normal.
		for vertex in [vertices[0],vertices[index+1],vertices[index]]:tool.set_normal(normal);tool.add_vertex(vertex)

func _beveled_stone(extent:Vector3,radius:float) -> ArrayMesh:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h:=extent*.5;var inset:=h-Vector3.ONE*radius
	for axis in range(3):
		var b:int=(axis+1)%3;var c:int=(axis+2)%3
		for sign in [-1,1]:
			var points:Array[Vector3]=[]
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p:=Vector3.ZERO;p[axis]=h[axis]*sign;p[b]=inset[b]*pair.x;p[c]=inset[c]*pair.y;points.append(p)
			_face(tool,points)
	for axes in [Vector3i(0,1,2),Vector3i(0,2,1),Vector3i(1,2,0)]:
		for a in [-1,1]:
			for b in [-1,1]:
				var points:Array[Vector3]=[]
				for pair in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,1)]:
					var p:=Vector3.ZERO;p[axes.x]=(h[axes.x] if pair.x==0 else inset[axes.x])*a;p[axes.y]=(inset[axes.y] if pair.x==0 else h[axes.y])*b;p[axes.z]=inset[axes.z]*pair.y;points.append(p)
				_face(tool,points)
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				var signs:=Vector3(x,y,z)
				_face(tool,[Vector3(h.x,inset.y,inset.z)*signs,Vector3(inset.x,h.y,inset.z)*signs,Vector3(inset.x,inset.y,h.z)*signs])
	return tool.commit()

func _rune(center: Vector3,normal: Vector3,radius: float) -> void:
	var axis:=Vector3.UP if normal==Vector3.RIGHT else Vector3.RIGHT
	var side:=normal.cross(axis)
	var points:=PackedVector3Array([center+axis*radius,center+side*radius*.55,center-axis*radius,center-side*radius*.55,center+axis*radius])
	for i in range(4):
		var line:=CylinderMesh.new();line.top_radius=.008;line.bottom_radius=.008;line.height=points[i].distance_to(points[i+1]);line.radial_segments=6
		var mesh:=MeshInstance3D.new();mesh.mesh=line;mesh.material_override=rune_material;mesh.position=(points[i]+points[i+1])*.5;mesh.quaternion=Quaternion(Vector3.UP,(points[i+1]-points[i]).normalized());add_child(mesh)

func tick(delta: float) -> bool:
	born+=delta
	if released:release_age+=delta
	var fade:=smoothstep(0,.32,release_age) if released else 0.0
	for piece in pieces:
		var p: Vector3=piece.origin
		var forming:=smoothstep(piece.delay,.18+piece.delay,born)
		piece.node.position=p+Vector3.DOWN*((1-forming)*.22+fade*.35)
		piece.node.scale=Vector3.ONE*maxf(.001,(.80+.20*forming)*(1-fade))
		piece.node.transparency=fade
	for index in range(sigils.size()):
		if kind==&"anchor":sigils[index].rotate_y(delta*(.35+index*.12))
		if kind==&"well":sigils[index].position.y=.35+fposmod(born*1.6+index*.48,2.4)
		sigils[index].transparency=fade
	rune_material.emission_energy_multiplier=(.5+(.25+.25*sin(born*6) if warning else 0))*(1-fade)
	return release_age<.33

func release() -> void:released=true
