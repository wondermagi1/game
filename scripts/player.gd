extends CharacterBody2D
const Stats = preload("res://scripts/stats.gd")
const Visual = preload("res://scripts/actor_visual.gd")
const SwordVisual3D = preload("res://scripts/character_3d_sword.gd")
const Skills = preload("res://scripts/skill_controller.gd")
const Catalog = preload("res://scripts/catalog.gd")
var skills
var barrier: float = 0
var barrier_time: float = 0
var magnet_time: float = 0
var item_clocks: Dictionary = {}
var game
var stats
var hp: float = 100.0
var visual
var visual_3d
var aim = Vector2.RIGHT
var attack_clock: float = 0.0
var skill_clock: float:
	get: return skills.cooldowns[0] if skills!=null else 0.0
	set(value):
		if skills!=null: skills.cooldowns[0] = value
var dash_clock: float = 0.0
var dash_time: float = 0.0
var dash_direction = Vector2.RIGHT
var invulnerable: float = 0.0
var reload_time: float = 0.0
var ammo: int = 6
var first_round: bool = false
var orbit_time: float = 0.0
var orbit_tick: float = 0.0
var kill_buff: float = 0.0
var dash_buff: float = 0.0
var dash_attack: bool = false
var status_proc_clock: float = 0
var resonance_clock: float = 3
var guardian_clock: float = 8
var heal_clock: float = 0.0
var slow_time: float = 0.0
var safe_clock: float = 0.0
var shield_ready: bool = false
var revive_used: bool = false
var dead: bool = false
var manual_control: bool = false
var attack_input_armed: bool = false
var action_recovery: float = 0.0
var attack_buffer: float = 0.0
var skill_buffer: int = -1
var skill_buffer_time: float = 0.0
var scripted_movement := Vector2.ZERO
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 1.4
@export var hit_protection: float = 0.4

func _exit_tree() -> void:
	if skills!=null: skills.ultimate.skills = null

func _ready() -> void:
	skills = Skills.new()
	skills.actor = self
	skills.game = game
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 22
	shape.shape = circle
	add_child(shape)
	visual = Visual.new()
	visual.kind = stats.role
	visual.tint = stats.base.color
	add_child(visual)
	var equipped: Dictionary = game.profile.item_by_id(game.profile.data.roles[stats.role].equipped.get("0",""))
	visual.quality = int(equipped.get("quality",0))
	visual_3d = SwordVisual3D.new()
	visual_3d.name = "SwordVisual3D"
	visual_3d.role = stats.role
	visual_3d.state_source = visual
	add_child(visual_3d)
	apply_visual_mode()
	hp = stats.value("hp")
	ammo = magazine_size()
	z_index = 5

func apply_visual_mode() -> void:
	if not is_instance_valid(visual):return
	var use_sample: bool=game!=null and game.use_3d_characters and stats.role==0
	visual.visible=not use_sample
	if is_instance_valid(visual_3d):visual_3d.set_enabled(use_sample)

func magazine_size() -> int:
	return mini(30,6+int(stats.bonus("magazine")))

func reload_duration() -> float:
	return 1.4 * (1.0-minf(0.8,stats.bonus("reload")))

