extends Node3D
## Authoritative mechanics own collision, damage and timing. This bridge only draws.
const OBJECTIVE=preload("res://enemy_fx_r14/objective_skin.gd")
const HAZARD=preload("res://enemy_fx_r14/hazard_skin.gd")
const WARD=preload("res://enemy_fx_r14/ward_skin.gd")
const CHAIN=preload("res://enemy_fx_r14/rune_chain.gd")
const SURFACE=preload("res://enemy_fx_r14/floating_surface_skin.gd")
const MODEL=preload("res://enemy_fx_r14/candidate_model.gd")
const TELL=preload("res://enemy_fx_r14/enemy_tell.gd")
const MISSILE=preload("res://enemy_fx_r14/hostile_magic.gd")
## Optional candidate substitution is explicit. Production final models keep their owner.
var use_candidate_models:bool=false
var profile:Resource=preload("res://enemy_fx_r14/default_profile.tres").duplicate(true)
var world:Node
var player:ParkourPlayer
var objectives:Dictionary={}
var hazards:Dictionary={}
var wards:Dictionary={}
var cracks:Dictionary={}
var surfaces:Dictionary={}
var enemies:Dictionary={}
var missiles:Dictionary={}
var recent_contacts:Array=[]
var fades:Array[Dictionary]=[]
var hidden:Dictionary={}
var connections:Array=[]
var events:Array[Dictionary]=[]
var generation:int=0
var age:float=0
var detached:bool=true
var was_controlled:bool=false

func _ready()->void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;process_priority=120

func apply_visual_profile(value:Resource)->bool:
	if not is_instance_valid(value) or value.get_script()!=preload("res://enemy_fx_r14/enemy_fx_profile.gd") or not value.valid():return false
	profile=value.duplicate(true);return true

func bind_actor_markers(actor:LanternAcolyte,weakpoint:Node3D,emitter:Node3D)->bool:
	if not is_instance_valid(actor) or not enemies.has(actor.get_instance_id()):return false
	if not is_instance_valid(weakpoint) or not is_instance_valid(emitter):return false
	enemies[actor.get_instance_id()].core_marker=weakref(weakpoint);enemies[actor.get_instance_id()].emitter_marker=weakref(emitter)
	return true

func bind(scene:Node,owner_player:ParkourPlayer)->bool:
	if not is_node_ready() or not is_instance_valid(scene) or not is_instance_valid(owner_player):return false
	detach();world=scene;player=owner_player;detached=false
	connect_source(get_tree(),&"node_added",_added);connect_source(world,&"tree_exiting",detach)
	connect_source(player.get_node("Combat"),&"temporal_reset_requested",reset_visuals)
	was_controlled=player.control_enabled;_scan()
	return true

func _scan()->void:
	for group in ["acolytes","boss_objectives","hostile_projectiles","boss_surfaces"]:
		for node in get_tree().get_nodes_in_group(group):_added(node)

func connect_source(source:Object,event:StringName,callback:Callable)->void:
	if source.is_connected(event,callback):return
	source.connect(event,callback);connections.append([weakref(source),event,callback])

func record(kind:String,data:Dictionary)->void:
	var item:=data.duplicate();item.kind=kind;item.world_seconds=age;events.append(item)
	while events.size()>256:events.pop_front()

func hide_original(node:Node3D)->void:
	if not is_instance_valid(node):return
	if not hidden.has(node.get_instance_id()):hidden[node.get_instance_id()]={"source":weakref(node),"visible":node.visible}
	node.hide()

func restore_originals()->void:
	for row in hidden.values():
		var node=row.source.get_ref()
		if is_instance_valid(node):node.visible=row.visible
	hidden.clear()

func reset_visuals()->void:
	generation+=1
	for rows in [objectives.values(),hazards.values(),wards.values(),cracks.values(),surfaces.values(),enemies.values(),missiles.values(),fades]:
		for row in rows:
			if is_instance_valid(row.visual):row.visual.hide();row.visual.queue_free()
			if row.has("chain") and is_instance_valid(row.chain):row.chain.queue_free()
			if row.has("model") and is_instance_valid(row.model):row.model.queue_free()
	objectives.clear();hazards.clear();wards.clear();cracks.clear();surfaces.clear();enemies.clear();missiles.clear();recent_contacts.clear();fades.clear();restore_originals()
	record("reset",{})
	if not detached:_scan.call_deferred()

func detach()->void:
	detached=true
	for row in connections:
		var node=row[0].get_ref()
		if is_instance_valid(node) and node.is_connected(row[1],row[2]):node.disconnect(row[1],row[2])
	connections.clear();reset_visuals();world=null;player=null

