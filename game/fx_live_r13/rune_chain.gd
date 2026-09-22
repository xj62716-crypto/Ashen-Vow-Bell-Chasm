extends Node3D
## Magical traction; actual launch/pull/release states, no movement or prediction.
var chain: MultiMeshInstance3D
var material: StandardMaterial3D
var beam: MeshInstance3D
var beam_mesh := ImmediateMesh.new()
var beam_material: StandardMaterial3D
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
	var ring:=TorusMesh.new();ring.inner_radius=.024;ring.outer_radius=.034;ring.rings=12;ring.ring_segments=5
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=ring;multi.instance_count=512;multi.visible_instance_count=0
	chain=MultiMeshInstance3D.new();chain.multimesh=multi;chain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(chain)
	material=StandardMaterial3D.new();material.albedo_color=Color("8db6d9");material.metallic=.42;material.roughness=.24;material.emission_enabled=true;material.emission=Color("5aa7ff");material.emission_energy_multiplier=1.15;chain.material_override=material
	beam=MeshInstance3D.new();beam.mesh=beam_mesh;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam_material=StandardMaterial3D.new();beam_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;beam_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;beam_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;beam_material.vertex_color_use_as_albedo=true;beam_material.albedo_color=Color("9dd5ff");beam_material.emission_enabled=true;beam_material.emission=Color("64b6ff");beam_material.emission_energy_multiplier=2.4;beam_material.cull_mode=BaseMaterial3D.CULL_DISABLED;beam.material_override=beam_material;add_child(beam)
	var rune:=TorusMesh.new();rune.inner_radius=.06;rune.outer_radius=.066;rune.rings=4;rune.ring_segments=4
	var runes:=MultiMesh.new();runes.transform_format=MultiMesh.TRANSFORM_3D;runes.mesh=rune;runes.instance_count=24;runes.visible_instance_count=0
	seals=MultiMeshInstance3D.new();seals.multimesh=runes;seals.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(seals)
	var seal_material:=StandardMaterial3D.new();seal_material.albedo_color=Color("b4bf96");seal_material.emission_enabled=true;seal_material.emission=Color("95b39d");seal_material.emission_energy_multiplier=.85;seals.material_override=seal_material

func update_endpoints(start:Vector3,finish:Vector3,state:Dictionary) -> void:
	last_start=start;last_finish=finish;phase=str(state.phase)
	var launch:float=clampf(float(state.elapsed)/ParkourGrapple.LAUNCH_TIME,0,1) if phase=="launch" else 1.0
	visible_finish=start.lerp(finish,launch)
	var distance:=start.distance_to(visible_finish)
	beam_mesh.clear_surfaces()
	if distance<.02:chain.multimesh.visible_instance_count=0;seals.multimesh.visible_instance_count=0;return
	var forward:Vector3=(visible_finish-start).normalized()
	var side:Vector3=forward.cross(Vector3.RIGHT if absf(forward.y)>.95 else Vector3.UP).normalized()
	beam_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(10):
		var t:float=index/9.0
		var point:Vector3=to_local(start.lerp(visible_finish,t))
		var width:float=lerpf(.040,.010,t)*(1.0+.12*sin(world_age*18.0+t*TAU*2.0))
		beam_mesh.surface_set_color(Color(0.62,0.84,1.0,.78+.22*sin(world_age*14.0+t*TAU*3.0)))
		beam_mesh.surface_add_vertex(point-side*width)
		beam_mesh.surface_add_vertex(point+side*width)
	beam_mesh.surface_end()
	active_links=clampi(int(distance/.084),1,512)
	chain.multimesh.visible_instance_count=active_links
	for index in range(active_links):
		var u:float=(index+.5)/float(active_links)
		var p:=start.lerp(visible_finish,u)
		var up:=side.cross(forward).normalized()
		if index%2==1:var old:=side;side=up;up=-old
		var basis:=Basis(side,up,forward).scaled(Vector3(1,1,1.7))
		chain.multimesh.set_instance_transform(index,Transform3D(basis,to_local(p)))
	var up:=side.cross(forward).normalized()
	var count:int=clampi(int(distance/1.4),1,24);seals.multimesh.visible_instance_count=count
	for index in range(count):
		var u:float=fposmod(float(index)/count-world_age*.9,1.0)
		var basis:=Basis(side,forward,-up).rotated(forward,PI*.25+world_age*.65)
		seals.multimesh.set_instance_transform(index,Transform3D(basis,to_local(start.lerp(visible_finish,u))))
	material.emission_energy_multiplier=1.0 if phase=="launch" else 1.35
	beam_material.emission_energy_multiplier=2.0 if phase=="launch" else 2.8

func release(exit_reason:String="") -> void:
	if fading:return
	fading=true;phase="detached";reason=exit_reason
func tick(delta: float) -> bool:
	world_age+=delta
	if fading:
		fade_age+=delta;chain.transparency=clampf(fade_age/.18,0,1);seals.transparency=chain.transparency;beam.transparency=clampf(fade_age/.14,0,1)
	return fade_age<.18
