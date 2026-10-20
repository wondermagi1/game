extends Node2D
const C = preload("res://scripts/td/catalog.gd")
const TextureFX = preload("res://scripts/skill_textures.gd")
const Atlas = preload("res://art/td/facilities.png")
var game
var kind: int = 0
var rank: int = 1
var pad: int = 0
var invested: int = 0
var clock: float = 0.2
var pulses: int = 0
var hp: float = 180.0
var max_hp: float = 180.0
var disabled_time: float = 0.0
var flash: float = 0.0
var boost_time: float = 0.0
var overcharge: float = 0.0
var source_region: Rect2

func _ready() -> void:
	z_index = 3
	source_region = C.REGIONS[kind]
	refresh_rank()

func refresh_rank() -> void:
	var difference = (180+float(rank-1)*125)-max_hp
	max_hp = 180+float(rank-1)*125
	hp = minf(max_hp,hp+maxf(0,difference))
	flash = 1
	queue_redraw()

func reach() -> float:
	return C.reach(kind,rank)

func take_hit(amount: float) -> void:
	if disabled_time>0: return
	hp -= amount*(0.55 if rank>=3 else 1.0)
	flash = 0.15
	if hp<=0:
		disabled_time = 12.0
		game.fx.caption(global_position-Vector2(35,110),"重组中",Color("#eac18b"))

func _physics_process(delta: float) -> void:
	if game.state!="combat": return
	flash = maxf(0,flash-delta)
	boost_time = maxf(0,boost_time-delta)
	overcharge = maxf(0,overcharge-delta)
	if disabled_time>0:
		disabled_time -= delta
		if disabled_time<=0: hp = max_hp
		queue_redraw()
		return
	if kind==7 and rank==4: hp = minf(max_hp,hp+delta*7)
	clock -= delta*(1.25 if boost_time>0 else 1.0)
	if clock<=0:
		clock = C.interval(kind,rank)
		activate()
	queue_redraw()

func targets() -> Array:
	var result: Array = []
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.state!="spawn" and enemy.global_position.distance_to(global_position)<reach(): result.append(enemy)
	result.sort_custom(func(a,b): return a.global_position.distance_squared_to(global_position)<b.global_position.distance_squared_to(global_position))
	return result

