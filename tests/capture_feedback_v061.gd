extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game);game.sound.volume=0
	game.profile.data.roles[1].level=30;game.profile.data.roles[1].skills=[10,10,10,10]
	game.start_run(1,611,1);game.player.manual_control=true;game.player.invulnerable=999
	game.rooms.data.rooms.r1.layout="open";game.rooms.enter("r1","r0");game.pending.clear()
	game.player.position=game.rooms.origin()+Vector2(680,550);game.player.aim=Vector2.RIGHT
	for i in range(3):
		var enemy=game.spawn_enemy(0,game.rooms.origin()+Vector2(1070,380+i*160))
		enemy.state="move";enemy.set_physics_process(false);enemy.hp=1e8;enemy.max_hp=1e8
	game.player.use_skill(2);game.player.use_skill(3)
	game.banner="0.6.1 · 火枪手旧版技能特效 · 训练靶";game.banner_time=12
	for frame in range(100):
		if frame==25:game.player.use_skill(0)
		if frame==45:game.player.use_skill(1)
		game.player.attack()
		await physics_frame
		if frame in [35,70]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../v061-gunner-%d.png"%frame))
	print("CAPTURE_FEEDBACK_V061_OK");game.free();await process_frame;await process_frame;quit()
