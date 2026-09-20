extends Node3D
## Visual-only service. The caller supplies world delta and real route/anchor data.
## Does not move the player, create collision or change enemy/world state.
const FX=preload("res://fx_live_r13/fx_revision.gd")
const MAX_ACTIVE=24
const MAX_HISTORY=128
var active: Array[Dictionary]=[]
var next_id: int=1

func create_effect(kind: String, where: Transform3D, hold_seconds: float=0.0, owner_node: Node3D=null) -> int:
	if kind not in FX.TYPES or not where.is_finite():return -1
	while active.size()>=MAX_ACTIVE:_remove_at(0)
	var node=FX.new();node.kind=kind;node.looping=false;add_child(node);node.global_transform=where;node.set_process(false)
	var id=next_id;next_id+=1
	active.append({"id":id,"node":node,"age":0.0,"phase":0.0,"hold":maxf(hold_seconds,0),"released":false,"release_age":0.0,"early_release":false,"release_phase":0.0,"meshes":node.find_children("*","MeshInstance3D",true,false),"owner":weakref(owner_node) if owner_node else null,"path":PackedVector3Array(),"lengths":PackedFloat32Array(),"a":Vector3.ZERO,"b":Vector3.ONE,"slack":.2})
	node.seek(0)
	return id

func set_chain(id: int,start: Vector3,finish: Vector3,slack: float) -> bool:
	if not start.is_finite() or not finish.is_finite() or start.distance_to(finish)>80:return false
	for item in active:
		if item.id!=id:continue
		if item.node.kind!="grapple":return false
		item.a=start;item.b=finish;item.slack=clampf(slack,0,8);return true
	return false

func set_history(id: int,history: PackedVector3Array) -> bool:
	if history.size()<2:return false
	for point in history:
		if not point.is_finite():return false
	var path=PackedVector3Array()
	for i in range(mini(MAX_HISTORY,history.size())):
		var index=roundi(float(i)*(history.size()-1)/(mini(MAX_HISTORY,history.size())-1));var point=history[index]
		if path.is_empty() or point.distance_to(path[-1])>.001:path.append(point)
	if path.size()<2:return false
	var lengths=PackedFloat32Array([0.0])
	for i in range(1,path.size()):lengths.append(lengths[-1]+path[i].distance_to(path[i-1]))
	for item in active:
		if item.id==id and item.node.kind in ["rewind","afterimage"]:
			item.path=path;item.lengths=lengths
			if item.has("history_line") and is_instance_valid(item.history_line):item.history_line.queue_free()
			item.history_line=_history_line(item.node,path)
			return true
	return false

func _history_line(parent:Node3D,path:PackedVector3Array) -> MultiMeshInstance3D:
	var line:=MultiMeshInstance3D.new();parent.add_child(line);line.top_level=true;line.global_transform=Transform3D.IDENTITY
	var mesh:=CylinderMesh.new();mesh.top_radius=.012;mesh.bottom_radius=.012;mesh.height=1;mesh.radial_segments=5
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=path.size()-1;line.multimesh=multi
	var material:=StandardMaterial3D.new();material.albedo_color=Color("8774a0");material.emission_enabled=true;material.emission=Color("706081");material.emission_energy_multiplier=.55
	line.material_override=material;line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in range(path.size()-1):
		var delta:=path[index+1]-path[index]
		var basis:=Basis(Quaternion(Vector3.UP,delta.normalized())).scaled(Vector3(1,delta.length(),1))
		multi.set_instance_transform(index,Transform3D(basis,(path[index]+path[index+1])*.5+Vector3.UP*.065))
	return line

func history_point(item: Dictionary,progress: float) -> Vector3:
	var distance_along=clampf(progress,0,1)*item.lengths[-1]
	for i in range(1,item.path.size()):
		if item.lengths[i]>=distance_along:return item.path[i-1].lerp(item.path[i],inverse_lerp(item.lengths[i-1],item.lengths[i],distance_along))
	return item.path[-1]

func release_effect(id: int) -> void:
	for item in active:
		if item.id==id and not item.released:
			item.released=true;item.release_age=0.0;item.release_phase=item.phase;item.early_release=item.phase<.22

func tick(world_delta: float) -> void:
	if not is_finite(world_delta) or world_delta<=0:return
	# No implicit real-time clock: pause/focus use the caller's authoritative delta.
	for index in range(active.size()-1,-1,-1):
		var item=active[index];var node=item.node
		if not is_instance_valid(node) or (item.owner!=null and item.owner.get_ref()==null):_remove_at(index);continue
		item.age+=world_delta
		if item.hold>0 and item.age>=item.hold:release_effect(item.id)
		var phase: float=item.age/maxf(node.duration,.01)
		if item.released:
			item.release_age+=world_delta;phase=lerpf(.82,1.0,clampf(item.release_age/.28,0,1))
		elif item.hold>0:phase=minf(.56,item.age/.5*.56)
		if phase>=1.0:_remove_at(index);continue
		if item.early_release:phase=item.release_phase
		item.phase=phase
		node.seek(phase)
		if item.early_release:
			var fade=clampf(item.release_age/.28,0,1)
			for mesh in item.meshes:mesh.transparency=fade
			if is_instance_valid(node.light):node.light.light_energy*=1-fade
		if node.kind=="grapple":
			node.set_line_endpoints(node.to_local(item.a),node.to_local(item.b),item.slack)
			# Persist a held chain without the old 1.8-second display timeout.
			var extend=smoothstep(0,.15,item.age)*(1.0-smoothstep(0,.28,item.release_age) if item.released else 1.0)
			node._make_chain(node.line_start.lerp(node.line_end,extend),item.slack)
		if not item.path.is_empty():
			if item.has("history_line"):item.history_line.transparency=1.0-smoothstep(0,.10,phase)*(1.0-smoothstep(.60,1.0,phase))
			var travel=1.0-smoothstep(.08,.85,phase)
			node.global_position=history_point(item,travel)+Vector3.UP*.65
			for i in range(node.ghost_roots.size()):
				var ghost=node.ghost_roots[i]
				var spacing:float=.9/maxf(.01,item.lengths[-1])
				var raw:float=travel+float(i)*spacing
				ghost.visible=(i==0 or (raw<=1 and item.lengths[-1]>float(i)*.9)) and raw*item.lengths[-1]>.8 and (1.0-raw)*item.lengths[-1]>.8
				var u=clampf(raw,0,1);ghost.global_position=history_point(item,u)
				var delta=history_point(item,minf(1,u+.015))-history_point(item,maxf(0,u-.015));delta.y=0
				if delta.length()>.001:ghost.look_at(ghost.global_position+delta.normalized())

func _remove_at(index: int) -> void:
	var node=active[index].node
	if is_instance_valid(node):node.visible=false;node.queue_free()
	active.remove_at(index)

func reset_all() -> void:
	while not active.is_empty():_remove_at(active.size()-1)
