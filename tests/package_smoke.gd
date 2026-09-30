extends SceneTree
## Freshly extracted package check. Real player progress is never loaded or saved.
var checks: int = 0

func _initialize() -> void:
	call_deferred("run_check")

func verify(ok: bool, label_text: String) -> void:
	if not ok:
		push_error("PACKAGE_FAILED: "+label_text)
		quit(1)
	checks += 1

func run_check() -> void:
	var art = load("res://art/heroes-v2.png")
	verify(art is Texture2D,"hero atlas imported")
	for i in range(19):
		verify(load("res://art/icons/%d.svg"%i) is Texture2D,"icon %d imported"%i)
	var gallery = load("res://scenes/CharacterGallery.tscn").instantiate()
	root.add_child(gallery)
	await process_frame
	verify(gallery.get_child_count()>=3,"gallery has three characters")
	gallery.free()
	var game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	verify(game.state=="menu" and game.ui!=null,"menu built")
	for role in range(3):
		game.start_run(role,92810+role,1)
		game.player.manual_control = true
		game.progress_delay = 999
		await physics_frame
		verify(game.player.stats.role==role and game.state=="combat","role %d starts"%role)
		game.back_to_menu()
	verify(game.profile.memory_only,"player save protected")
	game.free()
	print("PACKAGE_SMOKE_PASS checks=%d"%checks)
	quit()
