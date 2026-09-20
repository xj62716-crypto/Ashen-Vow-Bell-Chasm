class_name TrialHUD
extends Control

signal start_requested
signal resume_requested
signal restart_requested
signal quit_requested
signal sensitivity_changed(value: float)
signal fov_changed(value: float)
signal volume_changed(value: float)
signal music_volume_changed(value: float)
signal brightness_changed(value: float)
signal feedback_changed(enabled: bool)
signal rune_selected(index: int)

const INK := Color("#171510")
const MINT := Color("#bca87c")
const GOLD := Color("#c7ab7d")
const PAPER := Color("#ddd3bb")
const MUTED := Color("#a59d8b")

var stage_label: Label
var objective_label: Label
var time_label: Label
var speed_label: Label
var dash_label: Label
var status_label: Label
var toast_label: Label
var toast_panel: PanelContainer
var telemetry_label: Label
var gameplay: Control
var menu: Control
var menu_title: Label
var menu_copy: Label
var primary: Button
var restart: Button
var sensitivity_slider: HSlider
var fov_slider: HSlider
var volume_slider: HSlider
var music_slider: HSlider
var brightness_slider: HSlider
var feedback_toggle: CheckButton
var dash_bar: ProgressBar
var wall_label: Label
var wall_bar: ProgressBar
var course_choice: OptionButton
var class_choice: OptionButton
var item_choice: OptionButton
var class_hint: Label
var reward_layer: Control
var build_label: Label
var interaction_label: Label
var profession_label: Label
var focus_label: Label
var _focus_amount: float = 1.0
var _focus_active: bool = false
var _focus_visible: bool = false
var practice_mode: bool = false
var combat_mode: bool = false
var health_panel: PanelContainer
var health_label: Label
var health_bar: ProgressBar
var _hit_time: float = 0.0
var _hurt_time: float = 0.0
var _kill_hit: bool = false
var _toast_time: float = 0.0
var _menu_kind: String = "ready"
var _wall_panel: PanelContainer
var _timing_panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", PAPER)
	ui_theme.set_color("font_color", "Button", PAPER)
	ui_theme.set_color("font_hover_color", "Button", GOLD)
	ui_theme.set_color("font_focus_color", "Button", GOLD)
	ui_theme.set_stylebox("normal", "Button", _box(Color("#29271f")))
	ui_theme.set_stylebox("hover", "Button", _box(Color("#46402f")))
	ui_theme.set_stylebox("pressed", "Button", _box(Color("#171510")))
	for state in ["normal","hover","pressed"]:
		ui_theme.set_stylebox(state,"OptionButton",ui_theme.get_stylebox(state,"Button"))
	ui_theme.set_color("font_color","OptionButton",PAPER)
	var focus_style := _box(Color(0, 0, 0, 0), 8)
	focus_style.set_border_width_all(2)
	focus_style.border_color = GOLD
	ui_theme.set_stylebox("focus", "Button", focus_style)
	theme = ui_theme
	_build_gameplay()
	_build_menu()


func _box(color: Color, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.border_color=Color("#6b5b3e")
	style.set_border_width_all(1)
	return style


func _label(text_value: String, size: int, color: Color = PAPER) -> Label:
	var item := Label.new()
	item.text = text_value
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item


func _panel(parent: Node, position_value: Vector2, size_value: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position_value
	panel.size = size_value
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color(0.025, 0.032, 0.03, 0.74), 4))
	parent.add_child(panel)
	return panel


