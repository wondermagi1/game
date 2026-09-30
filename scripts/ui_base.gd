extends CanvasLayer
const Data = preload("res://scripts/data.gd")
const Visual = preload("res://scripts/actor_visual.gd")
var game
var overlay: Control
var hud: Control
var font = SystemFont.new()
var health: ProgressBar
var health_label: Label
var stage_label: Label
var detail_label: Label
var skill_label: Label
var ammo_label: Label
var banner_label: Label
var boss_label: Label
var boss_bar: ProgressBar
const GOLD := Color("#dcc391")
const WHITE := Color("#edf3f7")
const MUTED := Color("#8d9eb5")
const INK := Color("#111b2b")

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	layer = 100
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	build_hud()


func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	return s


func box(parent: Node, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var p = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel",style(color,border))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func label(parent: Node, text: String, rect: Rect2, size: int = 26, color: Color = WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_override("font",font)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func button(parent: Node, text: String, rect: Rect2, callback: Callable, accent: Color = GOLD) -> Button:
	var b = Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",27)
	b.add_theme_color_override("font_color",WHITE)
	b.add_theme_stylebox_override("normal",style(Color("#1b2a3c"),Color(accent,0.45)))
	b.add_theme_stylebox_override("hover",style(Color("#2c3f53"),accent))
	b.add_theme_stylebox_override("pressed",style(Color("#40526a"),accent))
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,accent))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func clear_overlay() -> void:
	if is_instance_valid(game.player): game.player.attack_input_armed = false
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	hud.visible = game.state in ["combat","paused","reward"]


func shade() -> void:
	var dim = ColorRect.new()
	dim.color = Color(0.025,0.035,0.060,0.93)
	dim.size = Vector2(1920,1080)
	overlay.add_child(dim)


func heading(kicker: String, title: String, subtitle: String) -> void:
	label(overlay,kicker,Rect2(130,70,1600,36),20,GOLD)
	label(overlay,title,Rect2(126,123,1650,88),64)
	label(overlay,subtitle,Rect2(130,215,1630,65),25,MUTED)


func portrait(parent: Node, role: int, pos: Vector2, scale_value: float) -> void:
	var v = Visual.new()
	v.kind = role
	v.tint = Data.ROLES[role].color
	v.position = pos
	v.scale = Vector2.ONE*scale_value
	v.aim = Vector2(0.9,-0.2)
	v.walking = 0.2
	parent.add_child(v)


func show_settings(in_run: bool) -> void:
	clear_overlay()
	shade()
	heading("SETTINGS","设置","音量与反馈选项会保存在本机。")
	var check1 = CheckButton.new()
	check1.text = "显示伤害数字"
	check1.button_pressed = game.show_numbers
	check1.position = Vector2(160,375)
	check1.size = Vector2(700,70)
	check1.add_theme_font_override("font",font)
	check1.add_theme_font_size_override("font_size",30)
	check1.toggled.connect(func(value): game.show_numbers=value; game.save_settings())
	overlay.add_child(check1)
	var check2 = CheckButton.new()
	check2.text = "启用受伤镜头抖动"
	check2.button_pressed = game.screen_shake
	check2.position = Vector2(160,470)
	check2.size = Vector2(700,70)
	check2.add_theme_font_override("font",font)
	check2.add_theme_font_size_override("font_size",30)
	check2.toggled.connect(func(value): game.screen_shake=value; game.save_settings())
	overlay.add_child(check2)
	label(overlay,"音效音量",Rect2(160,590,600,50),30)
	var slider = HSlider.new()
	slider.position = Vector2(165,675)
	slider.size = Vector2(750,45)
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = game.sound.volume
	slider.value_changed.connect(func(value): game.sound.volume=value; game.save_settings())
	overlay.add_child(slider)
	label(overlay,"特效密度（保留危险提示）",Rect2(1060,375,640,55),28)
	var intensity = HSlider.new()
	intensity.position = Vector2(1060,470)
	intensity.size = Vector2(600,45)
	intensity.min_value = 0.2
	intensity.max_value = 1
	intensity.step = 0.1
	intensity.value = game.effects_intensity
	intensity.value_changed.connect(func(value): game.effects_intensity=value; game.save_settings())
	overlay.add_child(intensity)
	button(overlay,"← 返回",Rect2(160,825,330,75),return_from_settings.bind(in_run))


func return_from_settings(in_run: bool) -> void:
	if in_run:
		show_pause()
	else:
		show_menu()


func build_hud() -> void:
	pass

func show_menu() -> void:
	pass

func show_pause(_stats_view: bool = false) -> void:
	pass
