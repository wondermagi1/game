extends RefCounted
## Stack counts are uncapped in abyss; physical objects and probability are bounded.
const MILESTONES = [3,5,10,20]
const STAGE_NAMES = ["未觉醒","基础强化","追加机制","形态变化","高级质变"]
const DEFENSE = ["hp","armor","shield","revive","healing","kill_heal","stage_heal","heal"]
const MOBILITY = ["speed_pct","dash_cooldown","kill_speed","pickup"]
static func tier(count: int) -> int:
	var result = 0
	for level in MILESTONES:
		if count>=level: result += 1
	return result
static func power_nodes(count: int) -> int:
	# Mechanic tiers stay bounded, while every ten stacks after 20 grants a safe
	# numerical breakthrough. This keeps endless growth without spawning more objects.
	return tier(count)+maxi(0,floori((count-20)/10.0))
static func next_milestone(count: int) -> int:
	for level in MILESTONES:
		if count<level: return level
	return 30+maxi(0,floori((count-20)/10.0))*10
static func stage_name(count: int) -> String:
	if count>20: return "循环突破 %d"%maxi(1,floori((count-20)/10.0)+1)
	return STAGE_NAMES[tier(count)]
static func progress_text(count: int) -> String:
	return "%s · 下一进阶 %d 层（还差 %d）"%[stage_name(count),next_milestone(count),next_milestone(count)-count]
static func crossed(previous: int, current: int) -> Array[int]:
	var result: Array[int] = []
	for level in MILESTONES:
		if previous<level and current>=level: result.append(level)
	var cycle = 30
	while cycle<=current:
		if previous<cycle: result.append(cycle)
		cycle += 10
	return result
static func family(key: String) -> String:
	if key in DEFENSE: return "守护"
	if key in MOBILITY: return "疾行"
	return "共鸣"
static func description(key: String) -> String:
	var mechanism = "每 3 秒发射 2/3/4/5 道共鸣弹，伤害 35/70/105/140% 攻击；可穿透 1/2/3/4 个目标。"
	if family(key)=="守护": mechanism = "每 8 秒获得最大生命 3/6/9/12% 护盾，持续 4 秒；取本系最高阶，不叠加无限护盾。"
	if family(key)=="疾行": mechanism = "闪避追加半径 100/140/180/220 的冲击，造成 40/80/120/160% 攻击；每次闪避一次。"
	if key=="burn": mechanism += " 燃烧每层强化持续伤害，5层后直接击杀燃烧目标追加80%爆破（1秒间隔，不递归）。"
	if key=="shield": mechanism += " 5层后护盾抵伤追加60%反击；恢复间隔随层数递减，最低2.5秒。"
	if key=="revive": mechanism += " 深渊整次挑战仅复活一次，额外层提高恢复生命（最高60%）并转化攻击。"
	return "主线保留原层数上限；深渊无限累计。3 / 5 / 10 / 20 层依次获得基础强化、追加机制、形态变化和高级质变。\n"+family(key)+"进阶："+mechanism+"\n20 层后每 10 层循环突破；继续获得基础收益，并把受工程上限限制的数量与概率安全转化为攻击。"
