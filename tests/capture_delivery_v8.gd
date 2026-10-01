extends SceneTree

var game
var output_dir: String

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count): await process_frame

func capture(name: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))

func run() -> void:
	output_dir = ProjectSettings.globalize_path("res://docs/screenshots-v8")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.profile.memory_only = true
	game.profile.fresh()
	game.profile.data.unlocked = 6
	game.profile.data.cleared = [1,2,3,4,5,6]
	game.profile.data.roles[0].level = 30
	game.profile.data.roles[0].skills = [10,10,10,10]
	game.start_run(0,8801,2)
	game.player.manual_control = true
	for id in game.rooms.data.rooms:
		game.rooms.data.rooms[id].visited = true
	game.rooms.data.revealed = true
	game.rooms.data.current = "r1"
	game.state = "paused"
	game.ui.show_world_map()
	await capture("06-chapter-two-route-map")

	game.back_to_menu()
	game.profile.data.gold = 20000
	game.profile.data.material = 300
	var rng = RandomNumberGenerator.new()
	rng.seed = 8802
	var item = game.profile.make_item(0,0,3,30,rng)
	item.enhance = 8
	game.profile.receive_item(item)
	game.profile.equip(0,item.uid)
	game.ui.view_role = 0
	game.ui.selected_uid = item.uid
	game.ui.show_equipment()
	await capture("07-legendary-equipment")

	game.back_to_menu()
	game.cinematic.seen.clear()
	game.cinematic.testing = true
	game.rooms.start_lulu(0,8803)
	game.player.manual_control = true
	game.rooms.enter("r1","r0")
	while not game.cinematic.active: await process_frame
	while game.cinematic.active and game.cinematic.clock<1.0: await process_frame
	await capture("08-lulu-boss-intro")
	game.cinematic.finish()

	game.telemetry.record_damage(5200,"ultimate",true)
	game.telemetry.record_damage(3100,"v7_greatsword",true)
	game.telemetry.record_damage(1250,"normal",false)
	game.telemetry.damage_taken = 72
	game.telemetry.healing = 55
	game.telemetry.dodges = 14
	game.telemetry.elite_kills = 4
	game.telemetry.boss_kills = 1
	game.telemetry.rewards.assign(["山河巨刃 · 巨剑流 2阶","锋芒 ×3","循环突破"])
	game.player.skills.combo_count = 6
	game.won = true
	game.state = "end"
	game.ui.show_run_report()
	await capture("09-detailed-run-report")
	game.free()
	quit()