func _exit_tree()->void:detach()

func _added(node:Node)->void:
	if detached:return
	if node is MagicBolt and not node.friendly:_watch_missile(node)
	if node is BossObjective or node is BossHazard or node is EnemyHazard or node is BossOrbitSurface or node is LanternAcolyte or node is ImpactBurst or node is BellAnchor or node is SweepWave:_observe.call_deferred(weakref(node),generation)

func _watch_missile(source:MagicBolt)->void:
	var id:int=source.get_instance_id()
	if missiles.has(id) or missiles.size()>=32 or not is_instance_valid(player) or not player.control_enabled:return
	missiles[id]={"source":weakref(source),"visual":null}
	connect_source(source,&"contacted",_missile_contact.bind(id));connect_source(source,&"tree_exiting",_missile_removed.bind(id))
	_make_missile.call_deferred(id,generation)
func _make_missile(id:int,serial:int)->void:
	if detached or serial!=generation or not missiles.has(id):return
	var source=missiles[id].source.get_ref()
	if not is_instance_valid(source) or source.is_queued_for_deletion():return
	missiles[id].visual=_new_missile(source);hide_original(source)
func _new_missile(source:MagicBolt)->Node3D:
	var skin=MISSILE.new();skin.crossbow=is_instance_valid(source.source_enemy) and source.source_enemy.role==&"crossbow"
	skin.element="blade" if skin.crossbow else "fire";skin.tint=Color("cba060") if skin.crossbow else Color("b77d67")
	var tuning=load("res://fx_live_r13/profiles/default.tres").duplicate(true);tuning.projectile_scale=.8;tuning.impact_scale=.7;tuning.emission_scale=.7;tuning.light_energy_scale=.35
	skin.configure(tuning);add_child(skin);skin.set_launch_origin(source.global_position);return skin
func _missile_contact(point:Vector3,_collider:Node,id:int)->void:
	if not missiles.has(id):return
	var row:Dictionary=missiles[id];var source=row.source.get_ref()
	if not is_instance_valid(source):return
	var skin=row.visual if is_instance_valid(row.visual) else _new_missile(source)
	skin.contact(point);fades.append({"visual":skin,"type":"missile"});row.visual=null
	recent_contacts.append({"point":point,"frame":Engine.get_process_frames()})
	record("hostile_contact",{"id":id,"point":str(point)})
func _missile_removed(id:int)->void:
	if not missiles.has(id):return
	if is_instance_valid(missiles[id].visual):missiles[id].visual.queue_free()
	missiles.erase(id);hidden.erase(id)

func _observe(ref:WeakRef,serial:int)->void:
	var source=ref.get_ref()
	if detached or serial!=generation or not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion():return
	if not is_instance_valid(player) or not player.control_enabled:return
	var id:int=source.get_instance_id()
	if source is ImpactBurst:
		if recent_contacts.any(func(row):return Engine.get_process_frames()-row.frame<=1 and row.point.distance_to(source.global_position)<.02):hide_original(source)
	elif source is BellAnchor:
		if objectives.has(id):return
		var skin=OBJECTIVE.new();skin.kind=&"chain";add_child(skin);skin.scale=Vector3.ONE*.72;skin.global_position=source.global_position
		var chain=CHAIN.new();add_child(chain);chain.material.emission=Color("8d7951")
		objectives[id]={"source":ref,"visual":skin,"chain":chain};hide_original(source)
		connect_source(source,&"shattered",_bell_broken.bind(id));connect_source(source,&"tree_exiting",_objective_removed.bind(id))
	elif source is BossObjective:
		if objectives.has(id):return
		var skin=OBJECTIVE.new();skin.kind=source.kind;add_child(skin);skin.global_transform=source.global_transform
		objectives[id]={"source":ref,"visual":skin};hide_original(source)
		if source.kind==&"chain":
			var chain=CHAIN.new();add_child(chain);chain.material.albedo_color=Color("68606e");chain.material.emission=Color("7f6390");objectives[id].chain=chain
		connect_source(source,&"struck",_objective_struck);connect_source(source,&"tree_exiting",_objective_removed.bind(id))
		record("objective_added",{"id":id,"type":str(source.kind),"point":str(source.global_position)})
	elif source is SweepWave:
		if hazards.has(id):return
		var skin=load("res://enemy_fx_r14/wave_skin.gd").new();skin.high=source.high;add_child(skin);skin.global_transform=source.global_transform
		hazards[id]={"source":ref,"visual":skin,"wave":true};hide_original(source);connect_source(source,&"tree_exiting",_hazard_removed.bind(id))
	elif source is BossHazard or source is EnemyHazard:
		if hazards.has(id):return
		var kind:StringName=source.kind if source is BossHazard else &"ground"
		var skin=HAZARD.new();skin.kind=kind;skin.radius=source.radius;skin.duration=source.delay;add_child(skin);skin.global_transform=source.global_transform
		hazards[id]={"source":ref,"visual":skin};hide_original(source)
		connect_source(source,&"detonated",_hazard_detonated.bind(id) if source is BossHazard else _ordinary_detonated.bind(id));connect_source(source,&"tree_exiting",_hazard_removed.bind(id))
		record("hazard_added",{"id":id,"type":str(kind),"radius":source.radius,"delay":source.delay})
	elif source is BossOrbitSurface:
		if surfaces.has(id):return
		var skin=SURFACE.new();add_child(skin);skin.bind(source);skin.global_transform=source.global_transform
		surfaces[id]={"source":ref,"visual":skin}
		for child in source.get_children():
			if child is MeshInstance3D:hide_original(child)
		connect_source(source,&"tree_exiting",_surface_removed.bind(id))
	elif source is LanternAcolyte:
		_bind_enemy(source)
		if is_instance_valid(source.boss_controller):_bind_controller(source.boss_controller)

