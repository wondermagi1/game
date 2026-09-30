extends "res://scripts/ui_v3.gd"
var minimap
var combo_hint: Label
func _ready() -> void:
	super._ready()
	health.add_theme_stylebox_override("fill",style(Color("#7acdb4")))
	health.add_theme_stylebox_override("background",style(Color("#263442")))
	minimap = preload("res://scripts/exploration_map.gd").new()
	minimap.game = game
	minimap.position = Vector2(1510,300)
	minimap.size = Vector2(345,168)
	add_child(minimap)
	combo_hint = label(self,"",Rect2(580,858,780,42),22,Color("#c8e9df"))
	combo_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	super._process(delta)
	toast.visible = game.state in ["combat","menu","end"]
	if not is_instance_valid(combo_hint): return
	combo_hint.visible = game.state=="combat"
	if not is_instance_valid(game.player): return
	var s = game.player.skills
	combo_hint.text = ""
	if s.ultimate.active: combo_hint.text = ["归宗持续：F 发动横向剑潮（每次一次）","重火力持续：F 装填衔接强化普攻","狩猎持续：E 发动逐日终结（每次一次）"][game.selected_role]
	elif s.windows[1]>0 and game.selected_role==0: combo_hint.text = "剑印窗口：C 可发动穿云归宗"
	elif s.windows[2]>0 and game.selected_role==2: combo_hint.text = "猎印窗口：C 可发动群星狩猎"
	if game.rooms.active:
		var r: Dictionary = game.rooms.current()
		stage_label.text = "%s · %s"%[game.flow.title(),game.rooms.Graph.NAMES[r.kind]]
		detail_label.text = "%s  敌人 %d  金币 %d  %02d:%02d"%["出口已开启" if r.cleared else "遭遇 %d/%d"%[game.rooms.waves_done,r.waves],game.enemies.size()+game.pending.size(),game.profile.data.gold,floori(game.elapsed/60),int(game.elapsed)%60]
		if r.cleared and combo_hint.text.is_empty(): combo_hint.text = "靠近中央 %s 交互 / 安全整备 · 走向出口探索 · %s 地图"%[game.bindings.text("interact"),game.bindings.text("map")]
func show_menu() -> void:
	super.show_menu()
	for child in overlay.get_children():
		if child is Label:
			child.text = child.text.replace("第三版","第四版").replace("深渊回响","星途远征").replace("V0.3","V0.4").replace("从每波抉择中构筑力量，让战利品成为下一次远征的起点。","探索房间、发现奇遇；更快养成，让终极技能照亮新的远征。")
	if not game.profile.data.exploration.is_empty():
		button(overlay,"继续探索存档",Rect2(1050,835,350,64),func(): game.rooms.resume(),Color("#7bd5ba"))
		button(overlay,"放弃探索存档…",Rect2(1430,835,350,64),confirm_exploration_abandon)
func confirm_exploration_abandon() -> void:
	page_start("放弃探索存档？","保留永久装备、等级和金币；清除本局房间和 Buff 进度。","abandon_exploration")
	button(overlay,"保留存档",Rect2(260,490,610,80),show_menu)
	button(overlay,"确认放弃本局",Rect2(1000,490,610,80),func(): game.rooms.abandon(); show_menu(),Color("#dc8f91"))
func show_chapters() -> void:
	page_start("选择远征","房间探索替代旧回合刷怪；难度固定，不随装备追涨。可选支路带来额外奖励。","chapters")
	for i in range(6):
		var c: Dictionary = C.CHAPTERS[i]
		var x = 130+(i%3)*560
		var y = 315+floori(i/3.0)*245
		box(overlay,Rect2(x,y,525,220),INK,Color(c.color))
		label(overlay,"%02d %s"%[i+1,c.name],Rect2(x+20,y+10,485,45),30,Color(c.color))
		label(overlay,"%s 个房间 · 推荐 Lv.%d\n主路 / 可选精英 / 奇遇 / 首领"%[["4","6","9","9–10","9–10","9–10"][i],c.level],Rect2(x+20,y+60,485,94),22)
		var b = button(overlay,"进入远征" if i<int(game.profile.data.unlocked) else "完成前章后解锁",Rect2(x+20,y+163,485,44),start_chapter.bind(i+1),Color(c.color))
		b.disabled = i>=int(game.profile.data.unlocked)
	button(overlay,"无尽深渊 →" if game.abyss.unlocked() else "无尽深渊 · 完成第六章解锁",Rect2(130,845,1660,65),func(): game.abyss.start(view_role)).disabled = not game.abyss.unlocked()
	label(overlay,"后期首领传奇保底：%d / 3 次未出；达到 3 后，下次第 5–6 章首领主掉落必为传奇。"%int(game.profile.data.legend_misses),Rect2(130,945,1660,65),23,GOLD)