func activate() -> void:
	var foes = targets()
	if kind<9 and foes.is_empty(): clock = 0.2; return
	pulses += 1
	var power = C.damage(kind,rank)*game.tower_multiplier(self)*(1.3 if overcharge>0 else 1.0)
	flash = 0.35
	match kind:
		0,1,2:
			var shots = 2 if kind==0 and rank>=3 else 1
			if rank==4 and pulses%4==0 and kind==0: shots = 3
			if kind==2 and rank==4 and pulses%3==0: shots = 3
			for i in range(shots):
				var target = foes[i%foes.size()]
				var projectile = preload("res://scripts/td/shot.gd").new()
				projectile.game = game
				projectile.kind = kind
				projectile.rank = rank
				projectile.target = target
				projectile.destination = target.global_position+Vector2(i*15,0)
				projectile.position = global_position+Vector2(0,-42+i*9)
				projectile.damage = power*(3 if kind==1 and rank==4 and pulses%3==0 else 1)
				projectile.homing = kind==0 and rank==4 and pulses%4==0
				projectile.pierce = (2 if rank>=2 else 1) if kind==0 else (3 if rank>=3 else 1)
				game.add_child(projectile)
				projectile.add_to_group("td_shots")
			game.tower_sound("gun" if kind==2 else ("sword" if kind==0 else "bow"))
		3:
			var count = [1,2,4,4][rank-1]
			if rank==4 and pulses%3==0: count = 7
			var origin = global_position-Vector2(0,70)
			var visited: Array = []
			var current = foes[0]
			for i in range(count):
				if current==null: break
				visited.append(current)
				game.energy_arc(origin,current.global_position,C.COLORS[kind])
				current.hurt(power,false,false,"tower")
				origin = current.global_position
				current = game.chain_target(origin,visited,190)
			game.tower_sound("crit")
		4:
			var aim: Vector2 = global_position.direction_to(foes[0].global_position)
			for enemy in foes:
				if aim.dot(global_position.direction_to(enemy.global_position))<(0.5 if rank>=2 else 0.75): continue
				enemy.hurt(power*(2 if rank==4 and pulses%3==0 else 1),false,false,"tower")
				if rank>=3:
					enemy.burn_time = 2.5
					enemy.td_burn = power*0.4
					enemy.weakened = 3
			game.art.emit("muzzle",global_position-Vector2(0,35),aim,reach()*0.8,0.32,1)
		5,6,8:
			for enemy in foes:
				enemy.hurt(power,false,false,"tower")
				if kind==5:
					enemy.slow_time = 3
					enemy.frost_hits += 1
					if rank>=3 and enemy.frost_hits%3==0:
						enemy.crowd_control(0.9)
						if rank==4: enemy.hurt(power*3,false,false,"tower")
				elif kind==6:
					var strength = (160+rank*55)*(1.7 if rank==4 and pulses%3==0 else 1)
					enemy.pull_velocity = enemy.global_position.direction_to(global_position)*strength*(0.25 if enemy.elite else 1.0)
					if rank>=3: enemy.hurt(power*1.5,false,false,"tower")
				else:
					enemy.thorn_hits += 1
					if rank>=3 and enemy.thorn_hits%3==0:
						enemy.crowd_control(0.8)
						if rank==4: enemy.hurt(power*2.5,false,false,"tower")
			game.pulse_at(global_position,reach(),C.COLORS[kind])
		7:
			foes[0].hurt(power*(2 if rank==4 else 1),false,false,"tower")
			game.art.emit("slash",global_position,global_position.direction_to(foes[0].global_position),95,0.3,0)
		9:
			if global_position.distance_to(game.player.global_position)<reach():
				game.player.hp = minf(game.player.stats.value("hp"),game.player.hp+5+rank*3)
				if rank>=3: game.player.slow_time = 0
				if rank==4:
					game.player.barrier = maxf(game.player.barrier,18)
					game.player.barrier_time = maxf(game.player.barrier_time,4)
				game.pulse_at(global_position,reach(),C.COLORS[kind])
		10:
			var nearest = null
			for tower in game.facilities:
				if tower.kind>=9 or tower==self or tower.global_position.distance_to(global_position)>reach(): continue
				if rank>=3: tower.boost_time = maxf(tower.boost_time,3)
				if nearest==null or tower.position.distance_squared_to(position)<nearest.position.distance_squared_to(position): nearest = tower
			if rank==4 and nearest!=null:
				nearest.overcharge = 3
				game.energy_arc(global_position-Vector2(0,60),nearest.position-Vector2(0,60),C.COLORS[kind])
		11: pass

func _draw() -> void:
	var tint = Color(0.55,0.55,0.6,0.65) if disabled_time>0 else Color.WHITE
	TextureFX.glow(self,Vector2(0,2),Vector2(115,34),0,Color(C.COLORS[kind],0.25+flash*0.3))
	var visual_size = source_region.size*minf(142.0/source_region.size.x,145.0/source_region.size.y)
	draw_texture_rect_region(Atlas,Rect2(Vector2(-visual_size.x*0.5,5-visual_size.y),visual_size),source_region,tint)
	# Rank ornaments are small and leave the painted silhouette readable.
	for i in range(rank):
		TextureFX.glow(self,Vector2((i-(rank-1)*0.5)*13,10),Vector2(16,16),0,C.COLORS[kind])
	if rank==4:
		TextureFX.rune(self,Vector2(0,0),Vector2(130,50),0,0.28)
	if kind==7 and hp<max_hp:
		draw_rect(Rect2(-30,-135,60,5),Color("#282333"))
		draw_rect(Rect2(-30,-135,60*maxf(0,hp/max_hp),5),C.COLORS[7])
