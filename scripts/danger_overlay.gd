extends Node2D
## Telegraph outlines stay above player effects, below HUD.
var game
func _ready() -> void:
	z_index = 80
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if game.state!="combat": return
	for hazard in game.hazards:
		draw_arc(hazard.p,hazard.radius,0,TAU,48,Color("#ff7385"),3,true)
		draw_arc(hazard.p,hazard.radius-6,-PI/2,-PI/2+TAU*(1-hazard.t/hazard.max),48,Color("#ffe0b1"),2,true)
	for enemy in game.enemies:
		if enemy.state=="windup":
			draw_arc(enemy.position,enemy.radius+18,0,TAU,32,Color("#ff8d9a"),3,true)
			if enemy.is_charge_windup():
				var side: Vector2 = enemy.locked_dir.orthogonal()*(enemy.radius+28)
				var finish: Vector2 = enemy.position+enemy.locked_dir*enemy.charge_length()
				draw_line(enemy.position+side,finish+side,Color(1,.48,.56,.65),2,true)
				draw_line(enemy.position-side,finish-side,Color(1,.48,.56,.65),2,true)
				draw_arc(finish,enemy.radius+28,enemy.locked_dir.angle()-PI/2,enemy.locked_dir.angle()+PI/2,20,Color(1,.48,.56,.65),2,true)
