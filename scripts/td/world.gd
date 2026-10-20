extends "res://scripts/game.gd"
## Isolated mode: campaign checkpoints and chapter progression are never replaced.
const TD = preload("res://scripts/td/catalog.gd")
const Facility = preload("res://scripts/td/facility.gd")
const DefenseEnemy = preload("res://scripts/td/enemy.gd")
const PADS = [Vector2(350,410),Vector2(350,710),Vector2(590,260),Vector2(590,840),Vector2(760,475),Vector2(760,660),Vector2(990,330),Vector2(990,800),Vector2(1130,450),Vector2(1130,650)]
const CORE = Vector2(1280,550)
var ROUTES = [PackedVector2Array([Vector2(140,295),Vector2(430,295),Vector2(600,375),Vector2(870,390),Vector2(1040,550),CORE]),PackedVector2Array([Vector2(140,805),Vector2(430,805),Vector2(600,725),Vector2(870,725),Vector2(1040,550),CORE])]
var facilities: Array = []
var energy: int = 190
var core_hp: float = 100.0
var defense_wave: int = 0
var cleared_waves: int = 0
var wave_queue: Array = []
var blueprints: Dictionary = {}
var blueprint_offer: Array[int] = []
var selected_pad: int = 0
var selected_kind: int = 0
var result_paid: bool = false
var result_text: String = ""
var wave_time: float = 0.0
var td_sound_clock: float = 0.0
var td_panel
var board
var reward_choice_pending: bool = false
var leaks: int = 0
var fire_patches: Array = []

func _ready() -> void:
	super._ready()
	rooms.active = false
	rooms.scene.theme = 2
	rooms.scene.load_scene_art()
	rooms.scene.wall(Rect2(1390,160,24,790))
	ARENA = Rect2(70,160,1320,790)
	board = preload("res://scripts/td/board.gd").new()
	board.game = self
	add_child(board)
	td_panel = preload("res://scripts/td/panel.gd").new()
	td_panel.game = self
	add_child(td_panel)
	td_panel.show_select()

func start_defense(role: int, seed_value: int = -1) -> void:
	reset_entities()
	for tower in facilities: if is_instance_valid(tower): tower.free()
	facilities.clear()
	clear_td_shots()
	board.effects.clear()
	fire_patches.clear()
	fx.queue_redraw()
	art.queue_redraw()
	notice_clock = 0
	selected_role = clampi(role,0,2)
	ui.view_role = selected_role
	flow.start(1)
	stage = 1
	run_seed = seed_value if seed_value>=0 else int(Time.get_unix_time_from_system())%2147483647
	rng.seed = run_seed
	energy = 190
	core_hp = 100
	defense_wave = 0
	cleared_waves = 0
	blueprints.clear()
	blueprint_offer.clear()
	wave_queue.clear()
	selected_pad = 0
	selected_kind = 0
	result_paid = false
	reward_choice_pending = false
	result_text = ""
	elapsed = 0
	kills = 0
	leaks = 0
	dealt = 0
	taken = 0
	earned_gold = 0
	earned_xp = 0
	earned_gear = 0
	telemetry.reset()
	player = Player.new()
	player.game = self
	player.stats = Stats.new(selected_role)
	player.stats.permanent = profile.permanent_bonuses(selected_role)
	player.position = Vector2(1090,550)
	add_child(player)
	focused = true
	enter_build()

func enter_build() -> void:
	state = "td_build"
	clear_td_shots()
	clear_attacks()
	clear_transient_effects()
	for tower in facilities:
		tower.hp = tower.max_hp
		tower.disabled_time = 0
	if is_instance_valid(player):
		player.hp = minf(player.stats.value("hp"),player.hp+player.stats.value("hp")*0.25)
		player.cancel_skill_windup()
		player.visual.walking = 0
		player.visual.movement = Vector2.ZERO
	td_panel.show_build()

func tower_at(slot: int):
	for tower in facilities:
		if tower.pad==slot: return tower
	return null

func discount() -> float:
	for tower in facilities:
		if tower.kind==11 and tower.rank==4: return 0.88
	return 1.0

func price(kind: int, rank: int = 0) -> int:
	if kind<0 or kind>=12 or rank<0 or rank>=4: return 0
	return ceili((float(TD.definition(kind).cost) if rank==0 else float(TD.UPGRADES[rank-1]))*discount())

