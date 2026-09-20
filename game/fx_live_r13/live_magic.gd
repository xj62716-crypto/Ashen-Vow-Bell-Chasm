extends "res://fx_live_r13/weapon_magic.gd"
## No predicted collision time. Gameplay supplies the current bolt or the actual contact.
var live_age: float = 0.0
var contact_age: float = -1.0
var contact_point: Vector3
var last_point: Vector3
var samples: PackedVector3Array = []
var chain_mode:bool=false
var chain_points:=PackedVector3Array()

func flight(point: Vector3,direction: Vector3,world_delta: float) -> void:
	live_age+=world_delta; last_point=point
	# Reuse material animation only; positions and history are overwritten with real samples.
	animate(live_age+.1,0.0,live_age+10.0,point,released_from,point)
	missile.global_position=point
	if direction.length_squared()>.001: missile.global_basis=Basis.looking_at(direction.normalized(),Vector3.RIGHT if absf(direction.normalized().y)>.95 else Vector3.UP)
	charge.hide(); burst.hide(); impact_core.hide(); motes.hide(); lamp.hide()
	for beam in lightning_branches: beam.hide()
	if samples.is_empty() or samples[-1].distance_to(point)>.018:samples.append(point)
	while samples.size()>18:samples.remove_at(0)
	projectile_trail.visible=samples.size()>1
	if samples.size()>1:projectile_trail.mesh=tube_mesh(samples,.006*_snapshot.trail_width_scale)
	if chain_mode:_chain_path(point)

func _chain_path(point:Vector3) -> void:
	if released_from.distance_to(point)<.02:return
	chain_points.clear();var forward:Vector3=(point-released_from).normalized()
	var side:=forward.cross(Vector3.UP if absf(forward.y)<.95 else Vector3.RIGHT).normalized();var up:=side.cross(forward)
	for index in range(19):
		var u:float=float(index)/18.0
		chain_points.append(released_from.lerp(point,u)+(side*sin(index*9.43+live_age*38)+up*cos(index*7.17-live_age*21))*.042*sin(u*PI))
	projectile_trail.visible=true;projectile_trail.mesh=tube_mesh(chain_points,.012*_snapshot.trail_width_scale)

func contact(point: Vector3) -> void:
	contact_age=0.0; contact_point=point; last_point=point
	# A fast secondary bolt may contact between render frames. Its completed
	# path is still authoritative and must not require two visual samples.
	if chain_mode:_chain_path(point)

func fade_contact(world_delta: float) -> bool:
	contact_age+=world_delta
	animate(.1+contact_age,0.0,.1,contact_point,released_from,contact_point)
	charge.hide(); missile.hide(); projectile_trail.hide()
	if chain_mode and chain_points.size()>1:
		# Keep the path already travelled visible briefly after the actual impact.
		projectile_trail.show();projectile_trail.mesh=tube_mesh(chain_points,.012*_snapshot.trail_width_scale);projectile_trail.transparency=clampf(contact_age/.24,0,1)
	for beam in lightning_branches:beam.hide()
	return contact_age < .9*_snapshot.decay_time_scale

func prepare_at(palm: Vector3,muzzle: Vector3,age_seconds: float,windup: float) -> void:
	animate(age_seconds,maxf(windup,.03),1000.0,palm,muzzle,muzzle)
	missile.hide(); burst.hide(); impact_core.hide(); motes.hide(); projectile_trail.hide()
	for beam in lightning_branches:beam.hide()
