extends Control
## Opt-in candidate. Attaches to a real MovementTrial without modifying its rules.
## Existing TrialHUD remains its API endpoint; hide it while this view is attached.
const CHOICE = preload("res://ui_live_r12/choice.gd")
const FOCUS = preload("res://ui_live_r12/focus_overlay_r6.gd")
const BINDINGS = preload("res://scripts/player/temporal_bindings.gd")
const CATALOG = preload("res://scripts/run/rune_catalog.gd")
const STYLE = preload("res://ui_live_r12/default_style.tres")
const APPEARANCE = preload("res://ui_live_r12/appearance_catalog.gd")
const PREFS_PATH = "user://ui_live_r12.cfg"
const DESIGN = Vector2(1920,1080)
const PHASE_NAMES = {0:"title",1:"hud",2:"pause",3:"result",4:"death",5:"altar"}
const REASONS = {"no_history":"尚未留下可返回的足迹","insufficient_history":"尚未留下可返回的足迹","path_blocked":"返回路径受阻","occupied":"返回落点被占据","destination_blocked":"返回落点被占据","anchor_blocked":"返回落点被占据","cooldown":"回溯正在恢复","controls_disabled":"当前无法回溯","locked":"尚未获得残影契印","binding_conflict":"按键发生冲突","no_anchor":"尚未留下可返回的足迹","too_fast":"当前速度超出回溯范围","no_displacement":"尚未离开残影位置"}
const CORE_ICONS = {"shade_parry":"flow_blade","shade_wall":"sky_hunter","shade_slide":"ground_raider","shade_echo":"afterimage","arcane_storm":"storm_walker","arcane_shape":"rift_shaper","arcane_seal":"seal_binder","arcane_element":"elementalist"}

var trial: Node
var legacy: Control
var profile: Resource
var canvas: Control
var hud_layer: Control
var page_layer: Control
var backdrop: ColorRect
var overlay: Control
var labels: Dictionary = {}
var buttons: Dictionary = {}
var settings_controls: Dictionary = {}
var mode: String = ""
var subpage: String = ""
var waiting_binding: StringName = &""
var focus_state: Dictionary = {}
var rewind_state: Dictionary = {}
var selection_ids: Array[StringName] = []
var _offer_signature: String = ""
var _selection_pending: bool = false
var _notice_left: float = 0.0
var _hurt_left: float = 0.0
var _hit_left: float = 0.0
var _kill: bool = false
var _focus_level: float = 0.0
var _last_usec: int = 0
var _clock: float = 0.0
var _connections: Array = []
var _old_visible: bool = true
var _last_phase: int = -1
var _has_bound: bool = false
var _setting_error: String = ""
var _pending_refresh: bool = false
var _serif: Font
var _sans: Font
var _leather: Texture2D
var _gold: Color
var _ivory: Color
var _muted: Color
var _danger: Color
var preview_offer_id: StringName = &""
var _appearance_index: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile = STYLE.duplicate(true)
	_serif = load("res://ui_live_r12/fonts/SourceHanSerifSC-Medium.otf")
	_sans = load("res://ui_live_r12/fonts/SourceHanSansSC-Regular.otf")
	_leather = load("res://ui_live_r12/textures/brown_leather.jpg")
	_gold = profile.gold; _ivory = profile.ivory; _muted = profile.muted; _danger = profile.danger
	backdrop = ColorRect.new(); backdrop.color = Color(.025,.024,.021,.93); backdrop.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(backdrop)
	canvas = Control.new(); canvas.size = DESIGN; canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(canvas)
	canvas.draw.connect(_draw_decals)
	hud_layer = Control.new(); hud_layer.size = DESIGN; hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE; canvas.add_child(hud_layer)
	page_layer = Control.new(); page_layer.size = DESIGN; page_layer.mouse_filter = Control.MOUSE_FILTER_STOP; canvas.add_child(page_layer)
	overlay = FOCUS.new(); add_child(overlay); overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_build_hud()
	_last_usec = Time.get_ticks_usec()
	_resize()
	get_viewport().size_changed.connect(_resize)
	var saved := ConfigFile.new()
	if saved.load(PREFS_PATH) == OK: profile.reduced_motion = bool(saved.get_value("visual","reduced_motion",false))
	_appearance_index = APPEARANCE.load_index()

func apply_style(candidate: Resource) -> bool:
	# Validate everything before replacing a live profile; never alter the caller resource.
	if candidate == null or candidate.get_script() != STYLE.get_script() or not candidate.validation_errors().is_empty(): return false
	profile = candidate.duplicate(true)
	_gold = profile.gold; _ivory = profile.ivory; _muted = profile.muted; _danger = profile.danger
	for child in hud_layer.get_children(): hud_layer.remove_child(child); child.queue_free()
	labels.clear(); _build_hud(); _pending_refresh = true
	if is_instance_valid(trial): _sync_state()
	return true

