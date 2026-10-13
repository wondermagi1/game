extends StaticBody2D
var room
var uid: String = ""
var hp: float = 45
var broken: bool = false
func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(65,65)
	shape.shape = rectangle
	add_child(shape)
func hurt(amount: float) -> void:
	if broken: return
	hp -= amount
	if hp>0: return
	broken = true
	collision_layer = 0
	room.destroy_crate(self)
	queue_free()
func _draw() -> void:
	preload("res://scripts/western_art.gd").prop(self,9,Rect2(-33,-38,66,76),Color.WHITE,false)
