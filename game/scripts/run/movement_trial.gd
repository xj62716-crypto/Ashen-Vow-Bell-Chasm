class_name MovementTrial
extends Node3D
## 此管理器负责试炼状态、检查点与界面，不包含角色运动公式。

enum Phase { READY, RUNNING, PAUSED, FINISHED, DEFEATED, REWARD }
@export var stage_count: int = 3
@export var formal_release: bool = false
const SETTINGS_PATH := "user://movement_trial.cfg"
const PROFILES: Array[ParkourProfile] = [preload("res://data/classes/shade.tres"), preload("res://data/classes/arcanist.tres")]

@onready var player: ParkourPlayer = $Player
@onready var hud: TrialHUD = $UI/HUD
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var audio: TrialAudio = $Audio
@onready var combat: PlayerCombat = $Player/Combat
@onready var combat_room: CombatRoom = $CombatRoom

var phase: Phase = Phase.READY
var elapsed: float = 0.0
var stage_elapsed: float = 0.0
var stage_splits: Array[float] = []
var best_time: float = 0.0
var checkpoint_index: int = 0
var combat_checkpoint_index: int = 0
var falls: int = 0
var retries: int = 0
var sound_volume: float = 0.65
var music_volume: float = 0.4
var brightness: float = 1.15
var _checkpoint: Transform3D
var _checkpoint_areas: Array[Area3D] = []
var practice_mode: bool = false
var combat_mode: bool = false
var stage_number: int = 1
var reward_options: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _practice_jump_done: bool = false
var _best_records: Dictionary = {}
var _active_altar: RunAltar
var gameplay_audio: Node
var _combat_checkpoint_defeated:Array[StringName]=[]
var _combat_checkpoint_kills:int=0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_checkpoint = spawn_point.global_transform
	hud.start_requested.connect(start_run)
	hud.resume_requested.connect(resume_run)
	hud.restart_requested.connect(start_run)
	hud.quit_requested.connect(_quit)
	hud.sensitivity_changed.connect(_set_sensitivity)
	hud.fov_changed.connect(_set_fov)
	hud.volume_changed.connect(_set_volume)
	hud.music_volume_changed.connect(_set_music_volume)
	hud.brightness_changed.connect(_set_brightness)
	hud.feedback_changed.connect(_set_feedback)
	hud.rune_selected.connect(choose_rune)
	player.jumped.connect(_jump_sound)
	player.dashed.connect(func(): _play("dash"))
	player.landed.connect(func(impact: float): _play("land", clampf(impact / 14.0, 0.25, 1.0)))
	player.fell_out.connect(_fell)
	player.wall_run_started.connect(func(_side: int): _play("footstep", 0.65))
	player.wall_jumped.connect(func(_normal: Vector3): _practice_jump_done = true)
	player.wall_bonus_triggered.connect(func(_bonus: StringName): hud.toast("借势 · 空中冲刺已恢复"))
	combat.swing_started.connect(func(): _play("cast_"+str(combat.spell_element()) if player.parkour_profile.id==&"arcanist" else ("cut_return" if combat.swing_return else "cut_outward")))
	combat.spell_contact.connect(func(element: StringName): _play("impact_"+str(element),.85))
	combat.hit_confirmed.connect(_combat_hit)
	combat.hurt.connect(func(_amount: int): hud.show_hurt(); _play("hurt"))
	combat.died.connect(_combat_died)
	combat_room.enemy_fired.connect(func():
		if gameplay_audio==null or not gameplay_audio.supported():_play("hostile_bolt",.45))
	combat_room.guard_broken.connect(func(): _play("guard_break",.75))
	combat_room.cleared.connect(_room_cleared)
	combat_room.altar_requested.connect(_open_altar)
	combat_room.mechanism_used.connect(func(): _play("checkpoint",.8))
	combat_room.checkpoint_reached.connect(_combat_checkpoint_reached)
	combat.ability_used.connect(func():
		# Raising the blade to guard is neither a slash nor a contact.
		# Real parry/contact signals own their sounds.
		if player.parkour_profile.id!=&"shade":_play("bolt",.9))
	combat.parried.connect(func(): _play("parry",1.0); hud.show_hit(false))
	combat.arts.performed.connect(func(kind: StringName):_play(str(kind),.85))
	combat.blocked_hit.connect(func(): _play("parry",.55))
	player.slide_started.connect(func(): _play("slide",.9))
	for child: Node in $Triggers.get_children():
		if child is Area3D:
			var area := child as Area3D
			area.body_entered.connect(_trigger_entered.bind(area))
			_checkpoint_areas.append(area)
	gameplay_audio = preload("res://scripts/combat/gameplay_audio_bridge.gd").new()
	add_child(gameplay_audio)
	gameplay_audio.configure(player,audio)
	_load_settings()
	_rng.randomize()
	if formal_release:
		# The old scene serialized a one-stage preview. The formal lifecycle now
		# includes the existing miniboss and final-boss stages as specified by QA.
		stage_count = 3
		combat_mode=true
		combat_room.visible=true
	_set_practice_geometry(false)
	audio.set_phase("ready")
	_update_stage(0)
	hud.show_menu("ready")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if phase == Phase.RUNNING:
		var real_delta:=delta/maxf(0.001,Engine.time_scale)
		elapsed += real_delta
		stage_elapsed += real_delta
		hud.update_run(player, elapsed, checkpoint_index, falls)
		if combat_mode:
			gameplay_audio.update_context(combat_room)
			var nearby: int=0
			for enemy in combat_room.enemies:
				if enemy.health>0 and enemy.global_position.distance_to(player.global_position)<23:nearby+=1
			audio.update_encounter(stage_number,minf(1,nearby*.25+(0.15 if player.horizontal_speed()>12 else 0)))


