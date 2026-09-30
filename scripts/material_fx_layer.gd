extends Node2D
var system
func _draw() -> void:
	if system!=null:system.draw(self)