func build_facility(slot: int, kind: int, blueprint: bool = false) -> bool:
	if state!="td_build" or slot<0 or slot>=PADS.size() or kind<0 or kind>=12 or tower_at(slot)!=null: return false
	var cost = price(kind)
	if blueprint:
		if blueprints.get(kind,0)<=0: return false
		blueprints[kind] -= 1
		cost = 0
	else:
		if energy<cost: return false
		energy -= cost
	var tower = Facility.new()
	tower.game = self
	tower.kind = kind
	tower.pad = slot
	tower.invested = cost
	tower.position = PADS[slot]
	add_child(tower)
	facilities.append(tower)
	selected_pad = slot
	sound.play("reward")
	td_panel.show_build()
	return true

func upgrade_facility(slot: int, blueprint: bool = false) -> bool:
	var tower = tower_at(slot)
	if state!="td_build" or tower==null or tower.rank>=TD.MAX_LEVEL: return false
	var cost = price(tower.kind,tower.rank)
	if blueprint:
		if blueprints.get(tower.kind,0)<=0: return false
		blueprints[tower.kind] -= 1
		cost = 0
	else:
		if energy<cost: return false
		energy -= cost
	tower.invested += cost
	tower.rank += 1
	tower.refresh_rank()
	sound.play("reward")
	td_panel.show_build()
	return true

func sell_facility(slot: int) -> bool:
	var tower = tower_at(slot)
	if state!="td_build" or tower==null: return false
	energy += floori(tower.invested*0.7)
	facilities.erase(tower)
	tower.queue_free()
	td_panel.show_build()
	return true

func repair_core() -> bool:
	if state!="td_build" or energy<25 or core_hp>=100: return false
	energy -= 25
	core_hp = minf(100,core_hp+25)
	td_panel.show_build()
	return true

func start_wave() -> bool:
	if state!="td_build" or defense_wave>=3 or facilities.is_empty() or reward_choice_pending: return false
	defense_wave += 1
	flow.wave = defense_wave
	wave_queue = TD.wave_plan(defense_wave)
	wave_time = 0
	spawn_clock = 1.5
	state = "combat"
	focused = true
	td_panel.show_combat()
	banner = "遗迹守卫 · 第 %d 波"%defense_wave
	banner_time = 2.0
	return true

func _physics_process(delta: float) -> void:
	if state!="combat": return
	elapsed += delta
	wave_time += delta
	td_sound_clock = maxf(0,td_sound_clock-delta)
	banner_time = maxf(0,banner_time-delta)
	process_hazards(delta)
	process_pickups(delta)
	process_zones(delta)
	for patch in fire_patches:
		patch.life -= delta
		patch.tick -= delta
		if patch.tick<=0:
			patch.tick = 0.5
			for enemy in enemies.duplicate():
				if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(patch.position)<patch.radius:
					enemy.hurt(patch.damage*0.5,false,false,"tower")
	fire_patches = fire_patches.filter(func(patch): return patch.life>0)
	if state!="combat": return
	spawn_clock -= delta
	if not wave_queue.is_empty() and spawn_clock<=0:
		var entry: Dictionary = wave_queue.pop_front()
		var enemy = spawn_enemy(entry.kind,ROUTES[entry.lane][0],entry.elite)
		enemy.route = ROUTES[entry.lane]
		spawn_clock = 1.25 if defense_wave==1 else 0.95
	# A hard limit prevents stalled enemies from making an unfinishable wave.
	if wave_time>95:
		for enemy in enemies.duplicate():
			leak_enemy(enemy)
			if state!="combat": break
	if state=="combat" and wave_queue.is_empty() and enemies.is_empty(): finish_wave()
	board.queue_redraw()
	queue_redraw()

func spawn_enemy(kind: int, pos: Vector2, is_elite: bool = false):
	var enemy = DefenseEnemy.new()
	enemy.game = self
	enemy.kind = clampi(kind,0,3)
	enemy.elite = is_elite
	enemy.position = safe_position(pos)
	enemy.route = ROUTES[0]
	add_child(enemy)
	enemies.append(enemy)
	return enemy

func enemy_defeated(enemy) -> void:
	var bonus = 0
	for tower in facilities:
		if tower.kind==11 and tower.rank>=3 and tower.position.distance_to(enemy.position)<tower.reach(): bonus += 2
	energy += (8 if enemy.elite else 4)+mini(bonus,4)
	if rng.randf()<0.12: drop_heal(enemy.position,12)

func leak_enemy(enemy) -> void:
	if not is_instance_valid(enemy) or enemy.dead: return
	enemy.dead = true
	enemies.erase(enemy)
	enemy.queue_free()
	leaks += 1
	core_hp = maxf(0,core_hp-(18 if enemy.elite else 8))
	pulse_at(CORE,105,Color("#f19788"))
	shake_strength = 3
	if core_hp<=0: end_run(false)

