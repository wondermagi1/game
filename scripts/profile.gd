extends RefCounted
## Persistent profile + small inventory/economy services. Never stores run buffs.
const C = preload("res://scripts/catalog.gd")
const V7 = preload("res://scripts/v7_catalog.gd")
var data: Dictionary = {}
var path: String = "user://profile_v2.json"
var memory_only: bool = false
var dirty: bool = false
var read_only: bool = false
var notice: String = ""
var events: Array = []

func fresh() -> void:
	data = {"version":5,"gold":80,"material":3,"v3_grant":true,"v7_migrated":true,"v7_gear_migrated":true,"favorites":{},"abyss_best":[0,0,0],"checkpoint":{},"next_id":1,"roles":[],"inventory":[],"overflow":[],"consumables":{"potion":3,"barrier":1},"quick":["potion","barrier","thunder"],"unlocked":1,"cleared":[],"found":{},"seen":{},"achievements":{},"claimed":{},"legend_misses":0,"exploration":{},"boss_misses":0,"secret":false,"chapter_pity":{},"camp_dialogue":{}}
	for role in range(3):
		data.roles.append({"level":1,"xp":0,"talents":{},"skills":[1,1,1,1],"spent":0,"resets":0,"equipped":{}})
		var rng = RandomNumberGenerator.new()
		rng.seed = 20+role
		var item = make_item(role,0,0,1,rng)
		item.set_piece = false
		item.starter = true
		receive_item(item)
		data.roles[role].equipped["0"] = item.uid
	dirty = true

func read_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path): return {}
	var f = FileAccess.open(file_path,FileAccess.READ)
	if f == null: return {}
	var parser = JSON.new()
	if parser.parse(f.get_as_text()) != OK: return {}
	var wrapper = parser.data
	if not wrapper is Dictionary or not wrapper.has("payload") or not wrapper.has("checksum"): return {}
	if not wrapper.payload is String or wrapper.payload.sha256_text() != wrapper.checksum: return {}
	if parser.parse(wrapper.payload) != OK: return {}
	var d = parser.data
	if not d is Dictionary: return {}
	if not d.has("roles") or not d.roles is Array or d.roles.size()!=3: return {}
	if not d.get("inventory") is Array or not d.get("consumables") is Dictionary: return {}
	for key in ["gold","material","next_id","unlocked"]:
		if not d.get(key) is float and not d.get(key) is int: return {}
		if float(d[key])<0: return {}
	for key in ["found","achievements","claimed"]:
		if not d.get(key) is Dictionary: return {}
	if not d.get("cleared") is Array: return {}
	for r in d.roles:
		if not r is Dictionary or not r.get("equipped") is Dictionary or not r.get("skills") is Array or r.skills.size()!=4: return {}
		if not r.get("talents") is Dictionary: return {}
		for key in ["level","xp","spent"]:
			if not r.get(key) is float and not r.get(key) is int: return {}
		for rank in r.skills:
			if not rank is float and not rank is int: return {}
			if rank<1 or rank>C.MAX_SKILL: return {}
	var ids: Dictionary = {}
	var all_items: Array = d.inventory.duplicate()
	if d.has("overflow"):
		if not d.overflow is Array: return {}
		all_items.append_array(d.overflow)
	for item in all_items:
		if not item is Dictionary: return {}
		if not item.get("uid") is String or ids.has(item.uid): return {}
		ids[item.uid] = true
		for key in ["role","slot","quality","level","enhance","created"]:
			if not item.get(key) is float and not item.get(key) is int: return {}
		if item.role<0 or item.role>2 or item.slot<0 or item.slot>5 or item.quality<0 or item.quality>3 or item.enhance<0 or item.enhance>10: return {}
		if not item.get("affixes") is Array or not item.get("locked") is bool: return {}
		for affix in item.affixes:
			if not affix is Dictionary or not affix.get("key") is String: return {}
			if not affix.get("amount") is float and not affix.get("amount") is int: return {}
	return d

