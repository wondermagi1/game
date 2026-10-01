extends RefCounted
## One finite state machine per actor. Cosmetic rain never creates damage objects.
var skills
var active: bool = false
var elapsed: float = 0
var duration: float = 0
var next_tick: float = 0
var ticks: int = 0
var limit: int = 0
var role: int = 0
var rank: int = 1
var center := Vector2.ZERO
var empowered: bool = false
var linked: bool = false
var secondary: bool = false
var total_budget: float = 0
func start(point: Vector2) -> void:
	role = skills.actor.stats.role
	rank = skills.rank(3)
	active = true
	elapsed = 0
	next_tick = 0.35
	ticks = 0
	linked = false
	secondary = false
	center = point
	limit = (8+floori((rank-1)*4.0/9)) if role==0 else ((24+rank*2) if role==1 else (10+rank))
	duration = 3.35 if role==0 else (4.35+(rank-1)*0.15)
	empowered = (skills.windows[1]>0 if role==0 else (skills.tactical_time>0 if role==1 else skills.windows[2]>0))
	var game = skills.game
	var actor = skills.actor
	# Sword and bow benefit from orbiting physical weapons. The gunner keeps the
	# accepted firearm silhouette and uses heat/smoke instead of floating bars.
	if role!=1:
		game.art.emit("gather",actor.global_position,actor.aim,100,0.5,role)
		game.art.emit("gather",center,actor.aim,radius(),0.6,role)
	game.art.emit(["sword_halo","gun_heat","bow_constellation"][role],actor.global_position,actor.aim,190,1.05,role)
	game.presentation_fx.emit("v8_gather",actor.global_position+actor.visual.muzzle_local(),actor.aim,role,2.4)
	game.sound.play("ultimate_%d_start"%role)
	game.fx.caption(actor.global_position-Vector2(80,100),["万剑归宗","炼狱火力","群星逐猎"][role],game.art.PALETTE[role])
	if role==2:
		for enemy in game.enemies:
			if not enemy.dead: enemy.mark_time = maxf(enemy.mark_time,6)
	if empowered:
		skills.combo(center,["穿云归宗","炼狱装填","群星狩猎"][role])
	if role==0 and actor.orbit_time>0:
		secondary = true
		skills.combo(center,"剑阵共鸣")
	if role==2 and skills.windows[1]>0:
		game.add_zone(center,280,0.35,0.8,actor.stats.value("attack")*0.8,"storm",5)
		skills.combo(center,"风暴箭域")
	# Exact sword single-target base budget, excluding explicit combo bonuses.
	total_budget = (2.5+(rank-1)/6.0)+limit*(1+(rank-1)/15.0)+(6.5+(rank-1)*3.5/9.0)
func radius() -> float:
	return 230+(35 if rank>=3 else 0)+(30 if rank>=10 else 0)
func target():
	var best = null
	var score: float = INF
	for enemy in skills.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var distance: float = enemy.global_position.distance_to(skills.actor.global_position)
		if distance>1400: continue
		var weight = distance-(500 if enemy.is_boss() else (200 if enemy.elite else 0))
		if enemy.mark_time>0 or enemy.sword_mark>0: weight -= 600
		if weight<score: score = weight; best = enemy
	return best
