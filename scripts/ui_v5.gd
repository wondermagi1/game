extends "res://scripts/ui_v4.gd"
const Look = preload("res://scripts/presentation.gd")
const Emblem = preload("res://scripts/gear_emblem.gd")
var growth_clock: float = 0
var growth_panel: Control
var action_lock: float = 0
var forge_lock: float = 0
var selected_menu: int = 0
var hud_masks: Array[ColorRect] = []
func _ready() -> void:
	super._ready()
	# Reserved top HUD region. Its bottom edge is 120, arena starts at 160.
	minimap.position = Vector2(1275,24)
	minimap.size = Vector2(335,96)
	stage_label.size.x = 640
	stage_label.add_theme_font_size_override("font_size",25)
	detail_label.size.x = 640
	detail_label.add_theme_font_size_override("font_size",15)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail_label.clip_text = true
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	boss_bar.add_theme_stylebox_override("fill",style(Color("#e1b58a")))
	boss_bar.add_theme_stylebox_override("background",style(Color("#233744")))
	growth_panel = box(self,Rect2(680,135,560,115),Color("#162f35"),GOLD)
	growth_panel.z_index = 80
	growth_panel.hide()
	for i in range(4):
		var mask = ColorRect.new()
		mask.color = Color(0.025,.04,.07,.65)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(mask)
		hud_masks.append(mask)
func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> StyleBoxFlat:
	var s = super.style(color,border,mini(radius,9))
	s.shadow_color = Color(0,0,0,.18)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0,4)
	return s
func shade() -> void:
	var background = preload("res://scripts/ui_atmosphere.gd").new()
	background.game = game
	background.menu = page=="menu"
	overlay.add_child(background)
	# Full-screen input shield below the controls.
	var shield = Control.new()
	shield.size = Vector2(1920,1080)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shield)
func clear_overlay() -> void:
	super.clear_overlay()
	growth_clock = 0
func page_start(title: String, subtitle: String, key: String) -> void:
	super.page_start(title,subtitle,key)
	for child in overlay.get_children():
		if child is Label: child.text = child.text.replace("第四版","第五版 · 绮光铸影")
func button(parent: Node, text_value: String, rect: Rect2, callback: Callable, accent: Color = GOLD) -> Button:
	var b = super.button(parent,text_value,rect,callback,accent)
	b.add_theme_stylebox_override("normal",style(Color("#15252e"),Color(accent,.42),8))
	b.add_theme_stylebox_override("hover",style(Color("#263f48"),accent,8))
	b.add_theme_stylebox_override("pressed",style(Color("#354a4d"),accent,8))
	b.add_theme_stylebox_override("disabled",style(Color("#182028"),Color("#3b4750"),8))
	b.add_theme_color_override("font_disabled_color",Color("#74838a"))
	b.mouse_entered.connect(func(): game.sound.play("ui_hover"))
	b.pressed.connect(func(): game.sound.play("ui_click"))
	return b
func emblem(parent: Node, item: Dictionary, rect: Rect2, animate: bool = false):
	var e = Emblem.new()
	e.role = int(item.role)
	e.slot = int(item.slot)
	e.quality = int(item.quality)
	e.rank = int(item.get("enhance",0))
	e.animated = animate and not game.reduced_motion
	e.position = rect.position
	e.size = rect.size
	parent.add_child(e)
	return e
