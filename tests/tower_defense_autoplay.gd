extends SceneTree
## No injected damage or free resources: fresh level-one heroes, real waves.
var game
var results: Array = []

func _initialize() -> void:
	call_deferred("run")

func plan() -> void:
	# Initial 190 energy: meaningful coverage of both routes.
	for entry in [[0,1],[1,0],[4,2],[5,5]]:
		if game.tower_at(entry[0])==null: game.build_facility(entry[0],entry[1])
	for kind in game.blueprints:
		if game.blueprints[kind]<=0: continue
		var match_slot = -1
		for tower in game.facilities:
			if tower.kind==kind and tower.rank<4: match_slot = tower.pad; break
		if match_slot>=0: game.upgrade_facility(match_slot,true)
		else:
			for slot in [6,7,8,9,2,3]:
				if game.tower_at(slot)==null: game.build_facility(slot,kind,true); break
	if game.cleared_waves>0:
		for slot in [4,0,1,5,4,0,1]: game.upgrade_facility(slot)
		if game.core_hp<80: game.repair_core()
	game.start_wave()

func run() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	for role in range(3):
		game = load("res://scenes/TowerDefense.tscn").instantiate()
		game.test_mode = true
		root.add_child(game)
		game.sound.volume = 0
		game.start_defense(role,500+role)
		game.player.manual_control = true
		var budget: int = 18000
		var skill_clock: float = 0.0
		while game.state!="td_result" and budget>0:
			budget -= 1
			if game.state=="td_build": plan()
			elif game.state=="td_reward": game.choose_blueprint(game.blueprint_offer[0])
			elif game.state=="td_choice": game.accept_challenge()
			elif game.state=="combat":
				var player = game.player
				var target = game.nearest_enemy(player.position,[],1000)
				var goal = Vector2(830,550)
				if is_instance_valid(target):
					player.aim = player.position.direction_to(target.position)
					goal = Vector2(clampf(target.position.x+250,570,1110),clampf(target.position.y,320,780))
					player.request_attack()
					if skill_clock<=0:
						player.request_skill(0)
						skill_clock = 1
				player.scripted_movement = player.position.direction_to(goal) if player.position.distance_to(goal)>45 else Vector2.ZERO
				skill_clock -= 1.0/60.0
			await physics_frame
		var record = {"role":role,"won":game.won,"cleared":game.cleared_waves,"seconds":snappedf(game.elapsed,0.1),"kills":game.kills,"leaks":game.leaks,"core":game.core_hp,"hero_hp":snappedf(game.player.hp,0.1),"gold":game.earned_gold,"remaining_budget":budget}
		results.append(record)
		print("TD_AUTOPLAY_ROLE ",JSON.stringify(record))
		game.reset_entities()
		game.queue_free()
		for i in range(5): await process_frame
	FileAccess.open("res://tests/tower_defense_autoplay_results.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	var passed = results.all(func(result): return result.won and result.cleared==3 and result.remaining_budget>0)
	print("TD_AUTOPLAY_PASS ",passed)
	quit(0 if passed else 1)