func _physics_process(delta: float) -> void:
	if phase == Phase.RUNNING:
		audio.update_footsteps(player, delta)
		if practice_mode and player.is_on_floor() and ($WallPractice/Finish as Area3D).overlaps_body(player):
			if _practice_jump_done:
				finish_run()
			else:
				hud.objective_label.text = "还需完成一次蹬墙跳 · R 返回起点重试"
		if combat_mode and combat_room.exit_unlocked and player.is_on_floor() and combat_room.exit_area.overlaps_body(player):
			if stage_number<stage_count:
				_next_stage.call_deferred()
			else:
				finish_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if phase == Phase.RUNNING:
			pause_run()
		elif phase == Phase.PAUSED:
			resume_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_checkpoint") and phase == Phase.RUNNING:
		if combat_mode:
			_retry_combat_checkpoint.call_deferred()
			return
		retries += 1
		_recover()
		hud.toast("已返回检查点")
	elif event.is_action_pressed("toggle_debug"):
		hud.telemetry_label.visible = not hud.telemetry_label.visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == Phase.RUNNING and not bool(get_meta("recording_focus_exempt",false)):
		pause_run()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_save_settings()


func start_run() -> void:
	# A defeat-menu restart is a checkpoint retry only when the selected class
	# still owns the current run. Changing class must rebuild the whole room so
	# the old weapon, profile and checkpoint state cannot leak into the new run.
	var selected_profile_id: StringName = PROFILES[clampi(hud.class_choice.selected, 0, PROFILES.size() - 1)].id
	var class_changed := is_instance_valid(player) and player.parkour_profile.id != selected_profile_id
	if phase==Phase.DEFEATED and combat_mode and not class_changed:
		_retry_combat_checkpoint()
		return
	var retrying := phase == Phase.DEFEATED
	get_tree().paused = false
	if (formal_release or hud.course_choice.selected == 2) and not _load_combat_room(1): return
	elapsed = 0.0
	stage_elapsed = 0.0
	stage_splits.clear()
	checkpoint_index = 0
	combat_checkpoint_index=0
	falls = 0
	retries = 0
	player.jump_count = 0
	player.dash_count = 0
	player.wall_run_count = 0
	player.wall_jump_count = 0
	player.dash_refund_count = 0
	_practice_jump_done = false
	practice_mode = not formal_release and hud.course_choice.selected == 1
	combat_mode = formal_release or hud.course_choice.selected == 2
	stage_number = 1
	hud._on_class_selected(hud.class_choice.selected)
	reward_options.clear()
	_active_altar = null
	hud.hide_rewards()
	_set_practice_geometry(practice_mode)
	combat_room.set_enabled(combat_mode)
	player.apply_profile(PROFILES[clampi(hud.class_choice.selected, 0, PROFILES.size() - 1)].duplicate() as ParkourProfile)
	if not combat_mode:
		(player.get_node("FirstPersonArms") as FirstPersonArms).unequip_item(&"right")
		var practice_item: HeldItemDefinition = null
		if hud.item_choice.selected == 1:
			practice_item = preload("res://data/equipment/long_sword.tres")
		elif hud.item_choice.selected == 2:
			practice_item = preload("res://data/equipment/arcane_staff.tres")
		if practice_item != null:
			(player.get_node("FirstPersonArms") as FirstPersonArms).equip_item(&"right", practice_item)
	best_time = float(_best_records.get(_record_key(), 0.0))
	_checkpoint = ($WallPractice/Spawn as Marker3D).global_transform if practice_mode else spawn_point.global_transform
	if combat_mode:
		_configure_encounter()
		_checkpoint = combat_room.spawn.global_transform
	player.respawn_at(_checkpoint)
	combat.enabled = true
	combat.reset_run()
	if combat_mode:_capture_combat_checkpoint(0)
	hud.reset_combat_feedback()
	audio.stop_effects()
	audio.reset_steps(player.global_position)
	if retrying and gameplay_audio.supported(): audio.set_phase("retry")
	audio.set_phase("running")
	player.control_enabled = true
	phase = Phase.RUNNING
	_update_stage(0)
	hud.hide_menu()
	hud.toast("靠右起跳，按住 W 贴墙前进" if practice_mode else "循着火光前进 · SPACE 起跳")
	if combat_mode:
		hud.toast("第一段 · " + combat_room.stage_title)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func pause_run() -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.PAUSED
	_suspend_gameplay(&"paused")
	combat.arts._held=0
	if is_instance_valid(combat.arts._preview):combat.arts._preview.hide()
	audio.set_phase("paused")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu("paused")
	_save_settings()


