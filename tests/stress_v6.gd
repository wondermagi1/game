extends SceneTree
var game
var results: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.sound.volume=0
	game.show_numbers=false
	for role in range(3):
		for intensity in [0.3,0.65,1.0]:
			game.profile.fresh()
			game.profile.data.unlocked=6
			game.profile.data.roles[role].level=30
			game.profile.data.roles[role].skills=[10,10,10,10]
			game.start_run(role,478,6)
			game.rooms.data.rooms.r1.layout="pillars"
			game.rooms.enter("r1","r0")
			game.pending.clear()
			game.player.manual_control=true
			game.player.invulnerable=999
			game.player.stats.abyss=true
			game.effects_intensity=intensity
			for u in game.Data.UPGRADES:
				if u[7] in [-1,role]:
					for j in range(100): game.player.stats.apply(u)
			for i in range(32):
				var e=game.spawn_enemy([0,9,11][i%3],game.safe_position(game.rooms.origin()+Vector2(250+(i%8)*200,300+floori(i/8.0)*155)))
				e.state="move"; e.hp=1e15; e.max_hp=1e15
			var times: Array = []
			var previous=Time.get_ticks_usec()
			var peak=0
			for frame in range(420):
				var target=game.nearest_enemy(game.player.position,[],1800)
				if is_instance_valid(target): game.player.aim=game.player.position.direction_to(target.position)
				game.player.use_skill(frame%4)
				if frame%8==0: game.fx.combo_burst(game.player.position,role,"高层压力测试")
				for i in range(5): game.spawn_projectile(game.rooms.origin()+Vector2(140,280+i*130),Vector2.RIGHT,{"style":role,"speed":200.0,"remaining":1600.0,"tint":Color("#abcfef")})
				peak=maxi(peak,game.projectiles.size())
				await process_frame
				var now=Time.get_ticks_usec()
				if frame>=120: times.append((now-previous)/1000.0)
				previous=now
			times.sort()
			var total: float=0
			for t in times: total+=t
			var mean=total/times.size()
			var record={"role":role,"effects":intensity,"enemies":32,"peak_projectiles":peak,"stack_fixture":100,"rank":10,"mean_ms":mean,"p95_ms":times[int(times.size()*0.95)],"fps":1000.0/mean,"samples":times.size(),"static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"video_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"texture_mb":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"window":"1280x720","renderer":"GL Compatibility"}
			results.append(record)
			print("V6_STRESS="+JSON.stringify(record))
	var f=FileAccess.open("res://tests/stress_v6_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"  ")); f.close()
	await process_frame
	await process_frame
	game.free()
	quit()
