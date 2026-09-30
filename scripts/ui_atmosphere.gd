extends Control
const P = preload("res://scripts/presentation.gd")
var game
var menu: bool = false
var clock: float = 0
var backdrop: TextureRect
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(1920,1080)
	backdrop = TextureRect.new()
	backdrop.texture = P.BACKGROUND
	backdrop.position = Vector2(-12,-10)
	backdrop.size = Vector2(1944,1100)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var dim = ColorRect.new()
	dim.size = Vector2(1920,1080)
	dim.color = Color(.018,.035,.06,.28 if menu else .87)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)
	var motes = preload("res://scripts/ui_motes.gd").new()
	motes.game = game
	motes.menu = menu
	add_child(motes)
func _process(delta: float) -> void:
	if game==null or game.reduced_motion: return
	clock += delta
	if is_instance_valid(backdrop) and game.menu_parallax:
		backdrop.position = Vector2(-12,-10)+(get_global_mouse_position().clamp(Vector2.ZERO,Vector2(1920,1080))-Vector2(960,540))*.006
	queue_redraw()
