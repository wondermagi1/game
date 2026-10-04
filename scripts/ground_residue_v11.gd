extends Node2D
## Visual-only ground marks. Damage-over-time remains owned by combat zones.
var game
var residues: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
const COLORS = [Color("#78eadc"),Color("#ff9b55"),Color("#b5e8aa")]

func _ready() -> void:
	z_index = 3
	rng.seed = 110917

func add(pos: Vector2, role: int, radius: float, duration: float = 1.25, power: float = 1.0) -> void:
	if residues.size()>=12: residues.pop_front()
	var branches: Array = []
	var count := 5 if game.effects_intensity<.5 else (8 if game.effects_intensity<.8 else 11)
	for i in range(count):
		var angle := i*TAU/count+rng.randf_range(-.22,.22)
		var reach := radius*rng.randf_range(.48,.92)
		var mid := Vector2.from_angle(angle)*reach*.52+Vector2.from_angle(angle+PI*.5)*rng.randf_range(-12,12)
		branches.append([mid,Vector2.from_angle(angle)*reach])
	residues.append({"p":pos,"role":clampi(role,0,2),"r":radius,"life":duration,"max":duration,"power":power,"branches":branches,"spin":rng.randf()*TAU})
	queue_redraw()

func _process(delta: float) -> void:
	if game.state not in ["combat","end"]: return
	for mark in residues: mark.life -= delta
	residues = residues.filter(func(mark): return mark.life>0)
	queue_redraw()

func clear() -> void:
	residues.clear()
	queue_redraw()

func _draw() -> void:
	for mark in residues:
		var phase: float = 1.0-mark.life/mark.max
		var fade: float = smoothstep(1.0,.58,phase)
		var color: Color = COLORS[mark.role]
		draw_set_transform(mark.p,0,Vector2(1,.42))
		match int(mark.role):
			0:
				for branch in mark.branches:
					draw_polyline(PackedVector2Array([Vector2.ZERO,branch[0],branch[1]]),Color(color,.34*fade),3.0,true)
					draw_line(branch[0],branch[0]+branch[1].orthogonal().normalized()*12,Color("#d7fff5",.18*fade),1.5,true)
				draw_arc(Vector2.ZERO,mark.r*.34,mark.spin+phase,mark.spin+phase+TAU*.78,32,Color(color,.30*fade),3,true)
			1:
				draw_circle(Vector2.ZERO,mark.r*.58,Color("#160d0b",.32*fade))
				draw_arc(Vector2.ZERO,mark.r*.52,0,TAU,48,Color("#6d2815",.42*fade),8,true)
				for branch in mark.branches:
					draw_circle(branch[0],3.5,Color("#ff8b3d",.40*fade))
			2:
				var previous := Vector2.ZERO
				for i in range(mark.branches.size()):
					var star: Vector2 = mark.branches[i][0]
					if i>0: draw_line(previous,star,Color(color,.24*fade),1.5,true)
					draw_circle(star,3.2,Color("#fff3b0",.46*fade))
					previous = star
				draw_arc(Vector2.ZERO,mark.r*.56,mark.spin-phase,mark.spin-phase+TAU*.72,40,Color(color,.27*fade),2,true)
		draw_set_transform(Vector2.ZERO)
