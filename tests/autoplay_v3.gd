extends SceneTree
## Combat simulation uses normal HP, damage, cooldowns and collisions.
## Later chapters use explicitly reported progression fixtures; player saves are never changed.
var game
var results: Array = []
var only_chapter: int = 0
var only_role: int = -1
var build: String = "recommended"
var output_path = "res://tests/autoplay_v3_results.json"

func _initialize() -> void:
 call_deferred("run_playthroughs")

func run_playthroughs() -> void:
 game = load("res://scenes/Main.tscn").instantiate()
 game.test_mode = true
 root.add_child(game)
 if game.ui==null:
  quit(1)
  return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--chapter="): only_chapter = int(arg.split("=")[1])
  if arg.begins_with("--role="): only_role = int(arg.split("=")[1])
  if arg.begins_with("--build="): build = arg.split("=")[1]
 if only_chapter>0: output_path = "res://tests/autoplay_v3_chapter%d.json"%only_chapter
 if build!="recommended": output_path = "res://tests/autoplay_v3_build_%s.json"%build
 game.sound.volume = 0
 game.show_numbers = false
 for chapter in range(1,7):
  if only_chapter>0 and chapter!=only_chapter: continue
  for role in range(3):
   if only_role>=0 and role!=only_role: continue
   var fixture = preload("res://tests/build_fixture.gd").configure(game,chapter,role,build)
   game.start_run(role,81800+chapter*10+role,chapter)
   fixture["starting_attack"] = snappedf(game.player.stats.value("attack"),0.1)
   fixture["starting_hp"] = snappedf(game.player.stats.value("hp"),0.1)
   game.player.manual_control = true
   var frames: int = 0
   var peaks: int = 0
   var boss_seconds: float = 0.0
   while game.state!="end" and frames<90000:
    frames += 1
    peaks = maxi(peaks,game.projectiles.size())
    if game.state=="reward":
     var choice = 0
     var best = -1.0
     for i in range(game.rewards.size()):
      var u: Array = game.rewards[i]
      var score = 1.0
      if u[3] in ["attack_pct","attack","multishot","burn","poison"]: score = 6
      if u[3] in ["heal","hp","kill_heal"] and game.player.hp<game.player.stats.value("hp")*0.5: score = 9
      if score>best: best = score; choice = i
     game.choose_reward(choice)
    if game.state=="intermission": game.next_round()
    if game.state=="combat":
     if game.flow.boss_kind()>=0: boss_seconds += 1.0/60.0
     var p = game.player
     var nearest = game.nearest_enemy(p.global_position,[],2000)
     var move = Vector2.ZERO
     if is_instance_valid(nearest):
      var distance: float = p.global_position.distance_to(nearest.global_position)
      var toward: Vector2 = p.global_position.direction_to(nearest.global_position)
      p.aim = toward
      var preferred = minf(p.stats.value("range")*0.66,470)
      if distance>preferred: move += toward*0.7
      elif distance<preferred*0.72: move -= toward
      move += toward.orthogonal()*0.65
      for enemy in game.enemies:
       var diff: Vector2 = p.position-enemy.position
       if diff.length()<160: move += diff.normalized()*2
      for shot in game.projectiles:
       if shot.enemy_shot and shot.position.distance_to(p.position)<120: move += shot.direction.orthogonal()*0.7
      for hazard in game.hazards:
       if p.position.distance_to(hazard.p)<hazard.radius+40: move += hazard.p.direction_to(p.position)*2
      p.attack()
      if distance<600:
       for slot in [2,0,1,3]: p.use_skill(slot)
      if distance<130: p.dash(move.normalized())
     else: move = p.position.direction_to(Vector2(960,600))*0.2
     if p.hp<p.stats.value("hp")*0.82:
      var pickup_distance = 380.0
      var pickup_target = Vector2.INF
      for drop in game.pickups:
       var d: float = drop.p.distance_to(p.position)
       if d<pickup_distance: pickup_distance = d; pickup_target = drop.p
      if pickup_target!=Vector2.INF: move = p.position.direction_to(pickup_target)*1.5+move*0.2
     if p.hp<p.stats.value("hp")*0.45: p.use_item(0); p.use_item(1)
     if p.position.x<180: move.x += 2
     if p.position.x>1740: move.x -= 2
     if p.position.y<250: move.y += 2
     if p.position.y>860: move.y -= 2
     p.scripted_movement = move.normalized()
    await physics_frame
   var record = {"chapter":chapter,"role":role,"won":game.won,"round":game.flow.round_number,"kills":game.kills,"health":game.player.hp,"seconds":snappedf(game.elapsed,0.1),"projectile_peak":peaks,"timeout":frames>=90000,"seed":game.run_seed,"boss_seconds":snappedf(boss_seconds,0.1),"damage_taken":snappedf(game.taken,0.1),"final_level":game.profile.data.roles[role].level}
   record.merge(fixture)
   results.append(record)
   var partial = FileAccess.open(output_path,FileAccess.WRITE)
   partial.store_string(JSON.stringify(results,"  "))
   partial.close()
   print("PLAYTHROUGH="+JSON.stringify(record))
 var f = FileAccess.open(output_path,FileAccess.WRITE)
 f.store_string(JSON.stringify(results,"  "))
 f.close()
 game.free()
 print("AUTOPLAY_RESULT="+JSON.stringify(results))
 quit()