func show_menu() -> void:
	page = "menu"
	game.state = "menu"
	clear_overlay()
	hud.hide()
	shade()
	label(overlay,"THREEFOLD TRIAL   /   绮光铸影  0.5",Rect2(75,30,1250,50),23,GOLD)
	label(overlay,"三途试炼",Rect2(75,128,1150,100),76)
	label(overlay,"三条道路，一场未竟的远征",Rect2(80,238,1200,50),27,Color("#ccdadd"))
	label(overlay,"金币 %d   材料 %d   远征 %d / 6"%[game.profile.data.gold,game.profile.data.material,game.profile.data.unlocked],Rect2(1220,35,620,45),22,GOLD)
	for config in Look.ROLES:
		var id: int = config.id
		var x = 80+id*445
		var col: Color = config.color
		box(overlay,Rect2(x,330,415,620),Color(.03,.07,.09,.84),col if selected_menu==id else Color(col,.35))
		var node = preload("res://scripts/actor_visual.gd").new()
		node.kind = id
		node.tint = col
		node.position = Vector2(x+210,670)
		node.scale = Vector2.ONE*2.75
		node.aim = Vector2(.95,.15)
		node.quality = 3 if game.profile.set_count(id)>=6 else 1
		overlay.add_child(node)
		label(overlay,config.word,Rect2(x+25,360,365,58),43,col)
		label(overlay,config.name+" · Lv.%d"%game.profile.data.roles[id].level,Rect2(x+25,730,365,42),28)
		label(overlay,config.tag,Rect2(x+25,785,365,36),21,MUTED)
		var unlocked = 0
		for required in C.SKILL_LEVELS:
			if game.profile.data.roles[id].level>=required: unlocked += 1
		label(overlay,"套装 %d / 6   技能 %d / 4"%[game.profile.set_count(id),unlocked],Rect2(x+25,832,365,36),20,GOLD)
		var b = button(overlay,"以"+config.name+"出征 →",Rect2(x+25,882,365,48),menu_choose.bind(id),col)
		b.set_meta("role_id",id)
		b.mouse_entered.connect(func(): node.action=.45; node.casting=true)
	var actions = [["角色属性",show_characters],["装备 · 铸造",show_equipment],["技能 · 天赋",show_talents],["万象图鉴",show_codex],["成就纪事",show_achievements],["设置",func(): show_settings(false)]]
	for i in range(actions.size()):
		button(overlay,actions[i][0],Rect2(1470,362+i*83,360,61),actions[i][1])
	if not game.profile.data.exploration.is_empty():
		button(overlay,"继续探索",Rect2(1470,872,170,55),func(): game.rooms.resume())
		button(overlay,"放弃…",Rect2(1660,872,170,55),confirm_exploration_abandon)
	elif not game.profile.data.checkpoint.is_empty():
		button(overlay,"继续深渊",Rect2(1470,872,170,55),func(): game.abyss.resume())
		button(overlay,"放弃…",Rect2(1660,872,170,55),confirm_abandon)
	button(overlay,"奇遇 · 噜噜温泉",Rect2(1260,995,360,46),show_lulu_select,Color("#a4dcd4"))
	button(overlay,"退出",Rect2(1650,995,180,46),func(): game.profile.save_profile(); get_tree().quit())
	label(overlay,"选择你的道路  ·  装备与等级永久保留  ·  按键可在设置修改",Rect2(80,993,1150,50),21,MUTED)
func menu_choose(role: int) -> void:
	selected_menu = role
	choose_role(role)

func show_lulu_select() -> void:
	page_start("奇遇 · 噜噜温泉","可选轻松挑战 · 不影响主线解锁 · 胜利保证一件当前职业史诗饰品","lulu_select")
	var v = preload("res://scripts/actor_visual.gd").new()
	v.kind = 16
	v.enemy_id = 14
	v.position = Vector2(460,740)
	v.scale = Vector2.ONE*2.4
	overlay.add_child(v)
	label(overlay,"温泉主人 / 水豚噜噜",Rect2(830,350,880,66),41,Color("#e5ca92"))
	label(overlay,"躲开慢悠悠的泡泡；拍水前会出现危险区域。\n它泡澡休息时，就是你的反击机会。\n\n首次胜利：解锁「噜噜的好朋友」成就。\n每次胜利：史诗饰品、金币、经验和材料。",Rect2(830,450,910,255),27)
	for role in range(3):
		button(overlay,Look.ROLES[role].word+" · "+Look.ROLES[role].name,Rect2(820+role*325,790,305,70),game.rooms.start_lulu.bind(role),Look.ROLES[role].color)
	label(overlay,"这是一场友好的泡泡切磋。噜噜战败后会回温泉休息。",Rect2(250,960,1430,65),26,GOLD)

func show_chapters() -> void:
	super.show_chapters()
	for child in overlay.get_children():
		if child is Button and child.position.y==845: child.size.x=1110
	button(overlay,"奇遇 · 噜噜温泉",Rect2(1270,845,520,65),show_lulu_select,Color("#a4dcd4"))

