extends Node3D
## First continuous 2.5D frontier: 3D world/physics/lighting + animated 2D actors.
const Terrain = preload("res://scripts/frontier/terrain.gd")
const Actor = preload("res://scripts/frontier/actor.gd")
const Checkpoint = preload("res://scripts/frontier/checkpoint.gd")
const WeaponMesh = preload("res://scripts/frontier/weapon_mesh.gd")
const COLORS = [Color("#8de3e4"),Color("#ffce8c"),Color("#b3e6a7")]
const ROLES = ["魔剑士 · 青岚","火枪手 · 赤烬","游侠 · 逐风"]
const SKILLS = [["环刃守护","霜辉巨剑","回锋跃步","万剑归宗"],["爆破弹","霰弹齐射","战术装填","晨星轰击"],["贯日箭","流星箭雨","星痕猎印","群星狩猎"]]
const COOLDOWNS = [[8.0,6.0,7.0,18.0],[7.0,5.0,8.0,18.0],[6.0,8.0,7.0,18.0]]
const BOONS = [
	["辉光锋刃","攻击伤害 +25%","power",.25],
	["双星追击","普攻额外发射一枚弹体","multishot",1.0],
	["风的祝福","移动速度 +12%","speed",.12],
	["余温护佑","生命上限 +30，并恢复 30 点生命","health",30.0],
	["迅捷咏唱","技能冷却缩短 15%","cooldown",.15],
	["破冰之矢","弹体额外穿透一个目标","pierce",1.0],
	["雪原回响","暴击率增加 15 个百分点","crit",.15],
	["流光连击","普通攻击速度 +20%","rate",.2]
]
@export var test_mode: bool = false
var state: String = "menu"
var selected_role: int = 0
var terrain
var player
var camera: Camera3D
var ui
var sound
var enemies: Array = []
var projectiles: Array = []
var effects: Array = []
var hazards: Array = []
var sites: Array = []
var discovered: Dictionary = {}
var claimed: Dictionary = {}
var cleared: Dictionary = {}
var buffs: Dictionary = {}
var reward_options: Array = []
var reward_site: String = ""
var active_camp: String = ""
var engaged_camps: Dictionary = {}
var pending_rewards: Array = []
var hp: float = 120
var max_hp: float = 120
var level: int = 1
var xp: int = 0
var coins: int = 0
var kills: int = 0
var elapsed: float = 0
var potions: int = 3
var stamina: float = 100
var attack_clock: float = 0
var dash_clock: float = 0
var dash_time: float = 0
var invulnerable: float = 0
var dash_dir = Vector3.FORWARD
var cooldowns: Array = [0.0,0.0,0.0,0.0]
var cast_slot: int = -1
var cast_time: float = 0
var ultimate_time: float = 0
var ultimate_tick: float = 0
var orbit_time: float = 0
var orbit_tick: float = 0
var empowered: int = 0
var mark_time: float = 0
var runes: int = 0
var aim = Vector3.FORWARD
var camera_offset = Vector3(18,24,22)
var notice: String = ""
var notice_time: float = 0
var saved_wins: int = 0
var rng = RandomNumberGenerator.new()
var snow: GPUParticles3D
var scripted_movement = Vector3.ZERO
var checkpoint: Dictionary = {}
var rested: Dictionary = {}
var waypoint: String = ""
var boss_intro_time: float = 0.0

func _ready() -> void:
	rng.seed = 20261012 if test_mode else Time.get_ticks_msec()
	DisplayServer.window_set_title("三途试炼 · 霜语边境 · 2.5D 探索样板")
	setup_world()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	load_progress()
	create_player(selected_role)
	sites = [
		{"id":"hearth_home","name":"暖灯营地","pos":Vector2(-44,45),"kind":"hearth"},
		{"id":"hearth_bridge","name":"古桥驿火","pos":Vector2(24,9),"kind":"hearth"},
		{"id":"camp_west","name":"风铃哨站","pos":Vector2(-28,18),"kind":"camp"},
		{"id":"camp_east","name":"雪松路口","pos":Vector2(12,-6),"kind":"camp"},
		{"id":"rune_west","name":"林间暖光","pos":Vector2(-42,-12),"kind":"rune"},
		{"id":"rune_east","name":"旧桥回声","pos":Vector2(34,24),"kind":"rune"},
		{"id":"rune_north","name":"星落祭坛","pos":Vector2(35,-35),"kind":"rune"},
		{"id":"hidden_chest","name":"旅人的遗赠","pos":Vector2(-50,-45),"kind":"chest"},
		{"id":"trail_chest","name":"桥边宝箱","pos":Vector2(45,5),"kind":"chest"},
		{"id":"boss","name":"霜角圣庭","pos":Vector2(5,-48),"kind":"boss"}
	]
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)
	sound.volume = 0 if test_mode else .16
	ui = preload("res://scripts/frontier/interface.gd").new()
	ui.game = self
	add_child(ui)
	checkpoint = {} if test_mode else Checkpoint.read_file()
	get_tree().auto_accept_quit = false
	camera.position = player.position+camera_offset
	camera.look_at(player.position+Vector3.UP)
	set_state("menu")
	ui.show_menu()

