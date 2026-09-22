class_name ParkourProfile
extends Resource
## 职业的移动数据；数值使用米、秒。战斗系统可订阅玩家的墙跑事件。
@export var id: StringName = &"wanderer"
@export var display_name: String = "巡游者"
@export_multiline var description: String = "均衡的墙面机动。"
@export_range(9.0, 24.0, 0.5) var wall_speed: float = 14.0
@export_range(1.0, 60.0, 1.0) var wall_acceleration: float = 18.0
@export_range(0.5, 4.0, 0.1) var wall_duration: float = 1.8
@export_range(0.0, 1.0, 0.05) var wall_gravity_scale: float = 0.18
@export_range(0.5, 3.0, 0.1) var wall_jump_height: float = 1.65
@export_range(3.0, 12.0, 0.5) var wall_jump_push: float = 7.0
@export var restore_dash_on_wall_jump: bool = false
@export_group("Grapple")
@export_range(20.0, 48.0, 0.5) var grapple_pull_speed: float = 38.0
@export_range(60.0, 260.0, 5.0) var grapple_pull_acceleration: float = 220.0
@export_range(8.0, 24.0, 0.5) var grapple_vertical_speed: float = 14.0
@export_range(0.4, 1.0, 0.05) var grapple_vertical_scale: float = 0.72
@export_range(2.0, 10.0, 0.25) var grapple_vertical_exit_gap: float = 6.0
@export_range(0.0, 10.0, 0.5) var grapple_steer_speed: float = 5.5
@export_range(0.0, 40.0, 1.0) var grapple_steer_acceleration: float = 20.0
@export_range(20.0, 48.0, 0.5) var grapple_max_speed: float = 40.0
@export_range(8.0, 32.0, 0.5) var grapple_exit_speed: float = 24.0
@export_range(0.0, 8.0, 0.5) var grapple_exit_lift: float = 3.5
@export_range(0.1, 1.5, 0.05) var grapple_exit_momentum_seconds: float = 0.45
@export var left_hand_item: HeldItemDefinition
@export var right_hand_item: HeldItemDefinition
