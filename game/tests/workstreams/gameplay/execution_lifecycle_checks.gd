extends "res://tests/workstreams/gameplay/builds_ai_checks.gd"

func _run() -> void:
	arena=Node3D.new()
	root.add_child(arena)
	current_scene=arena
	solid(Vector3(0,-.5,0),Vector3(120,1,120))
	player=load("res://scenes/player/player.tscn").instantiate()
	arena.add_child(player)
	combat=player.get_node("Combat")
	await step(4)
	await fresh("shade")

	# Hit stop has its own clock. It must finish while the player is idle; a
	# follow-up attack is not allowed to be the thing that clears it.
	combat.impact_hold=.12
	combat.attacking=false
	await step(3)
	check(combat.impact_hold < .12 and combat.impact_hold > 0.0,"impact hold advances while no primary attack is active")
	await step(12)
	check(is_zero_approx(combat.impact_hold),"impact hold expires without a second attack or death reset")

	combat.apply_rune(&"shade_wall")
	var foe:=enemy_at(Vector3(0,0,-6),&"crossbow")
	aim(foe)
	check(combat.arts.execute(foe,&"execute"),"pursuit enters through the real execution API")
	var started:=combat.arts.execution_status()
	check(started.phase==&"approach" and started.active and player.blade_approach_active,"pursuit exposes an approach phase and owns player motion")
	check(not combat.try_attack(),"primary attack cannot steal the pursuit approach")
	var arms:=player.get_node("FirstPersonArms")
	arms.trail_samples.append({"a":Vector3.ZERO,"b":Vector3.FORWARD,"age":0.0,"speed":12.0,"powered":true})
	combat.arts.cancel_execution(&"obstructed")
	var cancelled:=combat.arts.execution_status()
	check(cancelled.phase==&"idle" and not cancelled.active and not player.blade_approach_active and cancelled.cancel_reason==&"obstructed","blocked pursuit cancels with a readable lifecycle result")
	check(arms.trail_samples.is_empty(),"pursuit cancellation clears the viewmodel trail immediately")
	foe.queue_free()
	await step(2)

	# A successful contact enters a bounded recovery. Impact stop and recovery use
	# separate clocks, so recovery cannot remain latched by a stale hit pause.
	foe=enemy_at(Vector3(0,0,-6),&"crossbow")
	aim(foe)
	check(combat.arts.execute(foe,&"execute"),"second pursuit can start after cancellation")
	await step(28)
	var resolved:=combat.arts.execution_status()
	check(resolved.phase==&"recovery" or resolved.phase==&"idle","successful pursuit reaches contact and bounded recovery")
	await step(24)
	var recovered:=combat.arts.execution_status()
	check(recovered.phase==&"idle" and not combat.arts.blocks_primary_attack(),"pursuit recovery unlocks primary input on its own clock")

	print("RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
