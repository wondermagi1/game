extends CanvasLayer
var game
var hud: Control
var modal: Control
var title: Label
var health: ProgressBar
var energy: ProgressBar
var detail: Label
var objective: Label
var prompt: Label
var notice: Label
var skill_labels: Array = []
var map_canvas
var navigation: Label
var boss_panel: Panel
var boss_health: ProgressBar
var boss_name: Label
const GOLD = Color("#edcf97")
const INK = Color("#172e3e")
const TEXT = Color("#edf3f3")
const MUTED = Color("#adc3ce")

func _ready() -> void:
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	hud = Control.new()
	hud.theme = theme
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	modal = Control.new()
	modal.theme = theme
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)
	panel(hud,Rect2(36,30,365,123),Color(.055,.12,.17,.86))
	title = label(hud,"",Rect2(57,44,325,35),23,TEXT)
	health = meter(hud,Rect2(58,92,312,13),Color("#a9d7c6"))
	energy = meter(hud,Rect2(58,113,312,5),GOLD)
	detail = label(hud,"",Rect2(57,127,650,28),16,MUTED)
	panel(hud,Rect2(1450,30,432,174),Color(.055,.12,.17,.8))
	label(hud,"霜语边境",Rect2(1473,42,390,28),18,GOLD)
	objective = label(hud,"",Rect2(1473,80,389,55),21,TEXT)
	navigation = label(hud,"",Rect2(1473,147,385,45),17,GOLD)
	boss_panel = panel(hud,Rect2(602,30,716,92),Color(.055,.12,.17,.83))
	boss_name = label(boss_panel,"霜角守望者",Rect2(22,9,672,32),23,GOLD)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health = meter(boss_panel,Rect2(24,58,668,12),Color("#a9d9df"))
	for i in range(4):
		var x = 456+i*238
		panel(hud,Rect2(x,980,224,69),Color(.055,.12,.17,.9))
		skill_labels.append(label(hud,"",Rect2(x+15,990,197,50),20,TEXT))
	panel(hud,Rect2(427,1052,1070,28),Color(.055,.12,.17,.8))
	label(hud,"WASD 移动  ·  Shift 奔跑  ·  空格 闪避  ·  左键 普攻  ·  G 交互  ·  1 药剂  ·  M 地图",Rect2(444,1055,1040,23),15,TEXT)
	prompt = label(hud,"",Rect2(470,888,980,46),25,GOLD)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice = label(hud,"",Rect2(440,210,1040,50),25,TEXT)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_shadow_color",Color("#102638"))
	notice.add_theme_constant_override("shadow_outline_size",3)

