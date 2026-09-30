extends "res://scripts/ui_base.gd"
const C = preload("res://scripts/catalog.gd")
var view_role: int = 0
var selected_uid: String = ""
var inventory_rows: VBoxContainer
var inventory_detail: Control
var inventory_filter: Array[int] = [-1,-1,-1]
var inventory_sort: int = 0
var codex_rows: VBoxContainer
var codex_category: int = 0
var codex_query: String = ""
var codex_role: int = -1
var codex_quality: int = -1
var codex_found: int = 0
var skill_labels: Array[Label] = []
var item_buttons: Array[Button] = []
var buff_bar: HBoxContainer
var buff_signature: String = ""
var xp_bar: ProgressBar
var toast: Label
var page: String = "menu"

func _ready() -> void:
	super._ready()
	toast = label(self,"",Rect2(390,921,1140,42),22,GOLD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func can_fire() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered==null or hovered.mouse_filter==Control.MOUSE_FILTER_IGNORE

func page_start(title: String, subtitle: String, key: String) -> void:
	page = key
	clear_overlay()
	shade()
	heading("THREEFOLD TRIAL / 第三版",title,subtitle)
	button(overlay,"← 返回",Rect2(1510,85,260,62),management_back)

func management_back() -> void:
	if game.state=="intermission": show_intermission()
	elif game.state=="paused": show_pause()
	else:
		game.state = "menu"
		show_menu()

func commit(message: String = "") -> void:
	game.refresh_stats()
	var saved: bool = game.profile.save_profile()
	if not saved: game.notify_player(game.profile.notice,6)
	elif not message.is_empty(): game.notify_player(message)

func show_menu() -> void:
	page = "menu"
	game.state = "menu"
	clear_overlay()
	hud.hide()
	shade()
	label(overlay,"THREEFOLD TRIAL / ABYSS ECHOES",Rect2(125,70,1100,45),22,GOLD)
	label(overlay,"三途试炼",Rect2(115,140,950,125),91)
	label(overlay,"拾遗成器 · 百炼成途",Rect2(125,280,960,55),31,WHITE)
	label(overlay,"六重章节，三条成长之路。\n从每波抉择中构筑力量，让战利品成为下一次远征的起点。",Rect2(125,363,940,100),26,MUTED)
	label(overlay,"金币 %d    强化材料 %d    已解锁 %d / 6 章"%[game.profile.data.gold,game.profile.data.material,game.profile.data.unlocked],Rect2(125,489,1000,42),25,GOLD)
	button(overlay,"开始挑战  →",Rect2(125,564,800,80),show_select,Color("#77d5c0"))
	var actions = [["角色与属性",show_characters],["装备与强化",show_equipment],["技能与天赋",show_talents],["图鉴",show_codex],["成就",show_achievements],["设置",func(): show_settings(false)]]
	for i in range(actions.size()):
		button(overlay,actions[i][0],Rect2(125+(i%2)*415,674+floori(i/2.0)*86,385,65),actions[i][1])
	button(overlay,"退出游戏",Rect2(125,947,250,58),func(): game.profile.save_profile(); game.get_tree().quit())
	label(overlay,"WASD 移动 · 左键攻击 · Space 闪避 · E Q F C 技能",Rect2(420,954,1390,45),21,MUTED)
	box(overlay,Rect2(1030,150,755,700),Color("#112333"),Color("#385568"))
	portrait(overlay,0,Vector2(1190,595),3.3)
	portrait(overlay,1,Vector2(1420,650),3.2)
	portrait(overlay,2,Vector2(1620,580),3.3)
	label(overlay,"御剑       火药       长弓",Rect2(1110,760,670,50),31,GOLD)
	label(overlay,"等级与装备永久保留 · 随机强化属于本次挑战",Rect2(1020,870,770,60),22,MUTED)
	if not game.profile.notice.is_empty(): label(overlay,game.profile.notice,Rect2(1040,935,760,90),20,GOLD)

func show_select() -> void:
	game.state = "select"
	page_start("选择你的行者","角色等级、装备与天赋分别保存。所有角色均已解锁。","select")
	for i in range(3):
		var role: Dictionary = Data.ROLES[i]
		var r: Dictionary = game.profile.data.roles[i]
		var x = 130+i*565
		box(overlay,Rect2(x,305,530,630),Color("#122031"),Color(role.color,0.4))
		label(overlay,"%s / Lv.%d"%[role.name,r.level],Rect2(x+30,328,470,45),30,role.color)
		portrait(overlay,i,Vector2(x+265,638),2.6)
		label(overlay,role.title,Rect2(x+30,716,470,47),29)
		label(overlay,role.tag,Rect2(x+30,770,470,38),22,role.color)
		button(overlay,"选择%s →"%role.name,Rect2(x+30,843,470,64),choose_role.bind(i),role.color)

func choose_role(role: int) -> void:
	view_role = role
	game.selected_role = role
	show_chapters()

func show_chapters() -> void:
	page_start("选择章节","每章可独立挑战。失败保留已获得的金币、经验和装备；本局 Buff 清空。","chapters")
	for i in range(4):
		var c: Dictionary = C.CHAPTERS[i]
		var x = 130+(i%2)*850
		var y = 335+floori(i/2.0)*285
		var open: bool = i<int(game.profile.data.unlocked)
		box(overlay,Rect2(x,y,800,250),INK,Color(c.color,0.4))
		label(overlay,"%02d %s"%[i+1,c.name],Rect2(x+25,y+15,745,48),34,Color(c.color))
		label(overlay,"%d 回合 · 推荐 Lv.%d · 约 %s · 每回合最多 3 波"%[c.waves.size(),c.level,C.PACING[i].target],Rect2(x+25,y+70,745,40),21,MUTED)
		label(overlay,c.hint,Rect2(x+25,y+112,745,55),21)
		var b = button(overlay,"进入挑战" if open else "通关前一章后解锁",Rect2(x+25,y+184,745,48),start_chapter.bind(i+1),Color(c.color))
		b.tooltip_text = "参考构筑："+C.DIFFICULTY[i].build+"\n难度按章节固定，不随玩家装备实时提高。"
		b.disabled = not open

func start_chapter(chapter: int) -> void:
	game.start_run(view_role,-1,chapter)

func build_hud() -> void:
	box(hud,Rect2(45,20,1830,105),INK,Color("#2e435c"))
	health_label = label(hud,"",Rect2(70,27,510,33),22)
	health = ProgressBar.new()
	health.position = Vector2(70,68)
	health.size = Vector2(475,15)
	health.show_percentage = false
	hud.add_child(health)
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(70,95)
	xp_bar.size = Vector2(475,7)
	xp_bar.show_percentage = false
	hud.add_child(xp_bar)
	stage_label = label(hud,"",Rect2(605,26,950,40),28,GOLD)
	detail_label = label(hud,"",Rect2(605,77,1015,28),18,MUTED)
	button(hud,"属性 / 暂停",Rect2(1640,41,205,57),func(): game.pause_game(true))
	box(hud,Rect2(45,976,1830,84),INK,Color("#2e435c"))
	for i in range(4):
		var l = label(hud,"",Rect2(65+i*270,982,255,66),21)
		skill_labels.append(l)
	for i in range(3):
		var b = button(hud,"",Rect2(1170+i*225,990,210,56),use_item.bind(i))
		b.add_theme_font_size_override("font_size",20)
		item_buttons.append(b)
	buff_bar = HBoxContainer.new()
	buff_bar.position = Vector2(65,133)
	buff_bar.size = Vector2(1500,36)
	buff_bar.add_theme_constant_override("separation",8)
	hud.add_child(buff_bar)
	banner_label = label(hud,"",Rect2(470,175,1000,62),34,GOLD)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label = label(hud,"",Rect2(660,245,600,36),24,Color("#f6a0ae"))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(660,290)
	boss_bar.size = Vector2(600,10)
	boss_bar.show_percentage = false
	hud.add_child(boss_bar)

func use_item(slot: int) -> void:
	if is_instance_valid(game.player):
		game.player.attack_input_armed = false
		game.player.use_item(slot)

func _process(_delta: float) -> void:
	if toast!=null: toast.text = game.notice_text if game.notice_clock>0 else ""
	hud.visible = game.state=="combat"
	if not is_instance_valid(game.player): return
	var p = game.player
	var progress: Dictionary = game.profile.data.roles[p.stats.role]
	health.max_value = p.stats.value("hp")
	health.value = p.hp
	health_label.text = "%s Lv.%d · HP %d / %d%s"%[p.stats.base.name,progress.level,ceili(p.hp),ceili(p.stats.value("hp"))," 盾 %d"%p.barrier if p.barrier>0 else ""]
	xp_bar.max_value = C.xp_needed(int(progress.level))
	xp_bar.value = xp_bar.max_value if int(progress.level)==C.MAX_LEVEL else progress.xp
	stage_label.text = "%s · 回合 %d/%d"%[game.flow.title(),game.flow.round_number,game.flow.rounds()]
	detail_label.text = "波次 %d/%d  敌人 %d  金币 %d  %02d:%02d%s"%[game.wave,game.max_waves(),game.enemies.size()+game.pending.size(),game.profile.data.gold,floori(game.elapsed/60.0),int(game.elapsed)%60,"  弹药 %d/%d · 强化弹 %d"%[p.ammo,p.magazine_size(),p.skills.empowered_shots+(1 if p.first_round and p.skills.empowered_shots==0 else 0)] if p.stats.role==1 else ""]
	if game.wave>0:
		detail_label.text += "  · 增援 %ds"%game.director.remaining() if game.director.receiving() else ("  · 首领战" if game.flow.boss_kind()>=0 else "  · 肃清残敌")
	for i in range(4):
		var available = p.skills.unlocked(i)
		var cd: float = p.skills.cooldowns[i]
		skill_labels[i].text = "%s %s\n%s"%[game.bindings.text(["skill","skill_2","skill_3","skill_4"][i]),C.SKILLS[p.stats.role][i].name+" Lv.%d"%p.skills.rank(i),("就绪" if cd<=0 else "冷却 %.1fs"%cd) if available else "Lv.%d 解锁"%C.SKILL_LEVELS[i]]
		skill_labels[i].modulate = Color.WHITE if available else Color("#65758b")
	for i in range(3):
		var id: String = game.profile.data.quick[i]
		var item = item_definition(id)
		var cd: float = p.item_clocks.get(id,0)
		item_buttons[i].text = "%s %s ×%d%s"%[game.bindings.text("item_%d"%(i+1)),item.name,game.profile.data.consumables.get(id,0)," %.0fs"%cd if cd>0 else ""]
		item_buttons[i].tooltip_text = item.text
	banner_label.text = game.banner if game.banner_time>0 else ""
	boss_bar.hide()
	boss_label.hide()
	for e in game.enemies:
		if e.is_boss():
			boss_bar.show()
			boss_label.show()
			boss_bar.max_value = e.max_hp
			boss_bar.value = e.hp
			boss_label.text = C.ENEMIES[e.kind]+(" · 二阶段" if e.second_phase else "")
			break
	var signature = str(p.stats.stacks)
	if signature!=buff_signature:
		buff_signature = signature
		for child in buff_bar.get_children(): buff_bar.remove_child(child); child.queue_free()
		var count = 0
		for u in Data.UPGRADES:
			if not p.stats.stacks.has(u[0]): continue
			count += 1
			if count>11: continue
			var b = Button.new()
			b.text = "%s ×%d"%[u[1],p.stats.stacks[u[0]]]
			b.tooltip_text = u[2]+"\n本局有效 · Tab 查看完整构筑"
			b.add_theme_font_override("font",font)
			b.add_theme_font_size_override("font_size",16)
			b.pressed.connect(func(): game.pause_game(true))
			buff_bar.add_child(b)

func show_rewards(choices: Array) -> void:
	page_start("选择本波的馈赠","三选一 · 强化保留至本次章节挑战结束。回合末提高稀有强化权重。","reward")
	hide_back()
	for i in range(choices.size()):
		var u: Array = choices[i]
		var c = Color(C.COLORS[int(u[6])])
		var x = 130+i*565
		box(overlay,Rect2(x,340,530,540),INK,Color(c,0.5))
		icon(overlay,Rect2(x+34,370,58,58),buff_icon(u[3]),c)
		label(overlay,["普通","稀有","史诗"][int(u[6])],Rect2(x+115,378,345,36),23,c)
		label(overlay,u[1],Rect2(x+35,462,460,65),40)
		label(overlay,u[2],Rect2(x+35,557,455,110),27,MUTED)
		label(overlay,("已获得 %d 层 · 深渊无限叠加 · 5/10/20/40 进阶"%game.player.stats.stacks.get(u[0],0) if game.flow.abyss else "已获得 %d / %d 层 · 本局有效"%[game.player.stats.stacks.get(u[0],0),u[5]]),Rect2(x+35,710,460,40),22,c)
		button(overlay,"选择强化 →",Rect2(x+35,790,460,62),game.choose_reward.bind(i),c)
	label(overlay,"%s · 第 %d 回合 · 第 %d 波已清除"%[game.flow.title(),game.flow.round_number,game.wave],Rect2(130,945,1550,45),26,GOLD)

func hide_back() -> void:
	for child in overlay.get_children():
		if child is Button and child.text=="← 返回": child.hide()

func list_area(rect: Rect2, parent: Node = null) -> VBoxContainer:
	if parent==null: parent = overlay
	var scroll = ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",12)
	scroll.add_child(rows)
	return rows

func row(parent: VBoxContainer, height: float, width: float = 1500) -> Control:
	var r = Control.new()
	r.custom_minimum_size = Vector2(width,height)
	parent.add_child(r)
	box(r,Rect2(0,0,width,height),INK,Color("#293c52"))
	return r

func option(parent: Node, values: Array, rect: Rect2, selected: int, callback: Callable) -> OptionButton:
	var o = OptionButton.new()
	o.position = rect.position
	o.size = rect.size
	o.add_theme_font_override("font",font)
	o.add_theme_font_size_override("font_size",21)
	for value in values: o.add_item(str(value))
	o.select(selected)
	o.item_selected.connect(callback)
	parent.add_child(o)
	return o

func role_tabs() -> void:
	for i in range(3): button(overlay,("● " if view_role==i else "")+Data.ROLES[i].name,Rect2(130+i*230,294,210,52),switch_role.bind(i),Data.ROLES[i].color)

func switch_role(role: int) -> void:
	view_role = role
	if page=="equipment": show_equipment()
	elif page=="talents": show_talents()
	else: show_characters()

func editable() -> bool:
	return game.state in ["menu","select","intermission"] and (game.state!="intermission" or view_role==game.selected_role)

func preview_stats(role: int):
	if is_instance_valid(game.player) and role==game.selected_role and game.state in ["paused","intermission"]: return game.player.stats
	var stats = game.Stats.new(role)
	stats.permanent = game.profile.permanent_bonuses(role)
	return stats

func show_characters() -> void:
	page_start("角色与属性","基础 + 等级 / 装备 / 天赋 + 本局强化。条件增益另列，不混入常驻数值。","characters")
	role_tabs()
	var stats = preview_stats(view_role)
	var progress: Dictionary = game.profile.data.roles[view_role]
	var rows = list_area(Rect2(130,370,1660,550))
	var r = row(rows,160,1610)
	label(r,"%s Lv.%d · 经验 %d / %d · 可用天赋点 %d"%[Data.ROLES[view_role].name,progress.level,progress.xp,C.xp_needed(int(progress.level)),game.profile.talent_points(view_role)],Rect2(25,10,1560,44),28,GOLD)
	label(r,"生命 %.0f   防御 %.0f   攻击 %.1f   攻速 %.2f 次/秒\n移速 %.0f   射程 %.0f   暴击 %.1f%%   暴击伤害 %.0f%%   技能冷却缩减 %.0f%%"%[stats.value("hp"),stats.value("armor"),stats.value("attack"),stats.value("rate"),stats.value("speed"),stats.value("range"),stats.value("crit")*100,stats.value("crit_damage")*100,minf(0.8,stats.bonus("cooldown"))*100],Rect2(25,63,1560,85),24)
	r = row(rows,125,1610)
	label(r,"攻击计算：(基础 %.1f + 永久固定 %.1f + 本局固定 %.1f) × (1 + 永久 %.1f%% + 本局 %.1f%%)"%[stats.base.attack,stats.permanent.get("attack",0),stats.bonuses.get("attack",0),stats.permanent.get("attack_pct",0)*100,stats.bonuses.get("attack_pct",0)*100],Rect2(25,10,1560,60),23)
	label(r,"角色被动："+Data.ROLES[view_role].passive,Rect2(25,74,1560,35),23,GOLD)
	var found = false
	for u in Data.UPGRADES:
		if not stats.stacks.has(u[0]): continue
		found = true
		r = row(rows,105,1610)
		icon(r,Rect2(20,22,48,48),buff_icon(u[3]),Color(C.COLORS[int(u[6])]))
		label(r,"%s ×%d / %s · 来源：清房/深渊奖励 · 本局有效"%[u[1],stats.stacks[u[0]],"∞" if stats.abyss else str(u[5])],Rect2(85,10,1490,35),25,GOLD)
		var total = float(u[4])*int(stats.stacks[u[0]])
		var summary = " · 累计："+C.stat_text(u[3],total) if C.STAT_NAMES.has(u[3]) else ""
		label(r,u[2]+summary,Rect2(85,50,1490,44),22)
	if not found:
		r = row(rows,75,1610)
		label(r,"尚未获得本局 Buff。主线清房或深渊清层后进行三选一。",Rect2(25,10,1560,55),25,MUTED)

	for line in C.set_text(view_role):
		r = row(rows,75,1610)
		var pieces = game.profile.set_count(view_role)
		var required = int(line.left(1))
		label(r,"%s [%d/6] %s"%["已激活" if pieces>=required else "未激活",pieces,line],Rect2(25,10,1560,55),23,WHITE if pieces>=required else MUTED)

func show_pause(_stats_view: bool = false) -> void:
	page_start("试炼暂停","退出挑战保留已获得收益；本局 Buff 与战斗进度结束。","paused")
	view_role = game.selected_role
	label(overlay,build_names(),Rect2(145,320,1630,150),26,GOLD)
	button(overlay,"角色属性与 Buff",Rect2(150,510,740,75),show_characters)
	button(overlay,"查看装备",Rect2(1020,510,740,75),show_equipment)
	button(overlay,"继续挑战",Rect2(150,630,740,75),game.resume_game,Color("#77d5c0"))
	button(overlay,"设置",Rect2(1020,630,740,75),func(): show_settings(true))
	button(overlay,"结束挑战并返回",Rect2(150,760,1610,75),game.back_to_menu)
	hide_back()

func build_names() -> String:
	if not is_instance_valid(game.player): return ""
	var names = PackedStringArray()
	for u in Data.UPGRADES:
		if game.player.stats.stacks.has(u[0]): names.append("%s ×%d"%[u[1],game.player.stats.stacks[u[0]]])
	return "尚未获得本局强化" if names.is_empty() else " · ".join(names)

func show_intermission() -> void:
	view_role = game.selected_role
	page_start("回合整备","调整装备与天赋，购买补给。开始下一回合时恢复部分生命与技能。","intermission")
	hide_back()
	label(overlay,"%s · 第 %d 回合已完成\n金币 %d · 材料 %d · Lv.%d · 可用天赋 %d"%[game.flow.title(),game.flow.round_number,game.profile.data.gold,game.profile.data.material,game.profile.data.roles[view_role].level,game.profile.talent_points(view_role)],Rect2(150,320,1600,110),33,GOLD)
	var actions = [["装备与强化",show_equipment],["技能与天赋",show_talents],["整备商店",show_shop],["消耗品快捷栏",show_consumables],["属性与 Buff",show_characters],["图鉴",show_codex]]
	for i in range(actions.size()): button(overlay,actions[i][0],Rect2(150+(i%3)*550,485+floori(i/3.0)*110,505,78),actions[i][1])
	if game.flow.can_secret(): button(overlay,"进入镜渊裂隙（可选）",Rect2(150,755,780,70),game.enter_secret,Color("#c39ef1"))
	else: label(overlay,"整备后恢复 %.0f%% 最大生命。"%(game.stage_recovery_ratio*100),Rect2(150,755,780,70),26,MUTED)
	button(overlay,"开始下一回合 →",Rect2(980,755,775,70),game.next_round,Color("#77d5c0"))
	button(overlay,"结束挑战并保留收益",Rect2(150,870,1605,60),game.back_to_menu)

func show_end(victory: bool) -> void:
	page_start("章节通关" if victory else "此行暂止","本次获得的金币、经验与装备已保留。本局随机 Buff 在下一次挑战时清空。","end")
	hud.hide()
	box(overlay,Rect2(130,330,1660,360),INK,Color("#405064"))
	label(overlay,"%s · %s · 到达第 %d 回合\n击破 %d   造成伤害 %.0f   承受伤害 %.0f\n用时 %02d:%02d   本次金币 +%d   经验 +%d   装备 +%d"%[Data.ROLES[game.selected_role].name,game.flow.title(),game.flow.round_number,game.kills,game.dealt,game.taken,floori(game.elapsed/60.0),int(game.elapsed)%60,game.earned_gold,game.earned_xp,game.earned_gear],Rect2(175,365,1550,260),32)
	label(overlay,build_names(),Rect2(150,725,1600,105),23,GOLD)
	button(overlay,"再次挑战本章",Rect2(130,870,770,80),func(): game.start_run(game.selected_role,-1,game.stage))
	button(overlay,"返回营地整理装备",Rect2(1015,870,775,80),game.back_to_menu)

func icon(parent: Node, rect: Rect2, index: int, color: Color) -> void:
	box(parent,rect,Color(color,0.10),Color(color,0.6))
	var image = TextureRect.new()
	image.texture = load("res://art/icons/%d.svg"%posmod(index,19))
	image.position = rect.position+Vector2(7,7)
	image.size = rect.size-Vector2(14,14)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func buff_icon(key: String) -> int:
	if key in ["hp","heal","healing","kill_heal","stage_heal"]: return 13
	if key in ["armor","shield","revive"]: return 14
	if key in ["speed_pct","dash_cooldown","kill_speed"]: return 15
	if key in ["cooldown","reload"]: return 16
	if key in ["crit","crit_damage"]: return 18
	if key in ["burn","blast"]: return 10
	if key in ["range_pct","pierce","bounce"]: return 9
	return 0

func item_definition(id: String) -> Dictionary:
	for item in C.ITEMS:
		if item.id==id: return item
	return C.ITEMS[0]

func show_equipment() -> void:
	page_start("装备与强化","六部位 · 四品质 · 强化上限 +10。仅营地或回合整备允许换装；战斗暂停时只读。","equipment")
	role_tabs()
	label(overlay,"金币 %d · 材料 %d · 背包 %d / %d"%[game.profile.data.gold,game.profile.data.material,game.profile.data.inventory.size(),C.CAPACITY],Rect2(865,295,920,48),23,GOLD)
	option(overlay,["所有角色","剑修","火枪手","游侠"],Rect2(130,365,215,48),inventory_filter[0]+1,inventory_change.bind(0))
	option(overlay,["所有部位"]+C.SLOTS,Rect2(355,365,210,48),inventory_filter[1]+1,inventory_change.bind(1))
	option(overlay,["所有品质"]+C.QUALITIES,Rect2(575,365,210,48),inventory_filter[2]+1,inventory_change.bind(2))
	option(overlay,["最新获得","品质优先","等级优先"],Rect2(795,365,240,48),inventory_sort,sort_inventory)
	inventory_rows = list_area(Rect2(130,435,915,465))
	inventory_detail = Control.new()
	inventory_detail.position = Vector2(1080,365)
	inventory_detail.size = Vector2(710,540)
	overlay.add_child(inventory_detail)
	render_inventory()
	button(overlay,"领取暂存装备 (%d)"%game.profile.data.overflow.size(),Rect2(130,964,510,62),claim_stash)
	button(overlay,"查看六部位穿戴",Rect2(690,964,510,62),show_loadout)
	button(overlay,"配置道具快捷栏",Rect2(1250,964,540,62),show_consumables)

func clear_children(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child); child.queue_free()

func inventory_change(value: int, index: int) -> void:
	inventory_filter[index] = value-1
	render_inventory()

func sort_inventory(value: int) -> void:
	inventory_sort = value
	render_inventory()

func render_inventory() -> void:
	clear_children(inventory_rows)
	var items: Array = game.profile.data.inventory.duplicate()
	items.sort_custom(func(a,b):
		if inventory_sort==1 and a.quality!=b.quality: return a.quality>b.quality
		if inventory_sort==2 and a.level!=b.level: return a.level>b.level
		return a.created>b.created)
	var visible_count = 0
	for item in items:
		if inventory_filter[0]>=0 and int(item.role)!=inventory_filter[0]: continue
		if inventory_filter[1]>=0 and int(item.slot)!=inventory_filter[1]: continue
		if inventory_filter[2]>=0 and int(item.quality)!=inventory_filter[2]: continue
		visible_count += 1
		var r = row(inventory_rows,100,870)
		var col = Color(C.COLORS[int(item.quality)])
		icon(r,Rect2(15,21,54,54),int(item.slot),col)
		var text = "%s%s +%d%s\n%s · %s · Lv.%d"%["[已穿戴] " if game.profile.is_equipped(item.uid) else "",game.profile.item_name(item),item.enhance," [锁]" if item.locked else "",C.QUALITIES[int(item.quality)],Data.ROLES[int(item.role)].name,item.level]
		label(r,text,Rect2(86,10,585,80),22,col)
		button(r,"查看",Rect2(710,24,135,52),select_item.bind(item.uid),col)
	if visible_count==0:
		var r = row(inventory_rows,90,870)
		label(r,"暂无符合条件的装备。",Rect2(20,15,820,60),24,MUTED)
	render_item_detail()

func select_item(uid: String) -> void:
	selected_uid = uid
	render_item_detail()

func render_item_detail() -> void:
	clear_children(inventory_detail)
	box(inventory_detail,Rect2(0,0,710,540),INK,Color("#38516b"))
	var item: Dictionary = game.profile.item_by_id(selected_uid)
	if item.is_empty():
		label(inventory_detail,"选择左侧装备查看属性与比较。\n\n强化不会失败，消耗金币和分解材料。\n战利品暂存会保留背包装不下的装备。",Rect2(28,25,650,270),25,MUTED)
		return
	var col = Color(C.COLORS[int(item.quality)])
	label(inventory_detail,game.profile.item_name(item)+" +%d"%item.enhance,Rect2(25,14,650,55),31,col)
	label(inventory_detail,"%s · %s · Lv.%d · %s"%[C.QUALITIES[int(item.quality)],C.SLOTS[int(item.slot)],item.level,C.SETS[int(item.role)] if item.get("set_piece",true) else "基础旅装（无套装）"],Rect2(25,70,650,45),20,MUTED)
	var props: Dictionary = game.profile.item_stats(item)
	var equipped_id: String = game.profile.data.roles[view_role].equipped.get(str(int(item.slot)),"")
	var previous: Dictionary = game.profile.item_by_id(equipped_id)
	var old_props: Dictionary = {} if previous.is_empty() else game.profile.item_stats(previous)
	var lines = PackedStringArray()
	for key in props:
		var difference: float = float(props[key])-float(old_props.get(key,0))
		var percent = key.ends_with("_pct") or key in ["crit","crit_damage","cooldown","dash_cooldown"]
		lines.append(C.stat_text(key,props[key])+"  （对比 %+.2f%s）"%[difference*(100 if percent else 1)," 个百分点" if percent else ""])
	for key in old_props:
		if not props.has(key): lines.append("失去："+C.stat_text(key,old_props[key]))
	label(inventory_detail,"\n".join(lines),Rect2(25,120,650,160),21)
	var special = ""
	if item.get("hidden",false): special = C.special_text(int(item.role),true)
	elif int(item.quality)==3 and int(item.slot)==0: special = C.special_text(int(item.role))
	label(inventory_detail,special,Rect2(25,275,650,65),20,GOLD)
	var cost = C.upgrade_cost(mini(10,int(item.enhance)+1))
	label(inventory_detail,"已达 +10 上限" if int(item.enhance)>=10 else "下级 +%d：金币 %d / 材料 %d；基础属性累计 +%d%%"%[int(item.enhance)+1,cost.gold,cost.material,(int(item.enhance)+1)*3],Rect2(25,345,650,45),20,MUTED)
	var b = button(inventory_detail,"装备",Rect2(25,405,195,52),equip_item.bind(item.uid),col)
	b.disabled = not editable()
	b = button(inventory_detail,"强化",Rect2(245,405,195,52),enhance_item.bind(item.uid),col)
	b.disabled = not editable() or int(item.enhance)>=10 or int(game.profile.data.gold)<cost.gold or int(game.profile.data.material)<cost.material
	b = button(inventory_detail,"解锁" if item.locked else "锁定",Rect2(465,405,215,52),lock_item.bind(item.uid))
	b.disabled = not editable()
	b = button(inventory_detail,"分解 · 材料 +%d"%game.profile.salvage_value(item),Rect2(25,475,655,48),confirm_salvage.bind(item.uid))
	b.disabled = not editable() or item.locked or game.profile.is_equipped(item.uid)

func equip_item(uid: String) -> void:
	if not editable(): return
	commit(game.profile.equip(view_role,uid))
	show_equipment()

func enhance_item(uid: String) -> void:
	if not editable(): return
	commit(game.profile.enhance(uid))
	show_equipment()

func lock_item(uid: String) -> void:
	if not editable(): return
	var item: Dictionary = game.profile.item_by_id(uid)
	if item.is_empty(): return
	item.locked = not item.locked
	game.profile.dirty = true
	commit()
	show_equipment()

func confirm_salvage(uid: String) -> void:
	var item: Dictionary = game.profile.item_by_id(uid)
	if not editable() or item.is_empty(): return
	var dim = ColorRect.new()
	dim.size = Vector2(1920,1080)
	dim.color = Color(0,0,0,0.8)
	overlay.add_child(dim)
	box(dim,Rect2(490,340,940,370),INK,GOLD)
	label(dim,"分解 %s？\n获得 %d 强化材料，装备会被移除。"%[game.profile.item_name(item),game.profile.salvage_value(item)],Rect2(535,390,850,140),30)
	button(dim,"取消",Rect2(535,580,390,70),show_equipment)
	button(dim,"确认分解",Rect2(995,580,390,70),salvage_item.bind(uid))

func salvage_item(uid: String) -> void:
	if not editable(): return
	commit(game.profile.salvage(uid))
	show_equipment()

func claim_stash() -> void:
	if not editable(): return
	commit("已领取 %d 件装备"%game.profile.claim_overflow())
	show_equipment()

func show_loadout() -> void:
	page_start("当前穿戴 · "+Data.ROLES[view_role].name,"每个部位只计一件套装。不同品质可以组成同一套装。","loadout")
	var rows = list_area(Rect2(130,325,1660,585))
	for slot in range(6):
		var item: Dictionary = game.profile.item_by_id(game.profile.data.roles[view_role].equipped.get(str(slot),""))
		var r = row(rows,95,1610)
		label(r,C.SLOTS[slot]+"  "+("未装备" if item.is_empty() else game.profile.item_name(item)+" +%d"%item.enhance),Rect2(25,20,950,55),26)
		if not item.is_empty():
			var b = button(r,"卸下",Rect2(1320,23,250,50),unequip_slot.bind(slot))
			b.disabled = not editable()
	label(overlay,"%s · 已装备 %d / 6 件"%[C.SETS[view_role],game.profile.set_count(view_role)],Rect2(130,965,1100,45),27,GOLD)
	button(overlay,"返回背包",Rect2(1460,956,330,60),show_equipment)

func unequip_slot(slot: int) -> void:
	if not editable(): return
	game.profile.unequip(view_role,slot)
	commit("已卸下")
	show_loadout()

func show_talents() -> void:
	page_start("技能与天赋","等级 1 / 5 / 10 / 15 解锁技能；角色 10–60 级逐步开放技能等级，最高 10 级；天赋点有限，请选择构筑方向。","talents")
	role_tabs()
	label(overlay,"Lv.%d · 可用天赋 %d"%[game.profile.data.roles[view_role].level,game.profile.talent_points(view_role)],Rect2(1000,295,750,45),27,GOLD)
	var rows = list_area(Rect2(130,375,1660,530))
	for i in range(4):
		var skill: Dictionary = C.SKILLS[view_role][i]
		var rank = int(game.profile.data.roles[view_role].skills[i])
		var r = row(rows,190,1610)
		icon(r,Rect2(18,25,54,54),[[8,0,15,9],[10,11,17,6],[12,9,7,15]][view_role][i],Data.ROLES[view_role].color)
		label(r,"%s %s · 技能 Lv.%d · 角色 Lv.%d 解锁 · 基础冷却 %.0fs"%[C.SKILL_KEYS[i],skill.name,rank,C.SKILL_LEVELS[i],skill.cd],Rect2(90,10,1190,42),26,GOLD)
		label(r,skill.text+"\n"+C.skill_milestones(i),Rect2(90,60,1160,120),19)
		var b = button(r,"升级 (%d点)"%C.SKILL_COSTS[mini(9,rank)] if rank<C.MAX_SKILL else "已满级",Rect2(1280,49,295,60),train_skill.bind(i))
		b.disabled = not editable() or rank>=C.MAX_SKILL
		b.tooltip_text = "下级角色要求 Lv.%d；当前可用 %d 点"%[C.SKILL_REQUIREMENTS[mini(9,rank)],game.profile.talent_points(view_role)]
	for t in C.PASSIVES:
		var r = row(rows,105,1610)
		label(r,"%s · %s  %d/%d\n%s"%[t.branch,t.name,game.profile.data.roles[view_role].talents.get(t.id,0),t.max,t.text],Rect2(25,10,1190,85),24)
		var b = button(r,"投入 1 点",Rect2(1280,24,295,56),train_passive.bind(t.id))
		b.disabled = not editable()
	button(overlay,"重置天赋（首次免费，其后 120 金币）",Rect2(130,964,1120,62),reset_training).disabled = not editable()
	button(overlay,"查看组合说明",Rect2(1310,964,480,62),show_combos)

func train_skill(slot: int) -> void:
	if not editable(): return
	commit(game.profile.train_skill(view_role,slot))
	show_talents()

func train_passive(id: String) -> void:
	if not editable(): return
	commit(game.profile.train(view_role,id))
	show_talents()

func reset_training() -> void:
	if not editable(): return
	commit(game.profile.reset_talents(view_role))
	show_talents()

func show_combos() -> void:
	page_start("技能组合","追加伤害有独立来源，不会递归触发自身。组合无需额外花费天赋点。","combos")
	var texts = ["剑修：Q 穿云剑标记 6 秒 → 普攻消耗剑印，追加 120% 范围伤害，内置冷却 0.2 秒。\nE 剑阵持续期间使用 F 回锋步 → 周身追加一次 180% 攻击剑气。","火枪手：E 爆破弹留下 6 秒火药区 → F 装填后的强化弹（F 连续 3 发或普通换弹首发）命中标记/区内目标，追加 200% 爆破。\nQ 霰弹标记 6 秒 → 普攻或 C 火力命中消耗标记，追加 110% 范围伤害，内置冷却 0.2 秒。","游侠：F 猎印 → E 贯日箭消耗标记，追加 180% 范围伤害。\nQ 箭雨区域内普通箭命中目标 → 获得两次额外弹射及 +25% 伤害。"]
	for i in range(3):
		box(overlay,Rect2(130,330+i*190,1660,165),INK,Data.ROLES[i].color)
		label(overlay,texts[i],Rect2(165,345+i*190,1590,135),26)

func show_shop() -> void:
	if game.state!="intermission": return
	game.ensure_shop()
	page_start("整备商店","每回合固定库存，关闭重开不会刷新。金币 %d"%game.profile.data.gold,"shop")
	var rows = list_area(Rect2(130,330,1660,580))
	for i in range(game.flow.stock.size()):
		var offer: Dictionary = game.flow.stock[i]
		var r = row(rows,112,1610)
		label(r,offer.name+"  ·  %d 金币"%offer.price,Rect2(25,10,1050,42),28,GOLD)
		label(r,item_definition(offer.id).text if offer.type=="item" else "当前角色稀有装备 · 等级要求 %d"%offer.gear.level,Rect2(25,55,1120,42),22,MUTED)
		var b = button(r,"已售罄" if offer.sold else "购买",Rect2(1280,28,295,56),buy_offer.bind(i))
		b.disabled = offer.sold or int(game.profile.data.gold)<int(offer.price)
	button(overlay,"配置战斗快捷栏",Rect2(130,964,1660,62),show_consumables)

func buy_offer(index: int) -> void:
	if game.state!="intermission": return
	commit(game.profile.buy(game.flow.stock,index))
	show_shop()

func show_consumables() -> void:
	page_start("战斗道具","每槽可独立选择道具；点击右下按钮设置键盘按键。仅战斗中消耗。","consumables")
	var names: Array = []
	for item in C.ITEMS: names.append(item.name)
	for i in range(3):
		var selected = 0
		for j in range(C.ITEMS.size()):
			if C.ITEMS[j].id==game.profile.data.quick[i]: selected = j
		label(overlay,"按键 "+game.bindings.text("item_%d"%(i+1)),Rect2(130+i*555,305,180,50),25,GOLD)
		option(overlay,names,Rect2(315+i*555,305,335,50),selected,assign_item.bind(i)).disabled = not editable()
	var rows = list_area(Rect2(130,400,1660,500))
	for item in C.ITEMS:
		var r = row(rows,100,1610)
		label(r,"%s ×%d · 冷却 %.0fs"%[item.name,game.profile.data.consumables.get(item.id,0),item.cd],Rect2(25,10,1540,40),26,GOLD)
		label(r,item.text,Rect2(25,55,1540,35),22)

func assign_item(index: int, slot: int) -> void:
	if not editable(): return
	game.profile.data.quick[slot] = C.ITEMS[index].id
	game.profile.dirty = true
	commit("快捷栏已更新")

func show_achievements() -> void:
	page_start("成就","每项奖励只可领取一次。挑战成果永久保留。","achievements")
	var rows = list_area(Rect2(130,330,1660,620))
	for a in C.ACHIEVEMENTS:
		var r = row(rows,115,1610)
		var achieved: bool = game.profile.data.achievements.has(a.id)
		var claimed: bool = game.profile.data.claimed.has(a.id)
		label(r,a.name+" · "+a.text,Rect2(25,10,1180,45),27,GOLD if achieved else WHITE)
		label(r,"奖励 %d 金币 · %s"%[a.gold,"已达成" if achieved else "未达成"],Rect2(25,60,1180,35),22,MUTED)
		var b = button(r,"已领取" if claimed else "领取奖励",Rect2(1280,30,295,56),claim_achievement.bind(a.id))
		b.disabled = not achieved or claimed

func claim_achievement(id: String) -> void:
	commit(game.profile.claim_achievement(id))
	show_achievements()

func show_codex() -> void:
	page_start("行者图鉴","图鉴从实际配置生成。隐藏内容在发现前保留线索，NEW 表示尚未浏览。","codex")
	option(overlay,["Buff","装备","套装","技能","消耗品","敌人与首领","隐藏内容"],Rect2(130,300,250,50),codex_category,change_codex.bind("category"))
	var search = LineEdit.new()
	search.position = Vector2(410,300)
	search.size = Vector2(620,50)
	search.placeholder_text = "搜索名称或效果"
	search.text = codex_query
	search.add_theme_font_override("font",font)
	search.add_theme_font_size_override("font_size",23)
	search.text_changed.connect(search_codex)
	overlay.add_child(search)
	option(overlay,["全部角色","剑修","火枪手","游侠"],Rect2(1060,300,220,50),codex_role+1,change_codex.bind("role"))
	option(overlay,["全部品质"]+C.QUALITIES,Rect2(1300,300,220,50),codex_quality+1,change_codex.bind("quality"))
	option(overlay,["全部状态","已发现","未发现"],Rect2(1540,300,250,50),codex_found,change_codex.bind("found"))
	codex_rows = list_area(Rect2(130,380,1660,540))
	render_codex()

func change_codex(value: int, key: String) -> void:
	match key:
		"category": codex_category = value
		"role": codex_role = value-1
		"quality": codex_quality = value-1
		"found": codex_found = value
	render_codex()

func search_codex(text: String) -> void:
	codex_query = text
	render_codex()

func codex_entries() -> Array:
	var entries: Array = []
	match codex_category:
		0:
			for u in Data.UPGRADES: entries.append({"id":"buff_"+u[0],"name":u[1],"text":u[2]+" · 最多 %d 层 · 波次奖励 / 本局有效"%u[5],"role":int(u[7]),"quality":int(u[6]),"hidden":false})
		1:
			for role in range(3):
				for slot in range(6):
					for quality in range(4):
						var text = "%s · %s · 品质系数 %.2f · 可强化至 +10 · 怪物 / 首领 / 商店\n"%[C.SETS[role],C.SLOTS[slot],C.QUALITY_SCALE[quality]]
						for key in C.SLOT_STATS[slot]: text += C.stat_text(key,C.SLOT_STATS[slot][key]*C.QUALITY_SCALE[quality])+"  "
						text += "（Lv.1 基础，附加词条固定保存）"
						if quality==3 and slot==0: text += "\n"+C.special_text(role)
						entries.append({"id":"gear_%d_%d_%d"%[role,slot,quality],"name":C.QUALITIES[quality]+" · "+C.NAMES[role][slot],"text":text,"role":role,"quality":quality,"hidden":false})
		2:
			for role in range(3): entries.append({"id":"set_%d"%role,"name":C.SETS[role],"text":"\n".join(C.set_text(role))+"\n同套装不同品质可组合；每个部位只计一件。","role":role,"quality":-1,"hidden":false})
		3:
			for role in range(3):
				for slot in range(4):
					var skill: Dictionary = C.SKILLS[role][slot]
					entries.append({"id":"skill_%d_%d"%[role,slot],"name":C.SKILL_KEYS[slot]+" "+skill.name,"text":skill.text+"\n角色 Lv.%d 解锁 · 冷却 %.0fs · 技能最高 10 级"%[C.SKILL_LEVELS[slot],skill.cd],"role":role,"quality":-1,"hidden":false})
		4:
			for item in C.ITEMS: entries.append({"id":"item_"+item.id,"name":item.name,"text":item.text+" · 冷却 %.0fs · 商店 %d 金币"%[item.cd,item.price],"role":-1,"quality":-1,"hidden":false})
		5:
			for i in range(C.ENEMIES.size()): entries.append({"id":"enemy_%d"%i,"name":C.ENEMIES[i],"text":C.ENEMY_TEXT[i],"role":-1,"quality":-1,"hidden":i==8})
		6:
			entries.append({"id":"hidden_gate","name":"镜渊裂隙","text":"第三章第三回合唤醒三个符文，整备时进入可选挑战。","role":-1,"quality":-1,"hidden":true})
			for role in range(3): entries.append({"id":"hidden_%d"%role,"name":["镜渊剑心","镜渊火种","镜渊星瞳"][role],"text":C.special_text(role,true)+" · 隐藏首领掉落 · 替代对应套装护符并计入套装。","role":role,"quality":-1,"hidden":true})
	return entries

func render_codex() -> void:
	clear_children(codex_rows)
	var count = 0
	var mark_seen: Array = []
	for entry in codex_entries():
		if codex_role>=0 and entry.role not in [-1,codex_role]: continue
		if codex_quality>=0 and entry.quality!=codex_quality: continue
		var discovered: bool = game.profile.data.found.has(entry.id)
		if codex_found==1 and not discovered: continue
		if codex_found==2 and discovered: continue
		var title: String = entry.name
		var body: String = entry.text
		if entry.hidden and not discovered:
			title = "未知的裂隙回响"
			body = "线索：裂隙要塞深处，三枚符文等待行者回应。"
		if not codex_query.is_empty() and (title+body).findn(codex_query)<0: continue
		var col = Color(C.COLORS[maxi(0,entry.quality)])
		var height = 190 if codex_category in [1,2,3] else 135
		var r = row(codex_rows,height,1610)
		var fresh: bool = discovered and not game.profile.data.seen.has(entry.id)
		label(r,title+("  NEW" if fresh else "")+(" · 已发现" if discovered else " · 未发现"),Rect2(25,10,1550,43),27,col)
		label(r,body,Rect2(25,60,1550,height-70),22)
		if fresh: mark_seen.append(entry.id)
		count += 1
	if count==0:
		var r = row(codex_rows,90,1610)
		label(r,"没有符合筛选的条目。",Rect2(25,15,1560,60),25,MUTED)
	for id in mark_seen: game.profile.data.seen[id] = true; game.profile.dirty = true