func tick(delta: float) -> void:
	if not active: return
	var game = skills.game
	var actor = skills.actor
	elapsed += delta
	if elapsed>.6 and actor.visual.clip not in ["ultimate_sustain","combo","dash","hurt"]: actor.visual.play_gesture("ultimate_sustain",duration)
	if elapsed>=next_tick and ticks<limit:
		next_tick += (duration-0.35)/limit
		var enemy = target()
		if ticks==0:
			if is_instance_valid(enemy): center = game.safe_position(enemy.global_position)
			if role==0: strike(2.5+(rank-1)/6.0,"gather")
		if role==0:
			if rank>=3 and is_instance_valid(enemy): center = game.safe_position(center.move_toward(enemy.global_position,55))
			strike(1+(rank-1)/15.0,"fall")
		elif is_instance_valid(enemy):
			center = enemy.global_position
			var dir: Vector2 = actor.global_position.direction_to(center)
			actor.visual.aim=dir
			var factor = (0.65+0.035*rank) if role==1 else (0.85+0.045*rank)
			if empowered: factor *= 1.25
			skills.shot(dir,factor,3 if rank>=5 else 2,"rapid",{"body_length":75.0 if role==1 else 110.0,"hit_width":9.0,"speed":1500.0,"remaining":1600.0})
			actor.visual.aim=dir
			if role==1:
				game.art.emit("muzzle",actor.global_position+actor.visual.muzzle_local(),dir,85,.13,role)
			else:
				game.presentation_fx.emit("shot",actor.global_position+actor.visual.muzzle_local(),dir,role,1.6)
			game.sound.play("ultimate_%d_loop"%role)
			if rank>=5 and ticks%4==0: skills.shot(dir.rotated(0.12),factor*0.5,2,"guardian",{"body_length":65.0,"hit_width":7.0})
		if ticks%maxi(1,limit/6)==0:
			game.presentation_fx.emit("v8_sustain",center,actor.aim,role,1.5+rank*.06)
		ticks += 1
	if elapsed>=duration+0.15: finish()
func strike(factor: float, kind: String) -> void:
	var game = skills.game
	var actor = skills.actor
	game.explode(center,radius(),actor.stats.value("attack")*factor,false)
	if secondary and kind=="fall": game.explode(actor.global_position,180,actor.stats.value("attack")*0.25,false)
	if kind=="fall":
		for i in range(3 if game.effects_intensity>=0.5 else 1):
			var offset = Vector2.from_angle((ticks*3+i)*2.4)*(45+i*55)
			game.art.emit("fall",center+offset,Vector2.DOWN,135+(rank*4),0.35,0)
		game.sound.play("ultimate_0_loop")
		game.presentation_fx.emit("v8_impact",center,Vector2.DOWN,0,1.5+rank*.08)
		for enemy in game.enemies:
			if not enemy.is_boss() and enemy.global_position.distance_to(center)<radius(): enemy.slow_time = maxf(enemy.slow_time,0.4)
func finish() -> void:
	if not active: return
	active = false
	var game = skills.game
	var actor = skills.actor
	var enemy = target()
	actor.visual.play_gesture("ultimate_finish",.55)
	if is_instance_valid(enemy): center = game.safe_position(enemy.global_position)
	var factor = (6.5+(rank-1)*3.5/9.0) if role==0 else (5+rank*0.35)
	if empowered: factor *= 1.35
	game.explode(center,radius()+60,actor.stats.value("attack")*factor,false)
	game.art.emit("finish" if role!=1 else "blast",center,actor.aim,460 if rank>=10 else (370 if rank>=8 else 310),0.7,role)
	game.fx.burst(center,game.art.PALETTE[role],60)
	game.presentation_fx.emit("ultimate",center,actor.aim,role,4)
	game.presentation_fx.emit("v8_finish",center,actor.aim,role,3.4+rank*.12)
	game.art.emit("residue",center,actor.aim,radius()+70,1.1,role)
	game.sound.play("ultimate_%d_finish"%role)
	game.shake_strength = 6*game.effects_intensity
	if rank>=5 and role==0:
		game.art.emit("slash",center,Vector2.RIGHT,300,0.45,role)
	if rank>=10:
		# Distinct awakening payoff: a short, finite lingering field, not recursion.
		game.add_zone(center,260,0.7,0.7,actor.stats.value("attack")*0.6,"awakening",3)
func link(slot: int) -> void:
	if not active or linked: return
	var game = skills.game
	var actor = skills.actor
	if role==0 and slot==2:
		linked = true
		center = game.safe_position(actor.global_position+actor.aim*220)
		game.explode(center,300,actor.stats.value("attack")*3,false)
		game.art.emit("slash",center,actor.aim,330,0.65,0)
		skills.combo(center,"归宗回锋")
	elif role==2 and slot==0:
		linked = true
		skills.shot(actor.aim,4.5,16,"sun_finish",{"body_length":320.0,"hit_width":28.0,"speed":1500.0,"remaining":1500.0})
		skills.combo(actor.global_position,"逐日终结")
