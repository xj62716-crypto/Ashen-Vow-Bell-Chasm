extends Node3D
## Magical traction; actual launch/pull/release states, no movement or prediction.
var chain: MultiMeshInstance3D
var material: StandardMaterial3D
var last_start: Vector3
var last_finish: Vector3
var visible_finish:Vector3
var phase:String="idle"
var reason:String=""
var seals:MultiMeshInstance3D
var world_age:float=0.0
var active_links: int=0
var fading: bool=false
var fade_age: float=0.0

func _ready() -> void:
	var ring:=TorusMesh.new();ring.inner_radius=.021;ring.outer_radius=.031;ring.rings=12;ring.ring_segments=5
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=ring;multi.instance_count=512;multi.visible_instance_count=0
	chain=MultiMeshInstance3D.new();chain.multimesh=multi;chain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(chain)
	material=StandardMaterial3D.new();material.albedo_color=Color("33466e");material.metallic=.62;material.roughness=.32;material.emission_enabled=true;material.emission=Color("4f8dff");material.emission_energy_multiplier=.58;chain.material_override=material
	var rune:=TorusMesh.new();rune.inner_radius=.06;rune.outer_radius=.066;rune.rings=4;rune.ring_segments=4
	var runes:=MultiMesh.new();runes.transform_format=MultiMesh.TRANSFORM_3D;runes.mesh=rune;runes.instance_count=24;runes.visible_instance_count=0
	seals=MultiMeshInstance3D.new();seals.multimesh=runes;seals.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(seals)
	var seal_material:=StandardMaterial3D.new();seal_material.albedo_color=Color("d5e9ff");seal_material.emission_enabled=true;seal_material.emission=Color("9ecbff");seal_material.emission_energy_multiplier=1.2;seals.material_override=seal_material

func update_endpoints(start:Vector3,finish:Vector3,state:Dictionary) -> void:
	last_start=start;last_finish=finish;phase=str(state.phase)
	var launch:float=clampf(float(state.elapsed)/ParkourGrapple.LAUNCH_TIME,0,1) if phase=="launch" else 1.0
	visible_finish=start.lerp(finish,launch)
	var distance:=start.distance_to(visible_finish)
	if distance<.02:chain.multimesh.visible_instance_count=0;seals.multimesh.visible_instance_count=0;return
	active_links=clampi(int(distance/.084),1,512)
	chain.multimesh.visible_instance_count=active_links
	for index in range(active_links):
		var u:float=(index+.5)/float(active_links)
		var p:=start.lerp(visible_finish,u)
		var forward:Vector3=(visible_finish-start).normalized()
		var side:=forward.cross(Vector3.RIGHT if absf(forward.y)>.95 else Vector3.UP).normalized()
		var up:=side.cross(forward).normalized()
		if index%2==1:var old:=side;side=up;up=-old
		var basis:=Basis(side,up,forward).scaled(Vector3(1,1,1.7))
		chain.multimesh.set_instance_transform(index,Transform3D(basis,to_local(p)))
	var forward:Vector3=(visible_finish-start).normalized()
	var side:=forward.cross(Vector3.RIGHT if absf(forward.y)>.95 else Vector3.UP).normalized()
	var up:=side.cross(forward).normalized()
	var count:int=clampi(int(distance/1.4),1,24);seals.multimesh.visible_instance_count=count
	for index in range(count):
		var u:float=fposmod(float(index)/count-world_age*.9,1.0)
		var basis:=Basis(side,forward,-up).rotated(forward,PI*.25+world_age*.65)
		seals.multimesh.set_instance_transform(index,Transform3D(basis,to_local(start.lerp(visible_finish,u))))
	material.emission_energy_multiplier=.42 if phase=="launch" else .72

func release(exit_reason:String="") -> void:
	if fading:return
	fading=true;phase="detached";reason=exit_reason
func tick(delta: float) -> bool:
	world_age+=delta
	if fading:fade_age+=delta;chain.transparency=clampf(fade_age/.18,0,1);seals.transparency=chain.transparency
	return fade_age<.18