func attach(manager: Node) -> bool:
	if not is_node_ready() or not is_instance_valid(manager) or not manager.has_method("start_run"): return false
	detach()
	trial = manager
	legacy = trial.get("hud")
	if not is_instance_valid(legacy): trial = null; return false
	_old_visible = legacy.visible
	legacy.hide()
	_has_bound = true
	BINDINGS.ensure_actions()
	# Load stored keys even when project.godot already registered these actions.
	var keys := ConfigFile.new()
	if keys.load(BINDINGS.SETTINGS_PATH) == OK:
		for action in BINDINGS.DEFAULTS:
			var saved: int = int(keys.get_value("keys",action,BINDINGS.DEFAULTS[action]))
			if not BINDINGS.rebind_key(action,saved,false): _setting_error = "已保存的按键有冲突，请重新设置。"
	var player = trial.get("player")
	var combat = trial.get("combat")
	_connect(player.get_node("TemporalFocus"),"state_changed",_focus_changed)
	_connect(player.get_node("PositionRewind"),"state_changed",_rewind_changed)
	_connect(player.get_node("PositionRewind"),"rejected",_rewind_rejected)
	_connect(player.get_node("PositionRewind"),"rewound",_rewound)
	_connect(combat,"hurt",_hurt)
	_connect(combat,"hit_confirmed",_hit)
	_connect(combat,"temporal_reset_requested",_clear_feedback)
	_connect(trial,"tree_exiting",_host_exiting)
	_sync_state()
	return true

func _connect(source: Object, event: StringName, callback: Callable) -> void:
	if not source.is_connected(event,callback): source.connect(event,callback)
	_connections.append([weakref(source),event,callback])

func detach() -> void:
	for row in _connections:
		var source = row[0].get_ref()
		if is_instance_valid(source) and source.is_connected(row[1],row[2]): source.disconnect(row[1],row[2])
	_connections.clear()
	if is_instance_valid(legacy): legacy.visible = _old_visible
	trial = null; legacy = null; _has_bound = false; _last_phase = -1
	_clear_feedback()
	if is_instance_valid(canvas): canvas.hide()
	if is_instance_valid(backdrop): backdrop.hide()

func _host_exiting() -> void:
	detach()

func _exit_tree() -> void:
	detach()

func _resize() -> void:
	if not is_instance_valid(canvas): return
	var extent: Vector2 = get_viewport_rect().size
	var factor := minf(extent.x / DESIGN.x, extent.y / DESIGN.y)
	canvas.scale = Vector2(factor,factor)
	canvas.position = (extent - DESIGN * factor) * 0.5
	backdrop.size = extent
	if is_instance_valid(overlay): overlay.position=Vector2.ZERO; overlay.scale=Vector2.ONE*2*factor; overlay.size=extent/(2*factor)

