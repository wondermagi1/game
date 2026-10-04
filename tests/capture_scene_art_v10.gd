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
	print("SCENE_ART_V10_CAPTURE="+name)

func run() -> void:
	output_dir=ProjectSettings.globalize_path("res://docs/screenshots-v10")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.sound.volume=0
	game.profile.data.unlocked=6
	for role in range(3):
		game.profile.data.roles[role].level=30
		game.profile.data.roles[role].skills=[10,10,10,10]
	for chapter in range(1,7):
		game.profile.data.checkpoint={}
		game.profile.data.exploration={}
		game.start_run((chapter-1)%3,10400+chapter,chapter)
		game.pending.clear()
		game.banner_time=0
		game.player.manual_control=true
		game.player.global_position=game.rooms.origin()+Vector2(960,650)
		var enemy_kinds=[0,2,15,16,17,18]
		for i in range(3):
			var enemy=game.spawn_enemy(enemy_kinds[(chapter+i)%enemy_kinds.size()],game.rooms.origin()+Vector2(650+i*310,430+(i%2)*110),false)
			enemy.set_physics_process(false)
		await capture("%02d-chapter-scene"%chapter)
	game.free()
	quit()
