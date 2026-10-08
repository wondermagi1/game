extends SceneTree
var game
var results: Array = []
var only_chapter: int = 0
var only_role: int = -1
var build: String = "recommended"
var navigation_goal := Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func configure(chapter: int, role: int) -> Dictionary:
	var fixture = preload("res://tests/build_fixture.gd").configure(game,chapter,role,build)
	# Spend additional V4 points through the same player-facing upgrade service.
	var focus = 3 if chapter>=4 else (1 if role==0 and chapter>=2 else 0)
	for n in range(9): game.profile.train_skill(role,focus)
	for slot in range(4):
		for n in range(3): game.profile.train_skill(role,slot)
	fixture.fixture_skill_ranks = game.profile.data.roles[role].skills.duplicate()
	fixture.fixture_talent_points = game.profile.data.roles[role].spent
	return fixture
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter="): only_chapter = int(arg.split("=")[1])
		if arg.begins_with("--role="): only_role = int(arg.split("=")[1])
		if arg.begins_with("--build="): build = arg.split("=")[1]
	game.sound.volume = 0
	game.show_numbers = false
	for chapter in range(1,7):
		if only_chapter>0 and chapter!=only_chapter: continue
		for role in range(3):
			if only_role>=0 and role!=only_role: continue
			var fixture = configure(chapter,role)
			game.start_run(role,34180+chapter*20+role,chapter)
			game.player.manual_control = true
			var frames = 0
			var peak = 0
			var boss_seconds: float = 0
			var start_material: int = game.profile.data.material
			var start_items: int = game.profile.data.inventory.size()
			var inventory_before: Dictionary = {}
			for item in game.profile.data.inventory: inventory_before[item.uid]=true
			while game.state!="end" and frames<45000:
				frames += 1
				peak = maxi(peak,game.enemies.size())
				if game.state=="reward":
					var choice = 0
					var best = -1
					for i in range(game.rewards.size()):
						var u: Array = game.rewards[i]
						var score = 6 if u[3] in ["attack_pct","attack","multishot","burn","poison"] else 1
						if u[3] in ["heal","hp","kill_heal"] and game.player.hp<game.player.stats.value("hp")*0.5: score = 9
						if score>best: best=score; choice=i
					game.choose_reward(choice)
				elif game.state=="event": game.rooms.choose_event(0)
				elif game.state=="first_clear": game.rooms.claim_first_clear(0)
				elif game.state=="intermission": game.next_round()
				elif game.state=="combat":
					if game.rooms.current().kind=="boss": boss_seconds += 1.0/60
					pilot(frames)
				await physics_frame
			var quality = [0,0,0,0]
			var own = 0
			for item in game.profile.data.inventory:
				if inventory_before.has(item.uid): continue
				quality[item.quality]+=1
				if item.role==role: own+=1
			var record = {"chapter":chapter,"role":role,"build":build,"won":game.won,"timeout":frames>=45000,"seconds":snappedf(game.elapsed,0.1),"boss_seconds":snappedf(boss_seconds,0.1),"kills":game.kills,"hp":snappedf(game.player.hp,0.1),"damage_taken":snappedf(game.taken,0.1),"gold":game.earned_gold,"xp":game.earned_xp,"materials":int(game.profile.data.material)-start_material,"equipment":game.earned_gear,"qualities":quality,"own_role":own,"room_count":game.rooms.data.rooms.size(),"peak_enemies":peak,"final_room":game.rooms.data.current,"combo_count":game.player.skills.combo_count}
			record.merge(fixture)
			if frames>=45000:
				var remaining: Array = []
				for enemy in game.enemies:
					if is_instance_valid(enemy): remaining.append({"kind":enemy.kind,"p":str(enemy.global_position),"hp":enemy.hp,"state":enemy.state})
				record["timeout_diagnostics"]={"player":str(game.player.global_position),"movement":str(game.player.scripted_movement),"enemies":remaining,"state":game.state}
			results.append(record)
			var f = FileAccess.open("res://tests/autoplay_v4_%s_%d_%d.json"%[build,only_chapter,only_role],FileAccess.WRITE)
			f.store_string(JSON.stringify(results,"  ")); f.close()
			print("V4_PLAYTHROUGH="+JSON.stringify(record))
	await process_frame
	await process_frame
	game.free()
	quit()
