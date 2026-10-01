extends SceneTree

var game
var output_dir: String

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):await process_frame

func capture(name: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))

func run() -> void:
	output_dir=ProjectSettings.globalize_path("res://docs/screenshots-v8")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game);game.sound.volume=0
	game.profile.data.unlocked=6
	for role in range(3):
		game.profile.data.roles[role].level=30;game.profile.data.roles[role].skills=[10,10,10,10]
		game.start_run(role,8200+role,2);game.player.manual_control=true;game.player.invulnerable=999
		game.rooms.data.rooms.r1.layout="open";game.rooms.enter("r1","r0");game.pending.clear()
		game.player.position=game.rooms.origin()+Vector2(850,650);game.player.aim=Vector2.RIGHT
		for i in range(5):
			var enemy=game.spawn_enemy([0,2,15,16,17][i],game.rooms.origin()+Vector2(1120+(i%3)*150,470+floori(i/3.0)*220))
			enemy.hp=1.0e8;enemy.max_hp=1.0e8;enemy.state="move";enemy.set_physics_process(false)
		game.player.use_skill(3);await frames(50);await capture("02-ultimate-%d-sustain"%role)
		game.player.skills.ultimate.finish();await frames(3);await capture("03-ultimate-%d-finish"%role)
		game.back_to_menu();await frames(3)
	game.free();quit()
