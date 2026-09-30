extends CharacterBody2D
const Visual = preload("res://scripts/actor_visual.gd")
const V7 = preload("res://scripts/v7_catalog.gd")
var blast_mark: float = 0
var ward: float = 0
var fragment: bool = false
var primary_death: bool = false
var slow_time: float = 0
var mark_time: float = 0
var sword_mark: float = 0
var powder_mark: float = 0
var game
var kind: int = 0
var elite: bool = false
var hp: float = 40.0
var max_hp: float = 40.0
var armor: float = 0.0
var speed: float = 120.0
var damage: float = 10.0
var radius: float = 24.0
var state: String = "spawn"
var timer: float = 0.8
var cooldown: float = 0.6
var locked_dir = Vector2.DOWN
var knockback = Vector2.ZERO
var visual
var dead: bool = false
var burn_time: float = 0.0
var poison_time: float = 0.0
var poison_stacks: int = 0
var dot_clock: float = 0.5
var burn_damage: float = 0.0
var poison_damage: float = 0.0
var pattern: int = 0
var second_phase: bool = false
var navigation_clock: float = 0
var navigation_direction := Vector2.ZERO
var elite_modifiers: Array[String] = []
var modifier_clock: float = 0.0
var drain_clock: float = 0.0
var hunt_stacks: int = 0
var summoned_copy: bool = false

func is_boss() -> bool:
	return kind in [4,5,6,7,8,12,13,14]

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var hp_table = [34.0,48.0,32.0,90.0,980.0,1800.0,420.0,700.0,1600.0,54.0,38.0,42.0,1600.0,1750.0,1150.0,46.0,58.0,42.0,64.0]
	var difficulty: Dictionary = game.Catalog.DIFFICULTY[game.stage-1]
	max_hp = hp_table[kind]*0.73*difficulty.hp*(1.0+(game.flow.round_number-1)*difficulty.round_growth)
	if is_boss(): max_hp *= game.Catalog.PACING[game.stage-1].boss_hp
	if elite: max_hp *= 1.8
	if game.flow.abyss: max_hp *= game.abyss.scaling().hp
	hp = max_hp
	radius = 43.0 if is_boss() else 23.0
	speed = [142.0,125.0,110.0,80.0,96.0,75.0,80.0,85.0,68.0,85.0,150.0,95.0,74.0,90.0,76.0,92.0,108.0,165.0,82.0][kind]
	speed *= difficulty.speed
	if elite:
		var modifier_count = 2 if game.flow.abyss and game.flow.floor_number>=20 else 1
		var modifier_pool = V7.ELITE_MODIFIERS.duplicate(true)
		for i in range(modifier_count):
			var selected: Dictionary = modifier_pool.pop_at(game.rng.randi_range(0,modifier_pool.size()-1))
			elite_modifiers.append(selected.id)
		if elite_modifiers.has("swift"): speed *= 1.42
		else: speed *= 1.12
	armor = 18 if kind in [3,4] else 0
	if elite_modifiers.has("armored"):
		armor += 24
		ward = max_hp*0.28
	damage = ([10.0,14.0,10.0,18.0,20.0,18.0,10.0,14.0,20.0,9.0,11.0,12.0,21.0,23.0,9.0,8.0,9.0,16.0,9.0][kind]+1.0)*difficulty.damage*0.83
	if game.flow.abyss: damage *= game.abyss.scaling().damage
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	visual = Visual.new()
	visual.kind = kind+3 if kind>=9 else mini(kind+3,8)
	visual.tint = [Color("#d78383"),Color("#dd9865"),Color("#b486d0"),Color("#8795bb"),Color("#deae74"),Color("#ed6e92"),Color("#7ed8b5"),Color("#e8b66d"),Color("#b799f2"),Color("#7dbbdc"),Color("#b6d56e"),Color("#c091ea"),Color("#e3a25c"),Color("#8d9fff"),Color("#d7bf96"),Color("#ffe08a"),Color("#9ddf9a"),Color("#f2a36e"),Color("#b8d8f0")][kind]
	visual.enemy_id = kind
	visual.elite = elite
	add_child(visual)
	z_index = 4
	cooldown = game.rng.randf_range(0.3,1.0)
	modifier_clock = game.rng.randf_range(3.5,6.5)

