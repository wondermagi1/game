extends Node2D
## Bounded ambient budget across the scrolling garden. No full-screen fog veil.
var room
var clock := 0.0
var petals: Array[Dictionary] = []
var strength := 1.0

func _ready() -> void:
	z_as_relative = false
	z_index = 9
	var rng := RandomNumberGenerator.new()
	rng.seed = 121087
	for i in range(72):
		petals.append({"p":Vector2(rng.randf_range(100,room.WORLD.x-100),rng.randf_range(100,room.WORLD.y-100)),"phase":rng.randf_range(0,TAU),"speed":rng.randf_range(12,26),"size":rng.randf_range(2,4)})

func _process(delta: float) -> void:
	if room.run!=null:
		strength = room.run.game.effects_intensity
		if room.run.game.reduced_motion: delta = 0
	clock += delta
	queue_redraw()

func _draw() -> void:
	for i in range(roundi(petals.size()*strength)):
		var petal: Dictionary = petals[i]
		var p: Vector2 = petal.p
		p.x = fposmod(p.x+clock*9+sin(clock*.7+petal.phase)*18,room.WORLD.x)
		p.y = fposmod(p.y+clock*petal.speed,room.WORLD.y)
		var s: float = petal.size
		draw_set_transform(p,sin(clock+petal.phase),Vector2(1,.6))
		draw_colored_polygon(PackedVector2Array([Vector2(-s,0),Vector2(0,-s*.8),Vector2(s,0),Vector2(0,s)]),Color(1,.77,.82,.62))
	draw_set_transform(Vector2.ZERO)
