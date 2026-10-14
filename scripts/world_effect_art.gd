extends RefCounted
## 只负责材质绘制：不读取战斗随机数，不创建伤害、碰撞或灯光节点。
const Detail = preload("res://scripts/skill_textures.gd")
const VORTEX = "res://art/v13/aether-vortex.png"
const SHIELD = "res://art/v13/crystal-barrier.png"
const LIGHTNING = "res://art/v13/lightning-bolt.png"
const SMOKE = "res://art/v6/fx/smoke_01.png"
const FLAME = "res://art/v6/fx/flame_01.png"

static func school(kind: int) -> String:
	if kind==14: return "water"
	if kind in [5,8,11,13,18]: return "astral"
	if kind in [4,6]: return "steel"
	if kind==9: return "frost"
	if kind==16: return "nature"
	return "ember"

static func color_for(element: String) -> Color:
	return {"ember":Color("#ff9c68"),"astral":Color("#b3a4ff"),"steel":Color("#f3cd8b"),"water":Color("#a3e9ec"),"frost":Color("#95dfff"),"nature":Color("#b4d79e"),"heal":Color("#8ee8bd"),"gold":Color("#ffe0a0")}.get(element,Color("#a7d6f2"))

static func sprite(canvas: CanvasItem, path: String, pos: Vector2, size: Vector2, angle: float, tint: Color) -> void:
	Detail.image_at(canvas,path,pos,size,angle,tint)

static func vortex(canvas: CanvasItem, pos: Vector2, radius: float, tint: Color, phase: float, quality: float, moving: bool = true) -> void:
	var angle: float = phase*.48 if moving else 0.0
	sprite(canvas,VORTEX,pos,Vector2.ONE*radius*2,angle,Color(tint,tint.a*.55))
	if quality>=.5:
		sprite(canvas,VORTEX,pos,Vector2.ONE*radius*1.46,-angle*.7,Color(tint.lightened(.25),tint.a*.16))

static func motes(canvas: CanvasItem, pos: Vector2, radius: float, phase: float, tint: Color, count: int, inward: bool = false) -> void:
	for i in range(count):
		var a = float(i)*2.39996
		var progress = fposmod(phase*.7+float(i)*.153,1.0)
		var distance_factor: float = 1.0-progress if inward else progress
		var point = pos+Vector2.from_angle(a)*radius*(.25+.75*distance_factor)
		Detail.glow(canvas,point,Vector2(6,13),a,Color(tint,tint.a*sin(progress*PI)*.8))

static func spawn_portal(canvas: CanvasItem, pos: Vector2, radius: float, progress: float, quality: float, reduced: bool) -> void:
	var tint = Color("#dc718e")
	var r = radius*(.7+.3*progress)
	vortex(canvas,pos,r,Color(tint,.65),progress,quality,not reduced)
	Detail.glow(canvas,pos,Vector2(r*1.2,r*.6),0,Color(tint,.16))
	if quality>=.5:
		for i in range(3):
			var side = Vector2.from_angle(i*TAU/3+.4)*r*.48
			sprite(canvas,SMOKE,pos+side+Vector2(0,-progress*28),Vector2(28,46)*(1+progress*.5),0,Color(tint,.25*(1-progress*.4)))

static func shield(canvas: CanvasItem, pos: Vector2, radius: float, tint: Color, strength: float, clock: float, quality: float, reduced: bool) -> void:
	var center = pos-Vector2(0,radius*.72)
	var alpha = .36+.26*clampf(strength,0,1)
	sprite(canvas,SHIELD,center,Vector2(radius*2.35,radius*2.85),0,Color(tint,alpha))
	Detail.glow(canvas,pos+Vector2(0,5),Vector2(radius*1.6,18),0,Color(tint,.18))
	if quality>=.5:
		var phase: float = 0.7 if reduced else clock*.65
		var glint = center+Vector2(cos(phase)*radius*.88,sin(phase)*radius*1.08)
		Detail.glow(canvas,glint,Vector2(13,21),-.3,Color(tint.lightened(.4),.6))

static func warning(canvas: CanvasItem, pos: Vector2, radius: float, progress: float, element: String, quality: float, reduced: bool) -> void:
	var tint = color_for(element).lerp(Color("#ed708f"),.35)
	vortex(canvas,pos,radius*.93,Color(tint,.25+.18*progress),progress,quality,not reduced)
	Detail.glow(canvas,pos,Vector2.ONE*radius*1.45,0,Color(tint,.09+.10*progress))

static func charge_lane(canvas: CanvasItem, pos: Vector2, direction: Vector2, length: float, width: float, progress: float) -> void:
	Detail.glow(canvas,pos+direction*length*.5,Vector2(length*1.1,width*2.0),direction.angle(),Color(1,.32,.44,.13+.13*progress))
	for i in range(3):
		var point = pos+direction*length*(.2+float(i)*.3)
		Detail.glow(canvas,point,Vector2(30,width*.6),direction.angle(),Color(1,.64,.43,.22+.18*progress))

