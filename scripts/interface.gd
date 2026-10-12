extends "res://scripts/ui_v7.gd"

## Presentation-only polish. Keep existing navigation, saves and combat rules.
const SURFACE = Color("#12232d")
const EDGE = Color("#3b5662")
const SOFT_TEXT = Color("#afbfcc")
var skill_status: Array[Label] = []
var skill_keys: Array[Label] = []
var skill_progress: Array[ProgressBar] = []
var low_health: bool = false

func _ready() -> void:
	super._ready()
	var shared = make_theme()
	overlay.theme = shared
	hud.theme = shared
	# Cooldown information stays in the reserved bottom rail, outside the arena.
	for i in range(4):
		var x = 65+i*270
		var panel = box(hud,Rect2(x,983,255,68),SURFACE,EDGE)
		panel.z_index = 1
		skill_labels[i].position = Vector2(x+51,985)
		skill_labels[i].size = Vector2(196,30)
		skill_labels[i].add_theme_font_size_override("font_size",19)
		skill_labels[i].autowrap_mode = TextServer.AUTOWRAP_OFF
		skill_labels[i].clip_text = true
		skill_labels[i].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var key = label(hud,"",Rect2(x+5,995,40,34),20,GOLD)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.z_index = 2
		skill_keys.append(key)
		skill_status.append(label(hud,"",Rect2(x+51,1017,196,27),17,SOFT_TEXT))
		skill_status.back().z_index = 2
		var meter = ProgressBar.new()
		meter.add_theme_font_size_override("font_size",1)
		meter.position = Vector2(x+8,1049)
		meter.size = Vector2(239,4)
		meter.show_percentage = false
		meter.z_index = 2
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.add_theme_stylebox_override("background",meter_style(Color("#263744")))
		meter.add_theme_stylebox_override("fill",meter_style(Color("#80cdbc")))
		hud.add_child(meter)
		meter.set_deferred("size",Vector2(239,4))
		skill_progress.append(meter)
	health.add_theme_stylebox_override("fill",meter_style(Color("#80cdbc")))
	health.add_theme_stylebox_override("background",meter_style(Color("#283c48")))
	xp_bar.add_theme_stylebox_override("fill",meter_style(GOLD))
	xp_bar.add_theme_stylebox_override("background",meter_style(Color("#283c48")))
	for meter in [health,xp_bar,boss_bar]: meter.add_theme_font_size_override("font_size",1)
	health.set_deferred("size",Vector2(475,15))
	xp_bar.set_deferred("size",Vector2(475,7))
	boss_bar.set_deferred("size",Vector2(600,10))
	detail_label.add_theme_color_override("font_color",SOFT_TEXT)
	combo_hint.position = Vector2(480,921)
	combo_hint.size = Vector2(960,42)
	combo_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_hint.add_theme_color_override("font_shadow_color",Color("#09121d"))
	combo_hint.add_theme_constant_override("shadow_outline_size",5)

func meter_style(color: Color) -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(3)
	return result

func make_theme() -> Theme:
	var result = Theme.new()
	result.default_font = font
	result.default_font_size = 21
	for type_name in ["Button","OptionButton","LineEdit"]:
		result.set_stylebox("normal",type_name,style(SURFACE,EDGE))
		result.set_stylebox("hover",type_name,style(Color("#28434d"),GOLD))
		result.set_stylebox("pressed",type_name,style(Color("#354e55"),GOLD))
		result.set_stylebox("focus",type_name,focus_style(GOLD))
		result.set_stylebox("disabled",type_name,style(Color("#17212a"),Color("#364450")))
		result.set_color("font_color",type_name,WHITE)
		result.set_color("font_disabled_color",type_name,Color("#8d9ca8"))
	result.set_color("font_placeholder_color","LineEdit",SOFT_TEXT)
	result.set_color("selection_color","LineEdit",Color("#3b6267"))
	result.set_stylebox("panel","PopupMenu",style(Color("#101f29"),EDGE))
	result.set_stylebox("hover","PopupMenu",style(Color("#2b4852"),GOLD))
	result.set_constant("v_separation","PopupMenu",18)
	result.set_stylebox("panel","TooltipPanel",style(Color("#0e1b25"),GOLD))
	result.set_font_size("font_size","TooltipLabel",21)
	var slider_track = meter_style(Color("#2b404b"))
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	result.set_stylebox("slider","HSlider",slider_track)
	result.set_stylebox("grabber_area","HSlider",meter_style(Color("#78b5ac")))
	result.set_stylebox("grabber_area_highlight","HSlider",meter_style(GOLD))
	for type_name in ["VScrollBar","HScrollBar"]:
		var track = meter_style(Color("#172b36"))
		track.content_margin_left = 6
		track.content_margin_right = 6
		result.set_stylebox("scroll",type_name,track)
		result.set_stylebox("grabber",type_name,meter_style(Color("#597f86")))
		result.set_stylebox("grabber_highlight",type_name,meter_style(GOLD))
		result.set_stylebox("grabber_pressed",type_name,meter_style(GOLD))
	return result