func show_intermission() -> void:
	if not game.rooms.active: super.show_intermission(); return
	view_role = game.selected_role
	page_start("安全房间整备","仅已清理房间可整备和保存；保存包含路线、宝箱、事件及已售库存。","intermission")
	hide_back()
	label(overlay,"%s · %s\n金币 %d · 材料 %d · Lv.%d · 可用点数 %d"%[game.flow.title(),game.rooms.Graph.NAMES[game.rooms.current().kind],game.profile.data.gold,game.profile.data.material,game.profile.data.roles[view_role].level,game.profile.talent_points(view_role)],Rect2(150,305,1650,120),31,GOLD)
	var actions = [["装备与强化",show_equipment],["技能与天赋",show_talents],["补给商店",show_shop],["战斗道具",show_consumables],["属性与 Buff",show_characters],["图鉴",show_codex]]
	for i in range(actions.size()): button(overlay,actions[i][0],Rect2(150+(i%2)*830,475+floori(i/2.0)*85,790,65),actions[i][1])
	button(overlay,"保存探索并退出",Rect2(150,790,790,72),func(): game.rooms.save_exit())
	button(overlay,"继续探索 →",Rect2(980,790,790,72),game.next_round,Color("#77d5c0"))
	if game.rooms.current().id in ["elite","cache","secret"]:
		button(overlay,"使用捷径返回分叉房间",Rect2(150,895,1620,62),game.rooms.return_to_branch)
	else: label(overlay,"战斗中退出会结束本局。已清理房间回访不重复刷怪或发奖。",Rect2(150,900,1600,50),23,MUTED)
func show_room_event(kind: String, options: Array) -> void:
	page_start(game.rooms.Graph.EVENT_NAMES.get(kind,"奇遇"),"每个事件本局只能选择一次。永久成长与本局强化分别标明。","room_event")
	hide_back()
	for i in range(options.size()):
		var choice: Dictionary = options[i]
		box(overlay,Rect2(170,320+i*185,1580,155),INK,GOLD)
		label(overlay,choice.name+" · "+("免费" if choice.cost==0 else "%d 金币"%choice.cost),Rect2(200,337+i*185,1180,40),29,GOLD)
		label(overlay,choice.text,Rect2(200,395+i*185,1160,60),24)
		button(overlay,"选择",Rect2(1410,365+i*185,295,65),game.rooms.choose_event.bind(i)).disabled = int(game.profile.data.gold)<int(choice.cost)
	button(overlay,"暂时离开，稍后再来",Rect2(170,930,1580,65),func(): game.state="combat"; clear_overlay())
func show_first_clear(items: Array) -> void:
	page_start("章节首通 · 定向战利品","三选一，保证当前角色可装备。领取后完成章节结算。","first_clear")
	hide_back()
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var x = 130+i*565
		box(overlay,Rect2(x,330,530,530),INK,Color(C.COLORS[int(item.quality)]))
		label(overlay,C.QUALITIES[item.quality]+" · "+game.profile.item_name(item),Rect2(x+30,380,470,65),31,GOLD)
		label(overlay,"当前角色 · Lv.%d · 套装部件\n永久获得，可在主菜单装备强化。"%item.level,Rect2(x+30,505,465,150),26)
		button(overlay,"领取并结算",Rect2(x+30,750,470,65),game.rooms.claim_first_clear.bind(i))
func show_world_map() -> void:
	page_start("远征地图","亮框为当前房间。支路自选，首领始终沿主路可达。未发现的秘密房不显示。","world_map")
	var map = preload("res://scripts/exploration_map.gd").new()
	map.game = game
	map.expanded = true
	map.position = Vector2(160,300)
	map.size = Vector2(1590,565)
	overlay.add_child(map)
	button(overlay,"回到探索",Rect2(160,900,1590,65),game.resume_game)