func _bind_enemy(actor:LanternAcolyte)->void:
	var id:int=actor.get_instance_id()
	if enemies.has(id) or enemies.size()>=40:return
	var tell=TELL.new();tell.settings=profile.duplicate(true);add_child(tell);tell.bind(actor)
	var model:Node3D
	if use_candidate_models:
		model=MODEL.new();add_child(model)
		if not model.bind(actor):model.queue_free();model=null
		else:hide_original(actor._visual)
	enemies[id]={"source":weakref(actor),"visual":tell,"model":model}
	hide_original(actor._beam);hide_original(actor._tell);hide_original(actor._guard_visual)
	connect_source(actor.brain,&"attack_committed",_attack_committed.bind(id))
	connect_source(actor.brain,&"attack_released",_attack_released.bind(id))
	connect_source(actor.brain,&"state_changed",_enemy_state.bind(id))
	connect_source(actor,&"guard_opened",_guard_opened.bind(id))
	connect_source(actor,&"defeated",_enemy_defeated)
	connect_source(actor,&"hit_resolved",_hit_resolved)
	connect_source(actor,&"control_applied",_control_applied)
	connect_source(actor,&"tree_exiting",_enemy_removed.bind(id))
	if is_instance_valid(actor.brain.anchor):_added(actor.brain.anchor)

func _attack_committed(kind:StringName,point:Vector3,seconds:float,id:int)->void:
	if not enemies.has(id):return
	enemies[id].visual.committed(kind,seconds);record("attack_committed",{"id":id,"attack":str(kind),"seconds":seconds,"point":str(point)})
func _attack_released(kind:StringName,point:Vector3,id:int)->void:
	if not enemies.has(id):return
	enemies[id].visual.released(kind)
	if is_instance_valid(enemies[id].model):enemies[id].model.release_attack()
	record("attack_released",{"id":id,"attack":str(kind),"point":str(point)})
func _enemy_state(_previous:StringName,current:StringName,id:int)->void:
	if enemies.has(id):enemies[id].visual.changed(current)
func _guard_opened(id:int)->void:
	if enemies.has(id):enemies[id].visual.exposed();record("guard_opened",{"id":id})
func _hit_resolved(actor:LanternAcolyte,point:Vector3,accepted:bool,reason:StringName)->void:
	var id:int=actor.get_instance_id()
	if not enemies.has(id):return
	if not accepted and reason in [&"guard",&"boss_shield"]:enemies[id].visual.reaction(point,&"guard")
	record("hit_resolved",{"id":id,"accepted":accepted,"reason":str(reason),"point":str(point)})
func _control_applied(actor:LanternAcolyte,point:Vector3,element:StringName,seconds:float)->void:
	var id:int=actor.get_instance_id()
	if not enemies.has(id):return
	enemies[id].visual.reaction(point,element)
	record("control_applied",{"id":id,"element":str(element),"seconds":seconds})
func _enemy_defeated(actor:LanternAcolyte)->void:
	if enemies.has(actor.get_instance_id()):enemies[actor.get_instance_id()].visual.changed(&"idle")
func _enemy_removed(id:int)->void:
	if not enemies.has(id):return
	var row:Dictionary=enemies[id];row.visual.queue_free()
	if is_instance_valid(row.model):row.model.queue_free()
	enemies.erase(id)
