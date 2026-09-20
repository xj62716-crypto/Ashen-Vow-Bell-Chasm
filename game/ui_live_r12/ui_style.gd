extends Resource
## Q83: visual settings only; these do not change resources, physics or damage.
@export_range(0.35, 1.0) var hud_opacity: float = 0.94
@export_range(0.6, 1.0) var focus_strength: float = 0.92
@export_range(0.05, 0.3) var focus_enter_seconds: float = 0.06
@export_range(0.05, 0.4) var focus_exit_seconds: float = 0.10
@export_range(1.0, 5.0) var notice_seconds: float = 2.2
@export var reduced_motion: bool = false
@export var gold: Color = Color("bca172")
@export var ivory: Color = Color("e4d6b8")
@export var muted: Color = Color("b2a58e")
@export var danger: Color = Color("d99b88")
@export_range(0.2, 0.8) var hud_backing: float = 0.62

func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for row in [["hud_opacity",0.35,1.0],["hud_backing",0.2,0.8],["focus_strength",0.6,1.0],["focus_enter_seconds",0.05,0.3],["focus_exit_seconds",0.05,0.4],["notice_seconds",1.0,5.0]]:
		var value: float = get(row[0])
		if not is_finite(value) or value < row[1] or value > row[2]: errors.append(str(row[0])+": outside supported range")
	for field in ["gold","ivory","muted","danger"]:
		var color: Color = get(field)
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a): errors.append(field+": non-finite color")
	return errors
