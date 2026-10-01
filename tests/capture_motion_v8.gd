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
	var panel=Control.new();root.add_child(panel)
	var background=ColorRect.new();background.size=Vector2(1920,1080);background.color=Color("#0e1822");panel.add_child(background)
	panel.add_child(label("灵境重铸 · 三职业普攻动作阶段",Vector2(70,35),38))
	panel.add_child(label("每列依次为释放、冲击、回弹与收势；人物和武器保持同一完整帧",Vector2(70,88),22))
	var names=["剑修 · 前压斩势","火枪手 · 后坐回弹","游侠 · 弓身释力"]
	for role in range(3):
		panel.add_child(label(names[role],Vector2(45,250+role*290),24))
		for phase in range(6):
			var actor=preload("res://scripts/actor_visual.gd").new()
			actor.kind=role;actor.aim=Vector2.RIGHT;actor.facing_index=0
			actor.clip="attack";actor.forced_clip="attack";actor.override_phase=(phase+.01)/6.0
			actor.position=Vector2(250+phase*285,330+role*290);actor.scale=Vector2.ONE*1.65;actor.debug_joints=true
			panel.add_child(actor);actor._process(0.0);actor.set_process(false)
			panel.add_child(label(str(phase+1),Vector2(242+phase*285,405+role*290),18))
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var folder=ProjectSettings.globalize_path("res://docs/screenshots-v8")
	DirAccess.make_dir_recursive_absolute(folder)
	var path=folder.path_join("01-role-attack-motion.png")
	root.get_texture().get_image().save_png(path)
	print("MOTION_V8_CAPTURE="+path)
	quit()