func codex_entries() -> Array:
	var entries = super.codex_entries()
	if codex_category==6:
		entries.append({"id":"mode_lulu","name":"噜噜温泉","text":"从主菜单或章节选择进入，所有角色可挑战。独立泡泡切磋，不解锁主线章节。\n两间房：安全入口、噜噜温泉。入口可保存续玩。\n胜利保证一件当前职业史诗饰品；首次解锁「噜噜的好朋友」。","role":-1,"quality":-1,"hidden":false})
	return entries

func show_end(victory: bool) -> void:
	if not game.flow.capybara:
		super.show_end(victory)
		return
	page_start("噜噜的好朋友" if victory else "休息一下，再来玩", "这是一场友好的切磋。已获得的装备、金币和经验会保留。", "end")
	hide_back()
	var v = preload("res://scripts/actor_visual.gd").new()
	v.kind=16; v.enemy_id=14; v.position=Vector2(430,715); v.scale=Vector2.ONE*2.0
	overlay.add_child(v)
	label(overlay,"噜噜满足地打了个哈欠，回到温泉里。" if victory else "噜噜递来一条毛巾：下次再一起玩吧。",Rect2(760,360,990,105),36,Color("#c1e6d5"))
	label(overlay,"本次获得\n金币 +%d   经验 +%d   装备 +%d\n用时 %02d:%02d"%[game.earned_gold,game.earned_xp,game.earned_gear,floori(game.elapsed/60),int(game.elapsed)%60],Rect2(760,515,980,205),30)
	label(overlay,"保证奖励：当前角色史诗饰品。成就奖励可在成就页领取。" if victory else "可以在营地强化装备、提升天赋后再次挑战。",Rect2(760,750,980,75),24,GOLD)
	button(overlay,"再去找噜噜玩",Rect2(145,900,795,80),game.rooms.start_lulu.bind(game.selected_role))
	button(overlay,"返回营地",Rect2(980,900,795,80),game.back_to_menu)

func render_inventory() -> void:
	super.render_inventory()
	# Replace generic slot marks using the exact sorted and filtered item list.
	var items: Array = game.profile.data.inventory.duplicate()
	items.sort_custom(func(a,b):
		if inventory_sort==1 and a.quality!=b.quality: return a.quality>b.quality
		if inventory_sort==2 and a.level!=b.level: return a.level>b.level
		return a.created>b.created)
	var n = 0
	for item in items:
		if inventory_filter[0]>=0 and int(item.role)!=inventory_filter[0]: continue
		if inventory_filter[1]>=0 and int(item.slot)!=inventory_filter[1]: continue
		if inventory_filter[2]>=0 and int(item.quality)!=inventory_filter[2]: continue
		var r = inventory_rows.get_child(n)
		n += 1
		for child in r.get_children():
			if child is TextureRect: child.hide()
		emblem(r,item,Rect2(12,16,64,64))