func _physics_process(delta: float) -> void:
	if game.state != "combat" or dead: return
	if state == "spawn":
		timer -= delta
		visual.modulate.a = 0.5
		if timer <= 0:
			state = "move"
			visual.modulate.a = 1
		queue_redraw()
		return
	blast_mark = maxf(0,blast_mark-delta)
	slow_time = maxf(0,slow_time-delta)
	mark_time = maxf(0,mark_time-delta)
	sword_mark = maxf(0,sword_mark-delta)
	powder_mark = maxf(0,powder_mark-delta)
	drain_clock = maxf(0,drain_clock-delta)
	burn_time = maxf(0,burn_time-delta)
	poison_time = maxf(0,poison_time-delta)
	if poison_time <= 0: poison_stacks = 0
	dot_clock -= delta
	if dot_clock <= 0:
		dot_clock = 0.5
		if burn_time > 0: hurt(burn_damage*0.5,false,false)
		if poison_time > 0: hurt(poison_damage*poison_stacks*0.5,false,false)
		if dead: return
	var to_player: Vector2 = game.player.global_position-global_position
	var distance: float = to_player.length()
	visual.aim = to_player.normalized()
	cooldown -= delta
	velocity = Vector2.ZERO
	if kind in [4,5,8,12,13,14] and not second_phase and hp <= max_hp*0.5:
		second_phase = true
		if kind==14: visual.lulu_play("phase",1.4)
		state = "recover"
		timer = 1.4
		game.clear_enemy_attacks()
		game.banner = game.Catalog.ENEMIES[kind]+" · 第二阶段"
		game.banner_time = 2.0
		game.fx.ring(global_position,180,Color("#f9a0b9"))
	if state == "windup":
		timer -= delta
		if timer <= 0: execute_attack()
	elif state == "charge":
		timer -= delta
		velocity = locked_dir*(640.0 if kind == 1 else 740.0)
		if distance < radius+28: hit_player(damage)
		if timer <= 0 or is_on_wall():
			state = "recover"
			timer = 0.6
	elif state == "recover":
		timer -= delta
		if timer <= 0: state = "move"
	else:
		var desire = to_player.normalized()
		navigation_clock -= delta
		if is_instance_valid(game.rooms.scene) and distance>100:
			if navigation_clock<=0:
				navigation_clock=0.16
				var line = PhysicsRayQueryParameters2D.create(global_position,game.player.global_position,1)
				navigation_direction = desire if get_world_2d().direct_space_state.intersect_ray(line).is_empty() else game.rooms.scene.navigate(global_position,game.player.global_position)
			desire = navigation_direction
		if kind in [2,9,11,15,16,18]:
			if distance < 340: desire *= -1
			elif distance < 560: desire *= 0.0
		if kind == 5 and distance < 420: desire *= 0.0
		if kind in [0,3,10,17] and distance < 55+radius: desire *= 0.0
		var separation = Vector2.ZERO
		for other in game.enemies:
			if other == self or not is_instance_valid(other): continue
			var diff: Vector2 = global_position-other.global_position
			var d = diff.length()
			if d > 0.1 and d < radius+other.radius+8:
				separation += diff/d*60
		velocity = desire*speed+separation
		var can_attack = cooldown <= 0
		if can_attack and ((kind in [0,3,10,17] and distance < radius+85) or (kind in [1,2,9,11,15,16,18] and distance < 720) or is_boss()):
			locked_dir = to_player.normalized()
			state = "windup"
			timer = 0.75 if kind != 0 else 0.4
			if is_boss(): timer = 0.85
	if slow_time>0: velocity *= 0.75 if is_boss() else 0.45
	modifier_tick(delta)
	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO,delta*700)
	move_and_slide()
	visual.walking = minf(velocity.length()/120,1)
	if state=="windup":
		visual.casting = true
		visual.action = .15
	queue_redraw()

