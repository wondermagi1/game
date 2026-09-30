extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	for i in range(12): await process_frame
	print("BACKGROUND ",preload("res://scripts/presentation.gd").BACKGROUND.resource_path," ",preload("res://scripts/presentation.gd").BACKGROUND.get_size())
	for c in game.ui.overlay.get_children():
		if c is Control: print(c.name," ",c.get_script()," ",c.visible," ",c.modulate," ",c.size)
	var bg=game.ui.overlay.get_child(0)
	print("BGDATA ",bg.get_global_mouse_position()," / ",bg.backdrop.position," / ",bg.backdrop.size," / ",bg.backdrop.texture.get_image().get_pixel(850,400))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../v5-menu-fix.png"))
	game.free()
	quit()
