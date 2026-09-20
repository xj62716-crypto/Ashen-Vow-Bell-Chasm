extends Node
## Single attachment point. Gameplay owns all damage, timing and audio events.
## Candidate visibility here is not an entry in the user's final adoption record.
var trial: MovementTrial
var player_fx: Node
var enemy_fx: Node
var live_ui: Control
var boss_hud: Control
var attached: bool = false

func _ready() -> void:
	call_deferred("_attach")

func _attach() -> void:
	if attached:
		return
	trial = get_parent() as MovementTrial
	if not is_instance_valid(trial) or not is_instance_valid(trial.player):
		push_error("Integrated presentation requires a ready MovementTrial")
		return
	player_fx = load("res://fx_live_r13/live_fx.gd").new()
	player_fx.name = "PlayerEffects"
	add_child(player_fx)
	player_fx.attach(trial)
	enemy_fx = load("res://enemy_fx_r14/live_enemy_fx.gd").new()
	enemy_fx.name = "EnemyEffects"
	enemy_fx.use_candidate_models = true
	add_child(enemy_fx)
	enemy_fx.bind(trial, trial.player)
	live_ui = load("res://ui_live_r12/live_ui.gd").new()
	live_ui.name = "IntegratedUI"
	trial.get_node("UI").add_child(live_ui)
	live_ui.attach(trial)
	boss_hud = load("res://boss_hud_r12/boss_panel.gd").new()
	boss_hud.name = "IntegratedBossHUD"
	trial.get_node("UI").add_child(boss_hud)
	boss_hud.bind(trial, trial.player, trial)
	attached = true
