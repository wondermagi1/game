extends SceneTree
var game
var results: Array = []
var failures: Array = []
func _initialize() -> void:
	call_deferred("run_tests")
func check(value: bool, name: String) -> void:
	results.append(name)
	if not value: failures.append(name); push_error(name)
func run_tests() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.profile.data.unlocked = 6
	game.profile.data.cleared = [1,2,3,4,5,6]
	game.profile.data.roles[1].level = 30
	game.start_run(1,723,6)
	game.player.hp = 20
	game.progress_delay = 999
	game.bindings.bind_key("item_1",KEY_Z)
	var before: int = game.profile.data.consumables.potion
	var event = InputEventKey.new()
	event.physical_keycode = KEY_Z
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	for i in range(4): await physics_frame
	check(game.profile.data.consumables.potion==before-1 and game.player.hp>20,"physical Z event consumes potion exactly once")
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	game.pause_game()
	game.ui.show_bindings()
	game.ui.begin_binding("item_1")
	var gold: int = game.profile.data.gold
	before = game.profile.data.consumables.potion
	event.physical_keycode = KEY_X
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	for i in range(4): await physics_frame
	check(game.bindings.keys.item_1==KEY_X and game.profile.data.consumables.potion==before and game.projectiles.is_empty(),"capturing X changes key without consuming or attacking")
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	game.back_to_menu()
	game.abyss.start(1,989)
	game.player.manual_control = true
	game.progress_delay = 999
	game.flow.floor_number = 5
	game.flow.wave = 1
	game.state = "intermission"
	game.ensure_shop()
	game.profile.data.gold = 1000
	game.profile.buy(game.flow.stock,0)
	game.player.stats.apply(game.Data.UPGRADES[2])
	game.player.skills.temporary = [1,0,2,0]
	game.player.revive_used = true
	game.player.item_clocks.potion = 3.5
	game.player.hp = 100
	game.profile.path = "res://tests/checkpoint-integration-v3.json"
	game.profile.memory_only = false
	gold = game.profile.data.gold
	var rng_state: int = game.rng.state
	check(game.abyss.save_exit(),"checkpoint written to real isolated file")
	game.profile.load_profile()
	check(game.abyss.resume(),"checkpoint survives JSON load and resume")
	check(game.profile.data.gold==gold and game.flow.stock[0].sold,"real disk resume preserves currency and sold stock")
	check(game.player.stats.stacks.power==1 and game.player.skills.temporary[2]==2 and game.player.revive_used and game.player.item_clocks.potion==3.5,"real disk resume restores temporary progression and cooldowns")
	check(game.rng.state==rng_state,"64 bit RNG state roundtrips losslessly")
	game.profile.load_profile()
	check(game.profile.data.checkpoint.is_empty(),"consumed checkpoint remains consumed on fresh load")
	game.profile.memory_only = true
	game.next_round()
	check(game.flow.floor_number==6 and game.player.revive_used,"resume advances next floor without renewing abyss revive")
	game.back_to_menu()
	var damage_records: Array = []
	for role in range(3):
		for build in ["low","recommended","developed"]:
			var fixture = preload("res://tests/build_fixture.gd").configure(game,6,role,build)
			game.start_run(role,4811+role,6)
			game.player.manual_control = true
			game.progress_delay = 999
			game.player.position = Vector2(600,500)
			game.player.aim = Vector2.RIGHT
			var target = game.spawn_enemy(3,Vector2(1000,500))
			target.state = "move"
			target.hp = 1e12
			target.max_hp = target.hp
			target.speed = 0
			target.cooldown = 999
			for frame in range(600):
				game.player.attack()
				for slot in [2,0,1,3]: game.player.use_skill(slot)
				await physics_frame
			fixture.merge({"role":role,"damage_10s":snappedf(game.dealt,0.1),"combo_count":game.player.skills.combo_count})
			damage_records.append(fixture)
			check(game.dealt>0,"full build fixed target damage role %d %s"%[role,build])
			game.back_to_menu()
	for role in range(3):
		check(damage_records[role*3].damage_10s<damage_records[role*3+1].damage_10s and damage_records[role*3+1].damage_10s<damage_records[role*3+2].damage_10s,"gear and talent investment increases actual output role %d"%role)
	var report = {"checks":results.size(),"failures":failures,"checks_detail":results,"target_damage":damage_records}
	var file = FileAccess.open("res://tests/integration_v3.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	game.reset_entities()
	game.free()
	await process_frame
	print("INTEGRATION_V3 "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