func resume_run() -> void:
	if phase != Phase.PAUSED:
		return
	var selected_profile_id: StringName = PROFILES[clampi(hud.class_choice.selected, 0, PROFILES.size() - 1)].id
	if is_instance_valid(player) and player.parkour_profile.id != selected_profile_id:
		# The pause menu can leave the class selector focused. Treat that as a
		# deliberate new run instead of resuming with a mismatched checkpoint.
		get_tree().paused = false
		phase = Phase.DEFEATED
		start_run()
		return
	_save_settings()
	hud.hide_menu()
	phase = Phase.RUNNING
	get_tree().paused = false
	audio.set_phase("running")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _trigger_entered(body: Node3D, area: Area3D) -> void:
	if body != player or phase != Phase.RUNNING or practice_mode or combat_mode:
		return
	var index: int = int(area.get_meta("checkpoint_index", 0))
	if index == 3:
		if checkpoint_index == 2:
			finish_run()
		return
	if index != checkpoint_index + 1:
		return
	checkpoint_index = index
	_checkpoint = (area.get_node("RespawnPoint") as Marker3D).global_transform
	_update_stage(index)
	hud.toast("检查点 %d 已激活 · 失足后从这里继续" % index)
	_play("checkpoint")


func _fell() -> void:
	if phase != Phase.RUNNING:
		return
	falls += 1
	if combat_mode:
		combat.health=0
		_combat_died()
		return
	_recover()
	hud.toast("失足了 · 已返回检查点")


