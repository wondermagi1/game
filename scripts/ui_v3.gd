extends "res://scripts/ui_v2.gd"
const Evo = preload("res://scripts/buff_progression.gd")
var scroll_memory: Dictionary = {}
var focus_memory: Dictionary = {}
var binding_action: String = ""
var pending_key: int = 0
var conflict_action: String = ""
var binding_prompt: Label
var detail_panel: Control
var codex_selected: String = ""
var favorites_only: bool = false
var notification: Panel
var notification_clock: float = 0
var enhancing: bool = false
var progress_label: Label

func _ready() -> void:
	super._ready()
	notification = box(self,Rect2(1260,170,570,118),Color("#1c293c"),GOLD)
	notification.z_index = 20
	notification.hide()

func page_start(title: String, subtitle: String, key: String) -> void:
	remember_scroll()
	binding_action = ""
	super.page_start(title,subtitle,key)

func remember_scroll() -> void:
	if not is_instance_valid(overlay): return
	var index = 0
	for child in overlay.get_children():
		if child is ScrollContainer:
			scroll_memory[page+str(view_role)+str(index)] = child.scroll_vertical
			index += 1
	var focus = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and focus is Button: focus_memory[page] = focus.get_meta("focus_id","")

func list_area(rect: Rect2, parent: Node = null) -> VBoxContainer:
	var rows = super.list_area(rect,parent)
	var index = 0
	for child in overlay.get_children():
		if child is ScrollContainer: index += 1
	restore_scroll.call_deferred(rows.get_parent(),int(scroll_memory.get(page+str(view_role)+str(index-1),0)),page)
	return rows

func restore_scroll(scroll: ScrollContainer, value: int, key: String) -> void:
	await get_tree().process_frame
	if not is_instance_valid(scroll) or key!=page: return
	# Restore keyboard focus, then restore the scroll so focusing cannot jump it.
	for candidate in overlay.find_children("*","Button",true,false):
		if candidate.get_meta("focus_id","-")==focus_memory.get(key,""):
			candidate.grab_focus()
			break
	scroll.scroll_vertical = value

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(game.player) and game.flow.abyss: stage_label.text = game.flow.title()+" · 历史 %d 层"%int(game.profile.data.abyss_best[game.selected_role])
	if not is_instance_valid(notification): return
	if game.state not in ["combat","end"] and page!="menu":
		notification.hide()
		return
	if game.profile.events.size()>30: game.profile.events.resize(30)
	notification_clock = maxf(0,notification_clock-delta)
	if notification_clock<=0:
		notification.hide()
		if not game.profile.events.is_empty():
			var event: Dictionary = game.profile.events.pop_front()
			clear_children(notification)
			label(notification,event.title,Rect2(23,10,520,44),25,GOLD)
			label(notification,event.text,Rect2(23,57,520,50),19)
			notification_clock = 4
			game.sound.play("achievement")
			notification.show()
	if notification_clock>0:
		notification.modulate.a = minf(1,minf((4-notification_clock)*4,notification_clock*3))
		notification.position.x = 1260+maxf(0,notification_clock-3.7)*180

func show_menu() -> void:
	super.show_menu()
	label(overlay,"深渊回响 / V0.3",Rect2(1045,165,720,46),30,GOLD)
	if not game.profile.data.checkpoint.is_empty():
		button(overlay,"继续深渊 · 第 %d 层后整备"%int(game.profile.data.checkpoint.get("cleared",0)),Rect2(1050,815,700,58),func(): game.abyss.resume())
		button(overlay,"放弃此深渊存档",Rect2(1410,940,340,52),confirm_abandon)

func confirm_abandon() -> void:
	page_start("放弃深渊存档？","永久等级、金币和装备保留；本次 Buff、楼层及临时技能不可恢复。","abandon")
	button(overlay,"取消",Rect2(300,500,580,80),show_menu)
	button(overlay,"确认放弃本次深渊",Rect2(1030,500,580,80),func():
		if game.abyss.abandon(): show_menu()
		else: game.notify_player("存档写入失败，未放弃。"))

