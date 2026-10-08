extends RefCounted
## Owns exploration state; only one room's physics and actors exist at a time.
const Graph = preload("res://scripts/room_graph.gd")
var game
var active: bool = false
var data: Dictionary = {}
var scene
var transition_clock: float = 0
var reward_rng = RandomNumberGenerator.new()
var reward_layers: int = 2
var waves_done: int = 0
var event_options: Array = []
var boss_choices: Array = []
var secret_clock: float = 0
var objective_state: Dictionary = {}
var objective_target
func current() -> Dictionary:
	return data.rooms[data.current] if active else {}
func origin() -> Vector2:
	if not active: return Vector2.ZERO
	var grid: Array = current().grid
	return Vector2(grid[0]*2200,grid[1]*1400)
func start(chapter: int, seed_value: int) -> void:
	active = true
	game.flow.exploration = true
	data = Graph.generate(chapter,seed_value)
	reward_rng.seed = seed_value+71971
	game.flow.run_id = data.run_id
	enter("r0")
func clear_scene() -> void:
	if is_instance_valid(scene): scene.free()
	scene = null
func stop() -> void:
	active = false
	game.flow.exploration = false
	clear_scene()
	data.clear()
func enter(id: String, from_id: String = "") -> void:
	game.flow.capybara = bool(data.get("capybara",false))
	game.collect_loot(true)
	game.clear_attacks()
	game.zones.clear()
	game.pickups.clear()
	game.pending.clear()
	game.director.reset()
	game.encounter.reset()
	game.player.skills.ultimate.active = false
	game.player.orbit_time = 0
	game.art.glyphs.clear()
	game.fx.clear()
	for enemy in game.enemies:
		if is_instance_valid(enemy): enemy.free()
	game.enemies.clear()
	clear_scene()
	data.current = id
	data.entry = from_id
	var r = current()
	game.telemetry.record_room(r)
	game.flow.room_kind = r.kind
	game.flow.room_waves = int(r.waves)
	var first_visit: bool = not r.visited
	r.visited = true
	scene = load("res://scenes/rooms/%s.tscn"%r.layout).instantiate()
	scene.position = origin()
	scene.theme = game.stage-1
	game.add_child(scene)
	game.move_child(scene,0)
	var exits: Array = []
	for next_id in r.neighbors:
		if next_id=="secret" and not data.revealed: continue
		var next: Dictionary = data.rooms[next_id]
		var dir = Vector2(next.grid[0]-r.grid[0],next.grid[1]-r.grid[1])
		exits.append({"id":next_id,"dir":[dir.x,dir.y],"label":Graph.NAMES[next.kind]})
	scene.run = self
	scene.configure(exits,r.cleared,Graph.EVENT_NAMES.get(r.event,""),r.used)
	scene.clue = r.id=="r2" and data.rooms.has("secret") and not data.revealed
	scene.clue_count = int(data.switches)
	if not r.has("broken"): r.broken = []
	if r.kind in ["battle","elite"]: scene.add_crates(r.broken)
	game.ARENA = Rect2(origin()+Vector2(70,160),Vector2(1780,790))
	game.camera.position = origin()+Vector2(960,540)
	var spawn = Vector2(960,740)
	if not from_id.is_empty() and data.rooms.has(from_id):
		var previous: Dictionary = data.rooms[from_id]
		var dir = Vector2(previous.grid[0]-r.grid[0],previous.grid[1]-r.grid[1])
		spawn = scene.portal(dir)-dir*140
	game.player.global_position = origin()+scene.safe(spawn,28)
	game.player.invulnerable = maxf(1.2,game.player.invulnerable)
	game.player.scripted_movement = Vector2.ZERO
	game.flow.hidden = r.kind=="secret"
	game.flow.round_number = maxi(1,int(r.grid[0]))
	game.flow.wave = 1
	game.flow.stock = r.stock
	waves_done = 0
	setup_objective(r)
	transition_clock = 0.8
	game.state = "combat"
	game.ui.clear_overlay()
	game.banner = "%s · %s"%[game.flow.title(),Graph.NAMES[r.kind]]
	game.banner_time = 2.5
	if not r.cleared:
		spawn_wave()
	elif first_visit and r.kind=="event":
		game.notify_player("靠近房间中央，按 %s 与%s交互。"%[game.bindings.text("interact"),Graph.EVENT_NAMES[r.event]],5)
	if r.id=="r2" and data.rooms.has("secret") and not data.revealed:
		game.notify_player("北墙有三道发光裂纹：靠近北墙，连续唤醒三枚符纹可开启镜渊。",6)
	game.queue_redraw()
