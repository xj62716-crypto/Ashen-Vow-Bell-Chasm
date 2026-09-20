extends Resource
## Visual-only controls. No damage, collision size, timing or AI changes.
@export var tell_scale:float=1.0
@export var metal_color:Color=Color("d18b51")
@export var ritual_color:Color=Color("a48aa9")
@export var rune_energy:float=.8
@export var reaction_shards:int=20
@export var reaction_duration:float=.28
func valid()->bool:
	for value in [tell_scale,rune_energy,reaction_duration,metal_color.r,metal_color.g,metal_color.b,metal_color.a,ritual_color.r,ritual_color.g,ritual_color.b,ritual_color.a]:
		if not is_finite(value):return false
	return tell_scale>=.5 and tell_scale<=1.8 and rune_energy>=.1 and rune_energy<=2. and reaction_shards>=4 and reaction_shards<=32 and reaction_duration>=.1 and reaction_duration<=.6
