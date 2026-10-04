extends RefCounted
## Presentation-only five-stage routing. Combat timing and damage remain authoritative elsewhere.
var game
var active: Dictionary = {}
var heavy_hit_cooldown: float = 0.0
const PHASES = ["anticipation","release","sustain","impact","residue"]

func tick(delta: float) -> void:
	heavy_hit_cooldown=maxf(0,heavy_hit_cooldown-delta)

func begin_ultimate(origin: Vector2, target: Vector2, direction: Vector2, role: int, rank: int, duration: float) -> void:
	active={"role":role,"rank":rank,"duration":duration,"phase":"anticipation","origin":origin,"target":target}
	game.presentation_fx.emit("v11_anticipation",origin,direction,role,2.0+rank*.08)
	game.screen_fx.gather(origin,role,1.5+rank*.08)

func release_ultimate(origin: Vector2, direction: Vector2, role: int, rank: int) -> void:
	if not active.is_empty():active.phase="release"
	game.presentation_fx.emit("v11_release",origin,direction,role,2.0+rank*.10)
	game.screen_fx.release(origin,role,direction,1.5+rank*.08)

func sustain_ultimate(pos: Vector2, direction: Vector2, role: int, rank: int) -> void:
	if not active.is_empty():active.phase="sustain"
	game.presentation_fx.emit("v11_sustain",pos,direction,role,1.0+rank*.06)

func impact_ultimate(pos: Vector2, role: int, rank: int, heavy: bool = false) -> void:
	if not active.is_empty():active.phase="impact"
	game.presentation_fx.emit("v11_impact",pos,Vector2.UP,role,1.4+rank*.08)
	game.screen_fx.impact(pos,role,1.2+rank*.10,heavy)

func finish_ultimate(pos: Vector2, direction: Vector2, role: int, rank: int, radius: float) -> void:
	game.presentation_fx.emit("v11_finish",pos,direction,role,2.6+rank*.12)
	game.screen_fx.impact(pos,role,2.7+rank*.12,true)
	game.ground_residue.add(pos,role,radius,1.15+(rank/10.0)*.55,1.0+rank*.05)
	active={"role":role,"rank":rank,"phase":"residue","target":pos}

func combo(pos: Vector2, role: int, title: String) -> void:
	game.fx.combo_burst(pos,role,title)
	game.presentation_fx.emit("v11_combo",pos,Vector2.UP,role,2.2)
	game.screen_fx.combo(pos,role)

func heavy_hit(pos: Vector2, source: String, power: float) -> void:
	if heavy_hit_cooldown>0 or not is_instance_valid(game.player):return
	heavy_hit_cooldown=.065
	var role: int=game.player.stats.role
	game.presentation_fx.emit("v11_hit",pos,game.player.global_position.direction_to(pos),role,clampf(power,1,4))
	game.screen_fx.impact(pos,role,clampf(power,1,3),false)

func clear() -> void:
	active.clear();heavy_hit_cooldown=0