func setup_world() -> void:
	terrain = Terrain.new()
	terrain.name = "ContinuousSnowFrontier"
	add_child(terrain)
	var sun = DirectionalLight3D.new()
	sun.name = "LowWinterSun"
	sun.rotation_degrees = Vector3(-28,-38,0)
	sun.light_color = Color("#fff1d7")
	sun.light_energy = 1.0
	sun.light_angular_distance = 3.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	sun.shadow_bias = .12
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#adcadb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c4dced")
	env.ambient_light_energy = .42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = .24
	env.glow_hdr_threshold = 1.25
	env.ssao_enabled = true
	env.ssao_radius = .7
	env.ssao_intensity = .55
	env.ssao_power = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("#b9d4e1")
	env.fog_density = .0008
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = .0008
	env.volumetric_fog_albedo = Color("#c9dce9")
	env.volumetric_fog_length = 75
	env.volumetric_fog_ambient_inject = .5
	environment.environment = env
	add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32
	camera.near = .1
	camera.far = 250
	camera.current = true
	add_child(camera)
	snow = GPUParticles3D.new()
	snow.amount = 280
	snow.lifetime = 9
	snow.preprocess = 9
	snow.visibility_aabb = AABB(Vector3(-35,-15,-35),Vector3(70,35,70))
	var process_material = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(24,8,24)
	process_material.direction = Vector3(-.3,-1,.1)
	process_material.spread = 18
	process_material.initial_velocity_min = .35
	process_material.initial_velocity_max = .8
	process_material.gravity = Vector3(-.04,-.04,0)
	process_material.scale_min = .035
	process_material.scale_max = .08
	snow.process_material = process_material
	var flake = SphereMesh.new()
	flake.radius = .5
	flake.height = 1
	flake.radial_segments = 4
	flake.rings = 2
	snow.draw_pass_1 = flake
	snow.material_override = terrain.material(Color("#dce7ea"))
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(snow)

func create_player(role: int) -> void:
	if is_instance_valid(player): player.free()
	selected_role = role
	player = Actor.new()
	player.role = role
	player.name = "Player3D"
	add_child(player)
	player.position = Terrain.ground(Vector2(-48,42))+Vector3.UP*.2

func start_run(role: int, replace_checkpoint: bool = true) -> void:
	if replace_checkpoint: discard_checkpoint()
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.free()
	enemies.clear()
	clear_transients()
	# Rebuild opened props and activated shrines for a clean new expedition.
	terrain.free()
	terrain = Terrain.new()
	add_child(terrain)
	create_player(role)
	buffs.clear()
	discovered.clear()
	claimed.clear()
	cleared.clear()
	rested.clear()
	waypoint = ""
	boss_intro_time = 0
	active_camp = ""
	engaged_camps.clear()
	pending_rewards.clear()
	reward_options.clear()
	reward_site = ""
	runes = 0
	hp = 120
	max_hp = 120
	level = 1
	xp = 0
	coins = 0
	kills = 0
	elapsed = 0
	potions = 3
	cooldowns = [0.0,0.0,0.0,0.0]
	cast_slot = -1
	ultimate_time = 0
	orbit_time = 0
	empowered = 0
	mark_time = 0
	dash_time = 0
	dash_clock = 0
	attack_clock = 0
	stamina = 100
	invulnerable = 1.5
	camera.position = player.position+camera_offset
	set_state("combat")
	ui.clear_modal()
	tell("循着暖灯进入雪原。唤醒三处符文，再前往北方圣庭。",7)
	discovered.hearth_home = true
	if replace_checkpoint: save_checkpoint(false)