func _surface_removed(id:int)->void:
	if surfaces.has(id):surfaces[id].visual.queue_free();surfaces.erase(id)

func _bind_controller(controller:BossPhaseController)->void:
	if not is_instance_valid(controller) or not controller.is_inside_tree() or not is_instance_valid(controller.actor) or not controller.actor.is_inside_tree():return
	var id:int=controller.get_instance_id()
	if wards.has(id):return
	var skin=WARD.new();add_child(skin);skin.global_position=controller.actor.get_hit_point();skin.update_state(controller.state,controller.kind)
	wards[id]={"source":weakref(controller),"visual":skin}
	connect_source(controller,&"phase_changed",_phase_changed.bind(id))
	connect_source(controller,&"mechanic_event",_mechanic_event.bind(id))
	connect_source(controller.arena,&"terrain_warning",_terrain_warning.bind(id))
	connect_source(controller.arena,&"terrain_changed",_terrain_changed.bind(id))
	connect_source(controller,&"tree_exiting",_controller_removed.bind(id))

func _phase_changed(stage:int,state:StringName,id:int)->void:
	if not wards.has(id):return
	var controller=wards[id].source.get_ref()
	wards[id].visual.update_state(state,controller.kind)
	record("phase",{"stage":stage,"state":str(state),"controller":id})
	if state in [&"cancelled",&"dormant",&"defeated"]:_clear_controller_effects(controller)

func _clear_controller_effects(controller:BossPhaseController)->void:
	for id in hazards.keys():
		var node=hazards[id].source.get_ref()
		if not is_instance_valid(node) or (node is BossHazard and node.controller==controller):_hazard_removed(id)
	var id:int=controller.get_instance_id()
	if cracks.has(id):cracks[id].visual.queue_free();cracks.erase(id)

func _controller_removed(id:int)->void:
	if wards.has(id):wards[id].visual.queue_free();wards.erase(id)
	if cracks.has(id):cracks[id].visual.queue_free();cracks.erase(id)

func _mechanic_event(event:StringName,point:Vector3,seconds:float,id:int)->void:
	record("mechanic",{"event":str(event),"point":str(point),"seconds":seconds,"controller":id})

func _objective_struck(source:BossObjective)->void:
	var id:int=source.get_instance_id()
	_shatter_objective(id,source.global_position)
func _bell_broken(id:int)->void:
	if objectives.has(id):_shatter_objective(id,objectives[id].visual.global_position)
func _shatter_objective(id:int,point:Vector3)->void:
	if not objectives.has(id):return
	if objectives[id].has("chain"):
		objectives[id].chain.release("broken");fades.append({"visual":objectives[id].chain,"type":"chain"})
	var skin=objectives[id].visual;skin.shatter();fades.append({"visual":skin,"type":"objective"});objectives.erase(id)
	record("objective_broken",{"id":id,"point":str(point)})

func _objective_removed(id:int)->void:
	if objectives.has(id):
		objectives[id].visual.queue_free()
		if objectives[id].has("chain"):objectives[id].chain.queue_free()
		objectives.erase(id)
	hidden.erase(id)

func _hazard_detonated(kind:StringName,point:Vector3,id:int)->void:
	if not hazards.has(id):return
	var skin=hazards[id].visual;skin.discharge();fades.append({"visual":skin,"type":"hazard"});hazards.erase(id)
	record("hazard_detonated",{"type":str(kind),"point":str(point)})

func _ordinary_detonated(id:int)->void:
	if hazards.has(id):_hazard_detonated(&"ground",hazards[id].visual.global_position,id)

func _hazard_removed(id:int)->void:
	if hazards.has(id):hazards[id].visual.queue_free();hazards.erase(id)
	hidden.erase(id)

func _terrain_warning(seconds:float,id:int)->void:
	if not wards.has(id):return
	var controller=wards[id].source.get_ref();var floor=controller.arena.floor_body
	if not is_instance_valid(floor):return
	for child in floor.get_children():
		if not child is CollisionShape3D or not child.shape is BoxShape3D:continue
		var material:=ShaderMaterial.new();material.shader=preload("res://enemy_fx_r14/threat_sigil.gdshader");material.set_shader_parameter("square",true);material.set_shader_parameter("tint",Color("a181b0"))
		var plane:=PlaneMesh.new();plane.size=Vector2(child.shape.size.x,child.shape.size.z)
		var visual:=MeshInstance3D.new();visual.mesh=plane;visual.material_override=material;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
		visual.global_transform=child.global_transform;visual.global_position+=child.global_basis.y*(child.shape.size.y*.5+.025)
		if cracks.has(id):cracks[id].visual.queue_free()
		cracks[id]={"visual":visual,"material":material,"duration":seconds};record("terrain_warning",{"seconds":seconds,"size":str(child.shape.size),"controller":id});break

