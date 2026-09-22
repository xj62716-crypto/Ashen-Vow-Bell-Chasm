class_name CitadelExpansion
extends RefCounted

static func build(room: CombatRoom) -> void:
	var stage: int=room.stage
	var height: float=[0.0,3.0,1.0][stage-1]
	var z: float=[-72.0,-65.0,-68.0][stage-1]
	var hub := Vector3(0,height,z)
	var main: Array[Vector3]=[]
	match stage:
		1:main=[hub,hub+Vector3(-21,2,-33),hub+Vector3(-27,4,-67),hub+Vector3(4,6,-102),hub+Vector3(20,7,-138),hub+Vector3(0,5,-176)]
		2:main=[hub,hub+Vector3(22,1,-30),hub+Vector3(28,5,-65),hub+Vector3(-3,8,-101),hub+Vector3(-19,11,-139),hub+Vector3(0,8,-180)]
		3:main=[hub,hub+Vector3(-23,3,-31),hub+Vector3(-26,6,-67),hub+Vector3(0,10,-102),hub+Vector3(26,13,-140),hub+Vector3(13,11,-176),hub+Vector3(0,9,-211)]
	room.route_nodes=main
	# Register destinations before linking; using a fallback extent put ramps
	# inside the next platform and left a vertical lip at elevated arrivals.
	for i in range(main.size()):
		room.platform_extents[main[i]]=Vector2(28,24) if i==main.size()-1 else (Vector2(22,20) if i==0 else Vector2(16,18))
	# The earlier small arena is now the entrance quarter of the domain.
	var entry := Vector3(0,height,[-44.0,-32.0,-39.0][stage-1])
	if stage==3:_wall_link(room,entry,hub)
	else:_link(room,entry,hub,false)
	for i in range(main.size()):
		var point: Vector3=main[i]
		var size := Vector2(28,24) if i==main.size()-1 else (Vector2(22,20) if i==0 else Vector2(16,18))
		room._platform(point,size)
		_foundation(room,point,size)
		if i>0:_link(room,main[i-1],point,i!=1)
		# The hub's outside route exits east in the tower, west in the forge.
		# Keep its framing wall on the opposite flank, clear of the ramp.
		var flank := Vector3(-9 if i==0 and stage==3 else (9 if i%2==0 else -9),3.4,0)
		room._wall(point+flank,Vector3(.65,7,8))
		if i in [0,2] or i==main.size()-1:CitadelDressing.asset(room.geometry,"gothic_bay",point+Vector3(0,0,-7),Vector3(1.6,1.6,1))
		CitadelDressing.brazier(room.geometry,point+Vector3(-4,0,3))
		# Main platforms are traversal beats. Only the middle of a route is an
		# encounter; the entry/exit platforms stay readable for wall-run planning.
		if i>0 and i<main.size()-1:
			# Interrupt distant firing lines while keeping both flanks passable.
			room._wall(point+Vector3(5.5,1.8,0),Vector3(1.1,3.6,4.5))
	room._extra_altar(hub+Vector3(-5,0,-3))
	room._extra_altar(main[2]+Vector3(-3,0,3))
	# Wide outer route: an optional exploration circuit reconnects at the arena.
	var side: float=-1.0 if stage==2 else 1.0
	var outer_width: float=49.0 if stage==3 else 39.0
	var return_width: float=35.0 if stage==3 else 25.0
	var branch: Array[Vector3]=[hub+Vector3(side*25,2,-7),hub+Vector3(side*outer_width,5,-55),hub+Vector3(side*outer_width,9,-107),main[-1]+Vector3(side*return_width,4,20)]
	room.branch_nodes=branch
	for point in branch:room.platform_extents[point]=Vector2(8,9)
	_link(room,hub,branch[0],true)
	for i in range(branch.size()):
		room._platform(branch[i],Vector2(8,9))
		_foundation(room,branch[i],Vector2(8,9))
		if i>0:_link(room,branch[i-1],branch[i],true)
		room._wall(branch[i]+Vector3(side*4.5,3,0),Vector3(.6,6.5,6))
		# The outer loop is an exploration reward, not a second combat corridor.
	# After the outer loop's traversal tests, a continuous return ramp gives a
	# reliable recovery route into the arena without requiring another upgrade.
	_link(room,branch[-1],main[-1],false)
	room._extra_altar(branch[2]+Vector3(2,0,2))
	# A true isolated landing rewards creating a wall or using a guard as a node.
	var secret := main[2]+Vector3(-side*21,4,-5)
	room._platform(secret,Vector2(7,7))
	_foundation(room,secret,Vector2(7,7))
	room._extra_altar(secret+Vector3(-2,0,-2))
	room.shape_landings.append(secret)
	# A lower receiving ledge clears the flank wall and does not require a
	# living enemy or temporary construct. Its 4m rise still gates the reverse
	# trip: reaching the secret remains an optional build/mobility challenge.
	var return_landing := main[2]+Vector3(-side*11,0,-7)
	room._platform(return_landing,Vector2(6,4))
	_foundation(room,return_landing,Vector2(6,4))
	_return_hint(room,secret,return_landing)
	CitadelDressing.asset(room.geometry,"seal_obelisk",secret+Vector3(2,0,-2),Vector3(.5,.7,.5))
	# Permanent grappling anchors join exploration loops for either profession.
	for index in [0,2]:
		var approach := ((branch[index]-(hub if index==0 else branch[index-1]))*Vector3(1,0,1)).normalized()
		# Short-pull anchors sit over the arrival edge with an open centre line.
		# A low exit cap leaves braking room on the existing 8 x 9 m platform.
		var point := branch[index]-approach*1.4+Vector3.UP*2.3
		var anchor := RiftConstruct.new()
		anchor.kind=&"anchor"
		anchor.grapple_exit_speed=12.0
		anchor.grapple_exit_lift=1.5
		# These branch anchors sit just beyond a narrow receiving edge. Release
		# into the pad's approach lane, with enough separation to keep the anchor
		# readable without making the player overshoot the next platform.
		anchor.grapple_release_distance=4.5
		anchor.permanent=true
		room.geometry.add_child(anchor)
		anchor.position=point
		room.static_anchors.append(anchor)
	var lift := AnimatableBody3D.new()
	lift.sync_to_physics=false
	room.geometry.add_child(lift)
	lift.position=main[1]+Vector3(4.0,-.145,0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(5,.45,5)
	collision.shape=shape
	lift.add_child(collision)
	DemoGeometry.box(lift,Vector3.ZERO,shape.size,room._iron)
	# Ride control plus call stones on both landings: missing a departure never
	# strands the player. The upper balcony is optional; the main route stays open.
	var device := _device(room,lift.position+Vector3(-1.6,1.3,1.6),&"lift")
	device.reparent(lift,true)
	device.moving_body=lift
	device.start_point=lift.position
	device.finish_point=lift.position+Vector3.UP*5
	var balcony := main[1]+Vector3(4,5.08,-5)
	room._platform(balcony,Vector2(5,5))
	var lower_call := _device(room,main[1]+Vector3(.7,1,0),&"lift")
	lower_call.linked_device=device
	var upper_call := _device(room,balcony+Vector3(0,1,0),&"lift")
	upper_call.linked_device=device
	_device(room,main[2]+Vector3(3,1,3),&"breakable")
	_device(room,main[1]+Vector3(-4,1,-3),&"pulse")
	_device(room,branch[1]+Vector3(2,1,2),&"vent")
	# Final guardian positions now live in the encounter Resource. They are
	# still assigned before _ready, so AI records its final-district home.
	var seal_index: int=0
	for mechanism in room.mechanisms:
		if mechanism.kind==&"seal":
			mechanism.position=main[-1]+Vector3(-7 if seal_index==0 else 7,1.1,4)
			seal_index+=1
	room.exit_area.queue_free()
	room._gate.queue_free()
	room._exit_title.queue_free()
	room._exit(main[-1]+Vector3(0,0,-7))
	_city(room,hub,main[-1])

static func _wall_link(room: CombatRoom,a: Vector3,b: Vector3) -> void:
	# The archive roof ends at the takeoff edge. A rune-bound wall occupies the
	# exposed void; there is deliberately no deck beneath it.
	var direction:=((b-a)*Vector3(1,0,1)).normalized()
	var a_size:Vector2=room.platform_extents.get(a,Vector2(8,8))
	var b_size:Vector2=room.platform_extents.get(b,Vector2(8,8))
	var from_edge:=minf(a_size.x*.5/maxf(.001,absf(direction.x)),a_size.y*.5/maxf(.001,absf(direction.z)))
	var to_edge:=minf(b_size.x*.5/maxf(.001,absf(direction.x)),b_size.y*.5/maxf(.001,absf(direction.z)))
	var takeoff:=a+direction*from_edge
	var landing:=b-direction*to_edge
	var gap:=landing-takeoff
	var basis:=Basis.looking_at(gap.normalized())
	var wall_center:=takeoff.lerp(landing,.5)+basis.x*.72+Vector3.UP*3.4
	var wall:=DemoGeometry.box(room.geometry,wall_center,Vector3(.46,7.2,gap.length()+1.2),room._stone,true)
	wall.basis=basis
	wall.add_to_group("floating_route_surface")
	for fraction:float in [.18,.5,.82]:
		var rune:=DemoGeometry.box(wall,Vector3(0,0,(fraction-.5)*gap.length()),Vector3(.025,5.4,.12),room._accent)
		rune.set_meta("interactive_visual",true)
	room.route_links.append({"from":a,"to":b,"gap":true,"segments":[takeoff,takeoff,landing,landing],"mechanic":&"wall_run"})

static func _link(room: CombatRoom,a: Vector3,b: Vector3,gap: bool) -> void:
	# Long routes get reachable stepping stations, not proportionally wider gaps.
	if a.distance_to(b)>39:
		var middle := a.lerp(b,.5)
		room._platform(middle,Vector2(12,12))
		_foundation(room,middle,Vector2(12,12))
		_link(room,a,middle,false)
		_link(room,middle,b,gap)
		return
	# Meet platform edges at their exact floor heights. A ramp from centre to
	# centre leaves an invisible vertical curb at every elevated arrival.
	var from_center := a
	var to_center := b
	var flat := ((b-a)*Vector3(1,0,1)).normalized()
	var a_size: Vector2=room.platform_extents.get(a,Vector2(8,8))
	var b_size: Vector2=room.platform_extents.get(b,Vector2(8,8))
	var from_edge: float=minf(a_size.x*.5/maxf(.001,absf(flat.x)),a_size.y*.5/maxf(.001,absf(flat.z)))
	var to_edge: float=minf(b_size.x*.5/maxf(.001,absf(flat.x)),b_size.y*.5/maxf(.001,absf(flat.z)))
	var distance: float=Vector2(b.x-a.x,b.z-a.z).length()
	if from_edge+to_edge>distance-1:
		from_edge=minf(from_edge,distance*.35)
		to_edge=minf(to_edge,distance*.35)
	a+=flat*from_edge
	b-=flat*to_edge
	var direction := b-a
	var length: float=direction.length()
	var basis := Basis.looking_at(direction.normalized())
	# Continuous narrow ramps provide a baseline; broken paired ramps reward
	# jump/dash and leave actual space for a player-created wall.
	var segments: Array[Vector3]=[a,b]
	if gap:
		# Reserve enough solid run-up for elevation changes. A fixed 32% void
		# made short descending links steeper than the player's floor angle.
		var flat_length := Vector2(direction.x,direction.z).length()
		var gap_width := minf(flat_length*.32,maxf(0.0,flat_length-absf(direction.y)/.65))
		var gap_fraction := gap_width/maxf(.001,flat_length)
		if gap_width<2.0:
			# A centimetre-wide crack at a steep ridge is not a readable jump.
			gap=false
		else:
			var takeoff := a.lerp(b,(1.0-gap_fraction)*.5)
			var landing := a.lerp(b,(1.0+gap_fraction)*.5)
			# Spend the elevation gain on solid ramps; jump across a level opening.
			takeoff.y=(a.y+b.y)*.5
			landing.y=takeoff.y
			segments=[a,takeoff,landing,b]
	room.route_links.append({"from":from_center,"to":to_center,"gap":gap,"segments":segments.duplicate()})
	for index in range(0,segments.size(),2):
		var start: Vector3=segments[index]
		var finish: Vector3=segments[index+1]
		var deck_basis := Basis.looking_at((finish-start).normalized())
		var center := start.lerp(finish,.5)-deck_basis.y*.225
		var span: float=start.distance_to(finish)
		var deck := DemoGeometry.box(room.geometry,center,Vector3(3.2,.45,span),room._floor,true)
		deck.basis=deck_basis
		DemoGeometry.box(deck,Vector3(0,-.38,0),Vector3(.35,.55,span),room._iron)
		for side: float in [-1,1]:
			DemoGeometry.box(deck,Vector3(side*1.55,.235,0),Vector3(.045,.04,span),room._accent)
	if gap:
		var point := a.lerp(b,.5)+basis.x*2.1+Vector3.UP*2
		var wall := DemoGeometry.box(room.geometry,point,Vector3(.45,5,length*.65),room._stone,true)
		wall.basis=Basis.looking_at(Vector3(direction.x,0,direction.z).normalized())

static func _foundation(room: CombatRoom,p: Vector3,size: Vector2) -> void:
	var foundation:=DemoGeometry.box(room.geometry,p-Vector3.UP*7,Vector3(size.x-1,13,size.y-1),room._stone)
	foundation.add_to_group("structural_foundation")
	foundation.set_meta("platform_center",p)
	foundation.set_meta("platform_size",size)
	for side: float in [-1,1]:
		CitadelDressing.asset(room.geometry,"gothic_bay",p+Vector3(side*(size.x/2-.8),-13,0),Vector3(1.5,2,1),PI/2)

static func _return_hint(room: CombatRoom,secret: Vector3,destination: Vector3) -> void:
	room.return_landings.append(destination)
	var direction := ((destination-secret)*Vector3(1,0,1)).normalized()
	var facing := Basis.looking_at(direction)
	var surface := DemoGeometry.material(Color("#b49c71"),.7)
	for i in range(3):
		var marker := DemoGeometry.box(room.geometry,secret+direction*(1.8+i*.38)+Vector3.UP*.06,Vector3(.55,.025,.08),surface)
		marker.basis=facing
	DemoGeometry.label(room.geometry,secret+direction*2+Vector3.UP*.65,"跃向下层 · 返回主路",20)

static func _device(room: CombatRoom,p: Vector3,kind: StringName) -> TerrainDevice:
	var device := TerrainDevice.new()
	device.kind=kind
	device.tuning=room._configuration.mechanisms
	room.geometry.add_child(device)
	device.position=p
	device.activated.connect(func():room.mechanism_used.emit())
	room.terrain_devices.append(device)
	return device

static func _city(room: CombatRoom,hub: Vector3,end: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=room.stage*417
	for side: float in [-1,1]:
		for row in range(3):
			for i in range(13):
				var h: float=rng.randf_range(14,38)
				var p := Vector3(side*(55+row*19+rng.randf_range(-3,3)),-24,12-i*25)
				CitadelDressing.asset(room.geometry,"skyline_house",p,Vector3(rng.randf_range(.8,1.3),h/20,rng.randf_range(.9,1.3)),PI/2 if i%3==0 else 0)
	for side: float in [-1,1]:
		for i in range(7):
			var p := Vector3(side*49,-12,hub.z+10-i*28)
			CitadelDressing.asset(room.geometry,"citadel_bastion",p,Vector3(1.3,1.45+(i%3)*.18,1.3))
			if i%2==0:CitadelDressing.asset(room.geometry,"hanging_standard",p+Vector3(-side*3,17,0),Vector3(2,2,2),side*PI/2)
		DemoGeometry.box(room.geometry,Vector3(side*49,-8,(hub.z+end.z)*.5),Vector3(5,6,absf(hub.z-end.z)+30),room._stone)
	# Visible lower city, deliberately below the fall limit; gaps remain lethal.
	DemoGeometry.box(room.geometry,Vector3(0,-25,-130),Vector3(225,3,330),room._floor)
	if room.stage==2:
		var melt := ShaderMaterial.new()
		melt.shader=preload("res://assets/shaders/forge_melt.gdshader")
		DemoGeometry.box(room.geometry,Vector3(0,-18,(hub.z+end.z)*.5),Vector3(88,.3,220),melt)
		for side: float in [-1,1]:
			for i in range(4):CitadelDressing.asset(room.geometry,"furnace_stack",Vector3(side*37,-7,hub.z-i*25),Vector3(1.4,1.8,1.4))
