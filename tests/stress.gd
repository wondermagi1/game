extends SceneTree
## Real rendered-window stress sample; do not pass --headless or --fixed-fps.
var game

func _initialize() -> void:
 call_deferred("run_sample")

func run_sample() -> void:
 game = load("res://scenes/Main.tscn").instantiate()
 game.test_mode = true
 root.add_child(game)
 game.start_run(1,56291)
 game.sound.volume = 0
 game.player.manual_control = true
 game.player.invulnerable = 999
 game.progress_delay = 999
 for i in range(36):
  var enemy = game.spawn_enemy(i%4,Vector2(220+(i%9)*180,280+(i/9)*115))
  enemy.state = "move"
  enemy.speed = 0
  enemy.cooldown = 999
  enemy.hp = 999999
  enemy.max_hp = 999999
 var timings: Array[float] = []
 var previous: int = Time.get_ticks_usec()
 var peak: int = 0
 for frame in range(480):
  for i in range(5):
   game.spawn_projectile(Vector2(110,820+(i*23)),Vector2.RIGHT,{"style":frame%3,"speed":200.0,"remaining":1500.0,"tint":Color(0.7,0.85,1)})
  peak = maxi(peak,game.projectiles.size())
  await process_frame
  var now: int = Time.get_ticks_usec()
  if frame >= 180: timings.append(float(now-previous)/1000.0)
  previous = now
 timings.sort()
 var sum_ms: float = 0
 for ms in timings: sum_ms += ms
 var mean_ms: float = sum_ms/timings.size()
 print("STRESS_RESULT="+JSON.stringify({"enemies":36,"projectile_peak":peak,"samples":timings.size(),"mean_frame_ms":snappedf(mean_ms,0.01),"p95_frame_ms":snappedf(timings[int(timings.size()*0.95)],0.01),"mean_fps":snappedf(1000.0/mean_ms,0.1),"window":"1280x720","logical_viewport":"1920x1080","renderer":"GL Compatibility"}))
 game.free()
 quit()
