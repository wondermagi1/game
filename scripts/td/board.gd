extends Node2D
const Detail = preload("res://scripts/skill_textures.gd")
const Atlas = preload("res://art/td/facilities.png")
var game
var effects: Array = []
var font = SystemFont.new()

func _ready() -> void:
	z_index = 1
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])

func _process(delta: float) -> void:
	if game.state=="combat":
		for effect in effects: effect.life -= delta
		effects = effects.filter(func(effect): return effect.life>0)
	if effects.size()>60: effects = effects.slice(-60)
	visible = game.state!="menu"
	queue_redraw()

func _draw() -> void:
	if game.state=="menu": return
	for route in game.ROUTES:
		draw_polyline(route,Color(0.06,0.12,0.17,0.50),68,true)
		draw_polyline(route,Color(0.73,0.72,0.59,0.17),56,true)
		for i in range(route.size()-1):
			var start: Vector2 = route[i]
			var direction: Vector2 = start.direction_to(route[i+1])
			for step in range(1,int(start.distance_to(route[i+1])/70)):
				var p = start+direction*step*70
				draw_line(p-direction.rotated(0.65)*10,p,Color(0.85,0.8,0.6,0.36),2,true)
				draw_line(p-direction.rotated(-0.65)*10,p,Color(0.85,0.8,0.6,0.36),2,true)
	for i in range(game.PADS.size()):
		var p: Vector2 = game.PADS[i]
		Detail.rune(self,p,Vector2(100,42),0,0.3 if game.tower_at(i)==null else 0.15)
		if game.state=="td_build":
			draw_string(font,p+Vector2(-8,45),str(i+1),HORIZONTAL_ALIGNMENT_CENTER,20,19,Color("#d8d3be"))
	if game.state=="td_build":
		var tower = game.tower_at(game.selected_pad)
		var radius_value = tower.reach() if tower!=null else game.TD.reach(game.selected_kind,1)
		draw_circle(game.PADS[game.selected_pad],radius_value,Color(0.45,0.8,0.8,0.06))
		draw_arc(game.PADS[game.selected_pad],radius_value,0,TAU,80,Color(0.6,0.9,0.85,0.35),2,true)
	Detail.glow(self,game.CORE-Vector2(0,45),Vector2(210,210),0,Color(0.5,0.8,1,0.25))
	draw_texture_rect_region(Atlas,Rect2(game.CORE-Vector2(90,175),Vector2(180,180)),game.TD.REGIONS[10])
	draw_string(font,game.CORE+Vector2(-53,35),"遗迹核心",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("#d7edee"))
	draw_rect(Rect2(game.CORE+Vector2(-55,47),Vector2(110,8)),Color("#263644"))
	draw_rect(Rect2(game.CORE+Vector2(-55,47),Vector2(110*game.core_hp/100,8)),Color("#9adcc6"))
	for patch in game.fire_patches:
		Detail.glow(self,patch.position,Vector2(patch.radius*2,patch.radius*0.9),0,Color(1,0.45,0.18,minf(0.22,patch.life*0.2)))
		Detail.rune(self,patch.position,Vector2(patch.radius*1.8,patch.radius),0,minf(0.25,patch.life*0.2))
	for effect in effects:
		var alpha = clampf(effect.life*2,0,1)
		if effect.radius>0:
			Detail.rune(self,effect.from,Vector2.ONE*effect.radius*2,0,alpha*0.4)
			Detail.glow(self,effect.from,Vector2.ONE*effect.radius,0,Color(effect.color,alpha*0.2))
		else:
			var points = PackedVector2Array([effect.from,effect.from.lerp(effect.to,0.35)+Vector2(0,-18),effect.from.lerp(effect.to,0.7)+Vector2(0,13),effect.to])
			draw_polyline(points,Color(effect.color,alpha*0.25),10,true)
			draw_polyline(points,Color(effect.color,alpha),2,true)
			Detail.glow(self,effect.to,Vector2(75,75),0,Color(effect.color,alpha*0.4))
