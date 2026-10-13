extends SceneTree
## Behavioral UI checks use an in-memory profile; --capture also renders evidence.
var game
var checks: int = 0
var failures: Array[String] = []
var capture: bool = false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for i in range(6): await process_frame

func shot(id: String) -> void:
	await settle()
	if not capture: return
	await RenderingServer.frame_post_draw
	var folder = "res://docs/screenshots-ui"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(folder+"/"+id+".png")

func buttons() -> Array[Node]:
	return game.ui.overlay.find_children("*","Button",true,false)

func press(title: String) -> void:
	for b in buttons():
		if b.text==title:
			check(not b.disabled,"action enabled: "+title)
			b.pressed.emit()
			return
	check(false,"missing action: "+title)

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.reduced_motion = true
	await settle()
	var initial = JSON.stringify(game.profile.data)
	await shot("01-menu")
	for role in range(3):
		for b in buttons():
			if int(b.get_meta("role_id",-1))==role:
				b.pressed.emit()
				break
		check(game.selected_role==role and game.ui.page=="chapters","role card opens correct chapters %d"%role)
		game.ui.show_menu()
	check(initial==JSON.stringify(game.profile.data),"menu navigation leaves profile unchanged")
	press("装备与铸造")
	await settle()
	check(game.ui.page=="equipment","equipment menu callback")
	var uid: String = game.profile.data.inventory[0].uid
	game.ui.select_item(uid)
	await shot("02-equipment")
	var selected_rows = 0
	for r in game.ui.inventory_rows.get_children():
		for b in r.get_children():
			if b is Button and b.text=="已选中": selected_rows += 1
	check(selected_rows==1,"exactly one selected equipment row")
	game.ui.inventory_filter.assign([2,5,3])
	game.ui.render_inventory()
	press("重置筛选")
	check(game.ui.inventory_filter==[-1,-1,-1],"reset filter action")
	check(game.ui.inventory_rows.get_child_count()==game.profile.data.inventory.size(),"reset restores item list")
	game.ui.show_codex()
	await shot("03-codex")
	game.ui.show_settings(false)
	await shot("04-settings")
	for child in game.ui.overlay.get_children():
		if child is HSlider and child.name=="EffectsVolume":
			child.value = .37
			check(is_equal_approx(game.sound.volume,.37),"sound slider keeps original callback")
	game.sound.volume = 0
	game.ui.show_talents()
	await settle()
	for node in game.ui.overlay.get_children():
		if node is ScrollContainer:
			node.scroll_vertical = 10000
	await settle()
	game.ui.show_talents()
	await settle()
	for node in game.ui.overlay.get_children():
		if node is ScrollContainer and node.get_v_scroll_bar().max_value>node.size.y:
			check(node.scroll_vertical>0,"talent refresh preserves scroll")
	game.ui.show_menu()
	for dims in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dims
		await settle()
		check(root.content_scale_size==Vector2i(1920,1080),"fixed logical layout %s"%dims)
		for b in buttons():
			var rect: Rect2 = b.get_global_rect()
			check(Rect2(0,0,1920,1080).encloses(rect),"menu button within canvas: "+b.text)
		await shot("05-menu-%dx%d"%[dims.x,dims.y])
	game.profile.data.roles[0].level = 30
	game.profile.data.roles[0].skills = [10,10,10,10]
	game.start_run(0,1212,1)
	game.player.manual_control = true
	game.pending.clear()
	game.player.invulnerable = 999
	game.player.skills.cooldowns[1] = 5
	await shot("06-hud")
	check(game.ui.skill_status[0].text=="就绪","ready skill status")
	check(game.ui.skill_status[1].text.begins_with("冷却"),"cooldown status")
	check(game.ui.skill_progress[1].value<100,"cooldown meter")
	for meter in game.ui.skill_progress:
		check(meter.size.y<=6 and meter.position.y+meter.size.y<=1060,"cooldown bar stays inside bottom rail")
	check(game.ui.xp_bar.size.y<=8,"XP bar retains thin height")
	game.player.hp = game.player.stats.value("hp")*.1
	await settle()
	check(game.ui.low_health,"low health state")
	for i in range(3):
		var id: String = game.profile.data.quick[i]
		game.profile.data.consumables[id] = 0
	await settle()
	check(game.ui.item_buttons.all(func(b): return b.disabled),"empty consumables disabled")
	game.notify_player("拾取奖励测试",2)
	await settle()
	check(not game.ui.combo_hint.visible,"notification never overlaps combo hint")
	game.pause_game(true)
	await shot("07-pause")
	check(not game.ui.hud.visible,"HUD hidden while paused")
	game.state = "reward"
	game.rewards = game.roll_rewards(game.rng)
	game.ui.show_rewards(game.rewards)
	await shot("08-rewards")
	print("UI_POLISH_REGRESSION="+JSON.stringify({"checks":checks,"failures":failures}))
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
