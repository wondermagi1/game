extends RefCounted
var clock: float = 8
var pattern: int = 0
func reset() -> void:
	clock = 8
	pattern = 0
func tick(game, delta: float) -> void:
	if game.stage<5 or game.wave<=0: return
	if game.rooms.active and (game.rooms.current().cleared or game.rooms.current().kind!="boss"): return
	clock -= delta
	if clock>0: return
	clock = 12
	pattern += 1
	if game.stage==5:
		var gap = pattern%6
		for i in range(6):
			if i==gap or i==gap+1: continue
			game.add_hazard(game.ARENA.position+Vector2(190+i*280,290+(pattern%2)*250),90,1.7,18)
		game.notify_player("熔炉升温 · 横向火带留有缺口",2)
	else:
		var center: Vector2 = game.player.global_position
		game.add_hazard(center,95,1.8,22)
		game.add_hazard(game.safe_position(center+Vector2(160,0)),65,2.3,18)
		game.notify_player("星蚀锁定 · 离开光印",2)