func _text(parent: Control, id: String, value: String, rect: Rect2, px: int = 24, title: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.name = id; label.text = value; label.position = rect.position; label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",_serif if title else _sans)
	label.add_theme_font_size_override("font_size",px)
	label.add_theme_color_override("font_color",_ivory)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = align
	parent.add_child(label); label.size = rect.size; labels[id] = label
	return label

func _button(id: String, caption: String, point: Vector2, action: Callable, width: float = 520) -> Button:
	var b = CHOICE.new(); b.kind = "menu"; b.title = caption; b.name = id
	b.position = point; b.size = Vector2(width,72); b.set_meta("reduced_motion",profile.reduced_motion); page_layer.add_child(b)
	b.pressed.connect(action); buttons[id] = b
	return b

func _build_hud() -> void:
	_text(hud_layer,"stage","",Rect2(64,40,620,44),29,true)
	_text(hud_layer,"objective","",Rect2(66,94,680,68),20)
	_text(hud_layer,"class","",Rect2(65,874,430,48),28,true)
	_text(hud_layer,"build","",Rect2(67,924,540,66),18)
	_text(hud_layer,"ward","护契",Rect2(65,1004,82,33),18)
	_text(hud_layer,"dash","",Rect2(245,1004,230,33),18)
	_text(hud_layer,"wall","",Rect2(64,789,540,65),20)
	_text(hud_layer,"skill","",Rect2(1280,868,570,65),25,true,HORIZONTAL_ALIGNMENT_RIGHT)
	_text(hud_layer,"skill_detail","",Rect2(1240,929,610,64),18,false,HORIZONTAL_ALIGNMENT_RIGHT)
	_text(hud_layer,"focus_hint","",Rect2(1390,1006,460,32),19,false,HORIZONTAL_ALIGNMENT_RIGHT)
	_text(hud_layer,"rewind","",Rect2(1310,794,540,64),20,false,HORIZONTAL_ALIGNMENT_RIGHT)
	_text(hud_layer,"interaction","",Rect2(615,618,690,72),24,true,HORIZONTAL_ALIGNMENT_CENTER)
	_text(hud_layer,"notice","",Rect2(520,710,880,70),23,true,HORIZONTAL_ALIGNMENT_CENTER)
	_text(hud_layer,"boss","",Rect2(610,150,700,52),25,true,HORIZONTAL_ALIGNMENT_CENTER)
	_text(hud_layer,"time","",Rect2(1690,46,160,40),20,false,HORIZONTAL_ALIGNMENT_RIGHT)
	_text(hud_layer,"diagnostics","",Rect2(67,190,700,280),18)
	labels.objective.modulate = _muted; labels.skill_detail.modulate = _muted; labels.build.modulate = _muted

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf(0.1,maxf(0.0,(now-_last_usec)/1000000.0)); _last_usec = now
	_clock += dt
	if not is_instance_valid(trial): return
	_sync_state()
	if mode == "hud":
		_update_hud(dt)
	else:
		_focus_level = 0.0
		overlay.set_focus("idle",0,0,_clock)
	_notice_left = maxf(0,_notice_left-dt)
	_hurt_left = maxf(0,_hurt_left-dt); _hit_left = maxf(0,_hit_left-dt)
	labels.notice.visible = _notice_left > 0
	canvas.queue_redraw()

func _sync_state() -> void:
	canvas.show()
	var phase: int = trial.get("phase")
	if phase != _last_phase:
		_last_phase = phase; subpage = ""; waiting_binding = &""; _selection_pending = false
		_clear_feedback()
	var next: String = subpage if not subpage.is_empty() else PHASE_NAMES.get(phase,"title")
	var signature := ""
	if next == "altar":
		for option in trial.get("reward_options"): signature += str(option.get("id",""))+";"
	if mode != next or (next == "altar" and signature != _offer_signature) or _pending_refresh:
		mode = next; _offer_signature = signature; _pending_refresh = false
		_render_page()
	hud_layer.visible = mode == "hud"
	page_layer.visible = mode != "hud"
	backdrop.visible = mode != "hud"

func _render_page() -> void:
	buttons.clear(); settings_controls.clear(); selection_ids.clear()
	for child in page_layer.get_children(): page_layer.remove_child(child); child.queue_free()
	if mode == "hud": return
	if mode == "altar": _altar(); return
	if mode == "appearance": _appearance(); return
	if mode == "settings": _settings(); return
	if mode == "class": _classes(); return
	var titles := {"title":"灰烬行者","pause":"稍作停留","death":"契火熄灭","result":"城垣已解封"}
	_text(page_layer,"page_eyebrow","A S H E N   V O W",Rect2(150,132,800,42),21)
	_text(page_layer,"page_title",titles.get(mode,"灰烬行者"),Rect2(142,224,1350,126),80,true)
	var copy := "穿越坍塌的高墙，取回钟塔中的契印。"
	if mode == "pause": copy = "旅途暂歇，契火未息。"
	if mode == "death": copy = "在火光尚存之处，再次踏上城垣。"
	if mode == "result": copy = "你穿过了钟声与灰烬。"
	_text(page_layer,"page_copy",copy,Rect2(151,363,1170,70),24).modulate = _muted
	match mode:
		"title":
			_button("begin","踏入城垣",Vector2(126,500),func(): navigate("class"))
			_button("settings","旅者设置",Vector2(126,588),func(): navigate("settings"))
			_button("quit","退出",Vector2(126,676),func(): legacy.quit_requested.emit())
		"pause":
			_button("resume","继续前行",Vector2(126,500),func(): legacy.resume_requested.emit())
			_button("settings","旅者设置",Vector2(126,588),func(): navigate("settings"))
			_button("restart","重新挑战",Vector2(126,676),func(): legacy.restart_requested.emit())
		"death","result":
			var combat = trial.get("combat")
			_text(page_layer,"results_time",_time(trial.get("elapsed")),Rect2(150,476,450,80),48,true)
			_text(page_layer,"results_splits",_split_text(),Rect2(153,556,1450,48),21).modulate = _muted
			_text(page_layer,"results_numbers","击破 %d   ·   契印 %d   ·   第 %d 域" % [combat.kills,combat.runes.size(),trial.get("stage_number")],Rect2(153,615,1190,45),25)
			_button("restart","再次远征" if mode=="result" else "重新挑战",Vector2(126,705),func(): legacy.restart_requested.emit())
			_button("class","选择另一条道路",Vector2(126,793),func(): navigate("class"))
	_text(page_layer,"menu_controls","方向键选择   ·   Enter 确认",Rect2(150,995,800,40),18).modulate = _muted
	_focus_first()

func navigate(page: String) -> void:
	subpage = page
	_sync_state()

func _classes() -> void:
	_text(page_layer,"class_title","缔结契约",Rect2(150,95,1000,85),58,true)
	for index in range(2):
		var x: float = 280+index*815
		var icon := TextureRect.new(); icon.texture = load("res://ui_live_r12/icons/"+("flow_blade" if index==0 else "elementalist")+".svg")
		icon.position = Vector2(x+135,298); icon.size = Vector2(210,210); icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; page_layer.add_child(icon)
		_button("class_%d"%index,"影刃" if index==0 else "咒行者",Vector2(x+50,545),func(): start_class(index),410)
		_text(page_layer,"class_detail_%d"%index,"长刀 · 弹反 · 残影回返" if index==0 else "法杖 · 元素 · 塑形造路",Rect2(x-35,650,565,65),25,true,HORIZONTAL_ALIGNMENT_CENTER)
		_text(page_layer,"class_builds_%d"%index,"流刃决斗    飞檐猎杀\n掠地破阵    残影行者" if index==0 else "风暴行者    裂隙塑形\n封印术士    元素塑能者",Rect2(x-45,745,600,100),22,false,HORIZONTAL_ALIGNMENT_CENTER).modulate = _muted
	_button("back","返回",Vector2(125,955),back,320)
	_focus_first()

func start_class(index: int) -> void:
	if index < 0 or index > 1: return
	legacy.class_choice.select(index)
	legacy.start_requested.emit()
	subpage = ""; _pending_refresh = true; _sync_state()

func _altar() -> void:
	_text(page_layer,"altar_title","铭刻契印",Rect2(480,82,960,84),54,true,HORIZONTAL_ALIGNMENT_CENTER)
	_text(page_layer,"altar_subtitle","第 %d 域 · 选择一枚契印，继续前方的远征。"%trial.get("stage_number"),Rect2(430,184,1060,55),23,false,HORIZONTAL_ALIGNMENT_CENTER).modulate = _muted
	var options: Array = trial.get("reward_options")
	var width := 400.0
	var left := (DESIGN.x-options.size()*width-maxi(0,options.size()-1)*26)/2
	for index in range(options.size()):
		var id: StringName = options[index].get("id",&"")
		var rune: Dictionary = CATALOG.definition(id)
		# The actual offered ID is authority; normalization avoids legacy core labels.
		if rune.is_empty(): rune = options[index]
		selection_ids.append(id)
		var card = CHOICE.new(); card.name = "rune_%d"%index; card.position = Vector2(left+index*426,280); card.size = Vector2(width,612)
		card.number = index+1; card.title = str(rune.get("name",id)); card.eyebrow = str(rune.get("path","契印"))+ (" · 核心" if rune.get("core",false) else " · 联动")
		card.description = str(rune.get("effect",""))
		var parent_id: StringName = rune.get("requires",&"")
		card.synergy = "开启一种新的战斗与路线选择" if parent_id==&"" else "承接契印 · "+CATALOG.title(parent_id)
		var core: StringName = id
		var seen: Array[StringName] = []
		while not CORE_ICONS.has(str(core)) and core!=&"" and core not in seen:
			seen.append(core); core = CATALOG.definition(core).get("requires",&"")
		var icon_path: String = "res://ui_live_r12/icons/"+str(CORE_ICONS.get(str(core),"altar"))+".svg"
		card.crest = load(icon_path) if ResourceLoader.exists(icon_path) else load("res://ui_live_r12/icons/altar.svg")
		card.set_meta("reduced_motion",profile.reduced_motion)
		page_layer.add_child(card); buttons[card.name] = card
		card.pressed.connect(func(): select_offer(index,id))
		card.focus_entered.connect(func(): preview_offer_id = id)
		card.mouse_entered.connect(func(): preview_offer_id = id)
	_text(page_layer,"altar_controls","1 / 2 / 3 铭刻 · 方向键切换 · P 查看外观",Rect2(340,974,900,44),20)
	_button("appearance","外观变化",Vector2(1290,951),open_appearance,330)
	_focus_first()

func open_appearance() -> bool:
	if not is_instance_valid(trial) or int(trial.get("phase")) != 5 or preview_offer_id not in selection_ids: return false
	navigate("appearance")
	return true

func _appearance() -> void:
	var rune: Dictionary = CATALOG.definition(preview_offer_id)
	var plan: Dictionary = APPEARANCE.resolve(preview_offer_id,trial.combat.runes,_appearance_index)
	_text(page_layer,"appearance_title",str(plan.get("title","契印"))+" · 外观",Rect2(145,60,1530,82),47,true)
	_text(page_layer,"appearance_offer","本次契印 · "+str(rune.get("name","")),Rect2(150,150,1480,48),23)
	_text(page_layer,"appearance_effect",str(rune.get("effect","")),Rect2(150,208,1620,72),20).modulate = _muted
	if plan.is_empty():
		_text(page_layer,"appearance_missing","这枚契印暂未提供外观图。",Rect2(250,450,1400,90),30,true,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		for index in range(3):
			var stage: Dictionary = plan.stages[index]
			var x: float = 155+index*542
			_text(page_layer,"appearance_stage_%d"%index,stage.title,Rect2(x,310,500,48),27,true,HORIZONTAL_ALIGNMENT_CENTER)
			_picture(stage.weapon,Rect2(x,375,500,290))
			_picture(stage.garment,Rect2(x,685,215,200))
			_text(page_layer,"appearance_note_%d"%index,stage.note,Rect2(x+235,695,260,180),21)
	_text(page_layer,"appearance_rules","外观按核心与关键联动变化；普通数值强化沿用已有造型。",Rect2(153,909,1620,43),20).modulate = _muted
	_button("back","返回契印选择",Vector2(123,978),back,600)
	_focus_first()

func _picture(path: String, rect: Rect2) -> void:
	var picture := TextureRect.new(); picture.position = rect.position; picture.size = rect.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(path): picture.texture = load(path)
	page_layer.add_child(picture)

func select_offer(index: int, expected_id: StringName) -> bool:
	if not is_instance_valid(trial) or int(trial.get("phase"))!=5 or _selection_pending: return false
	var offered: Array = trial.get("reward_options")
	if index<0 or index>=offered.size() or offered[index].get("id",&"")!=expected_id: return false
	_selection_pending = true
	for button in buttons.values(): button.disabled = true
	legacy.rune_selected.emit(index)
	_pending_refresh = true
	_sync_state()
	return true

func _settings() -> void:
	_text(page_layer,"settings_title","旅者设置",Rect2(140,78,1200,90),54,true)
	_text(page_layer,"settings_subtitle","修改立即生效并保存。",Rect2(147,172,1200,44),22).modulate = _muted
	var rows := [["sensitivity","鼠标灵敏度",0.04,0.22,0.005],["fov","视野角度",65.0,100.0,1.0],["volume","音效音量",0.0,1.0,0.01],["music","音乐音量",0.0,1.0,0.01],["brightness","画面亮度",0.8,1.8,0.05]]
	var values := setting_values()
	for i in range(rows.size()):
		var row: Array = rows[i]; var key: String = row[0]; var y: float = 288+i*100
		_text(page_layer,"setting_name_"+key,row[1],Rect2(150,y,300,50),25,true)
		var slider := HSlider.new(); slider.name = key; slider.position = Vector2(455,y+7); slider.size = Vector2(510,40)
		slider.min_value = row[2]; slider.max_value = row[3]; slider.step = row[4]; slider.value = values[key]
		var style := StyleBoxFlat.new(); style.bg_color = Color("34332e"); style.content_margin_top = 3; style.content_margin_bottom = 3
		slider.add_theme_stylebox_override("slider",style)
		var fill := style.duplicate(); fill.bg_color = _gold
		slider.add_theme_stylebox_override("grabber_area",fill); slider.add_theme_stylebox_override("grabber_area_highlight",fill)
		for part in ["grabber","grabber_highlight"]: slider.add_theme_icon_override(part,load("res://ui_live_r12/icons/setting_grip.svg"))
		page_layer.add_child(slider); settings_controls[key] = slider
		_text(page_layer,"setting_value_"+key,_value_text(key,values[key]),Rect2(1000,y,150,52),23)
		slider.value_changed.connect(func(value): apply_setting(key,value))
	_button("feedback","镜头反馈 · "+("开" if values.feedback else "关"),Vector2(1215,278),func(): apply_setting("feedback",not trial.get("player").camera_feedback); _pending_refresh=true,540)
	_button("motion","界面动效 · "+("减弱" if profile.reduced_motion else "正常"),Vector2(1215,378),func(): apply_setting("reduced_motion",not profile.reduced_motion); _pending_refresh=true,540)
	for i in range(2):
		var action: StringName = &"focus" if i==0 else &"rewind"
		_button(str(action)+"_binding",("专注" if i==0 else "回溯")+" · "+binding_label(action),Vector2(1215,510+i*100),func(): begin_rebind(action),540)
	_text(page_layer,"binding_note","点击按键后按下新键，Esc 取消。\n已被使用的按键不会覆盖原设置。",Rect2(1250,735,520,100),20).modulate = _muted
	_text(page_layer,"settings_notice",_setting_error,Rect2(150,835,1600,60),22).modulate = _setting_tint()
	_button("defaults","恢复默认",Vector2(126,936),restore_defaults,400)
	_button("back","返回",Vector2(1350,936),back,350)
	_focus_first()

func setting_values() -> Dictionary:
	var p = trial.get("player")
	return {"sensitivity":p.mouse_sensitivity,"fov":p.field_of_view,"volume":trial.get("sound_volume"),"music":trial.get("music_volume"),"brightness":trial.get("brightness"),"feedback":p.camera_feedback,"reduced_motion":profile.reduced_motion}

func _value_text(key: String, value: float) -> String:
	if key in ["music","volume"]: return "%d%%"%roundi(value*100)
	if key=="fov": return "%d°"%roundi(value)
	return "%.3f"%value if key=="sensitivity" else "%.2f"%value

func apply_setting(key: String, value: Variant) -> bool:
	var ranges := {"sensitivity":Vector2(.04,.22),"fov":Vector2(65,100),"volume":Vector2(0,1),"music":Vector2(0,1),"brightness":Vector2(.8,1.8)}
	if key in ["feedback","reduced_motion"]:
		if not value is bool: return false
	elif ranges.has(key):
		if not (value is int or value is float) or not is_finite(float(value)): return false
		if float(value)<ranges[key].x or float(value)>ranges[key].y: return false
	else: return false
	var methods := {"sensitivity":"_set_sensitivity","fov":"_set_fov","volume":"_set_volume","music":"_set_music_volume","brightness":"_set_brightness","feedback":"_set_feedback"}
	if key=="reduced_motion": profile.reduced_motion = value
	else: trial.call(methods[key],value)
	var controls := {"sensitivity":"sensitivity_slider","fov":"fov_slider","volume":"volume_slider","music":"music_slider","brightness":"brightness_slider"}
	if controls.has(key): legacy.get(controls[key]).set_value_no_signal(value)
	if key=="feedback": legacy.feedback_toggle.set_pressed_no_signal(value)
	trial.call("_save_settings")
	var prefs := ConfigFile.new(); prefs.load(PREFS_PATH); prefs.set_value("visual","reduced_motion",profile.reduced_motion)
	var err := prefs.save(PREFS_PATH)
	# Verify durable values rather than assuming a void save method succeeded.
	var saved := ConfigFile.new()
	var stored_ok := saved.load(trial.SETTINGS_PATH)==OK
	var field := {"sensitivity":["controls","sensitivity"],"fov":["controls","fov"],"volume":["audio","volume"],"music":["audio","music"],"brightness":["display","brightness"],"feedback":["controls","feedback_v07"]}
	if field.has(key): stored_ok = stored_ok and saved.get_value(field[key][0],field[key][1],null)==value
	if err!=OK or not stored_ok:
		_setting_error = "保存失败：本次修改仅在当前会话生效。"
	else: _setting_error = "已保存"
	if is_instance_valid(labels.get("settings_notice")): labels.settings_notice.text = _setting_error; labels.settings_notice.modulate = _setting_tint()
	if is_instance_valid(labels.get("setting_value_"+key)): labels["setting_value_"+key].text = _value_text(key,float(value))
	return err==OK and stored_ok

func begin_rebind(action: StringName) -> void:
	if action not in BINDINGS.DEFAULTS: return
	waiting_binding = action
	labels.settings_notice.text = "请按下新的"+("专注" if action==&"focus" else "回溯")+"按键 · Esc 取消"
	labels.settings_notice.modulate = _ivory

func _setting_tint() -> Color:
	return _danger if "失败" in _setting_error or "冲突" in _setting_error or "占用" in _setting_error else _ivory

func binding_label(action: StringName) -> String:
	if not InputMap.has_action(action): return "未绑定"
	var parts: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			parts.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode!=KEY_NONE else event.keycode))
		else: parts.append(event.as_text())
	return " / ".join(parts)

