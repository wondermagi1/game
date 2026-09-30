extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	var result = {}
	var gear: Dictionary = game.profile.data.inventory[0]
	result["fresh_enhance"] = game.profile.enhance(gear.uid)
	result["fresh_material"] = game.profile.data.material
	result["has_keyboard_binding_page"] = game.ui.has_method("show_bindings")
	game.profile.data.roles[0].level = 20
	game.ui.show_talents()
	for i in range(4): await process_frame
	var scroll: ScrollContainer
	for child in game.ui.overlay.get_children():
		if child is ScrollContainer: scroll = child
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await process_frame
	result["scroll_before"] = scroll.scroll_vertical
	game.ui.train_passive("step")
	for i in range(4): await process_frame
	for child in game.ui.overlay.get_children():
		if child is ScrollContainer: scroll = child
	result["scroll_after"] = scroll.scroll_vertical
	game.start_run(1,512,1)
	game.progress_delay = 999
	game.player.manual_control = true
	var target = game.spawn_enemy(0,Vector2(1050,700))
	target.state = "move"
	target.hp = 1
	game.add_zone(target.position,180,4,4,0,"powder",1)
	var projectile = game.Projectile.new()
	projectile.source = "normal"
	projectile.empowered = true
	target.hurt(100)
	game.player.skills.on_hit(target,projectile)
	result["killing_hit_combo"] = game.profile.data.achievements.has("combo")
	projectile.free()
	var f = FileAccess.open("res://tests/v3_after_fixes.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	f.close()
	print("REPRO_V3 "+JSON.stringify(result))
	game.free()
	quit()