func show_chapters() -> void:
	page_start("选择旅途","前四章保留原流程；五、六章引入场地机制。难度固定，不随装备暗中提升。","chapters")
	for i in range(6):
		var c: Dictionary = C.CHAPTERS[i]
		var x = 130+(i%3)*560
		var y = 315+floori(i/3.0)*245
		box(overlay,Rect2(x,y,525,220),INK,Color(c.color))
		label(overlay,"%02d %s"%[i+1,c.name],Rect2(x+20,y+10,485,45),30,Color(c.color))
		label(overlay,"%d 回合 · 推荐 Lv.%d · 约 %s\n%s"%[c.waves.size(),c.level,C.PACING[i].target,c.hint],Rect2(x+20,y+60,485,94),20)
		var b = button(overlay,"进入挑战" if i<int(game.profile.data.unlocked) else "完成前章后解锁",Rect2(x+20,y+163,485,44),start_chapter.bind(i+1),Color(c.color))
		b.disabled = i>=int(game.profile.data.unlocked)
		b.tooltip_text = "参考构筑："+C.DIFFICULTY[i].build
	button(overlay,"无尽深渊 →" if game.abyss.unlocked() else "无尽深渊 · 完成第六章解锁",Rect2(130,845,1660,65),func(): game.abyss.start(view_role)).disabled = not game.abyss.unlocked()
	label(overlay,"深渊：每层三选一 · 每 5 层整备/保存退出 · 每 10 层首领 · Buff 无限层数 · 不屈每次深渊仅一次",Rect2(130,925,1660,66),23,GOLD)

func show_intermission() -> void:
	super.show_intermission()
	if game.flow.abyss:
		for child in overlay.get_children():
			if child is Label and child.position.y==123: child.text = "深渊整备"
			if child is Label and child.position.y==215: child.text = "休息点可保存退出；继续时恢复 25% 生命。战斗中结束挑战会失去本局构筑。"
			if child is Label and child.position.y==320: child.text = "第 %d 层已完成\n金币 %d · 材料 %d · Lv.%d · 可用天赋 %d"%[game.flow.floor_number,game.profile.data.gold,game.profile.data.material,game.profile.data.roles[view_role].level,game.profile.talent_points(view_role)]
			if child is Button and child.text=="开始下一回合 →": child.text = "进入下一层 →"
		button(overlay,"保存深渊并退出（休息点）",Rect2(150,755,780,70),func(): game.abyss.save_exit(),Color("#bc9dea"))
		label(overlay,"已完成第 %d 层；下一层 %d。续玩会消耗存档，强退不回退奖励。"%[game.flow.floor_number,game.flow.floor_number+1],Rect2(150,420,1600,50),23)

func show_end(victory: bool) -> void:
	super.show_end(victory)
	if game.flow.abyss:
		for child in overlay.get_children():
			if child is Button and child.text=="再次挑战本章":
				child.hide()
		button(overlay,"再次挑战深渊",Rect2(130,870,770,80),func(): game.abyss.start(game.selected_role))

func render_item_detail() -> void:
	super.render_item_detail()
	var item: Dictionary = game.profile.item_by_id(selected_uid)
	if item.is_empty(): return
	var rank = int(item.enhance)
	var cost = C.upgrade_cost(mini(10,rank+1))
	var reason = "强化必定成功；点击扣除一次费用。"
	if not editable(): reason = "战斗中不可强化；请在营地或整备时操作。"
	elif rank>=10: reason = "已达 +10 上限。"
	elif game.profile.data.gold<cost.gold: reason = "金币不足；挑战怪物、完成成就可获得。"
	elif game.profile.data.material<cost.material: reason = "材料不足；分解多余装备，精英/首领固定掉落。"
	var preview: Dictionary = item.duplicate(true)
	preview.enhance = mini(10,rank+1)
	var before: Dictionary = game.profile.item_stats(item)
	var after: Dictionary = game.profile.item_stats(preview)
	var lines = PackedStringArray()
	for key in before: lines.append("%s：%.2f → %.2f"%[C.STAT_NAMES.get(key,key),before[key],after[key]])
	for child in inventory_detail.get_children():
		if child is Label and child.position.y==345:
			child.text = "金币 %d / %d · 材料 %d / %d（持有/需要）"%[game.profile.data.gold,cost.gold,game.profile.data.material,cost.material]
			child.tooltip_text = "下级预览\n"+"\n".join(lines)+"\n"+reason
		if child is Button and child.text=="强化": child.tooltip_text = reason+"\n"+"\n".join(lines)
	label(inventory_detail,reason,Rect2(25,380,650,24),17,GOLD)
	for child in inventory_detail.get_children():
		if child is Label and child.position.y==120:
			child.text += "\n下级："+"；".join(lines)
			child.add_theme_font_size_override("font_size",19)