func panel(parent: Control,rect: Rect2,color: Color = INK) -> Panel:
	var node = Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(.62,.73,.77,.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	node.add_theme_stylebox_override("panel",style)
	parent.add_child(node)
	node.set_deferred("size",rect.size)
	return node

func label(parent: Control,text_value: String,rect: Rect2,size_value: int = 22,color: Color = TEXT) -> Label:
	var node = Label.new()
	node.position = rect.position
	node.size = rect.size
	node.text = text_value
	node.add_theme_font_size_override("font_size",size_value)
	node.add_theme_color_override("font_color",color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func meter(parent: Control,rect: Rect2,color: Color) -> ProgressBar:
	var node = ProgressBar.new()
	node.position = rect.position
	node.size = rect.size
	node.show_percentage = false
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var back = fill.duplicate()
	back.bg_color = Color("#385362")
	node.add_theme_stylebox_override("fill",fill)
	node.add_theme_stylebox_override("background",back)
	node.add_theme_font_size_override("font_size",1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.set_deferred("size",rect.size)
	return node

func button(parent: Control,text_value: String,rect: Rect2,callback: Callable) -> Button:
	var node = Button.new()
	node.position = rect.position
	node.size = rect.size
	node.text = text_value
	for state in ["normal","hover","pressed","focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#354f5d") if state!="normal" else Color("#243c4a")
		style.border_color = GOLD if state!="normal" else Color("#58717b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		node.add_theme_stylebox_override(state,style)
	node.add_theme_color_override("font_color",TEXT)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func clear_modal() -> void:
	for child in modal.get_children(): child.queue_free()
	map_canvas = null
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE

func backdrop(rect: Rect2) -> void:
	clear_modal()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.size = Vector2(1920,1080)
	panel(modal,rect,Color(.055,.11,.15,.95))

func show_menu() -> void:
	backdrop(Rect2(1000,145,810,800))
	label(modal,"THREEFOLD TRIAL  /  A NEW JOURNEY",Rect2(1050,189,690,38),17,GOLD)
	label(modal,"三途试炼\n霜语边境",Rect2(1045,243,690,163),60,TEXT)
	label(modal,"循着灯火，走进冬日的奇幻边境。\n寻找三处符文，穿过古桥，唤醒霜角守望者。",Rect2(1052,435,684,78),23,MUTED)
	var hints = ["贯穿飞剑 · 近身环刃","爆破火药 · 持续轰击","远射猎印 · 群星箭雨"]
	for role in range(3):
		var r = role
		button(modal,("✓ " if game.selected_role==role else "")+game.ROLES[role]+"\n"+hints[role],Rect2(1050,545+role*81,700,69),func(): game.create_player(r); game.set_state("menu"); show_menu())
	if not game.checkpoint.is_empty():
		button(modal,"继续旅程 · Lv.%d"%game.checkpoint.level,Rect2(1050,807,330,66),func(): game.continue_run())
		button(modal,"新旅程（替换续玩）",Rect2(1395,807,355,66),func(): game.start_run(game.selected_role))
	else:
		button(modal,"进入雪原",Rect2(1050,807,442,66),func(): game.start_run(game.selected_role))
		button(modal,"退出",Rect2(1514,807,236,66),func(): get_tree().quit())
	label(modal,"3D 雪原 · 实时光影 · 2.5D 动画角色\n营火休整 / 符文 / 领取祝福后自动保存 · F5 安全区域手动保存",Rect2(1050,896,700,45),16,MUTED)

func refresh() -> void:
	hud.visible = game.state=="combat"
	if not hud.visible: return
	title.text = "%s   Lv.%d"%[game.ROLES[game.selected_role],game.level]
	health.value = game.hp/game.max_hp*100
	energy.value = game.stamina
	detail.text = "生命 %d / %d   ·   金币 %d   ·   药剂 %d"%[ceil(game.hp),game.max_hp,game.coins,game.potions]
	objective.text = game.objective()
	navigation.text = game.waypoint_text()
	boss_panel.visible = false
	boss_panel.position.y = 30-124*pow(clampf(game.boss_intro_time/.65,0,1),3)
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.boss and enemy.alive:
			boss_panel.visible = true
			boss_health.value = enemy.hp/enemy.max_hp*100
			boss_name.text = "霜角守望者 · " + ("星霜共鸣" if enemy.hp<enemy.max_hp*.5 else "圣庭的试炼")
			break
	for i in range(4):
		var status = "就绪" if game.cooldowns[i]<=0 else "%.1fs"%game.cooldowns[i]
		skill_labels[i].text = "%s  %s\n%s"%[["E","Q","F","C"][i],game.SKILLS[game.selected_role][i],status]
	var site = game.interaction_site()
	prompt.text = "[G]  "+site.name if not site.is_empty() else ""
	notice.text = game.notice if game.notice_time>0 else ""

func show_pause() -> void:
	backdrop(Rect2(580,180,760,750))
	label(modal,"旅途小憩",Rect2(630,219,660,70),44,TEXT)
	var summary = "当前祝福\n"
	for boon in game.BOONS:
		if game.buffs.has(boon[2]): summary += "· %s ×%d\n"%[boon[0],roundi(game.buffs[boon[2]]/boon[3])]
	if game.buffs.is_empty(): summary += "探索营地与宝箱，获得旅途祝福。"
	label(modal,summary,Rect2(635,310,650,270),24,MUTED)
	var reason: String = game.checkpoint_block_reason()
	label(modal,"战斗外可保存；阵亡会结束本次旅程。" if reason.is_empty() else reason,Rect2(635,584,650,42),19,GOLD)
	button(modal,"继续旅程",Rect2(635,638,650,64),func(): game.set_state("combat"); clear_modal())
	var save_button = button(modal,"保存并返回营地",Rect2(635,718,650,64),func():
		if game.save_checkpoint(): game.set_state("menu"); show_menu())
	save_button.disabled = not reason.is_empty()
	button(modal,"退出游戏（保留最近存档）",Rect2(635,798,650,64),func():
		if game.checkpoint_block_reason().is_empty(): game.save_checkpoint(false)
		get_tree().quit())

func show_reward() -> void:
	backdrop(Rect2(280,245,1360,590))
	label(modal,"旅途的馈赠",Rect2(345,292,1180,80),46,GOLD)
	label(modal,"选择一个祝福，带着新的力量继续探索。",Rect2(348,385,1180,48),25,MUTED)
	for i in range(game.reward_options.size()):
		var boon: Array = game.BOONS[game.reward_options[i]]
		var index = i
		var x = 345+i*412
		panel(modal,Rect2(x,470,383,291),Color("#213d4a"))
		label(modal,boon[0],Rect2(x+23,501,337,58),30,GOLD)
		label(modal,boon[1],Rect2(x+23,583,337,64),23,TEXT)
		button(modal,"接受祝福",Rect2(x+23,679,337,54),func(): game.choose_reward(index))

func show_map() -> void:
	backdrop(Rect2(275,75,1370,930))
	label(modal,"霜语边境 · 探索地图",Rect2(330,106,900,70),39,GOLD)
	label(modal,"点击已发现的地标设置路标；收起地图后，右上方显示方向与距离。",Rect2(332,180,1110,40),22,MUTED)
	map_canvas = preload("res://scripts/frontier/map.gd").new()
	map_canvas.game = game
	map_canvas.position = Vector2(530,245)
	modal.add_child(map_canvas)
	label(modal,"▲ 你的位置   ◎ 路标\n暖金：待探索   青绿：已完成\n\nShift 奔跑 · 滚轮调整视野\nG 交互 · F5 安全区域保存\n营火恢复生命，首次休整补充药剂。\n\n当前目标：\n"+game.objective(),Rect2(1240,325,340,450),21,MUTED)
	button(modal,"收起地图  [M / Esc]",Rect2(1110,877,470,61),func(): game.set_state("combat"); clear_modal())

func show_result(victory: bool) -> void:
	backdrop(Rect2(505,190,910,720))
	label(modal,"雪原记住了你的脚步" if victory else "暖灯会等你归来",Rect2(563,242,800,86),43,GOLD)
	label(modal,"霜角守望者认可了你的勇气。" if victory else "带着探索的经验，再踏上一次旅途吧。",Rect2(567,358,780,50),26,TEXT)
	var summary = "旅途时间    %02d:%02d\n击败魔物    %d\n唤醒符文    %d / 3\n发现地标    %d / %d\n获得金币    %d\n到达等级    Lv.%d"%[int(game.elapsed)/60,int(game.elapsed)%60,game.kills,game.runes,game.discovered.size(),game.sites.size(),game.coins,game.level]
	label(modal,summary,Rect2(570,443,770,277),27,MUTED)
	button(modal,"再次踏上旅途",Rect2(565,769,385,66),func(): game.start_run(game.selected_role))
	button(modal,"返回营地",Rect2(972,769,385,66),func(): game.set_state("menu"); show_menu())
