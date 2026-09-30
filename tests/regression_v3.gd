extends SceneTree
var game
var checks: Array = []
var failed: Array = []
func _initialize() -> void:
	call_deferred("run_tests")
func check(condition: bool, title: String) -> void:
	checks.append(title)
	if not condition:
		failed.append(title)
		push_error("FAILED: "+title)
func setup_role(role: int = 0) -> void:
	game.profile.memory_only = true
	game.profile.fresh()
	game.profile.events.clear()
	game.profile.data.unlocked = 6
	game.profile.data.roles[role].level = 60
	game.start_run(role,4921,6)
	game.player.manual_control = true
	game.progress_delay = 999
func target(pos: Vector2 = Vector2(1200,600)):
	var e = game.spawn_enemy(0,pos)
	e.state = "move"
	e.hp = 100000
	e.max_hp = e.hp
	return e
func hit(e, source: String, empowered: bool = false):
	var shot = game.Projectile.new()
	shot.source = source
	shot.empowered = empowered
	shot.damage = 10
	game.player.skills.on_hit(e,shot)
	var result = shot.bounce
	shot.free()
	return result
func run_tests() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	var p = game.profile
	var uid: String = p.data.inventory[0].uid
	check(p.data.material==3,"new player receives three starter materials")
	var gold: int = p.data.gold
	check(p.enhance(uid)=="强化成功","starter equipment can enhance")
	check(p.data.gold==gold-45 and p.data.material==2 and p.item_by_id(uid).enhance==1,"enhancement charges exact resources once")
	p.data.gold = 0
	var held: int = p.data.material
	check(p.enhance(uid).begins_with("金币不足") and p.data.material==held,"insufficient gold does not consume materials")
	p.data.gold = 100000
	p.data.material = 0
	check(p.enhance(uid).begins_with("材料不足") and p.data.gold==100000,"insufficient material does not consume gold")
	p.data.material = 1000
	for i in range(9): p.enhance(uid)
	gold = p.data.gold
	check(p.item_by_id(uid).enhance==10 and p.enhance(uid).contains("上限") and p.data.gold==gold,"enhancement max +10")
	var settings = ConfigFile.new()
	check(game.bindings.bind_key("item_1",KEY_Z),"bind item one to Z")
	check(not game.bindings.bind_key("item_2",KEY_Z),"conflict cannot silently overwrite")
	check(game.bindings.bind_key("item_2",KEY_Z,true) and game.bindings.keys.item_1==KEY_2,"explicit swap keeps both actions")
	check(not game.bindings.bind_key("item_3",KEY_ESCAPE),"Escape remains reserved")
	game.bindings.save_config(settings)
	var loaded_bindings = load("res://scripts/input_bindings.gd").new()
	loaded_bindings.load_config(settings)
	check(loaded_bindings.keys==game.bindings.keys,"bindings roundtrip")
	var key_event = InputEventKey.new()
	key_event.physical_keycode = KEY_Z
	key_event.pressed = true
	check(InputMap.event_is_action(key_event,"item_2"),"actual InputMap uses assigned physical key")
	setup_role()
	game.state = "menu"
	game.ui.view_role = 0
	game.ui.show_talents()
	for i in range(4): await process_frame
	var scroll: ScrollContainer
	for node in game.ui.overlay.get_children():
		if node is ScrollContainer: scroll = node
	scroll.scroll_vertical = 1100
	await process_frame
	var previous = scroll.scroll_vertical
	game.ui.train_passive("step")
	for i in range(5): await process_frame
	for node in game.ui.overlay.get_children():
		if node is ScrollContainer: scroll = node
	check(scroll.scroll_vertical==previous and previous>0,"talent purchase preserves bottom scroll")
	game.ui.show_bindings()
	game.ui.begin_binding("item_3")
	var key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	game.ui._input(key)
	check(game.ui.binding_action.is_empty(),"binding Escape cancels without pausing/resuming")
	game.ui.begin_binding("item_3")
	game.ui.show_consumables()
	check(game.ui.binding_action.is_empty(),"leaving key capture clears capture state")
	game.bindings.keys = game.bindings.DEFAULTS.duplicate()
	game.bindings.apply()
	# Deterministic combo conditions, including a killing hit and collateral damage.
	setup_role(1)
	var enemy = target()
	var collateral = target(Vector2(1250,610))
	enemy.blast_mark = 6
	enemy.hp = 1
	enemy.hurt(100,false,false)
	var hp: float = collateral.hp
	hit(enemy,"normal",true)
	check(game.player.skills.combo_count==1 and collateral.hp<hp,"fatal empowered hit detonates at last target position")
	game.player.skills.combo_cd = 0
	collateral.powder_mark = 6
	hit(collateral,"normal")
	check(game.player.skills.combo_count==2,"gun shotgun mark plus normal triggers deterministically")
	game.player.skills.use(2)
	check(game.player.skills.empowered_shots>=3,"tactical reload grants multiple empowered bullets")
	setup_role(0)
	enemy = target()
	enemy.sword_mark = 6
	hit(enemy,"normal")
	check(game.player.skills.combo_count==1,"sword mark plus normal combo")
	game.player.orbit_time = 3
	game.player.skills.use(2)
	check(game.player.skills.combo_count==2,"sword orbit plus dash combo")
	setup_role(2)
	enemy = target()
	enemy.mark_time = 6
	hit(enemy,"sun")
	check(game.player.skills.combo_count==1,"bow hunt plus sun combo")
	game.add_zone(enemy.position,200,6,6,0,"arrows",1)
	check(hit(enemy,"normal")==2 and game.player.skills.combo_count==2,"bow rain plus normal extra bounce combo")
	var count: int = game.player.skills.combo_count
	hit(enemy,"set")
	check(game.player.skills.combo_count==count,"secondary sources do not recursively combo")
	for role in range(3):
		setup_role(role)
		for slot in range(4):
			for rank in [1,3,5,8,10]:
				p.data.roles[role].skills[slot] = rank
				game.player.skills.cooldowns[slot] = 0
				check(game.player.skills.use(slot),"role %d slot %d rank %d casts"%[role,slot,rank])
	# Every buff remains eligible in abyss at high stacks, bounded objects and finite stats.
	for role in range(3):
		var stats = game.Stats.new(role)
		stats.abyss = true
		for u in game.Data.UPGRADES:
			if u[7] not in [-1,role]: continue
			for i in range(41): stats.apply(u)
			check(stats.eligible(u),"abyss buff %s remains eligible"%u[0])
		check(stats.evolution_tier("共鸣")==4 and stats.evolution_tier("守护")==4,"all evolution tiers reachable role %d"%role)
		var attack: float = stats.value("attack")
		for u in game.Data.UPGRADES:
			if u[7] in [-1,role]: stats.apply(u)
		check(stats.value("attack")>attack,"post milestone stacks still improve role %d"%role)
		for key_name in ["hp","attack","crit","armor","rate","speed","crit_damage"]: check(is_finite(stats.value(key_name)),"finite deep stats %d %s"%[role,key_name])
		check(stats.bonus("multishot")<=6 and stats.value("rate")<=12.5 and stats.value("armor")<400,"object/rate/armor limits role %d"%role)
		for key_name in stats.bonuses: stats.bonuses[key_name] = 1e12
		check(is_finite(stats.value("attack")) and stats.value("attack")<=1e15,"engineering value limit role %d"%role)
	setup_role()
	for kind in [9,10,11,12,13]:
		var e = game.spawn_enemy(kind,Vector2(400,400))
		e.state = "move"
		check(e.is_boss()==(kind>=12),"new enemy classification %d"%kind)
		e.execute_attack()
	check(game.hazards.size()>0,"new casters/bosses create telegraphed hazards")
	var split = game.spawn_enemy(10,Vector2(650,500))
	split.state = "move"
	split.hurt(1e12,false,false)
	var fragments = game.enemies.filter(func(e): return e.fragment)
	check(fragments.size()==2,"splitter creates exactly two children")
	var enemy_count = game.enemies.size()
	fragments[0].state = "move"
	fragments[0].hurt(1e12,false,false)
	check(game.enemies.size()==enemy_count-1,"split children do not split recursively")
	setup_role()
	p.data.cleared = [1,2,3,4,5,6]
	game.back_to_menu()
	game.abyss.start(0,761)
	check(game.flow.abyss and game.player.stats.abyss,"abyss starts with separate rule set")
	for floor_id in range(1,31):
		check(game.flow.floor_number==floor_id,"sequential abyss floor %d"%floor_id)
		game.progress_delay = 0
		game.begin_wave()
		check((game.flow.boss_kind()>=0)==(floor_id%10==0),"boss cadence floor %d"%floor_id)
		game.pending.clear()
		game.director.elapsed = game.director.duration
		game.stage_finished()
		check(game.state=="reward" and game.rewards.size()==3,"three choices floor %d"%floor_id)
		game.choose_reward(0)
		check(game.state==("intermission" if floor_id%5==0 else "combat"),"rest cadence floor %d"%floor_id)
		if floor_id%5==0:
			var stock: Array = game.flow.stock.duplicate(true)
			p.data.gold = 100000
			p.buy(game.flow.stock,0)
			var saved_gold: int = p.data.gold
			var stacks: Dictionary = game.player.stats.stacks.duplicate(true)
			var rng_state: int = game.rng.state
			check(game.abyss.save_exit(),"checkpoint save floor %d"%floor_id)
			check(game.abyss.resume(),"checkpoint resume floor %d"%floor_id)
			check(game.flow.stock[0].sold and p.data.gold==saved_gold and game.player.stats.stacks==stacks and game.rng.state==rng_state,"checkpoint restores sold stock, rewards, RNG floor %d"%floor_id)
			check(p.data.checkpoint.is_empty(),"checkpoint consumed before play floor %d"%floor_id)
			game.next_round()
	check(p.data.abyss_best[0]==30 and p.data.achievements.has("abyss30"),"best floor and milestone achievement")
	game.state = "intermission"
	game.flow.floor_number = 35
	p.memory_only = false
	p.read_only = true
	check(not game.abyss.save_exit() and game.state=="intermission","failed checkpoint save preserves current rest")
	p.read_only = false
	p.memory_only = true
	# Actual checksummed disk roundtrip and migration use an isolated test path.
	game.back_to_menu()
	p.path = "res://tests/profile-v3-fixture.json"
	p.memory_only = false
	p.fresh()
	p.data.version = 2
	p.data.erase("v3_grant")
	p.data.erase("favorites")
	p.data.erase("checkpoint")
	p.data.erase("abyss_best")
	p.data.material = 7
	p.data.cleared = [1,2,3,4]
	p.data.roles[0].skills = [3,2,1,1]
	p.data.roles[0].spent = 7
	uid = p.data.inventory[0].uid
	check(p.save_profile(),"isolated V2 fixture saves")
	p.load_profile()
	check(p.data.material==10 and p.data.unlocked==5 and p.data.roles[0].spent==7 and p.data.roles[0].skills==[3,2,1,1] and p.data.inventory[0].uid==uid,"V2 migration preserves identity and allocated points")
	p.save_profile()
	p.load_profile()
	check(p.data.material==10,"migration gift cannot repeat")
	p.memory_only = true
	# Codex visibility and reading must not grant ownership.
	game.ui.codex_category = 0
	var before_inventory: int = p.data.inventory.size()
	var before_found: Dictionary = p.data.found.duplicate(true)
	for category in range(8):
		game.ui.codex_category = category
		game.ui.show_codex()
		check(not game.ui.codex_entries().is_empty(),"codex category %d populated"%category)
		game.ui.open_entry(game.ui.codex_entries()[0].id)
	check(p.data.inventory.size()==before_inventory and p.data.found==before_found,"codex browsing grants no assets")
	p.events.clear()
	p.data.achievements.erase("combo")
	p.unlock("combo")
	p.unlock("combo")
	check(p.events.size()==1,"achievement notification fires once")
	gold = p.data.gold
	p.claim_achievement("combo")
	p.claim_achievement("combo")
	check(p.data.gold==gold+80,"achievement rewards claimed once")
	var report = {"checks":checks.size(),"failures":failed,"passed":failed.is_empty(),"checks_detail":checks}
	var file = FileAccess.open("res://tests/results_v3.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	game.reset_entities()
	game.free()
	await process_frame
	print("REGRESSION_V3 "+JSON.stringify({"checks":checks.size(),"failures":failed}))
	quit(0 if failed.is_empty() else 1)
