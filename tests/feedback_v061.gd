extends SceneTree
## Check the requested selective rollback against the retained V5 sound generator.
var game
var checks=0
var failures=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game)
	var classic=load("res://scripts/sound.gd").new();root.add_child(classic)
	game.sound.volume=.08
	for role in [1,2]:
		game.profile.data.roles[role].level=30;game.profile.data.roles[role].skills=[10,10,10,10]
		game.start_run(role,610+role,1);game.player.manual_control=true
		game.rooms.data.rooms.r1.layout="open";game.rooms.enter("r1","r0");game.pending.clear()
		game.player.position=game.rooms.origin()+Vector2(760,560);game.player.aim=Vector2.RIGHT
		game.player.invulnerable=999
		var keys=["gun","reload","combo_gun","explosion","hit","crit"] if role==1 else ["bow","giant_arrow","combo_bow","hit","crit"]
		for phase in ["start","loop","finish"]:keys.append("ultimate_%d_%s"%[role,phase])
		for key in keys:
			game.sound.stop_all();game.sound.last_play.clear();game.sound.play(key)
			check(game.sound.voices.any(func(v):return v.playing and v.stream==game.sound.clips[key]),"classic voice plays "+key)
			check(not game.sound.foley.any(func(v):return v.playing),"no new sample overlay "+key)
			check(game.sound.clips[key].data==classic.clips[key].data,"original V5 waveform "+key)
		game.sound.stop_all()
		game.presentation_fx.clear()
		for kind in ["shot","cast","combo","ultimate","impact","explosion"]:
			game.presentation_fx.emit(kind,game.player.position,Vector2.RIGHT,role,2)
		check(game.presentation_fx.materials.bits.is_empty() if role==1 else not game.presentation_fx.materials.bits.is_empty(),"selective material rollback role "+str(role))
		if role==1:
			check(not game.presentation_fx.particles.is_empty(),"classic sparks remain visible")
			var e=game.spawn_enemy(0,game.player.position+Vector2(450,0));e.set_physics_process(false);e.hp=1e7;e.max_hp=1e7
			game.art.glyphs.clear();game.player.use_skill(3);game.player.skills.ultimate.tick(.36)
			check(game.art.glyphs.any(func(g):return g.kind=="muzzle" and g.role==1),"C restores V5 muzzle shape")
			check(game.presentation_fx.materials.bits.is_empty(),"C cannot reintroduce new explosions")
			check(not game.player.visual.articulated_preview and game.player.visual.muzzle_local().y<-35,"held weapon and release height retained")
		game.back_to_menu();await process_frame
	game.start_run(0,615,1);game.player.manual_control=true;game.sound.stop_all();game.sound.last_play.clear();game.sound.play("sword")
	check(game.sound.foley.any(func(v):return v.playing),"sword keeps V6 sound")
	game.sound.stop_all();game.sound.last_play.clear();game.sound.play("lulu_bubble")
	check(game.sound.foley.any(func(v):return v.playing),"Lulu keeps V6 sound")
	game.state="menu";game.sound.volume=0;game.sound.stop_all()
	# Allow the audio mixer to retire rapid start/stop test voices before teardown.
	await create_timer(.15).timeout
	classic.free();game.free()
	await process_frame;await process_frame
	var report={"checks":checks,"failures":failures}
	var f=FileAccess.open("res://tests/feedback_v061_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("FEEDBACK_V061="+JSON.stringify(report));quit(0 if failures.is_empty() else 1)
