extends RefCounted
const C = preload("res://scripts/catalog.gd")
const V7 = preload("res://scripts/v7_catalog.gd")
var actor
var game
var cooldowns: Array[float] = [0,0,0,0]
var rapid_time: float = 0
var rapid_tick: float = 0
var tactical_time: float = 0
var combo_cd: float = 0
var legendary_cd: float = 0
var set_cd: float = 0
var attacks: int = 0
var empowered_shots: int = 0
var temporary: Array = [0,0,0,0]
var combo_count: int = 0
var windows: Array[float] = [0,0,0,0]
var ultimate = preload("res://scripts/ultimate_controller.gd").new()
var evolutions: Dictionary = {}
var rerolls: int = 2
var reward_count: int = 0
var heat: float = 0.0

func rank(slot: int) -> int:
	return mini(10,int(game.profile.data.roles[actor.stats.role].skills[slot])+int(temporary[slot]))

func unlocked(slot: int) -> bool:
	return int(game.profile.data.roles[actor.stats.role].level)>=C.SKILL_LEVELS[slot]

func reset() -> void:
	ultimate.active = false
	windows = [0,0,0,0]
	cooldowns = [0,0,0,0]
	rapid_time = 0
	tactical_time = 0
	empowered_shots = 0
	combo_cd = 0
	legendary_cd = 0
	set_cd = 0
	heat = 0

func branch(slot: int) -> int:
	return int(evolutions.get(str(slot),{}).get("branch",-1))

func tier(slot: int) -> int:
	return int(evolutions.get(str(slot),{}).get("tier",0))

func dominant_branch() -> int:
	var counts = [0,0,0]
	for slot in range(4):
		var selected = branch(slot)
		if selected>=0: counts[selected] += tier(slot)
	var best = -1
	for i in range(3):
		if counts[i]>0 and (best<0 or counts[i]>counts[best]): best = i
	return best

func build_name() -> String:
	var selected = dominant_branch()
	return "未定流派" if selected<0 else V7.BUILD_NAMES[actor.stats.role][selected]

func build_tags() -> Array:
	var result: Array = []
	for slot in range(4):
		var selected = branch(slot)
		if selected<0: continue
		for tag in V7.BUILD_TAGS[actor.stats.role][selected]:
			if not result.has(tag): result.append(tag)
	return result

