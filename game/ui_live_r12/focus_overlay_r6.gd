extends Control
## Art candidate. Host feeds normalized reserve and focus phase; no time-scale control.
var strength: float=0.0
var reserve: float=1.0
var age: float=0.0
var phase: String="idle"
var serif: Font
var text_label: Label
var veil: ColorRect
var shimmer: float=0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	serif=load("res://ui_live_r12/fonts/SourceHanSerifSC-Medium.otf")
	veil=ColorRect.new();veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(veil)
	var material=ShaderMaterial.new();material.shader=load("res://ui_live_r12/focus_veil_r6.gdshader");veil.material=material
	text_label=Label.new();text_label.text="专 注";text_label.add_theme_font_override("font",serif);text_label.add_theme_font_size_override("font_size",21);text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(text_label)
func set_focus(state: String,amount: float,normalized_reserve: float,seconds: float) -> void:
	phase=state;strength=clampf(amount,0,1);reserve=clampf(normalized_reserve,0,1);age=seconds
	if veil:
		veil.visible=strength>.001
		veil.material.set_shader_parameter("strength",strength);veil.material.set_shader_parameter("phase_age",age)
	if text_label:
		text_label.position=Vector2(size.x*.5-80,24);text_label.size=Vector2(160,32);text_label.modulate=Color(0.87,0.78,0.59,strength);text_label.visible=strength>.01
	queue_redraw()
func rune(center: Vector2,radius: float,color: Color,rotation: float=0.0) -> void:
	var points=PackedVector2Array()
	for i in range(5):points.append(center+Vector2(cos(rotation+i*TAU/4),sin(rotation+i*TAU/4))*radius)
	draw_polyline(points,color,1.25,true)
	draw_line(center-Vector2(radius*.6,0),center+Vector2(radius*.6,0),color,1,true)
func _draw() -> void:
	if strength<.002:return
	var gold=Color(.74,.60,.35,strength*.8);var pale=Color(.94,.84,.62,strength*.86);var shadow=Color(.055,.065,.063,strength*.8)
	# A clear banner marks the state; ornament stays outside the center/landing area.
	var cx=size.x*.5;draw_style_box(_plaque(shadow),Rect2(cx-97,17,194,46))
	for sign in [-1,1]:
		draw_line(Vector2(cx+sign*100,38),Vector2(cx+sign*145,38),gold,1,true);rune(Vector2(cx+sign*153,38),5,gold,PI/4)
	for right in [false,true]:
		for bottom in [false,true]:
			var x=size.x-8 if right else 8.;var y=size.y-8 if bottom else 8.;var sx=-1 if right else 1;var sy=-1 if bottom else 1
			var enter=1.-strength;var origin=Vector2(x+sx*enter*13,y+sy*enter*13)
			draw_polyline(PackedVector2Array([origin+Vector2(0,sy*75),origin+Vector2(0,sy*15),origin+Vector2(sx*15,0),origin+Vector2(sx*65,0)]),gold,1.7,true)
			draw_polyline(PackedVector2Array([origin+Vector2(sx*6,sy*47),origin+Vector2(sx*6,sy*20),origin+Vector2(sx*20,sy*6),origin+Vector2(sx*47,sy*6)]),Color(gold,.4*strength),1,true)
			rune(origin+Vector2(sx*15,sy*15),6,pale,PI/4)
	var center=Vector2(size.x*.5,size.y-48);var radius=17.;draw_circle(center,24,shadow)
	draw_arc(center,radius+4,0,TAU,65,Color(gold,.28*strength),1,true)
	for i in range(12):
		var a=-PI*.5+i*TAU/12;var alpha=1.0 if float(i)/12<reserve else .16
		draw_arc(center,radius,a,a+TAU/12*.64,8,Color(pale,alpha*strength),2.2,true)
	# Hourglass with a moving narrow stream, recognizable at a glance.
	draw_polyline(PackedVector2Array([center+Vector2(-6,-9),center+Vector2(6,-9),center+Vector2(-5,9),center+Vector2(5,9),center+Vector2(-6,-9)]),gold,1.2,true)
	draw_line(center+Vector2(0,-1),center+Vector2(0,6),pale,1,true)
	draw_circle(center+Vector2(0,3+fmod(age*11,4)),1.2,pale)
func _plaque(color: Color) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=color;style.border_color=Color(.6,.49,.28,strength*.6);style.set_border_width_all(1);style.corner_radius_top_left=2;style.corner_radius_top_right=2;return style
