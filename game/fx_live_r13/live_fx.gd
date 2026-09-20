extends Node3D
## Opt-in art candidate. Reads actual gameplay and collision; changes visuals only.
const SERVICE=preload("res://fx_live_r13/fantasy_effect_lifecycle.gd")
const MAGIC=preload("res://fx_live_r13/live_magic.gd")
const SKIN=preload("res://fx_live_r13/construct_skin.gd")
const CHAIN=preload("res://fx_live_r13/rune_chain.gd")
const PROFILE=preload("res://fx_live_r13/profiles/default.tres")
const SEAL=preload("res://fx_live_r13/seal_visual.gd")
const TINTS={"fire":Color("df8247"),"ice":Color("a3d5dc"),"wind":Color("a8baa0"),"lightning":Color("a7bdcd"),"arcane":Color("9cc3ae"),"blade":Color("c4b491")}
var trial:Node
var service:Node3D
var bolts:Dictionary={}
var surfaces:Dictionary={}
var decoys:Dictionary={}
var finishes:Array[Node3D]=[]
var fades:Array[Node3D]=[]
var connections:Array=[]
var hidden:Dictionary={}
var events:Array[Dictionary]=[]
var chain:Node3D
var charge:Node3D
var seals:Dictionary={}
var seal_fades:Array[Node3D]=[]
var profile:Resource
var world_age:float=0.0
var last_phase:int=-1
var _exiting:bool=false
var generation:int=0
const MAX_PROJECTILES=32
const MAX_CONTACTS=24
const MAX_DISSOLVES=24

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority=100
	profile=PROFILE.duplicate(true)
	service=SERVICE.new();add_child(service)

func attach(manager:Node) -> bool:
	if not is_node_ready() or not is_instance_valid(manager) or not manager.has_method("start_run"):return false
	detach();trial=manager;_exiting=false
	_connect(get_tree(),&"node_added",_added)
	_connect(trial,&"tree_exiting",detach)
	_connect(trial.combat,&"temporal_reset_requested",reset_visuals)
	_connect(trial.combat,&"hit_confirmed",_melee_hit)
	_connect(trial.combat,&"parried",_parried)
	_connect(trial.combat.arts,&"performed",_arts_performed)
	if trial.combat.arts.has_signal("mark_changed"):
		_connect(trial.combat.arts,&"mark_changed",_mark_changed)
		_connect(trial.combat.arts,&"seal_detonated",_seal_detonated)
	if trial.combat.has_signal("chain_launched"):_connect(trial.combat,&"chain_launched",_chain_launched)
	_connect(trial.player.get_node("PositionRewind"),&"rewound",_rewound)
	_connect(trial.player.get_node("PositionRewind"),&"decoy_created",_decoy_created)
	_connect(trial.player.grapple,&"state_changed",_grapple_state)
	_scan()
	return true

func _connect(source:Object,signal_name:StringName,callable:Callable) -> void:
	if source.is_connected(signal_name,callable):return
	source.connect(signal_name,callable)
	connections.append([weakref(source),signal_name,callable])

func _hide(node:Node3D) -> void:
	if not is_instance_valid(node):return
	if not hidden.has(node.get_instance_id()):hidden[node.get_instance_id()]={"node":weakref(node),"visible":node.visible}
	node.hide()

func _restore() -> void:
	for row in hidden.values():
		var node=row.node.get_ref()
		if is_instance_valid(node):node.visible=row.visible
	hidden.clear()

func detach() -> void:
	_exiting=true
	for row in connections:
		var node=row[0].get_ref()
		if is_instance_valid(node) and node.is_connected(row[1],row[2]):node.disconnect(row[1],row[2])
	connections.clear();reset_visuals();trial=null;last_phase=-1

func _exit_tree() -> void:detach()