func rebind(action: StringName, key: Key) -> bool:
	var ok: bool = BINDINGS.rebind_key(action,key,true)
	_setting_error = "按键已保存" if ok else "该按键已被占用或无法保存，原按键保持不变。"
	waiting_binding = &""; _pending_refresh = true
	return ok

func restore_defaults() -> void:
	for row in [["sensitivity",.1],["fov",80.0],["volume",.65],["music",.4],["brightness",1.15],["feedback",true],["reduced_motion",false]]: apply_setting(row[0],row[1])
	# Check both defaults against every non-temporal action before a transactional reset.
	for action in BINDINGS.DEFAULTS:
		var event := InputEventKey.new(); event.physical_keycode = BINDINGS.DEFAULTS[action]
		for other in InputMap.get_actions():
			if other not in BINDINGS.DEFAULTS and not str(other).begins_with("ui_") and InputMap.action_has_event(other,event):
				_setting_error = "画面与声音已恢复；默认按键被其他操作占用。"; _pending_refresh = true; return
	var config := ConfigFile.new(); config.load(BINDINGS.SETTINGS_PATH)
	for action in BINDINGS.DEFAULTS: config.set_value("keys",action,BINDINGS.DEFAULTS[action])
	if config.save(BINDINGS.SETTINGS_PATH)!=OK: _setting_error = "默认按键保存失败"; _pending_refresh = true; return
	for action in BINDINGS.DEFAULTS: Input.action_release(action); InputMap.action_erase_events(action)
	for action in BINDINGS.DEFAULTS: BINDINGS.rebind_key(action,BINDINGS.DEFAULTS[action],false)
	_setting_error = "已恢复默认并保存"; _pending_refresh = true