static func enemy_orb(canvas: CanvasItem, element: String, boss: bool, is_bubble: bool) -> void:
	var tint = color_for("water" if is_bubble else element)
	var size: float = 24.0 if is_bubble else (23.0 if boss else 17.0)
	Detail.glow(canvas,Vector2.ZERO,Vector2.ONE*size*1.65,0,Color("#ff7589",.27))
	Detail.glow(canvas,Vector2(-size*.7,0),Vector2(size*2.2,size*.6),0,Color(tint,.46))
	if is_bubble:
		sprite(canvas,SHIELD,Vector2.ZERO,Vector2.ONE*size*1.3,0,Color(tint,.9))
	elif element=="ember":
		sprite(canvas,FLAME,Vector2(-3,0),Vector2(size*.85,size*1.6),PI*.5,Color(1,.86,.67,.9))
	else:
		sprite(canvas,VORTEX,Vector2.ZERO,Vector2.ONE*size,0,Color(tint,.9))
	Detail.glow(canvas,Vector2(2,-1),Vector2.ONE*size*.45,0,Color(1,.94,.88,.8))

static func event(canvas: CanvasItem, entry: Dictionary, quality: float, reduced: bool) -> void:
	var p: Vector2 = entry.p
	var radius: float = entry.r
	var phase: float = clampf(1.0-entry.life/entry.max,0,1)
	var fade: float = 1.0-phase
	var tint: Color = entry.c
	var kind: String = entry.kind
	var count: int = 3 if quality<.5 else (6 if quality<.8 else 9)
	var motion: float = 0.35 if reduced else phase
	if kind=="charge_wake":
		sprite(canvas,SMOKE,p,Vector2(radius*1.6,radius*.65)*(1+phase*.5),entry.dir.angle(),Color(tint,fade*.32))
		Detail.glow(canvas,p,Vector2(radius*2,radius*.26),entry.dir.angle(),Color(tint,fade*.4))
		return
	if kind in ["shield_hit","shield_break"]:
		sprite(canvas,SHIELD,p-Vector2(0,radius*.5),Vector2(radius*2.3,radius*2.7)*(1+phase*.35),0,Color(tint,fade*fade*.7))
		if kind=="shield_break":
			var tex_size = Detail.texture(SHIELD).get_size()
			for i in range(3 if quality<.5 else 5):
				var angle = float(i)*2.39996
				var source_rect = Rect2(Vector2(.12+float(i%2)*.48,.12+float((i>>1)%2)*.48)*tex_size,tex_size*.26)
				var point = p-Vector2(0,radius*.5)+Vector2.from_angle(angle)*radius*(.5+phase*1.4)
				Detail.image_at(canvas,SHIELD,point,Vector2(19,27),angle+motion,Color(tint,fade*.8),source_rect)
		motes(canvas,p-Vector2(0,radius*.5),radius*1.8,motion,Color(tint,fade),count)
		return
	if kind=="heal":
		vortex(canvas,p,radius*.6,Color(tint,fade*.65),motion,quality,not reduced)
		for i in range(count):
			var point = p+Vector2(sin(float(i)*2.4)*radius*.55,-18-motion*90-float(i%3)*13)
			Detail.glow(canvas,point,Vector2(10,22),.1,Color(tint,fade*.75))
		return
	if kind in ["magnet","time"]:
		vortex(canvas,p,radius*(1.0-phase*.65),Color(tint,fade*.75),motion*2,quality,not reduced)
		motes(canvas,p-Vector2(0,25),radius,motion,Color(tint,fade),count,true)
		return
	# 快速扩散只控制视觉半径，判定继续来自既有技能/危险区域。
	var expand = 1.0-pow(1.0-phase,3.0)
	vortex(canvas,p,radius*(.25+.75*expand),Color(tint,fade*.65),motion,quality,not reduced)
	Detail.glow(canvas,p,Vector2.ONE*radius*.75,0,Color(tint,fade*fade*.24))
	if kind=="lightning":
		var height = minf(420,radius*2.5)
		sprite(canvas,LIGHTNING,p-Vector2(0,height*.42),Vector2(height*.52,height),0,Color(.8,.88,1,fade*fade*.95))
		if quality>=.5:
			for side in [-1,1]:
				sprite(canvas,LIGHTNING,p+Vector2(side*radius*.5,-height*.25),Vector2(height*.26,height*.60),side*.1,Color(.8,.88,1,fade*fade*.55))
	elif kind in ["ice","water"] or entry.get("element","")=="water":
		for i in range(3 if quality>=.5 else 1):
			var point = p+Vector2.from_angle(i*TAU/3)*radius*.5*expand
			sprite(canvas,SHIELD,point-Vector2(0,25*fade),Vector2(30,65)*(1+phase),float(i)*.7,Color(tint,fade*.48))
	elif kind in ["impact","boss_cast","boss_phase"] and entry.get("element","")=="ember":
		for i in range(3 if quality>=.5 else 1):
			var point = p+Vector2(float(i-1)*radius*.4,-radius*.22)
			sprite(canvas,FLAME,point,Vector2(radius*.6,radius*1.1)*(1+phase*.25),float(i-1)*.2,Color(1,.8,.6,fade*.58))
	elif kind in ["boss_cast","boss_phase","impact"] and entry.get("element","")=="astral":
		Detail.sequence(canvas,"arcane",p-Vector2(0,38),Vector2.ONE*minf(170,radius),phase,entry.dir.angle(),Color(tint,fade*.6))
		if kind=="impact": sprite(canvas,LIGHTNING,p-Vector2(0,radius),Vector2(radius,radius*2.4),0,Color(tint,fade*fade*.8))
	if quality>=.5: motes(canvas,p,radius,motion,Color(tint,fade*.65),count)
