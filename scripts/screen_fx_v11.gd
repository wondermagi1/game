extends Node2D
## Short, bounded camera/light/impact feedback. UI remains in a separate canvas layer.
var game
var pulses: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var light_pool: Array[PointLight2D] = []
var distortion
var flash: float = 0.0
var zoom_kick: float = 0.0
var impact_cooldown: float = 0.0
const COLORS = [Color("#8effe8"),Color("#ffad62"),Color("#b9edb4")]
const LIGHT_TEXTURE = preload("res://art/v11/radial_light.svg")

func _ready() -> void:
	z_index = 28
	# Reuse the same small light set for every impact. This avoids allocating
	# short-lived nodes when several skills land during a dense encounter.
	for i in range(5):
		var light := PointLight2D.new()
		light.texture = LIGHT_TEXTURE
		light.enabled = false
		light.visible = false
		light.shadow_enabled = false
		light.range_z_min = 0
		light.range_z_max = 40
		add_child(light)
		light_pool.append(light)
	distortion = preload("res://scripts/impact_distortion_v11.gd").new()
	add_child(distortion)
	distortion.reset()

func gather(pos: Vector2, role: int, power: float) -> void:
	add_pulse(pos,role,80+power*18,.38,"gather")

func release(pos: Vector2, role: int, direction: Vector2, power: float) -> void:
	add_pulse(pos+direction*24,role,72+power*15,.22,"release")
	add_light(pos,role,100+power*22,.18,.65)

func impact(pos: Vector2, role: int, power: float, heavy: bool = false) -> void:
	if impact_cooldown>0 and not heavy: return
	impact_cooldown = .045 if heavy else .075
	var radius := clampf(95+power*32,110,330)
	add_pulse(pos,role,radius,.34 if heavy else .22,"impact")
	add_light(pos,role,radius,.20 if heavy else .12,1.15 if heavy else .72)
	if heavy:
		flash = maxf(flash,.16*game.effects_intensity)
		zoom_kick = maxf(zoom_kick,.035*game.effects_intensity)
		game.shake_strength = maxf(game.shake_strength,5.5*game.effects_intensity)
		if not game.reduced_motion and game.effects_intensity>=.62: add_distortion(pos,radius,5.5*game.effects_intensity)
	else:
		game.shake_strength = maxf(game.shake_strength,2.0*game.effects_intensity)

func combo(pos: Vector2, role: int) -> void:
	add_pulse(pos,role,190,.38,"combo")
	add_light(pos,role,210,.24,.85)
	flash = maxf(flash,.07*game.effects_intensity)
	if not game.reduced_motion: zoom_kick=maxf(zoom_kick,.014*game.effects_intensity)

func add_pulse(pos: Vector2, role: int, radius: float, duration: float, kind: String) -> void:
	if pulses.size()>=8: pulses.pop_front()
	pulses.append({"p":pos,"role":clampi(role,0,2),"r":radius,"life":duration,"max":duration,"kind":kind})
	queue_redraw()

func add_light(pos: Vector2, role: int, radius: float, duration: float, energy: float) -> void:
	if game.effects_intensity<.45: return
	var light: PointLight2D
	if lights.size()>=light_pool.size():
		var oldest=lights.pop_front()
		light=oldest.node
	else:
		for candidate in light_pool:
			var active := false
			for item in lights:
				if item.node==candidate:active=true;break
			if not active:light=candidate;break
	if light==null:return
	light.enabled = true
	light.visible = true
	light.position = pos
	light.texture_scale = radius/128.0
	light.color = COLORS[clampi(role,0,2)]
	light.energy = energy*game.effects_intensity
	lights.append({"node":light,"life":duration,"max":duration,"energy":light.energy})

func add_distortion(pos: Vector2, radius: float, strength: float) -> void:
	distortion.position = pos
	distortion.setup(radius,strength)

func _process(delta: float) -> void:
	impact_cooldown=maxf(0,impact_cooldown-delta)
	flash=maxf(0,flash-delta*1.5)
	zoom_kick=move_toward(zoom_kick,0,delta*.18)
	for pulse in pulses: pulse.life-=delta
	pulses=pulses.filter(func(pulse):return pulse.life>0)
	for item in lights.duplicate():
		item.life-=delta
		if is_instance_valid(item.node):item.node.energy=item.energy*clampf(item.life/item.max,0,1)
		if item.life<=0:
			lights.erase(item)
			if is_instance_valid(item.node):item.node.energy=0;item.node.enabled=false;item.node.visible=false
	if is_instance_valid(game.camera) and game.state=="combat":
		game.camera.zoom=Vector2.ONE*(1.0+(0.0 if game.reduced_motion else zoom_kick))
	queue_redraw()

func clear() -> void:
	pulses.clear();flash=0;zoom_kick=0;impact_cooldown=0
	for item in lights:
		if is_instance_valid(item.node):item.node.energy=0;item.node.enabled=false;item.node.visible=false
	lights.clear()
	if is_instance_valid(distortion):distortion.reset()
	if is_instance_valid(game.camera): game.camera.zoom=Vector2.ONE
	queue_redraw()

func _draw() -> void:
	for pulse in pulses:
		var phase: float=1.0-pulse.life/pulse.max
		var color: Color=COLORS[pulse.role]
		var radius: float=pulse.r*(.18+.92*phase)
		var alpha: float=(1.0-phase)*(.54 if pulse.kind=="impact" else .34)
		draw_arc(pulse.p,radius,0,TAU,64,Color(color,alpha),7.0*(1.0-phase)+1.0,true)
		if pulse.kind in ["impact","combo"]:draw_circle(pulse.p,pulse.r*.18*(1.0-phase),Color(1,1,1,.10*(1.0-phase)))
	if flash>0 and is_instance_valid(game.camera):
		draw_rect(Rect2(game.camera.position-Vector2(960,540),Vector2(1920,1080)),Color(1,1,1,flash))
