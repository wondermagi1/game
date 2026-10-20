extends SceneTree
## Real node integration; in-memory profile, isolated from the user's saves.
var game
var checks: int = 0
var failures: Array[String] = []
var capture: bool = false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func settle(count: int = 5) -> void:
	for i in range(count): await process_frame

func shot(title: String) -> void:
	if not capture: return
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/tower-defense"))
	root.get_texture().get_image().save_png("res://docs/tower-defense/"+title+".png")

func fresh(role: int = 0) -> void:
	game.start_defense(role,12345)
	game.player.manual_control = true
	game.set_physics_process(false)
	await settle()

func enemy_at(pos: Vector2, elite: bool = false):
	game.defense_wave = maxi(1,game.defense_wave)
	var enemy = game.spawn_enemy(0,pos,elite)
	enemy.state = "move"
	enemy.set_physics_process(false)
	enemy.hp = 10000
	enemy.max_hp = 10000
	return enemy

func remove_enemies() -> void:
	for enemy in game.enemies.duplicate():
		game.enemies.erase(enemy)
		enemy.free()

func run() -> void:
	game = load("res://scenes/TowerDefense.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.reduced_motion = true
	await settle()
	verify(game.state=="menu","role selection opens")
	await shot("01-selection")
	# The mode must preserve a preexisting campaign/abyss checkpoint.
	game.profile.data.exploration = {"sentinel":"campaign"}
	game.profile.data.checkpoint = {"sentinel":"abyss"}
	for role in range(3):
		await fresh(role)
		verify(game.player.stats.role==role,"existing role starts: %d"%role)
		verify(game.state=="td_build" and game.energy==190,"initial budget and build phase")
		verify(game.profile.data.exploration=={"sentinel":"campaign"},"campaign checkpoint preserved")
		verify(game.profile.data.checkpoint=={"sentinel":"abyss"},"abyss checkpoint preserved")
	await fresh()
	verify(not game.start_wave(),"cannot start empty layout")
	verify(not game.build_facility(-1,0) and not game.build_facility(0,12),"invalid build inputs rejected")
	var before = game.energy
	verify(game.build_facility(0,0),"build sword facility")
	verify(game.energy==before-45,"build charges exact cost")
	verify(not game.build_facility(0,1),"occupied slot rejected")
	verify(game.build_facility(1,0),"same type can be built repeatedly")
	game.energy = 500
	for rank in range(2,5):
		before = game.energy
		var cost: int = game.price(0,rank-1)
		verify(game.upgrade_facility(0),"upgrade succeeds %d"%rank)
		verify(game.tower_at(0).rank==rank and game.energy==before-cost,"rank/currency correct")
	before = game.energy
	game.blueprints[0] = 1
	verify(not game.upgrade_facility(0) and not game.upgrade_facility(0,true),"rank four hard cap, including blueprint")
	verify(game.energy==before and game.blueprints[0]==1,"cap never consumes currency or blueprint")
	verify(game.upgrade_facility(1,true) and game.blueprints[0]==0,"matching blueprint upgrades existing facility")
	game.blueprints[1] = 1
	verify(game.build_facility(2,1,true),"blueprint builds free facility")
	before = game.energy
	verify(game.sell_facility(2) and game.energy==before,"free blueprint has no resale arbitrage")
	game.energy = 0
	verify(not game.build_facility(2,2) and not game.upgrade_facility(1),"insufficient funds rejected")
	game.energy = 50
	game.core_hp = 70
	verify(game.repair_core() and game.core_hp==95 and game.energy==25,"core repair cost/healing")
	game.energy = 9999
	# Each of the twelve facilities builds, reaches IV, and executes real effects.
	for kind in range(12):
		await fresh()
		game.energy = 9999
		verify(game.build_facility(4,kind),"facility builds %d"%kind)
		var tower = game.tower_at(4)
		for i in range(3): game.upgrade_facility(4)
		verify(tower.rank==4,"facility reaches IV %d"%kind)
		game.state = "combat"
		game.player.position = tower.position+Vector2(40,0)
		game.player.hp = 25
		game.player.slow_time = 5
		var enemy = enemy_at(tower.position+Vector2(110,0))
		var second = enemy_at(tower.position+Vector2(150,25))
		var initial_hp: float = enemy.hp
		if kind==10:
			game.state = "td_build"
			game.build_facility(6,0)
			game.tower_at(6).position = tower.position+Vector2(70,0)
			game.state = "combat"
			tower.activate()
			verify(game.tower_at(6).boost_time>0 and game.tower_at(6).overcharge>0,"crystal haste and overcharge")
			verify(is_equal_approx(game.tower_multiplier(game.tower_at(6)),1.12),"crystal damage bonus")
		elif kind==11:
			verify(is_equal_approx(game.discount(),0.88),"collector IV discount")
			before = game.energy
			game.enemy_defeated(enemy)
			verify(game.energy==before+6,"collector III kill revenue")
			before = game.energy
			game.finish_wave()
			verify(game.energy==before+65+38,"collector end wave revenue")
		else:
			for i in range(4): tower.activate()
			if kind<3:
				for i in range(30):
					for projectile in get_nodes_in_group("td_shots"):
						if not projectile.is_queued_for_deletion(): projectile._physics_process(1.0/60.0)
					await process_frame
			if kind==9:
				verify(game.player.hp>25 and game.player.slow_time==0 and game.player.barrier>0,"fountain healing cleanse shield")
			else: verify(enemy.hp<initial_hp,"facility actually damages enemy %d"%kind)
			if kind==3: verify(second.hp<10000,"lightning chains to second target")
			if kind==4: verify(enemy.burn_time>0 and enemy.weakened>0,"dragon burn and armor debuff")
			if kind==5: verify(enemy.freeze_time>0 and enemy.slow_time>0,"frost accumulates freeze")
			if kind==6: verify(enemy.pull_velocity.length()>0,"gravity applies displacement")
			if kind==7:
				verify(game.nearest_guardian(enemy.position)==tower,"guardian attracts nearby enemies")
				tower.take_hit(9999)
				verify(tower.disabled_time>0 and game.nearest_guardian(enemy.position)==null,"broken guardian releases enemies")
				tower._physics_process(13)
				verify(tower.hp==tower.max_hp,"guardian recovers after downtime")
			if kind==8: verify(enemy.freeze_time>0,"thorns root enemies")
		remove_enemies()
	await fresh(1)
	game.energy = 700
	for entry in [[0,1],[1,0],[4,2],[5,5],[8,10],[7,11]]: game.build_facility(entry[0],entry[1])
	game.selected_pad = 4
	game.upgrade_facility(4)
	game.upgrade_facility(4)
	game.upgrade_facility(4)
	await shot("02-build")
	verify(game.start_wave(),"first wave starts")
	verify(not game.build_facility(2,0) and not game.upgrade_facility(0),"combat prevents construction")
	game._physics_process(2)
	verify(game.enemies.size()==1 and game.wave_queue.size()==17,"wave queue spawns real enemy")
	var mover = game.enemies[0]
	var progress = mover.position
	# CharacterBody2D.move_and_slide uses the actual physics-frame delta.
	# Let the physics server advance rather than calling it repeatedly in one frame.
	for i in range(70): await physics_frame
	verify(is_instance_valid(mover) and mover.position.distance_to(progress)>10,"enemy advances along route")
	game.pause_game()
	var time_before: float = game.elapsed
	game._physics_process(10)
	verify(game.elapsed==time_before and game.state=="paused","pause stops wave time")
	game.resume_game()
	verify(game.state=="combat","resume restores battle")
	var elite = enemy_at(Vector2(1000,700),true)
	elite.crowd_control(1)
	verify(elite.freeze_time<=0.33,"elite control resistance")
	var controlled: float = elite.freeze_time
	elite.crowd_control(8)
	verify(elite.freeze_time==controlled,"elite cannot be chain-frozen")
	remove_enemies()
	game.wave_queue.clear()
	game.finish_wave()
	verify(game.state=="td_reward" and game.blueprint_offer.size()==3,"wave reward offers three distinct blueprints")
	await shot("04-blueprint")
	game.choose_blueprint(game.blueprint_offer[0])
	verify(game.state=="td_build","blueprint returns to building")
	verify(game.start_wave() and game.defense_wave==2,"second wave starts")
	game.wave_queue.clear()
	game.finish_wave()
	game.choose_blueprint(game.blueprint_offer[0])
	verify(game.state=="td_choice","second victory offers stop or challenge")
	await shot("05-choice")
	game.accept_challenge()
	verify(game.state=="td_build" and game.start_wave() and game.defense_wave==3,"optional elite wave starts")
	verify(game.wave_queue.filter(func(e): return e.elite).size()==4,"third wave has exactly four elites")
	var gold_before: int = game.profile.data.gold
	game.wave_queue.clear()
	game.finish_wave()
	verify(game.state=="td_result" and game.earned_gold==420 and game.earned_xp==300 and game.earned_gear==1,"full reward deposited")
	verify(game.profile.data.gold==gold_before+420,"exact permanent currency award")
	game.end_run(true)
	verify(game.profile.data.gold==gold_before+420,"settlement idempotence")
	verify(game.profile.data.exploration=={"sentinel":"campaign"} and game.profile.data.checkpoint=={"sentinel":"abyss"},"settlement preserves checkpoints")
	await shot("06-result")
	await fresh()
	game.state = "combat"
	game.defense_wave = 3
	game.cleared_waves = 2
	game.end_run(false)
	verify(game.earned_gold==180 and game.earned_xp==200 and game.earned_gear==1,"failed elite challenge preserves two-wave reward")
	await fresh()
	game.state = "td_choice"
	game.cleared_waves = 2
	game.collect_defense_reward()
	verify(game.won and game.earned_gold==180 and game.earned_gear==1,"cash-out after two waves")
	await fresh()
	game.state = "combat"
	game.defense_wave = 1
	game.wave_queue.assign([{"kind":0,"lane":0,"elite":false}])
	var patch_target = enemy_at(Vector2(800,450))
	game.tower_blast(Vector2(800,450),100,60,3)
	verify(game.fire_patches.size()==1,"cannon III leaves a real fire zone")
	patch_target.burn_time = 0
	var health_before: float = patch_target.hp
	game._physics_process(0.6)
	verify(patch_target.hp<health_before,"standing in fire zone causes damage independently of burn status")
	game.enter_build()
	verify(game.fire_patches.is_empty() and game.zones.is_empty(),"wave preparation clears lingering damage zones")
	await fresh()
	game.build_facility(0,0)
	game.start_wave()
	game.core_hp = 8
	var leak = enemy_at(game.CORE)
	game.leak_enemy(leak)
	verify(game.core_hp==0 and game.state=="td_result" and not game.won,"core destruction fails run")
	verify(game.earned_gold==0 and game.earned_gear==0,"zero cleared waves grant no completion rewards")
	await fresh()
	game.state = "combat"
	game.player.invulnerable = 0
	game.player.hurt(1e10)
	verify(game.state=="td_result","player death fails run")
	await fresh()
	game.energy = 700
	for entry in [[0,1],[1,0],[4,2],[5,5],[8,10],[7,11]]: game.build_facility(entry[0],entry[1])
	game.start_wave()
	for i in range(8):
		var foe = game.spawn_enemy(i%4,game.ROUTES[i%2][0]+Vector2(50+i*45,0))
		foe.route = game.ROUTES[i%2]
		foe.state = "move"
	game.set_physics_process(true)
	for i in range(120): await physics_frame
	await shot("03-battle")
	game.state = "td_result"
	game.reset_entities()
	game.queue_free()
	await settle()
	# Exercise the actual main-menu callback and scene transition.
	var menu = load("res://scenes/Main.tscn").instantiate()
	menu.test_mode = true
	root.add_child(menu)
	current_scene = menu
	menu.sound.volume = 0
	var entrance = null
	for button in menu.ui.overlay.find_children("*","Button",true,false):
		if button.text=="遗迹守卫": entrance = button
	verify(entrance!=null,"main menu contains relic defense entrance")
	if entrance!=null:
		entrance.pressed.emit()
		await settle(10)
		verify(current_scene!=null and current_scene.has_method("start_defense"),"menu entrance loads the real defense scene")
		if current_scene!=null:
			current_scene.profile.memory_only = true
			current_scene.sound.volume = 0
			current_scene.queue_free()
	await settle()
	var result = {"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://tests/tower_defense_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("TD_TEST_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