func execute_attack() -> void:
	state = "recover"
	timer = 0.45
	cooldown = 1.5
	match kind:
		0,3,10:
			if global_position.distance_to(game.player.global_position) < radius+75:
				hit_player(damage)
			game.fx.ring(global_position,radius+50,Color("#ec8b80"))
		1:
			state = "charge"
			timer = 0.6
			cooldown = 2.1
		2:
			shoot(locked_dir,310,damage)
			cooldown = 2.6
		9:
			for ally in game.enemies:
				if ally!=self and ally.global_position.distance_to(global_position)<250: ally.ward = maxf(ally.ward,minf(45 if ally.is_boss() else 65,ally.max_hp*0.10))
			game.fx.ring(global_position,250,Color("#7dbbdc"))
			cooldown = 8
		11:
			game.add_hazard(game.player.global_position,80,1.3,damage)
			cooldown = 3.2
		15:
			for ally in game.enemies:
				if ally!=self and is_instance_valid(ally) and ally.global_position.distance_to(global_position)<280:
					ally.hp = minf(ally.max_hp,ally.hp+ally.max_hp*0.08)
					ally.ward = maxf(ally.ward,ally.max_hp*0.08)
			game.fx.ring(global_position,280,Color("#ffe08a"))
			cooldown = 6.5
		16:
			game.add_hazard(game.player.global_position,105,1.0,damage*0.55)
			game.player.slow_time = maxf(game.player.slow_time,2.5)
			game.fx.sigils(game.player.global_position,105,Color("#9ddf9a"),2)
			cooldown = 4.5
		17:
			game.fx.ring(global_position,125,Color("#ffad72"))
			if global_position.distance_to(game.player.global_position)<145: hit_player(damage*1.8)
			for other in game.enemies:
				if other!=self and is_instance_valid(other) and other.global_position.distance_to(global_position)<125: other.hurt(damage*1.5,false,false)
			hp = 0
			die()
		18:
			if game.enemies.size()<10:
				for i in range(2):
					var child = game.spawn_enemy(0,game.safe_position(global_position+Vector2(75*(i*2-1),65)),false)
					if is_instance_valid(child):
						child.summoned_copy = true
						child.hp *= 0.55
						child.max_hp = child.hp
			game.fx.sigils(global_position,100,Color("#b8d8f0"),2)
			cooldown = 7.0
		12:
			var gap = pattern%5
			for i in range(5):
				if i!=gap: game.add_hazard(Vector2(game.ARENA.position.x+230+i*310,game.player.global_position.y),95,1.6,damage)
			if pattern%4==0 and game.enemies.size()<5: game.spawn_enemy(9,game.safe_position(global_position+Vector2(130,80)))
			if second_phase:
				for i in range(6): shoot(locked_dir.rotated((i-2.5)*0.2),250,damage)
			pattern += 1
			cooldown = 2.6
		13:
			for i in range(16):
				if (i+pattern)%8 in [0,1,2]: continue
				shoot(Vector2.from_angle(i*TAU/16+pattern*0.12),250,damage)
			game.add_hazard(game.player.global_position,90,1.6,damage)
			if second_phase and pattern%4==0 and game.enemies.size()<5: game.spawn_enemy(11,game.random_spawn())
			pattern += 1
			cooldown = 2.6 if second_phase else 3.2
		4:
			match pattern % 3:
				0:
					state = "charge"
					timer = 0.65
				1:
					for i in range(7): shoot(locked_dir.rotated((i-3)*0.18),290,damage)
				2:
					if game.enemies.size() < 5:
						for i in range(2):
							game.spawn_enemy(i%2,game.safe_position(global_position+Vector2.from_angle(i*TAU/3)*130),false)
			pattern += 1
			cooldown = 1.4 if second_phase else 1.8
		5:
			match pattern % 3:
				0:
					# 留出安全间隙，二阶段改变角度而非粗暴翻倍弹速。
					for i in range(16):
						if i in [2,3,10,11]: continue
						shoot(Vector2.from_angle(i*TAU/16 + (0.18 if second_phase else 0.0)),240,damage)
				1:
					for i in range(9): shoot(locked_dir.rotated((i-4)*0.16),300,damage)
				2:
					game.add_hazard(game.player.global_position,95,1.0,damage*1.2)
					if second_phase:
						game.add_hazard(game.safe_position(game.player.global_position+Vector2(150,0)),80,1.3,damage)
						game.add_hazard(game.safe_position(game.player.global_position-Vector2(150,0)),80,1.3,damage)
			pattern += 1
			cooldown = 1.3 if second_phase else 1.8

		6:
			if pattern%2==0:
				state = "charge"
				timer = 0.38
			else:
				for i in range(3): shoot(locked_dir.rotated((i-1)*0.3),230,damage)
			pattern += 1
			cooldown = 2.4
		7:
			if pattern%3==2 and game.enemies.size()<5:
				for i in range(2): game.spawn_enemy(i,game.safe_position(global_position+Vector2(100*(i*2-1),80)),false)
			else:
				for i in range(5): shoot(locked_dir.rotated((i-2)*0.24),270,damage)
			pattern += 1
			cooldown = 2.6
		8:
			if pattern%2==0:
				for i in range(18):
					if (i+pattern)%9 in [0,1,2]: continue
					shoot(Vector2.from_angle(i*TAU/18+pattern*0.17),240,damage)
			else:
				var center: Vector2 = game.player.global_position
				game.add_hazard(center,105,1.15,damage)
				game.add_hazard(game.safe_position(center+locked_dir*150),85,1.6,damage)
				if second_phase: game.add_hazard(game.safe_position(center-locked_dir*150),70,1.8,damage)
			pattern += 1
			cooldown = 1.4 if second_phase else 1.9

