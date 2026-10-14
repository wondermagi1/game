extends "res://scripts/enemy.gd"
## A friendly optional boss. Timing and visible warning radius define every hit.
var bath_clock: float = 0
func _ready() -> void:
	super._ready()
	max_hp = 1150
	hp = max_hp
	damage = 9
	speed = 76
	armor = 5
	radius = 50
	var collision = get_child(0)
	if collision is CollisionShape2D: collision.shape.radius = radius
func execute_attack() -> void:
	state = "recover"
	timer = .8
	cooldown = 2.4 if second_phase else 3.0
	visual.action = .6
	visual.casting = true
	match pattern%3:
		0:
			visual.lulu_play("blow",1.7)
			visual.lulu_time=.85 # The painted release follows the existing .85 s telegraph.
			game.sound.play("lulu_bubble")
			game.fx.caption(global_position-Vector2(65,120),"噜噜 · 泡泡喷泉",Color("#a3e3e7"))
			for i in range(7 if second_phase else 5):
				var count = 7 if second_phase else 5
				var dir = locked_dir.rotated((i-(count-1)*.5)*.25)
				game.spawn_projectile(global_position+dir*62,dir,{"enemy_shot":true,"bubble":true,"damage":damage,"speed":205.0,"remaining":1100.0,"launch_offset":Vector2(0,-106)-dir*62})
		1:
			visual.lulu_play("splash",1.6)
			visual.lulu_time=.8
			game.sound.play("lulu_splash")
			game.presentation_fx.emit("water",global_position+Vector2(0,-15),Vector2.UP,2,2)
			game.fx.caption(global_position-Vector2(65,120),"噜噜 · 拍拍水",Color("#a3e3e7"))
			game.add_hazard(game.player.global_position,105,1.5,damage*1.2)
			if second_phase:
				for side in [-1,1]: game.add_hazard(game.safe_position(game.player.global_position+Vector2(side*240,0)),80,1.8,damage)
			game.presentation_fx.emit("cast",global_position,locked_dir,2,2)
		2:
			visual.lulu_play("bath",2.5)
			game.fx.caption(global_position-Vector2(70,120),"噜噜 · 泡澡时间",Color("#ffdc99"))
			# A real recovery opening, no healing or invulnerability.
			timer = 2.5
			cooldown = 4.1
			bath_clock = 2.5
			game.fx.ring(global_position,115,Color("#acdedd"))
	pattern += 1
func _physics_process(delta: float) -> void:
	var previous_state=state
	super._physics_process(delta)
	if game.state!="combat" or dead: return
	if state=="windup":
		var animation=["blow","splash","bath"][pattern%3]
		if previous_state!="windup":visual.lulu_play(animation,1.7 if pattern%3==0 else 1.6 if pattern%3==1 else 2.5)
		# Only pose timing follows the warning. Damage, cooldowns and targeting stay unchanged.
		var ready=clampf(1.0-timer/.85,0,1)
		visual.lulu_time=ready*(.85 if pattern%3==0 else .8 if pattern%3==1 else .40)
	bath_clock = maxf(0,bath_clock-delta)
	queue_redraw()
func _draw() -> void:
	super._draw()
	if bath_clock>0:
		for i in range(6):
			var p = Vector2(sin(bath_clock+i)*65,-65-fposmod(bath_clock*28+i*18,80))
			draw_arc(p,5+i%3,0,TAU,16,Color(.7,.95,.95,.45),1.5,true)
