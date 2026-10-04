extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func make_label(value: String,position: Vector2,size: int,color:=Color.WHITE) -> Label:
	var result=Label.new()
	result.text=value
	result.position=position
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	return result

func make_panel(title: String,subtitle: String) -> Control:
	var panel=Control.new()
	root.add_child(panel)
	var background=ColorRect.new()
	background.size=Vector2(1920,1080)
	background.color=Color("#0b1420")
	panel.add_child(background)
	panel.add_child(make_label(title,Vector2(70,34),38,Color("#f3dca4")))
	panel.add_child(make_label(subtitle,Vector2(70,87),21,Color("#aebed2")))
	return panel

func make_actor(role: int,direction: int,phase: int,position: Vector2,scale_factor: float) -> Node2D:
	var actor=preload("res://scripts/actor_visual.gd").new()
	actor.kind=role
	actor.aim=Vector2.from_angle(direction*PI/4.0)
	actor.facing_index=direction
	actor.clip="attack"
	actor.forced_clip="attack"
	actor.override_phase=(phase+.01)/6.0
	actor.position=position
	actor.scale=Vector2.ONE*scale_factor
	actor.debug_joints=true
	actor._process(0.0)
	actor.set_process(false)
	return actor

func capture(panel: Control,name: String) -> void:
	# Six rendered frames are enough for resources and draw commands to settle.
	# Awaiting frame_post_draw can stall indefinitely on Windows headless builds.
	for i in range(6):await process_frame
	var folder=ProjectSettings.globalize_path("res://docs/screenshots-v9")
	DirAccess.make_dir_recursive_absolute(folder)
	var path=folder.path_join(name)
	root.get_texture().get_image().save_png(path)
	print("ACTION_V9_CAPTURE="+path)
	panel.queue_free()
	await process_frame

func run() -> void:
	var names=["剑修 · 蓄势斩击","火枪手 · 肩托后坐","游侠 · 拉弓释力"]
	var phases=["蓄势","压缩","释放","延展","回弹","收势"]
	var panel=make_panel("灵境重铸 · 三职业真实攻击关键帧","每列使用独立位图轮廓；手、武器、躯干与重心随阶段共同变化")
	for phase in range(6):panel.add_child(make_label(phases[phase],Vector2(220+phase*285,135),18,Color("#78d7e5")))
	for role in range(3):
		panel.add_child(make_label(names[role],Vector2(45,265+role*285),23))
		for phase in range(6):panel.add_child(make_actor(role,0,phase,Vector2(260+phase*285,345+role*285),1.65))
	await capture(panel,"01-three-role-attack-keyframes.png")

	panel=make_panel("灵境重铸 · 四方向释放姿态","四个绘制朝向覆盖八方向输入；红点为动态武器/弹道挂点")
	var directions=[0,2,4,6]
	var direction_names=["向右","向下","向左","向上"]
	for column in range(4):panel.add_child(make_label(direction_names[column],Vector2(320+column*430,135),20,Color("#78d7e5")))
	for role in range(3):
		panel.add_child(make_label(names[role],Vector2(45,300+role*285),23))
		for column in range(4):panel.add_child(make_actor(role,directions[column],2,Vector2(390+column*430,370+role*285),1.9))
	await capture(panel,"02-four-direction-release.png")
	quit()
