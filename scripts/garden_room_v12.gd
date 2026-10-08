extends "res://scripts/room_template.gd"
## Japanese 2.5D garden: painted volume, foot-based sorting, traversable space.
const MAP_SCALE := .78125
const WORLD := Vector2(3200,2400)
const GROUND = preload("res://art/v12/garden/ground_pixel.png")
const PROPS = preload("res://art/v12/garden/props_pixel.png")
const Prop = preload("res://scripts/garden_prop_v12.gd")
const REGIONS = [Rect2(22,18,528,484),Rect2(581,42,427,461),Rect2(1033,42,469,459),Rect2(27,518,494,483),Rect2(645,565,250,420),Rect2(1044,542,445,445)]
var ponds: Array[PackedVector2Array] = []
var water_layers: Array[Polygon2D] = []
var props: Array[Node2D] = []
var caches := [Vector2(1110,2630)*MAP_SCALE,Vector2(3410,1430)*MAP_SCALE]
var area_name := "薄樱参道"
var ambient_clock := 0.0

func has_depth() -> bool:
	return true
func combat_ready(actor_world: Vector2) -> bool:
	return to_local(actor_world).distance_to(event_position())<650
func arena_rect() -> Rect2:
	return Rect2(80,80,WORLD.x-160,WORLD.y-160)
func entry_position() -> Vector2:
	return Vector2(2048,1810)*MAP_SCALE
func event_position() -> Vector2:
	return Vector2(2048,1750)*MAP_SCALE
func camera_target(actor_world: Vector2) -> Vector2:
	var p := to_local(actor_world)+Vector2(0,-160)
	# The lower 150 pixels of the HUD stay away from the hero's centre line.
	return to_global(Vector2(clampf(p.x,960,WORLD.x-960),clampf(p.y,540,WORLD.y-540)))
func portal(dir: Vector2) -> Vector2:
	return Vector2(90 if dir.x<0 else (WORLD.x-90 if dir.x>0 else WORLD.x*.5),90 if dir.y<0 else (WORLD.y-90 if dir.y>0 else WORLD.y*.5))

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	z_index = 5
	y_sort_enabled = true
	layout_name = "薄樱神社 · 可探索庭院"
	load_scene_art()
	build_landscape()
	build_navigation()

func load_scene_art() -> void:
	if has_node("GardenGround"): return
	scene_background = GROUND
	var ground = Sprite2D.new()
	ground.name = "GardenGround"
	ground.texture = GROUND
	ground.centered = false
	ground.scale = WORLD/GROUND.get_size()
	ground.z_as_relative = false
	ground.z_index = -2
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.modulate = Color(.86,.90,.86)
	add_child(ground)
	var atmosphere = preload("res://scripts/garden_atmosphere_v12.gd").new()
	atmosphere.name = "GardenAtmosphere"
	atmosphere.room = self
	add_child(atmosphere)

