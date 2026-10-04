extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):await process_frame

func run() -> void:
	var game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true;game.use_3d_characters=true;root.add_child(game);game.sound.volume=0
	game.profile.data.unlocked=6;game.profile.data.checkpoint={};game.profile.data.exploration={}
	game.start_run(0,12000,1);game.player.manual_control=true;game.player.invulnerable=999
	game.rooms.data.rooms.r1.layout="open";game.rooms.enter("r1","r0");game.pending.clear();game.banner_time=0
	game.player.position=game.rooms.origin()+Vector2(880,620);game.player.aim=Vector2.RIGHT
	game.player.scripted_movement=Vector2.RIGHT*.75
	for i in range(8):
		var enemy=game.spawn_enemy([0,2,9,10][i%4],game.rooms.origin()+Vector2(1100+(i%4)*120,370+floori(i/4.0)*220))
		enemy.hp=1.0e9;enemy.max_hp=1.0e9;enemy.state="move";enemy.set_physics_process(false)
	await frames(18)
	game.player.attack();await frames(5);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots-v12/02-sword-3d-combat.png")
	print("CAPTURE_3D_V12=res://docs/screenshots-v12/02-sword-3d-combat.png")
	quit()

