extends RefCounted
const Data = preload("res://scripts/data.gd")
const Evolution = preload("res://scripts/buff_progression.gd")
var abyss: bool = false
var role: int = 0
var base: Dictionary
var bonuses: Dictionary = {}
var stacks: Dictionary = {}
var permanent: Dictionary = {}

func _init(index: int = 0) -> void:
	role = index
	base = Data.ROLES[index].duplicate(true)

func raw_bonus(key: String) -> float:
	return clampf(float(bonuses.get(key,0.0))+float(permanent.get(key,0.0)),0,1.0e12)

func bonus(key: String) -> float:
	var raw = raw_bonus(key)
	if not abyss: return raw
	if key in ["cooldown","dash_cooldown","reload"]: return 0.8*raw/(0.8+raw)
	var limits = {"multishot":6.0,"pierce":8.0,"bounce":6.0,"magazine":24.0,"blast":300.0,"orbit":8.0,"pickup":900.0,"projectile_pct":2.0,"kill_speed":0.6,"kill_rate":2.0}
	return minf(raw,limits[key]) if limits.has(key) else raw

func evolution_tier(family_name: String) -> int:
	if not abyss: return 0
	var result = 0
	for u in Data.UPGRADES:
		if Evolution.family(u[3])==family_name: result = maxi(result,Evolution.tier(int(stacks.get(u[0],0))))
	return result

func overflow_power() -> float:
	if not abyss: return 0
	var extra = 0.0
	for key in ["multishot","pierce","bounce","magazine","blast","orbit","pickup","projectile_pct","kill_speed","kill_rate"]:
		extra += maxf(0,raw_bonus(key)-bonus(key))*(0.002 if key in ["blast","pickup"] else 0.06)
	for key in ["shield","revive","burn","poison","return"]: extra += maxf(0,raw_bonus(key)-1)*0.06
	extra += maxf(0,float(base.crit)+raw_bonus("crit")-0.8)
	extra += maxf(0,float(base.rate)*(1+raw_bonus("rate_pct"))-12.5)*0.05
	extra += maxf(0,float(base.speed)*(1+raw_bonus("speed_pct"))-650)*0.0005
	for u in Data.UPGRADES: extra += Evolution.tier(int(stacks.get(u[0],0)))*0.1
	return extra

func value(key: String) -> float:
	var start = float(base.get(key, 0.0)) + bonus(key)
	if key in ["attack","speed","range","rate"]:
		start *= 1.0 + bonus(key + "_pct")
	if key=="attack": start *= 1+overflow_power()
	start = clampf(start,0,1.0e15)
	match key:
		"crit": return clampf(start, 0.0, 0.8)
		"speed": return minf(start, 650.0)
		"rate": return clampf(start, 0.25, 12.5)
		"armor": return 400.0*start/(400.0+start) if abyss else clampf(start,0.0,80.0)
	return start

func apply(upgrade: Array) -> void:
	var key: String = upgrade[3]
	if key != "heal":
		# Run buffs must never absorb persistent equipment/talent bonuses.
		bonuses[key] = float(bonuses.get(key,0.0)) + float(upgrade[4])
	stacks[upgrade[0]] = int(stacks.get(upgrade[0], 0)) + 1

func eligible(u: Array) -> bool:
	if int(u[7]) != -1 and int(u[7]) != role: return false
	if abyss: return true
	if int(stacks.get(u[0], 0)) >= int(u[5]): return false
	if u[3] == "crit" and value("crit") >= 0.8: return false
	if u[3] == "armor" and value("armor") >= 80.0: return false
	if u[3] == "speed_pct" and value("speed") >= 650.0: return false
	return true

func reward_choices(rng: RandomNumberGenerator, current_health: float = -1.0, round_end: bool = false) -> Array:
	var pool: Array = []
	for u in Data.UPGRADES:
		if eligible(u):
			if u[3] == "heal" and current_health >= value("hp"): continue
			pool.append(u)
	var result: Array = []
	for slot in range(3):
		if pool.is_empty(): break
		var total = 0.0
		var weights: Array[float] = []
		for u in pool:
			var w: float = [6.0,3.0,1.0][int(u[6])]
			if int(u[7]) == role: w *= 1.3
			if round_end and int(u[6])>0: w *= 1.4
			weights.append(w)
			total += w
		var roll = rng.randf() * total
		var selected = pool.size() - 1
		for i in range(pool.size()):
			roll -= weights[i]
			if roll <= 0.0:
				selected = i
				break
		result.append(pool[selected])
		pool.remove_at(selected)
	while result.size()<3:
		var n = result.size()
		result.append(["supply_%d"%n,"金币补给","获得 40 金币（永久保留）","gold",40.0,999,0,-1])
	return result
