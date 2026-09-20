extends Resource
## Q83：单次施法的视觉参数。真实命中、范围、冷却与时钟由玩法提供。
## 复制 .tres 新建变体；配置在创建特效时取快照，施放中不热改。

@export_category("标识与版本")
@export var profile_id: StringName = &"magic_default"
@export var schema_version: int = 1
@export_category("形体 · 倍率")
@export_range(0.1, 3.0, 0.05) var charge_scale: float = 1.0
@export_range(0.1, 3.0, 0.05) var projectile_scale: float = 1.0
@export_range(0.1, 3.0, 0.05) var impact_scale: float = 1.0
@export_range(0.25, 3.0, 0.05) var trail_width_scale: float = 1.0
@export_category("亮度 · 倍率")
@export_range(0.0, 3.0, 0.05) var emission_scale: float = 1.0
@export_range(0.0, 3.0, 0.05) var light_energy_scale: float = 1.0
@export_range(0.1, 10.0, 0.1, "suffix:m") var light_radius_m: float = 3.0
@export_category("消散 · 倍率")
@export_range(0.25, 3.0, 0.05) var decay_time_scale: float = 1.0
@export_category("碎屑 · 数量与速度")
## -1 沿用元素默认数量；0 关闭碎屑；上限48。
@export_range(-1, 48, 1) var shard_count: int = -1
@export_range(0.1, 3.0, 0.05) var shard_speed_scale: float = 1.0
@export var random_seed: int = 7152

const RANGES := {
	"charge_scale": Vector2(0.1, 3.0), "projectile_scale": Vector2(0.1, 3.0),
	"impact_scale": Vector2(0.1, 3.0), "trail_width_scale": Vector2(0.25, 3.0),
	"emission_scale": Vector2(0.0, 3.0), "light_energy_scale": Vector2(0.0, 3.0),
	"light_radius_m": Vector2(0.1, 10.0), "decay_time_scale": Vector2(0.25, 3.0),
	"shard_speed_scale": Vector2(0.1, 3.0),
}

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(profile_id).strip_edges().is_empty(): errors.append("profile_id：必须有稳定 ID")
	if schema_version != 1: errors.append("schema_version：只支持版本1，请迁移配置")
	for field in RANGES:
		var value: float = get(field)
		var limits: Vector2 = RANGES[field]
		if not is_finite(value) or value < limits.x or value > limits.y:
			errors.append("%s：必须为有限数值，范围 %s–%s" % [field, limits.x, limits.y])
	if shard_count < -1 or shard_count > 48: errors.append("shard_count：范围 -1–48")
	return errors
