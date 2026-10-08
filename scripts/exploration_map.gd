extends Control
var game
var expanded: bool = false
var font = SystemFont.new()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
func _process(_delta: float) -> void:
	visible = game.rooms.active and is_instance_valid(game.player) and (expanded or game.state=="combat")
	if visible: queue_redraw()
func _draw() -> void:
	if not game.rooms.active: return
	var data: Dictionary = game.rooms.data
	var step = Vector2(165,155) if expanded else Vector2(44,25)
	var base = Vector2(90,220) if expanded else Vector2(27,57)
	var dims = Vector2(105,66) if expanded else Vector2(25,15)
	var discovered: Array = []
	for id in data.rooms:
		var r: Dictionary = data.rooms[id]
		if r.visited:
			if not discovered.has(id): discovered.append(id)
			for next in r.neighbors:
				if next=="secret" and not data.revealed: continue
				if not discovered.has(next): discovered.append(next)
	draw_style_box(panel_style(),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(16,22),"探索路线" if expanded else "%s 地图 · %s 交互"%[game.bindings.text("map"),game.bindings.text("interact")],HORIZONTAL_ALIGNMENT_LEFT,-1,23 if expanded else 16,Color("#dac997"))
	for id in discovered:
		var r: Dictionary = data.rooms[id]
		var p = base+Vector2(r.grid[0],r.grid[1])*step
		for next in r.neighbors:
			if discovered.has(next):
				var n: Dictionary = data.rooms[next]
				draw_line(p,base+Vector2(n.grid[0],n.grid[1])*step,Color("#526782"),4)
	for id in discovered:
		var r: Dictionary = data.rooms[id]
		var p = base+Vector2(r.grid[0],r.grid[1])*step
		var color = Color("#78d6bb") if r.cleared and r.visited else Color("#566983")
		if r.kind=="boss": color = Color("#e58b9b")
		if r.kind=="secret": color = Color("#bb9dec")
		draw_rect(Rect2(p-dims*0.5,dims),color.darkened(0.6))
		draw_rect(Rect2(p-dims*0.5,dims),color,false,2)
		if id==data.current:
			draw_rect(Rect2(p-dims*0.5-Vector2(4,4),dims+Vector2(8,8)),Color("#ffe3a3"),false,2)
			var local_pos: Vector2 = (game.player.global_position-game.rooms.origin()-Vector2(960,555))/Vector2(1780,790)
			draw_circle(p+local_pos*dims,4,Color.WHITE)
		var code = {"start":"营","battle":"战","elite":"精","event":"宝" if r.event=="chest" else "奇","boss":"王","secret":"隐"}[r.kind]
		if expanded:
			draw_string(font,p+Vector2(-42,-8),game.rooms.Graph.NAMES[r.kind],HORIZONTAL_ALIGNMENT_LEFT,-1,21,color)
			draw_string(font,p+Vector2(-40,18),"危险 %d · %s"%[int(r.get("danger",1)),str(r.get("reward_hint","未知奖励"))],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#e1c684"))
			draw_string(font,p+Vector2(-40,38),"已完成" if r.visited and r.cleared else ("已探索" if r.visited else str(r.get("enemy_hint","未知敌群"))),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#b1b9c6"))
		elif id!=data.current: draw_string(font,p+Vector2(-7,6),code,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
func panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.05,0.09,0.88)
	style.set_corner_radius_all(8)
	return style