func _update_stage(index: int) -> void:
	hud.practice_mode = practice_mode
	hud.combat_mode = combat_mode
	hud.set_stage(index)
	if formal_release:return
	$Signs.visible = not practice_mode and not combat_mode
	$Signs/Intro.visible = index == 0
	$Signs/IntroHelp.visible = index == 0
	$Signs/Dash.visible = index == 1
	$Signs/DashHelp.visible = index == 1
	$Signs/Chain.visible = index == 2
	$Signs/FinishTitle.visible = index == 2


func _recover() -> void:
	if combat_mode and not _load_combat_room(stage_number): return
	_practice_jump_done = false
	player.respawn_at(_checkpoint)
	if combat_mode:
		_configure_encounter()
		combat.shield = false
		hud.reset_combat_feedback()
	audio.stop_effects()
	audio.reset_steps(player.global_position)


func finish_run() -> void:
	if combat_mode and stage_splits.size()<stage_number:
		stage_splits.append(stage_elapsed)
	phase = Phase.FINISHED
	_suspend_gameplay(&"finished", true)
	audio.set_phase("finished")
	player.control_enabled = false
	combat.cancel_attack()
	if combat_mode:
		combat_room.clear_effects()
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var new_record: bool = best_time <= 0.0 or elapsed < best_time
	if new_record:
		best_time = elapsed
		_best_records[_record_key()] = best_time
	_save_settings()
	_play("finish")
	var summary: String = "用时 %s  ·  失足 %d  ·  手动返回 %d\n跳跃 %d  ·  冲刺 %d  ·  最佳 %s%s" % [TrialHUD.format_time(elapsed), falls, retries, player.jump_count, player.dash_count, TrialHUD.format_time(best_time), "  新纪录" if new_record else ""]
	if practice_mode:
		summary = "%s · 用时 %s · 失足 %d\n蹬墙跳 %d 次 · 同职业最佳 %s%s" % [player.parkour_profile.display_name, TrialHUD.format_time(elapsed), falls, player.wall_jump_count, TrialHUD.format_time(best_time), "  新纪录" if new_record else ""]
	if combat_mode:
		var split_text:=PackedStringArray()
		for index in stage_splits.size():split_text.append("%02d %s"%[index+1,TrialHUD.format_time(stage_splits[index])])
		summary = "%s · %s已解封\n总用时 %s · 分关 %s\n生命 %d · 击杀 %d · 命中 %d · 攻击 %d\n蹬墙 %d · 符文：%s" % [player.parkour_profile.display_name, combat_room.stage_title if formal_release else "三段回廊", TrialHUD.format_time(elapsed), "  /  ".join(split_text), combat.health, combat.kills, combat.hits, combat.attacks, player.wall_jump_count, " / ".join(combat.runes.map(func(id: StringName): return RuneCatalog.title(id)))]
	hud.show_menu("finished", summary)


func _record_key() -> String:
	if combat_mode:
		return "demo_v09_" + str(player.parkour_profile.id)
	return ("wall_v04_" if practice_mode else "movement_v04_") + str(player.parkour_profile.id)


func _combat_hit(target: Node3D, point: Vector3, defeated: bool) -> void:
	var melee: bool=player.parkour_profile.id==&"shade"
	if melee:_play("kill" if defeated else "hit")
	hud.show_hit(defeated)
	if melee and not player.get_node("FirstPersonArms").has_method("blade_contact_accent"):
		ImpactBurst.spawn(target.get_parent(), point, Color("#f2c590"),1.15 if defeated else .8,&"blade",player.camera.global_basis.x+Vector3.UP*.4)
	if combat_mode:
		hud.objective_label.text = "敌人 %d / %d" % [combat_room.defeated_count,combat_room.enemies.size()]
		if target is LanternAcolyte and is_instance_valid(target.boss_controller):
			hud.objective_label.text = target.boss_controller.objective_text()


func _room_cleared() -> void:
	if phase != Phase.RUNNING:
		return
	_play("checkpoint")
	hud.toast("封印已解 · 前往出口")