func _terrain_changed(collapsed:bool,id:int)->void:
	if cracks.has(id):cracks[id].visual.queue_free();cracks.erase(id)
	record("terrain_changed",{"collapsed":collapsed,"controller":id})

func _process(delta:float)->void:
	if detached or not is_instance_valid(player) or get_tree().paused:return
	if player.control_enabled!=was_controlled:
		was_controlled=player.control_enabled
		if was_controlled:_scan()
		else:reset_visuals()
	if not was_controlled:return
	age+=delta
	for row in hidden.values():
		var node=row.source.get_ref()
		if is_instance_valid(node):node.hide()
	for id in objectives.keys():
		var row:Dictionary=objectives[id];var node=row.source.get_ref()
		if is_instance_valid(node):
			row.visual.global_position=node.global_position;row.visual.global_basis=node.global_basis.scaled(Vector3.ONE*(.72 if node is BellAnchor else 1.));row.visual.tick(delta)
			var owner_enemy:LanternAcolyte=node.owner_enemy if node is BellAnchor else node.controller.actor if is_instance_valid(node.controller) else null
			if row.has("chain") and is_instance_valid(owner_enemy):
				row.chain.tick(delta);row.chain.update_endpoints(node.global_position,owner_enemy.get_hit_point(),{"phase":"pull","elapsed":0.})
	for row in missiles.values():
		var node=row.source.get_ref()
		if is_instance_valid(node) and is_instance_valid(row.visual):row.visual.flight(node.global_position,node.direction,delta)
	recent_contacts=recent_contacts.filter(func(row):return Engine.get_process_frames()-row.frame<=1)
	for id in surfaces.keys():
		var row:Dictionary=surfaces[id];var node=row.source.get_ref()
		if is_instance_valid(node):row.visual.global_transform=node.global_transform;row.visual.tick(delta)
	for id in enemies.keys():
		var row:Dictionary=enemies[id];var node=row.source.get_ref()
		if not is_instance_valid(node):continue
		var core:Vector3=node.get_hit_point()+node._visual.global_basis.z*.35
		if is_instance_valid(row.model):row.model.tick(delta);core=row.model.core_point(core)
		var emitter:Vector3=Vector3.INF
		if row.has("core_marker") and is_instance_valid(row.core_marker.get_ref()):core=row.core_marker.get_ref().global_position
		if row.has("emitter_marker") and is_instance_valid(row.emitter_marker.get_ref()):emitter=row.emitter_marker.get_ref().global_position
		row.visual.tick(delta,core,emitter)
	for id in hazards.keys():
		var row:Dictionary=hazards[id];var node=row.source.get_ref()
		if is_instance_valid(node):row.visual.global_transform=node.global_transform;row.visual.tick(delta,node.radius if row.get("wave",false) else node.delay)
	for id in wards.keys():
		var row:Dictionary=wards[id];var controller=row.source.get_ref()
		if not is_instance_valid(controller):continue
		row.visual.global_position=controller.actor.get_hit_point();row.visual.tick(delta)
		if cracks.has(id):
			cracks[id].material.set_shader_parameter("progress",clampf(1.0-controller.state_left/cracks[id].duration,0,1));cracks[id].material.set_shader_parameter("age",age)
	for index in range(fades.size()-1,-1,-1):
		var row:Dictionary=fades[index];var alive:bool=false
		if is_instance_valid(row.visual):alive=row.visual.fade_contact(delta) if row.type=="missile" else row.visual.tick(delta) if row.type in ["objective","chain"] else row.visual.tick(delta,0)
		if not alive:
			if is_instance_valid(row.visual):row.visual.queue_free()
			fades.remove_at(index)
	while fades.size()>32:fades.pop_front().visual.queue_free()
	if connections.size()>96:connections=connections.filter(func(row):return is_instance_valid(row[0].get_ref()))
	for id in hidden.keys():
		if not is_instance_valid(hidden[id].source.get_ref()):hidden.erase(id)

func snapshot()->Dictionary:
	return {"objectives":objectives.size(),"hazards":hazards.size(),"wards":wards.size(),"cracks":cracks.size(),"fades":fades.size(),"surfaces":surfaces.size(),"enemies":enemies.size(),"missiles":missiles.size(),"world_seconds":age}
