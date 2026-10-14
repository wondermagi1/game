extends Node2D
## Bounded visual-only weapon instances. Logical hits live in ultimate_controller.
var game
var glyphs: Array = []
const WEAPONS = preload("res://art/v5/weapons.png")
const PALETTE = [Color("#86ffe4"),Color("#ffb269"),Color("#cbb4ff")]
const Detail = preload("res://scripts/skill_textures.gd")
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
static func weapon(canvas: CanvasItem, role: int, length: float, _width: float, color: Color) -> void:
	var props=preload("res://scripts/weapon_art_v6.gd")
	if role in [0,2]:
		props.draw(canvas,(3 if length>100 else 0) if role==0 else (4 if length>100 else 5),length,Color(1,1,1,color.a))
	else:
		Detail.bullet(canvas,length,Color(1,1,1,color.a))

func skill_cast(role: int, slot: int, origin: Vector2, center: Vector2, direction: Vector2, rank: int) -> void:
	# Nine small skills receive authored artwork; sizes affect visuals only.
	var power = 1.0+minf(rank,10)*.025
	match role:
		0:
			if slot==0: emit("sword_halo",origin,direction,165*power,.65,0)
			elif slot==1: emit("slash",origin+direction*95+Vector2(0,-48),direction,210*power,.35,0)
			else: emit("dash_blades",origin,direction,200*power,.42,0)
		1:
			if slot==2: emit("reload",origin+Vector2(0,-48),direction,90*power,.70,1)
			else: emit("muzzle",origin+game.player.visual.muzzle_local(),direction,(100 if slot==0 else 135)*power,.22,1)
		2:
			if slot==0: emit("bow",origin+Vector2(0,-48),direction,170*power,.4,2)
			elif slot==1: emit("hunt",center,direction,240*power,.7,2)
			else: emit("hunt",center,direction,340*power,1.0,2)

func zone_anticipation(pos: Vector2, radius: float, kind: String, duration: float) -> void:
	if kind in ["arrows","v7_storm","storm"]: emit("rain",pos,Vector2.DOWN,radius,maxf(.15,duration),2)
	elif kind in ["swords","v7_array"]: emit("rain",pos,Vector2.DOWN,radius,maxf(.15,duration),0)
	elif kind=="blade": emit("slash",pos,game.player.aim,radius*1.8,maxf(.15,duration),0)
	elif kind in ["v7_trap","echo"]: emit("hunt",pos,Vector2.UP,radius*1.5,maxf(.3,duration),2)
	elif kind=="v7_fire": emit("blast",pos,Vector2.UP,radius,.52,1)