func _open_reward() -> void:
	_open_altar(combat_room.altar)

func _open_altar(altar: RunAltar) -> void:
	if phase != Phase.RUNNING or not is_instance_valid(altar) or altar.used:
		return
	if player.global_position.distance_to(altar.global_position) > 3.5:
		return
	reward_options = RuneCatalog.offer(player.parkour_profile.id,combat.runes,_rng)
	if reward_options.is_empty():
		return
	_active_altar = altar
	phase = Phase.REWARD
	_suspend_gameplay(&"altar")
	combat.cancel_attack()
	player.control_enabled = false
	get_tree().paused = true
	audio.set_phase("paused")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_rewards(reward_options,stage_number)


func choose_rune(index: int) -> void:
	if phase != Phase.REWARD or index<0 or index>=reward_options.size():
		return
	var id: StringName = reward_options[index].id
	var chosen_altar:=_active_altar
	if not is_instance_valid(chosen_altar) or not combat.apply_rune(id):
		return
	chosen_altar.consume()
	if combat_mode:
		# An altar is both the reward and the only formal recovery point. Store a
		# safe offset beside it, never the altar/brazier origin itself.
		_checkpoint=combat_room.altar_checkpoint_pose(chosen_altar,player.global_position)
		combat_checkpoint_index=combat_room.altar_checkpoint_index(chosen_altar)
		_capture_combat_checkpoint(combat_checkpoint_index)
		combat.health=combat.maximum_health
	_active_altar = null
	reward_options.clear()
	hud.hide_rewards()
	get_tree().paused = false
	player.control_enabled = true
	phase = Phase.RUNNING
	hud.hide_menu()
	hud.toast(RuneCatalog.title(id))
	_play("checkpoint")
	audio.set_phase("running")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _next_stage() -> void:
	if phase != Phase.RUNNING or stage_number >= stage_count:
		return
	var completed_time:=stage_elapsed
	if not _load_combat_room(stage_number+1): return
	stage_splits.append(completed_time)
	stage_elapsed=0.0
	stage_number += 1
	var carried_health: int = combat.health
	_configure_encounter()
	_checkpoint = combat_room.spawn.global_transform
	combat_checkpoint_index=0
	_capture_combat_checkpoint(0)
	player.respawn_at(_checkpoint)
	combat.health = carried_health
	combat.shield = false
	player.control_enabled = true
	phase = Phase.RUNNING
	_update_stage(0)
	hud.hide_menu()
	hud.toast("第 %d 段 · %s" % [stage_number,combat_room.stage_title])
	audio.set_phase("running")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _combat_died() -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.DEFEATED
	_suspend_gameplay(&"dead", true)
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	combat.cancel_attack()
	combat_room.clear_effects()
	for enemy: LanternAcolyte in combat_room.enemies:
		enemy.active = false
	audio.set_phase("dead" if gameplay_audio.supported() else "finished")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu("defeated", "%s · 击败 %d / %d\n%s" % [combat_room.stage_title,combat_room.defeated_count,combat_room.enemies.size(),"坠入深渊" if player.global_position.y<player.fall_limit else "命火熄灭"])

func _combat_checkpoint_reached(_id:StringName,pose:Transform3D,index:int)->void:
	if phase!=Phase.RUNNING or not combat_mode:return
	_checkpoint=pose
	combat_checkpoint_index=index
	_capture_combat_checkpoint(index)
	combat.health=combat.maximum_health
	hud.toast("祭坛 %d · 生命恢复，已记录存档"%index)
	_play("checkpoint")

func _capture_combat_checkpoint(_index:int)->void:
	_combat_checkpoint_defeated=combat_room.checkpoint_defeated_ids()
	_combat_checkpoint_kills=combat.kills

