extends "res://scripts/ui_v5.gd"
func show_menu() -> void:
	super.show_menu()
	for child in overlay.get_children():
		if child is Label:child.text=child.text.replace("绮光铸影  0.5","合刃同行  0.6.2")
	button(overlay,"持械动作 · 检视室",Rect2(1470,220,360,60),show_action_inspector,Color("#9edccc"))
func show_action_inspector() -> void:
	page="actions";game.state="menu";clear_overlay();hud.hide()
	var panel=preload("res://scenes/ActionInspector.tscn").instantiate()
	overlay.add_child(panel);panel.closed.connect(show_menu)
func show_visual_settings(in_run: bool) -> void:
	super.show_visual_settings(in_run)
	button(overlay,"窗口分辨率 →",Rect2(1050,900,680,65),show_resolution_settings.bind(in_run))

func show_resolution_settings(in_run: bool) -> void:
	page_start("窗口分辨率","选择后立即应用并保存。画面按 16:9 等比例缩放。","resolution_settings")
	label(overlay,"当前选择：%d × %d"%[game.window_resolution.x,game.window_resolution.y],Rect2(180,310,1500,65),32)
	for i in range(game.WINDOW_SIZES.size()):
		var resolution: Vector2i=game.WINDOW_SIZES[i]
		var title="%d × %d"%[resolution.x,resolution.y]
		if resolution==Vector2i(1920,1080):title+=" · 默认"
		if resolution==game.window_resolution:title+="  ✓"
		button(overlay,title,Rect2(180+(i%2)*790,425+floori(i/2.0)*120,735,85),func():game.set_window_resolution(resolution);show_resolution_settings(in_run))
	label(overlay,"建议选择不超过显示器尺寸的分辨率。\n若 Godot 内嵌运行窗口限制了尺寸，请关闭嵌入游戏后运行，或双击 Play.cmd。",Rect2(180,715,1530,110),25)
	button(overlay,"← 返回画面设置",Rect2(180,900,600,65),show_visual_settings.bind(in_run))
func page_start(title: String,subtitle: String,key: String) -> void:
	super.page_start(title,subtitle,key)
	for child in overlay.get_children():
		if child is Label:child.text=child.text.replace("第五版 · 绮光铸影","第六版 · 合刃同行")
