extends Button

var kind := "paper"
var chosen := false
var number := 1
var gold := Color("bc9b60")
var parchment := Color("dfcfaa")
var paper: Texture2D
var metal: Texture2D
var leather: Texture2D
var crest: Texture2D
var serif: Font
var sans: Font
var title := ""
var eyebrow := ""
var description := ""
var synergy := ""
var entered := false
var lift := 0.0
var attention_tween: Tween

func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	focus_mode=Control.FOCUS_ALL
	for state in ["normal","hover","pressed","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	serif=load("res://ui_live_r12/fonts/SourceHanSerifSC-Medium.otf")
	sans=load("res://ui_live_r12/fonts/SourceHanSansSC-Regular.otf")
	paper=load("res://ui_live_r12/textures/aged_vellum.png")
	metal=load("res://ui_live_r12/textures/metal_plate.jpg")
	leather=load("res://ui_live_r12/textures/brown_leather.jpg")
	mouse_entered.connect(func(): entered=true; animate_attention())
	mouse_exited.connect(func(): entered=false; animate_attention())
	focus_entered.connect(animate_attention)
	focus_exited.connect(animate_attention)
	if kind!="menu":
		add_text(eyebrow,Vector2(30,36),Vector2(size.x-60,28),16,false,Color("665139"))
		add_text(title,Vector2(22,228),Vector2(size.x-44,60),29,true,Color("302923"))
		add_text(description,Vector2(38,324),Vector2(size.x-76,144),20,false,Color("3d382d"))
		add_text(synergy,Vector2(38,483),Vector2(size.x-76,63),18,false,Color("67543b"))
	queue_redraw()

func add_text(value: String,point: Vector2,extent: Vector2,font_size: int,use_serif: bool,tint: Color) -> void:
	var node:=Label.new()
	node.text=value
	node.position=point
	node.size=extent
	node.add_theme_font_override("font",serif if use_serif else sans)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",tint)
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.clip_text=true
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(node)
	# Font changes can raise minimum size before wrapping is enabled. Reapply bounds.
	node.size=extent

func animate_attention() -> void:
	if get_meta("reduced_motion",false):
		lift=0.0
		queue_redraw()
		return
	if attention_tween and attention_tween.is_valid(): attention_tween.kill()
	var tw:=create_tween()
	attention_tween=tw
	tw.set_ignore_time_scale(true)
	tw.tween_property(self,"lift",1.0 if entered or has_focus() else 0.0,0.12)
	tw.tween_callback(queue_redraw)

func _process(_delta: float) -> void:
	queue_redraw()

func textured(points: PackedVector2Array,texture: Texture2D,tint: Color) -> void:
	var uv:=PackedVector2Array()
	for point in points:
		uv.append(point/size)
	draw_polygon(points,PackedColorArray([tint]),uv,texture)

func _draw() -> void:
	if serif==null:
		return
	if kind=="menu":
		var col:=Color("f0dec0") if entered or has_focus() or chosen else Color("b9aa8d")
		var offset:=8.0*lift
		draw_string(serif,Vector2(39+offset,46),title,HORIZONTAL_ALIGNMENT_LEFT,-1,30,col)
		if entered or has_focus() or chosen:
			draw_colored_polygon(PackedVector2Array([Vector2(9,32),Vector2(19,22),Vector2(29,32),Vector2(19,42)]),gold)
			draw_line(Vector2(40,61),Vector2(size.x-32,61),Color(gold,.65),1,true)
			draw_line(Vector2(40,63),Vector2(size.x*.62,63),Color(gold,.18),1,true)
		return
	var polygon:=PackedVector2Array([Vector2(17,7),Vector2(size.x-12,0),Vector2(size.x-4,size.y-57),Vector2(size.x-36,size.y-29),Vector2(size.x*.53,size.y-12),Vector2(size.x*.36,size.y-30),Vector2(8,size.y-18),Vector2(0,38)])
	var shadow:=PackedVector2Array()
	for p in polygon:shadow.append(p+Vector2(9,12))
	draw_colored_polygon(shadow,Color(0,0,0,.48))
	textured(polygon,paper,Color(1.05,1.02,.95) if entered or has_focus() else Color(1,1,1))
	draw_polyline(polygon,Color("594432"),2,true)
	draw_texture_rect(metal,Rect2(6,8,size.x-12,19),false,Color(.38,.32,.22,1))
	for x in [23.0,size.x-23.0]:
		draw_circle(Vector2(x,17),4,Color("251d17"))
		draw_arc(Vector2(x,17),3,PI,TAU,12,Color("bca576"),1,true)
	var center:=Vector2(size.x*.5,154)
	draw_circle(center,69,Color("422d21"))
	draw_arc(center,67,0,TAU,80,Color("98713f"),3,true)
	draw_arc(center,58,0,TAU,80,Color("654830"),1,true)
	if crest:
		draw_texture_rect(crest,Rect2(center-Vector2(51,51),Vector2(102,102)),false,Color("e8ce93"))
	draw_line(Vector2(42,302),Vector2(size.x-42,302),Color("6f5435"),1,true)
	for side in [-1,1]:
		draw_polyline(PackedVector2Array([Vector2(size.x/2+side*9,296),Vector2(size.x/2+side*16,302),Vector2(size.x/2+side*9,308)]),Color("6f5435"),1,true)
	draw_line(Vector2(40,477),Vector2(size.x-40,477),Color(.3,.23,.15,.3),1,true)
	draw_circle(Vector2(size.x*.5,size.y-50),23,Color("642d29") if not chosen else Color("a3783c"))
	draw_arc(Vector2(size.x*.5,size.y-50),18,0,TAU,40,Color("ac7c50"),1,true)
	draw_string(serif,Vector2(size.x*.5-9,size.y-41),"印" if chosen else str(number),HORIZONTAL_ALIGNMENT_CENTER,18,20,Color("e6c594"))
	if has_focus() or entered or chosen:
		var rim:=PackedVector2Array([Vector2(10,1),Vector2(size.x-5,-5),Vector2(size.x+3,size.y-56)])
		draw_polyline(rim,Color(gold,.95),2,true)
		draw_line(Vector2(3,41),Vector2(10,size.y-15),Color(gold,.9),2,true)
	if has_focus():
		draw_polyline(PackedVector2Array([Vector2(-14,35),Vector2(-22,47),Vector2(-14,59)]),parchment,2,true)
		draw_polyline(PackedVector2Array([Vector2(size.x+14,35),Vector2(size.x+22,47),Vector2(size.x+14,59)]),parchment,2,true)
