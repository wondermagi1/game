extends Node2D
## Tower weapons use their own damage and emitter, never the player's muzzle.
const Weapon = preload("res://scripts/weapon_art_v6.gd")
const TextureFX = preload("res://scripts/skill_textures.gd")
var game
var target
var destination := Vector2.ZERO
var direction := Vector2.RIGHT
var damage: float = 25.0
var kind: int = 0
var pierce: int = 1
var rank: int = 1
var life: float = 1.6
var hit_ids: Array[int] = []
var homing: bool = false

func _ready() -> void:
	z_index = 13
	direction = global_position.direction_to(destination)

func _physics_process(delta: float) -> void:
	if game.state!="combat": return
	life -= delta
	if life<=0: queue_free(); return
	if homing and is_instance_valid(target) and not target.dead:
		direction = global_position.direction_to(target.global_position)
	var origin = global_position
	var speed = 490.0 if kind==2 else 720.0
	global_position += direction*speed*delta
	rotation = direction.angle()
	if kind==2:
		if global_position.distance_to(destination)<speed*delta+12:
			game.tower_blast(destination,85+rank*10,damage,rank)
			queue_free()
	else:
		for enemy in game.enemies.duplicate():
			if not is_instance_valid(enemy) or enemy.dead or enemy.state=="spawn" or hit_ids.has(enemy.get_instance_id()): continue
			var nearest = Geometry2D.get_closest_point_to_segment(enemy.global_position,origin,global_position)
			if nearest.distance_to(enemy.global_position)>enemy.radius+10: continue
			hit_ids.append(enemy.get_instance_id())
			enemy.hurt(damage,false,false,"tower")
			game.fx.burst(enemy.global_position,Color("#b8e8ec"),4)
			pierce -= 1
			if pierce<=0: queue_free(); return
	queue_redraw()

func _draw() -> void:
	TextureFX.glow(self,Vector2(-18,0),Vector2(60,18),0,Color(0.6,0.9,1,0.22))
	if kind==2: TextureFX.grenade(self,25)
	else: Weapon.draw(self,0 if kind==0 else 5,48 if kind==0 else 55)
