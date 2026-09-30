extends Control
var game
var menu: bool = false
var clock: float = 0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if game.reduced_motion: return
	clock += delta
	queue_redraw()
func _draw() -> void:
	for i in range(18 if menu else 5):
		var p = Vector2(fposmod(i*137.13+sin(clock*.25+i)*14,1920),1080-fposmod(i*61+clock*(9+i%4),1080))
		draw_circle(p,1.2+i%2,Color(.65,.88,.83,.16+.08*sin(clock+i)))
