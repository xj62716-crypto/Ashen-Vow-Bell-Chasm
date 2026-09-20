class_name RuneCatalog
extends RefCounted

const ALL: Array[Dictionary] = [
	{"id":&"shade_slide_return","class":&"shade","name":"返月终式","path":"掠地破阵","requires":&"shade_slide_wind","effect":"同一次滑铲横劈实际处决两名敌人后，在原挥刀位置补出一次宽幅返斩；仍受遮挡限制。","color":Color("#e3bd72")},
	{"id":&"arcane_storm_tempest","class":&"arcanist","name":"巡天风暴","path":"风暴行者","requires":&"arcane_storm_chain","effect":"一次滞空命中三个不同目标，打断五米内可见威胁并恢复一次冲刺；每次落地后重置。","color":Color("#8dcde8")},
	{"id":&"arcane_seal_gate","class":&"arcanist","name":"末铭渡门","path":"封印术士","requires":&"arcane_seal_spread","effect":"一次手动连爆至少两个符印且处决至少两敌后，末端生成六秒悬锚作为后续移动节点。","color":Color("#c2a6e6")},
	{"id":&"shade_wall_chain","class":&"shade","name":"连壁","path":"飞檐猎杀","requires":&"shade_wall","effect":"空中墙跑增加至三段，同墙冲刺衔接计入，不自动恢复冲刺。","color":Color("#dd987d")},
	{"id":&"shade_wall_master","class":&"shade","name":"凌霄","path":"飞檐猎杀","requires":&"shade_wall_chain","effect":"空中墙跑增加至四段，每段独立计时。","color":Color("#dd987d")},
	{"id":&"shade_soul_node","class":&"shade","name":"猎魂悬锚","path":"飞檐猎杀","requires":&"shade_wall","effect":"空中击杀留下六秒魂锚，E 牵引借势；最多两个。","color":Color("#dd987d")},
	{"id":&"shade_duel_riposte","class":&"shade","name":"返锋剑气","path":"流刃决斗","requires":&"shade_parry","effect":"成功弹反后的下一次横劈释放有实体遮挡的远程剑气。","color":Color("#c3cbbb")},
	{"id":&"shade_slide_wind","class":&"shade","name":"掠地刃风","path":"掠地破阵","requires":&"shade_slide","effect":"滑铲跳后的横劈释放贴地刃风，实体遮挡生效。","color":Color("#e3bd72")},
	{"id":&"arcane_shape_recall","class":&"arcanist","name":"归墟震波","path":"裂隙塑形","requires":&"arcane_shape","effect":"达到上限后替换未承载玩家的旧构造，释放三米震波打断可见敌人。","color":Color("#78dfbf")},
	{"id":&"arcane_seal_spread","class":&"arcanist","name":"连铭","path":"封印术士","requires":&"arcane_seal","effect":"普通法术刻印向一个四米内可见活敌传播，不递归扩散，一次 Q 引爆。","color":Color("#c2a6e6")},
	{"id":&"arcane_storm","class":&"arcanist","name":"风暴行者","path":"法力 · 连锁机动","core":true,"effect":"滞空或墙跑移动产生法力；空中法术消耗法力破盾并连锁，命中延长漂浮和沿墙时间。Q 回收冲刺。","color":Color("#8dcde8")},
	{"id":&"arcane_shape","class":&"arcanist","name":"裂隙塑形","path":"创造 · 跑酷表面","core":true,"effect":"按住 Q 预览，松开生成临时墙、风井或牵引锚；Z 切换。每个消耗 30 法力，持续 12 秒，最多 3 个。","color":Color("#78dfbf")},
	{"id":&"arcane_seal","class":&"arcanist","name":"封印术士","path":"标记 · 路线引爆","core":true,"effect":"点按 Q 标记敌人或机关；长按 Q 引爆。高速接近标记也会触发，冻结周围敌人并处决核心。Boss 封印仍需机关。","color":Color("#c2a6e6")},
	{"id":&"arcane_element","class":&"arcanist","name":"元素塑能者","path":"元素 · 形态塑能","core":true,"effect":"法杖基础施法保持单一输入；祭坛获得火、冰、风或雷形态后改变弹道、控制和连锁方式，可与移动构筑混搭。","color":Color("#e6b27f")},
	{"id":&"shade_edge_fast","class":&"shade","name":"磨锋","path":"飞檐猎杀","requires":&"shade_wall","effect":"墙跑锋势积累速度提高 30%。","color":Color("#dd987d")},
	{"id":&"shade_hunt_range","class":&"shade","name":"鹰视","path":"飞檐猎杀","requires":&"shade_wall","effect":"蹬墙锁定距离由 16 米提高到 22 米。","color":Color("#dd987d")},
	{"id":&"shade_hunt_chain","class":&"shade","name":"连猎","path":"飞檐猎杀","requires":&"shade_wall","effect":"追身处决后恢复满格锋势，可衔接下一次蹬墙锁定。","color":Color("#dd987d")},
	{"id":&"shade_counter_range","class":&"shade","name":"越影","path":"返刃决斗","requires":&"shade_parry","effect":"弹反追身距离由 26 米提高至 32 米，仍受实体遮挡限制。","color":Color("#c3cbbb")},
	{"id":&"shade_counter_guard","class":&"shade","name":"断隙","path":"返刃决斗","requires":&"shade_parry","effect":"追身处决后获得 0.45 秒受击保护。","color":Color("#c3cbbb")},
	{"id":&"shade_slide_echo","class":&"shade","name":"掠影连斩","path":"掠地突袭","requires":&"shade_slide","effect":"滑铲跳后的横斩击杀刷新横斩窗口，可继续清理暴露核心。","color":Color("#e3bd72")},
	{"id":&"shade_slide_wave","class":&"shade","name":"扫阵","path":"掠地突袭","requires":&"shade_slide","effect":"滑铲跳横斩额外增加 2 米范围。","color":Color("#e3bd72")},
	{"id":&"arcane_storm_capacity","class":&"arcanist","name":"导流","path":"风暴行者","requires":&"arcane_storm","effect":"空中机动法力回复由每秒 17 提高至 23。","color":Color("#8dcde8")},
	{"id":&"arcane_storm_return","class":&"arcanist","name":"回响风暴","path":"风暴行者","requires":&"arcane_storm","effect":"空中命中回复的法力由 8 提高至 14。","color":Color("#8dcde8")},
	{"id":&"arcane_storm_chain","class":&"arcanist","name":"雷索","path":"风暴行者","requires":&"arcane_storm","effect":"连锁寻找距离扩大到 10 米，连接分散平台的敌人。","color":Color("#8dcde8")},
	{"id":&"arcane_shape_economy","class":&"arcanist","name":"薄界","path":"裂隙塑形","requires":&"arcane_shape","effect":"塑形消耗由 30 降低至 20 法力。","color":Color("#78dfbf")},
	{"id":&"arcane_shape_duration","class":&"arcanist","name":"定形","path":"裂隙塑形","requires":&"arcane_shape","effect":"临时构造持续时间延长至 20 秒。","color":Color("#78dfbf")},
	{"id":&"arcane_shape_capacity","class":&"arcanist","name":"织界","path":"裂隙塑形","requires":&"arcane_shape","effect":"可同时维持 5 个构造，搭建连续路线。","color":Color("#78dfbf")},
	{"id":&"arcane_shape_refund","class":&"arcanist","name":"回路","path":"裂隙塑形","requires":&"arcane_shape","effect":"首次使用临时墙面或牵引锚回复 15 法力，风井回复提高至 15。","color":Color("#78dfbf")},
	{"id":&"arcane_seal_capacity","class":&"arcanist","name":"七重符印","path":"封印术士","requires":&"arcane_seal","effect":"同时标记上限由 4 增至 7。","color":Color("#c2a6e6")},
	{"id":&"arcane_seal_range","class":&"arcanist","name":"远铭","path":"封印术士","requires":&"arcane_seal","effect":"标记射程 32 米，持续 22 秒。","color":Color("#c2a6e6")},
	{"id":&"arcane_seal_radius","class":&"arcanist","name":"霜封阵","path":"封印术士","requires":&"arcane_seal","effect":"引爆时周围冻结范围由 3 米增至 5 米。","color":Color("#c2a6e6")},
	{"id":&"arcane_seal_proximity","class":&"arcanist","name":"巡行敕令","path":"封印术士","requires":&"arcane_seal","effect":"高速经过时的自动引爆距离由 5 米增至 8 米。","color":Color("#c2a6e6")},
	{"id": &"shade_wall", "class": &"shade", "name": "飞檐血契", "path": "飞檐猎杀", "core": true, "effect": "墙跑积累锋势，超过半格后蹬墙锁敌；空中按 Q 追身处决，击杀刷新冲刺。蹬墙跳更高，下一刀可破盾。", "color": Color("#dd987d")},
	{"id": &"shade_slide", "class": &"shade", "name": "掠地血契", "path": "掠地突袭", "core": true, "effect": "增强滑铲和滑铲跳。滑铲后破盾，滑铲跳后 Q 或挥刀展开宽幅横斩，处理多个核心。", "color": Color("#e3bd72")},
	{"id": &"shade_parry", "class": &"shade", "name": "返刃血契", "path": "返刃决斗", "core": true, "effect": "延长弹反窗口。弹反弹体后 3 秒内按 Q 追身到射手并处决，恢复冲刺；实体墙会阻断追身。", "color": Color("#c3cbbb")},
	{"id": &"shade_echo", "class": &"shade", "name": "残影行者", "path": "残影 · 回溯猎杀", "core": true, "effect": "G 在合法历史锚点回溯约 1.5 秒，不回滚生命、世界或奖励；回溯位置可留下短暂残影诱导敌人，空中回溯可形成一次临时踏步。", "color": Color("#bda7d8")},
	{"id": &"shade_echo_decoy", "class": &"shade", "name": "诱影", "path": "残影行者", "requires": &"shade_echo", "effect": "回溯前的位置留下可被敌人锁定、射击或突进的残影；命中后消散，不会替玩家承受真实生命伤害。", "color": Color("#bda7d8")},
	{"id": &"shade_echo_step", "class": &"shade", "name": "踏影", "path": "残影行者", "requires": &"shade_echo", "effect": "空中回溯点生成短暂可碰撞踏步，允许回溯后接墙跑或滑铲跳，过期前有清晰消散预警。", "color": Color("#bda7d8")},
	{"id": &"shade_echo_cut", "class": &"shade", "name": "返身幻斩", "path": "残影行者", "requires": &"shade_echo", "effect": "回溯完成后，残影沿回溯路径末端补出一次幻影横斩；仍受视线和实际敌人碰撞限制。", "color": Color("#bda7d8")},
	{"id": &"shade_refund", "class": &"shade", "name": "残影刃", "path": "飞檐猎杀", "requires": &"shade_wall", "effect": "空中处决额外回馈半格锋势，可更快锁定下一名敌人。", "color": Color("#dd987d")},
	{"id": &"shade_reach", "class": &"shade", "name": "长锋", "path": "蹬墙跃升", "requires": &"shade_wall", "effect": "斩击距离提升至 3.6 米，扩大高处接敌范围。", "color": Color("#dd987d")},
	{"id": &"shade_slide_chain", "class": &"shade", "name": "疾掠", "path": "滑铲蓄势", "requires": &"shade_slide", "effect": "滑铲跳恢复冲刺。滑铲破盾处决后再次获得破盾斩。", "color": Color("#e3bd72")},
	{"id": &"shade_surge", "class": &"shade", "name": "逐地", "path": "滑铲蓄势", "requires": &"shade_slide", "effect": "滑铲再提速 2 米每秒，增强跨越远端落点的能力。", "color": Color("#e3bd72")},
	{"id": &"shade_counter", "class": &"shade", "name": "回锋", "path": "弹反突袭", "requires": &"shade_parry", "effect": "弹反后 3 秒内的近身处决重置弹反冷却。", "color": Color("#c3cbbb")},
	{"id": &"shade_rush", "class": &"shade", "name": "追猎", "path": "弹反突袭", "requires": &"shade_parry", "effect": "冲刺结束后保留更多速度，更快接近出现破绽的目标。", "color": Color("#c3cbbb")},
	{"id": &"shade_cleave", "class": &"shade", "name": "断月", "path": "横扫刀式", "core": true, "effect": "斩击展开为宽幅横扫，可同时处决正面多个已露出破绽的敌人。", "color": Color("#e2b887")},
	{"id": &"shade_arc", "class": &"shade", "name": "离刃", "path": "远程剑气", "core": true, "effect": "挥刀同时发出一道 14 米剑气，可远程处决无防护目标；封印与盾牌仍需破解。", "color": Color("#bccada")},
	{"id": &"shade_cleave_reach", "class": &"shade", "name": "大回环", "path": "横扫刀式", "requires": &"shade_cleave", "effect": "横扫范围扩大至 3.8 米。", "color": Color("#e2b887")},
	{"id": &"shade_cleave_break", "class": &"shade", "name": "裂甲连式", "path": "横扫刀式", "requires": &"shade_cleave", "effect": "每第三次挥刀可打破普通护盾，衔接近身处决。", "color": Color("#e2b887")},
	{"id": &"shade_arc_range", "class": &"shade", "name": "长虹", "path": "远程剑气", "requires": &"shade_arc", "effect": "剑气射程延长至 24 米。", "color": Color("#bccada")},
	{"id": &"shade_arc_split", "class": &"shade", "name": "双牙", "path": "远程剑气", "requires": &"shade_arc", "effect": "每次挥刀发出两道交错剑气。", "color": Color("#bccada")},
	{"id": &"arcane_fire", "class": &"arcanist", "name": "焚烬", "path": "火 · 爆裂法球", "core": true, "element": &"fire", "effect": "法球碰撞后在 3 米内爆炸，对视线可达、已失去防护的敌人造成范围处决。", "color": Color("#ed925a")},
	{"id": &"arcane_ice", "class": &"arcanist", "name": "凝霜", "path": "冰 · 冻结控制", "core": true, "element": &"ice", "effect": "冰刺命中普通护盾时冻结并破盾 1.6 秒，下一发处决；不冻结封印 Boss。", "color": Color("#8dd5f0")},
	{"id": &"arcane_fire_radius", "class": &"arcanist", "name": "燎原", "path": "火 · 爆裂法球", "requires": &"arcane_fire", "effect": "爆炸半径由 3 米扩大至 4.5 米。", "color": Color("#ed925a")},
	{"id": &"arcane_fire_shatter", "class": &"arcanist", "name": "熔甲", "path": "火 · 爆裂法球", "requires": &"arcane_fire", "effect": "爆炸先打破范围内普通护盾，再造成伤害；仍无法穿透墙壁或解除 Boss 封印。", "color": Color("#ed925a")},
	{"id": &"arcane_ice_duration", "class": &"arcanist", "name": "深寒", "path": "冰 · 冻结控制", "requires": &"arcane_ice", "effect": "冻结持续时间延长至 2.6 秒。", "color": Color("#8dd5f0")},
	{"id": &"arcane_ice_nova", "class": &"arcanist", "name": "冰葬", "path": "冰 · 冻结控制", "requires": &"arcane_ice", "effect": "处决冰冻敌人时向 3 米内可见目标扩散冻结。", "color": Color("#8dd5f0")},
	{"id": &"arcane_charge", "class": &"arcanist", "name": "雷行契印", "path": "空中充能", "core": true, "effect": "空中移动 0.7 秒充能。下一发法术破盾并连锁，命中恢复冲刺；每次落地重置。", "color": Color("#75c5de")},
	{"id": &"arcane_float", "class": &"arcanist", "name": "御风", "path": "风 · 漂浮施法", "core": true, "element": &"wind", "effect": "下落按住跳跃可漂浮 1.4 秒。风弹命中护盾时打断蓄势；漂浮射击可破盾。可与火、冰组合。", "color": Color("#b9d39b")},
	{"id": &"arcane_stride", "class": &"arcanist", "name": "长风契印", "path": "沿墙引流", "core": true, "effect": "沿墙速度提升、持续时间增加。蹬墙后下一次脉冲范围提升至 14 米。", "color": Color("#70cbb6")},
	{"id": &"arcane_network", "class": &"arcanist", "name": "雷网", "path": "空中充能", "requires": &"arcane_charge", "effect": "充能法术的连锁距离由 5 米提升至 9 米。", "color": Color("#75c5de")},
	{"id": &"arcane_conduit", "class": &"arcanist", "name": "疾雷", "path": "空中充能", "requires": &"arcane_charge", "effect": "空中充能时间缩短至 0.45 秒，更早处理下一个落点。", "color": Color("#75c5de")},
	{"id": &"arcane_split", "class": &"arcanist", "name": "裂星", "path": "漂浮施法", "requires": &"arcane_float", "effect": "法术分裂为三枚散射弹，可同时处理多个落点威胁。", "color": Color("#b9d39b")},
	{"id": &"arcane_suspend", "class": &"arcanist", "name": "长夜悬星", "path": "漂浮施法", "requires": &"arcane_float", "effect": "漂浮时长增加至 2.2 秒，扩大横越深渊的距离。", "color": Color("#b9d39b")},
	{"id": &"arcane_power", "class": &"arcanist", "name": "破界脉冲", "path": "沿墙引流", "requires": &"arcane_stride", "effect": "脉冲冷却由 3 秒缩短至 2 秒。", "color": Color("#70cbb6")},
	{"id": &"arcane_updraft", "class": &"arcanist", "name": "回旋上升", "path": "沿墙引流", "requires": &"arcane_stride", "effect": "蹬墙跳跃高度提升，可转移到更高的射击位置。", "color": Color("#70cbb6")},
]