func set_state(value: String) -> void:
	state = value
	if is_instance_valid(player): player.set_animation_running(state=="combat")
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.set_animation_running(state=="combat")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			if state=="combat": set_state("paused"); ui.show_pause()
			elif state in ["paused","map"]: set_state("combat"); ui.clear_modal()
		elif event.physical_keycode==KEY_M and state in ["combat","map"]:
			if state=="map": set_state("combat"); ui.clear_modal()
			else: set_state("map"); ui.show_map()
		elif event.physical_keycode==KEY_G and state=="combat": interact()
		elif event.physical_keycode==KEY_1 and state=="combat": drink_potion()
		elif event.physical_keycode==KEY_F5 and state=="combat": save_checkpoint()
	if event is InputEventMouseButton and event.pressed and state=="combat":
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.size = maxf(24,camera.size-2)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.size = minf(44,camera.size+2)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	var target: Vector3 = player.position+camera_offset
	camera.position = camera.position.lerp(target,1-exp(-delta*7))
	camera.look_at(camera.position-camera_offset+Vector3.UP)
	snow.position = player.position+Vector3.UP*7
	if state=="combat":
		notice_time = maxf(0,notice_time-delta)
		boss_intro_time = maxf(0,boss_intro_time-delta)
	if terrain.has_method("animate_scenery"): terrain.animate_scenery(delta, state=="combat" or state=="menu")
	if ui!=null: ui.refresh()

func _physics_process(delta: float) -> void:
	if state!="combat": return
	elapsed += delta
	attack_clock = maxf(0,attack_clock-delta)
	dash_clock = maxf(0,dash_clock-delta)
	invulnerable = maxf(0,invulnerable-delta)
	mark_time = maxf(0,mark_time-delta)
	for i in range(4): cooldowns[i] = maxf(0,cooldowns[i]-delta)
	if cast_slot>=0:
		cast_time -= delta
		if cast_time<=0:
			var slot = cast_slot
			cast_slot = -1
			release_skill(slot)
	var movement = scripted_movement.limit_length(1) if test_mode else Vector3.ZERO
	if not test_mode:
		var input = Input.get_vector("move_left","move_right","move_up","move_down")
		var forward = -camera.global_basis.z
		forward.y = 0
		movement = (camera.global_basis.x*input.x-forward.normalized()*input.y).limit_length(1)
		update_aim()
		if Input.is_action_just_pressed("dash"): dodge(movement)
		for i in range(4):
			if Input.is_action_just_pressed("skill" if i==0 else "skill_%d"%(i+1)): request_skill(i)
		if Input.is_action_pressed("attack"): attack()
	var sprint = not test_mode and Input.is_physical_key_pressed(KEY_SHIFT) and movement.length()>.1 and stamina>1 and dash_time<=0
	stamina = clampf(stamina+(-9 if sprint else 16)*delta,0,100)
	if dash_time>0:
		dash_time -= delta
		movement = dash_dir*2.7
	var speed = 7.0*(1+float(buffs.get("speed",0)))*(1.5 if sprint else 1)
	player.velocity.x = movement.x*speed
	player.velocity.z = movement.z*speed
	player.velocity.y -= 24*delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x,-61,61)
	player.position.z = clampf(player.position.z,-61,61)
	player.sync_visual(delta,screen_direction(aim))
	tick_enemies(delta)
	tick_projectiles(delta)
	tick_hazards(delta)
	tick_effects(delta)
	tick_ongoing_skills(delta)
	if state=="combat": tick_exploration()

func screen_direction(direction: Vector3) -> Vector2:
	return Vector2(direction.dot(camera.global_basis.x),-direction.dot(camera.global_basis.y)).normalized()

func update_aim() -> void:
	var mouse = get_viewport().get_mouse_position()
	var plane = Plane(Vector3.UP,player.position.y+1.1)
	var hit = plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	if hit!=null:
		var dir: Vector3 = hit-player.position
		dir.y = 0
		if dir.length()>.1: aim = dir.normalized()

func power() -> float:
	return (22+2*(level-1))*(1+float(buffs.get("power",0)))

func attack() -> bool:
	if state!="combat" or attack_clock>0 or cast_slot>=0: return false
	attack_clock = 1.0/([2.8,3.2,2.7][selected_role]*(1+float(buffs.get("rate",0))))
	player.gesture("attack",.3)
	# Immediate attacks start on their painted release; skill preparation is timed.
	player.visual.clip_time = .3*.28
	var count = 1+mini(4,int(buffs.get("multishot",0)))
	for i in range(count):
		shoot(player.position,aim.rotated(Vector3.UP,(i-(count-1)*.5)*.1),power()*(1.65 if empowered>0 else 1),selected_role,1+int(buffs.get("pierce",0)),false,1.0)
	if empowered>0: empowered -= 1
	sound.play(["sword","gun","bow"][selected_role])
	return true