func load_profile() -> void:
	if memory_only:
		fresh()
		return
	var loaded = read_file(path)
	if loaded.is_empty():
		loaded = read_file(path+".bak")
		if not loaded.is_empty(): notice = "存档备份已恢复。"
	if loaded.is_empty():
		if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
			read_only = true
			notice = "存档读取失败：原文件已保留。本次使用临时档，不会覆盖旧进度。"
		fresh()
		return
	if int(loaded.get("version",1)) > C.VERSION:
		read_only = true
		notice = "此存档来自更新版本，已禁止写入以保护进度。"
	data = loaded
	# JSON numbers deserialize as floats; normalize stable integer IDs before Array.has.
	data.cleared = data.cleared.map(func(value): return int(value))
	# Additive migration: stable equipment IDs and role records are retained.
	for pair in [["overflow",[]],["seen",{}],["claimed",{}],["boss_misses",0],["secret",false],["quick",["potion","barrier","thunder"]]]:
		if not data.has(pair[0]): data[pair[0]] = pair[1]
	for r in data.roles:
		r.level = clampi(int(r.level),1,C.MAX_LEVEL)
		r.xp = maxi(0,int(r.xp))
		r.resets = int(r.get("resets",0))
		r.skills = r.skills.map(func(value): return int(value))
	# Idempotent migration: retain equipment IDs, ranks, spent points and currencies.
	if not data.get("v3_grant",false):
		data.material += 3
		data.v3_grant = true
		notice = "第三版已更新：赠送 3 份强化材料。原有装备与进度保留。"
	for pair in [["favorites",{}],["abyss_best",[0,0,0]],["checkpoint",{}]]:
		if not data.has(pair[0]): data[pair[0]] = pair[1]
	if data.cleared.has(4): data.unlocked = maxi(5,int(data.unlocked))
	if data.cleared.has(5): data.unlocked = 6
	if not data.has("legend_misses"): data.legend_misses = 0
	if not data.has("exploration"): data.exploration = {}
	if not data.has("chapter_pity"): data.chapter_pity = {}
	if not data.has("camp_dialogue"): data.camp_dialogue = {}
	if not data.get("v7_migrated",false):
		data.v7_migrated = true
		notice = "第七版构筑系统已启用：旧角色、装备、天赋、货币和章节进度均已保留。"
	if not data.get("v7_gear_migrated",false):
		for item in data.inventory+data.overflow:
			if int(item.quality)>=2 and not item.has("mechanic"):
				var branch_index = int(item.slot)%3
				item.mechanic = V7.gear_mechanic(int(item.role),branch_index).id
				item.build_branch = branch_index
		data.v7_gear_migrated = true
	if int(data.get("version",1))<4: notice = "第四版成长已补齐：每级 2 点，5–30 级每 5 级额外 2 点；原有投入保留。"
	data.version = C.VERSION
	dirty = true

func save_profile() -> bool:
	if memory_only:
		dirty = false
		return true
	if read_only: return false
	var payload = JSON.stringify(data)
	var f = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f == null:
		notice = "保存失败：无法写入存档，请检查磁盘权限。"
		return false
	f.store_string(JSON.stringify({"payload":payload,"checksum":payload.sha256_text()}))
	f.flush()
	f.close()
	var absolute = ProjectSettings.globalize_path(path)
	if not read_file(path).is_empty():
		var copied = DirAccess.copy_absolute(absolute,absolute+".bak")
		if copied != OK:
			notice = "保存失败：无法建立备份，旧存档已保留。"
			return false
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(absolute) != OK: return false
	if DirAccess.rename_absolute(absolute+".tmp",absolute) != OK:
		notice = "存档替换失败，可以从备份恢复。"
		return false
	dirty = false
	return true