func pilot(frame: int) -> void:
	var p = game.player
	var r: Dictionary = game.rooms.current()
	var nearest = game.nearest_enemy(p.global_position,[],2200)
	var move = Vector2.ZERO
	if is_instance_valid(nearest):
		var distance: float = p.position.distance_to(nearest.position)
		var toward: Vector2 = p.position.direction_to(nearest.position)
		p.aim = toward
		var query = PhysicsRayQueryParameters2D.create(p.position,nearest.position,1)
		var obstructed = not p.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
		if obstructed:
			move = game.rooms.scene.navigate(p.position,nearest.position)
		else:
			var preferred = minf(p.stats.value("range")*0.7,450)
			if distance>preferred: move+=toward
			elif distance<preferred*0.7: move-=toward
			move += toward.orthogonal()*0.6
			p.attack()
			if distance<650:
				for slot in [2,0,1]: p.use_skill(slot)
				if nearest.is_boss() or nearest.elite or game.enemies.size()>=4: p.use_skill(3)
		for enemy in game.enemies:
			if p.position.distance_to(enemy.position)<120: move+=enemy.position.direction_to(p.position)*2
		for h in game.hazards:
			if p.position.distance_to(h.p)<h.radius+60: move += h.p.direction_to(p.position)*3
		for shot in game.projectiles:
			if shot.enemy_shot and shot.position.distance_to(p.position)<110: move += shot.direction.orthogonal()*1.2
		if distance<110: p.dash(move.normalized())
	elif r.cleared:
		var local_pos: Vector2 = p.position-game.rooms.origin()
		if r.id=="r2" and game.rooms.data.rooms.has("secret") and not game.rooms.data.revealed:
			var point: Vector2 = game.rooms.origin()+Vector2(960,245)
			move = walk_to(point)
			if p.position.distance_to(point)<85: game.rooms.interact()
		elif not r.event.is_empty() and not r.used:
			var point: Vector2 = game.rooms.origin()+game.rooms.scene.event_position()
			move = walk_to(point)
			if p.position.distance_to(point)<115: game.rooms.interact()
		else:
			var next = next_room()
			if not next.is_empty():
				var n: Dictionary = game.rooms.data.rooms[next]
				var dir = Vector2(n.grid[0]-r.grid[0],n.grid[1]-r.grid[1])
				var point: Vector2 = game.rooms.origin()+game.rooms.scene.portal(dir)-dir*35
				move = walk_to(point)
	elif game.rooms.waves_done==0:
		move = walk_to(game.rooms.scene.to_global(game.rooms.scene.event_position()))
	if p.hp<p.stats.value("hp")*0.45: p.use_item(0); p.use_item(1)
	var local: Vector2 = p.position-game.rooms.origin()
	if not r.cleared:
		var bounds: Rect2 = game.rooms.scene.arena_rect().grow(-70)
		if local.x<bounds.position.x: move.x+=2
		if local.x>bounds.end.x: move.x-=2
		if local.y<bounds.position.y: move.y+=2
		if local.y>bounds.end.y: move.y-=2
	p.scripted_movement = move.normalized()
func walk_to(point: Vector2) -> Vector2:
	if game.player.position.distance_to(point)<120: return game.player.position.direction_to(point)
	return game.rooms.scene.navigate(game.player.position,point)
func next_room() -> String:
	var map: Dictionary = game.rooms.data
	var queue: Array = [[map.current,""]]
	var seen: Array = [map.current]
	var boss_path: String = ""
	while not queue.is_empty():
		var step = queue.pop_front()
		var room: Dictionary = map.rooms[step[0]]
		if step[0]!=map.current and not room.visited:
			if room.kind!="boss": return step[1]
			boss_path = step[1]
		for next in room.neighbors:
			if next=="secret" and not map.revealed: continue
			if not seen.has(next): seen.append(next); queue.append([next,next if step[1].is_empty() else step[1]])
	return boss_path