func render_item_detail() -> void:
	clear_children(inventory_detail)
	box(inventory_detail,Rect2(0,0,710,575),Color("#10232d"),Color("#436068"))
	var item: Dictionary = game.profile.item_by_id(selected_uid)
	if item.is_empty():
		label(inventory_detail,"选择一件装备\n\n查看真实属性、换装对比与强化预览。\n强化上限 +10，必定成功。",Rect2(30,40,645,300),26,MUTED)
		return
	emblem(inventory_detail,item,Rect2(24,20,92,92),true)
	var col: Color = Look.QUALITY[int(item.quality)]
	label(inventory_detail,game.profile.item_name(item)+" +%d"%item.enhance,Rect2(134,20,548,47),29,col)
	label(inventory_detail,"%s · %s · Lv.%d\n%s"%[C.QUALITIES[int(item.quality)],C.SLOTS[int(item.slot)],item.level,C.SETS[int(item.role)] if item.get("set_piece",true) else "基础旅装"],Rect2(134,68,548,65),20,MUTED)
	var lines: Array[String] = []
	var raw: Dictionary = item.duplicate(true)
	raw.enhance = 0
	raw.affixes = []
	var base: Dictionary = game.profile.item_stats(raw)
	for key in base:
		lines.append(C.stat_text(key,base[key])+"  / 强化 "+C.stat_text(key,base[key]*.03*int(item.enhance)))
	for affix in item.affixes: lines.append("词条 · "+C.stat_text(affix.key,affix.amount))
	label(inventory_detail,"\n".join(lines),Rect2(25,143,655,150),19)
	var extra = "专属："+C.special_text(int(item.role),item.get("hidden",false)) if item.get("hidden",false) or (int(item.quality)==3 and int(item.slot)==0) else "套装效果请在「六部位穿戴」查看；基础旅装不计件数。"
	label(inventory_detail,extra,Rect2(25,297,655,67),19,GOLD)
	label(inventory_detail,comparison(item),Rect2(25,363,655,54),18,Color("#a8d8cb"))
	var reason = enhance_reason(item)
	label(inventory_detail,reason,Rect2(25,425,655,40),18,MUTED)
	button(inventory_detail,"装备",Rect2(25,478,150,49),equip_item.bind(item.uid),col).disabled = not editable() or int(item.role)!=view_role or int(item.level)>game.profile.data.roles[view_role].level
	button(inventory_detail,"强化",Rect2(189,478,150,49),enhance_item.bind(item.uid),col).disabled = not can_enhance(item)
	button(inventory_detail,"铸造详情",Rect2(353,478,156,49),show_forge.bind(item.uid),col)
	button(inventory_detail,"解锁" if item.locked else "锁定",Rect2(523,478,156,49),lock_item.bind(item.uid)).disabled = not editable()
	button(inventory_detail,"分解 · 材料 +%d"%game.profile.salvage_value(item),Rect2(25,535,654,32),confirm_salvage.bind(item.uid)).disabled = not editable() or item.locked or game.profile.is_equipped(item.uid)
func comparison(item: Dictionary) -> String:
	if int(item.role)!=view_role: return "属于"+Look.ROLES[int(item.role)].name+"，请切换角色后比较。"
	var copy = preload("res://scripts/profile.gd").new()
	copy.data = game.profile.data.duplicate(true)
	copy.data.roles[view_role].equipped[str(int(item.slot))] = item.uid
	var before = preload("res://scripts/stats.gd").new(view_role)
	var after = preload("res://scripts/stats.gd").new(view_role)
	before.permanent = game.profile.permanent_bonuses(view_role)
	after.permanent = copy.permanent_bonuses(view_role)
	var parts: Array[String] = []
	for key in ["attack","hp","armor","crit"]:
		var difference: float = after.value(key)-before.value(key)
		parts.append("%s %+.1f%s"%[C.STAT_NAMES.get(key,key),difference*(100 if key=="crit" else 1),"pp" if key=="crit" else ""])
	return "换装后最终属性："+ " · ".join(parts)
func can_enhance(item: Dictionary) -> bool:
	if item.is_empty() or not editable() or int(item.enhance)>=10: return false
	var cost = C.upgrade_cost(int(item.enhance)+1)
	return game.profile.data.gold>=cost.gold and game.profile.data.material>=cost.material
func enhance_reason(item: Dictionary) -> String:
	if int(item.enhance)>=10: return "已达 +10 强化上限"
	if not editable(): return "战斗中不可强化，请在营地或安全整备操作。"
	var cost = C.upgrade_cost(int(item.enhance)+1)
	return "金币 %d / %d · 材料 %d / %d（持有 / 需要）%s"%[game.profile.data.gold,cost.gold,game.profile.data.material,cost.material," · 资源不足" if not can_enhance(item) else " · 必定成功"]
