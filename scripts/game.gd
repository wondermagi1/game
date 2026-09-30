extends Node2D
const Data = preload("res://scripts/data.gd")
const Stats = preload("res://scripts/stats.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Effects = preload("res://scripts/effects.gd")
const Sound = preload("res://scripts/sound_v6.gd")
const Interface = preload("res://scripts/interface.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Profile = preload("res://scripts/profile.gd")
const Campaign = preload("res://scripts/campaign.gd")
const WaveDirector = preload("res://scripts/wave_director.gd")
var rooms = preload("res://scripts/room_run.gd").new()
var art
var presentation_fx
var cinematic
var reduced_motion: bool = false
var menu_parallax: bool = true
var skip_boss_intro: bool = true
var bindings = preload("res://scripts/input_bindings.gd").new()
var abyss = preload("res://scripts/abyss_run.gd").new()
var encounter = preload("res://scripts/encounter_rules.gd").new()
var profile = Profile.new()
var flow = Campaign.new()
var director = WaveDirector.new()
var zones: Array = []
var loot: Array = []
var earned_gold: int = 0
var earned_xp: int = 0
var earned_gear: int = 0
var save_clock: float = 0
var notice_clock: float = 0
var notice_text: String = ""
var rune_positions = [Vector2(250,320),Vector2(1630,320),Vector2(950,850)]
@export_range(0.2,1.0,0.1) var effects_intensity: float = 1.0
var ARENA := Rect2(70,160,1780,790)
@export_range(0.0,0.5,0.01) var stage_recovery_ratio: float = 0.15
var state: String = "menu"
var focused: bool = true
var player
var ui
var fx
var sound
var camera: Camera2D
var enemies: Array = []
var projectiles: Array = []
var hazards: Array = []
var pickups: Array = []
var pending: Array = []
var rewards: Array = []
var rng = RandomNumberGenerator.new()
var run_seed: int = 0
var selected_role: int = 0
var stage: int = 1
var wave: int:
	get: return flow.wave
	set(value): flow.wave = value
var spawn_clock: float = 0
var progress_delay: float = 0
var elapsed: float = 0
var kills: int = 0
var dealt: float = 0
var taken: float = 0
var banner: String = ""
var banner_time: float = 0
var shake_strength: float = 0
var screen_shake: bool = true
var show_numbers: bool = true
var won: bool = false
var test_mode: bool = false
const WINDOW_SIZES = [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]
var window_resolution := Vector2i(1920,1080)

func set_window_resolution(value: Vector2i) -> void:
	if not value in WINDOW_SIZES:return
	window_resolution=value
	apply_window_resolution()
	save_settings()

func apply_window_resolution() -> void:
	if DisplayServer.get_name()=="headless":return
	var window=get_window()
	window.mode=Window.MODE_WINDOWED
	window.size=window_resolution
	var desktop=DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position=desktop.position+Vector2i(maxi(0,(desktop.size.x-window_resolution.x)/2),maxi(0,(desktop.size.y-window_resolution.y)/2))

func _ready() -> void:
	get_window().title = "三途试炼 · 合刃同行 " + str(ProjectSettings.get_setting("application/config/version"))
	profile.memory_only = test_mode
	profile.load_profile()
	get_tree().auto_accept_quit = false
	setup_input()
	bindings.apply()
	abyss.game = self
	rooms.game = self
	rng.randomize()
	make_walls()
	camera = Camera2D.new()
	camera.position = Vector2(960,540)
	add_child(camera)
	sound = Sound.new()
	sound.game = self
	add_child(sound)
	fx = Effects.new()
	fx.game = self
	fx.name = "CombatEffects"
	add_child(fx)
	var danger = preload("res://scripts/danger_overlay.gd").new()
	danger.game = self
	add_child(danger)
	art = preload("res://scripts/skill_art.gd").new()
	art.game = self
	add_child(art)
	presentation_fx = preload("res://scripts/presentation_fx.gd").new()
	presentation_fx.game = self
	add_child(presentation_fx)
	cinematic = preload("res://scripts/boss_cinematic.gd").new()
	cinematic.game = self
	add_child(cinematic)
	ui = Interface.new()
	ui.game = self
	ui.name = "Interface"
	add_child(ui)
	load_settings()
	ui.show_menu()
	if not profile.notice.is_empty(): notify_player(profile.notice)

func setup_input() -> void:
	var actions = {"move_left":KEY_A,"move_right":KEY_D,"move_up":KEY_W,"move_down":KEY_S,"dash":KEY_SPACE,"skill":KEY_E,"reload":KEY_R,"skill_2":KEY_Q,"skill_3":KEY_F,"skill_4":KEY_C,"item_1":KEY_1,"item_2":KEY_2,"item_3":KEY_3,"attack":MOUSE_BUTTON_LEFT}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key: InputEvent
			if action=="attack":
				key = InputEventMouseButton.new()
				key.button_index = MOUSE_BUTTON_LEFT
			else:
				key = InputEventKey.new()
				key.physical_keycode = actions[action]
			InputMap.action_add_event(action,key)

func make_walls() -> void:
	rooms.clear_scene()
	rooms.scene = load("res://scenes/rooms/open.tscn").instantiate()
	add_child(rooms.scene)
	move_child(rooms.scene,0)
	rooms.scene.configure([],false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not ui.binding_action.is_empty(): return
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("map") and state=="combat" and rooms.active:
			state = "paused"
			ui.show_world_map()
		if event.keycode == KEY_ESCAPE:
			if state == "combat": pause_game()
			elif state == "paused": resume_game()
		if event.keycode == KEY_TAB and state == "combat": pause_game(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		profile.save_profile()
		get_tree().quit()
		return
	if test_mode: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		if state == "combat" and is_instance_valid(ui): pause_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true

func pause_game(stats_view: bool = false) -> void:
	if state != "combat": return
	state = "paused"
	ui.show_pause(stats_view)

func resume_game() -> void:
	if state != "paused": return
	state = "combat"
	focused = true
	ui.clear_overlay()

func reset_entities() -> void:
	if is_instance_valid(cinematic): cinematic.finish(false)
	if is_instance_valid(presentation_fx): presentation_fx.clear()
	for corpse in get_tree().get_nodes_in_group("visual_corpses"): corpse.queue_free()
	if is_instance_valid(art): art.glyphs.clear()
	director.reset()
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.free()
	enemies.clear()
	for shot in projectiles:
		if is_instance_valid(shot): shot.free()
	projectiles.clear()
	pending.clear()
	hazards.clear()
	pickups.clear()
	loot.clear()
	zones.clear()
	fx.clear()
	if is_instance_valid(player): player.free()
	player = null

func start_run(role: int, seed_value: int = -1, chapter: int = 1) -> void:
	if chapter<1 or chapter>mini(6,int(profile.data.unlocked)): return
	if not profile.data.checkpoint.is_empty() or not profile.data.exploration.is_empty():
		notify_player("请先继续或放弃已保存的探索/深渊存档。",5)
		return
	collect_loot(true)
	reset_entities()
	selected_role = role
	ui.view_role = role
	flow.start(chapter)
	stage = chapter
	run_seed = seed_value if seed_value>=0 else int(Time.get_unix_time_from_system())%2147483647
	rng.seed = run_seed
	elapsed = 0
	kills = 0
	dealt = 0
	taken = 0
	earned_gold = 0
	earned_xp = 0
	earned_gear = 0
	won = false
	player = Player.new()
	player.name = "Player"
	player.game = self
	player.stats = Stats.new(role)
	player.stats.permanent = profile.permanent_bonuses(role)
	add_child(player)
	player.position = Vector2(960,740)
	state = "combat"
	ui.clear_overlay()
	rooms.start(chapter,run_seed)
	profile.save_profile()

func begin_stage() -> void:
	if flow.abyss: rooms.abyss_room(flow.floor_number)
	encounter.reset()
	director.reset()
	wave = 0
	progress_delay = 1.2
	spawn_clock = 0
	pending.clear()
	clear_attacks()
	zones.clear()
	pickups.clear()
	player.stage_reset()
	banner = "%s · 第 %d / %d 回合" % [flow.title(),flow.round_number,flow.rounds()]
	if flow.abyss: banner = flow.title()+ (" · 首领" if flow.floor_number%10==0 else (" · 精英" if flow.floor_number%5==0 else ""))
	banner_time = 3.5
	if stage==1: notify_player(Catalog.CHAPTERS[0].hint,7)
	if stage==3 and flow.round_number==3: notify_player("靠近三枚发光符文，可在整备阶段开启镜渊裂隙。",7)
	queue_redraw()

func max_waves() -> int:
	return flow.waves()

func begin_wave() -> void:
	wave += 1
	spawn_clock = 0.2
	director.start(flow)
	var boss = flow.boss_kind()
	if boss>=0:
		pending.append({"kind":boss,"elite":false})
		banner = Catalog.ENEMIES[boss]
		banner_time = 3
		sound.play("boss")
	else:
		queue_reinforcements(director.tick(0.0,enemies.size()+pending.size()))

func queue_reinforcements(count: int) -> void:
	for i in range(count):
		var kind = 0
		if stage==1:
			if director.groups%3==0 and i==count-1: kind = 2
		else:
			# Rotate rush, ranged support and armoured groups within the same wave.
			var formations: Array = [
				[[0,1,0,2],[0,2,0,1],[3,0,1,0]],
				[[0,1,2,0],[3,2,0,1],[1,0,2,3]],
				[[1,2,0,3],[3,2,1,0],[1,3,2,0]],
				[[9,0,1,3],[10,2,0,1],[9,3,1,2]],
				[[11,1,0,10],[9,2,10,0],[11,3,1,0]]
			][stage-2]
			var lineup: Array = formations[director.groups%3]
			kind = int(lineup[(i+wave)%lineup.size()])
		if kind==2:
			var ranged_count = 0
			for enemy in enemies:
				if enemy.kind==2: ranged_count += 1
			for queued in pending:
				if queued.kind==2: ranged_count += 1
			if ranged_count>=int(Catalog.DIFFICULTY[stage-1].ranged): kind = 0
		var elite = i==count-1 and director.take_elite()
		if flow.abyss and flow.floor_number%5==0 and director.groups==1 and i==0: elite = true
		pending.append({"kind":kind,"elite":elite})

func _physics_process(delta: float) -> void:
	if state!="combat": return
	elapsed += delta
	encounter.tick(self,delta)
	banner_time = maxf(0,banner_time-delta)
	process_hazards(delta)
	process_pickups(delta)
	process_zones(delta)
	process_loot(delta)
	if not rooms.active and stage==3 and flow.round_number==3 and not flow.hidden and not flow.secret_done:
		for i in range(3):
			if not flow.runes.has(i) and player.global_position.distance_to(rune_positions[i])<65:
				flow.runes.append(i)
				fx.sigils(rune_positions[i],65,Color("#b6a1ff"),2)
				notify_player("符文已唤醒 %d / 3"%flow.runes.size())
	if state!="combat": return
	if rooms.active:
		rooms.tick(delta)
		queue_redraw()
		return
	if progress_delay>0:
		progress_delay -= delta
		return
	if wave>0:
		queue_reinforcements(director.tick(delta,enemies.size()+pending.size()))
	if pending.size()>0:
		spawn_clock -= delta
		if spawn_clock<=0 and enemies.size()<Catalog.ENEMY_LIMIT:
			var item: Dictionary = pending.pop_front()
			spawn_enemy(item.kind,random_spawn(),item.elite)
			spawn_clock = Catalog.SPAWN_INTERVAL
	elif enemies.is_empty():
		if wave==0: begin_wave()
		else: stage_finished()
	queue_redraw()

func _process(delta: float) -> void:
	save_clock += delta
	notice_clock = maxf(0,notice_clock-delta)
	if save_clock>=3:
		save_clock = 0
		if profile.dirty: profile.save_profile()
	shake_strength = move_toward(shake_strength,0,delta*24)
	camera.offset = Vector2(sin(Time.get_ticks_msec()*0.09),cos(Time.get_ticks_msec()*0.071))*shake_strength if screen_shake and not reduced_motion and state=="combat" else Vector2.ZERO
	if state != "combat": queue_redraw()

func safe_position(pos: Vector2) -> Vector2:
	if is_instance_valid(rooms.scene): return rooms.scene.to_global(rooms.scene.safe(rooms.scene.to_local(pos)))
	return Vector2(clampf(pos.x,ARENA.position.x+45,ARENA.end.x-45),clampf(pos.y,ARENA.position.y+45,ARENA.end.y-45))

func random_spawn() -> Vector2:
	var pos = ARENA.get_center()
	for i in range(40):
		pos = safe_position(Vector2(rng.randf_range(ARENA.position.x+80,ARENA.end.x-80),rng.randf_range(ARENA.position.y+80,ARENA.end.y-80)))
		if pos.distance_to(player.global_position)>450: return pos
	return pos

func spawn_enemy(kind: int, pos: Vector2, is_elite: bool = false):
	if enemies.size()>=Catalog.ENEMY_LIMIT: return null
	var enemy = preload("res://scripts/lulu_boss.gd").new() if kind==14 else Enemy.new()
	enemy.game = self
	enemy.kind = kind
	enemy.elite = is_elite
	enemy.position = safe_position(pos)
	enemy.name = "Enemy_"+str(kind)
	add_child(enemy)
	enemies.append(enemy)
	if enemy.is_boss(): cinematic.start.call_deferred(enemy)
	return enemy

func spawn_projectile(pos: Vector2, dir: Vector2, properties: Dictionary):
	if projectiles.size()>=450:
		# At visual saturation, merge friendly output instead of silently dropping growth.
		if not properties.get("enemy_shot",false):
			for candidate in projectiles:
				if not candidate.enemy_shot and not candidate.gone and candidate.source==properties.get("source","normal"):
					candidate.damage = minf(1e15,candidate.damage+float(properties.get("damage",0)))
					return candidate
		return null
	var shot = Projectile.new()
	shot.game = self
	var muzzle_blocked=false
	if not properties.get("enemy_shot",false) and is_instance_valid(player) and pos.distance_to(player.global_position)<100:
		var ray=PhysicsRayQueryParameters2D.create(player.global_position,pos,1)
		var wall=get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():pos=wall.position-dir.normalized()*1.5;muzzle_blocked=true
	shot.position = pos
	shot.direction = dir
	shot.rotation = dir.angle()
	for property in properties: shot.set(property,properties[property])
	if not shot.enemy_shot and is_instance_valid(player) and pos.distance_to(player.global_position)<100:
		shot.launch_offset=player.global_position+player.visual.muzzle_local()-pos
		if muzzle_blocked:shot.launch_offset=shot.height_offset
	add_child(shot)
	projectiles.append(shot)
	return shot

func nearest_enemy(pos: Vector2, excluded: Array, radius: float):
	var closest = null
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or excluded.has(enemy.get_rid()): continue
		var d: float = pos.distance_to(enemy.global_position)
		if d < radius:
			radius = d
			closest = enemy
	return closest

func explode(pos: Vector2, radius: float, amount: float, apply_status: bool = true) -> void:
	if is_instance_valid(player): presentation_fx.emit("explosion",pos,Vector2.UP,player.stats.role,clampf(radius/65,1,4))
	if is_instance_valid(rooms.scene): rooms.scene.damage_cover(pos,radius,amount)
	fx.ring(pos,radius,Color("#fac883"))
	fx.burst(pos,Color("#fac883"),20)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.global_position.distance_to(pos) < radius:
			enemy.hurt(amount,false,apply_status)

func clear_attacks() -> void:
	if is_instance_valid(presentation_fx): presentation_fx.clear()
	for shot in projectiles:
		if is_instance_valid(shot):
			shot.gone = true
			shot.queue_free()
	projectiles.clear()
	hazards.clear()

func clear_enemy_attacks() -> void:
	for shot in projectiles.duplicate():
		if is_instance_valid(shot) and shot.enemy_shot:
			shot.gone = true
			projectiles.erase(shot)
			shot.queue_free()
	hazards.clear()

func add_hazard(pos: Vector2, radius: float, delay: float, amount: float) -> void:
	hazards.append({"p":safe_position(pos),"radius":radius,"t":delay,"max":delay,"damage":amount})

func process_hazards(delta: float) -> void:
	for h in hazards.duplicate():
		h.t -= delta
		if h.t <= 0:
			hazards.erase(h)
			fx.ring(h.p,h.radius,Color("#ff7089"))
			if player.global_position.distance_to(h.p) < h.radius+20:
				player.hurt(h.damage)

func drop_heal(pos: Vector2, amount: float) -> void:
	pickups.append({"p":pos,"heal":amount,"life":25.0})

func process_pickups(delta: float) -> void:
	for drop in pickups.duplicate():
		drop.life -= delta
		if drop.life <= 0:
			pickups.erase(drop)
			continue
		var distance: float = drop.p.distance_to(player.global_position)
		if player.hp < player.stats.value("hp") and distance < 70+player.stats.bonus("pickup"):
			drop.p = drop.p.move_toward(player.global_position,delta*600)
			if distance < 30:
				player.heal(drop.heal)
				pickups.erase(drop)

func stage_finished() -> void:
	if rooms.active: return
	if state!="combat" or not pending.is_empty() or not enemies.is_empty(): return
	if director.receiving(): return
	clear_attacks()
	zones.clear()
	collect_loot(true)
	if flow.abyss:
		abyss.cleared()
		return
	if flow.final_wave():
		if flow.hidden:
			flow.hidden = false
			flow.secret_done = true
			wave = max_waves()
			state = "intermission"
			profile.data.secret = true
			profile.dirty = true
			ensure_shop()
			profile.save_profile()
			ui.show_intermission()
		else: end_run(true)
		return
	state = "reward"
	rewards = roll_rewards(rng,wave>=max_waves(),false)
	sound.play("reward")
	ui.show_rewards(rewards)

func choose_reward(index: int) -> void:
	if state!="reward" or index<0 or index>=rewards.size(): return
	var choice: Array = rewards[index]
	if choice[3]=="evolution":
		if not player.skills.apply_evolution(choice[0]): return
	elif choice[3]=="gold":
		profile.data.gold += int(choice[4])
		profile.dirty = true
	else:
		var previous: int = int(player.stats.stacks.get(choice[0],0))
		var layers = rooms.reward_layers if rooms.active else 1
		for layer in range(layers):
			if player.stats.abyss or int(player.stats.stacks.get(choice[0],0))<int(choice[5]): player.stats.apply(choice)
		if flow.abyss and previous+1 in [5,10,20,40]: profile.events.append({"title":"Buff 进阶 · "+choice[1],"text":"已达 %d 层 · 新机制生效"%(previous+1)})
		profile.discover("buff_"+choice[0])
	if choice[3]=="heal": player.heal(player.stats.value("hp")*float(choice[4]))
	if choice[3]=="hp": player.heal(float(choice[4]))
	rewards.clear()
	if rooms.active:
		rooms.after_reward()
		profile.save_profile()
		return
	if flow.abyss:
		abyss.after_reward()
		profile.save_profile()
		return
	if wave>=max_waves():
		state = "intermission"
		ensure_shop()
		ui.show_intermission()
	else:
		state = "combat"
		ui.clear_overlay()
		progress_delay = 0.65
		begin_wave()
	profile.save_profile()

func roll_rewards(source_rng: RandomNumberGenerator, round_end: bool = false, force_evolution: bool = false) -> Array:
	var base = player.stats.reward_choices(source_rng,player.hp,round_end)
	return player.skills.enhance_rewards(base,source_rng,force_evolution)

func reroll_rewards() -> void:
	if state!="reward" or not is_instance_valid(player) or player.skills.rerolls<=0: return
	player.skills.rerolls -= 1
	var source_rng: RandomNumberGenerator = rooms.reward_rng if rooms.active else rng
	var force = rooms.active and rooms.current().kind in ["elite","secret"]
	rewards = roll_rewards(source_rng,true,force)
	ui.show_rewards(rewards)
	sound.play("ui_confirm")

func end_run(victory: bool) -> void:
	if state!="combat": return
	collect_loot(true)
	won = victory
	if victory:player.visual.play_gesture("victory",1.8)
	state = "end"
	pending.clear()
	clear_attacks()
	zones.clear()
	if victory and flow.capybara:
		profile.data.gold += 150
		earned_gold += 150
		add_xp(350)
		profile.dirty = true
	elif victory:
		var reward = 240+stage*120
		profile.data.gold += reward
		earned_gold += reward
		add_xp(400+stage*220)
		if not profile.data.cleared.has(stage):
			profile.data.cleared.append(stage)
			if stage==1: receive_gear(profile.make_item(selected_role,1,1,1,rng))
		profile.data.unlocked = maxi(int(profile.data.unlocked),mini(6,stage+1))
		if stage==1: profile.unlock("chapter1")
		if stage==4: profile.unlock("chapter4")
		if stage==6: profile.unlock("chapter6")
		profile.dirty = true
	profile.save_profile()
	sound.play("win" if victory else "lose")
	ui.show_end(victory)

func back_to_menu() -> void:
	collect_loot(true)
	state = "menu"
	rooms.stop()
	camera.position = Vector2(960,540)
	reset_entities()
	profile.save_profile()
	ui.show_menu()

func save_settings() -> void:
	if test_mode: return
	var config = ConfigFile.new()
	bindings.save_config(config)
	config.set_value("settings","master",sound.master_volume)
	config.set_value("settings","volume",sound.volume)
	config.set_value("settings","shake",screen_shake)
	config.set_value("settings","numbers",show_numbers)
	config.set_value("settings","effects",effects_intensity)
	config.set_value("display","resolution",window_resolution)
	for key in ["reduced_motion","menu_parallax","skip_boss_intro"]: config.set_value("presentation",key,get(key))
	config.set_value("presentation","seen_bosses",cinematic.seen)
	config.save("user://settings.cfg")

func load_settings() -> void:
	if test_mode:return
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		bindings.load_config(config)
		sound.master_volume = config.get_value("settings","master",1.0)
		sound.volume = config.get_value("settings","volume",0.35)
		screen_shake = config.get_value("settings","shake",true)
		show_numbers = config.get_value("settings","numbers",true)
		effects_intensity = clampf(float(config.get_value("settings","effects",1.0)),0.2,1.0)
		for key in ["reduced_motion","menu_parallax","skip_boss_intro"]: set(key,bool(config.get_value("presentation",key,get(key))))
		var seen_value = config.get_value("presentation","seen_bosses",{})
		if seen_value is Dictionary: cinematic.seen = seen_value
		var saved_resolution=config.get_value("display","resolution",Vector2i(1920,1080))
		if saved_resolution is Vector2i and saved_resolution in WINDOW_SIZES:window_resolution=saved_resolution
	apply_window_resolution()

func _draw() -> void:
	for h in hazards:
		draw_circle(h.p,h.radius,Color(1,0.2,0.35,0.13))
		draw_arc(h.p,h.radius,0,TAU,48,Color("#ff8194"),3,true)
		draw_circle(h.p,h.radius*(1.0-h.t/h.max),Color(1,0.3,0.4,0.14))
	for drop in pickups:
		draw_circle(drop.p,12,Color("#345e51"))
		draw_line(drop.p-Vector2(6,0),drop.p+Vector2(6,0),Color("#a2f0b7"),4)
		draw_line(drop.p-Vector2(0,6),drop.p+Vector2(0,6),Color("#a2f0b7"),4)

	for zone in zones:
		var color = Color("#efbb6f") if zone.kind=="powder" else Color("#92d5ee")
		draw_circle(zone.p,zone.r,Color(color,0.06))
		draw_arc(zone.p,zone.r,0,TAU,48,Color(color,0.5),2,true)
	for drop in loot:
		var col = Color("#e7c980")
		if not drop.gear.is_empty():
			col = Color(Catalog.COLORS[int(drop.gear.quality)])
			draw_line(drop.p,drop.p-Vector2(0,65),Color(col,0.45),6)
			draw_arc(drop.p,18,0,TAU,20,col,2,true)
		draw_circle(drop.p,8,col)
		draw_colored_polygon(PackedVector2Array([drop.p+Vector2(13,-9),drop.p+Vector2(19,0),drop.p+Vector2(13,9),drop.p+Vector2(7,0)]),Color("#83c8f7"))

func notify_player(text: String, duration: float = 3.0) -> void:
	notice_text = text
	notice_clock = duration

func refresh_stats() -> void:
	if is_instance_valid(player):
		var item: Dictionary = profile.item_by_id(profile.data.roles[selected_role].equipped.get("0",""))
		player.visual.quality = int(item.get("quality",0))
	if not is_instance_valid(player): return
	player.stats.permanent = profile.permanent_bonuses(selected_role)
	player.hp = minf(player.hp,player.stats.value("hp"))
	player.ammo = mini(player.ammo,player.magazine_size())

func ensure_shop() -> void:
	if rooms.active:
		if rooms.current().stock.is_empty(): rooms.current().stock = profile.make_shop(selected_role,stage,rooms.reward_rng)
		flow.stock = rooms.current().stock
		return
	if flow.stock.is_empty(): flow.stock = profile.make_shop(selected_role,stage,rng)

func next_round() -> void:
	if rooms.active and state=="intermission":
		state = "combat"
		ui.clear_overlay()
		return
	if state!="intermission" or flow.hidden: return
	if flow.abyss:
		abyss.next_floor()
		return
	flow.round_number += 1
	flow.stock.clear()
	state = "combat"
	ui.clear_overlay()
	begin_stage()

func enter_secret() -> void:
	if state!="intermission" or not flow.can_secret(): return
	flow.hidden = true
	wave = 0
	state = "combat"
	profile.unlock("secret")
	profile.discover("hidden_gate")
	profile.save_profile()
	player.stage_reset()
	ui.clear_overlay()
	progress_delay = 1
	banner = "镜渊裂隙 · 额外试炼"
	banner_time = 3

func add_xp(amount: int) -> void:
	earned_xp += amount
	var levels = profile.gain_xp(selected_role,amount)
	if levels>0 and is_instance_valid(player):
		refresh_stats()
		sound.play("reward")
		fx.sigils(player.global_position,95,Color("#f0d492"),3)
		notify_player("等级提升至 Lv.%d · 可在整备时分配天赋"%int(profile.data.roles[selected_role].level),4)

func receive_gear(item: Dictionary) -> void:
	if profile.receive_item(item):
		earned_gear += 1
		notify_player("获得 %s · %s"%[Catalog.QUALITIES[int(item.quality)],profile.item_name(item)])

func enemy_defeated(enemy) -> void:
	var tier = 3 if enemy.kind==8 else (2 if enemy.is_boss() else (1 if enemy.elite else 0))
	profile.discover("enemy_%d"%enemy.kind)
	if tier>=2: profile.unlock("boss")
	var gold = (8+stage*3) * [1,3,14,20][tier]
	var xp = (12+stage*7) * [1,3,10,16][tier]
	if enemy.fragment: gold = 0; xp = 0
	var material = [0,2,8,12][tier]
	if tier==0 and rng.randf()<0.04: material = 1
	if enemy.fragment: material = 0
	if material>0:
		profile.data.material += material
		profile.discover("material")
		notify_player("强化材料 +%d"%material)
	loot.append({"p":safe_position(enemy.global_position),"gold":gold,"xp":xp,"gear":{} if enemy.fragment else profile.roll_equipment(tier,selected_role,stage,rng)})
	if tier==2 and rng.randf()<0.35:
		var extra = profile.make_item(selected_role,rng.randi_range(0,5),2 if stage>=3 else 1,mini(int(profile.data.roles[selected_role].level),int(Catalog.CHAPTERS[stage-1].level)),rng)
		loot.append({"p":safe_position(enemy.global_position+Vector2(30,0)),"gold":0,"xp":0,"gear":extra})
	if loot.size()>120: collect_drop(loot.front())

func collect_drop(drop: Dictionary) -> void:
	if not loot.has(drop): return
	loot.erase(drop)
	profile.data.gold += int(drop.gold)
	profile.dirty = true
	earned_gold += int(drop.gold)
	add_xp(int(drop.xp))
	if not drop.gear.is_empty(): receive_gear(drop.gear)
	sound.play("hit")

func collect_loot(all_drops: bool = false) -> void:
	if not all_drops: return
	for drop in loot.duplicate(): collect_drop(drop)

func process_loot(delta: float) -> void:
	for drop in loot.duplicate():
		var distance: float = drop.p.distance_to(player.global_position)
		if distance<110+player.stats.bonus("pickup")+(600 if player.magnet_time>0 else 0):
			drop.p = drop.p.move_toward(player.global_position,delta*650)
			if distance<30: collect_drop(drop)

func add_zone(pos: Vector2, radius: float, delay: float, interval: float, amount: float, kind: String, hits: int) -> void:
	if zones.size()>=40: return
	zones.append({"p":pos,"r":radius,"t":delay,"interval":interval,"damage":amount,"kind":kind,"hits":hits})

func process_zones(delta: float) -> void:
	for zone in zones.duplicate():
		zone.t -= delta
		if zone.t<=0:
			if zone.kind!="powder":
				explode(zone.p,zone.r,zone.damage,false)
				fx.sigils(zone.p,zone.r,player.stats.base.color,2)
			zone.hits -= 1
			zone.t = zone.interval
			if zone.hits<=0: zones.erase(zone)

func in_zone(pos: Vector2, kind: String) -> bool:
	for zone in zones:
		if zone.kind==kind and pos.distance_to(zone.p)<zone.r: return true
	return false

func consume_powder(pos: Vector2) -> bool:
	for zone in zones:
		if zone.kind=="powder" and pos.distance_to(zone.p)<zone.r:
			zones.erase(zone)
			return true
	return false
