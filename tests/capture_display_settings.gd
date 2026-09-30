extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game);game.sound.volume=0
	game.ui.show_resolution_settings(false)
	for target in [Vector2i(1280,720),Vector2i(1920,1080)]:
		game.set_window_resolution(target)
		game.ui.show_resolution_settings(false)
		for i in range(8):await process_frame
		print("DISPLAY_SIZE requested=",target," actual=",root.size," logical=",root.content_scale_size)
		assert(root.size==target)
		assert(root.content_scale_size==Vector2i(1920,1080))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../resolution-settings.png")
	game.free();await process_frame;quit()