func _physics_process(delta: float) -> void:
	if game.state != "combat" or dead: return
	attack_clock = maxf(0,attack_clock-delta)
	action_recovery = maxf(0,action_recovery-delta)
	attack_buffer = maxf(0,attack_buffer-delta)
	skill_buffer_time = maxf(0,skill_buffer_time-delta)
	if skill_buffer_time<=0: skill_buffer = -1
	status_proc_clock = maxf(0,status_proc_clock-delta)
	slow_time = maxf(0,slow_time-delta)
	skills.tick(delta)
	tick_evolution(delta)
	barrier_time = maxf(0,barrier_time-delta)
	if barrier_time<=0: barrier = 0
	magnet_time = maxf(0,magnet_time-delta)
	for key in item_clocks: item_clocks[key] = maxf(0,item_clocks[key]-delta)
	dash_clock = maxf(0,dash_clock-delta)
	invulnerable = maxf(0,invulnerable-delta)
	heal_clock = maxf(0,heal_clock-delta)
	kill_buff = maxf(0,kill_buff-delta)
	dash_buff = maxf(0,dash_buff-delta)
	safe_clock += delta
	if stats.bonus("shield") > 0 and safe_clock >= maxf(2.5,6.0/(1+stats.raw_bonus("shield")*0.08)): shield_ready = true
	if reload_time > 0:
		reload_time -= delta
		if reload_time <= 0:
			ammo = magazine_size()
			first_round = true
			game.sound.play("reload")
	var movement = scripted_movement.limit_length(1.0) if manual_control else Vector2.ZERO
	if not manual_control and game.focused and game.ui.binding_action.is_empty():
		movement = Input.get_vector("move_left","move_right","move_up","move_down")
		var cursor = get_global_mouse_position()-global_position
		if cursor.length() > 1: aim = cursor.normalized()
		if Input.is_action_just_pressed("dash"): dash(movement)
		if Input.is_action_just_pressed("skill"): request_skill(0)
		if Input.is_action_just_pressed("reload"): reload()
		for i in range(1,4):
			if Input.is_action_just_pressed("skill_%d"%(i+1)): request_skill(i)
		for i in range(3):
			if Input.is_action_just_pressed("item_%d"%(i+1)): use_item(i)
		if not Input.is_action_pressed("attack"): attack_input_armed = true
		if attack_input_armed and Input.is_action_pressed("attack") and game.ui.can_fire(): request_attack()
	tick_action_buffers()
	if dash_time > 0:
		dash_time -= delta
		velocity = dash_direction * stats.value("speed") * 2.5
	else:
		var boost = 1.0 + (stats.bonus("kill_speed") if kill_buff > 0 else 0.0)
		if stats.role==2 and skills.rapid_time>0: boost *= 1.2
		if slow_time>0: boost *= 0.68
		velocity = movement * stats.value("speed") * boost
	move_and_slide()
	visual.aim = aim
	visual.movement = velocity/280.0
	visual.walking = minf(1,velocity.length()/200)
	visual.modulate.a = 0.5 if invulnerable > 0 and fmod(invulnerable,0.12)<0.06 else 1.0
	if orbit_time > 0:
		orbit_time -= delta
		orbit_tick -= delta
		if orbit_tick <= 0:
			orbit_tick = 0.25
			for enemy in game.enemies.duplicate():
				if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) < 150+stats.bonus("orbit")*25+(skills.rank(0)-1)*20:
					var evolution_bonus = 0.12*skills.tier(0) if skills.branch(0)==0 else 0.0
					enemy.hurt(stats.value("attack")*(0.45+0.04*(skills.rank(0)-1)+evolution_bonus),false,true)
	queue_redraw()

func dash(movement: Vector2) -> bool:
	if dash_clock > 0: return false
	# A dodge is the universal defensive cancel. Reloading is interrupted without
	# refilling ammunition, and buffered actions are cleared to prevent accidents.
	action_recovery = 0
	attack_buffer = 0
	skill_buffer = -1
	skill_buffer_time = 0
	if reload_time>0: reload_time = 0
	game.telemetry.dodges += 1
	dash_direction = movement.normalized() if movement.length()>0 else aim
	visual.dash_trail = .25
	visual.play_gesture("dash",dash_duration)
	game.presentation_fx.emit("dash",global_position,-aim,stats.role)
	dash_time = dash_duration
	invulnerable = maxf(invulnerable,dash_duration)
	dash_clock = dash_cooldown * (1.0-minf(0.8,stats.bonus("dash_cooldown")))
	dash_buff = 2.0
	dash_attack = stats.bonus("dash_power") > 0
	game.fx.ring(global_position,50,stats.base.color)
	game.sound.play("dash")
	var evolution = stats.evolution_tier("疾行")
	if evolution>0: game.explode(global_position,60+evolution*40,stats.value("attack")*0.4*evolution,false)
	return true

func reload() -> void:
	if stats.role != 1 or reload_time > 0 or ammo == magazine_size(): return
	reload_time = reload_duration()
	visual.play_gesture("reload_open",reload_time/3)