func evolution_choices(rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	var role = actor.stats.role
	for slot in range(4):
		if not unlocked(slot): continue
		var selected = branch(slot)
		if selected<0:
			for branch_index in range(3): pool.append(V7.choice(role,slot,branch_index,1))
		elif tier(slot)<3:
			pool.append(V7.choice(role,slot,selected,tier(slot)+1))
	var result: Array = []
	while not pool.is_empty() and result.size()<3:
		var index = rng.randi_range(0,pool.size()-1)
		result.append(pool.pop_at(index))
	return result

func enhance_rewards(base_choices: Array, rng: RandomNumberGenerator, force: bool = false) -> Array:
	reward_count += 1
	var choices = base_choices.duplicate(true)
	var evolution_pool = evolution_choices(rng)
	if not evolution_pool.is_empty() and (force or reward_count%2==1):
		choices[0] = evolution_pool[0]
		# Elite/secret/Boss rewards show a second compatible evolution when possible.
		if force and evolution_pool.size()>1: choices[1] = evolution_pool[1]
	return choices

func apply_evolution(id: String) -> bool:
	var parsed = V7.parse_id(id)
	if parsed.is_empty() or int(parsed.role)!=actor.stats.role: return false
	var key = str(int(parsed.slot))
	var current: Dictionary = evolutions.get(key,{})
	if current.is_empty():
		if int(parsed.tier)!=1: return false
		evolutions[key] = {"branch":int(parsed.branch),"tier":1}
	elif int(current.branch)==int(parsed.branch) and int(parsed.tier)==int(current.tier)+1 and int(parsed.tier)<=3:
		current.tier = int(parsed.tier)
		evolutions[key] = current
	else: return false
	game.profile.discover(id)
	game.profile.events.append({"title":"技能进化 · "+build_name(),"text":V7.branch(actor.stats.role,int(parsed.slot),int(parsed.branch))[3]+" %d阶"%int(parsed.tier)})
	game.fx.sigils(actor.global_position,110+int(parsed.tier)*20,actor.stats.base.color,3)
	game.sound.play("reward")
	return true

func normal_multiplier() -> float:
	if actor.stats.role==1 and dominant_branch()==0: return 1.0+heat*0.0035
	if actor.stats.role==1 and dominant_branch()==2: return 1.0+0.08*maxi(0,tier(2))
	return 1.0

func decorate_normal(properties: Dictionary) -> Dictionary:
	var role = actor.stats.role
	var selected = dominant_branch()
	if role==0 and selected==2:
		properties.can_return = true
		properties.pierce = int(properties.get("pierce",1))+maxi(1,tier(0))
	elif role==1 and selected==1 and bool(properties.get("empowered",false)):
		properties.explosion = 65.0+30.0*maxi(1,tier(2))
	elif role==2 and selected==0:
		properties.bounce = int(properties.get("bounce",0))+maxi(1,tier(1))
	elif role==2 and selected==1:
		properties.body_length = 75.0+25.0*maxi(1,tier(0))
		properties.hit_width = 8.0+4.0*maxi(1,tier(0))
	elif role==2 and selected==2:
		properties.bounce = int(properties.get("bounce",0))+2
	return properties

func tick(delta: float) -> void:
	for i in range(4): cooldowns[i] = maxf(0,cooldowns[i]-delta)
	tactical_time = maxf(0,tactical_time-delta)
	combo_cd = maxf(0,combo_cd-delta)
	legendary_cd = maxf(0,legendary_cd-delta)
	set_cd = maxf(0,set_cd-delta)
	for i in range(4): windows[i] = maxf(0,windows[i]-delta)
	ultimate.tick(delta)
	rapid_time = maxf(0,ultimate.duration-ultimate.elapsed) if ultimate.active and actor.stats.role==2 else 0
	if actor.stats.role==1:
		heat = maxf(0,heat-delta*(7.0 if tactical_time>0 else 13.0))

func shot(dir: Vector2, factor: float, pierce: int = 1, source: String = "skill", extra: Dictionary = {}) -> void:
	var properties = {"damage":actor.stats.value("attack")*factor,"speed":1250.0,"remaining":1000.0,"pierce":pierce,"style":actor.stats.role,"tint":actor.stats.base.color,"source":source}
	properties.merge(extra,true)
	game.spawn_projectile(actor.global_position+dir*33,dir,properties)

func use(slot: int) -> bool:
	if game.state!="combat" or actor.dead or not unlocked(slot) or cooldowns[slot]>0: return false
	var role: int = actor.stats.role
	var level = rank(slot)
	actor.visual.aim = actor.aim
	actor.visual.play_gesture("ultimate_gather" if slot==3 else "skill_%d"%slot,.6 if slot==3 else .45)
	cooldowns[slot] = C.SKILLS[role][slot].cd*(1-minf(0.8,actor.stats.bonus("cooldown")))
	if role==0 and slot==2 and actor.stats.bonus("hidden_relic")>0: cooldowns[slot] *= 0.85
	game.presentation_fx.emit("cast",actor.global_position+actor.visual.muzzle_local(),actor.aim,actor.stats.role,1.5)
	actor.visual.action = 0.4
	actor.visual.casting = true
	game.sound.play("skill")
	game.fx.sigils(actor.global_position,60,actor.stats.base.color,1)
	if level>=5 and slot not in [1,3]: game.fx.ring(actor.global_position,90,actor.stats.base.color)
	var center: Vector2 = game.safe_position(actor.global_position+actor.aim*400)
	windows[slot] = 8
	ultimate.skills = self
	if slot==3:
		ultimate.start(center)
		game.profile.discover("skill_%d_%d" % [role,slot])
		return true
	ultimate.link(slot)
	match role:
		0:
			match slot:
				0:
					actor.orbit_time = minf(12,3.0+(level-1)+actor.stats.bonus("orbit"))
					actor.orbit_tick = 0
					if level>=3:
						for i in range(5): shot(actor.aim.rotated((i-2)*0.2),0.5,3)
				1:
					shot(actor.aim,2.8+level*0.5,10,"cloud",{"body_length":220.0+(30 if level>=10 else 0),"hit_width":24.0+(8 if level>=3 else 0),"speed":1450.0,"remaining":1400.0})
					game.art.emit("gather",actor.global_position,actor.aim,55,0.2,0)
					game.sound.play("giant_sword")
					if level>=5:
						for side in [-1,1]: shot(actor.aim.rotated(side*0.15),1.0,5,"cloud_guard",{"body_length":130.0,"hit_width":14.0})
				2:
					actor.dash(actor.aim)
					actor.dash_time = 0.28
					if level>=5: game.add_zone(center,130,0.5,0.2,actor.stats.value("attack"),"blade",2)
					actor.invulnerable = maxf(actor.invulnerable,0.35)
					for i in range(3): game.add_zone(game.safe_position(actor.global_position+actor.aim*(55+i*70)),65,0.15+i*0.12,0.3,(0.6+0.2*level)*actor.stats.value("attack"),"blade",1)
					if actor.orbit_time>0:
						game.explode(actor.global_position,240,actor.stats.value("attack")*1.8,false)
						combo(actor.global_position,"回锋剑潮")
				3: game.add_zone(center,170+(20 if level>=3 else 0),0.6,0.4,actor.stats.value("attack")*0.65,"swords",3+level)
		1:
			match slot:
				0: shot(actor.aim,2.1+level*0.4,1,"bomb",{"speed":660.0,"explosion":160.0+actor.stats.bonus("blast")+10*(level-1),"powder":true})
				1:
					for i in range(mini(9,4+level)): shot(actor.aim.rotated((i-(mini(9,4+level)-1)*0.5)*0.15),0.45+0.05*maxi(0,level-5),2 if level>=5 else 1,"shotgun",{"remaining":460.0})
				2:
					actor.reload_time = 0
					actor.ammo = actor.magazine_size()
					actor.first_round = true
					empowered_shots = 3+(1 if level>=5 else 0)+(2 if level>=8 else 0)
					tactical_time = 4+level+(2 if actor.stats.bonus("hidden_relic")>0 else 0)
					if level>=3: actor.barrier = maxf(actor.barrier,30); actor.barrier_time = 5
				3:
					rapid_time = minf(8,2+level)
					rapid_tick = 0
		2:
			match slot:
				0:
					shot(actor.aim,3.0+level*0.65,12,"sun",{"body_length":230.0,"hit_width":24.0,"speed":1500.0,"remaining":1500.0})
					game.presentation_fx.emit("shot",actor.global_position+actor.visual.muzzle_local(),actor.aim,2,1.5)
					game.sound.play("giant_arrow")
				1: game.add_zone(center,170+(20 if level>=3 else 0),0.6,0.4,actor.stats.value("attack")*0.5,"arrows",3+level)
				2:
					var radius = 210+(50 if level>=5 else 0)+(70 if actor.stats.bonus("hidden_relic")>0 else 0)
					for enemy in game.enemies:
						if enemy.global_position.distance_to(center)<radius: enemy.mark_time = 6+level+(2 if actor.stats.bonus("set_count")>=4 else 0)
					game.fx.sigils(center,radius,Color("#b7eb9a"),level)
				3:
					rapid_time = minf(8,2+level)
					rapid_tick = 0
	apply_v7_skill(role,slot,center)
	# Milestones add mechanics without increasing per-frame work without bound.
	if level>=5 and slot in [0,3]:
		game.add_zone(center,140,0.6,0.45,actor.stats.value("attack")*0.45,"echo",2)
	if level>=8:
		actor.barrier = maxf(actor.barrier,actor.stats.value("hp")*0.08)
		actor.barrier_time = maxf(actor.barrier_time,4)
	if level>=10:
		for i in range(4):
			if i!=slot: cooldowns[i] = maxf(0,cooldowns[i]-0.75)
	game.profile.discover("skill_%d_%d" % [role,slot])
	return true

func apply_v7_skill(role: int, slot: int, center: Vector2) -> void:
	var selected = branch(slot)
	var level = tier(slot)
	if selected<0 or level<=0: return
	var attack = actor.stats.value("attack")
	match role:
		0:
			if selected==0:
				for i in range(2+level): shot(actor.aim.rotated((i-(1+level)*0.5)*0.22),0.35+level*0.12,3,"v7_array")
				game.add_zone(actor.global_position,155+level*25,0.25,0.35,attack*(0.25+level*0.12),"v7_array",2+level)
			elif selected==1:
				shot(actor.aim,1.8+level*0.8,12,"v7_greatsword",{"body_length":230.0+level*65,"hit_width":30.0+level*9,"speed":1050.0,"remaining":1450.0})
				game.shake_strength = maxf(game.shake_strength,(2+level)*game.effects_intensity)
			else:
				for side in [-1,1]: shot(actor.aim.rotated(side*0.16),0.8+level*0.25,6,"v7_return",{"can_return":true,"remaining":900.0})
		1:
			if selected==0:
				heat = minf(100,heat+15+level*7)
				game.add_zone(center,125+level*22,0.25,0.5,attack*(0.3+level*0.15),"v7_fire",2+level)
			elif selected==1:
				game.explode(center,135+level*45,attack*(0.75+level*0.45),true)
				game.art.emit("blast",center,actor.aim,120+level*55,0.45,1)
			else:
				for enemy in game.enemies:
					if is_instance_valid(enemy) and enemy.global_position.distance_to(center)<220+level*45:
						enemy.hunt_stacks = mini(3,enemy.hunt_stacks+level)
						enemy.powder_mark = maxf(enemy.powder_mark,7)
		2:
			if selected==0:
				game.add_zone(center,190+level*35,0.3,0.55,attack*(0.35+level*0.18),"v7_storm",3+level*2)
			elif selected==1:
				shot(actor.aim,2.2+level,16,"v7_giant_arrow",{"body_length":260.0+level*85,"hit_width":32.0+level*12,"speed":1350.0,"remaining":1700.0})
				game.shake_strength = maxf(game.shake_strength,(2+level)*game.effects_intensity)
			else:
				for side in [-1,1]:
					var trap = game.safe_position(center+actor.aim.orthogonal()*side*(75+level*20))
					game.add_zone(trap,85+level*15,0.7,0.35,attack*(0.45+level*0.18),"v7_trap",2+level)
	if slot==3 and level>=2:
		game.presentation_fx.emit("ultimate",center,actor.aim,role,2+level)
		game.fx.burst(center,actor.stats.base.color,24+level*10)

func combo(pos: Vector2, title: String) -> void:
	combo_count += 1
	actor.visual.play_gesture("combo",.45)
	game.profile.unlock("combo")
	game.fx.combo_burst(pos,actor.stats.role,title)
	game.sound.play(["combo_sword","combo_gun","combo_bow"][actor.stats.role])
	game.shake_strength = maxf(game.shake_strength,3.0*game.effects_intensity)

func on_attack() -> void:
	attacks += 1
	if actor.stats.role==1 and dominant_branch()==0:
		heat = minf(110,heat+5+maxi(0,tier(0)))
		if heat>=100:
			heat = 68
			actor.reload_time = maxf(actor.reload_time,0.55)
			game.explode(actor.global_position,115,actor.stats.value("attack")*0.8,false)
			game.fx.caption(actor.global_position-Vector2(65,85),"泄压爆燃",Color("#ffb06a"))
	if actor.stats.role==0 and actor.stats.bonus("set_count")>=6 and actor.orbit_time>0 and attacks%4==0:
		for i in range(3): shot(actor.aim.rotated((i-1)*0.24),0.6,2,"set")

func on_hit(enemy, projectile) -> void:
	if not is_instance_valid(enemy): return
	var attack: float = actor.stats.value("attack")
	var role: int = actor.stats.role
	if role==1 and dominant_branch()==2:
		enemy.hunt_stacks = mini(3,enemy.hunt_stacks+1)
		if enemy.hunt_stacks>=3:
			enemy.hunt_stacks = 0
			game.explode(enemy.global_position,95+20*maxi(1,tier(0)),attack*(0.6+0.25*maxi(1,tier(0))),false)
			combo(enemy.global_position,"弱点处决")
	if role==0 and dominant_branch()==2 and projectile.returning:
		game.player.skills.cooldowns[2] = maxf(0,game.player.skills.cooldowns[2]-0.12*maxi(1,tier(2)))
	if projectile.source=="cloud":
		if rank(1)>=8 and enemy.sword_mark>0: game.explode(enemy.global_position,180,attack*0.8,false)
		enemy.sword_mark = 8
		if not enemy.is_boss(): enemy.knockback += projectile.direction*170
	if projectile.source=="shotgun": enemy.powder_mark = 8
	if projectile.source=="normal" and role==0 and enemy.sword_mark>0 and combo_cd<=0:
		enemy.sword_mark = 0
		combo_cd = 0.2
		game.explode(enemy.global_position,130,attack*2.4,false)
		combo(enemy.global_position,"穿云追剑")
	if projectile.source in ["rapid","normal"] and role==1 and enemy.powder_mark>0 and combo_cd<=0:
		enemy.powder_mark = 0
		combo_cd = 0.2
		game.explode(enemy.global_position,140,attack*1.1,false)
		combo(enemy.global_position,"霰幕连爆")
	if projectile.source=="sun" and enemy.mark_time>0:
		enemy.mark_time = 0
		game.explode(enemy.global_position,170,attack*2.4,false)
		combo(enemy.global_position,"猎日星坠")
	if projectile.source=="normal" and role==2 and game.in_zone(enemy.global_position,"arrows") and projectile.bounce==0:
		projectile.bounce = 2
		projectile.damage *= 1.25
		if combo_cd<=0:
			combo_cd = 0.3
			combo(enemy.global_position,"风雨追猎")
	if projectile.source!="normal": return
	if role==1 and projectile.empowered and combo_cd<=0 and (enemy.blast_mark>0 or game.consume_powder(enemy.global_position)):
		combo_cd = 0.3
		enemy.blast_mark = 0
		game.consume_powder(enemy.global_position)
		game.explode(enemy.global_position,220,attack*2.0,false)
		combo(enemy.global_position,"爆燃装填")
	if actor.stats.bonus("legend_weapon")>0 and legendary_cd<=0:
		if role==0 and projectile.returning:
			legendary_cd = 1
			shot(actor.global_position.direction_to(enemy.global_position),0.45,2,"legend")
		if role==1 and projectile.empowered:
			legendary_cd = 1
			game.explode(enemy.global_position,100,attack*0.6,false)
		if role==2 and enemy.mark_time>0:
			legendary_cd = 1
			projectile.bounce += 1
	if actor.stats.bonus("set_count")>=6 and set_cd<=0:
		if role==1 and projectile.empowered:
			set_cd = 1
			game.explode(enemy.global_position,100,attack*0.65,false)
		if role==2 and enemy.mark_time>0:
			set_cd = 1
			shot(actor.global_position.direction_to(enemy.global_position),0.7,1,"set")