static func definition(id: StringName) -> Dictionary:
	for rune in ALL:
		if rune.id == id:
			return _current(rune)
	return {}

const CORE_IDS := {&"shade": [&"shade_parry", &"shade_wall", &"shade_slide", &"shade_echo"], &"arcanist": [&"arcane_storm", &"arcane_shape", &"arcane_seal", &"arcane_element"]}
const PARENTS := {&"shade_cleave": &"shade_slide", &"shade_arc": &"shade_parry", &"arcane_fire": &"arcane_element", &"arcane_ice": &"arcane_element", &"arcane_float": &"arcane_element", &"arcane_charge": &"arcane_element", &"arcane_stride": &"arcane_storm"}

static func _current(source: Dictionary) -> Dictionary:
	var rune := source.duplicate(true)
	rune.core = rune.id in CORE_IDS.get(rune["class"], [])
	if PARENTS.has(rune.id): rune.requires = PARENTS[rune.id]
	if rune.id == &"arcane_element": rune.effect = "默认获得爆裂火球。后续祭坛选择冰、风、雷可改变主法术；混合元素保留控制与范围联动，无需战斗中切技能盘。"
	if rune.id == &"arcane_shape": rune.effect = "按住 Q 显示落点，松开塑形；垂直面生成跑墙，地面生成风井，向上生成悬锚，下方虚空生成浮台。直接攻击始终可用。"
	if rune.id == &"arcane_seal": rune.effect = "普通法术命中自动刻印，Q 引爆可见符印；瞄准机关点 Q 可标记。移动经过符印触发冻结与核心处决。"
	if rune.id == &"shade_echo": rune.effect = "G 沿合法历史返回约 1.5 秒前的位置，保持当前视角；不回滚生命、击杀、世界或冲刺。后续可获得诱饵、踏步和幻影补刀。"
	if rune.id == &"shade_wall": rune.effect = "蹬墙锁定视线内敌人，空中 Q 追身处决；击杀恢复冲刺。无需先积满锋势；普通挥刀始终可用。"
	if rune.id == &"shade_parry": rune.path="流刃决斗"
	if rune.id == &"shade_slide": rune.path="掠地破阵"
	if rune.id == &"shade_echo_cut": rune.effect="回溯后重放最近 1.8 秒内实际挥出的横斩，按原始位置、朝向和范围命中；受实体遮挡限制，不凭空生成攻击。"
	if rune.id == &"arcane_ice": rune.effect="冰枪击中护盾时先控制并破盾；再次命中处决。对首领转为短打断和失衡积累。"
	if rune.id == &"arcane_storm": rune.effect="空中法术消耗法力破盾并连锁。每个空中序列中对同一目标首次有效命中获得抬升、法力和沿墙时间；Q 回收冲刺。"
	return rune

