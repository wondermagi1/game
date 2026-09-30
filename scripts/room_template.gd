@tool
extends Node2D
## Editable room templates. Collision rectangles are authored in each .tscn.
@export_range(0,5) var theme: int = 0
@export var layout_name: String = "开阔庭院"
var gates: Array = []
var doors: Array = []
var cleared: bool = true
var event_name: String = ""
var event_used: bool = false
var run
var clue: bool = false
var clue_count: int = 0
var crates: Array = []
var obstacles: Array[Rect2] = []
var navigation = AStarGrid2D.new()
var font = SystemFont.new()
const COLORS = [Color("#79ccb5"),Color("#caaa79"),Color("#b09bcf"),Color("#ce8b9e"),Color("#d99a65"),Color("#929de0")]
func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	for child in get_children():
		if child is StaticBody2D:
			var shape = child.get_node_or_null("Shape")
			if shape and shape.shape is RectangleShape2D: obstacles.append(Rect2(child.position-shape.shape.size*0.5,shape.shape.size))
	build_navigation()
func build_navigation() -> void:
	navigation.region = Rect2i(0,0,48,27)
	navigation.cell_size = Vector2(40,40)
	navigation.offset = Vector2(20,20)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(48):
		for y in range(27):
			var p = Vector2(x*40+20,y*40+20)
			var blocked = not Rect2(100,190,1720,730).has_point(p)
			for rect in obstacles:
				if rect.grow(34).has_point(p): blocked = true
			navigation.set_point_solid(Vector2i(x,y),blocked)
func safe(pos: Vector2, margin: float = 42) -> Vector2:
	var p = Vector2(clampf(pos.x,70+margin,1850-margin),clampf(pos.y,160+margin,950-margin))
	for rect in obstacles:
		var grown = rect.grow(margin)
		if grown.has_point(p):
			var candidates = [Vector2(grown.position.x-1,p.y),Vector2(grown.end.x+1,p.y),Vector2(p.x,grown.position.y-1),Vector2(p.x,grown.end.y+1)]
			candidates.sort_custom(func(a,b): return a.distance_squared_to(p)<b.distance_squared_to(p))
			p = candidates[0]
	return p
func navigate(from_world: Vector2, to_world: Vector2) -> Vector2:
	var from = Vector2i((safe(to_local(from_world),55))/40)
	var target = Vector2i((safe(to_local(to_world),55))/40)
	if not navigation.is_in_boundsv(from) or not navigation.is_in_boundsv(target): return from_world.direction_to(to_world)
	if navigation.is_point_solid(from) or navigation.is_point_solid(target): return from_world.direction_to(to_world)
	var path = navigation.get_point_path(from,target)
	if path.size()>1: return from_world.direction_to(to_global(path[1]))
	return from_world.direction_to(to_world)
func wall(rect: Rect2, gate: bool = false) -> void:
	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	if gate: gates.append(collision)
func configure(exits: Array, done: bool, title: String = "", used: bool = false) -> void:
	if run!=null and run.data.get("capybara",false) and not has_node("SpringWater"):
		var spring=preload("res://scripts/ambient_v6.gd").new();spring.name="SpringWater";spring.room=self;add_child(spring)
	doors = exits
	event_name = title
	event_used = used
	for rect in [Rect2(45,135,835,25),Rect2(1040,135,835,25),Rect2(45,950,835,25),Rect2(1040,950,835,25),Rect2(45,160,25,315),Rect2(45,635,25,315),Rect2(1850,160,25,315),Rect2(1850,635,25,315)]: wall(rect)
	for dir in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var has_exit = false
		for door in exits:
			if Vector2(door.dir[0],door.dir[1])==dir: has_exit = true
		var pos = portal(dir)
		var rect = Rect2(pos-Vector2(12,80),Vector2(24,160)) if dir.x!=0 else Rect2(pos-Vector2(80,12),Vector2(160,24))
		wall(rect,has_exit)
	set_clear(done)
