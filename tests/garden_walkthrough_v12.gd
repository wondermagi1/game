extends SceneTree
## Deterministic, real-physics traversal; use --write-movie for the preview.
## No user save is loaded or written. This is not a difficulty/balance benchmark.
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures.append(title); push_error(title)
func walk_to(local_goal: Vector2) -> void:
	var room = game.rooms.scene
	var goal: Vector2 = room.to_global(room.safe(local_goal,55))
	var samples: Array[Vector2] = []
	for frame in range(1500):
		var p: Vector2=game.player.global_position
		if p.distance_to(goal)<32: break
		var direction: Vector2=room.navigate(p,goal)
		game.player.scripted_movement=direction
		game.player.aim=direction
		if frame%30==0: samples.append(game.camera.position)
		await physics_frame
	check(game.player.global_position.distance_to(goal)<45,"physics traversal reaches "+str(local_goal))
	check(samples.size()<2 or samples[0].distance_to(samples[-1])>10,"camera travels with the hero")
	game.player.scripted_movement=Vector2.ZERO
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.sound.volume=0
	game.start_run(0,12008,1)
	game.player.manual_control=true
	game.banner_time=0
	game.notice_clock=0
	game.player.invulnerable=0
	# Cross the courtyard, walk through the torii, circle around the koi pond,
	# visit the offering and return along the southern sakura route.
	for target in [Vector2(1600,1050),Vector2(1970,620),Vector2(2860,700),Vector2(2680,1120),Vector2(2490,1580),Vector2(1700,1850),Vector2(1300,1560)]:
		await walk_to(target)
	var result := {"checks":checks,"failures":failures,"mode":"real physics traversal, no combat, memory-only profile"}
	var file=FileAccess.open("res://tests/garden_walkthrough_v12_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("GARDEN_WALK="+JSON.stringify(result))
	game.free()
	quit(0 if failures.is_empty() else 1)
