extends Resource
## Gameplay timing is independent of imported animation frame rate.
@export_range(.08,.4) var hunt_approach_seconds:float=.18
@export_range(.12,.3) var counter_approach_seconds:float=.16
@export_range(40.,140.) var peak_approach_speed:float=105.
@export_range(.025,.15) var contact_seconds:float=.055
@export_range(.10,.4) var recovery_seconds:float=.24
@export_range(.03,.22) var attack_unlock_seconds:float=.12
@export_range(.08,.4) var attack_buffer_seconds:float=.22
@export_range(1.6,2.6) var target_spacing:float=1.95
@export_range(2.,3.5) var maximum_contact_distance:float=2.8
@export_range(.1,3.) var target_motion_tolerance:float=1.25
@export_range(0.,24.) var minimum_exit_speed:float=10.
@export_range(8.,40.) var maximum_exit_speed:float=24.
@export_range(0.,8.) var hunt_exit_lift:float=2.
@export_range(0.,6.) var counter_exit_lift:float=1.2
@export_range(0.,1.) var momentum_seconds:float=.5
@export_range(0.,1.) var kill_guard_seconds:float=.45

func validation_errors()->PackedStringArray:
	var errors:=PackedStringArray()
	for property in get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE==0 or property.type!=TYPE_FLOAT:continue
		var value:float=get(property.name)
		if not is_finite(value) or value<0:errors.append(property.name)
	if attack_unlock_seconds>recovery_seconds:errors.append("attack_unlock_seconds")
	if target_spacing>=maximum_contact_distance:errors.append("target_spacing")
	if minimum_exit_speed>maximum_exit_speed:errors.append("minimum_exit_speed")
	if peak_approach_speed<=0:errors.append("peak_approach_speed")
	return errors