func show_rewards(choices: Array) -> void:
	super.show_rewards(choices)
	if game.rooms.active:
		for child in overlay.get_children():
			if child is Label:
				child.text = child.text.replace("选择本波的馈赠","清房馈赠 · 构筑进阶").replace("回合末提高稀有强化权重。","本次增加 %d 层（主线上限内），本局有效。"%game.rooms.reward_layers)
				if child.position.y==945: child.text = "清房经验、金币与材料已获得；选择一次强化即可继续探索。"
				if child.position.y==710:
					var index = clampi(int((child.position.x-165)/565),0,choices.size()-1)
					var u: Array=choices[index]
					var previous=int(game.player.stats.stacks.get(u[0],0))
					var added=mini(game.rooms.reward_layers,maxi(0,int(u[5])-previous))
					child.text="本次 +%d 层 → 累计 %d / %d · 本局有效"%[added,previous+added,u[5]]
func show_talents() -> void:
	page_start("技能与天赋","每级 +2 点；Lv.5–30 每5级另 +2 点。C 在角色15级解锁，25级开放技能10级。","talents")
	role_tabs()
	var progress: Dictionary = game.profile.data.roles[view_role]
	var available: int = game.profile.talent_points(view_role)
	label(overlay,"Lv.%d · 可用 %d / 累计 %d 点"%[progress.level,available,C.earned_points(int(progress.level))],Rect2(1000,295,750,45),27,GOLD)
	if is_instance_valid(game.player) and game.selected_role==view_role and game.state!="menu":
		label(overlay,"本局临时技能：E +%d / Q +%d / F +%d / C +%d（有效等级最高10，解锁门槛保持）"%game.player.skills.temporary,Rect2(130,345,1660,26),18,MUTED)
	var rows = list_area(Rect2(130,375,1660,530))
	var details = preload("res://scripts/skill_details.gd")
	for i in range(4):
		var rank = int(progress.skills[i])
		var skill: Dictionary = C.SKILLS[view_role][i]
		var r = row(rows,290,1610)
		var required = maxi(C.SKILL_LEVELS[i],C.SKILL_REQUIREMENTS[mini(9,rank)])
		var cost = C.SKILL_COSTS[mini(9,rank)]
		label(r,"%s %s · Lv.%d/10 · 解锁 Lv.%d · 冷却 %.0fs"%[game.bindings.text(["skill","skill_2","skill_3","skill_4"][i]),skill.name,rank,C.SKILL_LEVELS[i],skill.cd],Rect2(25,10,1200,40),27,GOLD)
		var text = "当前："+details.effect(view_role,i,rank)
		text += "\n下级："+details.effect(view_role,i,rank+1) if rank<10 else "\n已达到满级。"
		text += "\n"+details.milestones(view_role,i)
		label(r,text,Rect2(25,60,1180,210),20)
		var reason = "满级" if rank>=10 else ("需角色 Lv.%d"%required if int(progress.level)<required else ("需 %d 点，现有 %d"%[cost,available] if available<cost else "升级 · %d 点"%cost))
		var b = button(r,reason,Rect2(1250,90,330,65),train_skill.bind(i))
		b.disabled = not editable() or rank>=10 or int(progress.level)<required or available<cost
		label(r,"下一等级：角色 Lv.%d\n费用 %d 点 · 可用 %d"%[required,cost,available],Rect2(1250,175,330,75),21,MUTED)
	for t in C.PASSIVES:
		var r = row(rows,105,1610)
		label(r,"%s · %s %d/%d\n%s"%[t.branch,t.name,progress.talents.get(t.id,0),t.max,t.text],Rect2(25,10,1190,85),24)
		button(r,"投入 1 点",Rect2(1280,24,295,56),train_passive.bind(t.id)).disabled = not editable() or available<1 or int(progress.talents.get(t.id,0))>=t.max
	button(overlay,"重置天赋（首次免费，其后120金币）",Rect2(130,964,1120,62),reset_training).disabled = not editable()
	button(overlay,"查看组合说明",Rect2(1310,964,480,62),show_combos)

