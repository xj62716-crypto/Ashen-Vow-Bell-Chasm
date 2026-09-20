class_name RefinedCauseway
extends RefCounted
## Authored route: genuine voids, separated encounters, one overhead swing anchor.

static func build(room: CombatRoom) -> void:
	room.stage_title = "钟渊城垣"
	room._bridge_open = true
	room.spawn.position = Vector3(4.45,.08,6)
	var path: Array[Vector3] = [Vector3(0,0,4),Vector3(0,0,-50),Vector3(-3,2,-70),Vector3(-3,2,-78),Vector3(-3,2,-113),Vector3(-3,2,-157),Vector3(-3,4,-184)]
	room.route_nodes = path
	for index in range(path.size()):
		var size := Vector2(18,18) if index==3 else (Vector2(22,20) if index==6 else (Vector2(14,14) if index==5 else Vector2(10,10)))
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
	room.geometry.add_child(anchor)
	anchor.position = Vector3(-3,18,-132)
	room.static_anchors.append(anchor)
	DemoGeometry.box(room.geometry,Vector3(-3,20,-132),Vector3(27,.8,1),room._iron)
	CitadelDressing.asset(room.geometry,"hanging_chain",Vector3(-3,18,-132),Vector3(.7,.7,.7))
	# Final broken cloister: alternate wall traversal into the guardian court.
	room._wall(Vector3(-10.4,6,-169),Vector3(.8,12,26))
	room._wall(Vector3(-3,6,-182),Vector3(2,4,3))
	room._extra_altar(Vector3(2,2,-159))
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
	room._exit(Vector3(-3,4,-192))
	for p: Vector3 in [Vector3(-10,2,-86),Vector3(4,4,-188)]:
		CitadelDressing.asset(room.geometry,"gothic_statue",p,Vector3(1.3,1.3,1.3))
	CitadelDressing.asset(room.geometry,"large_castle_door",Vector3(-3,4,-194),Vector3(2,2,2))
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
	for p: Vector3 in [Vector3(-3,0,6),Vector3(-3,0,-26),Vector3(-7,2,-67),Vector3(2,2,-76),Vector3(-6,2,-111),Vector3(2,2,-150),Vector3(-11,4,-188)]:
		CitadelDressing.brazier(room.geometry,p)
