@tool
class_name LevelMechanismTuning
extends Resource
## All durations use scaled world time. Snapshot taken at device creation.
## Lift travel height is authored geometry; changing it requires route checks.
@export_range(.75,12,.05,"suffix:s") var lift_travel_seconds: float=3.5714285714
@export_range(.5,12,.1,"suffix:s") var pulse_interval_seconds: float=2.8
@export_range(3,30,.5,"suffix:m") var pulse_activation_radius_m: float=15.0
## Local velocity transformed by the device basis; never edits player stats.
@export var launch_velocity_local_mps := Vector3(-4,14,-13)
@export_range(.25,8,.05,"suffix:s") var launch_cooldown_seconds: float=1.5
@export_range(.5,5,.1,"suffix:m") var launch_interact_range_m: float=3.0
@export_range(.25,2,.05,"suffix:m") var launch_auto_radius_m: float=1.4
@export_range(0,3,.05,"suffix:s") var launch_momentum_seconds: float=1.1
## Boss phase-one exposure after destroying every core/chain; later phases use 5/6 and 2/3.
## Field name retained for existing Resources. Legacy altar seals never bypass boss objectives.
@export_range(2,15,.25,"suffix:s") var seal_exposure_seconds: float=9.0
@export_range(1,5,.1,"suffix:m") var interaction_range_m: float=3.5

func validation_errors(path: String="mechanisms") -> PackedStringArray:
	var errors := PackedStringArray()
	var limits := {"lift_travel_seconds":Vector2(.75,12),"pulse_interval_seconds":Vector2(.5,12),"pulse_activation_radius_m":Vector2(3,30),"launch_cooldown_seconds":Vector2(.25,8),"launch_interact_range_m":Vector2(.5,5),"launch_auto_radius_m":Vector2(.25,2),"launch_momentum_seconds":Vector2(0,3),"seal_exposure_seconds":Vector2(2,15),"interaction_range_m":Vector2(1,5)}
	for key: String in limits:
		var value: float=get(key)
		var bounds: Vector2=limits[key]
		if not is_finite(value) or value<bounds.x or value>bounds.y:errors.append("%s.%s: expected finite %s..%s"%[path,key,bounds.x,bounds.y])
	if not launch_velocity_local_mps.is_finite() or absf(launch_velocity_local_mps.x)>25 or absf(launch_velocity_local_mps.z)>25 or launch_velocity_local_mps.y<6 or launch_velocity_local_mps.y>22:
		errors.append(path+".launch_velocity_local_mps: finite x/z ±25 and y 6..22 m/s required")
	if launch_auto_radius_m>launch_interact_range_m:errors.append(path+".launch_auto_radius_m: must not exceed launch_interact_range_m")
	return errors
