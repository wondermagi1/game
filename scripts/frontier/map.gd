extends Node2D
var game
func point(p: Vector2) -> Vector2:
	return (p+Vector2(65,65))*4.8
func _draw() -> void:
	draw_style_box(make_style(),Rect2(-18,-18,660,660))
	for path in game.Terrain.PATHS:
		var points = PackedVector2Array()
		for p in path: points.append(point(p))
		draw_polyline(points,Color("#637e8b"),4,true)
	var font: Font = game.ui.hud.theme.default_font
	for site in game.sites:
		if not game.discovered.has(site.id): continue
		var p = point(site.pos)
		var done = game.claimed.has(site.id) or game.cleared.has(site.id) or game.rested.has(site.id)
		draw_circle(p,7,Color("#a7d7bd") if done else Color("#e8c78e"))
		if game.waypoint==site.id: draw_arc(p,14,0,TAU,32,Color("#ffe9af"),2,true)
		draw_string(font,p+Vector2(12,5),site.name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#d6e7e6"))
	var p = point(Vector2(game.player.position.x,game.player.position.z))
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-10),p+Vector2(-7,7),p+Vector2(7,7)]),Color.WHITE)

func _input(event: InputEvent) -> void:
	if game.state!="map" or not event is InputEventMouseButton: return
	if event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed: return
	var mouse: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
	if not Rect2(0,0,624,624).has_point(mouse): return
	var closest_id = ""
	var closest_distance = 30.0
	for site in game.sites:
		if not game.discovered.has(site.id): continue
		var distance_value = point(site.pos).distance_to(mouse)
		if distance_value<closest_distance:
			closest_id = site.id
			closest_distance = distance_value
	if game.set_waypoint(closest_id):
		queue_redraw()
		get_viewport().set_input_as_handled()
func make_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#223e4c")
	style.border_color = Color("#77939b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style
