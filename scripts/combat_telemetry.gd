extends RefCounted
## Lightweight per-run telemetry. It is saved only inside an exploration snapshot
## and never changes combat resolution or random-number consumption.

var damage_by_source: Dictionary = {}
var kills_by_kind: Dictionary = {}
var rewards: Array[String] = []
var rooms: Array[String] = []
var damage_taken := 0.0
var healing := 0.0
var critical_hits := 0
var hits := 0
var elite_kills := 0
var boss_kills := 0
var rerolls := 0
var gear_found := 0

func reset() -> void:
	damage_by_source.clear()
	kills_by_kind.clear()
	rewards.clear()
	rooms.clear()
	damage_taken = 0
	healing = 0
	critical_hits = 0
	hits = 0
	elite_kills = 0
	boss_kills = 0
	rerolls = 0
	gear_found = 0

func record_damage(amount: float, source: String, critical: bool = false) -> void:
	if amount<=0: return
	var key = source if not source.is_empty() else "其他伤害"
	damage_by_source[key] = float(damage_by_source.get(key,0))+amount
	hits += 1
	if critical: critical_hits += 1

func record_enemy(enemy) -> void:
	var key = str(enemy.kind)
	kills_by_kind[key] = int(kills_by_kind.get(key,0))+1
	if enemy.elite: elite_kills += 1
	if enemy.is_boss(): boss_kills += 1

func record_room(room: Dictionary) -> void:
	var id = str(room.get("id",""))
	if rooms.is_empty() or rooms.back()!=id: rooms.append(id)

func record_reward(choice: Array) -> void:
	if choice.size()>1: rewards.append(str(choice[1]))

func damage_lines(limit: int = 6) -> Array[String]:
	var entries: Array = []
	var total := 0.0
	for key in damage_by_source:
		var amount = float(damage_by_source[key])
		total += amount
		entries.append([key,amount])
	entries.sort_custom(func(a,b): return a[1]>b[1])
	var lines: Array[String] = []
	for i in range(mini(limit,entries.size())):
		var entry: Array = entries[i]
		lines.append("%s  %.0f  (%d%%)"%[source_name(entry[0]),entry[1],roundi(entry[1]*100.0/maxf(1,total))])
	return lines

func source_name(source: String) -> String:
	var names = {"normal":"普通攻击","status":"持续伤害","explosion":"范围爆炸","skill_0":"技能 E","skill_1":"技能 Q","skill_2":"技能 F","skill_3":"终极技能 C","skill":"技能伤害"}
	return names.get(source,source)

func snapshot() -> Dictionary:
	return {"damage_by_source":damage_by_source.duplicate(true),"kills_by_kind":kills_by_kind.duplicate(true),"rewards":rewards.duplicate(),"rooms":rooms.duplicate(),"damage_taken":damage_taken,"healing":healing,"critical_hits":critical_hits,"hits":hits,"elite_kills":elite_kills,"boss_kills":boss_kills,"rerolls":rerolls,"gear_found":gear_found}

func restore(data: Dictionary) -> void:
	reset()
	damage_by_source = data.get("damage_by_source",{}).duplicate(true)
	kills_by_kind = data.get("kills_by_kind",{}).duplicate(true)
	rewards.assign(data.get("rewards",[]))
	rooms.assign(data.get("rooms",[]))
	for key in ["damage_taken","healing","critical_hits","hits","elite_kills","boss_kills","rerolls","gear_found"]:
		set(key,data.get(key,get(key)))
