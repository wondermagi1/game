extends SceneTree
var game
var results: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.sound.volume=0
	for role in range(3):
		game.profile.fresh()
		game.rooms.start_lulu(role,531+role)
		game.player.manual_control=true
		game.rooms.enter("r1","r0")
		var elapsed: float=0
		var p=game.player
		while elapsed<180 and game.state=="combat":
			var center: Vector2=game.rooms.origin()+Vector2(960,555)
			var destination=center+Vector2(cos(elapsed*.55)*560,sin(elapsed*.55)*255)
			p.scripted_movement=p.position.direction_to(destination)
			for h in game.hazards:
				var diff: Vector2=p.position-h.p
				if diff.length()<h.radius+70: p.scripted_movement=(p.scripted_movement+diff.normalized()*2).normalized()
			var target=game.nearest_enemy(p.position,[],2000)
			if is_instance_valid(target):
				p.aim=p.position.direction_to(target.position)
				p.attack()
				for slot in range(4): p.use_skill(slot)
			if p.hp<p.stats.value("hp")*.55: p.use_item(0)
			if fmod(elapsed,3.0)<.02: p.dash(p.scripted_movement)
			await physics_frame
			elapsed+=1.0/60.0
		var record={"role":role,"level":1,"seconds":snappedf(elapsed,.1),"won":game.won,"hp":p.hp,"taken":game.taken,"kills":game.kills,"gold":game.earned_gold,"xp":game.earned_xp,"gear":game.earned_gear}
		results.append(record)
		print("LULU_COMBAT="+JSON.stringify(record))
		game.back_to_menu()
	var f=FileAccess.open("res://tests/lulu_combat_v5_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"  "));f.close()
	game.free()
	quit()
