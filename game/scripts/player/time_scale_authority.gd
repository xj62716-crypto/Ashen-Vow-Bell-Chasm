class_name TimeScaleAuthority
extends RefCounted
## Owners release only their own request; freeing one player cannot cancel another.

static var _requests: Dictionary = {}

static func request(owner: Node, scale_value: float) -> void:
	_requests[owner.get_instance_id()] = {"owner": weakref(owner), "scale": clampf(scale_value, 0.1, 1.0)}
	_apply()


static func release(owner: Node) -> void:
	_requests.erase(owner.get_instance_id())
	_apply()


static func _apply() -> void:
	var speed := 1.0
	for id: int in _requests.keys():
		var owner: Node = _requests[id].owner.get_ref()
		if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion():
			_requests.erase(id)
		else:
			speed = minf(speed, float(_requests[id].scale))
	Engine.time_scale = speed
