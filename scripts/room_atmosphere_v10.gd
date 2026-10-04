extends Node2D
## Subtle chapter-specific motion layered above scene art and below gameplay actors.
var room
var theme: int = 0
var clock: float = 0.0
var motes: Array[Dictionary] = []
var smoke = preload("res://art/v6/fx/smoke_01.png")
const COLORS = [Color("#e8dcae"),Color("#ff9b55"),Color("#8fdcff"),Color("#ffd0d8"),Color("#d1b06a"),Color("#b8bcff")]

func _ready() -> void:
	z_index = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 98173+theme*701
	for i in range(34):
		motes.append({
			"p":Vector2(rng.randf_range(95,1825),rng.randf_range(185,925)),
			"speed":rng.randf_range(7.0,18.0),
			"phase":rng.randf_range(0,TAU),
			"size":rng.randf_range(1.8,4.8)
		})
	queue_redraw()

func _process(delta: float) -> void:
	var strength := 1.0
	if room!=null and room.run!=null:
		var game = room.run.game
		strength = game.effects_intensity
		if game.reduced_motion: delta *= 0.15
	clock += delta
	modulate.a = clampf(.45+strength*.55,.45,1.0)
	queue_redraw()

func _draw() -> void:
	var color: Color = COLORS[clampi(theme,0,COLORS.size()-1)]
	# Fog remains near the perimeter so silhouettes stay clean in the combat core.
	for i in range(5):
		var side := -1.0 if i%2==0 else 1.0
		var p := Vector2(130 if side<0 else 1790,250+i*145+sin(clock*.22+i)*22)
		var size := Vector2(250,150)*(0.82+0.08*sin(clock*.35+i))
		draw_texture_rect(smoke,Rect2(p-size*.5,size),false,Color(color,.025))
	for i in range(motes.size()):
		var mote := motes[i]
		var base: Vector2 = mote.p
		var y := fposmod(base.y-(clock*mote.speed),740.0)+185.0
		var x := base.x+sin(clock*.55+mote.phase)*24.0
		var p := Vector2(x,y)
		var radius: float = mote.size*(.75+.25*sin(clock*1.7+mote.phase))
		match theme:
			0:
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius*.55,0),p+Vector2(0,radius),p-Vector2(radius*.55,0)]),Color(color,.22))
			1:
				draw_circle(p,radius,Color(color,.28));draw_line(p,p+Vector2(-2,8),Color(color,.13),1.5,true)
			2:
				draw_arc(p,radius*1.8,clock+mote.phase,clock+mote.phase+PI*1.25,8,Color(color,.20),1.2,true)
			3:
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,0),p+Vector2(0,radius*.45),p-Vector2(radius,0)]),Color(color,.21))
			4:
				draw_circle(p,radius*.7,Color(color,.18));draw_arc(p,radius*1.8,0,TAU,8,Color(color,.13),1.0,true)
			5:
				draw_circle(p,radius*.48,Color.WHITE);draw_line(p-Vector2(radius*2,0),p+Vector2(radius*2,0),Color(color,.19),1,true);draw_line(p-Vector2(0,radius*2),p+Vector2(0,radius*2),Color(color,.19),1,true)
