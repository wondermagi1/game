extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func label(value: String, position: Vector2, size: int) -> Label:
	var result=Label.new()
	result.text=value
	result.position=position
	result.add_theme_font_size_override("font_size",size)
	return result

func run() -> void:
	var panel=Control.new()
	root.add_child(panel)
	var background=ColorRect.new()
	background.size=Vector2(1920,1080)
	background.color=Color("#101923")
	panel.add_child(background)
	panel.add_child(label("三职业 · 8 相位速度驱动步态",Vector2(70,30),38))
	panel.add_child(label("完整人物与武器同步形变；青点为脚底基准，红点为武器出手位置",Vector2(70,82),22))
	var names=["剑修","火枪手","游侠"]
	for role in range(3):
		panel.add_child(label(names[role],Vector2(45,245+role*290),25))
		for phase in range(8):
			var actor=preload("res://scripts/actor_visual.gd").new()
			actor.kind=role
			actor.aim=Vector2.RIGHT
			actor.movement=Vector2.RIGHT
			actor.forced_clip="run_forward"
			actor.clip="run_forward"
			actor.override_phase=(phase+.01)/8.0
			actor.position=Vector2(190+phase*225,330+role*290)
			actor.scale=Vector2.ONE*1.45
			actor.debug_joints=true
			panel.add_child(actor)
			actor._process(0.0)
			actor.set_process(false)
			panel.add_child(label(str(phase+1),Vector2(181+phase*225,390+role*290),18))
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://docs/screenshots-v7/05-walk-eight-phase.png")
	root.get_texture().get_image().save_png(path)
	print("WALK_CAPTURE="+path)
	quit()
