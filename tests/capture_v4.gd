extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func shot(id: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../v4-"+id+".png"))
	print("CAPTURE "+id)
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	await shot("menu")
	game.profile.data.unlocked = 6
	game.ui.show_chapters()
	await shot("chapters")
	for role in range(3):
		game.profile.data.roles[role].level = 30
		game.profile.data.roles[role].skills = [[1,10,1,10],[5,3,3,10],[10,1,1,10]][role]
		game.profile.data.roles[role].spent = [66,54,66][role]
		game.start_run(role,507,5)
		game.player.manual_control = true
		game.rooms.data.rooms.r1.layout = "open"
		game.rooms.enter("r1","r0")
		game.pending.clear()
		game.player.position = game.rooms.origin()+Vector2(760,600)
		game.player.aim = Vector2.RIGHT
		for i in range(5):
			var e = game.spawn_enemy(11,game.safe_position(game.rooms.origin()+Vector2(1100+(i%3)*170,420+floori(i/3.0)*280)))
			e.state="move"; e.set_physics_process(false); e.hp=1e8; e.max_hp=1e8
		game.player.use_skill(1 if role==0 else 0)
		await shot("giant-%d"%role)
		game.player.use_skill(3)
		for i in range(20): await physics_frame
		await shot("ultimate-%d-start"%role)
		for i in range(70): await physics_frame
		await shot("ultimate-%d-active"%role)
		while game.player.skills.ultimate.active: await physics_frame
		await shot("ultimate-%d-finish"%role)
	game.player.skills.ultimate.active = false
	game.rooms.enter("r2","r1")
	game.rooms.current().event="altar"
	game.rooms.open_event()
	await shot("event")
	game.rooms.choose_event(0)
	game.state="paused"
	game.ui.show_world_map()
	await shot("map")
	game.state="intermission"
	game.ui.show_talents()
	await shot("talents")
	game.ui.show_intermission()
	await shot("camp")
	game.ui.show_combos()
	await shot("combos")
	await process_frame
	await process_frame
	game.free()
	quit()
