extends SceneTree
const Checkpoint = preload("res://scripts/frontier/checkpoint.gd")
var game
var failures: Array = []
var checks = 0
var capture = false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func settle() -> void:
	for i in range(12): await process_frame

func move_to(p: Vector2) -> void:
	game.player.position = game.Terrain.ground(p)+Vector3.UP*.15
	game.player.velocity = Vector3.ZERO
	game.camera.position = game.player.position+game.camera_offset
	game.camera.look_at(game.player.position+Vector3.UP)

func shot(id: String) -> void:
	if not capture: return
	await settle()
	if id=="04-sanctuary": await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots-frontier-journey")
	root.get_texture().get_image().save_png("res://docs/screenshots-frontier-journey/"+id+".png")

func run() -> void:
	game = load("res://scenes/Frontier3D.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	root.size = Vector2i(1920,1080)
	await settle()
	game.start_run(0)
	game.set_physics_process(false)
	check(Checkpoint.valid(game.checkpoint),"new expedition creates a valid isolated checkpoint")
	check(game.terrain.get_node("Frostbrook") is MeshInstance3D,"stream is 3D geometry")
	check(game.terrain.get_node("OldBridge/BridgeDeck") is StaticBody3D,"bridge has a physical deck")
	move_to(Vector2(-44,43))
	game.hp = 60
	check(game.interact() and game.hp==game.max_hp,"hearth restores health")
	check(game.potions==4,"first rest grants one potion")
	game.interact()
	check(game.potions==4,"repeated rest does not duplicate potion rewards")
	game.coins = 123
	game.buffs.power = .5
	game.buffs.pierce = 1
	game.claimed.rune_west = true
	game.runes = 1
	game.cleared.camp_west = true
	game.discovered.rune_east = true
	check(game.set_waypoint("rune_east"),"discovered landmark accepts a waypoint")
	check(not game.set_waypoint("unknown"),"invalid waypoint is rejected")
	check(not game.set_waypoint("hidden_chest"),"unexplored locations cannot be tracked")
	check(game.save_checkpoint(false),"safe exploration can be saved")
	var data: Dictionary = game.checkpoint.duplicate(true)
	game.coins = 0
	game.buffs.clear()
	game.runes = 0
	check(game.continue_run(),"continue restores the last checkpoint")
	game.set_physics_process(false)
	check(game.coins==123 and game.runes==1 and game.buffs.power==.5,"currency, runes and boons survive resume")
	check(game.rested.has("hearth_home") and game.potions==4,"rest supply state survives resume")
	check(game.claimed.has("rune_west") and game.cleared.has("camp_west"),"completed world interactions survive resume")
	check(game.waypoint=="rune_east","waypoint survives resume")
	check(game.enemies.is_empty() and game.hazards.is_empty(),"resume contains no stale combat entities")
	move_to(Vector2(-28,18))
	game.tick_exploration()
	check(game.enemies.is_empty(),"cleared camp cannot spawn again after resume")
	move_to(Vector2(-44,43))
	var enemy = game.spawn_enemy(0,Vector2(-39,43),"test")
	check(not game.save_checkpoint(false),"active combat cannot overwrite a safe checkpoint")
	check(game.checkpoint==data,"refused save preserves the checkpoint")
	game.enemies.erase(enemy)
	enemy.free()
	game.hazards.append({"t":1.0})
	check(not game.save_checkpoint(false),"danger telegraphs block saving")
	game.hazards.clear()
	game.shoot(game.player.position,Vector3.RIGHT,2,1,1,true,1)
	check(not game.save_checkpoint(false),"lingering hostile shots block saving")
	game.clear_transients()
	var path = "res://tests/.frontier-save-test-%d.json"%OS.get_process_id()
	check(Checkpoint.write_file(data,path)==OK,"checkpoint writes to disk")
	var second = data.duplicate(true)
	second.coins = 147
	check(Checkpoint.write_file(second,path)==OK,"checkpoint can replace a previous save")
	check(Checkpoint.read_file(path).coins==147,"disk round trip keeps latest state")
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(Checkpoint.read_file(path).coins==123,"corrupt primary save falls back to the previous checkpoint")
	var invalid = data.duplicate(true)
	invalid.position = [900,0]
	check(Checkpoint.write_file(invalid,path)==ERR_INVALID_DATA,"invalid position cannot replace a valid backup")
	invalid = data.duplicate(true)
	invalid.hp = -1
	check(not Checkpoint.valid(invalid),"dead or malformed saves cannot resume")
	Checkpoint.clear_file(path)
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"isolated test saves are cleaned up")
	await shot("01-warm-camp")
	for role in range(3):
		game.create_player(role)
		move_to(Vector2(-34,31))
		game.attack_clock = 0
		game.aim = Vector3.RIGHT
		check(game.attack(),"role %d can attack with the new 3D weapon mesh"%role)
		check(game.projectiles[0].node is Node3D and game.projectiles[0].node.get_child_count()>1,"role %d projectile has assembled geometry"%role)
		game.clear_transients()
		game.shoot(game.player.position,Vector3.RIGHT,22,role,3,false,3)
		game.falling_blade(game.player.position+Vector3(3,0,-3),role,2.3)
		await shot("weapon-%d"%role)
		game.clear_transients()
	game.create_player(0)
	move_to(Vector2(23.5,1.7))
	game.scripted_movement = Vector3.RIGHT
	for i in range(135):
		game._physics_process(1.0/60)
		await physics_frame
	game.scripted_movement = Vector3.ZERO
	check(game.player.position.x>38,"actual capsule movement crosses the bridge without jumping")
	check(game.player.position.y>game.Terrain.height_at(game.player.position.x,game.player.position.z)-.15,"bridge crossing does not fall through terrain")
	move_to(Vector2(32,6))
	await shot("02-frostbrook-bridge")
	game.set_state("map")
	game.ui.show_map()
	await settle()
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(530,245)+game.ui.map_canvas.point(Vector2(-44,45))
	root.push_input(click,true)
	await process_frame
	check(game.waypoint=="hearth_home","map click sets an actual discovered waypoint")
	await shot("03-exploration-map")
	game.set_state("combat")
	game.ui.clear_modal()
	game.enemies.clear()
	game.clear_transients()
	move_to(Vector2(5,-48))
	game.runes = 3
	check(game.interact(),"three runes unlock the boss encounter")
	game.ui.refresh()
	check(game.ui.boss_panel.visible,"boss encounter displays a dedicated health bar")
	await shot("04-sanctuary")
	game.damage_enemy(game.enemies[0],10000)
	check(game.state=="end" and game.checkpoint.is_empty(),"victory finishes and removes resumable run")
	await shot("05-completion")
	game.start_run(2)
	game.set_physics_process(false)
	game.invulnerable = 0
	game.hurt_player(10000)
	check(game.state=="end" and game.checkpoint.is_empty(),"death finishes the run rather than restoring rewards")
	print("FRONTIER_JOURNEY="+JSON.stringify({"checks":checks,"failures":failures}))
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