func shoot(dir: Vector2, shot_speed: float, amount: float) -> void:
	game.spawn_projectile(global_position+dir*(radius+12),dir,{"enemy_shot":true,"damage":amount,"speed":shot_speed,"remaining":1700.0})

func hit_player(amount: float) -> void:
	game.player.hurt(amount)
	if elite_modifiers.has("draining") and drain_clock<=0:
		drain_clock = 5.0
		for i in range(game.player.skills.cooldowns.size()): game.player.skills.cooldowns[i] += 0.55
		game.fx.caption(game.player.global_position-Vector2(55,85),"吸能",Color("#c99bea"))

func modifier_tick(delta: float) -> void:
	if elite_modifiers.is_empty() or dead: return
	modifier_clock -= delta
	if modifier_clock>0: return
	modifier_clock = 6.5
	if elite_modifiers.has("commander"):
		for ally in game.enemies:
			if ally!=self and is_instance_valid(ally) and not ally.is_boss() and ally.global_position.distance_to(global_position)<300:
				ally.ward = maxf(ally.ward,ally.max_hp*0.06)
		game.fx.ring(global_position,300,Color("#e1c16b"))
	if elite_modifiers.has("mirror") and game.enemies.size()<12:
		var copy = game.spawn_enemy(kind,game.safe_position(global_position+Vector2(75,35)),false)
		if is_instance_valid(copy):
			copy.summoned_copy = true
			copy.hp *= 0.25
			copy.max_hp = copy.hp
			copy.scale = Vector2.ONE*0.72
			copy.visual.modulate.a = 0.55

func hurt(raw: float, critical: bool = false, apply_status: bool = true, source: String = "skill") -> void:
	if dead or state == "spawn" or game.state != "combat": return
	var amount = clampf(raw*100.0/(100.0+armor),1.0,1.0e15)
	var absorbed = minf(ward,amount)
	ward -= absorbed
	amount -= absorbed
	hp -= amount
	game.dealt += minf(amount,maxf(0,hp+amount))
	game.telemetry.record_damage(minf(amount,maxf(0,hp+amount)),"status" if not apply_status else source,critical)
	game.fx.number(global_position,amount,Color("#ffe0a4") if critical else Color("#e7f1fa"),critical)
	visual.flash = 0.09
	if apply_status:
		knockback = game.player.global_position.direction_to(global_position)*(45 if is_boss() else 120)
		var stats = game.player.stats
		if stats.bonus("burn")>0:
			burn_time = 3
			burn_damage = stats.value("attack")*(0.18+(minf(0.6,maxf(0,stats.raw_bonus("burn")-1)*0.02) if stats.abyss else 0))
		if stats.bonus("poison")>0:
			poison_time = 4
			poison_stacks = mini(3,poison_stacks+1)
			poison_damage = stats.value("attack")*(0.12+(minf(0.4,maxf(0,stats.raw_bonus("poison")-1)*0.015) if stats.abyss else 0))
		if critical: game.sound.play("crit")
	if hp<=0:
		primary_death = apply_status
		die()

