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
	draw_rect(Rect2(-32,-24,65,65),Color(0,0,0,0.4))
	draw_rect(Rect2(-32,-32,65,65),Color("#75583d"))
	draw_rect(Rect2(-27,-27,55,55),Color("#b99467"),false,5)
	draw_line(Vector2(-25,-25),Vector2(25,25),Color("#b99467"),5)
	draw_line(Vector2(-25,25),Vector2(25,-25),Color("#b99467"),5)
