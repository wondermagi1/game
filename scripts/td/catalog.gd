extends RefCounted
## All numbers belong to the local defense run. Rank is always 1..4.
const MAX_LEVEL = 4
const ROMAN = ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ"]
const UPGRADES = [35, 55, 85]
## Authored atlas silhouettes are not evenly spaced. UV regions isolate each prop
## without changing generated pixels or cropping off weapon tips.
const REGIONS = [Rect2(84,7,267,366),Rect2(432,30,307,342),Rect2(802,81,314,282),Rect2(1199,7,299,367),Rect2(39,382,322,307),Rect2(432,374,312,307),Rect2(805,380,314,305),Rect2(1190,381,310,303),Rect2(12,710,375,297),Rect2(421,685,334,322),Rect2(800,685,334,330),Rect2(1178,681,343,326)]
const COLORS = [Color("#9fe9e0"), Color("#bcdcea"), Color("#f3b676"), Color("#c4b1ef"), Color("#edaa72"), Color("#a5ddec"), Color("#b4a1e7"), Color("#d6c89a"), Color("#acd09c"), Color("#a4dfda"), Color("#bda6ed"), Color("#f0d795")]
const FACILITIES = [
 {"name":"飞剑法阵", "cost":45, "range":285, "damage":25, "interval":1.15, "tag":"穿刺 · 追击", "steps":["释放实体飞剑", "飞剑贯穿两名敌人", "双剑交替，攻速提升", "每四轮召唤三枚追击飞剑"]},
 {"name":"符文弩塔", "cost":40, "range":320, "damage":30, "interval":1.5, "tag":"远程 · 贯穿", "steps":["发射符文弩矢", "射程、攻速提升", "贯穿三名敌人", "每三轮发射三倍重弩"]},
 {"name":"炼金炮台", "cost":60, "range":280, "damage":30, "interval":2.1, "tag":"范围 · 灼烧", "steps":["炼金弹爆炸半径85", "爆炸范围扩大", "留下持续灼烧区域", "每三轮触发三连爆"]},
 {"name":"雷鸣尖塔", "cost":60, "range":240, "damage":22, "interval":1.45, "tag":"连锁 · 感电", "steps":["雷击一名敌人", "连锁两名敌人", "连锁四名敌人", "每三轮风暴连锁七名敌人"]},
 {"name":"龙息喷口", "cost":55, "range":190, "damage":14, "interval":0.85, "tag":"扇形 · 破甲", "steps":["向最近目标喷吐龙息", "扩大龙息扇形", "灼烧并削弱护甲", "每三轮双倍龙息"]},
 {"name":"寒霜碑", "cost":45, "range":180, "damage":6, "interval":2.3, "tag":"减速 · 冻结", "steps":["范围减速", "减速范围扩大", "三次命中短暂冻结", "冻结时追加寒霜爆破"]},
 {"name":"引力符井", "cost":50, "range":170, "damage":6, "interval":2.0, "tag":"聚怪 · 冲击", "steps":["牵引普通敌人", "牵引力度提升", "聚怪并造成冲击", "每三轮强引力脉冲"]},
 {"name":"守护石像", "cost":45, "range":150, "damage":12, "interval":1.5, "tag":"拦截 · 反击", "steps":["吸引附近敌人攻击", "耐久上限提升", "获得护盾减伤", "反击并每秒自我修复"]},
 {"name":"荆棘地阵", "cost":40, "range":120, "damage":12, "interval":1.2, "tag":"持续 · 定身", "steps":["刺伤范围内敌人", "荆棘范围扩大", "每三次命中定身", "定身时追加爆发伤害"]},
 {"name":"治愈圣泉", "cost":45, "range":190, "damage":0, "interval":3.5, "tag":"治疗 · 净化", "steps":["治疗范围内的角色", "治疗量提升", "净化角色减速", "治疗时附加临时护盾"]},
 {"name":"共鸣水晶", "cost":50, "range":245, "damage":0, "interval":6.0, "tag":"增伤 · 加速", "steps":["附近攻击设施伤害+12%", "扩大支援范围", "周期提供攻速脉冲", "周期超载最近攻击设施"]},
 {"name":"灵能采集器", "cost":65, "range":200, "damage":0, "interval":6.0, "tag":"经济 · 折扣", "steps":["每波结束收获18灵能", "每波收获30灵能", "附近击杀额外+2灵能", "全场建造升级折扣12%"]}
]

static func definition(id: int) -> Dictionary:
	return FACILITIES[clampi(id,0,11)]

static func reach(id: int, rank: int) -> float:
	return float(definition(id).range) + (rank-1)*(25.0 if id!=8 else 16.0)

static func damage(id: int, rank: int) -> float:
	return float(definition(id).damage)*(1.0+0.42*(rank-1))

static func interval(id: int, rank: int) -> float:
	return maxf(0.25,float(definition(id).interval)*(1.0-0.09*(rank-1)))

static func wave_plan(index: int) -> Array:
	# Two lanes remain relevant; heavy enemies alternate with fast runners.
	var result: Array = []
	var count = [18,26,32][clampi(index-1,0,2)]
	for i in range(count):
		var kind = 3 if i%7==6 else (1 if i%4==3 else 0)
		result.append({"kind":kind,"lane":i%2,"elite":index==3 and i%8==7})
	return result