func source_polygon(points: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for p in points: polygon.append(Vector2(p[0],p[1])*WORLD/Vector2(1448,1086))
	return polygon

func build_landscape() -> void:
	# Shorelines follow the actual pixels, leaving both cross paths and the
	# outer stepping-stone loops connected. Water is not a rectangular blocker.
	add_pond(source_polygon([[1038,216],[1074,192],[1176,167],[1227,170],[1260,191],[1262,224],[1298,262],[1350,286],[1378,321],[1390,376],[1373,409],[1343,416],[1292,403],[1253,357],[1233,324],[1160,302],[1090,300],[1047,271]]))
	add_pond(source_polygon([[102,798],[127,773],[181,759],[231,778],[269,807],[271,840],[242,865],[184,871],[137,855],[108,831]]))
	add_prop(0,Vector2(1280,1685),Vector2(800,620),Rect2(-330,-135,660,140))
	add_prop(1,Vector2(2048,1610),Vector2(540,490))
	# Only the two posts collide: the opening below the torii remains walkable.
	add_obstacle(Rect2(Vector2(1812,1560)*MAP_SCALE,Vector2(75,55)*MAP_SCALE))
	add_obstacle(Rect2(Vector2(2209,1560)*MAP_SCALE,Vector2(75,55)*MAP_SCALE))
	for spec in [[Vector2(2820,1690),Vector2(570,615)],[Vector2(1080,2200),Vector2(610,660)],[Vector2(2880,2610),Vector2(650,700)],[Vector2(620,1760),Vector2(510,550)]]:
		add_prop(2,spec[0],spec[1],Rect2(-44,-27,88,50),true)
	for p in [Vector2(290,545),Vector2(650,495),Vector2(300,1110),Vector2(3850,1960),Vector2(3730,2690),Vector2(485,2880),Vector2(2500,520),Vector2(1150,2960)]:
		add_prop(3,p,Vector2(380,490),Rect2(-95,-38,190,60),true)
	for p in [Vector2(1700,1640),Vector2(2410,1640),Vector2(1710,2220),Vector2(2360,2220),Vector2(2760,750),Vector2(3760,1340),Vector2(1040,2580),Vector2(3335,1410)]:
		add_prop(4,p,Vector2(115,195),Rect2(-24,-23,48,40))
		add_light((p+Vector2(0,-116))*MAP_SCALE)
	add_prop(5,Vector2(3390,2370),Vector2(390,415),Rect2(-107,-62,214,68))
	add_prop(5,Vector2(1220,2570),Vector2(255,280),Rect2(-66,-42,132,48))

func add_prop(index: int, foot: Vector2, dimensions: Vector2, collision: Rect2 = Rect2(), leafy: bool = false) -> void:
	foot *= MAP_SCALE
	dimensions *= MAP_SCALE
	collision = Rect2(collision.position*MAP_SCALE,collision.size*MAP_SCALE)
	var texture = AtlasTexture.new()
	texture.atlas = PROPS
	texture.region = REGIONS[index]
	texture.filter_clip = true
	var prop = Prop.new()
	prop.room = self
	prop.position = foot
	add_child(prop)
	prop.setup(texture,dimensions,leafy)
	props.append(prop)
	if collision.has_area(): add_obstacle(Rect2(foot+collision.position,collision.size))

func add_light(pos: Vector2) -> void:
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(1,.70,.34,.18),Color(1,.72,.36,0)])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	var glow = Sprite2D.new()
	glow.texture = texture
	glow.position = pos
	glow.z_as_relative = false
	glow.z_index = 8
	add_child(glow)

func add_obstacle(rect: Rect2) -> void:
	obstacles.append(rect)
	wall(rect)

func add_pond(polygon: PackedVector2Array) -> void:
	ponds.append(polygon)
	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape = CollisionPolygon2D.new()
	shape.polygon = polygon
	body.add_child(shape)
	add_child(body)
	var water = Polygon2D.new()
	water.polygon = polygon
	water.texture = GROUND
	water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var uv := PackedVector2Array()
	for p in polygon: uv.append(p*GROUND.get_size()/WORLD)
	water.uv = uv
	water.modulate = Color(.86,.90,.86)
	water.z_as_relative = false
	water.z_index = -1
	var surface = ShaderMaterial.new()
	surface.shader = preload("res://art/v12/garden/water.gdshader")
	water.material = surface
	add_child(water)
	water_layers.append(water)

func configure(exits: Array, done: bool, title: String = "", used: bool = false) -> void:
	doors = exits
	event_name = title
	event_used = used
	if run!=null:
		area_name = {"start":"薄樱参道","battle":"落樱练武庭","event":"林间祈愿","boss":"守望神社"}.get(run.current().kind,"薄樱庭院")
	# Closed outer border. Travel triggers at the inner gate before reaching it.
	for rect in [Rect2(40,40,WORLD.x-80,40),Rect2(40,WORLD.y-80,WORLD.x-80,40),Rect2(40,80,40,WORLD.y-160),Rect2(WORLD.x-80,80,40,WORLD.y-160)]: wall(rect)
	for door in doors:
		var dir := Vector2(door.dir[0],door.dir[1])
		var p := portal(dir)
		wall(Rect2(p-Vector2(16,110),Vector2(32,220)) if dir.x!=0 else Rect2(p-Vector2(110,16),Vector2(220,32)),true)
	set_clear(done)