func show_settings(in_run: bool) -> void:
	remember_scroll()
	super.show_settings(in_run)
	button(overlay,"自定义键盘按键",Rect2(1050,745,700,65),show_bindings)
	label(overlay,"主音量",Rect2(1050,550,650,45),27)
	var slider = HSlider.new()
	slider.position = Vector2(1050,625)
	slider.size = Vector2(650,45)
	slider.max_value = 1
	slider.step = 0.01
	slider.value = game.sound.master_volume
	slider.value_changed.connect(func(value): game.sound.master_volume=value; game.save_settings())
	overlay.add_child(slider)

func show_consumables() -> void:
	super.show_consumables()
	button(overlay,"设置快捷键对应的键盘按键",Rect2(1050,951,740,60),show_bindings)

func show_bindings() -> void:
	binding_action = ""
	page_start("键盘与快捷栏","点击一个动作后按新键；Esc 取消。重复按键必须确认交换。左键固定攻击，Tab 属性与 Esc 暂停保留。","bindings")
	var rows = list_area(Rect2(130,325,1100,570))
	for action in game.bindings.keys:
		var r = row(rows,75,1050)
		label(r,game.bindings.NAMES[action],Rect2(25,10,610,50),25)
		button(r,game.bindings.text(action),Rect2(690,12,330,50),begin_binding.bind(action))
	binding_prompt = label(overlay,"等待选择动作",Rect2(1300,335,475,220),27,GOLD)
	button(overlay,"恢复默认按键",Rect2(1300,640,475,62),func():
		game.bindings.keys = game.bindings.DEFAULTS.duplicate()
		game.bindings.apply()
		game.save_settings()
		show_bindings())
	button(overlay,"配置每槽道具",Rect2(1300,740,475,62),show_consumables)

func begin_binding(action: String) -> void:
	binding_action = action
	conflict_action = ""
	pending_key = 0
	binding_prompt.text = "请按下【%s】的新键\nEsc 取消"%game.bindings.NAMES[action]
	get_viewport().gui_release_focus()