func request_skill(slot: int) -> bool:
	if state!="combat" or slot<0 or slot>3 or cooldowns[slot]>0 or cast_slot>=0: return false
	cast_slot = slot
	cast_time = .32 if slot==3 else .14
	player.gesture("ultimate_gather" if slot==3 else "skill_%d"%slot,.85 if slot==3 else .5)
	return true

func release_skill(slot: int) -> void:
	if state!="combat" or hp<=0: return
	cooldowns[slot] = COOLDOWNS[selected_role][slot]*(1-minf(.6,float(buffs.get("cooldown",0))))
	player.visual.release_pose(slot)
	sound.play("skill")
	var p: Vector3 = player.position
	if slot==3:
		ultimate_time = 3
		ultimate_tick = 0
		player.gesture("ultimate_sustain",3)
		ring(p,4,COLORS[selected_role],.7)
		sound.play("ultimate_%d_start"%selected_role)
		return
	match selected_role:
		0:
			if slot==0: orbit_time = 4; orbit_tick = 0; ring(p,3.2,COLORS[0],.4)
			elif slot==1: shoot(p,aim,power()*4.5,0,10,false,3.0)
			else:
				dodge(aim,true)
				area_damage(p,4,power()*(3 if orbit_time>0 else 1.8))
				ring(p,4,COLORS[0],.5)
		1:
			if slot==0: shoot(p,aim,power()*3.0,1,1,false,1.7,3.5)
			elif slot==1:
				for i in range(7): shoot(p,aim.rotated(Vector3.UP,(i-3)*.11),power()*.85,1,2,false,1)
			else: empowered = 9; ring(p,2,COLORS[1],.5)
		2:
			if slot==0: shoot(p,aim,power()*(6 if mark_time>0 else 4),2,10,false,3)
			elif slot==1:
				var target = nearest_enemy(p)
				var center: Vector3 = target.position if target!=null else p+aim*8
				for i in range(7): hazards.append({"p":center+Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2)),"t":.18+i*.1,"radius":2.5,"damage":power()*1.3,"friendly":true})
			else: mark_time = 8; ring(p,6,COLORS[2],.6)

func dodge(direction: Vector3,free: bool = false) -> bool:
	if not free and (dash_clock>0 or stamina<20): return false
	cast_slot = -1
	dash_dir = direction.normalized() if direction.length()>.1 else aim
	dash_time = .2
	dash_clock = .75
	invulnerable = .3
	if not free: stamina -= 20
	player.gesture("dash",.2)
	sound.play("dash")
	return true

func drink_potion() -> bool:
	if potions<=0 or hp>=max_hp or state!="combat": return false
	potions -= 1
	hp = minf(max_hp,hp+max_hp*.45)
	ring(player.position,2.0,Color("#b8e9b0"),.5)
	tell("恢复了生命。剩余暖心药剂：%d"%potions,3)
	return true

func shoot(origin: Vector3,direction: Vector3,damage: float,style: int,pierce: int,hostile: bool,size_value: float,explosion: float = 0) -> void:
	if projectiles.size()>=160: return
	var color = Color("#e8a6a0") if hostile else COLORS[style]
	var node = WeaponMesh.create(terrain,style,color,hostile)
	terrain.add_child(node)
	node.scale = Vector3.ONE*size_value
	var pos = origin+Vector3.UP*1.1+direction*.8
	node.position = pos
	node.rotation.y = atan2(direction.x,direction.z)
	projectiles.append({"node":node,"p":pos,"dir":direction,"damage":damage,"speed":12.0 if hostile else (32.0 if style==1 else 24.0),"t":3.5 if hostile else 1.25,"pierce":pierce,"hit":[],"enemy":hostile,"radius":.28*size_value,"explosion":explosion})