func show_combos() -> void:
	page_start("技能连携","窗口 8 秒或持续技能期间；满足条件必定触发。追加来源不递归。","combos")
	var texts = ["剑修：Q → 普攻，剑印追击；E → F，回锋剑潮。\nQ 后 8 秒内 C：穿云归宗，终结 +35%；E 中 C：剑阵护卫追击。\nC 持续中 F：归宗回锋，300% 攻击横向剑潮并调整终结落点，每次 C 一次。","火枪手：E → F 强化弹：200% 爆燃；Q → 普攻 / C：霰幕连爆。\nF 强化状态中 C：持续重火力 +25%，终结 +35%。\nC 起手 → 有效目标重火力压制 → 终结爆破；不增加装饰弹的逻辑命中。","游侠：F → E，240% 猎日星坠；Q → 普攻，弹射 +2 与伤害 +25%。\nF 后 8 秒内 C：群星狩猎，追击 +25%、终结 +35%；Q 后 C：五次 80% 风暴箭域。\nC 中 E：额外 450% 巨型贯穿箭，每次 C 一次。"]
	for i in range(3):
		box(overlay,Rect2(130,305+i*220,1660,195),INK,Data.ROLES[i].color)
		label(overlay,texts[i],Rect2(155,320+i*220,1600,170),23)
func codex_entries() -> Array:
	var entries = super.codex_entries()
	for entry in entries:
		entry.text = entry.text.replace("角色 60 级最多获得 59 点","角色 60 级累计获得 130 点").replace("30+15×目标强化等级²","25+9×目标强化等级²")
		if entry.id=="hidden_gate": entry.text = "第三章第二处主路房间北墙有三道亮纹。靠近后交互三次开启秘密支路，在封印处主动挑战镜渊守望者。旧收集记录保留。"
	if codex_category==3:
		for entry in entries:
			var parts = str(entry.id).split("_")
			var role = int(parts[1])
			var slot = int(parts[2])
			entry.text = preload("res://scripts/skill_details.gd").effect(role,slot,1)+"\n满级："+preload("res://scripts/skill_details.gd").effect(role,slot,10)+"\n"+preload("res://scripts/skill_details.gd").milestones(role,slot)+"\n角色 Lv.%d 解锁；25级可升至10级。"%C.SKILL_LEVELS[slot]
	if codex_category==6:
		for entry in entries:
			if entry.id.begins_with("chapter_"): entry.text = "沿主路探索房间，出口在战斗结束后开启。可选精英、奇遇及秘密支路。\n普通遭遇 1 波，精英 2 波；首领独立战斗。靠近中央 G 交互，安全房间 G 整备，M 地图。\n安全整备可保存探索；继续存档会先消耗旧检查点。"
		for kind in game.rooms.Graph.EVENTS:
			var descriptions: Array = []
			for choice in preload("res://scripts/room_events.gd").options(kind,game): descriptions.append(choice.name+"："+choice.text+" 费用 %d 金币"%choice.cost)
			entries.append({"id":"event_"+kind,"name":game.rooms.Graph.EVENT_NAMES[kind],"text":"\n".join(descriptions)+"\n本局每个房间只能选择一次，回访不重置。","role":-1,"quality":-1,"hidden":false})
	if codex_category==1:
		entries.append({"id":"drop_rules","name":"掉落与传奇保底","text":"装备掉率：普通 7%，精英 40%，首领 100%。普通/精英装备 90% 为当前角色，首领主掉落保证当前角色。\n第5–6章条件品质（普通/稀有/史诗/传奇）：普通怪 10/40/40/10；精英 0/25/50/25；首领 0/0/60/40。\n后期首领主掉落连续三次非传奇，下次必传奇；其他来源不清空计数。当前 %d / 3。"%int(game.profile.data.legend_misses),"role":-1,"quality":-1,"hidden":false})
	return entries

func page_start(title: String, subtitle: String, key: String) -> void:
	super.page_start(title,subtitle,key)
	for child in overlay.get_children():
		if child is Label: child.text = child.text.replace("THREEFOLD TRIAL / 第三版","THREEFOLD TRIAL / 第四版")

func show_characters() -> void:
	super.show_characters()
	if not game.rooms.active or view_role!=game.selected_role: return
	for child in overlay.get_children():
		if child is ScrollContainer:
			var rows = child.get_child(0)
			for boon in game.rooms.data.get("boons",[]):
				var entry = row(rows,95,1610)
				label(entry,"奇遇增益 · "+str(boon),Rect2(25,10,1530,75),23,GOLD)
			break