func _margin(parent: Node, padding: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	parent.add_child(margin)
	return margin


func _build_gameplay() -> void:
	gameplay = Control.new()
	gameplay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gameplay)
	var left := _panel(gameplay, Vector2(28, 28), Vector2(350, 88))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	_margin(left, 18).add_child(info)
	info.add_child(_label("契 印 远 征", 11, MINT))
	stage_label = _label("01  起跳", 19)
	info.add_child(stage_label)
	objective_label = _label("循着火光，跨过前方的石台。", 14, MUTED)
	info.add_child(objective_label)
	var right := _panel(gameplay, Vector2.ZERO, Vector2(205, 110))
	_timing_panel=right
	right.hide()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -233
	right.offset_right = -28
	right.offset_top = 28
	right.offset_bottom = 138
	var timing := VBoxContainer.new()
	_margin(right, 18).add_child(timing)
	timing.add_child(_label("本次用时", 12, MUTED))
	time_label = _label("00:00.00", 23)
	timing.add_child(time_label)
	status_label = _label("检查点  0 / 2", 13, MINT)
	timing.add_child(status_label)
	health_panel = _panel(gameplay, Vector2.ZERO, Vector2(205, 68))
	health_panel.anchor_left = 0.0
	health_panel.anchor_right = 0.0
	health_panel.anchor_top = 1.0
	health_panel.anchor_bottom = 1.0
	health_panel.offset_left = 28
	health_panel.offset_right = 195
	health_panel.offset_top = -118
	health_panel.offset_bottom = -58
	var vitality := VBoxContainer.new()
	_margin(health_panel, 12).add_child(vitality)
	health_label = _label("生命 100 / 100", 16, PAPER)
	vitality.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.hide()
	health_bar.custom_minimum_size.y = 7
	health_bar.add_theme_stylebox_override("background", _box(Color("#392b2a"), 2))
	health_bar.add_theme_stylebox_override("fill", _box(Color("#bf6550"), 2))
	vitality.add_child(health_bar)
	focus_label = _label("F · 专注", 12, GOLD)
	gameplay.add_child(focus_label)
	focus_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	focus_label.offset_left = 70
	focus_label.offset_right = 195
	focus_label.offset_top = -53
	focus_label.offset_bottom = -25
	focus_label.hide()
	var crosshair := _label("·", 40, PAPER)
	gameplay.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -12
	crosshair.offset_right = 12
	crosshair.offset_top = -29
	crosshair.offset_bottom = 21
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bottom := _panel(gameplay, Vector2.ZERO, Vector2(340, 102))
	bottom.anchor_left = 0.0
	bottom.anchor_right = 0.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 206
	bottom.offset_right = 390
	bottom.offset_top = -76
	bottom.offset_bottom = -20
	var movement := VBoxContainer.new()
	movement.add_theme_constant_override("separation", 5)
	_margin(bottom, 10).add_child(movement)
	speed_label = _label("0.0 m/s", 20)
	speed_label.hide()
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	movement.add_child(speed_label)
	dash_label = _label("起跳后可冲刺 · SHIFT", 12, MINT)
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	movement.add_child(dash_label)
	dash_bar = ProgressBar.new()
	dash_bar.custom_minimum_size.y = 4
	dash_bar.show_percentage = false
	dash_bar.add_theme_stylebox_override("background", _box(Color("#2b3c49"), 2))
	dash_bar.add_theme_stylebox_override("fill", _box(MINT, 2))
	movement.add_child(dash_bar)
	var wall_panel := _panel(gameplay, Vector2.ZERO, Vector2(280, 84))
	_wall_panel=wall_panel
	wall_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	wall_panel.offset_left=-125
	wall_panel.offset_right=125
	wall_panel.offset_top=-165
	wall_panel.offset_bottom=-112
	wall_panel.hide()
	var wall_column := VBoxContainer.new()
	_margin(wall_panel, 12).add_child(wall_column)
	wall_label = _label("", 14, MINT)
	wall_column.add_child(wall_label)
	wall_bar = ProgressBar.new()
	wall_bar.show_percentage = false
	wall_bar.custom_minimum_size.y = 5
	wall_bar.add_theme_stylebox_override("background", _box(Color("#2b3c49"), 2))
	wall_bar.add_theme_stylebox_override("fill", _box(GOLD, 2))
	wall_column.add_child(wall_bar)
	build_label = _label("",13,GOLD)
	build_label.hide()
	gameplay.add_child(build_label)
	build_label.anchor_top = 1.0
	build_label.anchor_bottom = 1.0
	build_label.offset_left = 28
	build_label.offset_top = -184
	build_label.offset_right = 380
	build_label.offset_bottom = -108
	interaction_label = _label("",16,PAPER)
	gameplay.add_child(interaction_label)
	interaction_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_label.offset_left = -180
	interaction_label.offset_right = 180
	interaction_label.offset_top = -68
	interaction_label.offset_bottom = -38
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profession_label=_label("",14,GOLD)
	gameplay.add_child(profession_label)
	profession_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	profession_label.offset_left=-540
	profession_label.offset_right=-28
	profession_label.offset_top=-84
	profession_label.offset_bottom=-28
	profession_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	toast_panel = _panel(gameplay, Vector2.ZERO, Vector2(620, 44))
	toast_panel.anchor_left = 0.0
	toast_panel.anchor_right = 0.0
	toast_panel.offset_left = 28
	toast_panel.offset_right = 548
	toast_panel.offset_top = 142
	toast_panel.offset_bottom = 179
	toast_panel.visible = false
	toast_label = _label("", 18, GOLD)
	toast_panel.add_child(toast_label)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	telemetry_label = _label("", 13, MINT)
	gameplay.add_child(telemetry_label)
	telemetry_label.position = Vector2(28, 160)
	telemetry_label.visible = false


