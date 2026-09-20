extends Resource
@export var width:float=450
@export var top:float=78
@export var opacity:float=.94
@export var gold:Color=Color("bca172")
@export var ivory:Color=Color("e4d6b8")
@export var warning:Color=Color("d99b88")
@export var reduced_motion:bool=false
func valid()->bool:
	for value in [width,top,opacity,gold.r,gold.g,gold.b,gold.a,ivory.r,ivory.g,ivory.b,ivory.a,warning.r,warning.g,warning.b,warning.a]:
		if not is_finite(value):return false
	return width>=330 and width<=580 and top>=54 and top<=150 and opacity>=.65 and opacity<=1.
