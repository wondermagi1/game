extends SceneTree

func label(text: String, position: Vector2, size: int=26) -> Label:
	var result:=Label.new();result.text=text;result.position=position;result.add_theme_font_size_override("font_size",size);result.add_theme_color_override("font_color",Color("#e8f7f3"));return result

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var canvas:=Node2D.new();root.add_child(canvas)
	var background:=ColorRect.new();background.color=Color("#0b1720");background.size=Vector2(1920,1080);canvas.add_child(background)
	canvas.add_child(label("三途试炼 · 剑修 3D 适配样板",Vector2(70,48),42))
	canvas.add_child(label("透明 3D 视口叠加二维战场 · 武器绑定手部 · 连续转向与动作状态",Vector2(72,108),22))
	var states=["ready","run_forward","attack","skill_0","dash","hurt","victory","death"]
	var names=["待机","移动","普攻","技能","闪避","受击","胜利","死亡"]
	for i in range(states.size()):
		var source=preload("res://scripts/actor_visual.gd").new()
		source.kind=0;source.aim=Vector2.RIGHT.rotated((i%4-1.5)*.22);source.movement=Vector2.RIGHT
		source.clip=states[i];source.forced_clip=states[i];source.override_phase=.30;source.clip_time=.30;source.clip_length=1
		source.visible=false;canvas.add_child(source);source.set_process(false);source._process(0.0)
		var adapter=preload("res://scripts/character_3d_sword.gd").new()
		adapter.state_source=source;adapter.position=Vector2(270+(i%4)*450,385+floori(i/4.0)*430);adapter.scale=Vector2.ONE*1.35
		canvas.add_child(adapter)
		canvas.add_child(label(names[i],adapter.position+Vector2(-42,125),24))
	await process_frame;await process_frame;await process_frame;await process_frame
	var image:=root.get_texture().get_image()
	image.save_png("res://docs/screenshots-v12/01-sword-3d-adapter.png")
	print("CAPTURE_3D_V12=res://docs/screenshots-v12/01-sword-3d-adapter.png")
	quit()