func _build_menu() -> void:
	menu = Control.new()
	add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.018, 0.012, 0.30)
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	center.offset_left=64
	center.offset_right=554
	center.offset_top=-260
	center.offset_bottom=260
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(490, 0)
	var style := _box(Color(0.022, 0.021, 0.017, 0.88), 0)
	style.set_border_width_all(1)
	style.border_color = Color("#6b5b3e")
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_margin(card, 28).add_child(column)
	column.add_child(_label("A S H E N   V O W", 12, MINT))
	menu_title = _label("踏风 · 遗迹试炼", 36)
	var display_font := SystemFont.new()
	display_font.font_names=PackedStringArray(["STZhongsong","SimSun","Noto Serif CJK SC"])
	menu_title.add_theme_font_override("font",display_font)
	column.add_child(menu_title)
	menu_copy = _label("", 15, MUTED)
	menu_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_copy.custom_minimum_size = Vector2(430, 55)
	column.add_child(menu_copy)
	course_choice = _choice(column, "进入路线", ["断桥穿越 · 练习", "侧墙练习", "破界 · 三域主线"])
	course_choice.select(2)
	course_choice.get_parent().hide()
	class_choice = _choice(column, "职业机动", ["影刃 · 长刀疾行", "咒行者 · 法杖借势"])
	class_hint = _label(MovementTrial.PROFILES[0].description, 13, GOLD)
	column.add_child(class_hint)
	class_choice.item_selected.connect(_on_class_selected)
	item_choice = _choice(column, "练习持物", ["空手", "长刀", "法杖"])
	item_choice.get_parent().visible = false
	course_choice.item_selected.connect(func(index: int): item_choice.get_parent().visible = index!=2)
	column.add_child(HSeparator.new())
	var settings_dialog := AcceptDialog.new()
	settings_dialog.title = "画面、声音与操作设置"
	settings_dialog.size = Vector2i(560, 350)
	add_child(settings_dialog)
	var settings_column := VBoxContainer.new()
	settings_column.add_theme_constant_override("separation", 12)
	settings_dialog.add_child(settings_column)
	settings_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_column.offset_left = 20
	settings_column.offset_top = 20
	settings_column.offset_right = -20
	settings_column.offset_bottom = -60
	sensitivity_slider = _setting(settings_column, "鼠标灵敏度", 0.04, 0.22, 0.01, 0.10, "%.2f")
	fov_slider = _setting(settings_column, "视野角度", 65, 100, 1, 80, "%.0f°")
	brightness_slider = _setting(settings_column, "画面亮度", 0.8, 1.8, 0.05, 1.15, "%.2f")
	volume_slider = _setting(settings_column, "音效音量", 0, 1, 0.05, 0.65, "%.2f")
	music_slider = _setting(settings_column, "背景音乐", 0, 1, 0.05, 0.4, "%.2f")
	sensitivity_slider.value_changed.connect(func(value: float): sensitivity_changed.emit(value))
	fov_slider.value_changed.connect(func(value: float): fov_changed.emit(value))
	brightness_slider.value_changed.connect(func(value: float): brightness_changed.emit(value))
	volume_slider.value_changed.connect(func(value: float): volume_changed.emit(value))
	music_slider.value_changed.connect(func(value: float): music_volume_changed.emit(value))
	feedback_toggle = CheckButton.new()
	feedback_toggle.text = "墙跑倾斜与落地反馈"
	feedback_toggle.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), 4))
	feedback_toggle.add_theme_stylebox_override("pressed", _box(Color(0, 0, 0, 0), 4))
	feedback_toggle.add_theme_stylebox_override("hover", _box(Color("#203644"), 4))
	feedback_toggle.add_theme_stylebox_override("hover_pressed", _box(Color("#203644"), 4))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		feedback_toggle.add_theme_color_override(state, PAPER)
	settings_column.add_child(feedback_toggle)
	feedback_toggle.toggled.connect(func(enabled: bool): feedback_changed.emit(enabled))
	var settings_button := Button.new()
	settings_button.text = "画面 / 声音 / 操作设置"
	settings_button.custom_minimum_size.y = 34
	column.add_child(settings_button)
	settings_button.pressed.connect(func(): settings_dialog.popup_centered())
	primary = Button.new()
	primary.custom_minimum_size.y = 48
	column.add_child(primary)
	primary.pressed.connect(_primary_pressed)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	restart = Button.new()
	restart.text = "从起点重新开始"
	restart.custom_minimum_size.y = 40
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(restart)
	restart.pressed.connect(func(): restart_requested.emit())
	var exit_button := Button.new()
	exit_button.text = "退出"
	var secondary_style := _box(Color("#29261f"), 0)
	exit_button.add_theme_stylebox_override("normal", secondary_style)
	exit_button.add_theme_stylebox_override("hover", _box(Color("#484031"), 0))
	exit_button.add_theme_color_override("font_color", PAPER)
	exit_button.add_theme_color_override("font_hover_color", PAPER)
	exit_button.add_theme_color_override("font_focus_color", PAPER)
	exit_button.custom_minimum_size = Vector2(90, 40)
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(exit_button)
	exit_button.pressed.connect(func(): quit_requested.emit())
	var credits := LinkButton.new()
	credits.text = "音乐与美术素材署名"
	credits.add_theme_color_override("font_color", MUTED)
	credits.add_theme_font_size_override("font_size", 12)
	credits.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(credits)
	var attribution := AcceptDialog.new()
	attribution.title = "素材来源与许可证"
	attribution.size = Vector2i(620, 420)
	attribution.min_size = Vector2i(520, 320)
	add_child(attribution)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = "[b]本版原创配乐与技能声音[/b]\n余烬城垣 / 炉心追猎 / 封印回声\n三首原创主题，各含同步探索、战斗分轨；程序合成与混音。\n七种新职业技能声音为本项目制作。\n\n[b]音效与 3D 场景[/b]\nKenney — Castle Kit / RPG Audio / Impact Sounds / Interface Sounds\n[url=https://kenney.nl/assets]Kenney 原始资源[/url] · [url=https://creativecommons.org/publicdomain/zero/1.0/]CC0[/url]\n修改：音效分层、采样率与音量调整；模型缩放与场景摆放。\n\n[b]角色与第一人称手臂[/b]\npara / MakeHuman · [url=https://opengameart.org/content/fps-arms-rigged-only]CC0 原始模型[/url]\n修改：人体拓扑重组、护甲、固定长度骨架与 34 段 Blender 第一人称动作。武器与新增建筑为本项目制作。\n\n[b]地牢材质与岩石[/b]\n[url=https://polyhaven.com/]Poly Haven[/url] · [url=https://polyhaven.com/license]CC0[/url]\nCastle Wall Slates / Stone Floor / Brown Leather / Metal Plate / Rock Face / Boulder 01\n修改：材质参数、模型比例与场景摆放。\n\n[b]历史版本配乐[/b]\nThe Adventure Begins — bart (Bart Kelsey)\n[url=https://opengameart.org/content/adventure-begins]原作[/url] · CC BY 3.0。旧素材保留，本版主线使用原创配乐。"
	body.text += "\n\n[b]全身角色基础拓扑[/b]\nMakeHuman Community — base.obj\nData Collection AB / Joel Palmius / Jonas Hauquier\n[url=https://github.com/makehumancommunity/makehuman/blob/master/makehuman/data/3dobjs/base.obj]原始模型与 CC0 声明[/url]\n修改：体型、服装与护甲、蒙皮、动作和两职业外观。"
	body.meta_clicked.connect(func(meta: Variant): OS.shell_open(str(meta)))
	attribution.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 18
	body.offset_top = 12
	body.offset_right = -18
	body.offset_bottom = -62
	body.add_theme_font_size_override("normal_font_size", 16)
	credits.pressed.connect(func(): attribution.popup_centered())