func portal(dir: Vector2) -> Vector2:
	return Vector2(60 if dir.x<0 else (1860 if dir.x>0 else 960),145 if dir.y<0 else (965 if dir.y>0 else 555))
func set_clear(value: bool) -> void:
	cleared = value
	for collision in gates: collision.set_deferred("disabled",value)
	queue_redraw()
func _draw() -> void:
	var c = COLORS[theme]
	draw_rect(Rect2(0,0,1920,1080),Color("#080e18"))
	draw_rect(Rect2(70,160,1780,790),Color("#142333").lerp(c,0.07))
	var atlas = preload("res://scripts/presentation.gd").FLOORS
	var region = Rect2((theme%3)*512,floori(theme/3.0)*512,512,512)
	# Use near-native texel scale rather than stretching one square across the arena.
	for row in range(2):
		for col in range(4):
			var p=Vector2(70+col*445,160+row*395)
			draw_texture_rect_region(atlas,Rect2(p,Vector2(445,395)),region,Color(.64,.69,.73,.73))
	if run!=null and run.data.get("capybara",false): draw_onsen()
	for x in range(70,1850,80):
		for y in range(160,950,80):
			var tile = Rect2(x+2,y+2,76,76)
			draw_rect(tile,Color(c,0.035 if (x+y)%160==70 else 0.06))
	# Six architectural vocabularies: garden, timber, runes, altar, machinery, stars.
	for side in [0,1]:
		for i in range(6):
			var p = Vector2(160+i*320,210+side*690)
			match theme:
				0:
					draw_circle(p,18,Color("#386a59")); draw_circle(p+Vector2(12,-8),12,Color("#508476"))
				1:
					draw_line(p-Vector2(25,0),p+Vector2(25,0),Color("#825f43"),12); draw_circle(p,10,Color("#eda15f"))
				2:
					draw_arc(p,22,0,TAU,6,c,2); draw_line(p-Vector2(10,12),p+Vector2(10,-12),c,3)
				3:
					draw_colored_polygon(PackedVector2Array([p+Vector2(0,-28),p+Vector2(25,10),p+Vector2(-25,10)]),c.darkened(0.6)); draw_circle(p,6,c)
				4:
					draw_arc(p,22,0,TAU,12,c,6); draw_line(p-Vector2(25,0),p+Vector2(25,0),c.darkened(0.4),8)
				5:
					draw_arc(p,25,0,TAU,4,c,2); draw_line(p-Vector2(0,35),p+Vector2(0,35),Color(c,0.4),2)
	for rect in obstacles:
		draw_rect(Rect2(rect.position+Vector2(7,10),rect.size),Color(0,0,0,0.35))
		draw_rect(rect,c.darkened(0.72))
		draw_rect(rect.grow(-7),c.darkened(0.5))
		draw_texture_rect_region(atlas,Rect2(rect.position+Vector2(5,-10),rect.size-Vector2(10,0)),Rect2(region.position+Vector2(60,40),Vector2(230,180)),Color(.75,.77,.8))
		draw_rect(Rect2(rect.position+Vector2(0,rect.size.y-12),Vector2(rect.size.x,15)),c.darkened(.8))
		draw_line(rect.position,Vector2(rect.end.x,rect.position.y),c.lightened(0.1),4)
		if theme==1 or theme==4:
			draw_line(rect.position+Vector2(6,6),rect.end-Vector2(6,6),Color(c,0.4),4)
		else: draw_arc(rect.get_center(),minf(25,rect.size.y*0.25),0,TAU,4+theme,Color(c,0.7),2)
	draw_rect(Rect2(70,160,1780,790),Color(c,0.45),false,5)
	for door in doors:
		var dir = Vector2(door.dir[0],door.dir[1])
		var p = portal(dir)
		var col = c if cleared else Color("#da7386")
		draw_line(p-dir*90,p+dir*10,Color(col,0.22),100)
		draw_arc(p-dir*30,45,0,TAU,6,col,3,true)
		var label_pos = p-dir*120+Vector2(-55,-20)
		draw_string(font,label_pos,str(door.label) if cleared else "战斗封锁",HORIZONTAL_ALIGNMENT_LEFT,-1,20,col)
	if not event_name.is_empty():
		var p = Vector2(960,540)
		var col = c.darkened(0.5) if event_used else Color("#f1d28e")
		draw_rect(Rect2(p-Vector2(38,22),Vector2(76,52)),col.darkened(0.6))
		draw_arc(p,48,0,TAU,6,col,3,true)
		draw_circle(p,12,col)
		draw_string(font,p+Vector2(-95,-70),event_name+(" · 已使用" if event_used else ""),HORIZONTAL_ALIGNMENT_LEFT,-1,23,col)
	if clue:
		for i in range(3):
			var p = Vector2(900+i*60,193)
			var color = Color("#98efcd") if i<clue_count else Color("#a391d4")
			draw_arc(p,17,0,TAU,4,color,2)
			draw_line(p-Vector2(0,14),p+Vector2(0,14),color,3)
		draw_string(font,Vector2(830,242),"裂纹中有三道微光 · 靠近交互",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#b9abd7"))

func draw_onsen() -> void:
	draw_rect(Rect2(75,165,1770,780),Color("#665e4c"))
	for row in range(8):
		for col in range(18):
			var pos = Vector2(85+col*97+(row%2)*12,175+row*96)
			draw_style_box(stone_style(),Rect2(pos,Vector2(90,88)))
			draw_texture_rect_region(preload("res://scripts/presentation.gd").FLOORS,Rect2(pos+Vector2(5,5),Vector2(80,78)),Rect2(35+(col%3)*60,30+(row%3)*75,110,110),Color(.83,.78,.65,.65))
	draw_set_transform(Vector2(960,550),0,Vector2(1.8,.8))
	draw_circle(Vector2.ZERO,235,Color("#867760"))
	draw_circle(Vector2.ZERO,220,Color("#689f9b"))
	for r in [90,145,205]: draw_arc(Vector2.ZERO,r,0,TAU,64,Color(.7,.91,.83,.30),2,true)
	draw_set_transform(Vector2.ZERO)
	for side in [0,1]:
		for i in range(5):
			var pos = Vector2(300+i*315,235+side*635)
			draw_circle(pos,21,Color("#67866b"))
			draw_circle(pos+Vector2(13,-9),15,Color("#8baa7c"))
			draw_circle(pos+Vector2(-12,2),12,Color("#bad69a"))
	draw_string(font,Vector2(780,325),"噜噜温泉 · 浅水可通行",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("#e9e2b9"))
var stone: StyleBoxFlat
func stone_style() -> StyleBoxFlat:
	if stone==null:
		stone = StyleBoxFlat.new()
		stone.bg_color = Color("#8b8472")
		stone.border_color = Color("#a6a18a")
		stone.set_border_width_all(2)
		stone.set_corner_radius_all(15)
	return stone
func add_crates(broken_ids: Array) -> void:
	for i in range(2):
		var id = "crate_%d"%i
		if broken_ids.has(id): continue
		var crate = preload("res://scripts/breakable_cover.gd").new()
		crate.uid = id
		crate.room = self
		crate.position = Vector2(350+i*1220,770)
		add_child(crate)
		crates.append(crate)
		obstacles.append(Rect2(crate.position-Vector2(32.5,32.5),Vector2(65,65)))
	build_navigation()
func destroy_crate(crate) -> void:
	crates.erase(crate)
	obstacles.erase(Rect2(crate.position-Vector2(32.5,32.5),Vector2(65,65)))
	build_navigation()
	if run!=null and run.active:
		run.current().broken.append(crate.uid)
		run.game.fx.burst(crate.global_position,Color("#c6a071"),14)
		run.game.sound.play("hit")
func damage_cover(pos: Vector2, radius: float, amount: float) -> void:
	for crate in crates.duplicate():
		if is_instance_valid(crate) and crate.global_position.distance_to(pos)<radius+32: crate.hurt(amount)
