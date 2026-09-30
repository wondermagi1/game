extends Node2D
## Shares the actual visual weapon emitter; no player, hitbox, RNG or profile writes.
var game
var role: int = 0
var slot: int = 0
var rank: int = 1
var clock: float = 0
var art
var clock_game = {"state":"combat"}
func _ready() -> void:
	art = preload("res://scripts/skill_art.gd").new()
	art.game = clock_game
	add_child(art)
	var hero = preload("res://scripts/actor_visual.gd").new()
	hero.kind = role
	hero.scale = Vector2.ONE*2
	hero.position = Vector2(-340,40)
	hero.casting = true
	hero.action = 10
	add_child(hero)
func _process(delta: float) -> void:
	clock -= delta
	if clock<=0:
		clock = 2.2
		art.emit("gather" if slot==3 else (["slash","blast","bow"][role]),Vector2.ZERO,Vector2.RIGHT,150+rank*9,.8,role)
		art.emit("finish" if slot==3 else "fall",Vector2(80,20),Vector2.RIGHT,180+rank*12,1.2,role)
