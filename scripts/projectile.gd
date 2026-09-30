extends Node2D
var body_length: float = 0
var bubble: bool = false
var hit_width: float = 0
var source: String = "normal"
var empowered: bool = false
var powder: bool = false
var game
var direction = Vector2.RIGHT
var speed: float = 900.0
var damage: float = 20.0
var remaining: float = 700.0
var traveled: float = 0.0
var enemy_shot: bool = false
var style: int = 0
var pierce: int = 1
var bounce: int = 0
var critical: bool = false
var explosion: float = 0.0
var returning: bool = false
var can_return: bool = false
var gone: bool = false
var lifetime: float = 0.0
var launch_offset := Vector2(0,-48)
var height_offset := Vector2(0,-48)
func display_offset() -> Vector2:
	return launch_offset.lerp(height_offset,clampf(lifetime/.09,0,1))
var exclude: Array[RID] = []
var tint = Color.WHITE

func _physics_process(delta: float) -> void:
	if game.state != "combat" or gone: return
	lifetime += delta
	if lifetime<.12 or returning:queue_redraw()
	if lifetime > 5.0:
		finish()
		return
	if returning and is_instance_valid(game.player):
		direction = global_position.direction_to(game.player.global_position)
		if global_position.distance_to(game.player.global_position) < 28:
			finish()
			return
	var step: float = minf(speed*delta,remaining)
	var endpoint = global_position + direction*step
	if hit_width>0 and not enemy_shot:
		wide_step(endpoint,step)
		return
	if not enemy_shot: game.fx.streak(global_position+display_offset(),endpoint+display_offset(),tint,3 if style!=1 else 2)
	# 沿本帧完整路径查询，避免高速子弹穿过小目标。
	var mask: int = 3 if enemy_shot else (1 if pierce <= 0 else 5)
	var query = PhysicsRayQueryParameters2D.create(global_position,endpoint,mask,exclude)
	query.hit_from_inside = true
	for attempt in range(10):
		var hit = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): break
		var body = hit.collider
		if body is StaticBody2D:
			if body.has_method("hurt") and not enemy_shot: body.hurt(damage)
			global_position = hit.position - direction * 3.0
			finish(true)
			return
		# 爆破弹只通过范围伤害结算，不让直接命中的目标再承受一次重复伤害。
		if explosion > 0:
			global_position = hit.position
			finish()
			return
		if body.has_method("hurt"):
			if enemy_shot:
				body.hurt(damage)
			else:
				var amount = damage
				if game.player.stats.role == 2 and traveled > 420:
					amount *= 1.25 + game.player.stats.bonus("distance")
				body.hurt(amount,critical,true)
				game.presentation_fx.emit("impact",hit.position+height_offset,direction,style,.7)
				game.player.skills.on_hit(body,self)
			exclude.append(body.get_rid())
			pierce -= 1
			if bounce > 0 and not enemy_shot:
				var target = game.nearest_enemy(hit.position,exclude,420.0)
				if is_instance_valid(target):
					direction = (target.global_position - hit.position).normalized()
					bounce -= 1
					pierce = maxi(1,pierce)
					global_position = hit.position + direction*4
					rotation = direction.angle()
					queue_redraw()
					return
			if pierce <= 0:
				if can_return and not returning:
					break
				global_position = hit.position
				finish()
				return
		else:
			finish()
			return
		query.exclude = exclude
	global_position = endpoint
	remaining -= step
	traveled += step
	rotation = direction.angle()
	if remaining <= 0: finish(true)

func finish(allow_return: bool = false) -> void:
	if gone: return
	if allow_return and can_return and not returning and not enemy_shot:
		returning = true
		can_return = false
		remaining = 2000
		exclude.clear()
		pierce = 8
		damage *= 0.7
		return
	gone = true
	if explosion > 0 and game.state == "combat":
		if powder:
			for enemy in game.enemies:
				if enemy.global_position.distance_to(global_position)<explosion: enemy.blast_mark = 6
		game.explode(global_position,explosion,damage)
		game.fx.combo_burst(global_position,1,"")
		game.sound.play("explosion")
	if powder and game.state=="combat":
		game.add_zone(global_position,explosion,6,6,0,"powder",1)
	game.projectiles.erase(self)
	queue_free()

func _draw() -> void:
	# Ground-plane physics stays unchanged; this is the weapon-height projection.
	draw_set_transform(display_offset().rotated(-rotation))
	if bubble:
		draw_circle(Vector2.ZERO,12,Color(.4,.82,.91,.30))
		draw_arc(Vector2.ZERO,12,0,TAU,24,Color("#b3edf3"),2,true)
		draw_circle(Vector2(-4,-4),3,Color("#f0fffa"))
		return
	if body_length>0:
		preload("res://scripts/skill_art.gd").weapon(self,style,body_length,hit_width*0.6,tint)
		return
	if enemy_shot:
		draw_circle(Vector2.ZERO,9,Color("#ff657c"))
		draw_circle(Vector2(-2,-2),4,Color("#ffe2be"))
	elif explosion > 0:
		draw_circle(Vector2.ZERO,13,Color("#efb866"))
		draw_arc(Vector2.ZERO,19,0,TAU,16,Color("#f8e1ac"),2)
	elif style == 0:
		preload("res://scripts/skill_art.gd").weapon(self,0,58,3,Color.WHITE)
	elif style == 1:
		if empowered:
			draw_line(Vector2(-34,0),Vector2(14,0),Color(1,0.75,0.3,0.45),13,true)
			draw_arc(Vector2(8,0),9,0,TAU,12,Color("#fff2c0"),2,true)
		draw_line(Vector2(-23,0),Vector2(8,0),tint,5,true)
		draw_circle(Vector2(8,0),4,Color("#fff5d5"))
	else:
		preload("res://scripts/skill_art.gd").weapon(self,2,54,2,Color.WHITE)

func wide_step(endpoint: Vector2, step: float) -> void:
	var wall_at = endpoint+direction*body_length*0.5
	var wall_hit = false
	var space = get_world_2d().direct_space_state
	for offset in [-hit_width,0.0,hit_width]:
		var across = direction.orthogonal()*offset
		var q = PhysicsRayQueryParameters2D.create(global_position+across,wall_at+across,1)
		var wall = space.intersect_ray(q)
		if not wall.is_empty():
			if wall.collider.has_method("hurt"): wall.collider.hurt(damage)
			wall_at = wall.position-across
			wall_hit = true
	var start = global_position-direction*body_length*0.5
	for enemy in game.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead or exclude.has(enemy.get_rid()): continue
		var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position,start,wall_at)
		if closest.distance_to(enemy.global_position)>hit_width+enemy.radius: continue
		var sight = PhysicsRayQueryParameters2D.create(global_position,enemy.global_position,1)
		if not space.intersect_ray(sight).is_empty(): continue
		enemy.hurt(damage,critical,true)
		game.player.skills.on_hit(enemy,self)
		exclude.append(enemy.get_rid())
		pierce -= 1
		game.art.emit("slash" if style==0 else "blast",enemy.global_position,direction,60,0.25,style)
		if pierce<=0: finish(); return
	game.fx.streak(global_position-direction*body_length*0.4+display_offset(),endpoint+display_offset(),tint,hit_width if style==1 else hit_width*.4)
	global_position = endpoint
	rotation = direction.angle()
	remaining -= step
	traveled += step
	if wall_hit or remaining<=0: finish(true)