func reset_visuals() -> void:
	generation+=1
	if is_instance_valid(service):service.reset_all()
	for list in [bolts.values(),surfaces.values()]:
		for row in list:
			if is_instance_valid(row.visual):row.visual.hide();row.visual.queue_free()
	for node in finishes+fades:
		if is_instance_valid(node):node.hide();node.queue_free()
	for node in [chain,charge]:
		if is_instance_valid(node):node.hide();node.queue_free()
	bolts.clear();surfaces.clear();decoys.clear();finishes.clear();fades.clear();chain=null;charge=null
	for row in seals.values():
		if is_instance_valid(row.visual):row.visual.hide();row.visual.queue_free()
	for node in seal_fades:
		if is_instance_valid(node):node.hide();node.queue_free()
	seals.clear();seal_fades.clear()
	_restore()
	_record("reset",{})

func _record(kind:String,data:Dictionary) -> void:
	var row:=data.duplicate();row.kind=kind;row.world_seconds=world_age;events.append(row)
	while events.size()>256:events.pop_front()

func _scan() -> void:
	for group in ["friendly_projectiles","parkour_constructs","echo_steps"]:
		for node in get_tree().get_nodes_in_group(group):_added(node)
	for target in trial.combat.arts.marks:
		if is_instance_valid(target):_mark_changed(target,target.get_hit_point(),true,&"existing")

func _added(node:Node) -> void:
	if _exiting or not is_instance_valid(trial) or int(trial.phase)!=1:return
	if node is MagicBolt and node.friendly and node.owner_combat==trial.combat:
		var id:int=node.get_instance_id()
		if bolts.has(id) or bolts.size()>=MAX_PROJECTILES:return
		bolts[id]={"source":weakref(node),"visual":null,"age":0.0,"contacted":false}
		_connect(node,&"tree_exiting",_bolt_exiting.bind(id))
		_connect(node,&"contacted",_bolt_contact.bind(id))
	elif node is RiftConstruct or node is EchoStep:
		# At node_added, global placement may not yet be assigned. Defer visual construction.
		_surface_added.call_deferred(weakref(node),generation)
	elif node is EchoSlash and node.owner_combat==trial.combat:
		_connect(node,&"sweep_replayed",_echo_sweep)
	elif node is SpellBlast:
		# Frozen gameplay only creates SpellBlast from friendly MagicBolt._explode.
		# Damage has already been resolved there; replace the legacy plain ring visually.
		_hide(node)

func _new_magic(element:String) -> Node3D:
	var fx=MAGIC.new();fx.element=element;fx.tint=TINTS.get(element,TINTS.arcane);fx.configure(profile);add_child(fx)
	return fx

func apply_magic_profile(candidate:Resource) -> bool:
	if not is_instance_valid(profile) or candidate==null or candidate.get_script()!=profile.get_script():return false
	if not candidate.validation_errors().is_empty():return false
	profile=candidate.duplicate(true)
	return true

func _surface_added(ref:WeakRef,requested_generation:int) -> void:
	var node=ref.get_ref()
	if _exiting or not is_instance_valid(trial) or not is_instance_valid(node) or node.is_queued_for_deletion() or surfaces.has(node.get_instance_id()):return
	if requested_generation!=generation or int(trial.phase)!=1:return
	if node is RiftConstruct and node.player!=trial.player:return
	if node is EchoStep and node.owner_player!=trial.player:return
	var skin=SKIN.new();skin.kind=node.kind if node is RiftConstruct else &"platform";skin.dimensions=RiftConstruct.dimensions(node.kind) if node is RiftConstruct else EchoStep.SIZE
	add_child(skin);skin.global_transform=node.global_transform
	if node is EchoStep:skin.rune_material.emission=Color("9586b6")
	surfaces[node.get_instance_id()]={"source":weakref(node),"visual":skin,"collision_layer":node.collision_layer}
	_hide(node)
	_connect(node,&"tree_exiting",_surface_exiting.bind(node.get_instance_id()))
	if node is RiftConstruct:_connect(node,&"expiring",_surface_warning)
	_record("construct",{"id":node.get_instance_id(),"type":str(skin.kind),"dimensions":str(skin.dimensions)})

func _surface_warning(node:Node3D) -> void:
	if surfaces.has(node.get_instance_id()):surfaces[node.get_instance_id()].visual.warning=true;_record("construct_warning",{"id":node.get_instance_id()})

