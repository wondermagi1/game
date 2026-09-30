extends SceneTree
var game
var checks: int = 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures.append(title); push_error(title)
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.sound.volume=0
	game.profile.data.unlocked=6
	game.profile.data.roles[0].level=25
	game.start_run(0,904,6)
	game.player.manual_control=true
	var rng=RandomNumberGenerator.new()
	rng.seed=818
	for template in ["open","pillars","lanes","center","ring","elite","boss"]:
		game.rooms.data.rooms.r1.layout=template
		game.rooms.enter("r1","r0")
		game.pending.clear()
		var scene=game.rooms.scene
		for i in range(100):
			var pos=scene.safe(Vector2(rng.randf_range(50,1870),rng.randf_range(140,970)))
			var clear=true
			for rect in scene.obstacles:
				if rect.grow(30).has_point(pos): clear=false
			check(clear,"safe_point_%s_%d"%[template,i])
		for exit in [Vector2(160,555),Vector2(1760,555),Vector2(960,240),Vector2(960,880)]:
			var start=Vector2i(scene.safe(Vector2(150,555),55)/40)
			var goal=Vector2i(scene.safe(exit,55)/40)
			check(not scene.navigation.get_id_path(start,goal).is_empty(),"path_%s_%s"%[template,exit])
	# Every available choice resolves a real effect and is once-only.
	for event in game.rooms.Graph.EVENTS:
		var choices=preload("res://scripts/room_events.gd").options(event,game)
		for index in range(choices.size()):
			game.rooms.enter("r2","r1")
			game.rooms.current().event=event
			game.rooms.current().used=false
			game.profile.data.gold=10000
			game.player.hp=game.player.stats.value("hp")*0.3
			var before_gold: int=game.profile.data.gold
			var before_xp: int=game.earned_xp
			game.rooms.open_event()
			game.rooms.choose_event(index)
			check(game.state=="combat" and game.rooms.current().used,"event_%s_%d"%[event,index])
			check(game.earned_xp>before_xp,"event_xp")
			var settled=JSON.stringify(game.profile.data)
			game.rooms.choose_event(index)
			check(JSON.stringify(game.profile.data)==settled,"event_no_double")
	# Rune opening and hidden boss remain optional; all three clicks are explicit.
	game.rooms.data.rooms["secret"]=game.rooms.Graph.room("secret",2,-1,"secret",6,rng)
	if not game.rooms.data.rooms.r2.neighbors.has("secret"): game.rooms.Graph.connect_rooms(game.rooms.data.rooms,"r2","secret")
	game.rooms.data.revealed=false
	game.rooms.data.switches=0
	game.rooms.enter("r2")
	game.player.position=game.rooms.origin()+Vector2(960,235)
	for i in range(3): game.rooms.interact()
	check(game.rooms.data.revealed,"secret_rune_unlock")
	game.rooms.enter("secret","r2")
	game.player.position=game.rooms.origin()+Vector2(960,540)
	game.rooms.interact()
	check(not game.rooms.current().cleared and game.pending.size()==1 and game.pending[0].kind==8,"secret_boss_opt_in")
	check(game.profile.data.achievements.has("secret"),"secret_achievement_retained")
	var result={"checks":checks,"failures":failures}
	var f=FileAccess.open("res://tests/rooms_v4_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  ")); f.close()
	print("V4_ROOMS="+JSON.stringify(result))
	await process_frame
	await process_frame
	game.free()
	quit(0 if failures.is_empty() else 1)