func make_item(role: int, slot: int, quality: int, level: int, rng: RandomNumberGenerator, hidden: bool = false) -> Dictionary:
	var item = {"uid":"gear_%d" % int(data.next_id),"role":role,"slot":slot,"quality":quality,"level":clampi(level,1,C.MAX_LEVEL),"enhance":0,"locked":false,"hidden":hidden,"set_piece":true,"affixes":[],"paid_material":0,"created":int(data.next_id)}
	data.next_id = int(data.next_id)+1
	var pool = C.AFFIXES.duplicate(true)
	for i in range([0,1,2,2][quality]):
		var at = rng.randi_range(0,pool.size()-1)
		item.affixes.append(pool.pop_at(at))
	if quality>=2:
		var branch_index = rng.randi_range(0,2)
		item.mechanic = V7.gear_mechanic(role,branch_index).id
		item.build_branch = branch_index
	return item

func item_name(item: Dictionary) -> String:
	if item.get("starter",false): return ["练习飞剑","旧式火枪","练习长弓"][int(item.role)]
	if item.get("hidden",false): return ["镜渊剑心","镜渊火种","镜渊星瞳"][int(item.role)]
	return C.NAMES[int(item.role)][int(item.slot)]

func item_stats(item: Dictionary) -> Dictionary:
	var result: Dictionary = C.SLOT_STATS[int(item.slot)].duplicate(true)
	var multiplier = C.QUALITY_SCALE[int(item.quality)]*(1.0+0.025*(int(item.level)-1))*(1.0+0.03*int(item.enhance))
	for key in result: result[key] *= multiplier
	for affix in item.affixes:
		result[affix.key] = float(result.get(affix.key,0))+float(affix.amount)
	return result

func item_by_id(uid: String) -> Dictionary:
	for item in data.inventory:
		if item.uid == uid: return item
	return {}

func is_equipped(uid: String) -> bool:
	for r in data.roles:
		if uid in r.equipped.values(): return true
	return false

func discover(id: String) -> void:
	if not data.found.has(id):
		data.found[id] = true
		dirty = true

func receive_item(item: Dictionary) -> bool:
	if not item_by_id(item.uid).is_empty(): return false
	for held in data.overflow:
		if held.uid == item.uid: return false
	if data.inventory.size() >= C.CAPACITY:
		data.overflow.append(item)
		notice = "背包已满：装备已存入战利品暂存，可在装备界面领取。"
	else:
		data.inventory.append(item)
	discover("gear_%d_%d" % [item.role,item.slot])
	discover("gear_%d_%d_%d" % [item.role,item.slot,item.quality])
	if item.get("hidden",false): discover("hidden_%d" % item.role)
	if int(item.quality)==3:
		unlock("legend")
		events.append({"title":"传奇掉落","text":item_name(item)})
	dirty = true
	return true

func claim_overflow() -> int:
	var count = 0
	while data.inventory.size()<C.CAPACITY and not data.overflow.is_empty():
		data.inventory.append(data.overflow.pop_front())
		count += 1
	dirty = count>0 or dirty
	return count

func equip(role: int, uid: String) -> String:
	var item = item_by_id(uid)
	if item.is_empty(): return "装备不存在"
	if int(item.role)!=role: return "这件装备属于另一角色"
	if int(data.roles[role].level)<int(item.level): return "角色等级不足"
	var before_set = set_count(role)
	data.roles[role].equipped[str(int(item.slot))] = uid
	for threshold in [2,4,6]:
		if before_set<threshold and set_count(role)>=threshold: events.append({"title":"套装激活","text":C.SETS[role]+" · %d 件效果"%threshold})
	if set_count(role)>=2: discover("set_%d"%role)
	if set_count(role)>=6: unlock("set6")
	dirty = true
	return "已装备"

func unequip(role: int, slot: int) -> void:
	data.roles[role].equipped.erase(str(slot))
	dirty = true

func set_count(role: int) -> int:
	var count = 0
	for uid in data.roles[role].equipped.values():
		var item = item_by_id(uid)
		if not item.is_empty() and int(item.role)==role and item.get("set_piece",true): count += 1
	return count

