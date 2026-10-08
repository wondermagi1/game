extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func capture(label: String, pos: Vector2) -> void:
	game.player.global_position = game.rooms.scene.to_global(pos*game.rooms.scene.MAP_SCALE)
	game.player.invulnerable = 0
	game.camera.position = game.rooms.scene.camera_target(game.player.global_position)
	for i in range(35): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots-v12/"+label+".png")
	print("GARDEN_CAPTURE="+label)
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.start_run(0,121081,1)
	game.player.manual_control = true
	game.banner_time = 0
	game.notice_clock = 0
	await capture("01-courtyard",Vector2(2048,1810))
	await capture("02-shrine",Vector2(1570,1750))
	await capture("03-pond",Vector2(3030,1380))
	await capture("04-sakura-path",Vector2(2730,2740))
	await capture("05-canopy-occlusion",Vector2(2820,1520))
	game.rooms.enter("r1","r0")
	game.rooms.waves_done = 1
	game.pending.clear()
	game.player.global_position = game.rooms.scene.to_global(Vector2(2048,1900)*game.rooms.scene.MAP_SCALE)
	game.player.invulnerable = 99
	for i in range(5):
		var enemy = game.spawn_enemy([0,0,2,0,2][i],game.rooms.scene.to_global(Vector2(1610+i*200,1740+i%2*200)*game.rooms.scene.MAP_SCALE),false)
		enemy.set_physics_process(false)
	game.banner_time = 0
	await capture("06-combat",Vector2(2048,1900))
	game.free()
	quit()
