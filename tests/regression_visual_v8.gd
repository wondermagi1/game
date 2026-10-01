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
	game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game)
	game.sound.volume=0
	for role in range(3):
		game.profile.data.unlocked=6
		game.profile.data.roles[role].level=30
		game.profile.data.roles[role].skills=[10,10,10,10]
		game.start_run(role,8100+role,2)
		game.player.manual_control=true;game.player.invulnerable=999
		game.rooms.data.rooms.r1.layout="open";game.rooms.enter("r1","r0");game.pending.clear()
		game.player.position=game.rooms.origin()+Vector2(850,610);game.player.aim=Vector2.RIGHT
		var rng_before=game.rng.state
		check(game.player.use_skill(3),"role %d ultimate starts"%role)
		var expected=["sword_halo","gun_heat","bow_constellation"][role]
		check(game.art.glyphs.any(func(g):return g.kind==expected),"role %d has authored ultimate identity layer"%role)
		check(game.presentation_fx.materials.bits.size()>=2,"role %d gather has textured material layers"%role)
		check(game.rng.state==rng_before,"role %d presentation keeps combat RNG isolated"%role)
		game.player.skills.ultimate.finish()
		check(game.art.glyphs.any(func(g):return g.kind=="residue"),"role %d finish leaves bounded residue"%role)
		if role==1:check(game.presentation_fx.materials.bits.any(func(bit):return bit.type=="explosion"),"gunner finish keeps textured explosion core")
		else:check(game.presentation_fx.materials.bits.filter(func(bit):return bit.type=="magic").size()>=2,"role %d finish uses role-colored magic core"%role)
		check(game.presentation_fx.materials.bits.size()<=80,"role %d material budget bounded"%role)
		if role in [1,2]:check(game.sound.uses_classic_audio("ultimate_%d_finish"%role),"role %d accepted classic audio retained"%role)
		game.back_to_menu();await process_frame
	var report={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_visual_v8_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("VISUAL_V8_REGRESSION="+JSON.stringify(report))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
