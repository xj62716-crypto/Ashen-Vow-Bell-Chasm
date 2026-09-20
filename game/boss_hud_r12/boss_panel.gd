extends Control
## Authoritative BossPhaseController state drives a compact, non-interactive HUD.
const STYLE=preload("res://boss_hud_r12/boss_style.gd")
var profile:Resource=preload("res://boss_hud_r12/default_style.tres").duplicate(true)
var world:Node
var player:ParkourPlayer
var manager:Node
var sources:Dictionary={}
var links:Array=[]
var canvas:Control
var title:Label
var status:Label
var detail:Label
var stages:Label
var font:Font
var sans:Font
var active_id:int=-1
var total:int=0
var remaining:int=0
var stage:int=0
var state:StringName=&""
var seconds:float=0
var fill:float=0
var notice_left:float=0
var victory_left:float=0
var age:float=0
var _serial:int=0
var _attached:bool=false

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=load("res://ui_live_r12/fonts/SourceHanSerifSC-Medium.otf");sans=load("res://ui_live_r12/fonts/SourceHanSansSC-Regular.otf")
	canvas=Control.new();canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(canvas);canvas.draw.connect(_draw_frame)
	title=_label(font,22);stages=_label(sans,11);status=_label(sans,16);detail=_label(sans,12);hide()
func _label(typeface:Font,size_value:int)->Label:
	var label:=Label.new();label.add_theme_font_override("font",typeface);label.add_theme_font_size_override("font_size",size_value)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(label);return label
func apply_style(value:Resource)->bool:
	if not value or value.get_script()!=STYLE or not value.valid():return false
	profile=value.duplicate(true);return true
func bind(scene:Node,owner_player:ParkourPlayer,run_manager:Node)->bool:
	if not is_node_ready() or not is_instance_valid(scene) or not is_instance_valid(owner_player) or not is_instance_valid(run_manager):return false
	detach();world=scene;player=owner_player;manager=run_manager;_attached=true
	_connect(get_tree(),&"node_added",_added);_connect(world,&"tree_exiting",detach)
	for actor in get_tree().get_nodes_in_group("acolytes"):_added(actor)
	return true
func _connect(source:Object,event:StringName,callback:Callable)->void:
	if source.is_connected(event,callback):return
	source.connect(event,callback);links.append([weakref(source),event,callback])
func _added(node:Node)->void:
	if _attached and node is LanternAcolyte:_observe.call_deferred(weakref(node),_serial)
func _observe(ref:WeakRef,serial:int)->void:
	var actor=ref.get_ref()
	if not _attached or serial!=_serial or not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.player!=player or not is_instance_valid(actor.boss_controller):return
	var boss:BossPhaseController=actor.boss_controller;var id:int=boss.get_instance_id()
	if sources.has(id):return
	sources[id]={"source":weakref(boss),"original_title":actor._title.visible,"capacity":boss.objectives.size(),"window":boss.state_left}
	_connect(boss,&"phase_changed",_phase.bind(id));_connect(boss,&"tree_exiting",_removed.bind(id));_connect(actor,&"hit_resolved",_hit)
func _phase(_stage:int,next:StringName,id:int)->void:
	if not sources.has(id):return
	var boss=sources[id].source.get_ref()
	if not is_instance_valid(boss):return
	if next==&"shielded":sources[id].capacity=boss.objectives.size()
	if next in [&"exposed",&"terrain_warning"]:sources[id].window=boss.state_left
	if next==&"defeated" and id==active_id:victory_left=1.2
	if next in [&"dormant",&"cancelled"] and id==active_id:notice_left=0;victory_left=0
func _hit(actor:LanternAcolyte,_point:Vector3,accepted:bool,reason:StringName)->void:
	if accepted or reason!=&"boss_shield" or not is_instance_valid(actor.boss_controller):return
	if actor.boss_controller.get_instance_id()==active_id:notice_left=.8
func _removed(id:int)->void:
	if sources.has(id):
		var boss=sources[id].source.get_ref()
		if is_instance_valid(boss) and is_instance_valid(boss.actor):boss.actor._title.visible=sources[id].original_title and boss.actor.health>0
	sources.erase(id)
	if id==active_id:active_id=-1;hide()
func detach()->void:
	_attached=false;_serial+=1
	for row in links:
		var source=row[0].get_ref()
		if is_instance_valid(source) and source.is_connected(row[1],row[2]):source.disconnect(row[1],row[2])
	links.clear()
	for row in sources.values():
		var boss=row.source.get_ref()
		if is_instance_valid(boss) and is_instance_valid(boss.actor):boss.actor._title.visible=row.original_title and boss.actor.health>0
	sources.clear();world=null;player=null;manager=null;active_id=-1;notice_left=0;victory_left=0;hide()