func focus_style(accent: Color) -> StyleBoxFlat:
	var result = style(Color.TRANSPARENT,accent,7)
	result.set_border_width_all(2)
	result.shadow_size = 0
	return result

func button(parent: Node, text_value: String, rect: Rect2, callback: Callable, accent: Color = GOLD) -> Button:
	var result = super.button(parent,text_value,rect,callback,accent)
	var font_size = 23 if rect.size.y>=60 else (20 if rect.size.y>=44 else 17)
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_stylebox_override("focus",focus_style(accent))
	result.add_theme_color_override("font_disabled_color",Color("#95a2ae"))
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	result.clip_text = true
	result.tooltip_text = text_value
	return result

func label(parent: Node, text_value: String, rect: Rect2, font_size: int = 26, color: Color = WHITE) -> Label:
	return super.label(parent,text_value,rect,font_size,SOFT_TEXT if color==MUTED else color)

func heading(_kicker: String, title: String, subtitle: String) -> void:
	label(overlay,"三途试炼  /  行者营地",Rect2(130,70,1250,36),19,GOLD)
	label(overlay,title,Rect2(126,120,1650,88),56)
	label(overlay,subtitle,Rect2(130,215,1630,65),23,SOFT_TEXT)
	box(overlay,Rect2(130,202,74,3),GOLD)

func show_menu() -> void:
	page = "menu"
	game.state = "menu"
	clear_overlay()
	hud.hide()
	shade()
	label(overlay,"THREEFOLD TRIAL  /  "+str(ProjectSettings.get_setting("application/config/version")),Rect2(80,33,950,36),19,GOLD)
	label(overlay,"三途试炼",Rect2(75,99,870,102),76)
	label(overlay,"三条道路，一场未竟的远征",Rect2(81,212,950,46),25,SOFT_TEXT)
	box(overlay,Rect2(1100,38,730,63),Color(.04,.09,.12,.94),EDGE)
	label(overlay,"金币  %d     材料  %d     章节  %d / 6"%[game.profile.data.gold,game.profile.data.material,game.profile.data.unlocked],Rect2(1125,48,680,43),21,GOLD)
	box(overlay,Rect2(1100,124,730,124),Color(.04,.09,.12,.94),EDGE)
	label(overlay,V7.CAMP_NPC+" · 营地来信",Rect2(1125,137,670,30),18,GOLD)
	label(overlay,camp_story_line(),Rect2(1125,177,670,55),20,SOFT_TEXT)
	for config in Look.ROLES:
		var id: int = config.id
		var x = 80+id*445
		var col: Color = config.color
		var card = box(overlay,Rect2(x,300,415,632),Color(.035,.075,.10,.95),Color(col,.5))
		box(card,Rect2(24,0,367,3),col)
		label(card,"0%d  /  行者"%(id+1),Rect2(26,22,363,30),17,SOFT_TEXT)
		label(card,config.word,Rect2(26,61,363,65),46,col)
		var actor = Visual.new()
		actor.kind = id
		actor.tint = col
		actor.position = Vector2(208,375)
		actor.scale = Vector2.ONE*2.55
		actor.aim = Vector2(.95,.15)
		actor.quality = 3 if game.profile.set_count(id)>=6 else 1
		card.add_child(actor)
		label(card,config.name+"  /  Lv.%d"%game.profile.data.roles[id].level,Rect2(26,401,363,42),29)
		label(card,config.tag,Rect2(26,449,363,36),20,SOFT_TEXT)
		var unlocked = 0
		for required in C.SKILL_LEVELS:
			if game.profile.data.roles[id].level>=required: unlocked += 1
		label(card,"套装 %d / 6     技能 %d / 4"%[game.profile.set_count(id),unlocked],Rect2(26,495,363,32),18,GOLD)
		var action = button(card,"选择"+config.name+"  →",Rect2(26,550,363,58),menu_choose.bind(id),col)
		action.set_meta("role_id",id)
		action.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel",style(Color("#18333d"),col)))
		action.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel",style(Color(.035,.075,.10,.95),Color(col,.5))))
	box(overlay,Rect2(1450,300,380,632),Color(.035,.075,.10,.95),EDGE)
	label(overlay,"远征准备",Rect2(1474,320,330,43),26,GOLD)
	var actions = [["角色属性",show_characters],["装备与铸造",show_equipment],["技能与天赋",show_talents],["万象图鉴",show_codex],["成就纪事",show_achievements],["游戏设置",func(): show_settings(false)]]
	for i in range(actions.size()):
		button(overlay,actions[i][0],Rect2(1474,386+i*73,332,56),actions[i][1])
	if not game.profile.data.exploration.is_empty():
		button(overlay,"继续探索",Rect2(1474,850,202,57),func(): game.rooms.resume(),Color("#8ee4ce"))
		button(overlay,"放弃…",Rect2(1686,850,120,57),confirm_exploration_abandon)
	elif not game.profile.data.checkpoint.is_empty():
		button(overlay,"继续深渊",Rect2(1474,850,202,57),func(): game.abyss.resume(),Color("#8ee4ce"))
		button(overlay,"放弃…",Rect2(1686,850,120,57),confirm_abandon)
	else:
		label(overlay,"选择行者，开启下一段旅程",Rect2(1474,845,332,57),19,SOFT_TEXT)
	label(overlay,"成长永久保留 · 局内构筑随远征重启",Rect2(80,981,760,52),20,SOFT_TEXT)
	button(overlay,"持械动作检视",Rect2(990,980,275,55),show_action_inspector,Color("#9edccc"))
	button(overlay,"奇遇 · 噜噜温泉",Rect2(1285,980,330,55),show_lulu_select,Color("#9edccc"))
	button(overlay,"退出游戏",Rect2(1635,980,195,55),func(): game.profile.save_profile(); get_tree().quit())

