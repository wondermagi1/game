extends SceneTree

var game
var output_dir: String

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count): await process_frame

func capture(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
	print("V7_CAPTURE="+name)

func run() -> void:
	output_dir = ProjectSettings.globalize_path("res://docs/screenshots-v7")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.profile.data.unlocked = 6
	for role in range(3):
		game.profile.data.roles[role].level = 30
		game.profile.data.roles[role].skills = [10,10,10,10]
	game.ui.show_menu()
	await capture("01-menu-and-camp-npc")

	game.start_run(0,7702,2)
	game.player.manual_control = true
	game.player.skills.apply_evolution("evo_0_1_1_1")
	game.state = "reward"
	game.rewards = game.roll_rewards(game.rooms.reward_rng,true,true)
	game.ui.show_rewards(game.rewards)
	await capture("02-evolution-reward")

	game.state = "combat"
	game.ui.clear_overlay()
	game.rooms.enter("cross","r1")
	game.pending.clear()
	game.player.global_position = game.rooms.origin()+Vector2(760,700)
	for i in range(6):
		var enemy = game.spawn_enemy([0,2,15,16,17,18][i],game.rooms.origin()+Vector2(540+i*190,420+(i%2)*160),i==4)
		enemy.state = "move"
		enemy.set_physics_process(false)
	await capture("03-defend-objective")

	game.telemetry.record_damage(4200,"v7_greatsword",true)
	game.telemetry.record_damage(1700,"normal",false)
	game.telemetry.record_damage(900,"status",false)
	game.telemetry.damage_taken = 88
	game.telemetry.healing = 46
	game.telemetry.dodges = 12
	game.telemetry.elite_kills = 3
	game.telemetry.boss_kills = 1
	game.telemetry.rewards.assign(["山河巨刃 · 巨剑流 1阶","锋芒","灵泉"])
	game.won = true
	game.state = "end"
	game.ui.show_run_report()
	await capture("04-detailed-run-report")
	game.free()
	quit()