static func core_ids(profile_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for rune in ALL:
		if rune.get("class", &"") == profile_id and rune.id in CORE_IDS.get(profile_id, []):
			ids.append(rune.id)
	return ids

static func available(profile_id: StringName, acquired: Array[StringName]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in ALL:
		var rune := _current(source)
		if rune.get("class", &"") != profile_id or rune.id in acquired:
			continue
		var requires: StringName = rune.get("requires", &"")
		if requires != &"" and requires not in acquired:
			continue
		result.append(rune)
	return result

static func offer(profile_id: StringName, acquired: Array[StringName], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var eligible := available(profile_id, acquired)
	var cores: Array[Dictionary] = []
	var extensions: Array[Dictionary] = []
	for rune in eligible:
		if rune.get("core", false): cores.append(rune)
		else: extensions.append(rune)
	var result: Array[Dictionary] = []
	# The first altar intentionally offers three of the four distinct loops. It is
	# seeded by the run RNG, so a player cannot be forced into a single opening.
	# Later altars guarantee one legal synergy when one exists, then fill with
	# unowned cores/branches. Every returned option is executable immediately.
	if acquired.is_empty():
		var opening := cores.duplicate()
		while not opening.is_empty() and result.size() < 3:
			result.append(opening.pop_at(rng.randi_range(0, opening.size()-1)))
		return result
	if not extensions.is_empty():
		result.append(extensions.pop_at(rng.randi_range(0, extensions.size()-1)))
	var pool: Array[Dictionary] = []
	pool.append_array(cores)
	pool.append_array(extensions)
	while not pool.is_empty() and result.size() < 3:
		result.append(pool.pop_at(rng.randi_range(0, pool.size()-1)))
	return result

static func title(id: StringName) -> String:
	return str(definition(id).get("name", ""))
