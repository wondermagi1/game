extends SceneTree
const Scene = preload("res://scenes/Main.tscn")
const C = preload("res://scripts/catalog.gd")
const Profile = preload("res://scripts/profile.gd")
const Stats = preload("res://scripts/stats.gd")
const Data = preload("res://scripts/data.gd")
var game
var passed: int = 0
var failures: Array = []
var drop_samples: Array = []

func _initialize() -> void:
 call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
 if condition: passed += 1
 else:
  failures.append(message)
  push_error("FAILED: "+message)

func frames(count: int) -> void:
 for i in range(count): await physics_frame

func fresh(role: int = 0, chapter: int = 1) -> void:
 game.profile.data.unlocked = 4
 game.start_run(role,72301,chapter)
 game.player.manual_control = true
 game.player.invulnerable = 0
 game.player.attack_clock = 0
 game.progress_delay = 999
 game.sound.volume = 0

func target(pos: Vector2, kind: int = 0):
 var enemy = game.spawn_enemy(kind,pos)
 enemy.state = "move"
 enemy.speed = 0
 enemy.cooldown = 999
 enemy.hp = 5000
 enemy.max_hp = 5000
 return enemy

func run_tests() -> void:
 game = Scene.instantiate()
 game.test_mode = true
 root.add_child(game)
 await frames(3)
 check(game.state=="menu","v2 opens at main menu")
 for method in ["show_select","show_chapters","show_characters","show_equipment","show_loadout","show_talents","show_combos","show_consumables","show_achievements","show_codex"]:
  game.state = "menu"
  game.ui.call(method)
  await frames(2)
  check(game.ui.overlay.get_child_count()>0,"UI page builds: "+method)
 for cat in range(7):
  game.ui.codex_category = cat
  game.ui.show_codex()
  check(game.ui.codex_entries().size()>0,"codex category has data %d"%cat)
 game.ui.codex_query = "不存在的查询"
 game.ui.render_codex()
 check(game.ui.codex_rows.get_child_count()==1,"codex empty filter explains result")
 game.ui.codex_query = ""
 var p = Profile.new()
 p.memory_only = true
 p.fresh()
 var rng = RandomNumberGenerator.new()
 rng.seed = 93412
 check(p.data.inventory.size()==3,"three starter weapons")
 var layered_stats = Stats.new(0)
 layered_stats.permanent = {"attack":10.0,"attack_pct":0.08,"hp":50.0}
 layered_stats.apply(Data.UPGRADES[2])
 check(is_equal_approx(layered_stats.value("attack"),36.0),"persistent and run percentage bonuses counted exactly once")
 layered_stats.apply(Data.UPGRADES[0])
 check(is_equal_approx(layered_stats.value("hp"),180.0),"hp buff does not copy equipment hp into run bonus")
 layered_stats.permanent = {}
 check(is_equal_approx(layered_stats.value("attack"),22.4) and is_equal_approx(layered_stats.value("hp"),130.0),"removing permanent gear leaves only genuine run bonuses")
 check(p.set_count(0)==0,"starter is not full set")
 p.data.gold = 100000
 p.data.material = 10000
 for role in range(3):
  p.data.roles[role].level = 30
  var original = Stats.new(role)
  var base_attack = original.value("attack")
  for slot in range(6):
   var gear = p.make_item(role,slot,3,1,rng)
   p.receive_item(gear)
   check(p.equip(role,gear.uid)=="已装备","equip role %d slot %d"%[role,slot])
   check(p.item_by_id(gear.uid).affixes.size()==2,"legendary retains two affixes")
  check(p.set_count(role)==6,"complete six-piece set %d"%role)
  var stats = Stats.new(role)
  stats.permanent = p.permanent_bonuses(role)
  var attack = stats.value("attack")
  for i in range(10):
   p.equip(role,p.data.roles[role].equipped["0"])
   stats.permanent = p.permanent_bonuses(role)
  check(is_equal_approx(stats.value("attack"),attack),"re-equip never compounds attributes")
  check(is_equal_approx(Stats.new(role).value("attack"),base_attack),"shared base config untouched")
  var weapon: Dictionary = p.item_by_id(p.data.roles[role].equipped["0"])
  var before: float = p.item_stats(weapon).attack
  for n in range(10): check(p.enhance(weapon.uid)=="强化成功","enhance valid level")
  check(p.item_stats(weapon).attack>before,"enhancement changes actual stats")
  var gold: int = p.data.gold
  p.enhance(weapon.uid)
  check(int(weapon.enhance)==10 and int(p.data.gold)==gold,"+10 cap does not charge")
  check(p.salvage(weapon.uid)=="请先卸下并解除锁定","equipped gear cannot be salvaged")
  p.unequip(role,0)
  weapon.locked = true
  check(p.salvage(weapon.uid)=="请先卸下并解除锁定","locked gear protected")
  weapon.locked = false
  p.salvage(weapon.uid)
  check(p.item_by_id(weapon.uid).is_empty(),"salvage removes instance")
 var wrong = p.make_item(1,0,1,1,rng)
 p.receive_item(wrong)
 check(p.equip(0,wrong.uid)=="这件装备属于另一角色","wrong role rejected")
 p.data.roles[0].level = 1
 var high = p.make_item(0,0,1,15,rng)
 p.receive_item(high)
 check(p.equip(0,high.uid)=="角色等级不足","level requirement enforced")
 var count = p.data.inventory.size()
 p.receive_item(high)
 check(p.data.inventory.size()==count,"duplicate UID not inserted")
 while p.data.inventory.size()<C.CAPACITY: p.receive_item(p.make_item(0,1,0,1,rng))
 var overflow = p.make_item(0,2,2,1,rng)
 p.receive_item(overflow)
 check(p.data.overflow.size()==1,"full backpack safely stores overflow")
 var unwanted: Dictionary = p.data.inventory.back()
 p.salvage(unwanted.uid)
 check(p.claim_overflow()==1 and not p.item_by_id(overflow.uid).is_empty(),"overflow can be recovered")
 p.fresh()
 p.data.roles[0].level = 1
 var levels = p.gain_xp(0,1000000)
 check(levels==29 and int(p.data.roles[0].level)==30 and int(p.data.roles[0].xp)==0,"multi-level xp caps at 30")
 check(p.gain_xp(0,10000)==0,"max level ignores additional xp")
 check(p.train(0,"power")=="天赋提升","talent spends point")
 check(p.train_skill(0,0)=="技能升级","skill rank two")
 check(p.train_skill(0,0)=="技能升级","skill rank three")
 check(p.train_skill(0,0)=="技能已达 3 级","skill rank cap")
 check(p.talent_points(0)==23,"talent points charged exactly")
 check(p.reset_talents(0)=="已重置，天赋点全部返还" and p.talent_points(0)==29,"free reset returns all points")
 check(p.permanent_bonuses(0).get("attack_pct",0)==0,"reset removes bonus")
 p.data.gold = 1000
 var stock = p.make_shop(0,1,rng)
 check(p.buy(stock,0)=="购买成功","shop purchase")
 var gold = p.data.gold
 p.buy(stock,0)
 check(p.data.gold==gold,"sold offer cannot double charge")
 p.unlock("boss")
 p.claim_achievement("boss")
 gold = p.data.gold
 p.claim_achievement("boss")
 check(p.data.gold==gold,"achievement claim once")
 for tier in range(4):
  var drops = 0
  var qualities = [0,0,0,0]
  for i in range(10000):
   p.data.boss_misses = 0 # sample base rate separately from pity
   var item = p.roll_equipment(tier,0,2,rng)
   if not item.is_empty(): drops += 1; qualities[int(item.quality)] += 1
  var rate = drops/10000.0
  check(absf(rate-C.DROP_CHANCE[tier])<0.025,"drop base rate tier %d"%tier)
  drop_samples.append({"tier":tier,"samples":10000,"drops":drops,"rate":rate,"qualities":qualities})
 p.data.boss_misses = 2
 var pity = p.roll_equipment(2,0,2,rng)
 check(not pity.is_empty() and int(pity.quality)>=1 and int(p.data.boss_misses)==0,"boss pity guarantees rare or higher")
 # Real disk round trip isolated from the player's user:// save.
 p.path = "res://tests/profile_test_v2.json"
 p.memory_only = false
 check(p.save_profile(),"profile writes with checksum")
 var q = Profile.new()
 q.path = p.path
 q.load_profile()
 check(JSON.parse_string(JSON.stringify(q.data))==JSON.parse_string(JSON.stringify(p.data)),"profile round trip retains complete data")
 var saved_gold = int(p.data.gold)
 p.data.gold += 1
 check(p.save_profile(),"second save creates backup")
 var f = FileAccess.open(p.path,FileAccess.WRITE)
 f.store_string("broken")
 f.close()
 q = Profile.new()
 q.path = p.path
 q.load_profile()
 check(int(q.data.gold)==saved_gold and not q.notice.is_empty(),"corrupt primary restores backup")
 # All twelve skills execute through the real player/controller.
 for role in range(3):
  game.profile.data.roles[role].level = 30
  fresh(role)
  game.player.aim = Vector2.RIGHT
  for slot in range(4):
   check(game.player.use_skill(slot),"active skill executes %d/%d"%[role,slot])
   check(not game.player.use_skill(slot),"cooldown prevents duplicate %d/%d"%[role,slot])
  var before_cd = game.player.skills.cooldowns[0]
  game.pause_game()
  await frames(10)
  check(game.player.skills.cooldowns[0]==before_cd,"pause freezes skill timers")
  game.resume_game()
  await frames(20)
  check(game.player.skills.cooldowns[0]<before_cd,"combat advances skill timers")
 # Real swept projectile and status/combination path.
 fresh(0)
 game.player.global_position = Vector2(400,550)
 game.player.aim = Vector2.RIGHT
 var enemy = target(Vector2(620,550))
 game.player.use_skill(1)
 await frames(18)
 check(enemy.sword_mark>0 and enemy.hp<5000,"cloud projectile hits and marks")
 game.player.attack()
 await frames(18)
 check(game.profile.data.achievements.has("combo"),"ordinary attack consumes mark for combo")
 check(enemy.sword_mark<=0,"mark consumed exactly once")
 fresh(1)
 enemy = target(game.player.global_position+Vector2(90,0))
 game.player.aim = Vector2.RIGHT
 check(game.player.attack(),"normal gun attack")
 check(game.player.ammo==5,"normal gun consumes one round")
 game.player.ammo = 0
 game.player.attack_clock = 0
 check(not game.player.attack() and game.player.reload_time>0,"empty gun reloads without firing")
 var health = game.player.hp
 game.player.hurt(20)
 check(game.player.hp<health,"damage changes hp")
 var wounded = game.player.hp
 game.player.hurt(20)
 check(game.player.hp==wounded,"damage protection prevents repeated frame damage")
 game.player.invulnerable = 0
 game.player.hp = 20
 game.profile.data.consumables.potion = 2
 game.profile.data.quick[0] = "potion"
 check(game.player.use_item(0),"potion heals")
 check(not game.player.use_item(0) and int(game.profile.data.consumables.potion)==1,"item cooldown and quantity")
 # New role at level one cannot use later skills.
 game.profile.data.roles[2].level = 1
 fresh(2)
 check(not game.player.use_skill(1),"locked skill cannot execute")
 # Actual input release gate prevents the menu click from becoming a shot.
 fresh(0)
 game.player.manual_control = false
 game.focused = true
 Input.action_press("attack")
 await frames(2)
 check(game.projectiles.is_empty(),"closing UI with held click does not fire")
 Input.action_release("attack")
 await frames(2)
 Input.action_press("attack")
 await frames(2)
 check(not game.projectiles.is_empty(),"fresh click fires after release")
 Input.action_release("attack")
 # Skill combinations and six-piece / legendary procs use non-recursive sources.
 for role in range(3):
  game.profile.data.roles[role].level = 30
  fresh(role)
  game.player.stats.permanent["set_count"] = 6
  game.player.stats.permanent["legend_weapon"] = 1
  enemy = target(game.player.global_position+Vector2(120,0))
  var shot = game.Projectile.new()
  shot.source = "normal"
  var initial_hp = enemy.hp
  if role==0:
   enemy.sword_mark = 4
   game.player.skills.on_hit(enemy,shot)
   check(enemy.hp<initial_hp and enemy.sword_mark==0,"sword mark adds damage once")
   shot.returning = true
   game.player.skills.on_hit(enemy,shot)
   check(game.projectiles.size()==1 and game.projectiles[0].source=="legend","legendary return sword emits limited secondary")
   var before = game.projectiles.size()
   game.player.skills.on_hit(enemy,shot)
   check(game.projectiles.size()==before,"legendary return has internal cooldown")
   game.player.orbit_time = 3
   game.player.skills.attacks = 3
   game.player.skills.on_attack()
   check(game.projectiles.size()==before+3,"sword six-piece emits three blades")
   game.player.use_skill(2)
   check(game.zones.size()==3,"return-step creates three path strikes")
  elif role==1:
   shot.empowered = true
   game.add_zone(enemy.global_position,160,4,4,0,"powder",1)
   game.player.skills.on_hit(enemy,shot)
   check(not game.in_zone(enemy.global_position,"powder") and enemy.hp<initial_hp,"empowered shot consumes powder and detonates")
   var after_hp = enemy.hp
   game.player.skills.on_hit(enemy,shot)
   check(enemy.hp==after_hp,"gun legendary/set procs respect cooldown")
   shot.source = "rapid"
   enemy.powder_mark = 4
   game.player.skills.combo_cd = 0
   game.player.skills.on_hit(enemy,shot)
   check(enemy.powder_mark==0 and enemy.hp<after_hp,"rapid fire consumes shotgun mark")
  else:
   game.add_zone(enemy.global_position,170,1,0.4,10,"arrows",3)
   game.player.skills.on_hit(enemy,shot)
   check(shot.bounce==1,"rain grants a normal arrow bounce")
   enemy.mark_time = 5
   game.player.skills.on_hit(enemy,shot)
   check(shot.bounce==2 and game.projectiles.size()==1,"bow legend and six-piece each activate")
   shot.source = "sun"
   game.player.skills.on_hit(enemy,shot)
   check(enemy.mark_time==0 and enemy.hp<initial_hp,"sun arrow consumes hunt mark")
  shot.free()
 # Mutations are blocked in combat inspection and item use is blocked while paused.
 fresh(0)
 game.pause_game()
 var gear: Dictionary = game.profile.data.inventory[0]
 game.ui.view_role = 0
 var equipped_before = game.profile.data.roles[0].equipped.duplicate()
 game.ui.unequip_slot(0)
 check(game.profile.data.roles[0].equipped==equipped_before,"paused equipment UI is read-only")
 check(not game.player.use_item(0),"paused item hotkey cannot consume")
 game.ui.selected_uid = gear.uid
 game.ui.show_equipment()
 game.ui.render_item_detail()
 check(game.ui.inventory_detail.get_child_count()>5,"selected gear detail renders controls and values")
 # Reinforcement pacing: no early reward, bounded density, pause-safe timing.
 fresh(0,4)
 game.progress_delay = 0
 game.begin_wave()
 check(game.director.receiving() and game.pending.size()>0,"normal wave starts with a reinforcement group")
 game.pending.clear()
 game.stage_finished()
 check(game.state=="combat" and game.rewards.is_empty(),"clearing early cannot skip remaining reinforcements")
 game.pause_game()
 var frozen_wave_time: float = game.director.elapsed
 await frames(8)
 check(is_equal_approx(frozen_wave_time,game.director.elapsed),"pause freezes reinforcement timer")
 game.resume_game()
 await frames(60)
 check(game.enemies.size()+game.pending.size()>0,"empty arena receives next group promptly")
 fresh(0,4)
 check(not game.director.receiving(),"restart removes old reinforcement schedule")
 var director = game.WaveDirector.new()
 var simulated_flow = game.Campaign.new()
 for chapter in range(1,5):
  simulated_flow.start(chapter)
  simulated_flow.wave = 1
  director.start(simulated_flow)
  var capacity_ok = true
  var generated = 0
  for i in range(1000):
   var occupied = i%16
   var added: int = director.tick(0.1,occupied)
   if added>0 and occupied+added>int(C.PACING[chapter-1].alive): capacity_ok = false
   generated += added
  check(capacity_ok and generated>0,"reinforcement density bounded chapter %d"%chapter)
  check(not director.receiving() and director.tick(60,0)==0,"reinforcements stop after deadline chapter %d"%chapter)
  simulated_flow.round_number = simulated_flow.rounds()
  simulated_flow.wave = simulated_flow.waves()
  director.start(simulated_flow)
  check(not director.receiving(),"boss wave has no artificial timer chapter %d"%chapter)
 # Chapter curve uses fully equipped/talented reference builds, with fixed enemies.
 var last_hp = 0.0
 var last_delta = 0.0
 for chapter in range(1,5):
  fresh(0,chapter)
  var baseline_enemy = game.spawn_enemy(0,Vector2(800,300))
  var chapter_hp: float = baseline_enemy.max_hp
  if chapter>1:
   var hp_delta = chapter_hp-last_hp
   check(hp_delta>last_delta,"enemy HP chapter gaps grow nonlinearly %d"%chapter)
   last_delta = hp_delta
  last_hp = chapter_hp
  for role in range(3):
   var fixture = preload("res://tests/build_fixture.gd").configure(game,chapter,role)
   game.start_run(role,82+chapter,chapter)
   check(game.profile.talent_points(role)==0,"reference build allocates all starting talent points")
   check(game.profile.set_count(role)==[0,2,4,6][chapter-1],"reference build includes set bonuses")
   if chapter>=3: check(game.player.skills.rank(0)==2,"reference build includes skill upgrades")
   if chapter==4: check(game.player.skills.rank(1)==2,"late build includes second skill upgrade")
   check(fixture.fixture_talent_points==[0,4,9,14][chapter-1],"reference build talent budget is legal")
  var upgraded_enemy = game.spawn_enemy(0,Vector2(800,300))
  check(is_equal_approx(upgraded_enemy.max_hp,chapter_hp),"enemy strength does not follow player gear or talents")
  await frames(1)
 # Isolate equipment/talent impact from random chapter rewards and movement paths.
 var build_damage: Array = []
 for build in ["untrained","recommended","developed"]:
  preload("res://tests/build_fixture.gd").configure(game,4,0,build)
  game.start_run(0,55214,4)
  game.progress_delay = 999
  game.player.manual_control = true
  game.player.aim = Vector2.RIGHT
  var dummy = target(game.player.position+Vector2(100,0))
  dummy.hp = 100000
  dummy.max_hp = 100000
  for frame in range(600):
   game.player.attack()
   game.player.use_skill(0)
   await frames(1)
  build_damage.append({"build":build,"damage_10s":snappedf(game.dealt,0.1)})
 check(build_damage[1].damage_10s>build_damage[0].damage_10s,"talents and skill ranks increase actual combat damage")
 check(build_damage[2].damage_10s>build_damage[1].damage_10s,"developed equipment build improves controlled combat damage")
 # Full progression for all chapters, three roles: actual kill/drop/reward handlers.
 for role in range(3):
  for chapter in range(1,5):
   fresh(role,chapter)
   var wave_total = 0
   var reward_total = 0
   while game.state!="end" and wave_total<30:
    game.begin_wave()
    wave_total += 1
    check(game.max_waves()<=3,"wave ceiling")
    while not game.pending.is_empty():
     var entry: Dictionary = game.pending.pop_front()
     var e = game.spawn_enemy(entry.kind,Vector2(800,400),entry.elite)
     e.state = "move"
     e.hurt(1000000)
    game.director.elapsed = game.director.duration
    game.stage_finished()
    if game.state=="reward":
     reward_total += 1
     check(game.rewards.size()==3,"three options after cleared wave")
     game.choose_reward(0)
     var stacks = game.player.stats.stacks.duplicate()
     game.choose_reward(0)
     check(game.player.stats.stacks==stacks,"reward double click ignored")
     if game.state=="combat":
      # choose_reward has already scheduled the next wave, process that wave here.
      while not game.pending.is_empty():
       var entry: Dictionary = game.pending.pop_front()
       var e = game.spawn_enemy(entry.kind,Vector2(800,400),entry.elite)
       e.state = "move"
       e.hurt(1000000)
      wave_total += 1
      game.director.elapsed = game.director.duration
      game.stage_finished()
      while game.state=="reward":
       reward_total += 1
       game.choose_reward(0)
       if game.state=="combat":
        while not game.pending.is_empty():
         var entry: Dictionary = game.pending.pop_front()
         var e = game.spawn_enemy(entry.kind,Vector2(800,400),entry.elite)
         e.state = "move"
         e.hurt(1000000)
        wave_total += 1
        game.director.elapsed = game.director.duration
        game.stage_finished()
    if game.state=="intermission": game.next_round()
   check(game.won and game.state=="end","chapter complete role %d chapter %d"%[role,chapter])
   check(wave_total==[3,6,12,19][chapter-1],"exact chapter wave count")
   check(reward_total==wave_total-1,"all nonterminal waves reward")
   await frames(2)
 # Secret detour returns to same chapter/round, then advances normally.
 fresh(0,3)
 game.flow.round_number = 3
 game.flow.runes.assign([0,1,2])
 game.wave = game.max_waves()
 game.state = "intermission"
 game.enter_secret()
 check(game.flow.hidden and game.profile.data.achievements.has("secret"),"hidden gate enters")
 for wave_index in range(2):
  if game.wave==0: game.begin_wave()
  while not game.pending.is_empty():
   var entry: Dictionary = game.pending.pop_front()
   var e = game.spawn_enemy(entry.kind,Vector2(800,400),entry.elite)
   e.state = "move"
   e.hurt(1000000)
  game.director.elapsed = game.director.duration
  game.stage_finished()
  if game.state=="reward": game.choose_reward(0)
 check(game.state=="intermission" and not game.flow.hidden and game.flow.secret_done,"secret returns to intermission")
 check(game.profile.data.found.has("hidden_0"),"hidden boss grants role relic")
 game.next_round()
 check(game.flow.round_number==4,"secret exit preserves main chapter progress")
 # Persistence survives death, run buffs do not survive a restart.
 fresh(0)
 game.player.stats.apply(Data.UPGRADES[0])
 game.profile.data.gold += 20
 gold = game.profile.data.gold
 game.end_run(false)
 game.start_run(0,22,1)
 check(game.profile.data.gold==gold and game.player.stats.stacks.is_empty(),"death retains wealth; restart resets buffs")
 # All new bosses execute attack patterns without out-of-range tables.
 for kind in range(4,9):
  fresh(0)
  enemy = target(Vector2(1000,300),kind)
  for i in range(4): enemy.execute_attack()
  check(game.projectiles.size()+game.hazards.size()+game.enemies.size()>0,"boss patterns %d"%kind)
  await frames(3)
 game.back_to_menu()
 await frames(3)
 var result = {"passed":passed,"failures":failures,"drop_samples":drop_samples,"build_damage_benchmark":build_damage}
 f = FileAccess.open("res://tests/results_v2.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "))
 f.close()
 for suffix in ["",".bak",".tmp"]:
  var test_file = "res://tests/profile_test_v2.json"+suffix
  if FileAccess.file_exists(test_file): DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file))
 print("V2_TEST_RESULT "+JSON.stringify(result))
 game.free()
 quit(0 if failures.is_empty() else 1)
