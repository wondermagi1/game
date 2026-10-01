extends SceneTree

var game
var checks: int=0
var failures: Array=[]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game);game.sound.volume=0
	game.profile.data.unlocked=6
	for role in range(3):
		game.profile.data.roles[role].level=30;game.profile.data.roles[role].skills=[10,10,10,10]
		game.start_run(role,8300+role,2);game.player.manual_control=true;game.player.invulnerable=999
		game.rooms.data.rooms.r1.layout="open";game.rooms.enter("r1","r0");game.pending.clear()
		var enemy=game.spawn_enemy(0,game.rooms.origin()+Vector2(1050,550));enemy.hp=1e8;enemy.max_hp=1e8;enemy.state="move";enemy.set_physics_process(false)
		var idle=game.player.skills.combo_status()
		check(not bool(idle.ready),"role %d idle combo teaches next step"%role)
		check(str(idle.hint).contains("→"),"role %d idle hint shows sequence"%role)
		if role==0:enemy.sword_mark=10
		elif role==1:enemy.powder_mark=10
		else:enemy.mark_time=10
		var ready=game.player.skills.combo_status()
		check(bool(ready.ready) and float(ready.time)>=9.9,"role %d marked target exposes forgiving window"%role)
		game.ui._process(.1)
		check(game.ui.combo_hint.text.contains("连携就绪"),"role %d HUD announces readiness"%role)
		var before=game.player.skills.combo_count
		game.player.skills.combo(enemy.global_position,["穿云追剑","霰幕连爆","猎日星坠"][role])
		check(game.player.skills.combo_count==before+1,"role %d combo count recorded"%role)
		check(game.banner.begins_with("连携技"),"role %d combo receives center-screen feedback"%role)
		check(game.player.skills.combo_status().title==["穿云追剑","霰幕连爆","猎日星坠"][role],"role %d HUD keeps triggered combo title"%role)
		game.back_to_menu();await process_frame
	var report={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_combo_v8_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("COMBO_V8_REGRESSION="+JSON.stringify(report));game.free();await process_frame;quit(0 if failures.is_empty() else 1)