func spawn_wave() -> void:
	var r = current()
	waves_done += 1
	game.flow.wave = waves_done
	game.spawn_clock = 0.25
	if r.kind in ["boss","secret"]:
		game.pending.append({"kind":14 if data.get("capybara",false) else (8 if r.kind=="secret" else game.Catalog.CHAPTERS[game.stage-1].boss),"elite":false})
		game.sound.play("boss")
		return
	var count = (5+mini(4,game.stage)) if r.kind=="battle" else 7
	var pool: Array = [0,0,2] if game.stage==1 else ([0,1,2,3,15,16,17,18] if game.stage==2 else ([0,0,1,2,3,15,16,17,18] if game.stage<5 else [0,1,2,3,9,10,11,15,16,17,18]))
	for i in range(count):
		var kind: int = pool[(i+int(r.grid[0]))%pool.size()]
		game.pending.append({"kind":kind,"elite":r.kind=="elite" and i==count-1,"objective":r.objective if r.objective=="hunt" and i==count-1 else ""})
func tick(delta: float) -> void:
	transition_clock = maxf(0,transition_clock-delta)
	if not active or game.state!="combat": return
	var r = current()
	if not r.cleared:
		game.spawn_clock -= delta
		if game.spawn_clock<=0 and not game.pending.is_empty():
			var item = game.pending.pop_front()
			var spawned = game.spawn_enemy(item.kind,origin()+Vector2(1150,485) if item.kind==14 else game.random_spawn(),item.elite)
			if item.get("objective","")=="hunt" and is_instance_valid(spawned):
				objective_target = spawned
				spawned.hunt_stacks = 3
				game.notify_player("悬赏目标已出现：在倒计时结束前击败带三枚金印的敌人。",5)
			game.spawn_clock = 0.28
		if not str(r.get("objective","")).is_empty() and tick_objective(delta): return
		elif game.enemies.is_empty() and game.pending.is_empty() and transition_clock<=0:
			if game.player.skills.ultimate.active: return
			if waves_done<int(r.waves): spawn_wave()
			else: complete_room()
		return
	if transition_clock>0: return
	for door in scene.doors:
		var dir = Vector2(door.dir[0],door.dir[1])
		if game.player.global_position.distance_to(origin()+scene.portal(dir))<70:
			enter(door.id,r.id)
			return
	if game.focused and Input.is_action_just_pressed("interact"):
		interact()
func interact() -> void:
	if not active or game.state!="combat" or not current().cleared: return
	var p: Vector2 = game.player.global_position-origin()
	if current().id=="r2" and data.rooms.has("secret") and not data.revealed and p.distance_to(Vector2(960,235))<140:
		data.switches = mini(3,int(data.switches)+1)
		scene.clue_count = int(data.switches)
		scene.queue_redraw()
		game.fx.sigils(game.player.global_position,80,Color("#b9a0ef"),3)
		game.sound.play("reward")
		game.notify_player("北墙符纹 %d / 3"%int(data.switches))
		if int(data.switches)==3:
			data.revealed = true
			var player_pos: Vector2 = game.player.global_position
			enter(data.current)
			game.player.global_position = player_pos
			game.profile.discover("hidden_gate")
		return
	if p.distance_to(Vector2(960,540))<160 and not current().event.is_empty() and not current().used:
		if current().event=="secret":
			current().used = true
			current().cleared = false
			current().waves = 1
			scene.set_clear(false)
			game.profile.unlock("secret")
			game.profile.data.secret = true
			game.profile.dirty = true
			spawn_wave()
		else: open_event()
	else: camp()
func camp() -> void:
	if not active or game.state!="combat" or not current().cleared: return
	game.state = "intermission"
	game.ui.show_intermission()

func return_to_branch() -> void:
	if not active or game.state!="intermission" or not current().cleared: return
	if current().id not in ["elite","cache","secret"]: return
	var next_id: String = current().neighbors[0]
	if not data.rooms[next_id].cleared: return
	enter(next_id,current().id)