func show_forge(uid: String) -> void:
	selected_uid = uid
	var item: Dictionary = game.profile.item_by_id(uid)
	if item.is_empty(): show_equipment(); return
	page_start("铸造 · "+game.profile.item_name(item),"强化直接保存；演出不影响结果。连续操作间隔 0.45 秒。","forge")
	emblem(overlay,item,Rect2(215,355,325,325),true)
	label(overlay,"%s  +%d → +%d"%[C.QUALITIES[int(item.quality)],item.enhance,mini(10,int(item.enhance)+1)],Rect2(215,715,420,60),35,Look.QUALITY[int(item.quality)])
	var before: Dictionary = game.profile.item_stats(item)
	var preview: Dictionary = item.duplicate(true)
	preview.enhance = mini(10,int(item.enhance)+1)
	var after: Dictionary = game.profile.item_stats(preview)
	var lines: Array[String] = []
	for key in before: lines.append(C.stat_text(key,before[key])+"  →  "+C.stat_text(key,after[key]))
	label(overlay,"下级真实属性\n\n"+"\n".join(lines),Rect2(760,355,970,335),29)
	label(overlay,enhance_reason(item),Rect2(760,725,970,65),24,GOLD)
	button(overlay,"强化",Rect2(760,825,630,75),enhance_item.bind(uid)).disabled = not can_enhance(item)
	button(overlay,"返回装备",Rect2(1430,825,330,75),show_equipment)
func enhance_item(uid: String) -> void:
	var item: Dictionary = game.profile.item_by_id(uid)
	if forge_lock>0 or not can_enhance(item): return
	forge_lock = .45
	var old_rank = int(item.enhance)
	var before: Dictionary = game.profile.data.duplicate(true)
	var result: String = game.profile.enhance(uid)
	if not game.profile.save_profile():
		game.profile.data = before
		game.notify_player("保存失败，强化和费用已回滚。")
		return
	game.refresh_stats()
	var forge = page=="forge"
	if forge: show_forge(uid)
	else: show_equipment()
	var now: Dictionary = game.profile.item_by_id(uid)
	if int(now.enhance)>old_rank:
		growth("铸造成功  +%d → +%d"%[old_rank,now.enhance],result,Look.QUALITY[int(now.quality)])
		game.sound.play("forge")
func growth(title: String, detail: String, color: Color) -> void:
	clear_children(growth_panel)
	growth_clock = 1.3
	growth_panel.show()
	growth_panel.add_theme_stylebox_override("panel",style(Color("#173039"),color))
	label(growth_panel,title,Rect2(24,8,512,45),28,color)
	label(growth_panel,detail,Rect2(24,55,512,50),18)
func train_skill(slot: int) -> void:
	if not editable() or action_lock>0: return
	var previous = int(game.profile.data.roles[view_role].skills[slot])
	var before: Dictionary = game.profile.data.duplicate(true)
	var result: String = game.profile.train_skill(view_role,slot)
	if not game.profile.save_profile():
		game.profile.data = before
		game.notify_player("保存失败，升级已回滚。")
		return
	game.refresh_stats()
	show_talents()
	var now = int(game.profile.data.roles[view_role].skills[slot])
	if now>previous:
		action_lock = .22
		growth(C.SKILLS[view_role][slot].name+"  Lv.%d"%now,result,Look.ROLES[view_role].color)
		game.sound.play("train")
func train_passive(id: String) -> void:
	if not editable() or action_lock>0: return
	var before: Dictionary = game.profile.data.duplicate(true)
	var previous = int(game.profile.data.roles[view_role].talents.get(id,0))
	var result: String = game.profile.train(view_role,id)
	if not game.profile.save_profile():
		game.profile.data = before
		game.notify_player("保存失败，升级已回滚。")
		return
	game.refresh_stats()
	show_talents()
	if int(game.profile.data.roles[view_role].talents.get(id,0))>previous:
		action_lock = .22
		growth("天赋提升",result,Look.ROLES[view_role].color)
		game.sound.play("train")
func show_talents() -> void:
	super.show_talents()
	for child in overlay.get_children():
		if child is Label: child.text = child.text.replace("C 在角色",game.bindings.text("skill_4")+" 在角色")
	for child in overlay.get_children():
		if child is ScrollContainer:
			var rows = child.get_child(0)
			for i in range(mini(4,rows.get_child_count())):
				var r = rows.get_child(i)
				emblem(r,{"role":view_role,"slot":0,"quality":mini(3,int(game.profile.data.roles[view_role].skills[i])/3)},Rect2(14,8,42,42))
				for l in r.get_children():
					if l is Label and l.position.y==10: l.position.x=70; l.size.x=1150
				button(r,"效果预览",Rect2(1260,250,315,34),show_preview.bind(i))
			break
