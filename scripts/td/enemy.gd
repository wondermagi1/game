extends "res://scripts/enemy.gd"
## Defense enemies follow waypoints; control never changes their lane progress.
var route: PackedVector2Array
var waypoint: int = 1
var freeze_time: float = 0.0
var control_immunity: float = 0.0
var frost_hits: int = 0
var thorn_hits: int = 0
var pull_velocity := Vector2.ZERO
var td_burn: float = 0.0
var base_armor: float = 0.0
var weakened: float = 0.0

func _ready() -> void:
	super._ready()
	elite_modifiers.clear()
	ward = 0
	max_hp = (95.0 if kind==0 else (65.0 if kind==1 else 220.0)) * [1.0,1.45,1.9][game.defense_wave-1]
	if elite: max_hp *= 2.2
	hp = max_hp
	speed = 62.0 if kind==3 else (125.0 if kind==1 else 80.0)
	base_armor = 22.0 if kind==3 else 0.0
	armor = base_armor
	damage = 8.0 if not elite else 13.0
	timer = 0.45

func crowd_control(seconds: float) -> void:
	if control_immunity>0: return
	freeze_time = maxf(freeze_time,seconds*(0.32 if elite else 1.0))
	control_immunity = seconds+2.0 if elite else seconds+0.6

func _physics_process(delta: float) -> void:
	if game.state!="combat" or dead: return
	if state=="spawn":
		timer -= delta
		visual.modulate.a = 0.55
		if timer<=0:
			state = "move"
			visual.modulate.a = 1.0
		queue_redraw()
		return
	for property in ["slow_time","mark_time","sword_mark","powder_mark","blast_mark","burn_time","poison_time","hit_stop","freeze_time","control_immunity","weakened"]:
		set(property,maxf(0,float(get(property))-delta))
	armor = maxf(0,base_armor-18) if weakened>0 else base_armor
	dot_clock -= delta
	if dot_clock<=0:
		dot_clock = 0.5
		if burn_time>0: hurt(maxf(burn_damage,td_burn)*0.5,false,false,"burn")
		if poison_time>0: hurt(poison_damage*poison_stacks*0.5,false,false,"poison")
		if dead: return
	cooldown -= delta
	if waypoint>=route.size():
		game.leak_enemy(self)
		return
	var goal: Vector2 = route[waypoint]
	if global_position.distance_to(goal)<24:
		waypoint += 1
		return
	var blocker = game.nearest_guardian(global_position)
	if blocker!=null: goal = blocker.global_position
	var toward: Vector2 = global_position.direction_to(goal)
	velocity = toward*speed*(0.56 if slow_time>0 else 1.0)
	if blocker!=null and global_position.distance_to(goal)<76:
		velocity = Vector2.ZERO
		if cooldown<=0:
			blocker.take_hit(damage)
			cooldown = 1.0
	if cooldown<=0 and global_position.distance_to(game.player.global_position)<64:
		game.player.hurt(damage)
		cooldown = 1.0
	if freeze_time>0 or hit_stop>0: velocity = Vector2.ZERO
	velocity += knockback+pull_velocity
	knockback = knockback.move_toward(Vector2.ZERO,delta*800)
	pull_velocity = pull_velocity.move_toward(Vector2.ZERO,delta*650)
	move_and_slide()
	global_position = game.safe_position(global_position)
	visual.aim = toward
	visual.walking = minf(1,velocity.length()/100)
	queue_redraw()

func die() -> void:
	if dead: return
	dead = true
	collision_layer = 0
	game.kills += 1
	game.enemy_defeated(self)
	game.player.on_kill(self)
	game.fx.burst(global_position,visual.tint,7)
	game.sound.enemy_voice(kind)
	game.enemies.erase(self)
	queue_free()
