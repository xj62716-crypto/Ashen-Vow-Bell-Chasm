class_name SpellBlast
extends Node3D
var radius: float = 3.0
var tint := Color("#ef8749")
var _age: float = 0.0
var _rings: Array[MeshInstance3D] = []

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	for angle: Vector3 in [Vector3(PI/2,0,0),Vector3.ZERO,Vector3(0,PI/2,0)]:
		var ring := FxMaterials.sprite(self,2.85,FxMaterials.glow(tint,.35,true))
		ring.rotation = angle
		_rings.append(ring)

func _process(delta: float) -> void:
	_age += delta
	if _age>.35:
		queue_free()
		return
	var reach: float = radius*(1-pow(1-minf(1,_age/.3),3))
	for ring in _rings:
		ring.scale = Vector3.ONE*maxf(.05,reach)
		(ring.material_override as ShaderMaterial).set_shader_parameter("strength",(1-_age/.35)*.35)
