class_name HeldItemDefinition
extends Resource
## 纯表现定义：场景以米建模，原点放在握持中心；不会生成战斗碰撞。
@export var display_name: String = "手持物"
@export var scene: PackedScene
@export var grip_position: Vector3 = Vector3.ZERO
@export var grip_rotation_degrees: Vector3 = Vector3.ZERO
@export var grip_scale: Vector3 = Vector3.ONE
@export var hand_pose_offset: Vector3 = Vector3.ZERO
@export var hand_pose_rotation_degrees: Vector3 = Vector3.ZERO
@export_range(0.0, 1.5, 0.05) var finger_curl: float = 0.75
@export_range(0.0, 1.0, 0.05) var running_swing_multiplier: float = 0.55
@export_range(0, 100, 1) var melee_damage: int = 0
@export var ranged: bool = false
@export_range(1, 100, 1) var projectile_damage: int = 24
@export_range(8.0, 45.0, 1.0) var projectile_speed: float = 24.0
