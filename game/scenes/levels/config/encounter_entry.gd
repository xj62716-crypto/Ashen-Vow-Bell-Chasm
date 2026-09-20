@tool
class_name LevelEncounterEntry
extends Resource
## Stable authored spawn definition. Distances are metres in room-local space.
## Copied when a room is built; editing the source does not move live actors.
@export var id: StringName=&""
@export_range(1,3,1) var stage: int=1
@export var position_m := Vector3.ZERO
@export_enum("normal","shield","elite","miniboss","boss") var archetype: String="normal"
@export_enum("pursuer","heavy","crossbow","caster","bell","sentinel") var role: String="crossbow"
@export var required_guardian: bool=false
## First attack delay, not a periodic attack-speed override.
@export_range(0.1,15,.05,"suffix:s") var initial_delay_seconds: float=1.1
## Baseline actor attack/awareness radius; AI behavior remains gameplay-owned.
@export_range(4,40,.5,"suffix:m") var attack_range_m: float=18.0

func validation_errors(path: String="encounter") -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty() or not String(id).is_valid_ascii_identifier():errors.append(path+".id: use a non-empty ASCII identifier")
	if stage<1 or stage>3:errors.append(path+".stage: expected 1..3")
	if not position_m.is_finite() or absf(position_m.x)>150 or position_m.y< -10 or position_m.y>60 or position_m.z< -400 or position_m.z>30:
		errors.append(path+".position_m: outside finite authored bounds x±150 y[-10,60] z[-400,30]")
	if archetype not in ["normal","shield","elite","miniboss","boss"]:errors.append(path+".archetype: unknown prototype "+archetype)
	if role not in ["pursuer","heavy","crossbow","caster","bell","sentinel"]:errors.append(path+".role: unknown behavior "+role)
	if not is_finite(initial_delay_seconds) or initial_delay_seconds<.1 or initial_delay_seconds>15:errors.append(path+".initial_delay_seconds: expected finite 0.1..15 s")
	if not is_finite(attack_range_m) or attack_range_m<4 or attack_range_m>40:errors.append(path+".attack_range_m: expected finite 4..40 m")
	return errors