func bound_hint(text_value: String) -> String:
	var letters = ["E","Q","F","C"]
	var actions = ["skill","skill_2","skill_3","skill_4"]
	for i in range(4): text_value = text_value.replace(letters[i],"[%d]"%i)
	for i in range(4): text_value = text_value.replace("[%d]"%i,game.bindings.text(actions[i]))
	return text_value
func show_combos() -> void:
	super.show_combos()
	for child in overlay.get_children():
		if child is Label and child.text.begins_with("剑修：") or child is Label and child.text.begins_with("火枪手：") or child is Label and child.text.begins_with("游侠："):
			child.text = bound_hint(child.text)
func show_preview(slot: int) -> void:
	page_start(C.SKILLS[view_role][slot].name+" · 表现预览","仅播放表现层，不消耗资源、不造成伤害。实际机制以技能文字为准。","preview")
	var preview = preload("res://scripts/skill_preview.gd").new()
	preview.game = game
	preview.role = view_role
	preview.slot = slot
	preview.rank = int(game.profile.data.roles[view_role].skills[slot])
	preview.position = Vector2(950,570)
	overlay.add_child(preview)
	label(overlay,preload("res://scripts/skill_details.gd").effect(view_role,slot,preview.rank),Rect2(180,820,1540,90),25)
	button(overlay,"返回技能与天赋",Rect2(620,957,680,58),show_talents)
func show_settings(in_run: bool) -> void:
	super.show_settings(in_run)
	button(overlay,"画面与演出选项 →",Rect2(1050,850,700,65),show_visual_settings.bind(in_run))
func show_visual_settings(in_run: bool) -> void:
	page_start("画面与演出","显示档位只改变表现，不改变伤害、碰撞和掉落。","visual_settings")
	var names = ["减少动画与震动","背景视差","已观看的 Boss 入场自动跳过"]
	var keys = ["reduced_motion","menu_parallax","skip_boss_intro"]
	for i in range(3):
		var b = CheckButton.new()
		b.text = names[i]
		b.position = Vector2(180,330+i*95)
		b.size = Vector2(1550,70)
		b.button_pressed = game.get(keys[i])
		b.add_theme_font_override("font",font)
		b.add_theme_font_size_override("font_size",28)
		b.toggled.connect(func(v): game.set(keys[i],v); game.save_settings())
		overlay.add_child(b)
	label(overlay,"特效档位（粒子、残影与装饰光）",Rect2(180,648,1400,50),28)
	for i in range(3):
		button(overlay,["低 · 清晰","中 · 平衡","高 · 丰富"][i],Rect2(180+i*520,730,475,70),func(): game.effects_intensity=[.3,.65,1.0][i]; game.save_settings(); growth("画面选项已保存",["低","中","高"][i],GOLD))
	button(overlay,"← 返回设置",Rect2(180,900,600,65),show_settings.bind(in_run))
func _process(delta: float) -> void:
	super._process(delta)
	action_lock = maxf(0,action_lock-delta)
	forge_lock = maxf(0,forge_lock-delta)
	growth_clock = maxf(0,growth_clock-delta)
	if is_instance_valid(growth_panel):
		growth_panel.visible = growth_clock>0 and game.state!="cinematic"
		growth_panel.modulate.a = minf(1,growth_clock*4)
		growth_panel.position.y = 135-(0 if game.reduced_motion else maxf(0,growth_clock-1)*35)
	notification.visible = notification.visible and game.state in ["combat","menu","end"] and growth_clock<=0
	if is_instance_valid(game.player):
		var p = game.player
		for i in range(4):
			var mask = hud_masks[i]
			var l = skill_labels[i]
			var cd: float = p.skills.cooldowns[i]
			var fraction = clampf(cd/maxf(.1,C.SKILLS[p.stats.role][i].cd),0,1)
			mask.position = l.position+Vector2(0,l.size.y*(1-fraction))
			mask.size = Vector2(l.size.x,l.size.y*fraction)
			mask.visible = cd>0
			l.z_index = 2
		combo_hint.text = bound_hint(combo_hint.text)
		if p.stats.role==1 and game.state=="combat": detail_label.text += "  弹药 %d/%d"%[p.ammo,p.magazine_size()]