func _surface_exiting(id:int) -> void:
	if not surfaces.has(id):return
	var skin=surfaces[id].visual
	if is_instance_valid(skin):skin.release();fades.append(skin)
	while fades.size()>MAX_DISSOLVES:fades.pop_front().queue_free()
	surfaces.erase(id);hidden.erase(id);_record("construct_removed",{"id":id})

func _bolt_contact(point:Vector3,collider:Node,id:int) -> void:
	if not bolts.has(id):return
	var row:Dictionary=bolts[id];var node=row.source.get_ref();var fx=row.visual
	if row.contacted or not is_instance_valid(node):return
	row.contacted=true
	if not is_instance_valid(fx):fx=_new_magic(str(node.element));fx.set_launch_origin(node.global_position)
	fx.contact(point);finishes.append(fx);row.visual=null
	while finishes.size()>MAX_CONTACTS:finishes.pop_front().queue_free()
	_record("projectile_contact",{"element":str(node.element),"point":str(point),"visual_point":str(fx.contact_point),"collider":str(collider.get_class()) if is_instance_valid(collider) else "removed","collider_id":collider.get_instance_id() if is_instance_valid(collider) else -1})

func _bolt_exiting(id:int) -> void:
	if not bolts.has(id):return
	var row:Dictionary=bolts[id]
	if is_instance_valid(row.visual):row.visual.queue_free()
	if not row.contacted:_record("projectile_expired",{"id":id})
	bolts.erase(id);hidden.erase(id)

func _rewound(origin:Vector3,destination:Vector3,path:PackedVector3Array) -> void:
	if path.size()<2:return
	var id:int=service.create_effect("rewind",Transform3D.IDENTITY)
	var reverse:=path.duplicate();reverse.reverse()
	service.set_history(id,reverse)
	_record("rewound",{"effect":id,"samples":path.size(),"origin":str(origin),"destination":str(destination),"first":str(path[0]),"last":str(path[-1])})

func _decoy_created(node:Node3D) -> void:
	var id:int=service.create_effect("afterimage",node.global_transform,3600.0)
	for row in service.active:
		if row.id!=id:continue
		for i in range(row.node.ghost_roots.size()):
			row.node.echo_origins[i]=Vector3.ZERO
			row.node.ghost_roots[i].visible=i==0
	decoys[node.get_instance_id()]=id
	_connect(node,&"dissipated",_decoy_end.bind(node.get_instance_id()))
	_record("decoy",{"effect":id,"target":node.get_instance_id()})

func _decoy_end(reason:StringName,id:int) -> void:
	if decoys.has(id):service.release_effect(decoys[id]);decoys.erase(id);_record("decoy_dissipated",{"reason":str(reason)})

func _echo_sweep(origin:Vector3,direction:Vector3) -> void:
	var basis:=Basis.looking_at(direction,Vector3.RIGHT if absf(direction.normalized().y)>.95 else Vector3.UP)
	var arms:Node=trial.player.get_node_or_null("FirstPersonArms")
	if is_instance_valid(arms) and arms.has_method("blade_contact_accent"):
		if arms.weapon_effects_enabled:
			var stroke:=preload("res://viewmodel_r16/blade_echo_sweep.gd").new()
			stroke.lifetime=clampf(arms.tuning.blade_trail_lifetime*2.4,.16,.4)
			stroke.width=arms.tuning.blade_ribbon_width;stroke.strength=arms.tuning.trail_strength
			trial.add_child(stroke);stroke.global_transform=Transform3D(basis,origin)
	else:service.create_effect("return_cut",Transform3D(basis,origin))
	_record("echo_sweep",{"origin":str(origin),"direction":str(direction)})

func _melee_hit(_target:Node3D,point:Vector3,defeated:bool) -> void:
	if not is_instance_valid(trial) or trial.player.parkour_profile.id!=&"shade":return
	var arms:Node=trial.player.get_node_or_null("FirstPersonArms")
	if not is_instance_valid(arms) or not arms.has_method("blade_contact_accent"):
		service.create_effect("blood" if defeated else "armor",Transform3D(trial.player.camera.global_basis,point))
	_record("melee_contact",{"point":str(point),"defeated":defeated})