func attack() -> bool:
	if game.state != "combat" or dead or attack_clock > 0 or reload_time > 0: return false
	if stats.role == 1 and ammo <= 0:
		reload()
		return false
	var rate = stats.value("rate")
	if skills.tactical_time>0: rate *= 1.35
	if kill_buff > 0: rate *= 1+stats.bonus("kill_rate")
	if stats.role == 0 and dash_buff > 0: rate *= 1.25
	attack_clock = maxf(0.08,1.0/rate)
	action_recovery = maxf(action_recovery,minf(0.16,attack_clock*0.55))
	visual.aim = aim
	visual.play_gesture("attack",minf(.32,attack_clock))
	var empowered = first_round or skills.empowered_shots>0
	if skills.empowered_shots>0: skills.empowered_shots -= 1
	var amount = stats.value("attack")*skills.normal_multiplier()
	if hp < stats.value("hp")*0.35: amount *= 1+stats.bonus("berserk")
	if dash_attack:
		amount *= 1+stats.bonus("dash_power")
		dash_attack = false
	if stats.role == 1:
		ammo -= 1
		if empowered:
			amount *= 1.5+stats.bonus("first")
			first_round = false
	var critical: bool = game.rng.randf() < stats.value("crit")
	if critical: amount *= stats.value("crit_damage")
	var count = 1+int(stats.bonus("multishot"))
	for i in range(count):
		var dir = aim.rotated((i-(count-1)*0.5)*0.14)
		var properties = {
			"source":"normal","empowered":empowered,"damage":amount,"critical":critical,"style":stats.role,"tint":stats.base.color,
			"speed":[920.0,1500.0,1120.0][stats.role]*(1+stats.bonus("projectile_pct")),
			"remaining":stats.value("range"),
			"pierce":(2+int(stats.bonus("pierce"))) if stats.role == 0 else 1,
			"bounce":int(stats.bonus("bounce")) if stats.role == 2 else 0,
			"can_return":stats.role == 0 and stats.bonus("return")>0
		}
		game.spawn_projectile(global_position+dir*32,dir,skills.decorate_normal(properties))
	skills.on_attack()
	game.presentation_fx.emit("shot",global_position+visual.muzzle_local(),aim,stats.role)
	visual.action = 0.20
	visual.casting = false
	game.sound.play(["sword","gun","bow"][stats.role])
	if stats.role == 1 and ammo == 0: reload()
	return true

func use_skill(slot: int = 0) -> bool:
	var used = skills.use(slot)
	if used: action_recovery = maxf(action_recovery,0.30 if slot==3 else 0.14)
	return used

func request_attack() -> bool:
	if action_recovery<=0 and attack():
		attack_buffer = 0
		return true
	if reload_time<=0:
		attack_buffer = 0.16
	return false

func request_skill(slot: int) -> bool:
	if slot<0 or slot>3: return false
	if action_recovery<=0 and use_skill(slot):
		skill_buffer = -1
		skill_buffer_time = 0
		return true
	# Only buffer a cast that is otherwise available or about to become available.
	# Invalid/locked skills do not occupy the queue.
	if skills.unlocked(slot) and skills.cooldowns[slot]<=0.22:
		skill_buffer = slot
		skill_buffer_time = 0.22
	return false

func tick_action_buffers() -> void:
	if action_recovery>0: return
	if skill_buffer>=0 and skill_buffer_time>0 and skills.cooldowns[skill_buffer]<=0:
		var slot = skill_buffer
		skill_buffer = -1
		skill_buffer_time = 0
		use_skill(slot)
		return
	if attack_buffer>0 and attack_clock<=0 and reload_time<=0:
		attack_buffer = 0
		attack()

func hurt(raw: float) -> void:
	if game.state != "combat" or dead or invulnerable > 0 or dash_time > 0: return
	safe_clock = 0.0
	if shield_ready:
		shield_ready = false
		if stats.abyss and stats.raw_bonus("shield")>=5: game.explode(global_position,150,stats.value("attack")*0.6,false)
		invulnerable = 0.25
		game.fx.ring(global_position,70,Color("#a0e8ff"))
		return
	var amount = maxf(1,raw*100.0/(100.0+stats.value("armor")))
	var absorbed = minf(barrier,amount)
	barrier -= absorbed
	amount -= absorbed
	hp -= amount
	game.taken += amount
	game.telemetry.damage_taken += amount
	game.telemetry.failure_reason = "受到近身攻击或弹幕命中"
	game.sound.play("hurt")
	game.fx.number(global_position,amount,Color("#ff8090"))
	visual.flash = 0.18
	visual.play_gesture("hurt",.22)
	game.shake_strength = 8.0
	invulnerable = hit_protection
	if hp <= 0:
		if stats.bonus("revive")>0 and not revive_used:
			revive_used = true
			hp = stats.value("hp")*(minf(0.6,0.25+0.01*maxf(0,stats.raw_bonus("revive")-1)) if stats.abyss else 0.25)
			invulnerable = 1.5
			game.fx.ring(global_position,150,Color("#f1d795"))
		else:
			hp = 0
			dead = true
			visual.dying = true
			game.end_run(false)