func tick_projectiles(delta: float) -> void:
	for b in projectiles.duplicate():
		b.t -= delta
		var old: Vector3 = b.p
		b.p += b.dir*b.speed*delta
		b.p.y = Terrain.height_at(b.p.x,b.p.z)+1.1
		var query = PhysicsRayQueryParameters3D.create(old,b.p,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): b.t = 0
		if b.t>0:
			if b.enemy:
				if Geometry3D.get_closest_point_to_segment(player.position+Vector3.UP,old,b.p).distance_to(player.position+Vector3.UP)<.65+b.radius:
					hurt_player(b.damage); b.t = 0
			else:
				for enemy in enemies.duplicate():
					if not is_instance_valid(enemy) or not enemy.alive or b.hit.has(enemy.get_instance_id()): continue
					var center = enemy.position+Vector3.UP
					if Geometry3D.get_closest_point_to_segment(center,old,b.p).distance_to(center)<(.9 if enemy.boss else .6)+b.radius:
						b.hit.append(enemy.get_instance_id())
						damage_enemy(enemy,b.damage)
						b.pierce -= 1
						if b.explosion>0:
							area_damage(b.p,b.explosion,b.damage*.65)
							ring(b.p,b.explosion,COLORS[1],.45)
							sound.play("explosion")
						if b.pierce<=0: b.t = 0; break
		b.node.position = b.p
		if b.t<=0:
			b.node.queue_free()
			projectiles.erase(b)

func spawn_enemy(kind: int,p: Vector2,site_id: String,is_boss: bool = false):
	var enemy = Actor.new()
	enemy.enemy_kind = kind
	enemy.boss = is_boss
	enemy.hp = 1300 if is_boss else (85 if kind==3 else 60)
	enemy.max_hp = enemy.hp
	enemy.origin_site = site_id
	add_child(enemy)
	enemy.position = Terrain.ground(p)+Vector3.UP*.3
	enemy.set_meta("home",enemy.position)
	enemies.append(enemy)
	return enemy

func tick_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or not enemy.alive: continue
		enemy.attack_clock -= delta
		var toward: Vector3 = player.position-enemy.position
		toward.y = 0
		var distance_value = toward.length()
		var desired = toward.normalized()
		var returning_home = distance_value>25
		if returning_home:
			var home: Vector3 = enemy.get_meta("home")
			desired = (home-enemy.position).normalized() if flat_distance(home,enemy.position)>1 else Vector3.ZERO
		# Local obstacle avoidance around 3D trunks and rocks; no 2D nav grid.
		for obstacle in terrain.obstacles:
			var away = Vector3(enemy.position.x-obstacle.x,0,enemy.position.z-obstacle.y)
			if away.length()<obstacle.z+1.25:
				desired += away.normalized()*(obstacle.z+1.25-away.length())*2
		var speed = 2.1 if enemy.boss else (2.6 if enemy.enemy_kind==3 else 3.15)
		if enemy.enemy_kind==2 and distance_value<8: desired = -toward.normalized()*.35
		elif distance_value<1.8 or enemy.windup>0: desired = Vector3.ZERO
		enemy.velocity.x = desired.limit_length(1).x*speed
		enemy.velocity.z = desired.limit_length(1).z*speed
		enemy.velocity.y -= delta*24
		enemy.move_and_slide()
		enemy.sync_visual(delta,screen_direction(toward))
		if enemy.windup>0:
			enemy.windup -= delta
			if enemy.windup<=0 and distance_value<2.5: hurt_player(12)
		elif enemy.attack_clock<=0 and distance_value<15:
			if enemy.boss:
				enemy.attack_clock = 2.0 if enemy.hp<enemy.max_hp*.5 else 2.7
				for i in range(7 if enemy.hp<enemy.max_hp*.5 else 5):
					shoot(enemy.position,toward.normalized().rotated(Vector3.UP,(i-3)*.18),14,1,1,true,1)
				add_hazard(player.position,3,18,.95)
			elif enemy.enemy_kind==2:
				enemy.attack_clock = 2.5
				shoot(enemy.position,toward.normalized(),10,1,1,true,.9)
			elif distance_value<2.3:
				enemy.windup = .55
				enemy.attack_clock = 1.7
				ring(enemy.position,1.6,Color("#f1b9a5"),.55)

func hurt_player(amount: float) -> void:
	if state!="combat" or invulnerable>0: return
	hp = maxf(0,hp-amount)
	invulnerable = .55
	player.hit_flash = .15
	player.gesture("hurt",.2)
	sound.play("hurt")
	if hp<=0:
		cast_slot = -1
		discard_checkpoint()
		set_state("end")
		ui.show_result(false)

func damage_enemy(enemy,amount: float) -> void:
	if not is_instance_valid(enemy) or not enemy.alive: return
	var critical = rng.randf()<minf(.7,.1+float(buffs.get("crit",0)))
	var actual = amount*(1.7 if critical else 1.0)
	var defeated: bool = enemy.damage(actual)
	number(enemy.position+Vector3.UP*2.1,str(roundi(actual)),Color("#ffe8a2") if critical else Color.WHITE)
	if defeated:
		kills += 1
		coins += 60 if enemy.boss else 6
		xp += 80 if enemy.boss else 15
		while xp>=45+level*15:
			xp -= 45+level*15
			level += 1
			max_hp += 8
			hp = minf(max_hp,hp+18)
			tell("等级提升至 Lv.%d · 攻击与生命提高"%level,3)
		var was_boss: bool = enemy.boss
		enemies.erase(enemy)
		enemy.queue_free()
		if was_boss:
			cleared.boss = true
			discard_checkpoint()
			saved_wins += 1
			save_progress()
			set_state("end")
			ui.show_result(true)

