extends "res://fx_live_r13/weapon_magic_base.gd"
## R9 画面基线的可配置版本；参数不会改变伤害、发射点和命中时刻。
const PROFILE = preload("res://fx_live_r13/magic_tuning.gd")
@export var tuning: Resource
var _snapshot: Resource = PROFILE.new()
var _configured := false
var _valid := true

func configure(profile: Resource) -> PackedStringArray:
	if is_node_ready(): return PackedStringArray(["tuning：特效创建后不可替换；下次施放使用新实例"])
	return _snapshot_profile(profile)

func _snapshot_profile(profile: Resource) -> PackedStringArray:
	if not profile is PROFILE: return PackedStringArray(["tuning：需要 MagicTuning 配置 Resource"])
	var errors: PackedStringArray = profile.validation_errors()
	if not errors.is_empty(): return errors
	_snapshot = profile.duplicate(true)
	_configured = true
	return errors

func _ready() -> void:
	if not _configured and tuning != null:
		var errors := _snapshot_profile(tuning)
		if not errors.is_empty():
			_valid = false
			push_error("特效配置无效：" + "; ".join(errors))
			visible = false
			return
	# Base construction calls our material/ribbon overrides with the snapshot.
	super._ready()
	lamp.omni_range = _snapshot.light_radius_m
	rng.seed = _snapshot.random_seed
	for row in shard_data:
		row.direction = Vector3(rng.randf_range(-1,1),rng.randf_range(-.1,1),rng.randf_range(-1,1)).normalized()
		row.speed = (rng.randf_range(.4,1.4) if profession == "blade" else rng.randf_range(.6,2.6)) * _snapshot.shard_speed_scale
		row.delay = rng.randf_range(0,.06)
		row.scale = rng.randf_range(.5,1.4)
	for item in wisps: item.material.set_shader_parameter("emission_scale", _snapshot.emission_scale)
	for shader in ribbon_materials: shader.set_shader_parameter("emission_scale", _snapshot.emission_scale)

func material(color: Color, energy: float = 0.0, opacity: float = 1.0) -> StandardMaterial3D:
	return super.material(color, energy * _snapshot.emission_scale, opacity)

func animate(age: float, release: float, hit: float, palm: Vector3, origin: Vector3, target: Vector3, enabled: bool = true) -> void:
	if not _valid: return
	var visual_age: float = hit + (age - hit) / _snapshot.decay_time_scale if age > hit else age
	super.animate(visual_age, release, hit, palm, origin, target, enabled)
	if not enabled: return
	charge.scale *= _snapshot.charge_scale
	missile.scale = Vector3.ONE * _snapshot.projectile_scale
	burst.scale = Vector3.ONE * _snapshot.impact_scale
	impact_core.scale *= _snapshot.impact_scale
	motes.scale = Vector3.ONE * _snapshot.impact_scale
	if _snapshot.shard_count >= 0: motes.multimesh.visible_instance_count = _snapshot.shard_count
	lamp.light_energy *= _snapshot.light_energy_scale
	# Rebuild the finite trail cross-section without scaling world endpoints.
	if projectile_trail.visible and not is_equal_approx(_snapshot.trail_width_scale, 1.0):
		var points := PackedVector3Array()
		var travel := clampf(inverse_lerp(release, hit, visual_age), 0, 1)
		for i in range(17):
			var u := maxf(0, travel - .22 + float(i)/16*.22)
			var radius := .024*sin(float(i)/16*PI)
			points.append(released_from.lerp(target,u)+Vector3(sin(u*31+visual_age*8),cos(u*27+visual_age*8),0)*radius)
		projectile_trail.mesh = tube_mesh(points, .007 * _snapshot.trail_width_scale)

func reset() -> void:
	if _valid: super.reset()

func profile_snapshot() -> Resource:
	return _snapshot.duplicate(true)
