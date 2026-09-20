@tool
class_name LevelRunConfiguration
extends Resource
const SCHEMA_VERSION: int=1
@export var schema_version: int=SCHEMA_VERSION
@export var id: StringName=&""
@export var mechanisms: LevelMechanismTuning
@export var encounters: Array[LevelEncounterEntry]=[]

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version!=SCHEMA_VERSION:errors.append("schema_version: unsupported %d; expected %d; explicit migration required"%[schema_version,SCHEMA_VERSION])
	if String(id).is_empty() or not String(id).is_valid_ascii_identifier():errors.append("id: use a non-empty ASCII identifier")
	if mechanisms==null:errors.append("mechanisms: required resource is missing")
	else:errors.append_array(mechanisms.validation_errors())
	if encounters.size()>96:errors.append("encounters: maximum 96 entries")
	var ids: Dictionary={}
	var required := [0,0,0]
	var bosses := [0,0,0]
	for index in range(encounters.size()):
		var entry := encounters[index]
		var path := "encounters[%d]"%index
		if entry==null:
			errors.append(path+": required entry is missing")
			continue
		path+="("+String(entry.id)+")"
		errors.append_array(entry.validation_errors(path))
		if ids.has(entry.id):errors.append(path+".id: duplicate stable ID")
		ids[entry.id]=true
		if entry.stage>=1 and entry.stage<=3:
			if entry.required_guardian:required[entry.stage-1]+=1
			if entry.archetype in ["miniboss","boss"]:
				bosses[entry.stage-1]+=1
				if not entry.required_guardian:errors.append(path+".required_guardian: final guardian must remain required")
				if (entry.stage==2 and entry.archetype!="miniboss") or (entry.stage==3 and entry.archetype!="boss") or entry.stage==1:
					errors.append(path+".archetype: final guardian rank must match stage")
	for stage in range(3):
		if required[stage]<1:errors.append("encounters: stage %d needs at least one required guardian"%(stage+1))
		if stage>0 and bosses[stage]!=1:errors.append("encounters: stage %d needs exactly one final guardian"%(stage+1))
	return errors

func snapshot() -> LevelRunConfiguration:
	if not validation_errors().is_empty():return null
	# Explicitly clone external resources and array elements. A regular deep
	# duplicate can retain externally stored children and share editable data.
	var copy := LevelRunConfiguration.new()
	copy.schema_version=schema_version
	copy.id=id
	copy.mechanisms=mechanisms.duplicate(true) as LevelMechanismTuning
	for entry in encounters:copy.encounters.append(entry.duplicate(true) as LevelEncounterEntry)
	return copy
