extends Control
const P = preload("res://scripts/presentation.gd")
var role: int = 0
var slot: int = 0
var quality: int = 0
var rank: int = 0
var animated: bool = false
var clock: float = 0
var texture: Texture2D
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture = P.gear_texture(role,slot)
	if animated and quality>0:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = preload("res://art/v5/gear_glint.gdshader")
		shader_material.set_shader_parameter("strength",.06+quality*.025)
		material = shader_material
func _process(delta: float) -> void:
	if not animated: return
	clock += delta
	if material is ShaderMaterial: material.set_shader_parameter("phase",clock)
	queue_redraw()
func _draw() -> void:
	var c: Color = P.QUALITY[quality]
	var center = size/2
	var r = minf(size.x,size.y)*0.47
	draw_style_box(frame(c),Rect2(Vector2.ZERO,size))
	if animated:
		for i in range(8):
			var d = Vector2.from_angle(i*TAU/8+clock*.25)
			draw_line(center+d*r*0.85,center+d*r,Color(c,0.38),2,true)
		draw_arc(center,r*0.96,clock*.6,clock*.6+1.5,24,Color(c,.5),2,true)
	if texture!=null: draw_texture_rect(texture,Rect2(size*.12,size*.76),false)
	for i in range(quality+1):
		var p = Vector2(size.x/2+(i-quality*.5)*9,size.y-8)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-3),p+Vector2(3,0),p+Vector2(0,3),p+Vector2(-3,0)]),c)
func frame(c: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color("#12262e")
	s.border_color = Color(c,.65)
	s.set_border_width_all(2 if quality>1 else 1)
	s.set_corner_radius_all(8)
	return s
