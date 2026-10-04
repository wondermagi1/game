extends SceneTree

var game
var output_dir:String
func _initialize()->void:call_deferred("run")
func frames(count:int)->void:
	for i in range(count):await process_frame
func capture(name:String)->void:
	await frames(2);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output_dir.path_join(name+".jpg"),.88)
	print("VFX_V11_CAPTURE="+name)

func run()->void:
	output_dir=ProjectSettings.globalize_path("res://docs/screenshots-v11");DirAccess.make_dir_recursive_absolute(output_dir)
	game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game);game.sound.volume=0
	game.profile.data.unlocked=6;game.effects_intensity=1.0;game.reduced_motion=false
	for role in range(3):
		game.profile.data.checkpoint={};game.profile.data.exploration={}
		game.profile.data.roles[role].level=30;game.profile.data.roles[role].skills=[10,10,10,10]
		game.start_run(role,11200+role,role+1);game.player.manual_control=true;game.player.invulnerable=999
		game.rooms.data.rooms.r1.layout="open";game.rooms.enter("r1","r0");game.pending.clear();game.banner_time=0
		game.player.position=game.rooms.origin()+Vector2(790,650);game.player.aim=Vector2.RIGHT
		for i in range(5):
			var enemy=game.spawn_enemy([0,2,15,16,17][i],game.rooms.origin()+Vector2(1100+(i%3)*155,430+floori(i/3.0)*225))
			enemy.hp=1.0e9;enemy.max_hp=1.0e9;enemy.state="move";enemy.set_physics_process(false)
		game.player.use_skill(3);await capture("%02d-role-%d-anticipation"%[role*5+1,role])
		await frames(15);await capture("%02d-role-%d-release"%[role*5+2,role])
		await frames(30);await capture("%02d-role-%d-sustain"%[role*5+3,role])
		game.player.skills.ultimate.finish();await capture("%02d-role-%d-impact"%[role*5+4,role])
		await frames(50);await capture("%02d-role-%d-residue"%[role*5+5,role])
		game.clear_attacks();game.player.skills.combo(game.player.global_position+Vector2(300,-80),["穿云追剑","霰幕连爆","猎日星坠"][role]);await capture("combo-role-%d"%role)
		game.clear_attacks()
		for i in range(18):
			var dense_enemy=game.spawn_enemy([0,2,9,10,11,14,15,16,17][i%9],game.rooms.origin()+Vector2(880+(i%6)*125,300+floori(i/6.0)*190))
			dense_enemy.hp=1.0e9;dense_enemy.max_hp=1.0e9;dense_enemy.state="move";dense_enemy.set_physics_process(false)
		game.player.use_skill(3);await frames(24);await capture("density-role-%d"%role)
		game.back_to_menu();await frames(3)
	game.free();quit()
