extends SceneTree
var game
var checks: int = 0
var failures: Array = []
var capture: bool = false
func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")
func check(ok: bool,text_value: String) -> void:
	checks += 1
	if not ok: failures.append(text_value); push_error(text_value)
func settle() -> void:
	for i in range(12): await process_frame
func shot(id: String) -> void:
	if not capture: return
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots-frontier"))
	root.get_texture().get_image().save_png("res://docs/screenshots-frontier/"+id+".png")
func move_player(p: Vector2) -> void:
	game.player.position = game.Terrain.ground(p)+Vector3.UP*.1
	game.camera.position = game.player.position+game.camera_offset
	game.camera.look_at(game.player.position+Vector3.UP)
func run() -> void:
	game = load("res://scenes/Frontier3D.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	root.size = Vector2i(1920,1080)
	await settle()
	check(game.state=="menu","starts at role selection")
	check(game.terrain.get_node("SnowTerrain") is MeshInstance3D,"terrain is a real 3D mesh")
	check(game.get_node("LowWinterSun").shadow_enabled,"sun casts real shadows")
	await shot("01-camp-menu")
	game.start_run(0)
	await settle()
	for i in range(24): await physics_frame
	game.set_physics_process(false)
	check(game.hp==120 and game.runes==0,"new expedition resets progress")
	check(game.player.is_on_floor(),"player settles on terrain collision")
	var floor_start: Vector3 = game.player.position
	game.scripted_movement = Vector3.RIGHT
	for i in range(30):
		game._physics_process(1.0/60)
		await physics_frame
	game.scripted_movement = Vector3.ZERO
	check(game.player.position.x>floor_start.x+2.5,"actual 3D movement crosses continuous terrain")
	check(game.player.position.y>game.Terrain.height_at(game.player.position.x,game.player.position.z)-.1,"moving actor stays above ground")
	move_player(Vector2(-48,42))
	await shot("02-snow-trail")
	for role in range(3):
		game.create_player(role)
		game.cooldowns = [0.0,0.0,0.0,0.0]
		game.set_state("combat")
		for slot in range(4):
			game.cast_slot = -1
			game.cooldowns[slot] = 0
			check(game.request_skill(slot),"role %d skill %d accepts input"%[role,slot])
			check(game.cooldowns[slot]==0,"skill waits for release before spending cooldown")
			game.set_state("paused")
			var before: float = game.cast_time
			game._physics_process(.1)
			check(is_equal_approx(before,game.cast_time),"pause freezes skill windup")
			game.set_state("combat")
			game._physics_process(.34)
			check(game.cooldowns[slot]>0,"authored release spends cooldown")
			game.clear_transients()
			game.ultimate_time = 0
			game.orbit_time = 0
		game.cast_slot = -1
		game.cooldowns[0] = 0
		game.request_skill(0)
		game.dash_clock = 0
		game.stamina = 100
		check(game.dodge(Vector3.RIGHT),"dodge cancels preparation")
		check(game.cast_slot==-1 and game.cooldowns[0]==0,"cancelled skill does not spend cooldown")
	game.create_player(0)
	game.set_state("combat")
	move_player(Vector2(-28,18))
	var target = game.spawn_enemy(0,Vector2(-22,18),"projectile_test")
	await physics_frame
	var initial_hp: float = target.hp
	game.shoot(game.player.position,Vector3.RIGHT,20,0,1,false,1)
	for i in range(24): game.tick_projectiles(1.0/60)
	check(target.hp<initial_hp,"physical projectile ray and swept hit damage an enemy")
	game.enemies.erase(target)
	target.free()
	game.clear_transients()
	game.invulnerable = 0
	game.hurt_player(30)
	check(game.hp==90,"enemy damage changes HP")
	check(game.drink_potion() and game.hp==120 and game.potions==2,"potion heals and is consumed once")
	check(not game.drink_potion() and game.potions==2,"full-health potion is not consumed")
	move_player(Vector2(-28,18))
	game.tick_exploration()
	check(game.enemies.size()==5,"first camp starts a finite encounter")
	for enemy in game.enemies.duplicate(): game.damage_enemy(enemy,10000)
	game.tick_exploration()
	check(game.state=="reward" and game.reward_options.size()==3,"cleared encounter offers three rewards")
	await shot("03-camp-reward")
	check(game.choose_reward(0),"reward can be selected")
	check(not game.choose_reward(0),"reward cannot be claimed twice")
	game.tick_exploration()
	check(game.enemies.is_empty(),"cleared camp does not respawn")
	move_player(Vector2(5,-48))
	check(not game.interact(),"boss requires three activated runes")
	for point in [Vector2(-42,-12),Vector2(34,24),Vector2(35,-35)]:
		move_player(point+Vector2(0,2.6))
		game.tick_exploration()
		check(game.interact(),"rune can be activated")
		var before = game.runes
		check(not game.interact() and game.runes==before,"rune activation is idempotent")
	check(game.runes==3,"all three exploration objectives complete")
	game.tick_exploration()
	await shot("04-rune-shadows")
	game.set_state("map")
	game.ui.show_map()
	await shot("05-exploration-map")
	game.set_state("combat")
	game.ui.clear_modal()
	move_player(Vector2(-50,-45))
	check(game.interact() and game.state=="reward","hidden chest supplies boon and potion")
	game.choose_reward(0)
	check(not game.interact(),"opened chest cannot be farmed")
	move_player(Vector2(5,-48))
	check(game.interact() and game.enemies.size()==1,"boss encounter begins after rune quest")
	game.player.visual.forced_clip = "ultimate_gather"
	game.player.visual.override_phase = .2
	await shot("06-frost-stag")
	var boss = game.enemies[0]
	game.damage_enemy(boss,10000)
	check(game.state=="end" and game.cleared.has("boss"),"boss death completes expedition")
	await shot("07-result")
	print("FRONTIER_3D_REGRESSION="+JSON.stringify({"checks":checks,"failures":failures}))
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