func nearest_enemy(pos: Vector3):
	var best = null
	var distance_value = 30.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.alive: continue
		var distance_now = enemy.position.distance_to(pos)
		if distance_now<distance_value: best = enemy; distance_value = distance_now
	return best

func area_damage(pos: Vector3,radius: float,amount: float) -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and flat_distance(enemy.position,pos)<radius: damage_enemy(enemy,amount)

static func flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))

func tick_ongoing_skills(delta: float) -> void:
	if orbit_time>0:
		orbit_time -= delta
		orbit_tick -= delta
		if orbit_tick<=0:
			orbit_tick = .4
			ring(player.position,3.2,COLORS[0],.35)
			area_damage(player.position,3.3,power()*.7)
	if ultimate_time>0:
		ultimate_time -= delta
		ultimate_tick -= delta
		if ultimate_tick<=0:
			ultimate_tick = .2 if selected_role==1 else .35
			var target = nearest_enemy(player.position)
			var pos: Vector3 = target.position if target!=null else player.position+aim*7
			if selected_role==1:
				shoot(player.position,(pos-player.position).normalized(),power()*1.15,1,3,false,1.6,1.8)
			else:
				area_damage(pos,3.3,power()*(1.7 if selected_role==0 else 1.45))
				falling_blade(pos,selected_role,1.0)
		if ultimate_time<=0:
			var target = nearest_enemy(player.position)
			var pos: Vector3 = target.position if target!=null else player.position+aim*6
			area_damage(pos,6,power()*5)
			falling_blade(pos,selected_role,2.3)
			ring(pos,6,COLORS[selected_role],.75)
			player.gesture("ultimate_finish",.65)
			sound.play("ultimate_%d_finish"%selected_role)

func add_hazard(pos: Vector3,radius: float,damage: float,delay: float) -> void:
	ring(pos,radius,Color("#f6a492"),delay)
	hazards.append({"p":pos,"radius":radius,"damage":damage,"t":delay,"friendly":false})

func tick_hazards(delta: float) -> void:
	for hazard in hazards.duplicate():
		hazard.t -= delta
		if hazard.t>0: continue
		if hazard.friendly:
			area_damage(hazard.p,hazard.radius,hazard.damage)
			falling_blade(hazard.p,2,.8)
		else:
			if flat_distance(player.position,hazard.p)<hazard.radius: hurt_player(hazard.damage)
			ring(hazard.p,hazard.radius,Color("#f8d2bb"),.3)
		hazards.erase(hazard)

func ring(pos: Vector3,radius: float,color: Color,duration: float) -> void:
	if effects.size()>100: return
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		var a = Vector2.from_angle(float(i)/64*TAU)
		var b = Vector2.from_angle(float(i+1)/64*TAU)
		for offset in [a*radius,a*radius*.94,b*radius,b*radius,a*radius*.94,b*radius*.94]:
			surface.add_vertex(Vector3(offset.x,Terrain.height_at(pos.x+offset.x,pos.z+offset.y)-pos.y+.09,offset.y))
	surface.generate_normals()
	var node = terrain.mesh_node(surface.commit(),pos,color)
	node.material_override = terrain.material(color,.2,.5)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.append({"node":node,"t":duration,"max":duration,"type":"ring"})

func falling_blade(pos: Vector3,style: int,size_value: float) -> void:
	var node = WeaponMesh.create(terrain,style,COLORS[style])
	terrain.add_child(node)
	node.position = pos+Vector3.UP*6
	node.rotation.x = PI/2
	node.scale = Vector3.ONE*(size_value*2.1)
	effects.append({"node":node,"t":.5,"max":.5,"type":"blade","ground":pos.y})

func number(pos: Vector3,text_value: String,color: Color) -> void:
	if effects.size()>90: return
	var node = Label3D.new()
	node.text = text_value
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.position = pos
	node.font_size = 38
	node.outline_size = 9
	node.pixel_size = .013
	node.modulate = color
	add_child(node)
	effects.append({"node":node,"t":.65,"max":.65,"type":"number"})