func setup_objective(room: Dictionary) -> void:
	objective_state.clear()
	objective_target = null
	if room.cleared: return
	match str(room.get("objective","")):
		"defend": objective_state = {"id":"defend","time":24.0,"max_time":24.0,"hp":100.0,"max_hp":100.0,"pulse":0.0}
		"hunt": objective_state = {"id":"hunt","time":32.0,"max_time":32.0,"attempt":1}
		"seal": objective_state = {"id":"seal","index":0,"hold":0.0,"required":1.6,"points":[origin()+Vector2(420,390),origin()+Vector2(1480,390),origin()+Vector2(960,760)]}
	if not objective_state.is_empty(): game.notify_player(objective_text(),6)

func tick_objective(delta: float) -> bool:
	if objective_state.is_empty(): return false
	match objective_state.id:
		"defend":
			objective_state.time = maxf(0,float(objective_state.time)-delta)
			objective_state.pulse = maxf(0,float(objective_state.pulse)-delta)
			var center = origin()+Vector2(960,540)
			for enemy in game.enemies:
				if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(center)<105:
					objective_state.hp = maxf(0,float(objective_state.hp)-delta*8.0)
					if objective_state.pulse<=0:
						objective_state.pulse = 0.45
						game.fx.ring(center,95,Color("#ff8b89"))
			if objective_state.hp<=0:
				objective_state.hp = 70.0
				objective_state.time = minf(float(objective_state.max_time),float(objective_state.time)+7.0)
				game.player.hurt(game.player.stats.value("hp")*0.12)
				game.notify_player("灵石破裂：已重新凝聚，防守时间延长 7 秒。",5)
			if objective_state.time<=0: finish_objective("灵石坚守完成")
			elif game.enemies.is_empty() and game.pending.is_empty(): queue_objective_reinforcements(3)
		"hunt":
			if is_instance_valid(objective_target) and objective_target.dead:
				finish_objective("悬赏目标已击败")
			elif is_instance_valid(objective_target):
				objective_state.time = maxf(0,float(objective_state.time)-delta)
				if objective_state.time<=0:
					game.enemies.erase(objective_target)
					objective_target.queue_free()
					objective_target = null
					objective_state.attempt = int(objective_state.attempt)+1
					objective_state.time = maxf(18.0,float(objective_state.max_time)-4.0*(int(objective_state.attempt)-1))
					game.player.hurt(game.player.stats.value("hp")*0.10)
					game.pending.append({"kind":18,"elite":true,"objective":"hunt"})
					game.notify_player("目标逃脱：损失 10% 生命，新目标正在入场。",5)
			elif objective_target==null and game.pending.is_empty():
				game.pending.append({"kind":18,"elite":true,"objective":"hunt"})
		"seal":
			var index = int(objective_state.index)
			if index>=3:
				finish_objective("三处阵眼均已封印")
			else:
				var point: Vector2 = objective_state.points[index]
				if game.player.global_position.distance_to(point)<95:
					objective_state.hold = minf(float(objective_state.required),float(objective_state.hold)+delta)
					if objective_state.hold>=objective_state.required:
						objective_state.index = index+1
						objective_state.hold = 0.0
						game.fx.sigils(point,105,Color("#8ee8d0"),3)
						game.sound.play("reward")
						game.notify_player("阵眼 %d / 3 已封印"%int(objective_state.index),3)
				else: objective_state.hold = maxf(0,float(objective_state.hold)-delta*0.35)
				if game.enemies.is_empty() and game.pending.is_empty(): queue_objective_reinforcements(2)
	game.queue_redraw()
	return true

func queue_objective_reinforcements(count: int) -> void:
	var pool = [0,1,2,15,16,17]
	for i in range(count): game.pending.append({"kind":pool[(i+waves_done)%pool.size()],"elite":false,"objective":""})
	game.spawn_clock = 0.2

func finish_objective(message: String) -> void:
	for enemy in game.enemies.duplicate():
		if is_instance_valid(enemy): enemy.queue_free()
	game.enemies.clear()
	game.pending.clear()
	game.clear_enemy_attacks()
	objective_state.done = true
	game.notify_player(message+"，房间奖励已解锁。",4)
	complete_room()

