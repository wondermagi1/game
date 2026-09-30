extends CanvasLayer
## State-gated real-time intro; one exit function restores camera/input on skip or finish.
var game
var active: bool = false
var clock: float = 0
var boss
var old_position: Vector2
var old_zoom: Vector2
var stage_root: Control
var heading: Label
var subtitle: Label
var vignette: ColorRect
var portrait
var seen: Dictionary = {}
var testing: bool = false
func _ready() -> void:
	layer = 220
func start(enemy) -> void:
	if active or not is_instance_valid(enemy) or game.state!="combat": return
	if game.test_mode and not testing: return
	var key = str(enemy.kind)
	if game.skip_boss_intro and seen.has(key): return
	seen[key] = true
	game.save_settings()
	boss = enemy
	active = true
	clock = 0
	old_position = game.camera.position
	old_zoom = game.camera.zoom
	game.state = "cinematic"
	stage_root = Control.new()
	stage_root.size = Vector2(1920,1080)
	stage_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stage_root)
	vignette = ColorRect.new()
	vignette.size = Vector2(1920,1080)
	vignette.color = Color(0.02,0.025,0.05,.25)
	stage_root.add_child(vignette)
	for y in [0,890]:
		var bar = ColorRect.new()
		bar.position.y = y
		bar.size = Vector2(1920,190)
		bar.color = Color("#080f19")
		stage_root.add_child(bar)
	portrait = preload("res://scripts/actor_visual.gd").new()
	portrait.enemy_id = enemy.kind
	portrait.kind = 10
	portrait.tint = enemy.visual.tint
	portrait.position = Vector2(1410,765)
	portrait.scale = Vector2.ONE*3.8
	portrait.casting = true
	portrait.action = 3
	stage_root.add_child(portrait)
	heading = game.ui.label(stage_root,game.Catalog.ENEMIES[enemy.kind],Rect2(190,430,1040,110),78,Color("#efd59d"))
	subtitle = game.ui.label(stage_root,("温泉主人 / " if enemy.kind==14 else "试炼之敌 / ")+game.flow.title(),Rect2(195,370,880,50),27,Color("#aec5ce"))
	var intro_text: String = game.Catalog.ENEMY_TEXT[enemy.kind]
	if enemy.kind==14:
		intro_text = "头顶一颗橘子，慢悠悠地守着温泉。\n躲开泡泡和水花，等它泡澡时再反击。\n来一场轻松的切磋吧！"
	game.ui.label(stage_root,intro_text,Rect2(195,575,825,180),26)
	game.ui.label(stage_root,"空格 / Enter / Esc 或点击跳过",Rect2(1390,956,450,45),22,Color("#bac5d2"))
	game.sound.play("boss_intro")
func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE]:
		finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		finish()
		get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if not active: return
	if game.state!="cinematic" or not is_instance_valid(boss):
		finish(false)
		return
	clock += delta
	var t = smoothstep(0,1,minf(clock/.55,1))
	stage_root.modulate.a = minf(t,(3.2-clock)*4)
	heading.position.x = 190+(1-t)*45
	portrait.position.x = 1410+(1-t)*130
	portrait.action = maxf(.1,3.2-clock)
	if not game.reduced_motion:
		game.camera.position = old_position.lerp(boss.global_position,t*.22)
		game.camera.zoom = old_zoom.lerp(old_zoom*1.08,t)
	if clock>=3.2: finish()
func finish(resume: bool = true) -> void:
	if not active: return
	active = false
	game.camera.position = old_position
	game.camera.zoom = old_zoom
	game.camera.offset = Vector2.ZERO
	if is_instance_valid(stage_root):
		stage_root.queue_free()
	if resume and game.state=="cinematic":
		game.state = "combat" if game.focused else "paused"
		if game.state=="paused": game.ui.show_pause()
	if is_instance_valid(game.player): game.player.attack_input_armed = false
	boss = null