func back() -> void:
	waiting_binding = &""; subpage = ""; _sync_state()

func _input(event: InputEvent) -> void:
	if not _has_bound or not event is InputEventKey or not event.pressed or event.echo: return
	if waiting_binding!=&"":
		if event.keycode==KEY_ESCAPE: waiting_binding=&""; _setting_error="已取消改键"; _pending_refresh=true
		elif event.keycode not in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]: rebind(waiting_binding,event.physical_keycode if event.physical_keycode!=0 else event.keycode)
		get_viewport().set_input_as_handled(); return
	if event.keycode==KEY_ESCAPE and not subpage.is_empty(): back(); get_viewport().set_input_as_handled(); return
	if mode=="altar" and event.keycode==KEY_P: open_appearance(); get_viewport().set_input_as_handled(); return
	if mode=="altar" and event.keycode>=KEY_1 and event.keycode<=KEY_3:
		var index: int = event.keycode-KEY_1
		if index<selection_ids.size(): select_offer(index,selection_ids[index])
		get_viewport().set_input_as_handled()

func _focus_first() -> void:
	var choices: Array = settings_controls.values()+buttons.values()
	for i in range(choices.size()):
		choices[i].focus_next = choices[i].get_path_to(choices[(i+1)%choices.size()])
		choices[i].focus_previous = choices[i].get_path_to(choices[posmod(i-1,choices.size())])
		choices[i].focus_neighbor_left = choices[i].focus_previous; choices[i].focus_neighbor_right = choices[i].focus_next
		choices[i].focus_neighbor_top = choices[i].focus_previous; choices[i].focus_neighbor_bottom = choices[i].focus_next
	if not choices.is_empty(): choices[0].grab_focus()

