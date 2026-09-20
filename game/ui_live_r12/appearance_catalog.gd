extends RefCounted
## Stable-ID mapping; images are versioned separately from gameplay and never apply runes.
const RUNES = preload("res://scripts/run/rune_catalog.gd")
const LINKED = {
	"shade_parry":[&"shade_duel_riposte"],"shade_wall":[&"shade_hunt_chain"],
	"shade_slide":[&"shade_slide_return"],"shade_echo":[&"shade_echo_cut"],
	"arcane_storm":[&"arcane_storm_tempest"],"arcane_shape":[&"arcane_shape_recall"],
	"arcane_seal":[&"arcane_seal_gate"],"arcane_fire":[&"arcane_fire_shatter"],
	"arcane_element":[&"arcane_fire_shatter"],
	"arcane_ice":[&"arcane_ice_nova"],"arcane_float":[&"arcane_split"],"arcane_charge":[&"arcane_network"]}

static func load_index() -> Dictionary:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://ui_live_r12/appearance/catalog.json"))
	return source.get("branches",{}) if source is Dictionary else {}

static func branch(id: StringName, registry: Dictionary) -> String:
	var seen: Array[StringName] = []
	while id!=&"" and id not in seen:
		if registry.has(str(id)): return str(id)
		seen.append(id); id = RUNES.definition(id).get("requires",&"")
	return ""

static func resolve(id: StringName, acquired: Array, registry: Dictionary) -> Dictionary:
	var key := branch(id,registry)
	if key.is_empty(): return {}
	var row: Dictionary = registry[key].duplicate(true)
	var visual_links:Array=LINKED.get(key,[])
	if key.begins_with("arcane_") and key in ["arcane_element","arcane_fire","arcane_ice","arcane_float","arcane_charge"]:
		var future:Array=acquired.duplicate()
		if not id in future:future.append(id)
		var element_key:String="arcane_fire"
		for rune_id in future:
			if str(rune_id)=="arcane_element":element_key="arcane_fire"
			elif str(rune_id) in ["arcane_fire","arcane_ice","arcane_float","arcane_charge"]:element_key=str(rune_id)
		if registry.has(element_key):row.stages=registry[element_key].stages.duplicate(true)
		visual_links=LINKED.get(element_key,[])
	var current := 0
	if StringName(key) in acquired: current = 1
	for trigger in visual_links:
		if trigger in acquired: current = 2
	var next := maxi(current,1) if id==StringName(key) else current
	if id in visual_links: next=2
	var names := ["基础装备","获得核心" if not key in ["arcane_fire","arcane_ice","arcane_float","arcane_charge"] else "获得元素","关键联动"]
	for index in range(row.stages.size()):
		row.stages[index].title=names[index]
		var note := "武器\n初始形态" if index==0 else "武器\n进化形态"
		if index==current: note="武器\n当前阶段"
		if index==next and next!=current: note="武器\n铭刻后抵达"
		if current==next and index==current: note="武器\n本次沿用造型"
		row.stages[index].note=note
	row["branch"]=key; row["current_stage"]=current; row["next_stage"]=next
	return row
