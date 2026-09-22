extends Resource
## Visual response only. Combat timing remains owned by PlayerCombat.
@export_range(0.0, 0.15) var attack_blend_seconds: float = .025
@export_range(0.0, 0.3) var movement_blend_seconds: float = .085
@export_range(0.0, 0.3) var recovery_blend_seconds: float = .10
@export_range(0.0, 0.5) var sway_strength: float = .25
@export_range(50.0, 85.0) var viewmodel_fov: float = 65.0
@export_range(0.02, 0.18) var trail_lifetime: float = .065
@export_range(0.0, 1.5) var trail_strength: float = .60
@export_range(0.0, 1.0) var trail_inner_fraction: float = .28
@export_range(0.0, 1.0) var body_camera_strength: float = .14
@export var carry_offset: Vector3 = Vector3.ZERO
@export_group("Left hand presentation")
@export_range(0.02, 0.2) var left_enter_seconds: float = .055
@export_range(0.03, 0.3) var left_exit_seconds: float = .12
@export_range(0.0, 0.15) var left_action_hold_seconds: float = .025
@export_range(0.0, 1.0) var left_action_weight: float = 1.0
@export var left_stow_offset: Vector3 = Vector3(-.20,-.82,.16)
@export var left_action_offset: Vector3 = Vector3.ZERO
@export var left_special_parkour: bool = true
@export_group("Blade framing and contact")
@export_range(65.0, 80.0) var blade_viewmodel_fov: float = 71.0
@export var blade_grip_right_offset: Vector3 = Vector3.ZERO
@export var blade_grip_left_offset: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0) var blade_grip_weight: float = 1.0
@export_range(0.0, 0.08) var blade_hit_stop: float = .038
@export_range(0.0, 0.08) var blade_kill_stop: float = .052
@export_range(0.0, 1.5) var blade_camera_impulse: float = .65
@export_group("Blade magic")
@export_range(.02, .18) var blade_trail_lifetime: float = .12
@export_range(.1, 1.0) var blade_trail_width: float = .95
@export_range(0.0, 2.0) var blade_trail_brightness: float = 1.8
@export_range(0.0, 1.0) var blade_bloom_contribution: float = .55
@export_range(0.0, 1.0) var blade_trail_breakup: float = .4
@export_range(0, 3) var blade_afterimage_count: int = 1
@export var blade_core_color: Color = Color("dce7e8")
@export var blade_echo_color: Color = Color("382740")
@export var blade_duel_color: Color = Color("541c35")
@export var blade_slide_color: Color = Color("512829")
@export var blade_hunt_color: Color = Color("542443")
@export_range(.03, .06) var blade_impact_flash_seconds: float = .045
@export_range(0.0, 2.0) var blade_impact_burst: float = .7
@export_group("Blade contact mist")
@export_range(0.0, 1.0) var blade_contact_mist_opacity: float = .96
@export var blade_contact_mist_size: Vector2 = Vector2(.84, .64)
@export_range(.18, .5) var blade_contact_mist_lifetime: float = .45
@export_range(0.0, 2.0) var blade_contact_mist_speed: float = 1.2
@export_range(0.0, 8.0) var blade_contact_mist_expansion: float = 5.8
@export_group("Compound blade arc")
@export var blade_compound_arc_enabled:bool = true
@export_range(.015, .09) var blade_ribbon_width: float = .075
@export_range(1.0, 2.5) var blade_empowered_width: float = 1.35
@export_range(.04, .14) var blade_empowered_lifetime: float = .09
@export_range(0.0, 3.0) var blade_camera_yaw_degrees: float = 1.1
@export_range(0.0, 3.0) var blade_camera_pitch_degrees: float = .7
@export_range(0.0, 4.0) var blade_camera_roll_degrees: float = 1.6
@export_range(4.0, 30.0) var blade_camera_settle: float = 18.0
@export_group("R3 authored samples")
@export var blade_sample_r3:bool = false # Rejected pose/camera candidate only; blade magic is independent.
@export_range(.02,.18) var blade_left_release_seconds:float=.07
@export_range(0,8) var blade_cut_yaw:float=3.8
@export_range(0,10) var blade_cut_roll:float=5.5
@export_range(0,.12) var blade_cut_camera_travel:float=.045
@export_range(0,8) var blade_cut_fov:float=3.5
@export_range(0,3) var blade_contact_recoil:float=1.2
@export_group("Compound blade arc appearance")
@export_range(0,1) var blade_motion_smear:float=.22
@export_range(2,16) var blade_curve_samples:int=8
@export_range(.03,.22) var blade_arc_lifetime:float=.11
@export_range(.03,.3) var blade_arc_width:float=.065
@export_range(0,6) var blade_arc_emission:float=2.45
@export_range(0,1) var blade_arc_opacity:float=.56
@export_range(0,1) var blade_arc_rune_gain:float=.28
@export var blade_arc_outer:Color=Color("a84368")
@export var blade_arc_core:Color=Color("e3efff")
@export_group("Execution spacing")
@export_range(1.6,2.6) var blade_execution_distance:float=1.95
@export_range(.12,.32) var blade_execution_camera_seconds:float=.18

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var sample_ranges:Dictionary={"blade_left_release_seconds":Vector2(.02,.18),"blade_cut_yaw":Vector2(0,8),"blade_cut_roll":Vector2(0,10),"blade_cut_camera_travel":Vector2(0,.12),"blade_cut_fov":Vector2(0,8),"blade_contact_recoil":Vector2(0,3),"blade_motion_smear":Vector2(0,1),"blade_curve_samples":Vector2(2,16),"blade_arc_lifetime":Vector2(.03,.22),"blade_arc_width":Vector2(.03,.3),"blade_arc_emission":Vector2(0,6),"blade_arc_opacity":Vector2(0,1),"blade_arc_rune_gain":Vector2(0,1),"blade_execution_distance":Vector2(1.6,2.6),"blade_execution_camera_seconds":Vector2(.12,.32)}
	for key:String in sample_ranges:
		var value:float=get(key);var bounds:Vector2=sample_ranges[key]
		if not is_finite(value) or value<bounds.x or value>bounds.y:errors.append(key)
	var ranges := {"attack_blend_seconds":Vector2(0,.15), "movement_blend_seconds":Vector2(0,.3), "recovery_blend_seconds":Vector2(0,.3), "sway_strength":Vector2(0,.5), "viewmodel_fov":Vector2(50,85), "trail_lifetime":Vector2(.02,.18), "trail_strength":Vector2(0,1.5), "trail_inner_fraction":Vector2(0,1), "body_camera_strength":Vector2(0,1)}
	for key in ranges:
		var value:float=get(key)
		if not is_finite(value) or value<ranges[key].x or value>ranges[key].y:errors.append(key)
	if not carry_offset.is_finite() or carry_offset.length()>.25:errors.append("carry_offset")
	for key in {"left_enter_seconds":Vector2(.02,.2),"left_exit_seconds":Vector2(.03,.3),"left_action_hold_seconds":Vector2(0,.15),"left_action_weight":Vector2(0,1)}:
		var bounds:Vector2={"left_enter_seconds":Vector2(.02,.2),"left_exit_seconds":Vector2(.03,.3),"left_action_hold_seconds":Vector2(0,.15),"left_action_weight":Vector2(0,1)}[key]
		var value:float=get(key)
		if not is_finite(value) or value<bounds.x or value>bounds.y:errors.append(key)
	if not left_stow_offset.is_finite() or left_stow_offset.y>-.55 or left_stow_offset.length()>1.8:errors.append("left_stow_offset")
	if not left_action_offset.is_finite() or left_action_offset.length()>.15:errors.append("left_action_offset")
	var blade_ranges:Dictionary={"blade_viewmodel_fov":Vector2(65,80),"blade_grip_weight":Vector2(0,1),"blade_hit_stop":Vector2(0,.08),"blade_kill_stop":Vector2(0,.08),"blade_camera_impulse":Vector2(0,1.5),"blade_trail_lifetime":Vector2(.02,.18),"blade_trail_width":Vector2(.1,1),"blade_trail_brightness":Vector2(0,2),"blade_bloom_contribution":Vector2(0,1),"blade_trail_breakup":Vector2(0,1),"blade_afterimage_count":Vector2(0,3),"blade_impact_flash_seconds":Vector2(.03,.06),"blade_impact_burst":Vector2(0,2),"blade_contact_mist_opacity":Vector2(0,1),"blade_contact_mist_lifetime":Vector2(.18,.5),"blade_contact_mist_speed":Vector2(0,2),"blade_contact_mist_expansion":Vector2(0,8)}
	for key in blade_ranges:
		var value:float=get(key)
		if not is_finite(value) or value<blade_ranges[key].x or value>blade_ranges[key].y:errors.append(key)
	for offset:Vector3 in [blade_grip_right_offset,blade_grip_left_offset]:
		if not offset.is_finite() or offset.length()>.025:errors.append("blade_grip_offset")
	if not blade_contact_mist_size.is_finite() or blade_contact_mist_size.x<.2 or blade_contact_mist_size.x>.9 or blade_contact_mist_size.y<.2 or blade_contact_mist_size.y>.8:errors.append("blade_contact_mist_size")
	for key in {"blade_ribbon_width":Vector2(.015,.09),"blade_empowered_width":Vector2(1,2.5),"blade_empowered_lifetime":Vector2(.04,.14),"blade_camera_yaw_degrees":Vector2(0,3),"blade_camera_pitch_degrees":Vector2(0,3),"blade_camera_roll_degrees":Vector2(0,4),"blade_camera_settle":Vector2(4,30)}:
		var bounds:Vector2={"blade_ribbon_width":Vector2(.015,.09),"blade_empowered_width":Vector2(1,2.5),"blade_empowered_lifetime":Vector2(.04,.14),"blade_camera_yaw_degrees":Vector2(0,3),"blade_camera_pitch_degrees":Vector2(0,3),"blade_camera_roll_degrees":Vector2(0,4),"blade_camera_settle":Vector2(4,30)}[key]
		var value:float=get(key)
		if not is_finite(value) or value<bounds.x or value>bounds.y:errors.append(key)
	for colour:Color in [blade_core_color,blade_echo_color,blade_duel_color,blade_slide_color,blade_hunt_color,blade_arc_core,blade_arc_outer]:
		for value:float in [colour.r,colour.g,colour.b,colour.a]:
			if not is_finite(value) or value<0 or value>1:errors.append("blade_colour")
	return errors
