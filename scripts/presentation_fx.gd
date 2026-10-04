extends Node2D
## Pure presentation particles. Uses independent RNG and never calls combat code.
var game
var particles: Array = []
var rng = RandomNumberGenerator.new()
var cooldowns: Dictionary = {}
var materials=preload("res://scripts/material_fx.gd").new()
func _ready() -> void:
	z_index = 24
	rng.seed = 540519
func emit(kind: String, pos: Vector2, dir: Vector2, role: int, strength: float = 1) -> void:
	# These extra impact/explosion bursts did not exist in the V5 gunner.
	# game.explode still draws the original ring and sparks.
	if role==1 and kind in ["impact","explosion"]:return
	var key = kind+str(role)
	if cooldowns.get(key,0)>0: return
	cooldowns[key] = .10 if kind=="shot" else (.10 if kind=="v11_sustain" else (.04 if role==1 else (.15 if kind=="explosion" else .06)))
	materials.emit(kind,pos,dir,role,strength,game.effects_intensity)
	# Existing explosion rings/sparks already cover secondary debris. Avoid duplicating
	# their full particle burst for every chained hit at deep-abyss stack counts.
	if kind=="explosion":return
	var base_count=10 if kind=="shot" else (18 if kind.begins_with("v11_") else 38)
	var count = int(base_count*game.effects_intensity)
	var color: Color = preload("res://scripts/presentation.gd").ROLES[clampi(role,0,2)].color
	for i in range(mini(count,420-particles.size())):
		var heading = dir.rotated(rng.randf_range(-.4,.4)) if kind=="shot" else Vector2.from_angle(rng.randf()*TAU)
		var speed = rng.randf_range(50,190)*sqrt(strength)
		var life = rng.randf_range(.18,.6)
		particles.append({"p":pos,"v":heading*speed,"life":life,"max":life,"size":rng.randf_range(1.2,4.0),"color":color,"kind":kind,"role":role})
func _process(delta: float) -> void:
	if game.state not in ["combat","end"]: return
	for key in cooldowns: cooldowns[key] = maxf(0,cooldowns[key]-delta)
	materials.tick(delta)
	for p in particles:
		p.life -= delta
		p.p += p.v*delta
		p.v *= maxf(0,1-delta*2)
		if p.role==1: p.v.y += delta*80
	particles = particles.filter(func(p): return p.life>0)
	queue_redraw()
func clear() -> void:
	particles.clear()
	materials.bits.clear()
	cooldowns.clear()
	queue_redraw()
func _draw() -> void:
	materials.draw(self)
	# Batch cosmetic streaks by role instead of one polygon draw per particle.
	for role in range(3):
		var points = PackedVector2Array()
		for p in particles:
			if p.role!=role: continue
			var a: float = p.life/p.max
			var tail: Vector2 = p.v.normalized()*p.size*3*a
			points.append(p.p+tail*.25)
			points.append(p.p-tail)
		if not points.is_empty():
			var c: Color = preload("res://scripts/presentation.gd").ROLES[role].color
			draw_multiline(points,Color(c,.65),2,true)