func render_inventory() -> void:
	super.render_inventory()
	mark_selected_item()

func select_item(uid: String) -> void:
	super.select_item(uid)
	mark_selected_item()

func mark_selected_item() -> void:
	if not is_instance_valid(inventory_rows): return
	for item_row in inventory_rows.get_children():
		var chosen = item_row.get_meta("item_uid","")==selected_uid and not selected_uid.is_empty()
		var panel = item_row.get_child(0) as Panel
		if panel!=null: panel.add_theme_stylebox_override("panel",style(Color("#213e47") if chosen else INK,GOLD if chosen else EDGE))
		for child in item_row.get_children():
			if child is Button:
				child.text = "已选中" if chosen else "查看"

func show_equipment() -> void:
	super.show_equipment()
	button(overlay,"重置筛选",Rect2(130,916,195,36),func(): inventory_filter.assign([-1,-1,-1]); inventory_sort=0; show_equipment())
	label(overlay,"点击查看对比 · 金色边框为当前选中",Rect2(345,916,700,36),18,SOFT_TEXT)

func show_settings(in_run: bool) -> void:
	super.show_settings(in_run)
	for rect in [Rect2(130,335,825,420),Rect2(1020,335,735,370)]:
		var panel = box(overlay,rect,Color(.05,.10,.14,.94),EDGE)
		overlay.move_child(panel,2)
	# Preserve the existing sliders and callbacks; show their exact current values.
	for child in overlay.get_children():
		if not child is HSlider: continue
		var readout_pos: Vector2
		if child.position.x<1000: readout_pos = Vector2(790,590)
		elif child.position.y<550: readout_pos = Vector2(1560,375)
		else: readout_pos = Vector2(1600,550)
		var value_label = label(overlay,"%d%%"%roundi(child.value*100),Rect2(readout_pos,Vector2(115,45)),23,GOLD)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		child.value_changed.connect(func(value): value_label.text="%d%%"%roundi(value*100))

func render_item_detail() -> void:
	super.render_item_detail()
	var item: Dictionary = game.profile.item_by_id(selected_uid)
	if item.is_empty(): return
	for child in inventory_detail.get_children():
		if child is Button:
			if child.text=="装备" and game.profile.is_equipped(item.uid):
				child.text = "已穿戴"
				child.disabled = true
			if child.text=="强化": child.tooltip_text = enhance_reason(item)
			elif child.disabled: child.tooltip_text = "已穿戴" if child.text=="已穿戴" else "当前无法操作：请检查营地状态、所属角色、等级或装备锁定。"

func _process(delta: float) -> void:
	super._process(delta)
	if game.state!="combat" or not is_instance_valid(game.player): return
	var p = game.player
	for i in range(skill_status.size()):
		var available: bool = p.skills.unlocked(i)
		var cd: float = p.skills.cooldowns[i]
		skill_labels[i].text = C.SKILLS[p.stats.role][i].name+"  Lv.%d"%p.skills.rank(i)
		skill_labels[i].tooltip_text = skill_labels[i].text
		skill_keys[i].text = game.bindings.text(["skill","skill_2","skill_3","skill_4"][i])
		skill_status[i].text = ("就绪" if cd<=0 else "冷却  %.1f 秒"%cd) if available else "Lv.%d 解锁"%C.SKILL_LEVELS[i]
		skill_status[i].modulate = Color("#8ee4ce") if available and cd<=0 else Color.WHITE
		skill_progress[i].value = 100*(1-clampf(cd/maxf(.1,C.SKILLS[p.stats.role][i].cd),0,1)) if available else 0
		hud_masks[i].hide()
	var danger: bool = p.hp/maxf(1,p.stats.value("hp"))<.25
	if danger!=low_health:
		low_health = danger
		health.add_theme_stylebox_override("fill",meter_style(Color("#ed8e88") if danger else Color("#80cdbc")))
	for i in range(item_buttons.size()):
		var id: String = game.profile.data.quick[i]
		item_buttons[i].disabled = game.profile.data.consumables.get(id,0)<=0 or p.item_clocks.get(id,0)>0
	# Notices and combo guidance share a rail but never cover one another.
	combo_hint.visible = game.notice_clock<=0