func enhance(uid: String) -> String:
	var item = item_by_id(uid)
	if item.is_empty(): return "装备不存在"
	if int(item.enhance)>=C.MAX_ENHANCE: return "已经达到 +10 上限"
	var cost = C.upgrade_cost(int(item.enhance)+1)
	if int(data.gold)<cost.gold: return "金币不足：需要 %d，持有 %d"%[cost.gold,data.gold]
	if int(data.material)<cost.material: return "材料不足：需要 %d，持有 %d；分解装备或击败首领可获得"%[cost.material,data.material]
	data.gold -= cost.gold
	data.material -= cost.material
	item.paid_material = int(item.get("paid_material",0))+cost.material
	item.enhance += 1
	if int(item.enhance)==10: unlock("enhance10")
	dirty = true
	return "强化成功"

func salvage_value(item: Dictionary) -> int:
	return [1,3,7,15][int(item.quality)]+floori(int(item.get("paid_material",0))*0.5)

func salvage(uid: String) -> String:
	var item = item_by_id(uid)
	if item.is_empty(): return "装备已不存在"
	if item.locked or is_equipped(uid): return "请先卸下并解除锁定"
	var amount = salvage_value(item)
	data.material += amount
	data.inventory.erase(item)
	dirty = true
	return "分解获得 %d 强化材料" % amount

func permanent_bonuses(role: int) -> Dictionary:
	var r: Dictionary = data.roles[role]
	var result = {"hp":(int(r.level)-1)*4.0,"attack":(int(r.level)-1)*0.65}
	for uid in r.equipped.values():
		var item = item_by_id(uid)
		if item.is_empty(): continue
		var props = item_stats(item)
		for key in props: result[key] = float(result.get(key,0))+props[key]
		if int(item.quality)==3 and int(item.slot)==0: result["legend_weapon"] = 1.0
		if item.get("hidden",false): result["hidden_relic"] = 1.0
		if item.has("mechanic"):
			var branch_index = int(item.get("build_branch",int(item.slot)%3))
			result["gear_branch_%d"%branch_index] = float(result.get("gear_branch_%d"%branch_index,0))+1.0
	for t in C.PASSIVES:
		result[t.key] = float(result.get(t.key,0))+int(r.talents.get(t.id,0))*t.amount
	var count = set_count(role)
	result["set_count"] = count
	if count>=2:
		var key = ["attack_pct","magazine","crit"][role]
		result[key] = float(result.get(key,0))+[0.08,2.0,0.05][role]
	if count>=4:
		match role:
			0:
				result["pierce"] = float(result.get("pierce",0))+1
				result["return"] = 1
			1:
				result["reload"] = float(result.get("reload",0))+0.15
				result["first"] = float(result.get("first",0))+0.25
			2: result["distance"] = float(result.get("distance",0))+0.15
	return result

func gain_xp(role: int, amount: int) -> int:
	var r: Dictionary = data.roles[role]
	var levels = 0
	var before_points = C.earned_points(int(r.level))
	if int(r.level)>=C.MAX_LEVEL: return 0
	r.xp += maxi(0,amount)
	while int(r.level)<C.MAX_LEVEL and int(r.xp)>=C.xp_needed(int(r.level)):
		r.xp -= C.xp_needed(int(r.level))
		r.level += 1
		levels += 1
		for i in range(4):
			if int(r.level)==C.SKILL_LEVELS[i]: events.append({"title":"新技能解锁","text":C.SKILLS[role][i].name})
	if levels>0: events.append({"title":"等级提升","text":["剑修","火枪手","游侠"][role]+" Lv.%d · 天赋点 +%d"%[int(r.level),C.earned_points(int(r.level))-before_points]})
	if int(r.level)>=C.MAX_LEVEL: r.xp = 0
	if int(r.level)>=15: unlock("level15")
	dirty = true
	return levels

