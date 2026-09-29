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
		2:main=[hub,hub+Vector3(24,1,-30),hub+Vector3(28,5,-65),hub+Vector3(-3,5,-101),hub+Vector3(-19,7,-139),hub+Vector3(0,7,-180)]
		3:main=[hub,hub+Vector3(-23,3,-31),hub+Vector3(-26,6,-67),hub+Vector3(0,10,-102),hub+Vector3(26,13,-140),hub+Vector3(13,11,-176),hub+Vector3(0,9,-211)]
	# Wall-commit arrivals use a lower service apron. Lowering the authored node
	# itself keeps the route graph, collision floor and visual landing at the
	# same height; the following segment then climbs again as a deliberate beat.
	for i in range(2,main.size()):
		if i % 2 == 0 or (stage == 3 and i == 5):
			main[i].y-=1.0
			if stage == 2 and i == 2: main[i].y-=1.0
	room.route_nodes=main
	# Register destinations before linking. The hubs are staging landings, not
	# arenas: their tighter footprint preserves a readable void around the next
	# traversal beat and prevents a straight-line ground bypass.
	for i in range(main.size()):
		# The first post-entry hub is the receiving deck for the authored wall
		# tutorial. Its extra depth is real masonry and only covers the braking
		# lane; the void remains outside the deck edge.
		var hub_extent := Vector2(22,12) if i==0 and stage==3 else (Vector2(22,40) if i==0 and stage==2 else (Vector2(16,14) if i==0 else Vector2(12,14)))
		# Phase-crossing landings take a diagonal airborne arrival. Give only those
		# authored decks a wider receiving footprint so the player can settle on
		# real stone after the handoff without adding a flat bypass to the route.
		if i == 3 and stage in [2,3]: hub_extent=Vector2(18,20)
		room.platform_extents[main[i]]=Vector2(24,20) if i==main.size()-1 else hub_extent
	if stage == 3:
		# The faster wall profile can still leave the first tower transfer at the
		# far edge of the receiving hub while descending. This tail is a separate
		# grounded masonry landing beyond the hub, so it catches the arrival without
		# extending the hub toward the entrance or creating a ground bypass.
		var hub_tail := main[0] + Vector3(0,0,-24)
		room.platform_extents[hub_tail]=Vector2(12,10)
		room._platform(hub_tail,Vector2(12,10))
		_foundation(room,hub_tail,Vector2(12,10))
	# The earlier small arena is now the entrance quarter of the domain.
	var entry := Vector3(0,height,[-44.0,-32.0,-39.0][stage-1])
	if stage>=2:_wall_link(room,entry,hub)
	else:_link(room,entry,hub,false)
	for i in range(main.size()):
		var point: Vector3=main[i]
		var size := Vector2(24,20) if i==main.size()-1 else (Vector2(22,12) if i==0 and stage==3 else (Vector2(22,40) if i==0 and stage==2 else (Vector2(12,26) if i==1 and stage==3 else (Vector2(16,14) if i==0 else (Vector2(18,20) if i==3 and stage in [2,3] else Vector2(12,14))))))
		# The first expansion beat is already a transfer out of the entrance
		# quarter. Later beats alternate wall commitments and short recovery pads;
		# no stage-2/3 critical route can be cleared by holding forward on a deck.
		# The forge's mid-course rise is a committed vertical beat, not a
		# walkable recovery ramp.  Keeping it as a generic split link let a
		# forward runner follow the lower slab to its edge and fall before the
		# intended high-line handoff.  Author it as a wall transfer so the
		# elevation is earned through the same wall-kick language as the rest of
		# the critical route.
		var wall_commit := i >= 1 and (i == 1 or i % 2 == 0 or (stage == 2 and i == 3) or (stage == 3 and i == 5))
		if wall_commit:
			# A wall-run landing needs a real receiving apron. Widening the deck in
			# the travel axis gives the player braking room without filling the void
			# beneath the critical wall segment.
			size += Vector2(2.0, 4.0)
			if stage == 3 and i == 1:
				# The first tower rise exits from a diagonal wall-kick. The original
				# 14 m receiver left the carried lateral impulse just outside its
				# visible edge, so both professions fell beside a real platform.
				# Widen this elevated landing only; it remains above the void and
				# does not create a ground bypass.
				size.x += 20.0
			if stage in [2,3] and i == 2:
				# The second forge wall exits with carried momentum at the near edge
				# of this raised deck. Extend the authored stone catch zone along
				# the route axis, while leaving the preceding gap open. This is a
				# receiving apron on the same structural deck, not a ground shortcut.
				# Keep the deck compact on the forge rise. A deep slab reaches back
				# under the wall-run and its underside catches the capsule before the
				# receiving ramp reaches the top surface.
				size += Vector2(2.0, 0.0)
			if stage == 2 and i == 1:
				# The first forge wall is approached from both directions during
				# route validation. Its receiving deck needs enough real stone
				# behind the wall exit for reverse braking before the next void.
				size.y += 6.0
			if stage == 2 and i == 3:
				# The phase-return wall kicks into this elevated deck from its
				# outer edge. Preserve the void below, but give the carried lateral
				# impulse a real transverse landing band; the former 20 m width
				# ended just before a valid kick from the diagonal face could settle.
				size += Vector2(8.0,4.0)
				# Keep the deck's route-facing edge clear of the lower wall. A deep
				# slab put its underside over the final kick window, so the runner
				# struck the platform from below instead of rising onto its top.
				size.y = 12.0
			if stage == 3 and i == 1:
				# The first tower receiver must keep its lateral catch width, but its
				# original 30 m depth put the front edge at z=-84. That real vertical
				# face intercepted the runner before the authored wall-kick window.
				# The current kick exits around the near quarter of this high deck and
				# carries roughly four metres beyond the old rear edge. Extend the
				# visible landing band along the authored transfer, with its foundation
				# remaining below the same elevated slab. This catches the physical
				# arrival without filling the void beneath the wall or adding a ground
				# bypass.
				size = Vector2(24.0,16.0)
		# The route builder uses platform_extents to place wall takeoff and
		# landing edges. Keep that contract in sync with the real slab size after
		# the authored receiving margins above; stale extents put the wall several
		# metres inside the collider and make the reverse pass hit its side.
		room.platform_extents[point]=size
		room._platform(point,size)
		_foundation(room,point,size)
		if i>0:
			# Every second expansion beat is a true wall transfer. The intervening
			# links remain broken decks for recovery, so the player alternates
			# wall-run/air-dash with a short landing instead of ground-running the
			# full domain. Wall commits deliberately remove the ground deck: the
			# high route is the authored critical path, not a decorative shortcut.
			if wall_commit:
				_wall_link(room,main[i-1],point)
				room.signature_sections[&"wall_commit_%d"%i]={
					"from":main[i-1],"to":point,"mechanic":&"wall_run",
					"ground_route":false,"critical":true}
			else:
				_link(room,main[i-1],point,true if i != 1 else false)
		# The hub's outside route exits east in the tower, west in the forge.
		# Keep its framing wall on the opposite flank, clear of the ramp.
		# The tower hub exits toward the negative-x route. The old negative flank
		# wall sat directly across that first sightline and physically trapped the
		# player before the authored wall transfer. Keep the arcade on the far
		# side of the hub so it frames the route without becoming an invisible gate.
		# The tower outer loop exits on the positive-x side. Keep this framing wall
		# on the opposite flank so it cannot block the first grapple line.
		# Stage-3's outer circuit exits on the positive-x side. Keep the first
		# framing wall on the opposite flank so its body and sightline never
		# occlude the authored grapple from the hub to branch[0].
		var flank := Vector3(-9 if i==0 and stage==3 else (9 if i%2==0 else -9),3.4,0)
		# Framing masonry is visual composition only. Route walls are authored by
		# _wall_link/_pressure_wall; this bay must not become an air-wall gate.
		room._wall(point+flank,Vector3(.65,7,8),false)
		if i in [0,2] or i==main.size()-1:CitadelDressing.asset(room.geometry,"gothic_bay",point+Vector3(0,0,-7),Vector3(1.6,1.6,1))
		CitadelDressing.brazier(room.geometry,point+Vector3(-4,0,3))
		# Main platforms are traversal beats. Only the middle of a route is an
		# encounter; the entry/exit platforms stay readable for wall-run planning.
		if i>0 and i<main.size()-1:
			# Interrupt distant firing lines while keeping both flanks passable.
			# Combat cover stays readable while leaving the traversal lane open.
			room._wall(point+Vector3(5.5,1.8,0),Vector3(1.1,3.6,4.5),false)
	room._extra_altar(hub+Vector3(-5,0,-3))
	# Wide outer route: an optional exploration circuit reconnects at the arena.
	var side: float=-1.0 if stage==2 else 1.0
	var outer_width: float=49.0 if stage==3 else 39.0
	var return_width: float=35.0 if stage==3 else 25.0
	# Start the outer loop far enough beyond the hub edge that its receiving
	# deck cannot present a vertical side before the authored jump cue. The
	# previous 25 m offset put the deck edge at roughly x=8 while the cue was
	# still at x=11, so a runner hit the side and could not commit to the gap.
	var branch: Array[Vector3]=[hub+Vector3(side*30,2,-7),hub+Vector3(side*outer_width,5,-55),hub+Vector3(side*outer_width,9,-107),main[-1]+Vector3(side*return_width,4,20)]
	room.branch_nodes=branch
	# Exploration branches still leave the centre open, but their authored
	# receiving decks need enough width for a real wall-kick or grapple exit.
	# Eight-by-nine pads let a valid arrival skim the bevel and fall in both
	# directions, especially when the player carries a lateral dash.
	for index in branch.size():
		# The grapple releases a few metres before the anchor. The first outer
		# deck therefore needs a broad, readable catch zone; later pads stay
		# tighter so the branch remains a traversal route instead of a flat road.
		room.platform_extents[branch[index]]=Vector2(20,18) if index==0 else Vector2(14,14)
	# Keep the outer grapple lane clear of the central gap wall. The void remains
	# real; the side walls and landing pads still provide the authored route.
	# The outer lane keeps the void and relay anchor, but no central filler wall:
	# that wall would occupy the receiving edge and block the first turn onto the
	# exploration platform.
	_link(room,hub,branch[0],true,false)
	for i in range(branch.size()):
		var branch_size := Vector2(20,18) if i==0 else Vector2(14,14)
		room._platform(branch[i],branch_size)
		_foundation(room,branch[i],branch_size)
		if i>0:_link(room,branch[i-1],branch[i],true,false)
		room._wall(branch[i]+Vector3(side*4.5,3,0),Vector3(.6,6.5,6))
		# The outer loop is an exploration reward, not a second combat corridor.
	# The mid-route checkpoint lives on the first outer landing.  The main
	# high-line deck is intentionally retired in one timeline, so mounting an
	# altar there would create a visible prop over a phase-dependent void.
	# Keep the checkpoint readable without putting its physical plinth in the
	# centre of the next traversal lane. The first outer landing continues
	# straight into the following rise, so mount it on the inner shoulder of the
	# same real platform.
	room._extra_altar(branch[1]+Vector3(4.0,0,3.0))
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
	# The secret return is an airborne handoff. Give the player enough real stone
	# to bleed the carried velocity before the phase-chain continuation; a tiny
	# pad turned a valid arrival into a lateral miss for both professions.
	var return_landing := main[2]+Vector3(-side*11,0,-7)
	var return_size := Vector2(12,8)
	room._platform(return_landing,return_size)
	_foundation(room,return_landing,return_size)
	_return_hint(room,secret,return_landing)
	CitadelDressing.asset(room.geometry,"seal_obelisk",secret+Vector3(2,0,-2),Vector3(.5,.7,.5))
	# Permanent grappling anchors join exploration loops for either profession.
	for index in [0,1,2,3]:
		var approach := ((branch[index]-(hub if index==0 else branch[index-1]))*Vector3(1,0,1)).normalized()
		# Mount the anchor on the approach face of the receiving deck.  Placing it
		# inside the platform made the grapple ray hit the platform's side before
		# reaching the target, while placing it just beyond the edge keeps the
		# short Ghostrunner-style zip readable and leaves the real landing to the
		# deck collision.
		var receiving_size: Vector2 = room.platform_extents.get(branch[index],Vector2(14,14))
		var edge_clearance := minf(receiving_size.x*.5/maxf(.001,absf(approach.x)),receiving_size.y*.5/maxf(.001,absf(approach.z)))
		var point := branch[index]-approach*(edge_clearance+1.2)+Vector3.UP*2.3
		var anchor := RiftConstruct.new()
		anchor.kind=&"anchor"
		anchor.grapple_exit_speed=12.0
		anchor.grapple_exit_lift=1.5
		# These branch anchors sit just beyond a narrow receiving edge. Release
		# into the pad's approach lane, with enough separation to keep the anchor
		# readable without making the player overshoot the next platform.
		anchor.grapple_release_distance=2.0
		anchor.permanent=true
		# Keep the authored branch identity with the physical anchor.  Long links
		# also create relay anchors; without an explicit identity, route probes and
		# the interaction fallback can confuse a relay with the branch landing.
		anchor.set_meta("route_branch_index",index)
		anchor.set_meta("route_source",hub if index==0 else branch[index-1])
		anchor.set_meta("route_landing",branch[index])
		var exit_direction := branch[index]-point
		exit_direction.y=0.0
		if exit_direction.length_squared()>.25:
			anchor.set_meta("grapple_exit",{"direction":exit_direction.normalized()})
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
	# The base forge/tower builders used to create a provisional exit before the
	# long expansion was appended. Remove it only when it exists; the expansion
	# owns the single playable exit at the end of the full route.
	if is_instance_valid(room.exit_area): room.exit_area.queue_free()
	if is_instance_valid(room._gate): room._gate.queue_free()
	if is_instance_valid(room._exit_title): room._exit_title.queue_free()
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
	# End the wall-run inside the receiving deck rather than at its bevel. The
	# extra landing margin is part of the authored metric, so both directions
	# get braking room after the wall surface ends.
	to_edge=maxf(0.0,to_edge-2.0)
	var takeoff:=a+direction*from_edge
	var landing:=b-direction*to_edge
	var wall_exit := landing
	var gap:=wall_exit-takeoff
	# A rising route still uses a vertical wall face.  Tilting the wall's local
	# Z axis along the full 3D gap made its lower edge climb with the destination
	# deck; the runner then lost the face while still below the wall-kick window.
	# Keep the authored elevation in the wall centre, but orient the contact
	# surface along the horizontal route so its usable height stays constant.
	var horizontal_gap := Vector3(gap.x,0.0,gap.z).normalized()
	var basis:=Basis.looking_at(horizontal_gap)
	var legacy_stage3_entry: bool = room.stage == 3 and a.z > -45.0
	var entry_transfer: bool = a.z > -45.0
	var first_tower_handoff: bool = room.stage == 3 and a.distance_to(Vector3(0,1,-68)) < .1
	# The reverse tutorial pass approaches from the hub side. Extend only the
	# entry wall toward that side so the player meets a continuous surface before
	# the end cap, while keeping the authored receiving platform unchanged.
	var entry_center_shift := direction.normalized()*1.5 if entry_transfer else Vector3.ZERO
	# The wall and apron are a bidirectional handoff.  The previous wall stopped
	# several metres before the receiving edge; on a reverse traversal the apron
	# face was reached first, so the player landed on its vertical end and could
	# never reacquire the wall.  Extend the authored wall slightly past both
	# route edges and centre it on the actual gap so either direction sees the
	# same contact surface.  The overlap is intentional masonry, not an extra
	# walkable deck.
	# Keep the masonry just beyond both authored edges. Entry links need the extra
	# three metres only on the hub side for a bidirectional wall capture.
	# The entry jump is evaluated from the departure apron.  The old +10m
	# extension left the near end of the collision box about 2m beyond the
	# authored jump cue, so the capsule hit the end cap before either side probe
	# could latch.  Extend the physical face toward the departure deck while
	# keeping the landing edge unchanged; this is collision continuity, not a
	# hidden floor and it keeps the same wall valid in both directions.
	# Entry walls only need a short lead-in on each side of the transfer. They
	# deliberately finish inside the overlap of the two real decks so the runner
	# can brake and land; the longer wall used by later links would carry the
	# player past the receiving slab at full wall speed.
	# The wall is a traversal surface, not a decorative slice between the two
	# decks.  Give high-line transfers a real lead-in and run-out so the capsule
	# does not leave the face before the authored kick/landing window.
	var wall_length := gap.length()+22.0 if room.stage==2 else gap.length()+24.0
	if entry_transfer:
		# Keep a compact, high-commitment wall between the two real decks.  The
		# departure deck is intentionally short, so this leaves an open gap in
		# both directions without carrying the runner past the receiving platform.
		# Forge entry caps need a short overlap with the receiving slab. The
		# capsule radius and wall-normal push otherwise stop the reverse pass at
		# the bevel before the real floor begins.
		wall_length=maxf(11.0,gap.length()+2.0)
	elif room.stage == 2 and a.distance_to(Vector3(0,3,-65)) < .1:
		# Stop the first forge face before it crosses the next wall-run's takeoff
		# deck. Its former run-out formed a solid corner at (24, 4, -96).
		wall_length=gap.length()+4.0
	elif room.stage == 2 and a.distance_to(Vector3(28,6,-130)) < .1:
		# The forge's rising mid-course transfer needs to stay under the runner
		# through the wall-kick window, but its previous long run-out crossed the
		# receiving deck and left an end cap in front of the next wall's takeoff.
		# Keep only a real handoff margin beyond the authored gap; the receiving
		# ramp below supplies the remaining landing continuity.
		wall_length=gap.length()+14.0
	elif room.stage == 3 and a.distance_to(Vector3(0,1,-68)) < .1:
		# The first tower face must release before the next wall begins; their
		# overlapping end caps otherwise pin the runner on the shared deck.
		# The first tower face carries the player through the full rising transfer;
		# its visible run-out must cover the kick window, not end at the midpoint.
		wall_length=gap.length()+20.0
	elif room.stage == 3 and b.distance_to(Vector3(-26,6,-135)) < .1:
		# This rising tower transfer lands on the enlarged high deck. The generic
		# run-out carried the wall several metres beyond its real receiving edge,
		# so the kick happened after the ramp had ended and the runner fell below
		# the visible platform. Keep a short handoff margin like the first tower.
		# The source deck is itself a short landing band. Extending the wall back
		# over that band creates a solid end cap at the exact place where the next
		# transfer begins. Keep the wall edge-to-edge here; the receiving ramp and
		# deck provide the braking margin on the far side.
		# Start this face at the end of the preceding tower face. The two
		# authored walls form one visible handoff with a short open seam, so the
		# player can carry the same jump into the second wall without a hidden
		# floor or an unphysical suction point.
		wall_length=gap.length()
	elif room.stage == 3 and a.distance_to(Vector3(0,11,-170)) < .1:
		# The previous wall must end before the next wall-run's departure deck.
		wall_length=gap.length()+8.0
	elif room.stage == 3 and b.distance_to(Vector3(13,11,-244)) < .1:
		# This descending transfer still needs the face through the braking window.
		# The previous shortened wall ended before the receiving ramp, so a runner
		# lost contact in mid-air several metres above the lower deck. Keep a short
		# run-out beyond the authored handoff and let the real ramp catch the fall.
		wall_length=maxf(14.0,gap.length()+4.0)
	elif room.stage == 3 and b.distance_to(Vector3(0,9,-279)) < .1:
		# The final tower wall hands into the arena from the lower return deck. A
		# full-length decorative overrun reaches the guardian's final platform,
		# so stop it near the authored wall-kick window.
		wall_length=maxf(10.0,gap.length()-4.0)
	# Entry walls are the first committed vertical beat. Start them at the deck
	# and give both professions enough readable face above the jump arc; later
	# transfers retain their tighter profile and preserve the surrounding void.
	# The route surface is a thin dressed wall face. A 0.46 m collision slab
	# leaves the capsule pressed into its edge when the wall-run keeps its
	# authored inward bias, which can swallow tangent motion at a seam. Keep the
	# visible masonry unchanged while using a 0.24 m physical face.
	var wall_size:=Vector3(.24,15.0,wall_length) if entry_transfer else Vector3(.24,11.0,wall_length)
	# Two offset faces form a readable stone gorge. Both directions use the same
	# pair of contact surfaces; the old single-face entrance was valid only in the
	# authored direction and let a reverse traversal fall onto the nave roof.
	# A single entry face is intentional: it teaches wall capture without
	# turning the entrance into a narrow collision gorge. The opposite flank is
	# the caster's rear approach and remains open; later transfers still use the
	# paired faces that support side-to-side parkour.
	# One continuous entry face is enough for both travel directions. Keeping a
	# second face here creates a boxed corridor: its near end cap can catch the
	# capsule before the intended wall probe, which reads as an invisible stop.
	var route_index := room.route_nodes.find(a)
	var primary_side: float = 1.0 if route_index < 0 or route_index % 2 == 1 else -1.0
	var wall_sides: Array[float] = [primary_side]
	# Entry transfers are bidirectional authored links. Keep both real faces so
	# the same wall can be captured from the hub on the return pass; the two
	# faces remain separated by the route clearance and do not form a filler
	# floor or an invisible shortcut.
	# Entry transfers are approached from a real deck, so the teaching face must
	# sit beside the lane. The old two-face 1 m offset put their inner faces only
	# about 1.5 m apart; a player capsule could enter the corridor but could not
	# move laterally to either the rear lane or the receiving edge. Derive the
	# clearance from the departure deck instead of hard-coding a width so the
	# stage-2 and stage-3 entry metrics stay valid when their decks differ.
	# Keep the authored face inside the player's 2.2 m wall probe. The
	# departure deck remains wide enough to leave a rear combat lane beside it.
	# Keep the route face just inside the capsule's authored attach band.  The
	# previous .62 m offset left a measured .286 m surface gap after the wall
	# slab and capsule radius were accounted for, one physics threshold beyond
	# wall_attach_distance (.28 m).  On diagonal follow-up links the landing
	# drift adds a small lateral component, so .50 m leaves a stable margin
	# without putting the wall inside the grounded route.
	var entry_side_clearance := .50
	# Keep the two authored faces far enough apart that the forward-clearance
	# probe cannot see the opposite wall as an obstacle during a diagonal run.
	# The player still reaches either face within wall_probe_reach, while the
	# corridor no longer behaves like an accidental collision slot.
	var side_offset: float = entry_side_clearance
	# The phase crossing is authored on the following airborne transfer. Keep
	# this bidirectional wall solid in both timeline states so a return run can
	# reacquire either side; gating one face by phase leaves the reverse route
	# with no physical surface even though the wall is visibly present.
	var phase_crossing := false
	for side:float in wall_sides:
		# Expansion walls begin above the departure deck so ground-running cannot
		# collide with their extended lead-in; the raised face remains reachable by
		# the authored jump and preserves the wall-run commitment.
		var wall_offset := Vector3.UP*1.0 if entry_transfer else Vector3.UP*2.0
		# The final tower wall is approached from its lower end on the return
		# circuit. Lower that face into the player's wall-probe band so the reverse
		# transfer can latch before the capsule loses its floor contact.
		if room.stage == 3 and b.distance_to(Vector3(0,9,-279)) < .1:
			wall_offset=Vector3.UP*.8
		var wall_center:=takeoff.lerp(landing,.5)+entry_center_shift+basis.x*(side*side_offset)+wall_offset
		if room.stage == 3 and b.distance_to(Vector3(-26,6,-135)) < .1:
			# Keep only a short masonry seam beyond the previous receiver.  A five
			# metre translation left a real airborne gap between the first tower face
			# and this face: the runner left the first wall before entering the next
			# wall's valid height band.  The first face is already shortened above,
			# so a small seam is enough to keep their end caps separate.
			# Keep the next face clear of the receiving cap while retaining enough
			# overlap for the real diagonal wall-kick window.
			wall_center += direction.normalized()*5.0
		var hub_exit_side: float = 1.0 if room.stage == 2 else -1.0
		if entry_transfer and side == hub_exit_side:
			# Keep both faces available for a sustained wall run, but pull the
			# hub-side end of each face toward the entry by a short masonry bay.
			# Both the main and outer hub exits then remain open while the wall still
			# reaches the receiving deck for the authored entry transfer.
			wall_center -= direction.normalized()*6.0
		var actual_size := wall_size
		if entry_transfer and side > 0.0 and room.stage == 2:
			# Keep a second face for reverse capture, but start it after the
			# departure lip. Its shortened source end removes the collision cap that
			# previously caught a forward runner before the primary face.
			actual_size.z = maxf(4.0,wall_length-8.0)
			wall_center += direction.normalized()*4.0
		if phase_crossing:
			# The present line remains a complete physical wall so the base route is
			# still fair without requiring an undocumented timeline toggle. Remnant
			# keeps its offset shorter wall as the higher-risk alternate line; the
			# two phase-owned surfaces never overlap in collision at the same time.
			if side > 0.0:
				actual_size.z = wall_length
				wall_center = takeoff.lerp(landing,.5)+entry_center_shift+basis.x*(side*side_offset*.92)+wall_offset
			else:
				# Keep the remnant face physically continuous through the airborne
				# phase handoff.  It is offset from the present face, so the overlap
				# does not create a solid wall across the route; it only prevents a
				# visible wall from becoming non-collidable under the player.
				actual_size.z = gap.length()*.88+3.0
				wall_center = takeoff.lerp(landing,.56)+entry_center_shift+basis.x*(side*side_offset*.92)+wall_offset
		var wall:=DemoGeometry.box(room.geometry,wall_center,actual_size,room._stone,true)
		wall.basis=basis
		wall.set_meta("route_wall_size",actual_size)
		wall.set_meta("wall_link_from",a)
		wall.set_meta("wall_link_to",b)
		wall.set_meta("entry_wall",entry_transfer)
		if phase_crossing:
			wall.set_meta("timeline_phase",&"present" if side>0 else &"remnant")
			wall.set_meta("timeline_crossing",true)
		wall.add_to_group("floating_route_surface")
		for fraction:float in [.18,.5,.82]:
			var rune:=DemoGeometry.box(wall,Vector3(0,0,(fraction-.5)*(actual_size.z-1.2)),Vector3(.025,5.4,.12),room._accent)
			rune.set_meta("interactive_visual",true)
		if room.stage == 3 and a.is_equal_approx(room.route_nodes[0]):
			# Mark the real kick window before the rising receiver interrupts the
			# face. The metal inlay belongs to this wall, never a floating cue.
			var kick_point := b-direction*23.0
			kick_point.y = a.y+2.5
			var kick_local := wall.to_local(room.to_global(kick_point))
			for index in range(3):
				var mark := DemoGeometry.box(wall,Vector3(-side*(actual_size.x*.5+.016),kick_local.y+index*.18,kick_local.z),Vector3(.025,.045,.55),room._accent)
				mark.rotation.x = -.5
				mark.set_meta("interactive_visual",true)
	# A compact receiving apron sits under the wall exit. It is a deliberate
	# landing asset, not a hidden floor: its own paving and foundation make the
	# wall-to-platform handoff readable and stop the player being caught on the
	# platform bevel.
	# Keep the receiving deck behind the end of the ramp. A deep apron whose
	# near edge starts halfway up the slope creates a vertical curb; this short
	# stone handoff remains level with the authored arrival slab in both stages.
	# Put the lip wholly on the receiving side of the wall exit. A centred lip
	# still projected its near edge back into the wall and became the first
	# collider hit during the final metres of a wall run.
	# Descending exits need the threshold fully on the receiving side.  The
	# runner is already below the source deck when the wall timer ends, so a
	# centred apron presents its near end cap before the lower ramp can catch.
	var apron_offset := 6.0 if b.y < a.y-.75 else 4.0
	if first_tower_handoff:
		# The tower's first receiver is entered from the positive-X side. Put a
		# short real landing bay on that approach side so the deck's vertical edge
		# cannot intercept the wall-run before the receiving ramp reaches its top.
		apron_offset=-2.0
	var apron := wall_exit + direction * apron_offset
	# A full square here reaches several metres back into the wall-run and
	# presents an axis-aligned vertical face before the player can kick toward
	# the receiving deck.  Keep a real landing lip, but limit its depth to the
	# handoff zone so the wall remains continuous until the authored exit.
	var apron_size := Vector2(8,8) if first_tower_handoff else Vector2(8,1.4)
	# An apron wholly inside the destination slab duplicates its coplanar floor
	# and can become the first platform_at() match for that centre.
	var apron_inside_deck := first_tower_handoff or (absf(apron.x-b.x)+apron_size.x*.5 <= b_size.x*.5 and absf(apron.z-b.z)+apron_size.y*.5 <= b_size.y*.5)
	if not apron_inside_deck:
		var apron_body := room._platform(apron,apron_size)
		_foundation(room,apron,apron_size)
	# High-line transfers need a sloped receiving surface. A flat platform at
	# the destination height presents a vertical face while the runner is still
	# descending from the wall, so the capsule hits the side and falls through.
		# Keep this ramp on the receiving side of the wall exit. Extending it back
		# toward the takeoff lip creates a real collider in the jump approach and
		# catches the capsule before the wall probe can commit.
	var rise := b.y-a.y
	if not entry_transfer and absf(rise)>.75:
		var ramp_start := wall_exit - direction.normalized()*1.0
		var ramp_end := wall_exit + direction.normalized()*3.0
		if first_tower_handoff:
			# Carry the real catch slope back to the authored wall-kick window. The
			# previous four-metre stub began after the airborne trajectory had already
			# dropped outside the receiver, so both professions fell beside the deck.
			# This is a visible rising stone surface in the high route, not a ground
			# bridge or hidden recovery floor.
			# Reach the destination height before the deck's front edge. The runner is
			# expected to kick and optionally air-dash from the wall; ending the slope
			# at the deck edge made the capsule meet its vertical face while still
			# descending. The extra six metres are the visible receiving incline and
			# remain entirely above the void.
			ramp_end = b-direction*(to_edge+6.0)
			ramp_start = b-direction*23.0
		elif room.stage == 2 and b.distance_to(Vector3(28,6,-130)) < .1:
			ramp_start = wall_exit - direction*5.0
			ramp_end = wall_exit - direction*2.0
		if rise < -0.75:
			ramp_start = wall_exit - direction.normalized()*1.0
			ramp_end = b + direction.normalized()*6.0
			ramp_start.y = b.y-3.0
			ramp_end.y = b.y
		else:
			ramp_start.y = b.y-signf(rise)*minf(2.5,absf(rise)+.5)
			ramp_end.y = b.y
			if first_tower_handoff:
				# The kick leaves the wall around the departure-deck height. Start
				# the narrow catch slope below the elevated slab so the capsule meets
				# its top while descending instead of passing underneath it.
				ramp_start.y = b.y-3.0
			elif room.stage == 2 and b.distance_to(Vector3(28,6,-130)) < .1:
				ramp_start.y = b.y-4.0
				ramp_end.y = b.y
		if room.stage == 2 and b.distance_to(Vector3(-3,8,-166)) < .1:
			# The forge's second kick exits below the receiving deck while the
			# runner still carries diagonal momentum. Extend the real landing ramp
			# back to that exit and let it rise continuously into the deck; a short
			# high threshold otherwise presents the deck's vertical side first.
			ramp_start = wall_exit - direction.normalized()*4.0
			# wall_exit is already two metres inside the deck. End two metres
			# toward the departure side from that point, at the actual front edge,
			# instead of placing the slope below the platform's underside.
			ramp_end = wall_exit - direction.normalized()*2.0
			ramp_start.y = b.y-3.0
			ramp_end.y = b.y
		var ramp_delta := ramp_end-ramp_start
		var ramp_basis := Basis.looking_at(ramp_delta.normalized())
		var ramp_width := 18.0 if first_tower_handoff else 9.0
		# The first tower receiver already has a real elevated landing slab. Its
		# sloped dressing must not add a side collider across the wall-kick flight.
		var ramp := DemoGeometry.box(room.geometry,ramp_start.lerp(ramp_end,.5)-ramp_basis.y*.225,Vector3(ramp_width,.45,ramp_delta.length()),room._floor,true)
		ramp.basis=ramp_basis
		ramp.set_meta("route_connector",true)
		# Reach full deck height before its vertical front face, then carry a
		# level stone threshold over that edge. Otherwise the capsule hits the
		# platform side while still climbing, despite seeing a continuous slope.
		var threshold_end := ramp_end + direction.normalized()*6.0
		var threshold := DemoGeometry.box(room.geometry,ramp_end.lerp(threshold_end,.5)-Vector3.UP*.225,Vector3(ramp_width,.45,ramp_end.distance_to(threshold_end)),room._floor,true)
		threshold.basis=Basis.looking_at(direction.normalized())
		threshold.set_meta("route_connector",true)
	if entry_transfer:
		# Entry walls are bidirectional tutorials. The reverse traversal exits at
		# the opposite cap, so mirror the visible landing bay there instead of
		# relying on a platform bevel at the exact void edge.
		# The reverse handoff belongs at the original takeoff edge.  Reusing the
		# destination edge put this body in front of the forward wall-run and made
		# a solid platform appear several metres before the exit.
		var reverse_apron := takeoff - direction * 4.0
		room._platform(reverse_apron,apron_size)
		_foundation(room,reverse_apron,apron_size)
	elif not legacy_stage3_entry:
		# Every authored wall link is traversable in both directions. The forward
		# receiving apron is on the landing side; mirror a short apron on the
		# departure side so the reverse wall-kick exits onto real stone instead of
		# meeting the underside of the source platform. Its narrow depth preserves
		# the void and only covers the final braking window.
		var reverse_apron := takeoff - direction.normalized()*4.0
		room._platform(reverse_apron,apron_size)
		_foundation(room,reverse_apron,apron_size)
	# The apron is level with the receiving deck and overlaps its edge by design;
	# the overlap is the visible stone handoff after the wall-run.
	# Advertise the extended hub-side edge as the reverse jump cue. This keeps
	# the acceptance route and the physical wall in the same place, so a reverse
	# runner jumps before reaching the wall cap instead of being stopped by it.
	# Trigger the jump cue while the capsule is still well inside the departure
	# deck. At the bevel the floor contact can disappear one physics tick before
	# the authored wall begins, which makes a valid wall transfer look skipped.
	var route_takeoff := takeoff - direction.normalized()*4.0
	var route_exit := wall_exit + direction.normalized()*5.0 if entry_transfer else wall_exit
	room.route_links.append({"from":a,"to":b,"gap":true,"segments":[route_takeoff,route_takeoff,route_exit,route_exit],"mechanic":&"wall_run"})
	if phase_crossing:
		room.route_links[-1]["phase_crossing"]=true
		room.signature_sections[&"forge_phase_crossing"]={"from":takeoff,"to":wall_exit,"phases":[&"present",&"remnant"],"mechanics":[&"wall_run",&"wall_kick",&"timeline_shift"]}