func water_blocked(p: Vector2, margin: float) -> bool:
	for polygon in ponds:
		if Geometry2D.is_point_in_polygon(p,polygon): return true
		for i in range(polygon.size()):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()]))<margin: return true
	return false

func walkable(p: Vector2, margin: float = 34) -> bool:
	if not arena_rect().grow(-margin).has_point(p): return false
	for rect in obstacles:
		if rect.grow(margin).has_point(p): return false
	return not water_blocked(p,margin)

func safe(pos: Vector2, margin: float = 42) -> Vector2:
	var bounds := arena_rect().grow(-margin)
	var p := pos.clamp(bounds.position,bounds.end)
	if walkable(p,margin): return p
	# Search nearby navigable ground, including the complete shoreline. Avoid
	# the old one-pass projection which can push into a second obstacle.
	for radius in range(40,961,40):
		for i in range(32):
			var sample := (p+Vector2.from_angle(TAU*i/32.0)*radius).clamp(bounds.position,bounds.end)
			if walkable(sample,margin): return sample
	return event_position()

func build_navigation() -> void:
	navigation.region = Rect2i(0,0,80,60)
	navigation.cell_size = Vector2(40,40)
	navigation.offset = Vector2(20,20)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(80):
		for y in range(60): navigation.set_point_solid(Vector2i(x,y),not walkable(Vector2(x*40+20,y*40+20),42))

func nearby_spawn(player_world: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var local := to_local(player_world)
	var start := nav_cell(local)
	for i in range(48):
		var candidate := safe(local+Vector2.from_angle(rng.randf_range(0,TAU))*rng.randf_range(500,800),55)
		var target := nav_cell(candidate)
		if candidate.distance_to(local)<450 or candidate.distance_to(local)>950: continue
		if not navigation.get_id_path(start,target).is_empty(): return to_global(candidate)
	return to_global(safe(local+Vector2(520,0),55))

func nav_cell(local: Vector2) -> Vector2i:
	# Do not project a physically valid actor through safe() here. Its wider
	# spawn clearance can push an approaching actor BACK by a whole grid cell,
	# producing a two-frame oscillation at a building corner.
	var cell := Vector2i(local/40)
	if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell): return cell
	# A clear world point can round into a shoreline cell. Find the nearest
	# free grid centre instead of telling an enemy to walk through the shore.
	var best := Vector2i(event_position()/40)
	var distance := INF
	for x in range(-3,4):
		for y in range(-3,4):
			var candidate := cell+Vector2i(x,y)
			if not navigation.is_in_boundsv(candidate) or navigation.is_point_solid(candidate): continue
			var d := (Vector2(candidate)*40+Vector2(20,20)).distance_squared_to(local)
			if d<distance: best=candidate; distance=d
	return best

func navigate(from_world: Vector2, to_world: Vector2) -> Vector2:
	var local := to_local(from_world)
	var path := navigation.get_point_path(nav_cell(local),nav_cell(to_local(to_world)))
	var raw_cell := Vector2i(local/40)
	if not path.is_empty() and (not navigation.is_in_boundsv(raw_cell) or navigation.is_point_solid(raw_cell)):
		return from_world.direction_to(to_global(path[0]))
	if path.size()>1: return from_world.direction_to(to_global(path[1]))
	return from_world.direction_to(to_world)

func add_crates(broken_ids: Array) -> void:
	for i in range(2):
		var id := "crate_%d"%i
		if broken_ids.has(id): continue
		var crate = preload("res://scripts/breakable_cover.gd").new()
		crate.uid = id
		crate.room = self
		crate.position = Vector2(1510+i*1110,2020)*MAP_SCALE
		add_child(crate)
		crates.append(crate)
		obstacles.append(Rect2(crate.position-Vector2(32.5,32.5),Vector2(65,65)))
	build_navigation()

