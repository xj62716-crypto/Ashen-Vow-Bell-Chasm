extends Node
## Review fixture clock; real AI/controller methods advance by world delta.
var world_seconds:float=0
var actor:LanternAcolyte
var controller:BossPhaseController
func _physics_process(delta:float)->void:
	world_seconds+=delta
	if is_instance_valid(actor):
		if actor.windup>=0:actor.brain._advance_attack(delta)
		elif actor.brain.recovery_left>0:actor.brain.recovery_left=maxf(0,actor.brain.recovery_left-delta)
	if is_instance_valid(controller):controller.advance(delta)
