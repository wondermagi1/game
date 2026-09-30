extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	for dims in [Vector2i(960,540),Vector2i(1280,800),Vector2i(1600,900)]:
		root.size=dims
		game.ui.show_menu()
		for i in range(6): await process_frame
		var bg=game.ui.overlay.get_child(0)
		assert(absf(bg.backdrop.position.x)<30 and absf(bg.backdrop.position.y)<30)
		assert(game.ui.minimap.position.y+game.ui.minimap.size.y<=125)
		print("LAYOUT ",dims," content ",root.content_scale_size," aspect ",root.content_scale_aspect)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../v5-layout-%dx%d.png"%[dims.x,dims.y]))
	game.free()
	quit()
