extends RefCounted
## World-space textured particles; isolated cosmetic RNG, no hit callbacks.
var bits: Array=[]
var rng=RandomNumberGenerator.new()
const SMOKE=[preload("res://art/v6/fx/smoke_01.png"),preload("res://art/v6/fx/smoke_02.png"),preload("res://art/v6/fx/smoke_03.png")]
const FLAMES=[preload("res://art/v6/fx/flame_01.png"),preload("res://art/v6/fx/flame_02.png"),preload("res://art/v6/fx/flame_03.png")]
const LIGHT=preload("res://art/v6/fx/light_01.png")
const MAGIC=preload("res://art/v6/fx/magic_01.png")
const EXPLOSIONS=[preload("res://art/v6/fx/explosion00.png"),preload("res://art/v6/fx/explosion01.png"),preload("res://art/v6/fx/explosion02.png"),preload("res://art/v6/fx/explosion03.png"),preload("res://art/v6/fx/explosion04.png"),preload("res://art/v6/fx/explosion05.png"),preload("res://art/v6/fx/explosion06.png"),preload("res://art/v6/fx/explosion07.png"),preload("res://art/v6/fx/explosion08.png")]
func _init() -> void: rng.seed=61927
func add(type: String, pos: Vector2, velocity: Vector2, size: Vector2, duration: float, color: Color, angle: float = 0, cap: int = 112) -> void:
	if bits.size()>=cap: bits.pop_front()
	bits.append({"type":type,"p":pos,"v":velocity,"size":size,"life":duration,"max":duration,"c":color,"a":angle,"variant":rng.randi_range(0,2)})
func emit(kind: String, pos: Vector2, dir: Vector2, role: int, strength: float, quality: float) -> void:
	# Gunner uses V5 flashes/rings again, also in the action inspector.
	if role==1:return
	var cap=24 if quality<.5 else (48 if quality<.8 else 80)
	var color=[Color("#99f7ef"),Color("#ffb269"),Color("#a5e9bc")][clampi(role,0,2)]
	if kind=="shot":
		if role==1:
			add("flame",pos+dir*14,dir*35,Vector2(26,60),.10,Color("#ffe5a0"),dir.angle()+PI/2,cap)
			add("light",pos,Vector2.ZERO,Vector2(72,60),.075,Color(1,.57,.22,.5),0,cap)
			for i in range(1 if quality<.5 else 3):
				add("smoke",pos+dir*(10+i*7),dir*(20+i*10)+Vector2(0,-22),Vector2.ONE*(24+i*9),.55+i*.1,Color(.54,.57,.6,.37),rng.randf()*TAU,cap)
		else:
			add("magic",pos,dir*28,Vector2.ONE*35,.18,Color(color,.6),dir.angle(),cap)
	elif role==1 and kind in ["explosion","ultimate","combo","cast"]:
		var size=clampf(strength*52,80,230)
		add("explosion",pos,Vector2.ZERO,Vector2.ONE*size,.46,Color.WHITE,0,cap)
		add("light",pos,Vector2.ZERO,Vector2.ONE*size*1.3,.16,Color(1,.58,.22,.55),0,cap)
		for i in range(1 if quality<.5 else (3 if quality<.8 else 4)):
			var v=Vector2.from_angle(rng.randf()*TAU)
			add("smoke",pos+v*size*.2,v*35+Vector2(0,-34),Vector2.ONE*size*.5,.8+rng.randf()*.35,Color(.36,.40,.45,.4),rng.randf()*TAU,cap)
	elif kind in ["impact","explosion","ultimate","combo","cast"]:
		add("magic",pos,Vector2.ZERO,Vector2.ONE*clampf(strength*48,42,190),.32,Color(color,.7),rng.randf()*TAU,cap)
		add("smoke",pos,Vector2(0,-20),Vector2.ONE*clampf(strength*26,30,95),.55,Color(color,.23),rng.randf()*TAU,cap)
	elif kind=="water":
		for i in range(5):add("smoke",pos+Vector2(rng.randf_range(-30,30),0),Vector2(rng.randf_range(-30,30),-45),Vector2.ONE*35,.6,Color(.6,.9,.96,.45),rng.randf()*TAU,cap)
func tick(delta: float) -> void:
	for p in bits:
		p.life-=delta;p.p+=p.v*delta
		if p.type=="smoke":p.v.y-=delta*12;p.a+=delta*.18
	bits=bits.filter(func(p):return p.life>0)
func draw(canvas: CanvasItem) -> void:
	for p in bits:
		var phase: float=1-p.life/p.max
		var tex: Texture2D=LIGHT
		var size: Vector2=p.size
		var col: Color=p.c
		match p.type:
			"flame":tex=FLAMES[mini(2,int(phase*3))];size*=1-phase*.45;col.a*=1-phase
			"smoke":tex=SMOKE[p.variant];size*=.65+phase*.95;col.a*=sin(phase*PI)*.9
			"explosion":tex=EXPLOSIONS[mini(8,int(phase*9))];size*=.7+phase*.5;col.a*=minf(1,(1-phase)*4)
			"magic":tex=MAGIC;size*=.75+phase*.6;col.a*=1-phase
			_:col.a*=1-phase
		canvas.draw_set_transform(p.p,p.a)
		canvas.draw_texture_rect(tex,Rect2(-size*.5,size),false,col)
	canvas.draw_set_transform(Vector2.ZERO)