func _retry_combat_checkpoint()->void:
	if not combat_mode or phase not in [Phase.RUNNING,Phase.DEFEATED]:return
	get_tree().paused=false
	retries+=1
	var revived:=combat_room.restore_checkpoint(_combat_checkpoint_defeated)
	for enemy in revived:combat.allow_repeat_defeat(enemy)
	combat.reset_state()
	combat.kills=_combat_checkpoint_kills
	combat.shield=false
	player.respawn_at(_checkpoint)
	player.control_enabled=true
	phase=Phase.RUNNING
	hud.reset_combat_feedback()
	hud.hide_menu()
	audio.stop_effects()
	audio.reset_steps(player.global_position)
	audio.set_phase("retry" if gameplay_audio.supported() else "running")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	hud.toast("从祭坛存档继续")

func _suspend_gameplay(reason: StringName, clear_arts: bool = false) -> void:
	player.grapple.cancel()
	var focus := player.get_node_or_null("TemporalFocus") as TemporalFocus
	if focus != null: focus.interrupt(reason)
	var rewind := player.get_node_or_null("PositionRewind") as PositionRewind
	if rewind != null: rewind.clear_history(reason)
	combat.cancel_attack()
	combat.attack_buffer=0
	combat.parry_left=0
	combat.arts._held=0
	combat.arts._skill_intent=&""
	combat.arts.release_required=Input.is_action_pressed("profession_skill")
	if is_instance_valid(combat.arts._preview): combat.arts._preview.hide()
	if clear_arts:
		combat.arts.reset_state()
		player.grapple.cancel()
		for enemy in combat_room.enemies:
			if is_instance_valid(enemy.boss_controller): enemy.boss_controller.cancel_encounter()

func _try_build_room(number: int) -> bool:
	# The level lane validates before replacing its current geometry. Dynamic
	# dispatch also supports the historical void-returning baseline during merge.
	var result: Variant = combat_room.call("reset_room",player,number)
	var accepted: bool = not (result is bool) or result
	if accepted:
		# Room lighting is rebuilt per stage; retain the user's exposure setting.
		_set_brightness(brightness)
	return accepted

func _load_combat_room(number: int) -> bool:
	if _try_build_room(number): return true
	# A rejected configuration must not advance the stage, teleport the player,
	# clear runes/health, dereference a missing spawn, or continue combat.
	_suspend_gameplay(&"configuration_error")
	player.control_enabled = false
	combat.enabled = false
	phase = Phase.READY
	audio.set_phase("paused")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu("ready","关卡暂时无法载入，已停止运行。请重试。")
	return false

func _configure_encounter() -> void:
	# Compatibility adapter for the existing level's legacy enemy labels. The
	# level lane may supply explicit roles via metadata without editing combat.
	var ordinary:=0
	var variants: Array[StringName]=[&"crossbow",&"caster",&"sentinel",&"bell",&"pursuer"]
	for enemy in combat_room.enemies:
		var rank: StringName=enemy.archetype if enemy.archetype in [&"elite",&"miniboss",&"boss"] else &"normal"
		var role_value: StringName
		if enemy.has_meta("gameplay_role"):
			role_value=StringName(enemy.get_meta("gameplay_role"))
		elif enemy.archetype==&"shield":role_value=&"heavy"
		elif enemy.archetype==&"elite":role_value=&"pursuer"
		elif rank in [&"miniboss",&"boss"]:role_value=&"caster"
		else:
			role_value=variants[posmod(ordinary+stage_number-1,variants.size())]
			ordinary+=1
		enemy.configure_behavior(role_value,rank)
		if is_instance_valid(enemy.boss_controller):
			var controller := enemy.boss_controller
			controller.phase_changed.connect(func(_stage: int,_state: StringName): hud.objective_label.text=controller.objective_text())
			controller.objective_broken.connect(func(_kind: StringName,_remaining: int): hud.objective_label.text=controller.objective_text())
			controller.mechanic_event.connect(_boss_mechanic_event)
	gameplay_audio.bind_room(combat_room)
	# Boss objectives replace the legacy generic seal shortcut. Other mechanisms
	# retain their usual bridge/launch roles and IDs.
	for device in combat_room.mechanisms.duplicate():
		if device.kind == &"seal" and stage_number in [2,3]:
			combat_room.mechanisms.erase(device)
			device.collision_layer = 0
			device.hide()
			device.queue_free()