func _update_hud(dt: float) -> void:
	var player = trial.get("player"); var combat = trial.get("combat"); var arts = combat.arts
	focus_state = player.get_node("TemporalFocus").status()
	rewind_state = player.get_node("PositionRewind").status()
	var active: bool = str(focus_state.get("phase","idle")) in ["entering","active"]
	var target: float = profile.focus_strength if active else 0.0
	var span: float = profile.focus_enter_seconds if active else profile.focus_exit_seconds
	_focus_level = target if profile.reduced_motion else move_toward(_focus_level,target,dt/maxf(.01,span))
	overlay.set_focus(str(focus_state.phase),_focus_level,float(focus_state.reserve)/maxf(.001,float(focus_state.capacity)),0.0 if profile.reduced_motion else _clock)
	if is_instance_valid(overlay.text_label): overlay.text_label.text = "专 注" if active else "时流复归"
	hud_layer.modulate.a = profile.hud_opacity
	var room = trial.get("combat_room")
	labels.stage.text = "%02d / %02d  %s" % [trial.get("stage_number"),trial.get("stage_count"),room.stage_title]
	labels.objective.text = room.objective_text()
	labels["class"].text = player.parkour_profile.display_name
	var names: PackedStringArray = []
	for id in combat.runes:
		var rune: Dictionary = CATALOG.definition(id)
		if rune.get("core",false): names.append(str(rune.get("name",id)))
	labels.build.text = " · ".join(names) if not names.is_empty() else "前往祭坛，铭刻你的第一枚契印"
	labels.dash.text = "冲刺就绪" if player.dash_available else "冲刺已消耗"
	labels.wall.text = "沿墙疾行 · %.1f 秒 · 余 %d 段"%[player.wall_time_remaining(),player.wall_segments_remaining()] if player.is_wall_running() else ""
	var focus_key: String = binding_label(&"focus")
	labels.focus_hint.text = "%s · 空中专注"%focus_key
	if float(focus_state.reserve)<=.001: labels.focus_hint.text = "%s · 专注耗尽"%focus_key
	if focus_state.release_required: labels.focus_hint.text = "松开 %s 后可再次专注"%focus_key
	labels.time.text = _time(trial.get("elapsed"))
	_update_skill(arts)
	_update_rewind()
	labels.interaction.text = legacy.interaction_label.text
	if arts._held>0 and arts._skill_intent in [&"wall",&"well",&"platform",&"anchor"]:
		var shapes := {&"wall":"石壁",&"well":"风井",&"platform":"浮台",&"anchor":"悬锚"}
		labels.interaction.text = "松开 Q · 凝成"+str(shapes[arts._skill_intent]) if arts._preview_valid else "此处无法塑形 · 移开遮挡，寻找落点"
		labels.interaction.modulate = _ivory if arts._preview_valid else _danger
	else: labels.interaction.modulate = _ivory
	if player.grapple.has_method("status") and player.grapple.active:
		var tether:Dictionary=player.grapple.status()
		labels.interaction.text=("符链出手" if str(tether.phase)=="launch" else "牵引中 · 接近悬锚自动松开")+"\nE / Space 松开 · Shift 松开并尝试冲刺"
		labels.interaction.modulate=_ivory
	labels.boss.text = ""
	for enemy in room.enemies:
		if is_instance_valid(enemy) and enemy.health>0 and str(enemy.get("threat_rank")) in ["boss","miniboss"]:
			labels.boss.text = enemy._name()+ (" · 核心暴露" if enemy.vulnerable else " · 破解封印")
			break
	labels.diagnostics.text = legacy.telemetry_label.text if legacy.telemetry_label.visible else ""