static func _pressure_wall(room: CombatRoom,a: Vector3,b: Vector3,index: int) -> void:
	# A side-mounted traversal face follows the same direction as the deck but
	# sits beyond the recovery line. Its lower edge is reachable from a
	# jump/dash and its upper edge is intentionally open to the void; the
	# recovery deck remains clear instead of being cut by the wall volume.
	var direction := ((b-a)*Vector3(1,0,1)).normalized()
	if direction.length_squared() < .25:return
	var side := Vector3(-direction.z,0,direction.x) * (5.4 if index%2==0 else -5.4)
	var midpoint := a.lerp(b,.5) + side + Vector3.UP*3.2
	var length := Vector2(b.x-a.x,b.z-a.z).length()*.58
	room._wall(midpoint,Vector3(.52,5.8,maxf(7.0,length)))
	room.signature_sections[&"wall_pressure_%d"%index]={"from":a,"to":b,"high_line":midpoint,"mechanic":&"wall_run"}

static func _link(room: CombatRoom,a: Vector3,b: Vector3,gap: bool,include_gap_wall: bool=true) -> void:
	# Long routes get reachable stepping stations, not proportionally wider gaps.
	if a.distance_to(b)>39:
		var middle := a.lerp(b,.5)
		# Keep the recovery midpoint close to the departure floor.  Splitting the
		# full elevation jump evenly made the first connector a steep ramp that
		# stopped the capsule at its lip; the remaining rise is carried by the
		# second authored connector where the next wall/air beat begins.
		middle.y = a.y + clampf(b.y-a.y,-1.0,1.0)
		var middle_size := Vector2(12,12)
		if room.stage == 3 and b.distance_to(Vector3(0,11,-170)) < .1:
			# This elevated phase-chain midpoint is the real handoff between the
			# lower recovery link and the continuous climb. The incoming connector
			# reaches its near edge with carried momentum; give that node a modest
			# transverse landing band so the player can settle before the next jump.
			middle_size = Vector2(20,20)
		# Recursive links use the same extents to derive edge-to-edge segments.
		# Register the generated recovery slab before recursing; otherwise the
		# builder falls back to 8x8 and places the jump/landing geometry inside its
		# real 12x12 collision, which is where the diagonal routes were catching.
		room.platform_extents[middle]=middle_size
		var middle_body := room._platform(middle,middle_size)
		if room.stage == 3 and b.distance_to(Vector3(0,11,-170)) < .1:
			# This generated midpoint is part of the remnant high line. It is not a
			# decorative recovery slab: bind its real floor to the same phase as the
			# continuous handoff so the landing cannot disappear after the shift.
			middle_body.set_meta("timeline_phase", &"remnant")
			middle_body.set_meta("timeline_authored", true)
		_foundation(room,middle,middle_size)
		if not include_gap_wall:
			# Exploration branches use a real intermediate grapple point so the
			# authored zip is reachable from both halves without widening the void.
			var relay := RiftConstruct.new()
			relay.kind=&"anchor"
			relay.grapple_exit_speed=12.0
			relay.grapple_exit_lift=1.5
			relay.grapple_release_distance=2.0
			relay.permanent=true
			relay.set_meta("route_relay",true)
			relay.set_meta("route_source",a)
			relay.set_meta("route_landing",b)
			room.geometry.add_child(relay)
			relay.position=middle+Vector3.UP*2.3
			var relay_direction := b-relay.position
			relay_direction.y=0.0
			if relay_direction.length_squared()>.25:
				relay.set_meta("grapple_exit",{"direction":relay_direction.normalized()})
			room.static_anchors.append(relay)
		_link(room,a,middle,false,include_gap_wall)
		_link(room,middle,b,gap,include_gap_wall)
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
	var phase_handoff := (room.stage == 2 and to_center.distance_to(Vector3(-3,8,-166)) < .1) or (room.stage == 3 and to_center.distance_to(Vector3(0,11,-170)) < .1)
	# These phase transfers are short vertical climbs after a wall/air beat. Use
	# the full centre-to-centre run for the ramp so its slope stays walkable; the
	# surrounding slabs remain the visual takeoff and receiving decks.
	if phase_handoff:
		from_edge=0.0
		to_edge=0.0
		# The full-length phase handoff is deliberately a continuous ramp. Keeping
		# the generic broken-gap flag would make the route test jump from its first
		# midpoint even though the physical surface now spans the whole transfer.
		gap=false
	elif from_edge+to_edge>distance-1:
		from_edge=minf(from_edge,distance*.35)
		to_edge=minf(to_edge,distance*.35)
	# The route body is travelled by a capsule, not a point.  Keep its visible
	# end inside each real deck by a metre so the capsule does not slip off the
	# exact geometric edge while lining up for the next transfer.
	from_edge=maxf(0.0,from_edge-1.0)
	to_edge=maxf(0.0,to_edge-1.0)
	if room.stage == 3 and to_center.distance_to(Vector3(0,11,-170)) < .1 and not phase_handoff:
		# Start the four-metre climb on the actual midpoint deck. The short
		# edge-to-edge ramp exceeds the capsule's walkable slope and bounces the
		# player at its toe despite looking like a continuous bridge.
		from_edge=0.0
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
	if room.stage == 2 and to_center.distance_to(Vector3(-3,8,-166))<.1 and segments.size()>2:
		# Keep the authored takeoff and landing points on their original sides of
		# the gap.  Extending the landing point toward the receiving deck moved the
		# ramp into the takeoff lane and left the capsule against its end face.
		# Only the final endpoint enters the real destination slab, so the player
		# still has a readable gap and a stable landing surface.
		segments[3] = segments[3] + flat*2.0
	if room.stage == 3 and to_center.distance_to(Vector3(0,11,-170))<.1 and segments.size()>2:
		# Preserve the source-side takeoff and gap width.  The receiving endpoint
		# is the only point that needs extra overlap with the destination slab;
		# moving the landing point backward creates a solid side face in the jump.
		segments[3] = segments[3] + flat*2.0
	room.route_links.append({"from":from_center,"to":to_center,"gap":gap,"segments":segments.duplicate()})
	# Two authored mid-route rise links already terminate on their intended
	# intermediate landing. Their original slope is the stable handoff; the
	# wider receiving-threshold treatment below is reserved for outer recovery
	# links and must not displace these phase-chain midpoints.
	# Rising handoffs need the same source-side run-up as every other authored
	# bridge. Keeping the old midpoint exceptions left a vertical front face at
	# the exact point where the capsule entered the sloped deck, so both the
	# forge diagonal and tower diagonal stopped one body radius early.
	var skip_ramp_adjust := false
	for index in range(0,segments.size(),2):
		var start: Vector3=segments[index]
		var finish: Vector3=segments[index+1]
		if not gap and not skip_ramp_adjust and not phase_handoff and finish.y > start.y+.25:
			# A rising service bridge must reach deck height before its vertical
			# edge. The original centre-to-centre slope touched the platform one
			# capsule radius too low, leaving a visible path with a solid curb.
			start -= flat*2.0
			finish -= flat*2.5
		var deck_basis := Basis.looking_at((finish-start).normalized())
		var center := start.lerp(finish,.5)-deck_basis.y*.225
		var span: float=start.distance_to(finish)
		# The bridge remains narrow enough to preserve the void and route choice.
		var receiving_jump := room.stage == 2 and to_center.distance_to(Vector3(-3,8,-166)) < .1
		# The stage-3 rising handoff is a diagonal approach used by both
		# professions. Give it a wider physical stone face so the caster's
		# lateral profile cannot catch the bevel while still preserving a narrow
		# elevated bridge over the void.
		var wide_rising_handoff := room.stage == 3 and ((finish.y > start.y+.25 and not gap) or to_center.distance_to(Vector3(0,11,-170)) < .1)
		var deck_width := 11.0 if receiving_jump else (8.4 if wide_rising_handoff else 5.8)
		var deck := DemoGeometry.box(room.geometry,center,Vector3(deck_width,.45,span),room._floor,true)
		deck.basis=deck_basis
		DemoGeometry.box(deck,Vector3(0,-.38,0),Vector3(.35,.55,span),room._iron)
		for side: float in [-1,1]:
			DemoGeometry.box(deck,Vector3(side*1.55,.235,0),Vector3(.045,.04,span),room._accent)
		if not gap and not skip_ramp_adjust and not phase_handoff and finish.y > start.y+.25:
			var threshold_end := finish+flat*5.0
			var threshold := DemoGeometry.box(room.geometry,finish.lerp(threshold_end,.5)-Vector3.UP*.225,Vector3(5.8,.45,finish.distance_to(threshold_end)),room._floor,true)
			threshold.basis=Basis.looking_at(flat)
			threshold.set_meta("route_connector",true)
	# Broken links receive a short physical threshold over the destination edge.
	# Continuous ramps already meet the authored platform and must not add a
	# second coplanar body at shared nodes: that duplicate end cap traps reverse
	# traversal against the platform while looking like ordinary floor.
	if gap:
		var landing_direction := flat
		var landing_basis := Basis.looking_at(landing_direction)
		var landing_width := 11.0 if ((room.stage == 2 and to_center.distance_to(Vector3(-3,8,-166)) < .1) or (room.stage == 3 and to_center.distance_to(Vector3(0,11,-170)) < .1)) else minf(5.8,maxf(2.8,b_size.x))
		var landing_size := Vector3(landing_width,.45,0.2)
		var landing_center := to_center - landing_direction * maxf(0.0,to_edge-1.5)
		var landing_lip := DemoGeometry.box(room.geometry,landing_center-Vector3.UP*.225,landing_size,room._floor,true)
		landing_lip.basis=landing_basis
		landing_lip.set_meta("route_connector",true)
	if gap:
		var point := a.lerp(b,.5)+basis.x*2.1+Vector3.UP*2
		if include_gap_wall and not (room.stage == 2 and to_center.distance_to(Vector3(-3,8,-166)) < .1):
			var wall := DemoGeometry.box(room.geometry,point,Vector3(.45,5,length*.65),room._stone,true)
			wall.basis=Basis.looking_at(Vector3(direction.x,0,direction.z).normalized())

static func _foundation(room: CombatRoom,p: Vector3,size: Vector2) -> void:
	# Foundations are visual support below the authored platform. The platform
	# body itself is the only walkable collision owner; a solid 13 m foundation
	# turns a removed timeline deck into an invisible floor/wall and lets players
	# bypass the intended wall, grapple, and phase route.
	var foundation:=DemoGeometry.box(room.geometry,p-Vector3.UP*7,Vector3(size.x-1,13,size.y-1),room._stone,false)
	foundation.add_to_group("structural_foundation")
	foundation.set_meta("platform_center",p)
	foundation.set_meta("platform_size",size)
	foundation.set_meta("visual_only",true)
	foundation.set_meta("presentation_only",true)
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
	# These physical route devices are shared affordances. Their nearby deck may
	# belong to one timeline, but the device itself must not become an invisible
	# phase-gated blocker or disappear from the player's current interaction path.
	# Timeline-exclusive surfaces are authored explicitly on route geometry.
	device.set_meta("timeline_shared", true)
	device.position=p
	# Set the authored world position before entering the tree. TerrainDevice
	# creates its independent route barrier in _ready(); adding first would build
	# that blocker at the room origin and leave the visible device unblocked.
	room.geometry.add_child(device)
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