func _input(event: InputEvent) -> void:
	if binding_action.is_empty(): return
	if not event is InputEventKey: return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo: return
	if event.keycode==KEY_ESCAPE:
		show_bindings()
		return
	if not conflict_action.is_empty(): return
	if event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed:
		binding_prompt.text = "请选择不带修饰键的单个键。"
		return
	var key = int(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
	conflict_action = game.bindings.conflict(binding_action,key)
	if not conflict_action.is_empty():
		pending_key = key
		binding_prompt.text = "%s 已用于【%s】。\n选择交换，或按 Esc 取消。"%[OS.get_keycode_string(key),game.bindings.NAMES[conflict_action]]
		button(overlay,"确认交换",Rect2(1300,560,475,60),confirm_binding_swap)
		return
	if game.bindings.bind_key(binding_action,key):
		game.save_settings()
		show_bindings()
	else: binding_prompt.text = "该按键为系统保留，请选择其他键。"

func confirm_binding_swap() -> void:
	if game.bindings.bind_key(binding_action,pending_key,true): game.save_settings()
	show_bindings()

func show_codex() -> void:
	page_start("行者档案馆","选择左侧条目查看效果与获得方式。浏览不会授予装备、Buff 或成就。","codex")
	option(overlay,["Buff","装备","套装","技能","道具 / 材料","怪物 / 首领","章节 / 玩法","成就 / 秘闻"],Rect2(130,295,310,50),codex_category,change_codex.bind("category"))
	var search = LineEdit.new()
	search.position = Vector2(460,295)
	search.size = Vector2(400,50)
	search.placeholder_text = "搜索名称 / 效果"
	search.text = codex_query
	search.text_changed.connect(search_codex)
	search.add_theme_font_override("font",font)
	search.add_theme_font_size_override("font_size",22)
	overlay.add_child(search)
	option(overlay,["所有角色","剑修","火枪手","游侠"],Rect2(880,295,205,50),codex_role+1,change_codex.bind("role"))
	option(overlay,["所有品质"]+C.QUALITIES,Rect2(1100,295,205,50),codex_quality+1,change_codex.bind("quality"))
	option(overlay,["所有状态","已发现","未发现","NEW"],Rect2(1320,295,220,50),codex_found,change_codex.bind("found"))
	button(overlay,"★ 收藏" if favorites_only else "全部 / 收藏",Rect2(1555,295,235,50),func(): favorites_only=not favorites_only; show_codex()).add_theme_font_size_override("font_size",21)
	codex_rows = list_area(Rect2(130,380,625,550))
	detail_panel = Control.new()
	detail_panel.position = Vector2(790,380)
	overlay.add_child(detail_panel)
	progress_label = label(overlay,"",Rect2(130,950,1650,55),22,GOLD)
	render_codex()

func codex_entries() -> Array:
	var entries: Array = []
	if codex_category==6:
		for i in range(6):
			var c: Dictionary = C.CHAPTERS[i]
			entries.append({"id":"chapter_%d"%(i+1),"name":c.name,"text":c.hint+"\n推荐构筑："+C.DIFFICULTY[i].build+"\n%d 回合，每回合最多三波。目标 %s；通关解锁后章。"%[c.waves.size(),C.PACING[i].target],"role":-1,"quality":-1,"hidden":false})
		entries.append({"id":"mode_abyss","name":"无尽深渊","text":"完成第六章解锁。每层奖励三选一；5层精英+整备，10层首领替代普通战。整备点可保存退出。\nBuff 无层数上限，5/10/20/40 阶段进化，工程上限超额转换攻击收益。临时技能每5层提升一次，最高10级。\n存档包含本次构筑、随机状态和商店库存；续玩先消耗存档。退出普通战斗不保存本局。\n不屈整次深渊仅可复活一次。","role":-1,"quality":-1,"hidden":false})
	elif codex_category==7:
		codex_category = 6
		entries = super.codex_entries()
		codex_category = 7
		for a in C.ACHIEVEMENTS: entries.append({"id":"achievement_"+a.id,"name":a.name,"text":a.text+"\n达成后在成就页领取 %d 金币；每项仅一次。"%a.gold,"role":-1,"quality":-1,"hidden":false})
	else:
		entries = super.codex_entries()
		if codex_category==0:
			for i in range(entries.size()): entries[i].text += "\n"+Evo.description(Data.UPGRADES[i][3])
		if codex_category==3:
			for i in range(entries.size()): entries[i].text += "\n"+C.skill_milestones(i%4)+"\n技能提升需要天赋点，角色 60 级最多获得 59 点，无法点满全部分支。"
		if codex_category==4: entries.append({"id":"material","name":"强化材料","text":"新档/旧档升级首次赠送 3 份；普通怪 4% 掉落 1 份，精英固定 2，章节首领 8，隐藏首领 12；另有清房与奇遇材料。\n分解普通/稀有/史诗/传奇装备返还 1/3/7/15，加已消耗材料的 50%。\n强化必定成功，最高 +10。金币成本 30+15×目标强化等级²；材料 1+floor(目标等级/3)。","role":-1,"quality":-1,"hidden":false})
	return entries

func entry_found(entry: Dictionary) -> bool:
	if entry.id.begins_with("chapter_"): return game.profile.data.cleared.has(int(entry.id.trim_prefix("chapter_")))
	if entry.id.begins_with("achievement_"): return game.profile.data.achievements.has(entry.id.trim_prefix("achievement_"))
	return game.profile.data.found.has(entry.id)

func render_codex() -> void:
	clear_children(codex_rows)
	var entries = codex_entries()
	var discovered_count = 0
	var visible_count = 0
	var selected: Dictionary = {}
	for entry in entries:
		var found = entry_found(entry)
		if found: discovered_count += 1
		if codex_role>=0 and entry.role not in [-1,codex_role]: continue
		if codex_quality>=0 and entry.quality!=codex_quality: continue
		if codex_found==1 and not found: continue
		if codex_found==2 and found: continue
		if codex_found==3 and (not found or game.profile.data.seen.has(entry.id)): continue
		if favorites_only and not game.profile.data.favorites.has(entry.id): continue
		var title: String = entry.name if not entry.hidden or found else "未知秘闻 · 裂隙回响"
		var body: String = entry.text if not entry.hidden or found else "线索：裂隙深处的符文。"
		if not codex_query.is_empty() and (title+body).findn(codex_query)<0: continue
		visible_count += 1
		var r = row(codex_rows,90,580)
		var fresh = found and not game.profile.data.seen.has(entry.id)
		var b = button(r,title+("  NEW" if fresh else ""),Rect2(10,10,560,70),open_entry.bind(entry.id),Color(C.COLORS[maxi(0,entry.quality)]))
		b.add_theme_font_size_override("font_size",23)
		if entry.id==codex_selected: selected = entry
	if visible_count==0:
		var empty_row = row(codex_rows,90,580)
		label(empty_row,"没有符合筛选的条目。",Rect2(20,15,540,60),23,MUTED)
	progress_label.text = "本类发现 %d / %d · 筛选结果 %d · 未发现的公开内容可预览，隐藏效果须探索后揭示"%[discovered_count,entries.size(),visible_count]
	show_codex_detail(selected)

func open_entry(id: String) -> void:
	codex_selected = id
	for entry in codex_entries():
		if entry.id==id and entry_found(entry):
			game.profile.data.seen[id] = true
			game.profile.dirty = true
	render_codex()

func show_codex_detail(entry: Dictionary) -> void:
	clear_children(detail_panel)
	box(detail_panel,Rect2(0,0,1000,550),INK,Color("#536078"))
	if entry.is_empty():
		label(detail_panel,"选择一个条目\n\n查看实际配置、获得方式与进阶规则。",Rect2(40,65,910,210),30,MUTED)
		return
	var found = entry_found(entry)
	var hidden: bool = entry.hidden and not found
	label(detail_panel,"未知的回响" if hidden else entry.name,Rect2(35,25,920,65),36,GOLD)
	var rows = super.list_area(Rect2(35,110,930,340),detail_panel)
	var body = Label.new()
	body.text = "线索：裂隙要塞主路第二处房间北墙有三道微光，靠近交互。" if hidden else entry.text
	body.custom_minimum_size = Vector2(890,0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font",font)
	body.add_theme_font_size_override("font_size",23)
	rows.add_child(body)
	button(detail_panel,"取消收藏" if game.profile.data.favorites.has(entry.id) else "☆ 收藏",Rect2(35,470,410,55),func():
		if game.profile.data.favorites.has(entry.id): game.profile.data.favorites.erase(entry.id)
		else: game.profile.data.favorites[entry.id] = true
		game.profile.dirty = true
		commit()
		render_codex()).add_theme_font_size_override("font_size",22)
	label(detail_panel,"已发现" if found else "尚未发现",Rect2(505,470,410,55),23,MUTED)

func show_characters() -> void:
	super.show_characters()
	var stats = preview_stats(view_role)
	if stats.abyss:
		label(overlay,"深渊进阶：共鸣 %d / 守护 %d / 疾行 %d 阶 · 溢出与进阶攻击 +%.1f%% · 当前防御/冷却已按软上限折算"%[stats.evolution_tier("共鸣"),stats.evolution_tier("守护"),stats.evolution_tier("疾行"),stats.overflow_power()*100],Rect2(130,935,1660,95),23,GOLD)

func button(parent: Node, text_value: String, rect: Rect2, callback: Callable, accent: Color = GOLD) -> Button:
	var result = super.button(parent,text_value,rect,callback,accent)
	result.set_meta("focus_id",str(callback.get_method())+str(callback.get_bound_arguments()))
	return result

func enhance_item(uid: String) -> void:
	if enhancing or not editable(): return
	enhancing = true
	var before: Dictionary = game.profile.data.duplicate(true)
	var result: String = game.profile.enhance(uid)
	if not game.profile.save_profile():
		game.profile.data = before
		result = "保存失败，强化与费用已回滚。"
	game.refresh_stats()
	game.notify_player(result)
	show_equipment()
	await get_tree().process_frame
	enhancing = false

func show_talents() -> void:
	super.show_talents()
	if game.flow.abyss and is_instance_valid(game.player) and view_role==game.selected_role:
		label(overlay,"深渊临时技能加成：E +%d / Q +%d / F +%d / C +%d（有效上限 10；退出本次深渊清空）"%game.player.skills.temporary,Rect2(130,350,1660,25),17,GOLD)