func heal(amount: float) -> void:
	if dead: return
	var restored = minf(stats.value("hp")-hp,amount*(1+stats.bonus("healing")))
	hp += restored
	game.telemetry.healing += restored
	if restored > 0: game.fx.number(global_position,restored,Color("#89edb3"))

func on_kill(enemy = null) -> void:
	kill_buff = 2.0
	if stats.role==1 and stats.bonus("gear_branch_1")>0 and is_instance_valid(enemy) and enemy.last_source in ["bomb","explosion","v7_greatsword","skill_0"]:
		ammo = mini(magazine_size(),ammo+1)
		game.fx.caption(global_position-Vector2(60,82),"爆破解闩 +1",Color("#ffc06c"))
	if heal_clock <= 0 and stats.bonus("kill_heal") > 0:
		heal(stats.bonus("kill_heal"))
		heal_clock = 0.7

func stage_reset() -> void:
	global_position = Vector2(960,750)
	invulnerable = 1.2
	dash_clock = 0
	skills.reset()
	reload_time = 0
	ammo = magazine_size()
	orbit_time = 0
	if not game.flow.abyss: revive_used = false
	attack_clock = 0.25
	action_recovery = 0
	attack_buffer = 0
	skill_buffer = -1
	skill_buffer_time = 0
	# 每回合之间给予补给；局内强化仍保留至章节挑战结束。
	if not game.flow.abyss and (game.flow.round_number>1 or game.flow.hidden):
		heal(stats.value("hp")*game.stage_recovery_ratio+stats.bonus("stage_heal"))

func _draw() -> void:
	if shield_ready: draw_arc(Vector2(0,-6),39,0,TAU,48,Color("#a0e8ff"),2,true)
	if dash_buff > 0 and stats.role == 0: draw_arc(Vector2.ZERO,32,0,TAU,32,Color("#69dbce"),1.5,true)
	if orbit_time > 0:
		var r = 150.0+stats.bonus("orbit")*25.0+(skills.rank(0)-1)*20
		draw_arc(Vector2.ZERO,r,0,TAU,64,Color(0.4,0.9,0.85,0.18),2,true)
		var sword_count = 5+(2+skills.tier(0)+int(stats.bonus("gear_branch_0")) if skills.branch(0)==0 else 0)
		for i in range(sword_count):
			var angle = orbit_time*4+i*TAU/sword_count
			var p = Vector2.from_angle(angle)*r
			draw_line(p-Vector2.from_angle(angle+PI/2)*17,p+Vector2.from_angle(angle+PI/2)*17,Color("#c5fff0"),6,true)

func use_item(slot: int) -> bool:
	if game.state!="combat" or dead or slot<0 or slot>2: return false
	var id: String = game.profile.data.quick[slot]
	if int(game.profile.data.consumables.get(id,0))<=0 or float(item_clocks.get(id,0))>0: return false
	var definition: Dictionary = {}
	for item in Catalog.ITEMS:
		if item.id==id: definition = item
	if definition.is_empty(): return false
	if id=="potion" and hp>=stats.value("hp"): return false
	game.profile.data.consumables[id] -= 1
	game.profile.dirty = true
	item_clocks[id] = definition.cd
	match id:
		"potion": heal(stats.value("hp")*0.35)
		"barrier": barrier = maxf(barrier,45); barrier_time = 8
		"frost":
			for enemy in game.enemies: enemy.slow_time = 5
		"thunder": game.explode(global_position,330,stats.value("attack")*2.5,false)
		"magnet": magnet_time = 12; game.collect_loot(true)
		"sand":
			for i in range(4): skills.cooldowns[i] *= 0.5
	game.fx.sigils(global_position,100,Color("#b4e2d1"),2)
	game.profile.discover("item_"+id)
	game.profile.save_profile()
	return true

func tick_evolution(delta: float) -> void:
	resonance_clock -= delta
	guardian_clock -= delta
	var offense = stats.evolution_tier("共鸣")
	if resonance_clock<=0:
		resonance_clock = 3
		if offense>0:
			for i in range(offense+1): skills.shot(aim.rotated((i-offense*0.5)*0.22),offense*0.35,offense,"evolution")
	var defense = stats.evolution_tier("守护")
	if guardian_clock<=0:
		guardian_clock = 8
		if defense>0:
			barrier = maxf(barrier,stats.value("hp")*0.03*defense)
			barrier_time = maxf(barrier_time,4)
			game.fx.sigils(global_position,60+defense*12,Color("#8ad9ff"),defense)
