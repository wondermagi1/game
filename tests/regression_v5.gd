extends SceneTree
var game
var checks: int = 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	checks += 1
	if not value: failures.append(title); push_error(title)
func frames(n: int) -> void:
	for i in range(n): await process_frame
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	for role in range(3):
		game.ui.show_menu()
		var matching: Button
		for b in game.ui.overlay.get_children():
			if b is Button and b.get_meta("role_id",-1)==role: matching=b
		check(is_instance_valid(matching),"menu role button "+str(role))
		matching.pressed.emit()
		check(game.selected_role==role and game.ui.view_role==role and game.ui.page=="chapters","role matches selection "+str(role))
		game.back_to_menu()
	check(not Rect2(game.ui.minimap.position,game.ui.minimap.size).intersects(Rect2(70,160,1780,790)),"minimap does not overlap combat")
	check(game.ui.minimap.position.y+game.ui.minimap.size.y<=125,"minimap fits HUD")
	game.profile.data.gold = 20000
	game.profile.data.material = 100
	var weapon = game.profile.item_by_id(game.profile.data.roles[0].equipped["0"])
	var gold: int = game.profile.data.gold
	var cost = game.Catalog.upgrade_cost(1)
	game.ui.view_role = 0
	game.ui.enhance_item(weapon.uid)
	game.ui.enhance_item(weapon.uid)
	check(weapon.enhance==1 and game.profile.data.gold==gold-cost.gold,"enhance debounced once")
	check(game.ui.growth_clock>0,"enhance feedback")
	game.ui.forge_lock = 0
	game.profile.memory_only = false
	game.profile.read_only = true
	var before = JSON.stringify(game.profile.data)
	game.ui.enhance_item(weapon.uid)
	check(JSON.stringify(game.profile.data)==before,"failed save rolls back cost and level")
	game.profile.read_only = false
	game.profile.memory_only = true
	var saved_cleared: Array = game.profile.data.cleared.duplicate()
	game.rooms.start_lulu(0,55)
	game.player.manual_control = true
	check(game.flow.capybara and game.rooms.data.rooms.size()==2,"lulu independent room graph")
	game.rooms.camp()
	check(game.rooms.save_exit(),"lulu safe camp saves")
	check(game.rooms.resume(),"lulu safe camp resumes")
	check(game.flow.capybara,"lulu mode restored")
	game.cinematic.testing = true
	game.rooms.enter("r1","r0")
	game.pending.clear()
	var boss = game.spawn_enemy(14,game.rooms.origin()+Vector2(1100,500))
	await frames(3)
	check(game.cinematic.active and game.state=="cinematic","lulu intro starts")
	var cooldown: float = game.player.skills.cooldowns[0]
	var p: Vector2 = game.player.position
	var hp: float = game.player.hp
	var boss_hp: float = boss.hp
	var old_camera: Vector2 = game.cinematic.old_position
	game.player.scripted_movement = Vector2.RIGHT
	for i in range(12): await physics_frame
	check(game.player.position==p and game.player.hp==hp and game.player.skills.cooldowns[0]==cooldown and boss.hp==boss_hp,"cinematic freezes combat and cooldowns")
	var key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	game.cinematic._input(key)
	game.cinematic.finish()
	check(not game.cinematic.active and game.state=="combat" and game.camera.position==old_camera and game.camera.zoom==Vector2.ONE,"skip restores state camera exactly once")
	game.player.scripted_movement = Vector2.ZERO
	boss.state = "move"
	boss.set_physics_process(false)
	boss.locked_dir = Vector2.LEFT
	boss.pattern = 0
	boss.execute_attack()
	check(game.projectiles.size()==5,"lulu first phase five slow bubbles")
	for shot in game.projectiles: check(shot.bubble and shot.enemy_shot and shot.speed==205,"bubble visual matches projectile")
	game.clear_attacks()
	boss.pattern = 1
	boss.execute_attack()
	check(game.hazards.size()==1 and game.hazards[0].max>=1.5,"water splash telegraphs")
	game.clear_attacks()
	boss.pattern = 2
	boss.execute_attack()
	check(boss.state=="recover" and boss.timer==2.5,"bath provides attack opening")
	var held_hp: float = boss.hp
	boss.hurt(50,false,false)
	check(boss.hp<held_hp,"bathing boss remains vulnerable")
	boss.second_phase = true
	boss.pattern=0
	boss.execute_attack()
	check(game.projectiles.size()==7,"lulu second phase seven bubbles")
	game.clear_attacks()
	game.player.skills.ultimate.active = false
	boss.state = "move"
	var count: int = game.profile.data.inventory.size()
	boss.hurt(1e12,false,false)
	game.rooms.transition_clock=0
	game.rooms.tick(.1)
	check(game.state=="end" and game.won,"lulu victory settles")
	check(game.profile.data.achievements.has("lulu"),"lulu friendship achievement")
	check(game.profile.data.cleared==saved_cleared and game.profile.data.unlocked==1,"lulu does not unlock main chapters")
	var epic_accessory = false
	for item in game.profile.data.inventory:
		if item.role==0 and item.slot==5 and item.quality==2: epic_accessory=true
	check(epic_accessory,"guaranteed usable epic accessory")
	var after_rewards = JSON.stringify(game.profile.data)
	game.rooms.complete_room()
	game.end_run(true)
	check(after_rewards==JSON.stringify(game.profile.data),"lulu no duplicate settlement")
	var retry: Button
	for child in game.ui.overlay.get_children():
		if child is Button and child.text=="再去找噜噜玩": retry=child
	check(is_instance_valid(retry),"lulu victory exposes retry")
	if is_instance_valid(retry): retry.pressed.emit()
	check(game.flow.capybara and game.rooms.current().kind=="start" and game.rooms.data.rooms.size()==2,"retry starts lulu safe camp, not main chapter")
	game.back_to_menu()
	check(game.presentation_fx.particles.is_empty() and not game.cinematic.active,"reset clears effects and intro")
	# Full intro and focus-loss exit as well as death/removal cancellation.
	game.rooms.start_lulu(1,56)
	game.player.manual_control=true
	game.rooms.enter("r1","r0")
	game.pending.clear()
	boss=game.spawn_enemy(14,game.rooms.origin()+Vector2(1100,500))
	game.cinematic.seen.clear()
	await frames(3)
	game.cinematic._process(3.3)
	check(game.state=="combat" and not game.cinematic.active,"intro completes automatically")
	game.cinematic.seen.clear()
	game.cinematic.start(boss)
	game.focused=false
	game.cinematic.finish()
	check(game.state=="paused","focus lost ends intro safely paused")
	game.focused=true
	game.resume_game()
	game.cinematic.seen.clear()
	game.cinematic.start(boss)
	game.back_to_menu()
	check(game.state=="menu" and not game.cinematic.active and game.camera.zoom==Vector2.ONE,"menu during intro resets")
	# Preview is side-effect free.
	before = JSON.stringify(game.profile.data)
	game.ui.show_preview(3)
	await frames(8)
	check(before==JSON.stringify(game.profile.data),"skill preview does not mutate profile")
	game.bindings.bind_key("skill",KEY_Q,true)
	check(game.ui.bound_hint("E → Q → F → C")=="Q → E → F → C","swapped skill hints do not cascade")
	game.bindings.bind_key("skill",KEY_E,true)
	var report={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_v5_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("V5_REGRESSION="+JSON.stringify(report))
	game.free()
	quit(0 if failures.is_empty() else 1)
