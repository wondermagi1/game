extends RefCounted
const VERSION = 1
const EVENTS = ["merchant","altar","chest","fountain","forge","traveler"]
const EVENT_NAMES = {"merchant":"行商营地","altar":"武器祭坛","chest":"古代宝箱","fountain":"治疗泉","forge":"遗失工坊","traveler":"神秘旅人","secret":"三纹封印"}
const NAMES = {"start":"出发营地","battle":"战斗房","event":"奇遇房","elite":"试炼契约","boss":"首领大殿","secret":"镜渊裂隙"}
static func generate(chapter: int, seed_value: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value+41043
	if chapter==2: return generate_chapter_two(seed_value,rng)
	var kinds: Array = ["start","battle","event","boss"] if chapter==1 else (["start","battle","event","battle","boss"] if chapter==2 else (["start","battle","event","battle","event","boss"] if chapter==3 else ["start","battle","event","battle","battle","event","boss"]))
	var rooms: Dictionary = {}
	for i in range(kinds.size()):
		var id = "r%d"%i
		rooms[id] = room(id,i,0,kinds[i],chapter,rng)
		if i>0: connect_rooms(rooms,"r%d"%(i-1),id)
	if chapter>=2:
		rooms["elite"] = room("elite",1,1,"elite",chapter,rng)
		connect_rooms(rooms,"r1","elite")
	if chapter>=3:
		rooms["cache"] = room("cache",3,1,"event",chapter,rng)
		rooms.cache.event = "chest"
		connect_rooms(rooms,"r3","cache")
	if chapter==3 or (chapter>=4 and rng.randf()<0.8):
		rooms["secret"] = room("secret",2,-1,"secret",chapter,rng)
		connect_rooms(rooms,"r2","secret")
	return {"version":VERSION,"seed":seed_value,"run_id":"%d-%d"%[Time.get_ticks_usec(),seed_value],"chapter":chapter,"current":"r0","entry":"","rooms":rooms,"revealed":false,"switches":0}

static func generate_chapter_two(seed_value: int, rng: RandomNumberGenerator) -> Dictionary:
	var rooms: Dictionary = {}
	rooms.r0 = room("r0",0,0,"start",2,rng)
	rooms.r1 = room("r1",1,0,"battle",2,rng)
	rooms.safe = room("safe",2,-1,"event",2,rng)
	rooms.safe.event = "fountain"
	rooms.safe.reward_hint = "恢复 / 稳定强化"
	rooms.safe.danger = 1
	rooms.elite = room("elite",2,1,"elite",2,rng)
	rooms.elite.reward_hint = "高阶进化 / 稀有装备"
	rooms.elite.danger = 3
	rooms.cross = room("cross",3,0,"battle",2,rng)
	rooms.cross.objective = "defend"
	rooms.cross.reward_hint = "强化材料 / 防御馈赠"
	rooms.cross.danger = 2
	rooms.shop = room("shop",4,-1,"event",2,rng)
	rooms.shop.event = "merchant"
	rooms.shop.reward_hint = "定向购买 / 补给"
	rooms.shop.danger = 1
	rooms.hunt = room("hunt",4,1,"battle",2,rng)
	rooms.hunt.objective = "hunt"
	rooms.hunt.reward_hint = "金币 / 定向装备"
	rooms.hunt.danger = 3
	rooms.seal = room("seal",4,0,"battle",2,rng)
	rooms.seal.objective = "seal"
	rooms.seal.reward_hint = "技能进化 / 高阶馈赠"
	rooms.seal.danger = 2
	rooms.boss = room("boss",5,0,"boss",2,rng)
	rooms.boss.reward_hint = "首领宝箱 / 章节解锁"
	rooms.boss.danger = 4
	connect_rooms(rooms,"r0","r1")
	connect_rooms(rooms,"r1","safe")
	connect_rooms(rooms,"r1","elite")
	connect_rooms(rooms,"safe","cross")
	connect_rooms(rooms,"elite","cross")
	connect_rooms(rooms,"cross","shop")
	connect_rooms(rooms,"cross","hunt")
	connect_rooms(rooms,"cross","seal")
	connect_rooms(rooms,"shop","boss")
	connect_rooms(rooms,"hunt","boss")
	connect_rooms(rooms,"seal","boss")
	return {"version":VERSION,"seed":seed_value,"run_id":"%d-%d"%[Time.get_ticks_usec(),seed_value],"chapter":2,"current":"r0","entry":"","rooms":rooms,"revealed":true,"switches":0,"sample":true}
static func room(id: String, x: int, y: int, kind: String, chapter: int, rng: RandomNumberGenerator) -> Dictionary:
	var layout = ["open","pillars","lanes","center","ring"][rng.randi_range(0,4)]
	if kind in ["start","event","secret"]: layout = "open"
	if kind in ["boss","elite"]: layout = kind
	var event = EVENTS[(chapter-1+rng.randi_range(0,5))%6] if kind=="event" else ("secret" if kind=="secret" else "")
	return {"id":id,"grid":[x,y],"kind":kind,"layout":layout,"event":event,"neighbors":[],"visited":false,"cleared":kind in ["start","event","secret"],"claimed":false,"used":false,"stock":[],"broken":[],"waves":2 if kind=="elite" else 1,"objective":"","danger":4 if kind=="boss" else (3 if kind=="elite" else 2),"reward_hint":"首领奖励" if kind=="boss" else ("高阶馈赠" if kind=="elite" else ("奇遇选择" if kind in ["event","secret"] else "清房馈赠")),"enemy_hint":"战术敌群" if chapter>=2 else "基础敌群"}
static func connect_rooms(rooms: Dictionary, a: String, b: String) -> void:
	rooms[a].neighbors.append(b)
	rooms[b].neighbors.append(a)
static func reachable(map: Dictionary) -> bool:
	var seen: Array = ["r0"]
	var queue: Array = ["r0"]
	while not queue.is_empty():
		var id = queue.pop_front()
		for next in map.rooms[id].neighbors:
			if not seen.has(next): seen.append(next); queue.append(next)
	return seen.size()==map.rooms.size()
