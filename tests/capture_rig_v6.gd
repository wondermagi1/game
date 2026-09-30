extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var panel=Control.new()
	root.add_child(panel)
	var bg=ColorRect.new();bg.size=Vector2(1920,1080);bg.color=Color("#202a36");panel.add_child(bg)
	for role in range(3):
		for direction in range(8):
			var actor=load("res://scripts/actor_visual.gd").new()
			actor.kind=role;actor.aim=Vector2.from_angle(direction*PI/4)
			actor.position=Vector2(120+direction*235,290+role*340)
			actor.scale=Vector2.ONE*1.7
			actor.forced_clip="ready"
			panel.add_child(actor)
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../v6-rig-directions.png"))
	print("RIG_CAPTURE_OK")
	quit()
