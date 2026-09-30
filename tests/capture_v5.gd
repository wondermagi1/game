extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func shot(id: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../v5-"+id+".png"))
	print("CAPTURE V5 "+id)
func frames(count: int) -> void:
	for i in range(count): await process_frame
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	await frames(30)
	await shot("menu")
	game.profile.data.unlocked = 6
	game.profile.data.gold = 20000
	game.profile.data.material = 300
	var rng = RandomNumberGenerator.new()
	rng.seed = 531
	for role in range(3):
		game.profile.data.roles[role].level = 30
		game.profile.data.roles[role].skills = [7,2,2,10]
		game.profile.data.roles[role].spent = 68
		for slot in range(6):
			var item = game.profile.make_item(role,slot,3 if slot==0 else 2,25,rng)
			item.enhance = 5
			game.profile.receive_item(item)
			game.profile.equip(role,item.uid)
		game.ui.view_role = role
		game.ui.selected_uid = game.profile.data.roles[role].equipped["0"]
		game.ui.show_equipment()
		await shot("equipment-%d"%role)
	game.ui.view_role = 0
	game.ui.selected_uid = game.profile.data.roles[0].equipped["0"]
	game.ui.show_forge(game.ui.selected_uid)
	await shot("forge")
	game.ui.enhance_item(game.ui.selected_uid)
	await frames(12)
	await shot("forge-success")
	game.ui.show_talents()
	await shot("talents")
	game.ui.show_preview(3)
	await frames(24)
	await shot("preview")
	game.ui.show_codex()
	await shot("codex")
	game.ui.show_visual_settings(false)
	await shot("settings")
	game.ui.show_lulu_select()
	await shot("lulu-select")
	for role in range(3):
		game.start_run(role,507,6)
		game.player.manual_control = true
		game.rooms.data.rooms.r1.layout = "open"
		game.rooms.enter("r1","r0")
		game.pending.clear()
		game.player.position = game.rooms.origin()+Vector2(760,600)
		game.player.aim = Vector2.RIGHT
		for i in range(6):
			var e = game.spawn_enemy([0,1,2,3,9,10][i],game.rooms.origin()+Vector2(1100+(i%3)*210,410+floori(i/3.0)*330))
			e.state="move"; e.set_physics_process(false); e.hp=1e8; e.max_hp=1e8
		game.player.attack()
		game.player.use_skill(0)
		game.player.use_skill(3)
		await frames(50)
		await shot("combat-%d"%role)
		await frames(230)
		await shot("finish-%d"%role)
	game.player.skills.ultimate.active = false
	game.cinematic.testing = true
	var boss = game.spawn_enemy(13,game.rooms.origin()+Vector2(1180,550))
	while game.cinematic.active and game.cinematic.clock<1.0: await process_frame
	await shot("boss-intro")
	game.cinematic.finish()
	await frames(3)
	boss.hurt(1e12,false,false)
	await frames(5)
	await shot("boss-defeat")
	game.back_to_menu()
	game.cinematic.seen.clear()
	game.rooms.start_lulu(0,123)
	game.player.manual_control=true
	game.rooms.enter("r1","r0")
	# Wait for the scheduled spawn and the fully opaque intro, independent of FPS.
	while not game.cinematic.active: await process_frame
	while game.cinematic.active and game.cinematic.clock<1.0: await process_frame
	await shot("lulu-intro")
	game.cinematic.finish()
	await frames(30)
	var lulu=game.enemies[0]
	lulu.pattern=0
	lulu.locked_dir=Vector2.DOWN
	lulu.execute_attack()
	await frames(25)
	await shot("lulu-combat")
	lulu.pattern=2
	lulu.execute_attack()
	await frames(12)
	await shot("lulu-bath")
	lulu.hurt(1e12,false,false)
	await frames(50)
	await shot("lulu-victory")
	game.free()
	quit()
