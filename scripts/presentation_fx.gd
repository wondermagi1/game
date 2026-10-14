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
	var key = kind+str(role)
	if cooldowns.get(key,0)>0: return
	cooldowns[key] = .10 if kind=="shot" else (.10 if kind=="v11_sustain" else (.04 if role==1 else (.15 if kind=="explosion" else .06)))
	materials.emit(kind,pos,dir,role,strength,game.effects_intensity)
	# Existing explosion rings/sparks already cover secondary debris. Avoid duplicating
	# their full particle burst for every chained hit at deep-abyss stack counts.
	if kind=="explosion":return
	var base_count=3 if kind=="shot" else (7 if kind.begins_with("v11_") else 12)
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
	# Soft textured embers stay subordinate to solid bullets/swords/arrows.
	for p in particles:
		var a: float = p.life/p.max
		preload("res://scripts/skill_textures.gd").glow(self,p.p,Vector2(p.size*3,p.size*1.6)*a,p.v.angle(),Color(p.color,.42*a))
