extends SceneTree
var game
var checks=0
var failures=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game)
	game.sound.volume=0
	var profile_before=JSON.stringify(game.profile.data)
	game.ui.show_action_inspector()
	await process_frame
	var inspector=game.ui.overlay.get_child(0)
	for role in range(3):
		inspector.actor.kind=role
		for direction in range(8):
			inspector.actor.aim=Vector2.from_angle(direction*PI/4)
			for action in [0,1,4,10,11,12,13]:
				inspector.selected_action=action;inspector.refresh();inspector.advance(.12)
				var a=inspector.actor
				check(not a.articulated_preview,"default whole-frame route")
				check(a.frame_mesh().get_surface_count()==1,"valid registered frame mesh")
				check(a.muzzle_local().y<-35 and a.muzzle_local().y>-130,"muzzle above ground")
	check(JSON.stringify(game.profile.data)==profile_before,"inspection never alters save")
	game.ui.show_menu()
	for role in range(3):
		game.profile.data.unlocked=6;game.profile.data.roles[role].level=30;game.profile.data.roles[role].skills=[10,10,10,10]
		game.start_run(role,602,1);game.rooms.data.rooms.r1.layout="open";game.rooms.enter("r1","r0");game.pending.clear()
		game.player.manual_control=true;game.player.invulnerable=999
		game.player.position=game.rooms.origin()+Vector2(800,550);game.player.aim=Vector2.RIGHT
		await physics_frame
		var count=game.projectiles.size();game.player.attack_clock=0
		check(game.player.attack(),"first attack emits")
		var release_socket: Vector2=game.player.position+game.player.visual.muzzle_local()
		var emitted=game.projectiles.size()
		for i in range(10):game.player.visual._process(.01)
		check(emitted>count and game.projectiles.size()==emitted,"animation never creates extra bullets")
		var shot=game.projectiles.back()
		check((shot.position+shot.launch_offset).distance_to(release_socket)<3,"visual shot starts at socket")
		var rng=game.rng.state
		for i in range(40):game.presentation_fx.emit("ultimate",game.player.position,Vector2.UP,role,4);game.presentation_fx._process(.05)
		check(game.rng.state==rng,"cosmetic RNG isolated")
		check(game.presentation_fx.materials.bits.size()<=112,"texture particle budget")
		game.player.use_skill(3)
		check(game.player.skills.ultimate.active,"C controller starts")
		game.player.skills.ultimate.tick(.7)
		check(game.player.visual.clip in ["ultimate_sustain","combo"],"C sustain synced")
		game.state="paused"
		var time=game.player.visual.clock;var n=game.projectiles.size()
		for i in range(3):await process_frame
		check(game.player.visual.clock==time and game.projectiles.size()==n,"pause freezes animation and projectiles")
		game.state="combat";game.player.skills.ultimate.active=false;game.clear_attacks()
		# Author a thin obstacle between root and old projectile spawn, testing near-wall fire.
		var wall=StaticBody2D.new();wall.position=game.player.position+Vector2(25,0);wall.collision_layer=1
		var shape=CollisionShape2D.new();var rect=RectangleShape2D.new();rect.size=Vector2(10,140);shape.shape=rect;wall.add_child(shape);game.add_child(wall)
		await physics_frame;await physics_frame
		var s=game.spawn_projectile(game.player.position+Vector2(32,0),Vector2.RIGHT,{"damage":5.0,"speed":900.0})
		check(s.position.x<wall.position.x,"near wall cannot spawn through cover")
		wall.queue_free();game.back_to_menu();await process_frame
		check(game.presentation_fx.materials.bits.is_empty(),"room reset clears all material particles")
	game.rooms.start_lulu(0,607);game.player.manual_control=true
	game.cinematic.testing=true;game.rooms.enter("r1","r0");game.pending.clear()
	var lulu=game.spawn_enemy(14,game.rooms.origin()+Vector2(1100,500))
	game.cinematic.finish();game.state="combat";lulu.set_physics_process(false)
	lulu.state="move";lulu.cooldown=0;lulu.pattern=0
	lulu._physics_process(.01)
	check(lulu.state=="windup" and lulu.visual.lulu_animation=="blow","Lulu starts authored telegraph before damage")
	lulu._physics_process(.4)
	check(game.projectiles.is_empty() and lulu.visual.lulu_battle_frame().x<3,"Lulu preparation cannot fire early")
	lulu._physics_process(.46)
	check(game.projectiles.size()==5 and lulu.visual.lulu_battle_frame()==Vector2i(3,0),"Lulu release frame and five bubbles agree")
	game.state="paused";var lulu_time=lulu.visual.lulu_time;lulu.visual._process(.3)
	check(lulu.visual.lulu_time==lulu_time,"Lulu new atlas pauses with combat")
	game.state="combat";lulu.pattern=1;lulu.execute_attack()
	check(lulu.visual.lulu_battle_frame()==Vector2i(3,1) and game.hazards.size()==1,"painted splash keeps the warning hazard")
	lulu.pattern=2;lulu.execute_attack();lulu.visual._process(1.1)
	check(lulu.visual.lulu_battle_frame().y==2 and lulu.state=="recover","painted bath keeps a real recovery opening")
	game.back_to_menu();await process_frame
	game.ui.show_menu()
	check(AudioServer.get_bus_index("Combat")>=0 and AudioServer.get_bus_index("UI")>=0,"audio buses ready")
	for key in ["gun","sword","bow","hit"]:check(game.sound.variations[key].size()>=3,"three source variants "+key)
	game.sound.volume=.3
	var before=game.rng.state;game.sound.play("gun");game.sound.last_play.clear();game.sound.play("sword")
	check(game.rng.state==before,"sound RNG isolated")
	game.sound.stop_all();check(not game.sound.foley.any(func(v):return v.playing),"audio stop clears voices")
	var report={"checks":checks,"failures":failures}
	var f=FileAccess.open("res://tests/regression_v6_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print("V6_REGRESSION="+JSON.stringify(report));game.free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