func finish_wave() -> void:
	cleared_waves = defense_wave
	var income = 0
	for tower in facilities:
		if tower.kind==11: income += 18 if tower.rank==1 else (30 if tower.rank==2 else 38)
	energy += 65+mini(120,income)
	if defense_wave==3: end_run(true); return
	state = "td_reward"
	clear_attacks()
	clear_td_shots()
	clear_transient_effects()
	blueprint_offer.clear()
	var pool: Array[int] = []
	for i in range(12): pool.append(i)
	for i in range(3): blueprint_offer.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	td_panel.show_blueprints()

func choose_blueprint(kind: int) -> void:
	if state!="td_reward" or not blueprint_offer.has(kind): return
	blueprints[kind] = int(blueprints.get(kind,0))+1
	blueprint_offer.clear()
	if cleared_waves==2:
		reward_choice_pending = true
		state = "td_choice"
		td_panel.show_choice()
	else: enter_build()

func accept_challenge() -> void:
	if state!="td_choice": return
	reward_choice_pending = false
	enter_build()

func end_run(victory: bool) -> void:
	if result_paid: return
	result_paid = true
	won = victory
	state = "td_result"
	wave_queue.clear()
	clear_td_shots()
	clear_attacks()
	var coins = cleared_waves*90+(150 if cleared_waves==3 else 0)
	var experience = cleared_waves*100
	profile.data.gold += coins
	earned_gold = coins
	add_xp(experience)
	if cleared_waves>=2:
		var item = profile.make_item(selected_role,rng.randi_range(0,5),2 if cleared_waves==3 else 1,maxi(1,int(profile.data.roles[selected_role].level)),rng)
		receive_gear(item)
	profile.dirty = true
	profile.save_profile()
	result_text = "守卫成功" if victory else ("核心失守" if core_hp<=0 else "角色倒下")
	td_panel.show_result()

func collect_defense_reward() -> void:
	if state=="td_choice": end_run(true)

func back_to_menu() -> void:
	profile.save_profile()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func pause_game(_stats_view: bool = false) -> void:
	if state!="combat": return
	state = "paused"
	td_panel.show_pause()

func resume_game() -> void:
	if state!="paused": return
	state = "combat"
	focused = true
	td_panel.show_combat()

func safe_position(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x,105,1350),clampf(pos.y,195,912))

func clear_td_shots() -> void:
	for projectile in get_tree().get_nodes_in_group("td_shots"): projectile.queue_free()

func clear_transient_effects() -> void:
	fire_patches.clear()
	zones.clear()
	board.effects.clear()
	fx.clear()
	fx.queue_redraw()
	art.glyphs.clear()
	art.queue_redraw()

func nearest_guardian(pos: Vector2):
	var closest = null
	for tower in facilities:
		if tower.kind!=7 or tower.disabled_time>0 or pos.distance_to(tower.position)>tower.reach(): continue
		if closest==null or pos.distance_squared_to(tower.position)<pos.distance_squared_to(closest.position): closest = tower
	return closest

func chain_target(pos: Vector2, excluded: Array, reach: float):
	var closest = null
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.state=="spawn" or excluded.has(enemy) or pos.distance_to(enemy.position)>reach: continue
		if closest==null or pos.distance_squared_to(enemy.position)<pos.distance_squared_to(closest.position): closest = enemy
	return closest

func tower_multiplier(tower) -> float:
	var buffs = 0
	for other in facilities:
		if other.kind==10 and other!=tower and other.position.distance_to(tower.position)<other.reach(): buffs += 1
	# Multiple crystals add diminishing returns; never multiply recursively.
	return 1.0+(0.12 if buffs>0 else 0.0)+minf(0.12,maxi(0,buffs-1)*0.04)

func tower_blast(pos: Vector2, radius_value: float, damage: float, rank: int) -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(pos)<radius_value:
			enemy.hurt(damage,false,false,"tower")
			if rank>=3: enemy.burn_time = 3; enemy.td_burn = damage*0.2
	art.emit("blast",pos,Vector2.UP,radius_value,0.45,1)
	if rank>=3:
		if fire_patches.size()>=24: fire_patches.pop_front()
		fire_patches.append({"position":pos,"radius":radius_value*0.75,"damage":damage*0.18,"life":2.5,"tick":0.5})
	tower_sound("explosion")

func tower_sound(id: String) -> void:
	if td_sound_clock>0: return
	td_sound_clock = 0.14
	sound.play(id)

func pulse_at(pos: Vector2, radius_value: float, color: Color) -> void:
	board.effects.append({"from":pos,"to":pos,"radius":radius_value,"color":color,"life":0.5})

func energy_arc(from: Vector2, to: Vector2, color: Color) -> void:
	board.effects.append({"from":from,"to":to,"radius":0.0,"color":color,"life":0.3})