func _setting(parent: Node, title: String, minimum: float, maximum: float, step_value: float, initial: float, format_value: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := _label(title, 14, MUTED)
	label.custom_minimum_size.x = 112
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 25
	row.add_child(slider)
	var number := _label(format_value % initial, 14, MINT)
	number.custom_minimum_size.x = 48
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	slider.value_changed.connect(func(value: float): number.text = format_value % value)
	return slider


func _choice(parent: Node, title: String, choices: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := _label(title, 14, MUTED)
	label.custom_minimum_size.x = 100
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.y = 32
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for choice: String in choices:
		option.add_item(choice)
	row.add_child(option)
	return option


func _primary_pressed() -> void:
	if _menu_kind == "paused":
		resume_requested.emit()
	else:
		start_requested.emit()


func _on_class_selected(index: int) -> void:
	class_hint.text = MovementTrial.PROFILES[index].description


func hide_rewards() -> void:
	if is_instance_valid(reward_layer):
		remove_child(reward_layer)
		reward_layer.queue_free()
	reward_layer = null


func show_rewards(options: Array[Dictionary], stage: int) -> void:
	hide_rewards()
	menu.hide()
	gameplay.hide()
	reward_layer = Control.new()
	add_child(reward_layer)
	reward_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.015,.022,.02,.82)
	reward_layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	reward_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",22)
	center.add_child(column)
	column.add_child(_label("第 %d 域 · 契印祭坛" % stage,16,GOLD))
	column.add_child(_label("选择契印",30,PAPER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	column.add_child(row)
	for index in range(options.size()):
		var rune: Dictionary = options[index]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(250,300)
		var border := _box(Color("#18221f"),6)
		border.set_border_width_all(1)
		border.border_color = rune.color
		card.add_theme_stylebox_override("panel",border)
		row.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",12)
		_margin(card,20).add_child(content)
		content.add_child(_label(rune.path,13,rune.color))
		content.add_child(_label(rune.name,24,PAPER))
		var effect := _label(rune.effect,15,MUTED)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.custom_minimum_size = Vector2(210,125)
		content.add_child(effect)
		var button := Button.new()
		button.text = "铭刻"
		button.custom_minimum_size.y = 40
		content.add_child(button)
		button.pressed.connect(func(): rune_selected.emit(index))
		if index==0:
			button.grab_focus()
	column.add_child(_label("命火延续 · %d / 2" % (get_tree().current_scene as MovementTrial).combat.health,14,MINT))


func show_menu(kind: String, copy: String = "") -> void:
	var player := get_parent().get_parent().get_node_or_null("Player")
	if player!=null:player.get_node("FirstPersonArms").hide()
	_menu_kind = kind
	menu.visible = true
	gameplay.visible = false
	restart.visible = kind == "paused"
	match kind:
		"ready":
			menu_title.text = "灰烬行者"
			menu_copy.text = "钟渊城垣
穿越坍塌的高墙，取回钟塔中的契印。"
			primary.text = "踏入城垣"
		"paused":
			menu_title.text = "稍作停留"
			menu_copy.text = "城垣中的时间已停驻。\n变更职业后，重新踏入城垣。"
			primary.text = "继续"
		"finished":
			menu_title.text = "回廊已解封" if combat_mode else "试炼完成"
			menu_copy.text = copy
			primary.text = "再跑一次"
		"defeated":
			menu_title.text = "灯火吞没了你"
			menu_copy.text = copy
			primary.text = "重新挑战"
	primary.grab_focus()


func hide_menu() -> void:
	var player := get_parent().get_parent().get_node_or_null("Player")
	if player!=null:player.get_node("FirstPersonArms").show()
	menu.visible = false
	gameplay.visible = true
	primary.release_focus()


func set_stage(index: int) -> void:
	health_panel.visible = combat_mode
	if combat_mode:
		stage_label.text = "囚灯回廊  /  破除封印"
		objective_label.text = "囚灯 0 / 3"
		return
	if practice_mode:
		stage_label.text = "侧墙练习  /  踏墙与蹬跳"
		objective_label.text = "靠右起跳，沿墙前进；标记处空格向左蹬跳。"
		return
	var names := ["01  起跳", "02  凌空冲刺", "03  连贯穿越"]
	var objectives := ["循着火光，跳向前方石台。", "前方断桥：先起跳，再用 SHIFT 冲刺。", "空中调整方向，抵达远处的封印。"]
	stage_label.text = names[clampi(index, 0, 2)]
	objective_label.text = objectives[clampi(index, 0, 2)]


func update_run(player: ParkourPlayer, seconds: float, checkpoint: int, falls: int) -> void:
	time_label.text = format_time(seconds)
	var focus := player.get_node_or_null("TemporalFocus") as TemporalFocus
	_focus_visible = combat_mode and focus != null
	focus_label.visible = _focus_visible
	if _focus_visible:
		_focus_amount = clampf(focus.reserve / maxf(0.001, focus.capacity), 0.0, 1.0)
		_focus_active = focus.active
		focus_label.text = "凝神" if focus.active else ("专注耗尽" if focus.reserve <= 0.001 else "F · 空中专注")
		focus_label.modulate = PAPER if focus.active else GOLD
	status_label.text = "检查点  %d / 2  ·  失足 %d" % [checkpoint, falls]
	if practice_mode:
		status_label.text = "%s · 失足 %d" % [player.parkour_profile.display_name, falls]
	if combat_mode:
		var combat := player.get_node("Combat") as PlayerCombat
		profession_label.text=combat.arts.status()
		var trial := get_tree().current_scene as MovementTrial
		health_label.text = "◆  ◆" if combat.health>=2 else ("◆  ◇" if combat.health==1 else "◇  ◇")
		health_bar.value = 100.0 * combat.health / combat.maximum_health
		status_label.text = "%s · 界标 %d / 3 · 击杀 %d" % [player.parkour_profile.display_name,trial.combat_checkpoint_index if trial!=null else 0,combat.kills]
		if trial != null:
			stage_label.text = "%02d / %02d  %s" % [trial.stage_number,trial.stage_count,trial.combat_room.stage_title]
			objective_label.text = trial.combat_room.objective_text()
			var target := trial.combat_room.interaction_target()
			interaction_label.text = ""
			if target is RunAltar and not target.used:
				interaction_label.text = "E · 铭刻契印"
			elif target is RunMechanism and not target.used:
				interaction_label.text = "E · 激活"
			elif target is TerrainDevice and not target.used:
				interaction_label.text="E · 改变通路"
			elif target is RiftConstruct and target.kind==&"anchor":
				interaction_label.text="E · 抛出钩锁"
			if player.grapple.active:interaction_label.text="空格 / E · 松钩"
		var names := combat.runes.map(func(id: StringName):return RuneCatalog.title(id))
		build_label.text=" · ".join(names.slice(maxi(0,names.size()-3)))
		var ready: String = combat.build_status()
		if not ready.is_empty():
			build_label.text += "\n" + ready
	speed_label.text = "%.1f m/s" % player.horizontal_speed()
	dash_label.text = "冲刺中" if player.is_dashing() else "冲刺就绪"
	if player.sliding:
		dash_label.text = "滑铲"
	if not player.dash_available and not player.is_dashing():
		dash_label.text = "冲刺已消耗"
	dash_label.modulate = Color.WHITE if player.dash_available or player.is_dashing() else MUTED
	dash_bar.value = 100.0 if player.dash_available else 0.0
	wall_bar.value = 100.0 * player.wall_time_remaining() / maxf(.001,player.parkour_profile.wall_duration)
	_wall_panel.visible = player.is_wall_running()
	_timing_panel.visible = telemetry_label.visible
	build_label.visible = telemetry_label.visible
	if player.is_wall_running():
		wall_label.text = "%s墙疾行 · %.1f 秒 · 余 %d 段" % ["左" if player.wall_side < 0 else "右", player.wall_time_remaining(), player.wall_segments_remaining()]
	else:
		wall_label.text = "墙跑耗尽" if player.wall_time_remaining()<=0.0 else "墙跑就绪"
	if telemetry_label.visible:
		telemetry_label.text = "FPS %d\n位置 %.1f / %.1f / %.1f\n垂直速度 %.2f\n落地 %s · 跳跃 %d · 冲刺 %d" % [Engine.get_frames_per_second(), player.position.x, player.position.y, player.position.z, player.velocity.y, str(player.is_on_floor()), player.jump_count, player.dash_count]
		telemetry_label.text += "\n沿墙 %d · 蹬跳 %d · 冲刺恢复 %d" % [player.wall_run_count, player.wall_jump_count, player.dash_refund_count]


func toast(message: String) -> void:
	toast_label.text = message
	toast_panel.visible = true
	toast_label.modulate.a = 1.0
	_toast_time = 2.2


func _process(delta: float) -> void:
	if get_tree().paused:
		_focus_active = false
		queue_redraw()
		return
	_toast_time = maxf(0.0, _toast_time - delta)
	toast_label.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
	toast_panel.visible = _toast_time > 0.0
	_hit_time = maxf(0.0, _hit_time - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	queue_redraw()


func show_hit(defeated: bool) -> void:
	_hit_time = 0.24
	_kill_hit = defeated


func show_hurt() -> void:
	_hurt_time = 0.35


func reset_combat_feedback() -> void:
	_hit_time = 0.0
	_hurt_time = 0.0


func _draw() -> void:
	if gameplay == null or not gameplay.visible:
		return
	if _focus_visible:
		var focus_center := Vector2(45, size.y - 40)
		draw_arc(focus_center, 14, -PI * 0.5, PI * 1.5, 40, Color(0.28, 0.25, 0.19), 1.0, true)
		if _focus_amount > 0.001:
			draw_arc(focus_center, 14, -PI * 0.5, -PI * 0.5 + TAU * _focus_amount, 40, PAPER if _focus_active else GOLD, 2.0, true)
		# An hourglass engraving keeps the resource readable without another card.
		var rune := PackedVector2Array([Vector2(-5,-7),Vector2(5,-7),Vector2(-5,7),Vector2(5,7),Vector2(-5,-7)])
		for index in range(rune.size()):
			rune[index] += focus_center
		draw_polyline(rune, GOLD, 1.0, true)
		if _focus_active:
			var gold := Color(GOLD, 0.35)
			for side: float in [-1.0, 1.0]:
				var x: float = 14.0 if side < 0.0 else size.x - 14.0
				draw_line(Vector2(x, size.y * 0.34), Vector2(x, size.y * 0.66), gold, 1.0, true)
				for fraction: float in [0.34, 0.5, 0.66]:
					var point := Vector2(x, size.y * fraction)
					draw_line(point + Vector2(-4, 0), point + Vector2(0, -6), gold, 1.0, true)
					draw_line(point + Vector2(0, -6), point + Vector2(4, 0), gold, 1.0, true)
	if _hit_time > 0.0:
		var center := size * 0.5
		var color: Color = GOLD if _kill_hit else PAPER
		color.a = minf(1.0, _hit_time * 10.0)
		for direction: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + direction * 7, center + direction * 14, color, 2.5, true)
	if _hurt_time > 0.0:
		var color := Color(0.8, 0.15, 0.08, _hurt_time * 2.0)
		draw_rect(Rect2(Vector2.ZERO, size), color, false, 12.0)


static func format_time(seconds: float) -> String:
	var centiseconds: int = int(seconds * 100.0)
	return "%02d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]
