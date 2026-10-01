extends SceneTree

var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output_dir = ProjectSettings.globalize_path("res://docs/screenshots-v8")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.profile.data.unlocked = 6
	game.profile.data.cleared = [1,2,3,4,5,6]
	game.start_run(0,8600,6)
	game.flow.abyss = true
	game.player.stats.abyss = true
	var choices: Array = []
	for upgrade in game.Data.UPGRADES:
		if choices.size()>=3: break
		if int(upgrade[7]) in [-1,0] and upgrade[3]!="heal":
			for i in range([2,4,9][choices.size()]): game.player.stats.apply(upgrade)
			choices.append(upgrade)
	game.state = "reward"
	game.ui.show_rewards(choices)
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("05-abyss-buff-progression.png"))
	game.free()
	quit()
