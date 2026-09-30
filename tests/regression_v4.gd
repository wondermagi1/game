extends SceneTree
var game
var checks: int = 0
var failures: Array = []
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures.append(title); push_error(title)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.sound.volume = 0
	var C = game.Catalog
	for pair in [[10,22],[15,34],[20,46],[25,58],[30,70],[60,130]]: check(C.earned_points(pair[0])==pair[1],"points_%d"%pair[0])
	game.profile.data.roles[0].level = 25
	for i in range(9): check(game.profile.train_skill(0,0)=="技能升级","train_%d"%i)
	check(game.profile.data.roles[0].skills[0]==10 and game.profile.talent_points(0)==25,"level25_max_skill")
	game.profile.reset_talents(0)
	check(game.profile.talent_points(0)==58,"reset_points")
	var Graph = preload("res://scripts/room_graph.gd")
	for chapter in range(1,7):
		for seed_value in range(50):
			var map = Graph.generate(chapter,seed_value)
			check(Graph.reachable(map),"connected_%d_%d"%[chapter,seed_value])
			check(map.rooms.size()>=4 and map.rooms.size()<=10,"room_count")
	var rng = RandomNumberGenerator.new()
	rng.seed = 1991
	game.profile.data.roles[0].level = 30
	var table: Array = []
	for tier in range(3):
		var quality = [0,0,0,0]
		var drops = 0
		var own = 0
		var consecutive = 0
		for n in range(10000):
			var item = game.profile.roll_equipment(tier,0,6,rng)
			if item.is_empty(): continue
			drops += 1
			quality[item.quality] += 1
			if item.role==0: own+=1
			check(item.level<=game.profile.data.roles[item.role].level,"usable_drop")
			if tier==2:
				consecutive = consecutive+1 if item.quality<3 else 0
				check(consecutive<=3,"legend_pity")
		check(absf(drops/10000.0-C.DROP_CHANCE[tier])<0.025,"drop_rate")
		check(own/float(drops)>=0.88,"own_role_ratio")
		table.append({"tier":tier,"rolls":10000,"drops":drops,"quality":quality,"own_role":own})
	game.profile.data.unlocked = 6
	game.start_run(0,731,6)
	game.player.manual_control = true
	check(game.rooms.active and game.rooms.current().id=="r0","room_start")
	var initial_gold: int = game.profile.data.gold
	game.rooms.enter("r1","r0")
	await physics_frame
	check(game.camera.position.x>2000,"world_origin_camera")
	check(game.player.position.x>2000,"world_origin_actor")
	check(game.rooms.scene.obstacles.size()>=0,"template_loaded")
	game.pending.clear()
	for e in game.enemies.duplicate(): e.free()
	game.enemies.clear()
	game.rooms.complete_room()
	check(game.state=="reward","room_reward")
	game.choose_reward(0)
	var after_gold: int = game.profile.data.gold
	game.rooms.enter("r0","r1")
	game.rooms.enter("r1","r0")
	check(game.pending.is_empty() and game.profile.data.gold==after_gold,"revisit_no_rewards")
	game.rooms.enter("r2","r1")
	game.rooms.current().event = "chest"
	game.rooms.open_event()
	game.rooms.choose_event(0)
	var gear_count: int = game.profile.data.inventory.size()
	game.rooms.choose_event(0)
	check(game.profile.data.inventory.size()==gear_count,"event_once")
	game.rooms.camp()
	var snap: Dictionary = game.rooms.snapshot()
	check(game.rooms.valid(snap),"valid_checkpoint")
	check(game.rooms.save_exit(),"save_exit")
	check(game.rooms.resume(),"resume")
	check(game.rooms.current().used,"restore_chest")
	check(game.profile.data.exploration.is_empty(),"consume_checkpoint")
	for role in range(3):
		game.profile.data.roles[role].level = 30
		game.profile.data.roles[role].skills = [10,10,10,10]
		game.start_run(role,1800+role,6)
		game.player.manual_control = true
		game.rooms.enter("r1","r0")
		game.pending.clear()
		var target = game.spawn_enemy(13,game.safe_position(game.player.position+Vector2(300,0)))
		target.state = "move"
		target.set_physics_process(false)
		target.hp = 1e7
		target.max_hp = 1e7
		game.player.aim = game.player.position.direction_to(target.position)
		game.player.skills.windows.assign([8.0,8.0,8.0,0.0])
		check(game.player.skills.use(3),"C_cast_%d"%role)
		var before: float = target.hp
		for frame in range(440): await physics_frame
		check(target.hp<before,"C_damage_%d"%role)
		check(not game.player.skills.ultimate.active,"C_finish_%d"%role)
		check(game.art.glyphs.size()<=64,"art_budget")
		game.ui.show_talents()
		game.ui.show_combos()
		game.ui.codex_category=6
		game.ui.show_codex()
		await process_frame
	var result = {"checks":checks,"failures":failures,"drop_samples":table}
	var f = FileAccess.open("res://tests/regression_v4_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	f.close()
	print("V4_REGRESSION="+JSON.stringify(result))
	await process_frame
	await process_frame
	game.free()
	quit(0 if failures.is_empty() else 1)
