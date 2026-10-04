extends Node2D
var visual_rng = RandomNumberGenerator.new()
var game
var bits: Array = []
var texts: Array = []
var rings: Array = []
var trails: Array = []
var seals: Array = []
var font = SystemFont.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	z_index = 30

func burst(pos: Vector2, color: Color, count: int = 8) -> void:
	count = mini(count,240-bits.size())
	count = int(count*game.effects_intensity)
	for i in range(count):
		bits.append({"p":pos,"v":Vector2.from_angle(visual_rng.randf()*TAU)*visual_rng.randf_range(50,180),"t":0.38,"c":color})

func ring(pos: Vector2, radius: float, color: Color) -> void:
	if rings.size()>=maxi(12,int(80*game.effects_intensity)): return
	rings.append({"p":pos,"r":radius,"t":0.4,"c":color})

func number(pos: Vector2, amount: float, color: Color, big: bool = false, delay: float = 0.0) -> void:
	if game.show_numbers and texts.size()<80:
		texts.append({"p":pos+Vector2(visual_rng.randf_range(-12,12),-32),"text":(str(snappedf(amount/1e6,0.1))+"M" if amount>1.0e9 else str(ceili(amount))),"t":0.75,"delay":delay,"c":color,"size":30 if big else 23})

func _process(delta: float) -> void:
	if game.state not in ["combat","end"]: return
	for b in bits:
		b.p += b.v * delta
		b.t -= delta
	for t in texts:
		if t.get("delay",0.0)>0:t.delay=maxf(0,t.delay-delta)
		else:
			t.p.y -= delta * 38
			t.t -= delta
	for r in rings: r.t -= delta
	for t in trails: t.t -= delta
	for seal in seals: seal.t -= delta
	trails = trails.filter(func(t): return t.t>0)
	seals = seals.filter(func(t): return t.t>0)
	bits = bits.filter(func(b): return b.t > 0)
	texts = texts.filter(func(t): return t.t > 0)
	rings = rings.filter(func(r): return r.t > 0)
	queue_redraw()

func clear() -> void:
	bits.clear()
	texts.clear()
	rings.clear()
	trails.clear()
	seals.clear()

func _draw() -> void:
	for t in trails:
		draw_line(t.a,t.b,Color(t.c,t.t/0.16*0.4),t.width,true)
	for seal in seals:
		var alpha = clampf(seal.t/0.7,0,1)*0.7
		for level in range(seal.rank):
			var radius: float = seal.r*(1-level*0.12)
			draw_arc(seal.p,radius,seal.t,TAU+seal.t,6+level*3,Color(seal.c,alpha),2+level,true)
			for i in range(4+seal.rank):
				var d = Vector2.from_angle(i*TAU/(4+seal.rank)+seal.t)
				draw_line(seal.p+d*radius,seal.p+d*(radius+14),Color(seal.c,alpha),2,true)
	for b in bits:
		var c: Color = b.c
		c.a = maxf(0,b.t/0.38)
		draw_circle(b.p,3,c)
	for r in rings:
		var c: Color = r.c
		c.a = maxf(0,r.t/0.4)
		draw_arc(r.p,r.r*(1.1-r.t),0,TAU,48,c,3,true)
	for t in texts:
		if t.get("delay",0.0)>0:continue
		var c: Color = t.c
		c.a = minf(1,t.t*3)
		draw_string(font,t.p+Vector2(2,2),t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,t.size,Color(0,0,0,c.a))
		draw_string(font,t.p,t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,t.size,c)


func streak(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	if trails.size()>=int(350*game.effects_intensity): return
	trails.append({"a":a,"b":b,"c":color,"width":width,"t":0.16})

func sigils(pos: Vector2, radius: float, color: Color, rank: int) -> void:
	if seals.size()>=maxi(6,int(30*game.effects_intensity)): return
	seals.append({"p":pos,"r":radius,"c":color,"rank":mini(maxi(1,ceili(game.effects_intensity*4)),rank),"t":0.7})

func caption(pos: Vector2, value: String, color: Color) -> void:
	if texts.size()>=80: return
	texts.append({"p":pos,"text":value,"t":0.75,"c":color,"size":22})

func combo_burst(pos: Vector2, role: int, title: String) -> void:
	game.presentation_fx.emit("combo",pos,Vector2.UP,role,2.5)
	game.art.emit(["slash","blast","bow"][role],pos,Vector2.RIGHT,170,.4,role)
	var color = [Color("#7fffe4"),Color("#ffb353"),Color("#bf9fff")][role]
	sigils(pos,120,color,3)
	ring(pos,210,color)
	burst(pos,color,36)
	for i in range(12):
		var dir = Vector2.from_angle(i*TAU/12)
		streak(pos+dir*25,pos+dir*170,color,8 if role==1 else 3)
	if not title.is_empty(): caption(pos-Vector2(0,75),title,color)

func mastery_burst(pos: Vector2, role: int, level: int) -> void:
	var color = [Color("#8bffe3"),Color("#ffc07a"),Color("#c1abff")][role]
	ring(pos,160,color)
	if level>=8:
		ring(pos,215,color.lightened(0.3))
		for i in range(8):
			var dir = Vector2.from_angle(i*TAU/8)
			streak(pos+dir*80,pos+dir*155,color,4)
	if level>=10:
		sigils(pos,255,color,4)
		caption(pos-Vector2(0,100),"觉醒",color)