func _update_skill(arts: Node) -> void:
	var action: StringName = arts.selected()
	var names := {&"counter":"追身返刃",&"hunt":"空中处决",&"sweep":"掠地横斩",&"wall":"塑形 · 石壁",&"well":"塑形 · 风井",&"platform":"塑形 · 浮台",&"anchor":"塑形 · 悬锚",&"seal":"封印引爆",&"storm":"风暴借势"}
	labels.skill.text = "Q · "+str(names.get(action,"等待破势时机"))
	labels.skill_detail.text = "基础攻击始终可用"
	if action in [&"wall",&"well",&"platform",&"anchor"]: labels.skill_detail.text = "按住预览，松开塑形 · 法力 %d"%arts.mana
	elif action==&"seal": labels.skill_detail.text = "攻击自动刻印 · %d 枚符印"%arts.marks.size()+ ("\n按住 Q 预览塑形" if arts.has(&"arcane_shape") else "")
	elif action==&"storm": labels.skill_detail.text = "空中命中维持机动 · 法力 %d"%arts.mana
	elif action==&"counter": labels.skill_detail.text = "弹反机会 · %.1f 秒"%arts.counter_left
	elif action==&"hunt": labels.skill_detail.text = "锁定机会 · %.1f 秒"%arts.lock_left
	elif action==&"sweep": labels.skill_detail.text = "滑铲跳切入 · %.1f 秒"%arts.slide_window
	if arts.cooldown>0: labels.skill_detail.text = "恢复中 · %.1f 秒"%arts.cooldown