func _parried() -> void:
	var arms:Node=trial.player.get_node_or_null("FirstPersonArms")
	if is_instance_valid(arms) and arms.has_method("blade_contact_accent") and arms.active_kind=="blade":
		var contact:Vector3=arms.sockets.edge_root.global_position.lerp(arms.sockets.edge_tip.global_position,.28)
		arms.blade_contact_accent(null,arms.to_world(contact),false)
	else:
		service.create_effect("parry",Transform3D(trial.player.camera.global_basis,trial.player.camera.global_position-trial.player.camera.global_basis.z*1.2))
	_record("parry",{})

func _arts_performed(kind:StringName) -> void:
	if kind in [&"storm",&"tempest"]:
		service.create_effect("wind",Transform3D(trial.player.global_basis,trial.player.global_position+Vector3.DOWN*.35))
		_record("arts_performed",{"action":str(kind)})

func _mark_changed(target:Node3D,point:Vector3,marked:bool,reason:StringName) -> void:
	if _exiting or not is_instance_valid(trial):return
	var id:int=target.get_instance_id() if is_instance_valid(target) else -1
	if marked:
		if id<0 or seals.has(id) or int(trial.phase)!=1:return
		var visual:=SEAL.new();add_child(visual);visual.global_position=point
		seals[id]={"source":weakref(target),"visual":visual}
		_record("seal_mark",{"target":id,"reason":str(reason),"point":str(point)})
	elif seals.has(id):
		var visual=seals[id].visual;seals.erase(id)
		if is_instance_valid(visual):
			if reason==&"detonated":visual.hide();visual.queue_free()
			else:visual.release();seal_fades.append(visual)
		_record("seal_removed",{"target":id,"reason":str(reason),"point":str(point)})

func _seal_detonated(target:Node3D,point:Vector3) -> void:
	if _exiting or not is_instance_valid(trial) or int(trial.phase)!=1:return
	var visual:=SEAL.new();add_child(visual);visual.global_position=point;visual.age=.2;visual.release(true);seal_fades.append(visual)
	# The authoritative event occurs after spawning the old ring. Replace only
	# that same-frame seal ring; unrelated enemy/terrain effects remain visible.
	for effect in get_tree().get_nodes_in_group("transient_effects"):
		if effect is SkillEffect and effect.style==&"rift" and effect.age==0 and effect.global_position.distance_to(point)<.001 and effect.tint.is_equal_approx(Color("baa5ef")):_hide(effect)
	while seal_fades.size()>MAX_CONTACTS:seal_fades.pop_front().queue_free()
	_record("seal_detonated",{"target":target.get_instance_id() if is_instance_valid(target) else -1,"point":str(point)})

func _chain_launched(origin:Vector3,target:Node3D,bolt:MagicBolt) -> void:
	if _exiting or not is_instance_valid(trial) or int(trial.phase)!=1:return
	_added(bolt)
	if not bolts.has(bolt.get_instance_id()):return
	var row:Dictionary=bolts[bolt.get_instance_id()]
	if not is_instance_valid(row.visual):row.visual=_new_magic("lightning")
	row.visual.set_launch_origin(origin);row.visual.chain_mode=true
	_record("chain_launched",{"origin":str(origin),"target":target.get_instance_id(),"bolt":bolt.get_instance_id()})

