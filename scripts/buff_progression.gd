extends RefCounted
## Stack counts are uncapped in abyss; physical objects and probability are bounded.
const MILESTONES = [5,10,20,40]
const DEFENSE = ["hp","armor","shield","revive","healing","kill_heal","stage_heal","heal"]
const MOBILITY = ["speed_pct","dash_cooldown","kill_speed","pickup"]
static func tier(count: int) -> int:
	var result = 0
	for level in MILESTONES:
		if count>=level: result += 1
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
	return "主线保留原层数上限；深渊无限累计。5 / 10 / 20 / 40 层进阶，每个节点额外攻击 +10%。\n"+family(key)+"进阶："+mechanism+"\n满阶后仍获得每层基础收益。超额数量与概率转伤害，布尔效果追加层转攻击 +6%。"