func objective_text() -> String:
	if objective_state.is_empty(): return ""
	match objective_state.id:
		"defend": return "灵石坚守 · 剩余 %.0fs · 灵石 %d%%"%[objective_state.time,ceili(objective_state.hp)]
		"hunt":
			var hp_text = "等待目标" if not is_instance_valid(objective_target) else "目标 %d%%"%ceili(100.0*objective_target.hp/maxf(1,objective_target.max_hp))
			return "悬赏追猎 · %s · 剩余 %.0fs"%[hp_text,objective_state.time]
		"seal": return "三阵封印 · %d / 3 · 当前阵眼 %d%%"%[objective_state.index,ceili(100.0*objective_state.hold/objective_state.required)]
	return ""

func draw_objective() -> void:
	if objective_state.is_empty() or objective_state.get("done",false): return
	match objective_state.id:
		"defend":
			var center = origin()+Vector2(960,540)
			var color = Color("#81dfcf") if objective_state.hp>35 else Color("#ff8b89")
			game.draw_circle(center,44,Color(color,0.16))
			game.draw_arc(center,54,-PI/2,-PI/2+TAU*float(objective_state.hp)/float(objective_state.max_hp),48,color,6,true)
			game.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-38),center+Vector2(30,18),center+Vector2(0,38),center+Vector2(-30,18)]),Color(color,0.65))
		"hunt":
			if is_instance_valid(objective_target):
				for i in range(3): game.draw_arc(objective_target.global_position,objective_target.radius+13+i*6,0,TAU,32,Color("#f2cf6c"),2,true)
		"seal":
			for i in range(objective_state.points.size()):
				var point: Vector2 = objective_state.points[i]
				var color = Color("#5c6b78") if i<int(objective_state.index) else (Color("#8ee8d0") if i==int(objective_state.index) else Color("#876ba8"))
				game.draw_circle(point,62,Color(color,0.10))
				game.draw_arc(point,62,0,TAU,40,color,4,true)
				if i==int(objective_state.index): game.draw_arc(point,72,-PI/2,-PI/2+TAU*float(objective_state.hold)/float(objective_state.required),40,Color("#f1d98a"),7,true)
func complete_room() -> void:
	var r = current()
	if r.claimed: return
	r.cleared = true
	r.claimed = true
	scene.set_clear(true)
	game.clear_attacks()
	game.collect_loot(true)
	game.zones.clear()
	game.player.skills.ultimate.active = false
	var gold = 130+game.stage*65
	var xp = 160+game.stage*110
	var material = 3+game.stage
	if r.kind in ["elite","boss","secret"]: gold *= 2; xp *= 2; material *= 2
	if not str(r.get("objective","")).is_empty():
		gold = roundi(gold*1.35)
		xp = roundi(xp*1.25)
		material += 2
	grant(gold,xp,material)
	game.player.heal(game.player.stats.value("hp")*0.12)
	game.profile.events.append({"title":"房间已清理","text":"金币 +%d · 经验 +%d · 材料 +%d"%[gold,xp,material]})
	if r.kind=="boss":
		if data.get("capybara",false):
			game.receive_gear(game.profile.make_item(game.selected_role,5,2,mini(5,int(game.profile.data.roles[game.selected_role].level)),reward_rng))
			game.profile.unlock("lulu")
			game.end_run(true)
			return
		if not game.profile.data.cleared.has(game.stage):
			boss_choices.clear()
			for slot in [0,2,5]: boss_choices.append(game.profile.make_item(game.selected_role,slot,2 if game.stage<5 else 3,mini(game.Catalog.CHAPTERS[game.stage-1].level,int(game.profile.data.roles[game.selected_role].level)),reward_rng))
			game.state = "first_clear"
			game.ui.show_first_clear(boss_choices)
		else: game.end_run(true)
		return
	reward_layers = 3 if r.kind in ["elite","secret"] or not str(r.get("objective","")).is_empty() else 2
	game.state = "reward"
	game.rewards = game.roll_rewards(reward_rng,true,r.kind in ["elite","secret"] or r.get("objective","")=="seal")
	game.ui.show_rewards(game.rewards)
	game.sound.play("reward")
	game.profile.save_profile()
func claim_first_clear(index: int) -> void:
	if game.state!="first_clear" or index<0 or index>=boss_choices.size(): return
	game.receive_gear(boss_choices[index])
	boss_choices.clear()
	game.state = "combat"
	game.end_run(true)
