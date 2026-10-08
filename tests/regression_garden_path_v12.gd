extends SceneTree
## Regression for the real gunner playthrough's shrine-corner oscillation.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.start_run(1,1,1)
	game.rooms.enter("r1","r0")
	game.player.manual_control=true
	game.player.global_position=Vector2(2900,1376.147)
	var room=game.rooms.scene
	var goal:=Vector2(3245.026,952.8385)
	var failures: Array[String]=[]
	for point in [Vector2(700,1376.147),Vector2(700,1371.147)]:
		if room.navigate(room.to_global(point),goal).y>=0: failures.append("corner guidance must keep moving north")
	for frame in range(240):
		if game.player.global_position.distance_to(goal)<35: break
		game.player.scripted_movement=room.navigate(game.player.global_position,goal)
		await physics_frame
	if game.player.global_position.distance_to(goal)>45: failures.append("actor must physically round the shrine corner")
	var result: Dictionary={"checks":3,"failures":failures}
	var file=FileAccess.open("res://tests/regression_garden_path_v12_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("GARDEN_PATH="+JSON.stringify(result))
	game.free();quit(0 if failures.is_empty() else 1)
