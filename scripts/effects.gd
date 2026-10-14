extends Node2D
const WorldArt = preload("res://scripts/world_effect_art.gd")
var visual_rng = RandomNumberGenerator.new()
var game
var bits: Array = []
var texts: Array = []
var rings: Array = []
var trails: Array = []
var seals: Array = []
var surges: Array[Dictionary] = []
var font = SystemFont.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	z_index = 30
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func burst(pos: Vector2, color: Color, count: int = 8) -> void:
	count = mini(count,240-bits.size())
	count = int(count*game.effects_intensity)
	var classic_sparks: bool = is_instance_valid(game.player) and game.player.stats.role==1
	for i in range(count):
		bits.append({"p":pos,"v":Vector2.from_angle(visual_rng.randf()*TAU)*visual_rng.randf_range(50,180),"t":0.38,"c":color,"classic_sparks":classic_sparks})

func ring(pos: Vector2, radius: float, color: Color, classic: bool = false) -> void:
	if rings.size()>=maxi(12,int(80*game.effects_intensity)): return
	rings.append({"p":pos,"r":radius,"t":0.4,"c":color,"classic":classic})

func surge(kind: String, pos: Vector2, radius: float, color: Color, direction: Vector2 = Vector2.UP, duration: float = .65, element: String = "") -> void:
	var cap: int = 12 if game.effects_intensity<.5 else (22 if game.effects_intensity<.8 else 32)
	if surges.size()>=cap:
		if kind=="charge_wake": return
		while surges.size()>=cap: surges.pop_front()
	surges.append({"kind":kind,"p":pos,"r":radius,"c":color,"dir":direction,"life":duration,"max":duration,"element":element})

func item_use(id: String, pos: Vector2) -> void:
	match id:
		"potion": surge("heal",pos,80,WorldArt.color_for("heal"),Vector2.UP,1.0)
		"barrier": surge("shield_hit",pos,48,WorldArt.color_for("frost"))
		"frost":
			surge("ice",pos,180,WorldArt.color_for("frost"))
			for enemy in game.enemies.slice(0,8):
				if is_instance_valid(enemy): surge("ice",enemy.global_position,enemy.radius+20,WorldArt.color_for("frost"))
		"thunder": surge("lightning",pos,330,Color("#b7caff"),Vector2.UP,.48)
		"magnet": surge("magnet",pos,140,Color("#c9b3ff"),Vector2.UP,.8)
		"sand": surge("time",pos,110,WorldArt.color_for("gold"),Vector2.UP,.95)

func boss_cast(pos: Vector2, kind: int, direction: Vector2, phase_change: bool = false) -> void:
	var element = WorldArt.school(kind)
	surge("boss_phase" if phase_change else "boss_cast",pos,230 if phase_change else 130,WorldArt.color_for(element),direction,.8 if phase_change else .5,element)

func number(pos: Vector2, amount: float, color: Color, big: bool = false, delay: float = 0.0) -> void:
	if game.show_numbers and texts.size()<80:
		texts.append({"p":pos+Vector2(visual_rng.randf_range(-12,12),-32),"text":(str(snappedf(amount/1e6,0.1))+"M" if amount>1.0e9 else str(ceili(amount))),"t":0.75,"delay":delay,"c":color,"size":30 if big else 23})

func _process(delta: float) -> void:
	if game.state not in ["combat","end"]: return
	var surge_cap: int = 12 if game.effects_intensity<.5 else (22 if game.effects_intensity<.8 else 32)
	while surges.size()>surge_cap: surges.pop_front()
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
	for surge_event in surges: surge_event.life -= delta
	surges = surges.filter(func(event): return event.life>0)
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
	surges.clear()
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(game.player) and not game.player.dead and game.state in ["combat","paused","cinematic"]:
		var actor = game.player
		if actor.shield_ready or actor.barrier>0:
			var strength: float = 1.0 if actor.shield_ready else clampf(actor.barrier/45.0,.15,1.0)
			WorldArt.shield(self,actor.global_position,45,Color("#a1deff"),strength,game.elapsed,game.effects_intensity,game.reduced_motion)
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.ward>0:
			WorldArt.shield(self,enemy.global_position,enemy.radius+12,Color("#b5b1f1"),.6,game.elapsed,game.effects_intensity,game.reduced_motion)
	for surge_event in surges:
		WorldArt.event(self,surge_event,game.effects_intensity,game.reduced_motion)
	for t in trails:
		if t.get("classic_sparks",false):
			draw_line(t.a,t.b,Color(t.c,t.t/0.16*.4),t.width,true)
			continue
		var delta: Vector2 = t.b-t.a
		preload("res://scripts/skill_textures.gd").glow(self,(t.a+t.b)*.5,Vector2(maxf(8,delta.length()*1.25),maxf(5,t.width*2.0)),delta.angle(),Color(t.c,t.t/0.16*.20))
	for seal in seals:
		var alpha = clampf(seal.t/0.7,0,1)*0.7
		WorldArt.vortex(self,seal.p,seal.r,Color(seal.c,alpha),1-seal.t/.7,game.effects_intensity,not game.reduced_motion)
	for b in bits:
		var c: Color = b.c
		c.a = maxf(0,b.t/0.38)
		if b.get("classic_sparks",false): draw_circle(b.p,3,c)
		else: preload("res://scripts/skill_textures.gd").glow(self,b.p,Vector2(8,6),0,Color(c,c.a*.6))
	for r in rings:
		var c: Color = r.c
		c.a = maxf(0,r.t/0.4)
		if r.get("classic",false): draw_arc(r.p,r.r*(1.1-r.t),0,TAU,48,c,3,true)
		else: WorldArt.vortex(self,r.p,r.r*(1.1-r.t),Color(c,c.a*.6),1-r.t/.4,game.effects_intensity,not game.reduced_motion)
	for t in texts:
		if t.get("delay",0.0)>0:continue
		var c: Color = t.c
		c.a = minf(1,t.t*3)
		draw_string(font,t.p+Vector2(2,2),t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,t.size,Color(0,0,0,c.a))
		draw_string(font,t.p,t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,t.size,c)


func streak(a: Vector2, b: Vector2, color: Color, width: float, classic_sparks: bool = false) -> void:
	if trails.size()>=int(350*game.effects_intensity): return
	trails.append({"a":a,"b":b,"c":color,"width":width,"t":0.16,"classic_sparks":classic_sparks})

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
	ring(pos,210,color,role==1)
	burst(pos,color,36)
	for i in range(12):
		var dir = Vector2.from_angle(i*TAU/12)
		streak(pos+dir*25,pos+dir*170,color,8 if role==1 else 3,role==1)
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