func tick_effects(delta: float) -> void:
	for effect in effects.duplicate():
		effect.t -= delta
		if not is_instance_valid(effect.node): effects.erase(effect); continue
		if effect.type=="number": effect.node.position.y += delta*1.8
		elif effect.type=="blade": effect.node.position.y = maxf(effect.ground,effect.node.position.y-delta*30)
		if effect.t<=0: effect.node.queue_free(); effects.erase(effect)

func clear_transients() -> void:
	for entry in projectiles+effects:
		if is_instance_valid(entry.node): entry.node.free()
	projectiles.clear()
	effects.clear()
	hazards.clear()

func tick_exploration() -> void:
	for site in sites:
		var distance_value = Vector2(player.position.x,player.position.z).distance_to(site.pos)
		if distance_value<18 and not discovered.has(site.id):
			discovered[site.id] = true
			tell("发现："+site.name,3)
		if site.kind=="camp" and distance_value<9 and not engaged_camps.has(site.id) and not cleared.has(site.id): begin_camp(site)
	for id in engaged_camps.keys():
		if enemies.any(func(enemy): return is_instance_valid(enemy) and enemy.origin_site==id): continue
		engaged_camps.erase(id)
		cleared[id] = true
		pending_rewards.append(id)
	if not pending_rewards.is_empty():
		reward_site = pending_rewards.pop_front()
		hp = minf(max_hp,hp+25)
		open_reward()

func begin_camp(site: Dictionary) -> void:
	active_camp = site.id
	engaged_camps[site.id] = true
	var count = 5 if site.id=="camp_west" else 7
	for i in range(count):
		var point = site.pos+Vector2(cos(i*TAU/count),sin(i*TAU/count))*4
		spawn_enemy(2 if i%3==0 else (3 if i%4==0 else 0),point,site.id)
	tell(site.name+"：清理拦路的魔物，可获得一次祝福。",4)

func interaction_site() -> Dictionary:
	for site in sites:
		if site.kind=="camp" or claimed.has(site.id): continue
		if Vector2(player.position.x,player.position.z).distance_to(site.pos)<3.8: return site
	return {}

func interact() -> bool:
	if state!="combat": return false
	var site = interaction_site()
	if site.is_empty(): return false
	if enemies.any(func(enemy): return is_instance_valid(enemy) and flat_distance(enemy.position,player.position)<14):
		tell("先处理身边的魔物，再与这里交互。",3)
		return false
	if site.kind=="hearth":
		var reason = checkpoint_block_reason()
		if not reason.is_empty():
			tell(reason,3)
			return false
		hp = max_hp
		stamina = 100
		cooldowns = [0.0,0.0,0.0,0.0]
		if not rested.has(site.id): potions = mini(5,potions+1)
		rested[site.id] = true
		sound.play("reward")
		if save_checkpoint(false): tell(site.name+" · 生命已恢复，旅程已保存。",4)
		return true
	if site.kind=="boss":
		if runes<3: tell("圣庭尚未苏醒：需要唤醒三处符文（%d / 3）。"%runes,4); return false
		claimed[site.id] = true
		spawn_enemy(13,site.pos+Vector2(0,-4),"boss",true)
		boss_intro_time = .65
		tell("霜角守望者 · 请以勇气证明自己",5)
		sound.play("boss")
		return true
	claimed[site.id] = true
	terrain.activate(site.id)
	if site.kind=="rune":
		runes += 1
		hp = minf(max_hp,hp+20)
		coins += 15
		tell("符文回应了你（%d / 3）· 恢复 20 生命"%runes,4)
		ring(player.position,3,Color("#b6e6d0"),.8)
	else:
		coins += 45
		potions += 1
		reward_site = site.id
		open_reward()
	sound.play("reward")
	if site.kind=="rune": save_checkpoint(false)
	return true

func open_reward() -> void:
	reward_options.clear()
	var pool = range(BOONS.size())
	for i in range(3):
		var pick = rng.randi_range(0,pool.size()-1)
		reward_options.append(pool[pick])
		pool.remove_at(pick)
	cast_slot = -1
	set_state("reward")
	ui.show_reward()

func choose_reward(index: int) -> bool:
	if state!="reward" or index<0 or index>=reward_options.size(): return false
	var boon: Array = BOONS[reward_options[index]]
	buffs[boon[2]] = float(buffs.get(boon[2],0))+float(boon[3])
	if boon[2]=="health": max_hp += boon[3]; hp = minf(max_hp,hp+float(boon[3]))
	reward_options.clear()
	set_state("combat")
	ui.clear_modal()
	tell("获得祝福："+boon[0],4)
	save_checkpoint(false)
	return true

