extends "res://tests/workstreams/gameplay/builds_ai_checks.gd"

var blade_projectiles: int = 0
var spell_projectiles: int = 0
var committed_swings: int = 0


func _on_node_added(node: Node) -> void:
	if node is MagicBolt and node.friendly and node.owner_combat == combat:
		if node.element == &"blade":
			blade_projectiles += 1
		else:
			spell_projectiles += 1


func slash_count(label: String) -> int:
	var before := blade_projectiles
	var swings_before := committed_swings
	check(combat.try_attack(), label + " starts a real primary attack")
	await step(65)
	check(committed_swings == swings_before + 1, label + " commits exactly once")
	return blade_projectiles - before


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	current_scene = arena
	solid(Vector3(0, -.5, 0), Vector3(140, 1, 140))
	player = load("res://scenes/player/player.tscn").instantiate()
	arena.add_child(player)
	combat = player.get_node("Combat")
	node_added.connect(_on_node_added)
	combat.swing_started.connect(func(): committed_swings += 1)
	await step(4)

	await fresh("shade")
	check(await slash_count("plain grounded slash") == 0, "plain blade never fires a projectile")
	player._start_dash(Vector3.FORWARD)
	check(player.is_dashing(), "ground dash fixture is active")
	check(await slash_count("plain dash slash") == 0, "dash alone grants no ranged attack")
	for receipt: StringName in [&"wall", &"dash", &"grapple"]:
		await fresh("shade")
		player.global_position = Vector3(0, 12, 0)
		await step(2)
		player.mark_traversal_action(receipt)
		check(not player.is_on_floor() and player.has_recent_traversal_action(), "%s fixture has an airborne traversal receipt" % receipt)
		check(await slash_count("airborne %s slash" % receipt) == 0, "%s receipt alone grants no ranged attack" % receipt)

	await fresh("shade")
	combat.apply_rune(&"shade_wall")
	combat.apply_rune(&"shade_echo")
	player._start_dash(Vector3.FORWARD)
	check(await slash_count("hunt and echo slash") == 0, "hunt and echo cores do not silently unlock sword beams")

	await fresh("shade")
	combat.apply_rune(&"shade_parry")
	check(combat.apply_rune(&"shade_arc"), "explicit sword-beam rune applies")
	check(await slash_count("sword-beam slash") == 1, "explicit sword-beam rune emits one blade projectile")

	await fresh("shade")
	combat.apply_rune(&"shade_parry")
	combat.apply_rune(&"shade_duel_riposte")
	check(await slash_count("unarmed riposte slash") == 0, "riposte rune cannot fire without a successful parry")
	var foe := enemy_at(Vector3(10, 0, -8))
	combat.confirm_parry(foe)
	check(await slash_count("armed riposte slash") == 1 and not combat.riposte_ready, "successful parry grants and consumes one ranged riposte")
	check(await slash_count("consumed riposte slash") == 0, "ranged riposte cannot repeat after consumption")

	await fresh("shade")
	combat.apply_rune(&"shade_slide")
	combat.apply_rune(&"shade_slide_wind")
	check(await slash_count("idle slide-wind slash") == 0, "slide-wind rune requires an actual slide window")
	player.slide_started.emit()
	player.slide_jumped.emit()
	check(await slash_count("slide-jump wind slash") == 1, "slide-jump rune still emits the authored low blade wave")

	await fresh("arcanist")
	var spells_before := spell_projectiles
	check(await slash_count("staff cast") == 0 and spell_projectiles == spells_before + 1, "staff retains its own ranged spell")
	await fresh("shade")
	var arms := player.get_node("FirstPersonArms") as FirstPersonArms
	check(not arms.get_item_definition(&"right").ranged and combat.runes.is_empty() and not combat.riposte_ready, "class swap clears staff and ranged build state")
	spells_before = spell_projectiles
	player._start_dash(Vector3.FORWARD)
	check(await slash_count("blade after staff swap") == 0 and spell_projectiles == spells_before, "class swap cannot leak staff projectiles into a blade slash")

	arena.queue_free()
	await step(4)
	print("RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
