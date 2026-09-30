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
			if enemy.kind in [1,4,6]: draw_line(enemy.position,enemy.position+enemy.locked_dir*440,Color(1,0.35,0.45,0.8),3,true)
