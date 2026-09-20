class_name EncounterDirector
extends Node
## Spatial leases limit overlapping committed threats, not all enemy activity.
const SCENE_META := &"_gameplay_encounter_director"
var leases: Dictionary = {}
var world_time: float = 0.0

static func obtain(scene: Node) -> EncounterDirector:
	var existing := scene.get_node_or_null("GameplayEncounterDirector") as EncounterDirector
	if existing != null: return existing
	if scene.has_meta(SCENE_META):
		var pending := scene.get_meta(SCENE_META) as EncounterDirector
		if is_instance_valid(pending): return pending
	var director := EncounterDirector.new()
	director.name = "GameplayEncounterDirector"
	# Enemy brains can request the director while their room is still adding
	# children. Register it immediately, then attach it after setup completes.
	scene.set_meta(SCENE_META, director)
	scene.add_child.call_deferred(director)
	return director

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE

func _physics_process(delta: float) -> void:
	world_time += delta
	for id in leases.keys():
		var entry: Dictionary = leases[id]
		var actor: Node = entry.owner.get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.health <= 0 or not actor.active or world_time > float(entry.until): leases.erase(id)

func claim(actor: LanternAcolyte, major: bool, seconds: float) -> bool:
	var count := 0
	for entry: Dictionary in leases.values():
		var other := entry.owner.get_ref() as LanternAcolyte
		if not is_instance_valid(other) or other == actor or other.health <= 0 or not other.active or world_time >= float(entry.until): continue
		if other.player != actor.player or other.global_position.distance_to(actor.global_position) > 28: continue
		count += 1
		if major and bool(entry.major): return false
	if count >= 2: return false
	leases[actor.get_instance_id()] = {"owner":weakref(actor), "major":major, "until":world_time+seconds}
	return true

func release(actor: LanternAcolyte) -> void:
	leases.erase(actor.get_instance_id())
