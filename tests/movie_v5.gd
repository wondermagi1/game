extends SceneTree
## Capture with Godot --write-movie; targets are explicitly training fixtures.
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.profile.data.unlocked=6
	for role in range(3):
		game.profile.data.roles[role].level=60
		game.profile.data.roles[role].skills=[10,9,10,10]
		game.profile.data.roles[role].spent=127
		game.start_run(role,411+role,6)
		game.rooms.data.rooms.r1.layout="open"
		game.rooms.enter("r1","r0")
		game.pending.clear()
		game.player.manual_control=true
		game.player.position=game.rooms.origin()+Vector2(560,600)
		game.player.aim=Vector2.RIGHT
		game.banner=["剑修","火枪手","游侠"][role]+" · C 技能 Lv.10 / 普攻与连携表现 · 训练靶"
		game.banner_time=20
		for i in range(6):
			var enemy=game.spawn_enemy(3,game.rooms.origin()+Vector2(1100+(i%3)*170,400+floori(i/3.0)*280))
			enemy.state="move"; enemy.set_physics_process(false); enemy.hp=1e8; enemy.max_hp=1e8
		for frame in range(540):
			game.player.attack()
			if frame==45: game.player.use_skill(1 if role==0 else 0)
			if frame==110: game.player.use_skill(0 if role==0 else 2)
			if frame==150: game.player.use_skill(3)
			if frame==220 and role==0: game.player.use_skill(2)
			if frame==300 and role==2:
				game.player.skills.cooldowns[0]=0
				game.player.use_skill(0)
			await physics_frame
	game.back_to_menu()
	game.cinematic.testing=true
	game.cinematic.seen.clear()
	game.ui.show_lulu_select()
	for frame in range(120): await process_frame
	game.rooms.start_lulu(0,413)
	game.player.manual_control=true
	game.rooms.enter("r1","r0")
	for frame in range(540):
		if game.state=="combat":
			var target=game.nearest_enemy(game.player.position,[],2000)
			if is_instance_valid(target):
				game.player.aim=game.player.position.direction_to(target.position)
				game.player.scripted_movement=game.player.aim if game.player.position.distance_to(target.position)>400 else game.player.aim.orthogonal()
				if frame>360: game.player.attack(); game.player.use_skill(3)
		await physics_frame
	await process_frame
	game.free()
	quit()