func talent_points(role: int) -> int:
	return C.earned_points(int(data.roles[role].level))-int(data.roles[role].spent)

func train(role: int, id: String) -> String:
	var r: Dictionary = data.roles[role]
	for t in C.PASSIVES:
		if t.id!=id: continue
		if int(r.talents.get(id,0))>=t.max: return "已达上限"
		if talent_points(role)<1: return "天赋点不足"
		r.talents[id] = int(r.talents.get(id,0))+1
		r.spent += 1
		dirty = true
		return "天赋提升"
	return "未知天赋"

func train_skill(role: int, slot: int) -> String:
	var r: Dictionary = data.roles[role]
	var rank = int(r.skills[slot])
	if rank>=C.MAX_SKILL: return "技能已达 10 级"
	var required = C.SKILL_REQUIREMENTS[rank]
	if int(r.level)<maxi(C.SKILL_LEVELS[slot],required): return "需要角色 %d 级" % maxi(C.SKILL_LEVELS[slot],required)
	var cost = C.SKILL_COSTS[rank]
	if talent_points(role)<cost: return "需要 %d 天赋点" % cost
	r.skills[slot] += 1
	events.append({"title":"技能提升","text":C.SKILLS[role][slot].name+" Lv.%d"%int(r.skills[slot])})
	r.spent += cost
	dirty = true
	return "技能升级"

func reset_talents(role: int) -> String:
	var r: Dictionary = data.roles[role]
	var cost = 0 if int(r.resets)==0 else 120
	if int(r.spent)==0: return "还未分配天赋"
	if int(data.gold)<cost: return "金币不足"
	data.gold -= cost
	r.talents.clear()
	r.skills = [1,1,1,1]
	r.spent = 0
	r.resets += 1
	dirty = true
	return "已重置，天赋点全部返还"

func unlock(id: String) -> void:
	if not data.achievements.has(id):
		data.achievements[id] = true
		for entry in C.ACHIEVEMENTS:
			if entry.id==id: events.append({"title":"成就达成 · "+entry.name,"text":entry.text+" · 奖励请前往成就页领取"})
		dirty = true

func claim_achievement(id: String) -> String:
	if not data.achievements.has(id) or data.claimed.has(id): return "尚未达成或已领取"
	for a in C.ACHIEVEMENTS:
		if a.id==id:
			data.claimed[id] = true
			data.gold += a.gold
			dirty = true
			return "获得 %d 金币" % a.gold
	return "未知成就"

func roll_equipment(tier: int, role: int, chapter: int, rng: RandomNumberGenerator) -> Dictionary:
	return preload("res://scripts/loot_rules.gd").roll(self,tier,role,chapter,rng)

func make_shop(role: int, chapter: int, rng: RandomNumberGenerator) -> Array:
	var stock: Array = []
	for i in range(C.ITEMS.size()):
		stock.append({"type":"item","id":C.ITEMS[i].id,"name":C.ITEMS[i].name,"price":C.ITEMS[i].price,"sold":false})
	var gear = make_item(role,rng.randi_range(0,5),1,mini(int(data.roles[role].level),int(C.CHAPTERS[chapter-1].level)),rng)
	stock.append({"type":"gear","gear":gear,"name":item_name(gear),"price":120+chapter*35,"sold":false})
	return stock

func buy(stock: Array, index: int) -> String:
	if index<0 or index>=stock.size(): return "商品不存在"
	var offer: Dictionary = stock[index]
	if offer.sold: return "已售罄"
	if int(data.gold)<int(offer.price): return "金币不足"
	if offer.type=="gear" and data.inventory.size()>=C.CAPACITY: return "装备背包已满，请先整理"
	offer.sold = true
	data.gold -= int(offer.price)
	if offer.type=="gear": receive_item(offer.gear)
	else:
		data.consumables[offer.id] = int(data.consumables.get(offer.id,0))+1
		discover("item_"+offer.id)
	dirty = true
	return "购买成功"