func _process(delta:float) -> void:
	if not is_instance_valid(trial):return
	var phase:int=trial.phase
	if phase!=last_phase:
		last_phase=phase
		if phase in [0,3,4]:reset_visuals()
		if phase==1:_scan()
	if phase!=1 or get_tree().paused:return
	world_age+=delta;service.tick(delta)
	if connections.size()>64:connections=connections.filter(func(row):return is_instance_valid(row[0].get_ref()))
	for id in hidden.keys():
		if not is_instance_valid(hidden[id].node.get_ref()):hidden.erase(id)
	for id in bolts.keys():
		var row:Dictionary=bolts[id];var node=row.source.get_ref()
		if not is_instance_valid(node) or row.contacted:continue
		if not is_instance_valid(row.visual):row.visual=_new_magic(str(node.element));row.visual.set_launch_origin(node.global_position)
		_hide(node)
		var point:Vector3=node._visual.global_position if is_instance_valid(node._visual) else node.global_position
		row.visual.flight(point,node.direction,delta)
	for index in range(finishes.size()-1,-1,-1):
		if not is_instance_valid(finishes[index]) or not finishes[index].fade_contact(delta):
			if is_instance_valid(finishes[index]):finishes[index].queue_free()
			finishes.remove_at(index)
	for row in surfaces.values():
		var node=row.source.get_ref()
		if is_instance_valid(node):row.visual.global_transform=node.global_transform;row.visual.tick(delta)
	for id in seals.keys():
		var source=seals[id].source.get_ref()
		var visual=seals[id].visual
		if not is_instance_valid(source) or not is_instance_valid(visual) or not source.is_inside_tree():
			if is_instance_valid(visual):visual.release();seal_fades.append(visual)
			seals.erase(id);continue
		visual.global_position=source.get_hit_point();
		if not visual.tick(delta,trial.player.camera):visual.queue_free();seals.erase(id)
		if trial.combat.arts._icons.has(source):_hide(trial.combat.arts._icons[source])
	for index in range(seal_fades.size()-1,-1,-1):
		if not is_instance_valid(seal_fades[index]) or not seal_fades[index].tick(delta,trial.player.camera):
			if is_instance_valid(seal_fades[index]):seal_fades[index].queue_free()
			seal_fades.remove_at(index)
	for index in range(fades.size()-1,-1,-1):
		if not is_instance_valid(fades[index]) or not fades[index].tick(delta):
			if is_instance_valid(fades[index]):fades[index].queue_free()
			fades.remove_at(index)
	_update_chain(delta);_update_charge()

func _update_chain(delta:float) -> void:
	var grapple=trial.player.grapple
	if grapple.active and is_instance_valid(grapple.anchor):
		_hide(grapple)
		if is_instance_valid(chain) and chain.fading:chain.queue_free();chain=null
		if not is_instance_valid(chain):chain=CHAIN.new();add_child(chain);_record("grapple_started",{})
		var arms=trial.player.get_node("FirstPersonArms")
		chain.update_endpoints(arms.grapple_world_position(),grapple.anchor.global_position,grapple.status())
	elif is_instance_valid(chain) and not chain.fading:chain.release(str(grapple.status().reason))
	if is_instance_valid(chain) and not chain.tick(delta):chain.queue_free();chain=null

func _grapple_state(phase:StringName,reason:StringName) -> void:
	_record("grapple_state",{"phase":str(phase),"reason":str(reason)})
	if phase in [&"detached",&"idle"] and is_instance_valid(chain):chain.release(str(reason))

func _update_charge() -> void:
	var combat=trial.combat;var arms=trial.player.get_node("FirstPersonArms")
	var preparing:bool=trial.player.parkour_profile.id==&"arcanist" and combat.attacking and combat.attack_age<combat.windup
	if preparing:
		if not is_instance_valid(charge):charge=_new_magic(str(combat.spell_element()))
		# Hands render in a separate viewport. Convert the left socket through both cameras.
		var pixel:Vector2=arms.camera.unproject_position(arms.get_hand_socket(&"left").global_position)
		pixel*=Vector2(trial.player.get_viewport().get_visible_rect().size)/Vector2(arms.viewport.size)
		var palm:Vector3=trial.player.camera.project_position(pixel,maxf(.1,-arms.camera.to_local(arms.get_hand_socket(&"left").global_position).z))
		charge.prepare_at(palm,arms.muzzle_world_position(),combat.attack_age,combat.windup)
	elif is_instance_valid(charge):charge.queue_free();charge=null

func snapshot() -> Dictionary:
	return {"bolts":bolts.size(),"surfaces":surfaces.size(),"decoys":decoys.size(),"finishes":finishes.size(),"fades":fades.size(),"effects":service.active.size(),"seals":seals.size(),"seal_fades":seal_fades.size(),"chain":is_instance_valid(chain),"world_age":world_age,"manual_adoption":false}