func grant(gold: int, xp: int, material: int) -> void:
	game.profile.data.gold += gold
	game.earned_gold += gold
	game.profile.data.material += material
	game.add_xp(xp)
	game.profile.dirty = true
func after_reward() -> void:
	game.state = "combat"
	game.ui.clear_overlay()
	transition_clock = 0.5
	if current().get("objective","")=="seal" and data.rooms.has("secret") and not data.revealed:
		data.revealed = true
		game.profile.data.camp_dialogue.secret = true
		game.profile.events.append({"title":"隐藏道路 · 镜渊旧印","text":"三处阵眼连成一扇旧门；门后留着指向第三章的裂隙坐标。"})
		game.profile.dirty = true
		var player_pos: Vector2 = game.player.global_position
		enter(str(data.current),str(data.entry))
		game.player.global_position = player_pos
		game.notify_player("三阵共鸣：隐藏的镜渊支路已经显现。",6)
		return
	game.notify_player("出口已开启。靠近门继续探索；%s 可在安全房间整备。"%game.bindings.text("interact"),5)
func open_event() -> void:
	var kind: String = current().event
	event_options = preload("res://scripts/room_events.gd").options(kind,game)
	game.state = "event"
	game.ui.show_room_event(kind,event_options)
func choose_event(index: int) -> void:
	if game.state!="event" or current().used or index<0 or index>=event_options.size(): return
	var choice: Dictionary = event_options[index]
	if int(game.profile.data.gold)<int(choice.cost): game.notify_player("金币不足，可稍后再来。"); return
	current().used = true
	current()["choice"] = choice.effect
	if not data.has("boons"): data.boons = []
	if choice.effect in ["attack","cooldown","vital","heal","mastery"]: data.boons.append(choice.name+"："+choice.text)
	game.profile.data.gold -= int(choice.cost)
	preload("res://scripts/room_events.gd").apply(self,choice)
	game.profile.discover("event_"+current().event)
	game.profile.dirty = true
	# This is a live run; persistence of permanent progress uses the existing transaction.
	if not game.profile.save_profile(): game.notify_player("奖励已在本局生效，但磁盘保存失败："+game.profile.notice,8)
	scene.event_used = true
	scene.queue_redraw()
	game.sound.play("reward")
	game.state = "combat"
	game.ui.clear_overlay()
	event_options.clear()
func snapshot() -> Dictionary:
	var p = game.player
	return {"version":1,"map":data.duplicate(true),"role":game.selected_role,"rng":str(game.rng.state),"reward_rng":str(reward_rng.state),"hp":p.hp,"bonuses":p.stats.bonuses.duplicate(true),"stacks":p.stats.stacks.duplicate(true),"revive_used":p.revive_used,"elapsed":game.elapsed,"kills":game.kills,"gold":game.earned_gold,"xp":game.earned_xp,"gear":game.earned_gear,"item_clocks":p.item_clocks.duplicate(),"cooldowns":p.skills.cooldowns.duplicate(),"temporary":p.skills.temporary.duplicate(),"evolutions":p.skills.evolutions.duplicate(true),"rerolls":p.skills.rerolls,"reward_count":p.skills.reward_count,"telemetry":game.telemetry.snapshot()}
func save_exit() -> bool:
	if not active or not current().cleared or game.state!="intermission": return false
	var old: Dictionary = game.profile.data.exploration
	game.profile.data.exploration = snapshot()
	if not game.profile.save_profile():
		game.profile.data.exploration = old
		game.notify_player("保存失败，仍停留在整备点。",5)
		return false
	game.state = "menu"
	game.reset_entities()
	stop()
	game.ui.show_menu()
	return true
