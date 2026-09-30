extends Node2D
## Bounded visual-only weapon instances. Logical hits live in ultimate_controller.
var game
var glyphs: Array = []
const WEAPONS = preload("res://art/v5/weapons.png")
const PALETTE = [Color("#86ffe4"),Color("#ffb269"),Color("#cbb4ff")]
func _ready() -> void:
	z_index = 25
func emit(kind: String, pos: Vector2, direction: Vector2, size: float, duration: float, role: int) -> void:
	if glyphs.size()>=64: glyphs.pop_front()
	glyphs.append({"kind":kind,"p":pos,"dir":direction,"size":size,"life":duration,"max":duration,"role":role})
func _process(delta: float) -> void:
	if game.state not in ["combat","end"]: return
	for g in glyphs: g.life -= delta
	glyphs = glyphs.filter(func(g): return g.life>0)
	queue_redraw()
static func weapon(canvas: CanvasItem, role: int, length: float, width: float, color: Color) -> void:
	var props=preload("res://scripts/weapon_art_v6.gd")
	if role in [0,2]:
		props.draw(canvas,(3 if length>100 else 0) if role==0 else (4 if length>100 else 5),length,Color(1,1,1,color.a))
	else:
		# V5 gunner tracer silhouette, retaining the corrected V6 release position.
		var half=length*.5
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-half,-width),Vector2(half*.5,-width),Vector2(half,0),Vector2(half*.5,width),Vector2(-half,width)]),color)
		canvas.draw_line(Vector2(-half*.6,0),Vector2(half*.6,0),Color("#fff5c7"),width,true)
func _draw() -> void:
	for g in glyphs:
		var progress: float = 1-g.life/g.max
		var color: Color = PALETTE[g.role]
		color.a = minf(1,g.life*5)
		match g.kind:
			"fall", "finish":
				var p: Vector2 = g.p-Vector2(0,pow(1-progress,3)*g.size*1.4)
				draw_set_transform(p,PI*0.5)
				draw_colored_polygon(PackedVector2Array([Vector2(-g.size*1.6,-8),Vector2(g.size*0.4,-g.size*0.07),Vector2(g.size*0.4,g.size*0.07)]),Color(color,0.15))
				weapon(self,g.role,g.size,g.size*0.055,color)
				if progress>0.6:
					draw_set_transform(g.p)
					draw_arc(Vector2.ZERO,g.size*progress*0.5,0,TAU,48,color,3,true)
			"gather":
				draw_set_transform(g.p)
				draw_arc(Vector2.ZERO,g.size,0,TAU,8,color,3,true)
				for i in range(6):
					var angle = i*TAU/6+progress*0.5
					draw_set_transform(g.p+Vector2.from_angle(angle)*g.size,angle+PI)
					weapon(self,g.role,90,6,color)
			"slash":
				draw_set_transform(g.p,g.dir.angle())
				var points = PackedVector2Array()
				for i in range(20): points.append(Vector2.from_angle(-1.2+i*2.4/19)*g.size*(0.6+progress*0.4))
				for i in range(19,-1,-1): points.append(Vector2.from_angle(-1.2+i*2.4/19)*g.size*(0.5+progress*0.4))
				draw_colored_polygon(points,color)
			"muzzle":
				draw_set_transform(g.p,g.dir.angle())
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(g.size*0.4,-28),Vector2(g.size,0),Vector2(g.size*0.4,28)]),color)
			"bow":
				draw_set_transform(g.p,g.dir.angle())
				draw_arc(Vector2.ZERO,g.size,-1.2,1.2,24,color,5,true)
				draw_line(Vector2.from_angle(-1.2)*g.size,Vector2(-15,0),color,2,true)
				draw_line(Vector2.from_angle(1.2)*g.size,Vector2(-15,0),color,2,true)
			"blast":
				draw_set_transform(g.p)
				for i in range(8):
					var p = Vector2.from_angle(i*TAU/8)*g.size*progress*0.6
					draw_circle(p,g.size*(1-progress)*0.28,Color(color,0.5))
				draw_arc(Vector2.ZERO,g.size*progress,0,TAU,48,color,6*(1-progress)+1,true)
	draw_set_transform(Vector2.ZERO)
