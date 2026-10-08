extends SceneTree
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.profile.data.unlocked = 6
	game.start_run(0,12108,1)
	game.player.manual_control = true
	var room = game.rooms.scene
	check(room.has_depth(),"chapter one opens the garden")
	check(game.ARENA.size.x>1920 and game.ARENA.size.y>1080,"play space extends beyond the viewport in both axes")
	check(room.camera_target(room.to_global(Vector2(1100,1200)))!=room.camera_target(room.to_global(Vector2(2900,2200))),"camera follows exploration")
	for point in [Vector2.ZERO,Vector2(-1000,-1000),room.WORLD,room.WORLD+Vector2(1000,1000)]:
		var cam: Vector2 = room.to_local(room.camera_target(room.to_global(point)))
		check(cam.x>=960 and cam.y>=540 and cam.x<=room.WORLD.x-960 and cam.y<=room.WORLD.y-540,"camera keeps the art on screen at boundaries")
	var anchor := Vector2i(room.event_position()/40)
	for point in [room.entry_position(),room.portal(Vector2.LEFT)+Vector2(140,0),room.portal(Vector2.RIGHT)-Vector2(140,0),Vector2(1600,350),Vector2(1600,2200),Vector2(1200,1200),Vector2(2380,1120),room.caches[0],room.caches[1]]:
		var goal := Vector2i(room.safe(point,55)/40)
		check(not room.navigation.get_id_path(anchor,goal).is_empty(),"reachable landmark / gate: "+str(point))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5512
	for i in range(120):
		var point := Vector2(rng.randf_range(-200,4296),rng.randf_range(-200,3272))
		check(room.walkable(room.safe(point,55),54),"safe relocation excludes terrain "+str(i))
	for polygon in room.ponds:
		var center := Vector2.ZERO
		for p in polygon: center+=p/polygon.size()
		check(not room.walkable(center),"water blocks the actor")
		check(not room.water_blocked(room.safe(center,55),54),"water relocation reaches dry shore")
	# Actual physics sweeps, not only rectangle assertions.
	await physics_frame
	game.player.global_position=room.to_global(Vector2(2048,1800)*room.MAP_SCALE)
	check(not game.player.test_move(game.player.global_transform,Vector2(0,-270)),"torii opening is physically traversable")
	game.player.global_position=room.to_global(Vector2(1850,1800)*room.MAP_SCALE)
	check(game.player.test_move(game.player.global_transform,Vector2(0,-220)),"torii post has collision")
	for p in [Vector2(290,1240),Vector2(1600,1400),Vector2(2150,1170),Vector2(2950,2170)]:
		game.player.global_position=room.to_global(room.safe(p))
		for i in range(15):
			var spawn: Vector2=game.random_spawn()
			check(spawn.distance_to(game.player.global_position)>440 and spawn.distance_to(game.player.global_position)<=960,"spawns stay nearby but not on the hero")
	# Optional exploration rewards must be once-only across room revisits/saves.
	game.player.global_position=room.to_global(room.caches[0])
	var gold_before: int=game.profile.data.gold
	game.rooms.interact()
	check(game.profile.data.gold==gold_before+65,"side path grants its reward")
	check(game.rooms.snapshot().map.rooms.r0.broken.has("garden_offering_0"),"cache state survives snapshot")
	game.rooms.enter("r0")
	room=game.rooms.scene
	check(not room.try_interact(room.caches[0]),"revisit cannot farm the same offering")
	check(game.profile.data.gold==gold_before+65,"once-only gold remains unchanged")
	game.rooms.enter("r1","r0")
	room=game.rooms.scene
	await process_frame
	check(game.pending.is_empty() and game.rooms.waves_done==0,"walking in from the gate does not start an edge fight")
	game.player.global_position=room.to_global(room.event_position())
	game.rooms.tick(.01)
	check(not room.cleared and game.pending.size()>0,"battle remains gated with a real enemy wave")
	for gate in room.gates: check(not gate.disabled,"uncleared gate blocks crossing")
	game.pending.clear()
	game.rooms.complete_room()
	check(game.state=="reward","clearing a garden still opens the reward flow")
	game.rooms.after_reward()
	await process_frame
	for gate in room.gates: check(gate.disabled,"cleared gate opens")
	game.rooms.enter("r2","r1")
	room=game.rooms.scene
	game.player.global_position=room.to_global(room.event_position())
	game.rooms.interact()
	check(game.state=="event","event uses the new garden centre")
	game.back_to_menu()
	check(game.camera.position==Vector2(960,540) and not game.y_sort_enabled,"leaving the garden restores menu framing")
	game.start_run(0,77,2)
	check(not game.rooms.scene.has_depth() and game.ARENA.size==Vector2(1780,790),"chapter two retains its authored layout")
	game.rooms.start_lulu(0,1234)
	check(not game.rooms.scene.has_depth(),"Lulu keeps the separate hot-spring stage")
	var result := {"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_garden_v12_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("GARDEN_V12="+JSON.stringify(result))
	game.free()
	quit(0 if failures.is_empty() else 1)