func die() -> void:
	if dead: return
	dead = true
	collision_layer = 0
	game.kills += 1
	game.enemy_defeated(self)
	game.player.on_kill()
	game.fx.burst(global_position,visual.tint,18 if is_boss() else 8)
	game.sound.play("hit")
	if elite_modifiers.has("volatile"):
		game.add_hazard(global_position,125,0.85,damage*1.25)
		game.explode(global_position,125,damage*0.8,false)
	var corpse = preload("res://scripts/actor_visual.gd").new()
	corpse.kind = visual.kind
	corpse.enemy_id = kind
	corpse.tint = visual.tint
	corpse.aim = visual.aim
	corpse.position = global_position
	corpse.dying = true
	corpse.add_to_group("visual_corpses")
	game.add_child(corpse)
	var fade = corpse.create_tween()
	fade.tween_interval(.65)
	fade.tween_callback(corpse.queue_free)
	game.presentation_fx.emit("death",global_position,Vector2.UP,game.selected_role,2 if is_boss() else 1)
	if is_boss():
		game.art.emit("blast",global_position,Vector2.UP,210,.65,game.selected_role)
		game.sound.play("boss_finish")
	game.enemies.erase(self)
	if primary_death and game.player.stats.abyss and burn_time>0 and game.player.stats.raw_bonus("burn")>=5 and game.player.status_proc_clock<=0:
		game.player.status_proc_clock = 1
		game.explode(global_position,140,game.player.stats.value("attack")*0.8,false)
		game.fx.combo_burst(global_position,1,"")
	if kind==10 and not fragment:
		for i in range(2):
			var child = game.spawn_enemy(10,game.safe_position(global_position+Vector2(45*(i*2-1),0)))
			if is_instance_valid(child):
				child.fragment = true
				child.scale = Vector2.ONE*0.6
				child.hp *= 0.25
				child.max_hp = child.hp
	if is_boss():
		game.clear_enemy_attacks()
		for other in game.enemies.duplicate():
			if is_instance_valid(other):
				game.enemies.erase(other)
				other.queue_free()
	if not summoned_copy and (elite or is_boss() or game.rng.randf() < 0.13):
		game.drop_heal(global_position,18 if elite else 10)
	queue_free()

func _draw() -> void:
	if state == "spawn":
		draw_arc(Vector2.ZERO,45+timer*20,0,TAU,40,Color(1,0.4,0.5,0.6),3,true)
		return
	if state == "windup":
		if kind in [1,4,6]:
			draw_line(Vector2.ZERO,locked_dir*440,Color(1,0.3,0.4,0.30),24,true)
			draw_line(Vector2.ZERO,locked_dir*440,Color("#ff8e87"),2,true)
		else:
			draw_arc(Vector2.ZERO,radius+15,0,TAU,40,Color("#ff9b88"),4,true)
	if hp < max_hp and not is_boss():
		draw_rect(Rect2(-28,-59,56,5),Color("#291e2c"))
		draw_rect(Rect2(-28,-59,56*maxf(0,hp/max_hp),5),Color("#ee909b"))
	if burn_time > 0: draw_circle(Vector2(-12,-68),5,Color("#ffb563"))
	if poison_time > 0: draw_circle(Vector2(10,-68),5,Color("#a6ed80"))

	if ward>0: draw_arc(Vector2.ZERO,radius+8,0,TAU,6,Color("#7dbbdc"),4,true)
	if blast_mark>0:
		draw_arc(Vector2.ZERO,radius+12,0,TAU*blast_mark/6,32,Color("#ffb45b"),4,true)
		draw_circle(Vector2(0,-radius-14),7,Color("#ffb45b"))
	if mark_time>0:
		draw_arc(Vector2.ZERO,radius+10,0,TAU,4,Color("#c5ed99"),3,true)
	if slow_time>0: draw_arc(Vector2.ZERO,radius+5,0,TAU,24,Color("#8cd3ff"),2,true)
	if sword_mark>0 or powder_mark>0: draw_circle(Vector2(0,-radius-22),6,Color("#f1dc9a"))
	if hunt_stacks>0:
		draw_string(ThemeDB.fallback_font,Vector2(-7,-radius-28),str(hunt_stacks),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#ffd978"))
	for i in range(elite_modifiers.size()):
		var matches = V7.ELITE_MODIFIERS.filter(func(entry): return entry.id==elite_modifiers[i])
		if matches.is_empty(): continue
		var definition: Dictionary = matches[0]
		draw_circle(Vector2(-12*(elite_modifiers.size()-1)+i*24,-radius-43),8,Color(definition.color))
