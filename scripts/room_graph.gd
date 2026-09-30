extends RefCounted
const VERSION = 1
const EVENTS = ["merchant","altar","chest","fountain","forge","traveler"]
const EVENT_NAMES = {"merchant":"行商营地","altar":"武器祭坛","chest":"古代宝箱","fountain":"治疗泉","forge":"遗失工坊","traveler":"神秘旅人","secret":"三纹封印"}
const NAMES = {"start":"出发营地","battle":"战斗房","event":"奇遇房","elite":"试炼契约","boss":"首领大殿","secret":"镜渊裂隙"}
static func generate(chapter: int, seed_value: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value+41043
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
static func room(id: String, x: int, y: int, kind: String, chapter: int, rng: RandomNumberGenerator) -> Dictionary:
	var layout = ["open","pillars","lanes","center","ring"][rng.randi_range(0,4)]
	if kind in ["start","event","secret"]: layout = "open"
	if kind in ["boss","elite"]: layout = kind
	var event = EVENTS[(chapter-1+rng.randi_range(0,5))%6] if kind=="event" else ("secret" if kind=="secret" else "")
	return {"id":id,"grid":[x,y],"kind":kind,"layout":layout,"event":event,"neighbors":[],"visited":false,"cleared":kind in ["start","event","secret"],"claimed":false,"used":false,"stock":[],"broken":[],"waves":2 if kind=="elite" else 1}
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
