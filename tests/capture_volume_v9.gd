extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func label(value: String,position: Vector2,size: int,color:=Color.WHITE) -> Label:
	var result=Label.new();result.text=value;result.position=position
	result.add_theme_font_size_override("font_size",size);result.add_theme_color_override("font_color",color)
	return result

func run() -> void:
	var panel=Control.new();root.add_child(panel)
	var background=ColorRect.new();background.size=Vector2(1920,1080);background.color=Color("#09121c");panel.add_child(background)
	panel.add_child(label("V9 · 三职业 C 技能体积核心",Vector2(70,36),38,Color("#f3dca4")))
	panel.add_child(label("新贴图负责烟雾、火焰、能量与星风体积；原有剑阵、热流、弓阵和冲击层继续叠加",Vector2(70,90),21,Color("#aebed2")))
	var system=preload("res://scripts/material_fx.gd").new()
	var layer=preload("res://scripts/material_fx_layer.gd").new();layer.system=system;panel.add_child(layer)
	var names=["剑修 · 万剑灵涡","火枪手 · 炼狱爆燃","游侠 · 群星风眼"]
	var colors=[Color("#8ff7ef"),Color("#ffb269"),Color("#a5e9bc")]
	for role in range(3):
		var center=Vector2(340+role*620,520)
		panel.add_child(label(names[role],center+Vector2(-150,-285),25,colors[role]))
		system.emit("v8_gather",center,Vector2.RIGHT,role,3.2,1.0)
		system.emit("v8_sustain",center,Vector2.RIGHT,role,2.4,1.0)
		system.emit("v8_finish",center,Vector2.RIGHT,role,4.2,1.0)
	for i in range(5):system.tick(.025);layer.queue_redraw();await process_frame
	var folder=ProjectSettings.globalize_path("res://docs/screenshots-v9");DirAccess.make_dir_recursive_absolute(folder)
	var path=folder.path_join("04-ultimate-volume-cores.png")
	root.get_texture().get_image().save_png(path)
	print("VOLUME_V9_CAPTURE="+path)
	quit()
