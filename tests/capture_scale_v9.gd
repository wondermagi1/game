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

func make_actor(role: int,clip_name: String,phase: int,position: Vector2) -> Node2D:
	var actor=preload("res://scripts/actor_visual.gd").new()
	actor.kind=role
	actor.aim=Vector2.RIGHT
	actor.facing_index=0
	actor.clip=clip_name
	actor.forced_clip=clip_name
	actor.override_phase=(phase+.01)/6.0 if clip_name=="attack" else -1.0
	actor.position=position
	actor.scale=Vector2.ONE*1.8
	actor._process(0.0)
	actor.set_process(false)
	return actor

func run() -> void:
	var panel=Control.new();root.add_child(panel)
	var background=ColorRect.new();background.size=Vector2(1920,1080);background.color=Color("#0b1420");panel.add_child(background)
	panel.add_child(make_label("V9 · 普攻尺寸连续性",Vector2(70,34),38,Color("#f3dca4")))
	panel.add_child(make_label("所有样本使用完全相同的节点缩放；青色基线为角色原点",Vector2(70,87),21,Color("#aebed2")))
	var columns=["待机","蓄势","释放","收势","回到待机"]
	var clips=["ready","attack","attack","attack","ready"]
	var phases=[0,0,2,5,0]
	for column in range(5):panel.add_child(make_label(columns[column],Vector2(235+column*340,145),20,Color("#78d7e5")))
	var names=["剑修","火枪手","游侠"]
	for role in range(3):
		var y=330+role*290
		panel.add_child(make_label(names[role],Vector2(60,y-20),24))
		for column in range(5):
			var x=280+column*340
			panel.add_child(make_actor(role,clips[column],phases[column],Vector2(x,y)))
			var line=ColorRect.new();line.color=Color(0,.9,1,.65);line.position=Vector2(x-90,y);line.size=Vector2(180,2);panel.add_child(line)
	for i in range(6):await process_frame
	var folder=ProjectSettings.globalize_path("res://docs/screenshots-v9");DirAccess.make_dir_recursive_absolute(folder)
	var path=folder.path_join("03-attack-scale-continuity.png")
	root.get_texture().get_image().save_png(path)
	print("ACTION_V9_SCALE_CAPTURE="+path)
	quit()