func checkpoint_block_reason() -> String:
	if state not in ["combat", "paused", "map"] or hp <= 0: return "当前无法保存旅程。"
	if not enemies.is_empty() or not engaged_camps.is_empty(): return "战斗中无法保存，请先结束当前遭遇。"
	if not pending_rewards.is_empty() or not reward_options.is_empty(): return "请先领取旅途祝福。"
	if cast_slot >= 0 or ultimate_time > 0 or orbit_time > 0 or dash_time > 0: return "请等待当前动作与技能结束。"
	if not hazards.is_empty(): return "请离开危险并等待攻击结束。"
	if projectiles.any(func(b): return b.enemy): return "请等待敌方弹体消散后再保存。"
	return ""

func save_checkpoint(show_notice: bool = true) -> bool:
	var reason = checkpoint_block_reason()
	if not reason.is_empty():
		if show_notice: tell(reason,4)
		return false
	var data = {
		"version":Checkpoint.VERSION, "role":selected_role, "hp":hp, "max_hp":max_hp,
		"level":level, "xp":xp, "coins":coins, "kills":kills, "elapsed":elapsed,
		"potions":potions, "runes":runes, "position":[player.position.x,player.position.z],
		"claimed":claimed.duplicate(true), "cleared":cleared.duplicate(true),
		"discovered":discovered.duplicate(true), "buffs":buffs.duplicate(true),
		"rested":rested.duplicate(true), "cooldowns":cooldowns.duplicate(), "waypoint":waypoint
	}
	var error: Error = OK if test_mode else Checkpoint.write_file(data)
	if error != OK:
		tell("旅程保存失败，请检查存储空间。原存档会保留。",5)
		return false
	checkpoint = data
	if show_notice: tell("旅程已保存 · 可从主菜单继续",3)
	return true

func discard_checkpoint() -> void:
	checkpoint.clear()
	if not test_mode: Checkpoint.clear_file()

func continue_run() -> bool:
	if not Checkpoint.valid(checkpoint): return false
	var data = checkpoint.duplicate(true)
	# Reset all transient objects before restoring only validated durable state.
	start_run(int(data.role),false)
	for key in ["hp","max_hp","level","xp","coins","kills","elapsed","potions","runes"]: set(key,data[key])
	for key in ["claimed","cleared","discovered","buffs","rested"]: set(key,data[key].duplicate(true))
	cooldowns = data.cooldowns.duplicate()
	for id in claimed: terrain.activate(id)
	player.position = Terrain.ground(Vector2(data.position[0],data.position[1]))+Vector3.UP*.12
	player.velocity = Vector3.ZERO
	camera.position = player.position+camera_offset
	waypoint = str(data.get("waypoint",""))
	checkpoint = data
	tell("欢迎回来。符文、祝福与已清理营地均已恢复。",5)
	return true

func set_waypoint(id: String) -> bool:
	for site in sites:
		if site.id==id and discovered.has(id):
			waypoint = id
			return true
	return false

func waypoint_text() -> String:
	for site in sites:
		if site.id!=waypoint: continue
		var distance_value = Vector2(player.position.x,player.position.z).distance_to(site.pos)
		var direction = screen_direction(Terrain.ground(site.pos)-player.position)
		var arrow_index = posmod(roundi(direction.angle()/(PI/4)),8)
		return "%s %s · %dm"%[["→","↘","↓","↙","←","↖","↑","↗"][arrow_index],site.name,roundi(distance_value)]
	return "M 打开地图 · 点击已发现地标设置路标"

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(player) and checkpoint_block_reason().is_empty(): save_checkpoint(false)
		get_tree().quit()

func objective() -> String:
	if runes<3: return "唤醒雪原符文  %d / 3"%runes
	return "前往北方圣庭 · 与霜角守望者对话"

func tell(text_value: String,duration: float = 4) -> void:
	notice = text_value
	notice_time = duration

func load_progress() -> void:
	if test_mode: return
	var config = ConfigFile.new()
	if config.load("user://frontier_progress.cfg")==OK:
		saved_wins = int(config.get_value("progress","wins",0))
		selected_role = clampi(int(config.get_value("progress","role",0)),0,2)

func save_progress() -> void:
	if test_mode: return
	var config = ConfigFile.new()
	config.set_value("progress","wins",saved_wins)
	config.set_value("progress","role",selected_role)
	config.save("user://frontier_progress.cfg")
