@tool
extends Node2D
## Front/back painted cutout, mirrored facing, cloth deformation and separate 360° weapon.
const P = preload("res://scripts/presentation.gd")
const Art = preload("res://scripts/skill_art.gd")
@export_range(0,16) var kind: int = 0
var enemy_id: int = -1
var action: float = 0
var casting: bool = false
var dying: bool = false
var death_time: float = 0
var tint = Color("#8ee4ce")
var aim = Vector2.RIGHT
var walking: float = 0
var clock: float = 0
var flash: float = 0
var elite: bool = false
var quality: int = 0
var dash_trail: float = 0
var reduced: bool = false
func _process(delta: float) -> void:
	var owner_node = get_parent()
	if owner_node!=null and "game" in owner_node and owner_node.game!=null:
		reduced = owner_node.game.reduced_motion
		if owner_node.game.state not in ["combat","end","cinematic"]:
			if dying: death_time = minf(1,death_time+delta)
			queue_redraw()
			return
		if owner_node.game.state=="cinematic": delta = 0
	clock += delta
	action = maxf(0,action-delta)
	flash = maxf(0,flash-delta)
	dash_trail = maxf(0,dash_trail-delta)
	if dying: death_time = minf(1,death_time+delta*1.8)
	queue_redraw()
func weapon_layer() -> void:
	var role = clampi(kind,0,2)
	var c: Color = P.ROLES[role].color
	var recoil = sin(clampf(action/0.2,0,1)*PI)*5
	draw_set_transform(Vector2(aim.x*15,2)+aim*(7-recoil),aim.angle())
	if quality>0:
		draw_line(Vector2(-8,0),Vector2(47,0),Color(P.QUALITY[quality],0.15),10+quality*2,true)
	match role:
		0:
			Art.weapon(self,0,62,3.5,c)
			draw_line(Vector2(-30,0),Vector2(-43,sin(clock*8)*5),Color(c,0.6),2,true)
		1:
			draw_texture_rect_region(Art.WEAPONS,Rect2(-27,-4.7,78,14.1),Rect2(45,378,1460,265))
			if action>0 and not casting:
				draw_colored_polygon(PackedVector2Array([Vector2(44,0),Vector2(57,-7),Vector2(73,0),Vector2(57,7)]),Color("#ffdc94"))
		2:
			var pull = recoil*2
			draw_arc(Vector2(-8,0),35,-1.1,1.1,20,c,3,true)
			draw_line(Vector2(8,-31),Vector2(-8-pull,0),Color("#e6e4c9"),1,true)
			draw_line(Vector2(8,31),Vector2(-8-pull,0),Color("#e6e4c9"),1,true)
			Art.weapon(self,2,48,2.2,c)
	draw_set_transform(Vector2.ZERO)
var metal: StyleBoxFlat
func make_metal() -> StyleBoxFlat:
	if metal==null:
		metal = StyleBoxFlat.new()
		metal.bg_color = Color("#48535b")
		metal.border_color = Color("#dcb77b")
		metal.set_border_width_all(1)
		metal.set_corner_radius_all(2)
	return metal
func _draw() -> void:
	var hero = kind<3 and enemy_id<0
	var alpha = 1-death_time
	var motion = 0.0 if reduced else walking
	var bob = sin(clock*11)*motion*2
	draw_set_transform(Vector2(0,22),0,Vector2(1,0.3))
	draw_circle(Vector2.ZERO,25 if hero else 31,Color(0,0,0,0.32*alpha))
	draw_set_transform(Vector2.ZERO)
	if hero and aim.y<-.25: weapon_layer()
	var texture: Texture2D = P.HEROES if hero else P.ENEMIES
	var region: Rect2
	var height: float = 113
	if hero:
		region = P.ROLES[kind].back if aim.y<-.25 else P.ROLES[kind].front
	else:
		var display_id = enemy_id if enemy_id>=0 else kind-3
		if display_id>=15: display_id = [2,10,1,9][display_id-15]
		var index = clampi(display_id,0,13)
		region = P.ENEMY_REGIONS[P.ENEMY_LOOKS[index]]
		height = 160 if index in [4,5,6,7,8,12,13] else 100
		if enemy_id==14:
			texture = P.LULU
			region = Rect2(Vector2.ZERO,P.LULU.get_size())
			height = 186
	var width = height*region.size.x/region.size.y
	var lean = sin(clock*11)*motion*0.025 + death_time*1.35
	if action>0: lean += (-0.06 if casting else 0.08)*signf(aim.x)
	var facing = -1.0 if aim.x<0 else 1.0
	var light = 1.15 if reduced else 1.55
	var col = Color(light,light,light,alpha) if flash>0 else Color(1,1,1,alpha)
	if not hero: col = col.lerp(Color(tint,alpha),0.12)
	if dash_trail>0 and not reduced:
		draw_texture_rect_region(texture,Rect2(-width/2-aim.x*22,-height+28-aim.y*22,width,height),region,Color(tint,0.18))
	draw_set_transform(Vector2(0,bob+death_time*15),lean,Vector2(facing,1-death_time*0.35))
	# Smooth cloth deformation in strips, preserving the full painted silhouette.
	var slices = 12 if hero else 1
	for strip in range(slices):
		var y = float(strip)/slices
		var sy = region.size.y/slices
		var offset = sin(clock*7+y*4)*motion*pow(y,2)*2.3
		var dest = Rect2(-width/2+offset,-height+28+y*height,width,height/slices+0.15)
		draw_texture_rect_region(texture,dest,Rect2(region.position+Vector2(0,strip*sy),Vector2(region.size.x,sy)),col)
	draw_set_transform(Vector2.ZERO)
	if hero and aim.y>=-.25 and not dying: weapon_layer()
	if action>0 and casting:
		for i in range(5):
			var d = Vector2.from_angle(i*TAU/5+clock)
			draw_line(d*30,d*(36+action*14),Color(tint,alpha*0.6),2,true)
	if elite:
		for i in range(4):
			var d = Vector2.from_angle(i*TAU/4+PI/4)
			draw_colored_polygon(PackedVector2Array([d*34,d*43+d.orthogonal()*4,d*49,d*43-d.orthogonal()*4]),Color("#e7c082"))
