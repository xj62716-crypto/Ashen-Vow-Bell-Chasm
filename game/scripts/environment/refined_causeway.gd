class_name RefinedCauseway
extends RefCounted
## Authored route: genuine voids, separated encounters, one overhead zip anchor.

static func build(room: CombatRoom) -> void:
	room.stage_title = "钟渊城垣"
	room._bridge_open = true
	room.spawn.position = Vector3(4.45,.08,6)
	var path: Array[Vector3] = [Vector3(0,0,4),Vector3(0,0,-50),Vector3(-3,2,-70),Vector3(-3,2,-78),Vector3(-3,2,-113),Vector3(-3,2,-157),Vector3(-3,4,-184),Vector3(-3,4,-214),Vector3(4,7,-235),Vector3(4,10,-260),Vector3(-2,12,-286)]
	room.route_nodes = path
	for index in range(path.size()):
		# The grapple exit arrives at the north edge of this landing with
		# authored carry speed. Give the receiving deck enough depth to brake,
		# while keeping the surrounding void and the next wall transfer intact.
		var size := Vector2(10,10)
		if index == 3:
			size = Vector2(18,18)
		elif index == 6:
			size = Vector2(22,20)
		elif index == 5:
			size = Vector2(18,24)
		elif index == 10:
			size = Vector2(18,16)
		elif index == 8 or index == 9:
			size = Vector2(12,12)
		elif index == 7:
			size = Vector2(18,12)
		room._platform(path[index],size)
		CitadelExpansion._foundation(room,path[index],size)
	# Entry edge -1 to landing edge -45: 44 m of empty air. Both base classes
	# must spend two wall segments and the intervening air dash on the same face.
	room._wall(Vector3(5.4,4,-22),Vector3(.8,12,50))
	room.signature_sections[&"same_wall_chain"]={
		"start":Vector3(4.45,.08,.1),"landing":Vector3(0,.08,-50),
		"wall_plane_x":5.0,"void_m":44.0,
		"mechanics":[&"wall_run",&"air_dash",&"same_wall_reattach"]}
	# Transfer between opposed faces. Looking away from a latched wall is allowed.
	room._wall(Vector3(5.4,4,-51),Vector3(.8,10,10))
	room._wall(Vector3(.4,5,-62),Vector3(.8,10,24))
	room._route_marker(Vector3(4.4,.08,.8),Color("#b49c71"),&"wall")
	# Combat begins only after the transfer's safe landing.
	room._wall(Vector3(-3,3.8,-79),Vector3(2,3.6,2))
	room._extra_altar(Vector3(-9,2,-71))
	# A vaulted service duct asks for a slide; the following gap rewards a slide jump.
	room._platform(Vector3(-3,2,-94),Vector2(5,14))
	room._wall(Vector3(-6,4,-94),Vector3(1,5,14))
	room._wall(Vector3(0,4,-94),Vector3(1,5,14))
	DemoGeometry.box(room.geometry,Vector3(-3,3.95,-93),Vector3(5,1.6,8),room._stone,true)
	room._route_marker(Vector3(-3,2.08,-88),Color("#b49c71"),&"slide")
	# The anchor hangs above the middle, not above the destination.
	var anchor := RiftConstruct.new()
	anchor.kind = &"anchor"
	anchor.permanent = true
	anchor.grapple_exit_speed = 18.0
	anchor.grapple_exit_lift = 3.5
	room.geometry.add_child(anchor)
	anchor.position = Vector3(-3,18,-132)
	room.static_anchors.append(anchor)
	DemoGeometry.box(room.geometry,Vector3(-3,20,-132),Vector3(27,.8,1),room._iron)
	CitadelDressing.asset(room.geometry,"hanging_chain",Vector3(-3,18,-132),Vector3(.7,.7,.7))
	# Final broken cloister: alternate wall traversal into the guardian court.
	room._wall(Vector3(-10.4,6,-169),Vector3(.8,12,26))
	room._wall(Vector3(-3,6,-182),Vector3(2,4,3))
	room._extra_altar(Vector3(2,2,-159))
	# The final approach climbs through three separated decks. Each anchor is
	# aimed at the next wall plane, making the vertical route a grapple ->
	# release -> wall-run handoff instead of a decorative shortcut.
	room._wall(Vector3(5.4,8,-220),Vector3(.8,14,32))
	room._wall(Vector3(-5.0,10,-248),Vector3(.8,18,24))
	room._wall(Vector3(6.0,12,-279),Vector3(.8,20,26))
	var upper_anchor := RiftConstruct.new()
	upper_anchor.kind = &"anchor"
	upper_anchor.permanent = true
	upper_anchor.grapple_exit_speed = 19.0
	upper_anchor.grapple_exit_lift = 5.0
	upper_anchor.set_meta("followup_wall", {"normal": Vector3(-1,0,0), "point": Vector3(4.55,7.0,-232.0)})
	room.geometry.add_child(upper_anchor)
	upper_anchor.position = Vector3(5.0,16.0,-224.0)
	room.static_anchors.append(upper_anchor)
	CitadelDressing.asset(room.geometry,"hanging_chain",upper_anchor.position,Vector3(.7,.7,.7))
	var transfer_anchor := RiftConstruct.new()
	transfer_anchor.kind = &"anchor"
	transfer_anchor.permanent = true
	transfer_anchor.grapple_exit_speed = 18.0
	transfer_anchor.grapple_exit_lift = 5.5
	transfer_anchor.set_meta("followup_wall", {"normal": Vector3(1,0,0), "point": Vector3(-4.55,10.0,-257.0)})
	room.geometry.add_child(transfer_anchor)
	transfer_anchor.position = Vector3(-5.0,19.0,-252.0)
	room.static_anchors.append(transfer_anchor)
	CitadelDressing.asset(room.geometry,"hanging_chain",transfer_anchor.position,Vector3(.7,.7,.7))
	room.signature_sections[&"vertical_anchor_chain"]={
		"start":Vector3(-3,4,-204),"upper_deck":Vector3(4,7,-235),
		"transfer_deck":Vector3(4,10,-260),"boss_approach":Vector3(-2,12,-286),
		"mechanics":[&"grapple_to_wall","wall_run","wall_kick","air_dash"]}
	room._route_marker(Vector3(-3,4.08,-207),Color("#75c5de"),&"air")
	room._route_marker(Vector3(4.4,7.08,-232),Color("#dd987d"),&"wall")
	room._route_marker(Vector3(-4.4,10.08,-257),Color("#dd987d"),&"wall")
	room._enemy(Vector3(4,7.04,-233),&"normal",&"crossbow")
	room._enemy(Vector3(-4,10.04,-258),&"elite",&"pursuer")
	room._enemy(Vector3(-2,12.04,-284),&"normal",&"caster")
	# Visible bonus ledge: reachable using acquired shaping/enemy-node abilities.
	var secret := Vector3(16,7,-80)
	room._platform(secret,Vector2(7,8))
	CitadelExpansion._foundation(room,secret,Vector2(7,8))
	room.branch_nodes = [secret]
	room.shape_landings = [secret]
	CitadelExpansion._return_hint(room,secret,Vector3(1,2,-77))
	room._extra_altar(secret+Vector3(1,0,-2))
	CitadelExpansion._device(room,Vector3(-8,3,-84),&"breakable")
	CitadelExpansion._device(room,Vector3(1,3,-155),&"pulse")
	room._exit(Vector3(-2,12,-300))
	for p: Vector3 in [Vector3(-10,2,-86),Vector3(4,4,-188)]:
		CitadelDressing.asset(room.geometry,"gothic_statue",p,Vector3(1.3,1.3,1.3))
	CitadelDressing.asset(room.geometry,"large_castle_door",Vector3(-2,12,-302),Vector3(2.2,2.2,2.2))
	# Surrounding architecture has no collision: it cannot bridge the authored gaps.
	CitadelExpansion._city(room,path[0],path[-1])
	# West now opens onto the chosen D01-D05 city composition, rather than a
	# repeated curtain of old bay modules concealing those authored assets.
	for side: float in [1]:
		for i in range(16):
			var z: float = 7-i*13
			CitadelDressing.asset(room.geometry,"gothic_bay",Vector3(side*19,-5,z),Vector3(2,3,1.5),PI/2)
			if i%3==0:
				CitadelDressing.asset(room.geometry,"citadel_bastion",Vector3(side*29,-28,z),Vector3(1.5,2,1.5))
				CitadelDressing.asset(room.geometry,"hanging_standard",Vector3(side*17,7,z),Vector3(1.6,1.6,1.6),side*PI/2)
	for p: Vector3 in [Vector3(-3,0,6),Vector3(-3,0,-26),Vector3(-7,2,-67),Vector3(2,2,-76),Vector3(-6,2,-111),Vector3(2,2,-150),Vector3(-11,4,-188),Vector3(4,7,-235),Vector3(-2,12,-286)]:
		CitadelDressing.brazier(room.geometry,p)
