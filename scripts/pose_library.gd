extends RefCounted
## Authored joint-space gestures. Movement never changes gameplay timing.
const CLIPS = ["idle","ready","start","run_forward","run_back","strafe_left","strafe_right","stop","turn","attack","recover","dash","hurt","reload_open","reload_insert","reload_close","skill_0","skill_1","skill_2","ultimate_gather","ultimate_sustain","ultimate_finish","combo","victory","death"]
const LABELS = ["呼吸待机","持械警戒","起步","前进","后撤","左横移","右横移","急停","转身","普攻释放","攻击收势","闪避","受击","开启枪机 / 收剑 / 取箭","填装 / 授剑 / 搭箭","合机 / 收势 / 拉弦","技能一","技能二","技能三","大招聚势","大招维持","大招终结","组合连携","胜利","退场"]

static func elbow(a: Vector2, b: Vector2, side: float, upper: float = 24, lower: float = 26) -> Vector2:
	var axis = b-a
	var d = clampf(axis.length(),0.01,upper+lower-0.01)
	var along = (upper*upper-lower*lower+d*d)/(2*d)
	return a+axis.normalized()*along+axis.normalized().orthogonal()*sqrt(maxf(0,upper*upper-along*along))*side

static func pose(role: int, aim: Vector2, move: Vector2, clock: float, clip: String, phase: float) -> Dictionary:
	var d = aim.normalized() if aim.length_squared()>.001 else Vector2.RIGHT
	var side = 1.0 if d.x>=0 else -1.0
	var moving = clampf(move.length(),0,1)
	var step = sin(clock*10.5)
	var bob = -absf(step)*moving*2.0+sin(clock*2.1)*.5
	var body = Vector2(move.x*1.5,bob)
	var stance = 7.0+moving*2
	var stride = d*0.0+move*step*12
	var left_foot = Vector2(-stance,0)+stride
	var right_foot = Vector2(stance,0)-stride
	left_foot.y -= maxf(0,step)*moving*5
	right_foot.y -= maxf(0,-step)*moving*5
	var center = Vector2(0,-58)+body
	var shoulder_axis = Vector2(-d.y*10,d.x*4)
	var shoulder_l = center+shoulder_axis
	var shoulder_r = center-shoulder_axis
	var weapon = center+d*12
	var angle = d.angle()
	var draw = .92 if role==2 else 0.0
	var recoil = 0.0
	var lift = 0.0
	var p = clampf(phase,0,1)
	var wave = sin(p*PI)
	match clip:
		"idle": weapon += Vector2(-side*4,8); angle += side*.25; draw=.18
		"start": body += -move*3*(1-p)
		"stop": body += move*4*(1-p)
		"turn": body.x += sin(p*TAU)*2; weapon -= d*3*wave
		"run_back": stance=11; body.y+=1.5
		"strafe_left": body.x-=1.8
		"strafe_right": body.x+=1.8
		"attack":
			recoil = pow(1-p,2)*(6 if role==1 else 3)
			weapon -= d*recoil
			if role==0: angle += side*-.42*wave; lift=wave*5
			if role==2: draw = .15+.8*smoothstep(.25,1,p)
		"recover": weapon+=Vector2(-side*3,3)*wave; draw=.4+.5*p
		"dash": body+=move*8; body.y+=8; weapon-=d*5; left_foot-=move*11; right_foot+=move*11
		"hurt": body-=d*4*wave; weapon-=d*5*wave
		"reload_open": angle-=side*.7*wave; weapon+=Vector2(-side*5,6); draw=.05
		"reload_insert": angle-=side*.65; weapon+=Vector2(-side*8,8); draw=.2
		"reload_close": angle-=side*.65*(1-p); weapon+=Vector2(0,7*(1-p)); draw=p
		"skill_0":
			weapon+=Vector2(0,-10*wave); angle-=side*.18*wave; draw=1
		"skill_1":
			weapon+=d*7*wave; angle+=side*.1*wave; stance=13; draw=1
		"skill_2":
			weapon-=d*7*wave; weapon.y-=10*wave; angle-=side*.5*wave; draw=.5
		"ultimate_gather": weapon.y-=15*wave; angle-=side*.55*wave; lift=wave*14; draw=1
		"ultimate_sustain": weapon+=Vector2(0,-6); angle+=sin(clock*8)*.045; lift=10; draw=.8+.2*sin(clock*16)
		"ultimate_finish": weapon+=d*9*wave; body-=d*4*wave; lift=20*wave; draw=1-p
		"combo": weapon+=d*5*wave; angle+=side*sin(p*TAU)*.25; lift=10*wave; draw=1
		"victory": weapon.y-=15; angle-=side*.7; draw=.1
		"death": body.y+=p*28; weapon.y+=p*32; angle+=side*p*1.2; left_foot.x-=p*8; right_foot.x+=p*8
	var foreshorten = lerpf(1.0,.52,absf(sin(angle)))
	var forward = Vector2.from_angle(angle)*foreshorten
	var hand_r: Vector2
	var hand_l: Vector2
	var muzzle: Vector2
	if role==1:
		hand_r=weapon-forward*7
		hand_l=weapon+forward*18
		if clip=="reload_insert": hand_l=weapon+Vector2(side*4,-12+sin(p*TAU)*6)
		muzzle=weapon+forward*50
	elif role==2:
		hand_l=weapon+forward*12
		hand_r=weapon-forward*(8+draw*17)
		muzzle=weapon+forward*47
	else:
		hand_r=weapon-forward*8
		hand_l=center+Vector2(-side*14,-10-lift)
		if clip in ["skill_0","ultimate_gather","ultimate_sustain","ultimate_finish","combo"]:
			hand_r=center+forward*20+Vector2(0,-lift)
			weapon=hand_r+forward*14+Vector2(0,-16-lift)
		muzzle=weapon+forward*43
	return {"body":body,"shoulder_l":shoulder_l,"shoulder_r":shoulder_r,"hand_l":hand_l,"hand_r":hand_r,"elbow_l":elbow(shoulder_l,hand_l,side),"elbow_r":elbow(shoulder_r,hand_r,-side),"hip_l":Vector2(-7,-39)+body,"hip_r":Vector2(7,-39)+body,"foot_l":left_foot,"foot_r":right_foot,"weapon":weapon,"angle":angle,"muzzle":muzzle,"draw":draw,"recoil":recoil,"foreshorten":foreshorten}