func _update_rewind() -> void:
	labels.rewind.visible = rewind_state.get("unlocked",false)
	if not labels.rewind.visible: return
	var key: String = binding_label(&"rewind")
	if float(rewind_state.cooldown)>0: labels.rewind.text = "%s · 回溯恢复 %.1f 秒"%[key,rewind_state.cooldown]
	elif not rewind_state.has_anchor: labels.rewind.text = "%s · 正在留下足迹"%key
	elif not rewind_state.path_valid: labels.rewind.text = "%s · %s"%[key,REASONS.get(str(rewind_state.path_reason),"返回路径受阻")]
	else: labels.rewind.text = "%s · 回溯 %.1f 秒前"%[key,rewind_state.anchor_age]
	labels.rewind.modulate = _ivory if rewind_state.ready else _muted

func _focus_changed(_previous: StringName, _current: StringName, _reason: StringName) -> void:
	if is_instance_valid(trial): focus_state = trial.get("player").get_node("TemporalFocus").status()

func _rewind_changed(state: Dictionary) -> void:
	rewind_state = state.duplicate(true)

func _rewind_rejected(reason: StringName) -> void:
	notify(str(REASONS.get(str(reason),"当前无法沿足迹回返")))

func _rewound(_origin: Vector3,_destination: Vector3,_path: PackedVector3Array) -> void:
	notify("残影回返")

func notify(message: String) -> void:
	if labels.has("notice"): labels.notice.text = message
	_notice_left = profile.notice_seconds

func _hurt(_amount: int) -> void:
	_hurt_left = .4; notify("护契破裂")

func _hit(_target: Node3D,_point: Vector3,defeated: bool) -> void:
	_hit_left = .19; _kill = defeated

func _clear_feedback() -> void:
	focus_state.clear(); rewind_state.clear(); _notice_left=0; _hurt_left=0; _hit_left=0; _focus_level=0
	if is_instance_valid(overlay): overlay.set_focus("idle",0,0,0)

func _time(seconds: float) -> String:
	return "%02d:%02d"%[int(seconds)/60,int(seconds)%60]

func _split_text() -> String:
	var values:PackedStringArray=[]
	var splits:Array=trial.get("stage_splits")
	for index in splits.size():values.append("第 %d 关 %s"%[index+1,_time(splits[index])])
	if values.size()<trial.get("stage_number"):
		values.append("第 %d 关进行中 %s"%[trial.get("stage_number"),_time(trial.get("stage_elapsed"))])
	return "   ·   ".join(values)

func _draw_decals() -> void:
	if not _has_bound: return
	if mode=="hud":
		var dark := Color(0.012,0.015,0.014,profile.hud_backing)
		var clear := Color(dark,0)
		canvas.draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(800,0),Vector2(700,190),Vector2(0,210)]),PackedColorArray([dark,clear,clear,clear]))
		canvas.draw_polygon(PackedVector2Array([Vector2(0,745),Vector2(705,890),Vector2(740,1080),Vector2(0,1080)]),PackedColorArray([clear,clear,clear,dark]))
		canvas.draw_polygon(PackedVector2Array([Vector2(1920,745),Vector2(1215,890),Vector2(1180,1080),Vector2(1920,1080)]),PackedColorArray([clear,clear,clear,dark]))
		canvas.draw_circle(Vector2(960,540),2.0,_ivory)
		var health: int = trial.get("combat").health
		for i in range(2): _diamond(Vector2(167+i*35,1020),9,_gold if health>i else Color("51493d"),2)
		canvas.draw_line(Vector2(65,859),Vector2(452,859),Color(_gold,.65),1,true)
		canvas.draw_line(Vector2(1600,853),Vector2(1850,853),Color(_gold,.45),1,true)
		if _hurt_left>0: canvas.draw_rect(Rect2(Vector2.ZERO,DESIGN),Color(_danger,minf(.35,_hurt_left)),false,10)
		if _hit_left>0:
			for x in [-1,1]:
				for y in [-1,1]: canvas.draw_line(Vector2(960+x*7,540+y*7),Vector2(960+x*15,540+y*15),_danger if _kill else _ivory,2,true)
	else:
		canvas.draw_texture_rect(_leather,Rect2(95,110,16,780),false,Color(.25,.22,.17,.85))
		canvas.draw_line(Vector2(114,112),Vector2(114,890),Color(_gold,.48),1,true)

func _diamond(center: Vector2,radius: float,color: Color,width: float) -> void:
	canvas.draw_polyline(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0),center+Vector2(0,-radius)]),color,width,true)

func snapshot() -> Dictionary:
	return {"mode":mode,"bound":_has_bound,"focus_level":_focus_level,"focus":focus_state.duplicate(true),"rewind":rewind_state.duplicate(true),"skill":labels.skill.text,"skill_detail":labels.skill_detail.text,"rewind_text":labels.rewind.text,"offers":selection_ids.duplicate(),"connection_count":_connections.size(),"settings_error":_setting_error,"manual_adoption":false}