func _exit_tree()->void:detach()
func _process(delta:float)->void:
	if not _attached or not is_instance_valid(player) or not is_instance_valid(manager):hide();return
	if links.size()>32:links=links.filter(func(row):return is_instance_valid(row[0].get_ref()))
	var paused:bool=get_tree().paused
	if not paused:age+=delta;notice_left=maxf(0,notice_left-delta);victory_left=maxf(0,victory_left-delta)
	var chosen:BossPhaseController;var closest:float=55
	for id in sources:
		var boss=sources[id].source.get_ref()
		if not is_instance_valid(boss) or not is_instance_valid(boss.actor):continue
		boss.actor._title.visible=sources[id].original_title and boss.actor.health>0
		if not boss.actor.active or not boss.activated or boss.state in [&"dormant",&"cancelled"]:continue
		if boss.state==&"defeated" and (id!=active_id or victory_left<=0):continue
		var distance:float=boss.actor.global_position.distance_to(player.global_position)
		if distance<closest:chosen=boss;closest=distance
	if not is_instance_valid(chosen):active_id=-1;hide();return
	active_id=chosen.get_instance_id();stage=chosen.stage;state=chosen.state;seconds=maxf(0,chosen.state_left)
	var row:Dictionary=sources[active_id];total=int(row.capacity);remaining=chosen.objectives.size()
	fill=clampf(seconds/maxf(.01,float(row.window)),0,1) if state in [&"exposed",&"terrain_warning"] else 0
	title.text=chosen.actor._name();stages.text="I   ·   II   ·   III     /     第 %d 阶段"%stage
	var target_name:String="熔炉核心" if chosen.kind==&"forge" else "束缚锁链"
	match state:
		&"shielded":status.text="击碎%s  ·  剩余 %d"%[target_name,remaining];detail.text="护盾尚存 · 攻击本体无效" if notice_left>0 else "本体受护盾保护"
		&"exposed":status.text="核心暴露  ·  攻击本体";detail.text="%.1f 秒后重新封闭"%seconds
		&"terrain_warning":status.text="地台即将崩塌";detail.text="%.1f 秒  ·  跃入风井 / 牵引浮墙"%seconds
		&"transition":status.text="封印破裂";detail.text=""
		&"defeated":status.text="已击败";detail.text=""
		_:status.text="";detail.text=""
	visible=not paused and player.control_enabled and int(manager.get("phase"))==1
	if visible:chosen.actor._title.hide()
	_layout();canvas.queue_redraw()
func _layout()->void:
	var view:Vector2=get_viewport().get_visible_rect().size;var scale_value:float=minf(view.x/1280.,view.y/720.)
	canvas.scale=Vector2.ONE*scale_value;canvas.size=Vector2(profile.width,118);canvas.position=Vector2((view.x-profile.width*scale_value)*.5,profile.top*scale_value);canvas.modulate.a=profile.opacity
	for label in [title,stages,status,detail]:label.size.x=profile.width;label.add_theme_color_override("font_color",profile.ivory)
	stages.position.y=0;stages.size.y=18;stages.modulate=Color("a49a85")
	title.position.y=17;title.size.y=33
	status.position.y=62;status.size.y=24;detail.position.y=87;detail.size.y=21
	detail.modulate=profile.warning if state==&"terrain_warning" or notice_left>0 else Color("b2a58e")
func _draw_frame()->void:
	var w:float=profile.width;var c:Color=profile.gold
	canvas.draw_rect(Rect2(0,0,w,115),Color(.025,.027,.024,.64))
	canvas.draw_line(Vector2(0,50),Vector2(w*.38,50),Color(c,.5),1,true);canvas.draw_line(Vector2(w*.62,50),Vector2(w,50),Color(c,.5),1,true)
	if state==&"shielded":
		for index in range(total):
			var p:=Vector2(w*.5+(index-(total-1)*.5)*16,52);var vertices:=PackedVector2Array([p+Vector2(0,-5),p+Vector2(4,0),p+Vector2(0,5),p+Vector2(-4,0)])
			canvas.draw_colored_polygon(vertices,Color(c,1. if index<remaining else .16))
	elif state in [&"exposed",&"terrain_warning"]:
		canvas.draw_line(Vector2(w*.39,52),Vector2(w*.61,52),Color(c,.18),3,true)
		canvas.draw_line(Vector2(w*.39,52),Vector2(w*.39+w*.22*fill,52),profile.warning if state==&"terrain_warning" else c,3,true)
func snapshot()->Dictionary:
	return {"visible":visible,"controller":active_id,"state":str(state),"stage":stage,"total":total,"remaining":remaining,"seconds":seconds,"title":title.text,"status":status.text,"detail":detail.text,"notice":notice_left,"connections":links.size()}