func _draw() -> void:
	for g in glyphs:
		var progress: float = 1-g.life/g.max
		var color: Color = PALETTE[g.role]
		color.a = minf(1,g.life*5)
		match g.kind:
			"sword_halo":
				draw_set_transform(g.p)
				for ring in range(3):
					var radius=g.size*(.48+ring*.18)*(0.88+sin(progress*PI)*.12)
					draw_arc(Vector2.ZERO,radius,progress*TAU*(1 if ring%2==0 else -1),TAU+progress*TAU,32,Color(color,.42-ring*.09),3-ring*.55,true)
				for i in range(8):
					var angle=i*TAU/8+progress*1.8
					draw_set_transform(g.p+Vector2.from_angle(angle)*g.size*.72,angle+PI*.5)
					weapon(self,0,58+g.size*.08,3.5,Color(color,.78))
			"gun_heat":
				draw_set_transform(g.p,g.dir.angle())
				Detail.rune(self,Vector2(0,-35),Vector2.ONE*g.size*.85,progress*.5,(1-progress)*.55)
				Detail.sequence(self,"arcane",Vector2(18,-42),Vector2(72,100),progress,0,Color(1,1,1,(1-progress)*.42))
				for i in range(3):
					var angle = -1.0+i
					draw_set_transform(g.p+Vector2.from_angle(angle)*g.size*.38+Vector2(0,-45),g.dir.angle())
					weapon(self,1,38,8,color)
			"bow_constellation":
				draw_set_transform(g.p,g.dir.angle())
				draw_arc(Vector2.ZERO,g.size*.72,-1.25,1.25,40,Color(color,.75),5,true)
				draw_line(Vector2.from_angle(-1.25)*g.size*.72,Vector2(-30-progress*18,0),Color(color,.7),2,true)
				draw_line(Vector2.from_angle(1.25)*g.size*.72,Vector2(-30-progress*18,0),Color(color,.7),2,true)
				for i in range(7):
					var star=Vector2(-g.size*.25+i*g.size*.09,sin(i*2.1+progress*TAU)*g.size*.18)
					draw_circle(star,3+i%2,Color("#f6eeff"))
					if i>0:draw_line(star,Vector2(-g.size*.25+(i-1)*g.size*.09,sin((i-1)*2.1+progress*TAU)*g.size*.18),Color(color,.38),1.5,true)
			"residue":
				draw_set_transform(g.p,0,Vector2(1,.38))
				for i in range(3):
					var radius=g.size*(.3+i*.2+progress*.12)
					draw_arc(Vector2.ZERO,radius,progress*TAU+i*.7,TAU+progress*TAU,32,Color(color,(1-progress)*(.34-i*.06)),3-i*.5,true)
			"fall", "finish":
				var p: Vector2 = g.p-Vector2(0,pow(1-progress,3)*g.size*1.4)
				draw_set_transform(p,PI*0.5)
				Detail.glow(self,Vector2(-g.size*.6,0),Vector2(g.size*1.8,g.size*.16),0,Color(color,.20))
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
				Detail.sequence(self,"sword_slash",Vector2.ZERO,Vector2.ONE*g.size*1.35,progress,0,Color(1,1,1,color.a))
			"muzzle":
				draw_set_transform(g.p,g.dir.angle())
				Detail.muzzle(self,g.size,progress)
			"bow":
				draw_set_transform(g.p,g.dir.angle())
				Detail.sequence(self,"nature_bloom",Vector2.ZERO,Vector2(g.size*1.4,g.size*.85),progress,0,Color(1,1,1,color.a))
				preload("res://scripts/weapon_art_v6.gd").draw(self,2,g.size*.23,Color(1,1,1,color.a*.8))
			"blast":
				draw_set_transform(g.p)
				if g.role==1: Detail.explosion(self,Vector2.ZERO,g.size,progress)
				else: Detail.sequence(self,"nature_bloom",Vector2.ZERO,Vector2.ONE*g.size*1.5,progress)
			"reload":
				draw_set_transform(g.p)
				Detail.rune(self,Vector2.ZERO,Vector2(g.size*1.8,g.size*1.0),-progress*.7,(1-progress)*.6)
				Detail.sequence(self,"alchemy_slash",Vector2.ZERO,Vector2.ONE*g.size*1.45,progress,0,Color(1,1,1,.6))
				for i in range(3):
					var angle = progress*1.8+i*TAU/3
					draw_set_transform(g.p+Vector2.from_angle(angle)*g.size*(1-progress),g.dir.angle())
					weapon(self,1,36,8,Color(1,1,1,color.a))
			"hunt":
				draw_set_transform(g.p)
				Detail.sequence(self,"nature_bloom",Vector2.ZERO,Vector2(g.size*1.6,g.size*.85),progress,0,Color(1,1,1,.8))
				Detail.rune(self,Vector2.ZERO,Vector2(g.size,g.size*.6),-progress*.4,(1-progress)*.38)
				for i in range(4):
					var off = Vector2.from_angle(i*TAU/4)*g.size*.42
					Detail.sequence(self,"nature_wreath",off,Vector2(65,125),progress,0,Color(1,1,1,.65))
			"dash_blades":
				for i in range(3):
					draw_set_transform(g.p+g.dir*(45+i*65)+Vector2(0,-32),g.dir.angle())
					Detail.sequence(self,"sword_wave",Vector2.ZERO,Vector2(g.size*.7,g.size*.65),progress,0,Color(1,1,1,(1-progress)*.8))
					weapon(self,0,70+i*15,4,Color(1,1,1,(1-progress)*.6))
			"rain":
				for i in range(3 if game.effects_intensity<.5 else 7):
					var landing: Vector2 = g.p+Vector2.from_angle(i*2.4)*g.size*(.2+float(i%3)*.22)
					var phase = clampf(progress*1.35-float(i%3)*.10,0,1)
					var pos: Vector2 = landing-Vector2(30,170)*(1-phase)
					draw_set_transform(pos,Vector2(30,170).angle())
					weapon(self,g.role,84,5,Color(1,1,1,1.0 if phase<.9 else (1-phase)*10))
					if phase>.7:
						draw_set_transform(landing)
						Detail.sequence(self,"nature_leaves" if g.role==2 else "sword_slash",Vector2.ZERO,Vector2(66,48),(phase-.7)/.3)
	draw_set_transform(Vector2.ZERO)