func _boss_mechanic_event(event: StringName, _point: Vector3, _seconds: float) -> void:
	match event:
		&"terrain_warning": hud.toast("地台将在 4 秒后崩塌 · 借风井升空，E 牵引浮墙符文锚")
		&"shield_broken": hud.toast("护盾破碎 · 抓住窗口攻击本体")
		&"arena_binding_failed": hud.toast("首领场地绑定异常 · 请重试")


func _set_practice_geometry(enabled: bool) -> void:
	if formal_release:return
	for section: Node3D in [$Geometry,$Decoration,$DungeonDressing]:
		section.visible = not combat_mode
		for shape in section.find_children("*","CollisionShape3D",true,false):
			shape.set_deferred("disabled",combat_mode)
	$WallPractice.visible = enabled
	for shape: Node in $WallPractice.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred("disabled", not enabled)


func _jump_sound() -> void:
	if gameplay_audio != null and gameplay_audio.supported():
		_ordinary_jump_sound.call_deferred(Engine.get_physics_frames())
	else: _play("jump")

func _ordinary_jump_sound(frame: int) -> void:
	# Dedicated wall/slide notifications can come before or after jumped within
	# the same physics tick. Resolve after both instead of inspecting visual pose.
	if gameplay_audio.special_jump_frame != frame: _play("jump")

func _play(key: String, strength: float = 1.0) -> void:
	audio.set_sound_volume(sound_volume)
	audio.play_effect(key, strength)


func _set_sensitivity(value: float) -> void:
	player.mouse_sensitivity = value


func _set_fov(value: float) -> void:
	player.field_of_view = value


func _set_brightness(value: float) -> void:
	brightness = value
	$WorldEnvironment.environment.tonemap_exposure = value


func _set_volume(value: float) -> void:
	sound_volume = value
	audio.set_sound_volume(value)


func _set_music_volume(value: float) -> void:
	music_volume = value
	audio.set_music_volume(value)


func _set_feedback(enabled: bool) -> void:
	player.camera_feedback = enabled


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		player.mouse_sensitivity = clampf(float(config.get_value("controls", "sensitivity", 0.1)), 0.04, 0.22)
		player.field_of_view = clampf(float(config.get_value("controls", "fov", 80.0)), 65.0, 100.0)
		player.camera_feedback = bool(config.get_value("controls", "feedback_v07", true))
		sound_volume = clampf(float(config.get_value("audio", "volume", 0.65)), 0.0, 1.0)
		music_volume = clampf(float(config.get_value("audio", "music", 0.4)), 0.0, 1.0)
		brightness = clampf(float(config.get_value("display", "brightness", 1.15)), 0.8, 1.8)
		if config.has_section("records_v04"):
			for key: String in config.get_section_keys("records_v04"):
				_best_records[key] = maxf(0.0, float(config.get_value("records_v04", key, 0.0)))
	hud.sensitivity_slider.value = player.mouse_sensitivity
	hud.fov_slider.value = player.field_of_view
	hud.volume_slider.value = sound_volume
	hud.music_slider.value = music_volume
	hud.brightness_slider.value = brightness
	_set_brightness(brightness)
	audio.set_sound_volume(sound_volume)
	audio.set_music_volume(music_volume)
	hud.feedback_toggle.button_pressed = player.camera_feedback


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("controls", "sensitivity", player.mouse_sensitivity)
	config.set_value("controls", "fov", player.field_of_view)
	config.set_value("controls", "feedback_v07", player.camera_feedback)
	config.set_value("audio", "volume", sound_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("display", "brightness", brightness)
	for key: String in _best_records:
		config.set_value("records_v04", key, _best_records[key])
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("无法保存试炼设置，当前会话仍可继续。")


func _quit() -> void:
	_save_settings()
	get_tree().paused = false
	get_tree().quit()