func try_interact(local_pos: Vector2) -> bool:
	if run==null: return false
	for i in range(caches.size()):
		if local_pos.distance_to(caches[i])>125: continue
		var key := "garden_offering_%d"%i
		if run.current().broken.has(key): return false
		run.current().broken.append(key)
		run.grant(65,80,2)
		run.game.sound.play("reward")
		run.game.fx.burst(to_global(caches[i]),Color("#eed695"),14)
		run.game.notify_player("发现林间供奉：金币 +65 · 经验 +80 · 强化材料 +2",5)
		queue_redraw()
		return true
	return false

func _process(delta: float) -> void:
	ambient_clock += delta
	if run!=null:
		for water in water_layers:
			water.material.set_shader_parameter("motion",0.0 if run.game.reduced_motion else run.game.effects_intensity)
	if ambient_clock>.08:
		ambient_clock = 0
		queue_redraw()

func _draw() -> void:
	# Handrails at the perimeter provide a visible reason for the map boundary.
	for y in [86,WORLD.y-86]:
		for x in range(100,int(WORLD.x)-100,110):
			if absf(x-WORLD.x*.5)<120: continue
			draw_line(Vector2(x,y-16),Vector2(x+97,y-16),Color("#837b53"),7)
			draw_line(Vector2(x,y-35),Vector2(x,y+3),Color("#aba276"),9)
	for door in doors:
		var dir := Vector2(door.dir[0],door.dir[1])
		var p := portal(dir)-dir*105
		var col := Color("#eadab4") if cleared else Color("#d48b88")
		draw_circle(p,44,Color(.055,.085,.067,.8))
		draw_arc(p,40,0,TAU,32,col,2,true)
		draw_line(p-dir*20,p+dir*20,col,4,true)
		draw_line(p+dir*20,p+dir.rotated(PI*.7)*14,col,3,true)
		draw_line(p+dir*20,p+dir.rotated(-PI*.7)*14,col,3,true)
		draw_string_outline(font,p+Vector2(-70,74),str(door.label) if cleared else "战斗封锁",HORIZONTAL_ALIGNMENT_LEFT,-1,22,5,Color("#1b2925"))
		draw_string(font,p+Vector2(-70,74),str(door.label) if cleared else "战斗封锁",HORIZONTAL_ALIGNMENT_LEFT,-1,22,col)
	if not event_name.is_empty():
		var p := event_position()
		draw_circle(p,35,Color("#534c36"))
		draw_arc(p,39,0,TAU,8,Color("#e5c68d"),3,true)
		draw_string_outline(font,p+Vector2(-100,-55),event_name+(" · 已使用" if event_used else " · 交互"),HORIZONTAL_ALIGNMENT_LEFT,-1,24,5,Color("#1b2925"))
		draw_string(font,p+Vector2(-100,-55),event_name+(" · 已使用" if event_used else " · 交互"),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("#f7e3b4"))
	for i in range(caches.size()):
		if run==null or run.current().broken.has("garden_offering_%d"%i): continue
		var p: Vector2 = caches[i]
		draw_rect(Rect2(p-Vector2(22,15),Vector2(44,30)),Color("#746046"))
		draw_rect(Rect2(p-Vector2(22,15),Vector2(44,30)),Color("#ddc493"),false,3)
		draw_circle(p+Vector2(0,-26),5,Color("#ffe9ac"))
		if is_instance_valid(run.game.player) and to_local(run.game.player.global_position).distance_to(p)<160:
			draw_string_outline(font,p+Vector2(-62,-62),run.game.bindings.text("interact")+" 林间供奉",HORIZONTAL_ALIGNMENT_LEFT,-1,22,5,Color("#1b2925"))
			draw_string(font,p+Vector2(-62,-62),run.game.bindings.text("interact")+" 林间供奉",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("#f7e3b4"))