func resume() -> bool:
	var c: Dictionary = game.profile.data.exploration.duplicate(true)
	if not valid(c): game.notify_player("探索存档版本或结构不完整，已保留。"); return false
	game.profile.data.exploration = {}
	if not game.profile.save_profile(): game.profile.data.exploration=c; return false
	game.start_run(int(c.role),int(c.map.seed),int(c.map.chapter))
	data = c.map
	enter(str(data.current),str(data.entry))
	var p = game.player
	p.stats.bonuses = c.bonuses
	p.stats.stacks = c.stacks
	p.hp = minf(float(c.hp),p.stats.value("hp"))
	p.revive_used = c.revive_used
	p.skills.cooldowns.assign(c.cooldowns)
	p.skills.temporary = c.temporary
	p.skills.evolutions = c.get("evolutions",{}).duplicate(true)
	p.skills.rerolls = int(c.get("rerolls",2))
	p.skills.reward_count = int(c.get("reward_count",0))
	p.item_clocks = c.item_clocks
	game.elapsed = c.elapsed
	game.kills = int(c.kills)
	game.earned_gold = int(c.gold)
	game.earned_xp = int(c.xp)
	game.earned_gear = int(c.gear)
	game.telemetry.restore(c.get("telemetry",{}))
	game.rng.state = int(c.rng)
	reward_rng.state = int(c.reward_rng)
	game.notify_player("已恢复房间、宝箱和奇遇状态。续玩记录已消耗；到安全房间可再次保存。",6)
	return true
func valid(c: Dictionary) -> bool:
	if int(c.get("version",0))!=1 or not c.get("map") is Dictionary: return false
	var m: Dictionary = c.map
	if int(m.get("version",0))!=Graph.VERSION or not m.get("rooms") is Dictionary: return false
	if not m.rooms.has(m.get("current","")) or not m.rooms[m.current].get("cleared",false): return false
	if int(c.get("role",-1)) not in [0,1,2] or int(m.get("chapter",0)) not in range(1,7): return false
	if not m.get("run_id") is String or not m.get("entry") is String: return false
	for id in m.rooms:
		var r = m.rooms[id]
		if not r is Dictionary or r.get("id")!=id: return false
		if not r.get("grid") is Array or r.grid.size()!=2: return false
		for coordinate in r.grid:
			if not coordinate is float and not coordinate is int: return false
		if r.get("layout","") not in ["open","pillars","lanes","center","ring","elite","boss"]: return false
		if r.get("kind","") not in Graph.NAMES: return false
		if not r.get("neighbors") is Array or not r.get("stock") is Array: return false
		for neighbor in r.neighbors:
			if not m.rooms.has(neighbor): return false
		for flag in ["visited","cleared","claimed","used"]:
			if not r.get(flag) is bool: return false
	for key in ["rng","reward_rng"]:
		if not c.get(key) is String or not c[key].is_valid_int(): return false
	if float(c.get("hp",0))<=0 or not is_finite(float(c.hp)): return false
	for key in ["bonuses","stacks","item_clocks"]:
		if not c.get(key) is Dictionary: return false
	for key in ["cooldowns","temporary"]:
		if not c.get(key) is Array or c[key].size()!=4: return false
	return Graph.reachable(m)
func abandon() -> bool:
	var old: Dictionary = game.profile.data.exploration
	game.profile.data.exploration = {}
	if not game.profile.save_profile(): game.profile.data.exploration = old; return false
	return true

func abyss_room(floor_id: int) -> void:
	game.flow.capybara = false
	active = false
	game.flow.exploration = false
	clear_scene()
	var layouts = ["open","pillars","lanes","center","ring","elite"]
	scene = load("res://scenes/rooms/%s.tscn"%("boss" if floor_id%10==0 else layouts[(floor_id-1)%layouts.size()])).instantiate()
	scene.theme = (floor_id/5)%6
	game.add_child(scene)
	game.move_child(scene,0)
	scene.configure([],false)
	game.ARENA = Rect2(70,160,1780,790)
	game.camera.position = Vector2(960,540)
	game.player.position = scene.safe(Vector2(960,740))

func start_lulu(role: int, seed_value: int = -1) -> void:
	if not game.profile.data.checkpoint.is_empty() or not game.profile.data.exploration.is_empty():
		game.notify_player("请先继续或放弃已保存的挑战。")
		return
	game.start_run(role,seed_value,1)
	data.capybara = true
	data.rooms = {}
	data.rooms.r0 = Graph.room("r0",0,0,"start",1,reward_rng)
	data.rooms.r1 = Graph.room("r1",1,0,"boss",1,reward_rng)
	data.rooms.r1.layout = "open"
	Graph.connect_rooms(data.rooms,"r0","r1")
	enter("r0")
	game.notify_player("噜噜在右侧温泉等你：躲开泡泡和拍水，泡澡时是反击机会。",6)
