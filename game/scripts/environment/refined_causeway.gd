class_name RefinedCauseway
extends RefCounted
## Authored route: genuine voids, separated encounters, one overhead zip anchor.

static func build(room: CombatRoom) -> void:
	room.stage_title = "钟渊城垣"
	room._bridge_open = true
	room.spawn.position = Vector3(4.52,.08,6)
	var path: Array[Vector3] = [Vector3(0,0,4),Vector3(0,0,-50),Vector3(-3,1.2,-70),Vector3(-3,1.2,-78),Vector3(-3,2,-113),Vector3(-3,2,-157),Vector3(-3,4,-184),Vector3(-3,4,-214),Vector3(4,7,-235),Vector3(4,10,-260),Vector3(-2,12,-286)]
	room.route_nodes = path
	for index in range(path.size()):
		# The grapple exit arrives at the north edge of this landing with
		# authored carry speed. Give the receiving deck enough depth to brake,
		# while keeping the surrounding void and the next wall transfer intact.
		var size := Vector2(10,10)
		if index == 1:
			# Short receiving deck: enough room to brake after the wall kick, while
			# preserving the visible void on both sides and the next wall decision.
			# The wall ends one metre before the original front bevel. The capsule
			# descends slightly while carrying the second wall segment, so the
			# receiving stone needs a real two-metre overlap to catch the feet rather
			# than leaving a visually plausible but physically empty seam.
			size = Vector2(10,16)
		elif index == 2:
			# The first elevated recovery is approached from the right-hand wall;
			# give the real landing volume enough lateral room for a grapple exit.
			# It also has to meet the north edge of the present-world deck: after an
			# airborne timeline shift the runner must see one continuous receiving
			# highline instead of a four-metre unowned gap before the first remnant
			# landing.
			# The first elevated receiver stays a compact landing. The east-side
			# wall kick must be corrected toward its centre instead of being caught
			# by a filled-in floor shortcut.
			size = Vector2(10,12)
		elif index == 3:
			size = Vector2(18,18)
		elif index == 6:
			# Leave a one-metre air-step before the lower guardian apron. The
			# previous north edge at z=-174 caught the wall runner on its vertical
			# face before the authored landing threshold.
			size = Vector2(22,18)
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
	# The first wall begins at the departure deck instead of three metres beyond
	# its edge. This makes a straight run followed by a jump visibly capture the
	# wall; holding right from spawn would otherwise slip around the north cap
	# before the wall exists in the route.
	# Entry edge 7 to landing edge -45: 38 m of empty air. Both base classes
	# must spend two wall segments and the intervening air dash on the same face.
	# Overlap the spawn deck by a metre so a player who jumps while steering
	# toward the face cannot slip around the north cap before the wall probe
	# gets a physics frame to capture it. Keep the south edge at z=-45, where
	# the authored receiving deck and air-dash handoff remain unchanged.
	# The first traversal face is a suspended wall, not a ground extension.
	# Its one-metre lower gap makes the jump into the wall readable and keeps
	# the deck below from becoming a walkable substitute for the void.
	# The foot-level contact probe descends about a metre during two wall runs.
	# Keep the suspended face below that probe without adding any floor to the void.
	room._wall(Vector3(5.4,3.4,-19),Vector3(.8,9.2,52))
	# The wall exits while the capsule is already descending. A short visible
	# masonry lip carries that descent onto the real receiving deck; without it,
	# the deck's north face catches the capsule below its top and reads as an
	# invisible blocker even though both objects are individually visible.
	var first_receive_ramp := DemoGeometry.box(room.geometry,Vector3(0,-.40,-43.5),Vector3(9.4,.45,4.2),room._floor,true)
	first_receive_ramp.set_meta("route_connector",true)
	room.signature_sections[&"same_wall_chain"]={
		"start":Vector3(4.52,.08,5.0),"landing":Vector3(0,.08,-50),
		"wall_plane_x":5.0,"void_m":40.0,
		"mechanics":[&"wall_run",&"air_dash",&"same_wall_reattach"]}
	# Transfer between opposed faces. Looking away from a latched wall is allowed.
	# The short follow-up face starts from the real receiving deck. Its lower
	# edge must sit inside a normal jump's probe band; the old 1.5 m sill made
	# the wall visually present but unreachable from the landing.
	room._wall(Vector3(5.4,4.0,-51),Vector3(.8,8,10))
	room._wall(Vector3(.4,5.5,-62),Vector3(.8,7,24))
	# The remnant line adds a real high-side transfer at the first timeline
	# teaching beat. It is a separate collision surface, not a recoloured copy
	# of the present wall, and is enabled only while the player is in the
	# remnant. The low route remains available as the recovery line.
	var remnant_wall := DemoGeometry.box(room.geometry,Vector3(-4.8,5.2,-62),Vector3(.7,8.4,16),DemoGeometry.material(Color("#433855"),.35),true)
	remnant_wall.set_meta("timeline_phase",&"remnant")
	for z: float in [-68.0,-64.0,-60.0,-56.0]:
		DemoGeometry.box(remnant_wall,Vector3(0.38,1.1,z+62.0),Vector3(.08,1.4,.22),DemoGeometry.material(Color("#9a6fc2"),1.4))
	# The phase crossing needs a real first receiver before the elevated remnant
	# deck. Its top is reachable by the base jump from the present-world floor;
	# the higher deck remains the next earned transfer instead of becoming an
	# impossible two-metre underside that lets the runner fall through the seam.
	# The first remnant receiver is a low suspended slab. Its 0.65 m deck keeps
	# the four-metre void visible while landing inside the base jump envelope;
	# the raised -78 deck remains the earned second transfer.
	var remnant_receiver := room._platform(Vector3(-3,0.65,-65),Vector2(10,10))
	remnant_receiver.set_meta("timeline_phase",&"remnant")
	remnant_receiver.set_meta("timeline_contract",&"causeway_airborne_handoff")
	remnant_receiver.set_meta("route_platform_center",Vector3(-3,0.65,-65))
	remnant_receiver.set_meta("route_platform_size",Vector2(10,10))
	# The next remnant deck overlaps this receiver by one metre but stands 0.55 m
	# higher. Bridge only that shared stone footprint so its vertical edge does
	# not stop the runner after a successful airborne phase handoff.
	var ramp_start := Vector3(-3,0.65,-65.5)
	var ramp_end := Vector3(-3,1.2,-68.25)
	var ramp_direction := ramp_end-ramp_start
	var remnant_step := DemoGeometry.box(room.geometry,ramp_start.lerp(ramp_end,.5)-Basis.looking_at(ramp_direction.normalized()).y*.225,Vector3(10,.45,ramp_direction.length()),room._floor,true)
	remnant_step.basis = Basis.looking_at(ramp_direction.normalized())
	remnant_step.set_meta("timeline_phase",&"remnant")
	remnant_step.set_meta("timeline_contract",&"causeway_airborne_handoff")
	remnant_step.set_meta("timeline_authored",true)
	remnant_step.set_meta("route_connector",true)
	var remnant_lip := DemoGeometry.box(room.geometry,Vector3(-3,0.975,-69.75),Vector3(10,.45,3.0),room._floor,true)
	remnant_lip.set_meta("timeline_phase",&"remnant")
	remnant_lip.set_meta("timeline_contract",&"causeway_airborne_handoff")
	remnant_lip.set_meta("timeline_authored",true)
	remnant_lip.set_meta("route_connector",true)
	room._route_marker(Vector3(4.4,.08,.8),Color("#b49c71"),&"wall")
	# Combat begins only after the transfer's safe landing.
	var remnant_slide_lintel := DemoGeometry.box(room.geometry,Vector3(-3,4.2,-79),Vector3(2,3.6,2),room._stone,true)
	remnant_slide_lintel.set_meta("timeline_phase",&"remnant")
	remnant_slide_lintel.set_meta("timeline_authored",true)
	# Keep the checkpoint on the real first high landing.  The former x=-9
	# coordinate sat beyond the ten-metre deck edge and left a visible altar
	# over the void after the route was widened.
	room._extra_altar(Vector3(0,1.2,-72))
	# A vaulted service duct asks for a slide; the following gap rewards a slide jump.
	# Keep the authored low-vault start point one capsule radius inside the
	# landing instead of exactly on its north bevel. The void and slide gate stay
	# unchanged; the extra two metres only provide a stable real floor at entry.
	var low_vault := room._platform(Vector3(-3,2,-94),Vector2(5,16))
	# This service landing is a present-world teaching deck, not a nearest-node
	# phase candidate. Locking its real collision prevents the timeline builder
	# from turning it into a visible-but-empty floor during the present pass.
	low_vault.set_meta("timeline_phase", &"present")
	low_vault.set_meta("timeline_contract", &"causeway_low_vault")
	CitadelExpansion._foundation(room,Vector3(-3,2,-94),Vector2(5,16))
	var low_vault_support := room.platform_at(Vector3(-3,2,-94))
	if low_vault_support != null:
		low_vault_support.set_meta("timeline_phase", &"present")
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
	# The wall exits onto a lower service apron before the raised guardian court.
	# It is a real, supported landing so the wall-run can finish at the authored
	# height; the next jump/route then climbs to the court platform.
	var guardian_apron := room._platform(Vector3(-3,2,-175.5),Vector2(14,6))
	guardian_apron.set_meta("timeline_phase", &"present")
	guardian_apron.set_meta("timeline_contract", &"causeway_guardian_approach")
	CitadelExpansion._foundation(room,Vector3(-3,2,-175.5),Vector2(14,6))
	var court_ramp_start := Vector3(-3,2,-170)
	var court_ramp_end := Vector3(-3,4,-174.3)
	var court_ramp_direction := court_ramp_end-court_ramp_start
	var court_ramp_basis := Basis.looking_at(court_ramp_direction.normalized())
	var court_ramp := DemoGeometry.box(room.geometry,court_ramp_start.lerp(court_ramp_end,.5)-court_ramp_basis.y*.225,Vector3(5.5,.45,court_ramp_direction.length()),room._floor,true)
	court_ramp.basis = court_ramp_basis
	court_ramp.set_meta("timeline_phase",&"present")
	court_ramp.set_meta("route_connector",true)
	var court_lip := DemoGeometry.box(room.geometry,Vector3(-3,3.775,-175.5),Vector3(5.5,.45,2.4),room._floor,true)
	court_lip.set_meta("timeline_phase",&"present")
	court_lip.set_meta("route_connector",true)
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
	upper_anchor.position = Vector3(5.0,16.0,-218.0)
	room.static_anchors.append(upper_anchor)
	CitadelDressing.asset(room.geometry,"hanging_chain",upper_anchor.position,Vector3(.7,.7,.7))
	var transfer_anchor := RiftConstruct.new()
	transfer_anchor.kind = &"anchor"
	transfer_anchor.permanent = true
	transfer_anchor.grapple_exit_speed = 18.0
	transfer_anchor.grapple_exit_lift = 5.5
	transfer_anchor.set_meta("followup_wall", {"normal": Vector3(1,0,0), "point": Vector3(-4.55,10.0,-257.0)})
	room.geometry.add_child(transfer_anchor)
	transfer_anchor.position = Vector3(-4.0,19.0,-252.0)
	room.static_anchors.append(transfer_anchor)
	CitadelDressing.asset(room.geometry,"hanging_chain",transfer_anchor.position,Vector3(.7,.7,.7))
	room.signature_sections[&"vertical_anchor_chain"]={
		"start":Vector3(-3,4,-204),"upper_deck":Vector3(4,7,-235),
		"transfer_deck":Vector3(4,10,-260),"boss_approach":Vector3(-2,12,-286),
		"mechanics":[&"grapple_to_wall","wall_run","wall_kick","air_dash"]}
	room._route_marker(Vector3(-3,4.08,-207),Color("#75c5de"),&"air")
	room._route_marker(Vector3(4.4,7.08,-232),Color("#dd987d"),&"wall")
	room._route_marker(Vector3(-4.4,10.08,-257),Color("#dd987d"),&"wall")
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
	# The final platform ends at z=-294. Keep the exit gate on its landing
	# surface so the next-stage trigger is reachable on foot, rather than
	# floating six metres beyond the deck in the void.
	room._exit(Vector3(-2,12,-291))
	for p: Vector3 in [Vector3(-10,2,-86),Vector3(4,4,-188)]:
		var statue := CitadelDressing.asset(room.geometry,"gothic_statue",p,Vector3(1.3,1.3,1.3))
		statue.set_meta("attached_to_route", true)
	# The door is the physical destination dressing for this route. Keep its
	# full depth on the final landing instead of placing it beyond the deck in
	# the void. The authored GLB's lowest mesh point is y=-0.228; at the 2.2x
	# scale its door leaves sit 0.50 m below the instance origin, so this
	# offset seats the leaves on the platform top (y=final_platform.y).
	var final_platform: Vector3 = path[-1]
	var final_platform_size: Vector2 = room.platform_extents[final_platform]
	var door_scale := Vector3(2.2,2.2,2.2)
	var door_y := final_platform.y + 0.50
	var door_z := final_platform.z - final_platform_size.y*.5 + 0.30
	CitadelDressing.asset(room.geometry,"large_castle_door",Vector3(final_platform.x,door_y,door_z),door_scale)
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
