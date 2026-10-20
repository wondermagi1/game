extends Node
const C = preload("res://scripts/td/catalog.gd")
const Atlas = preload("res://art/td/facilities.png")
var game
var ui
var status: Label
var energy_label: Label
const GOLD = Color("#dec48c")
const WHITE = Color("#e7edf3")
const MUTED = Color("#a9bdc9")

func _ready() -> void:
	ui = game.ui
	process_priority = 20

func reset() -> void:
	ui.clear_overlay()
	status = null
	energy_label = null

func text(value: String, rect: Rect2, size: int = 23, color: Color = WHITE) -> Label:
	return ui.label(ui.overlay,value,rect,size,color)

func action(value: String, rect: Rect2, callback: Callable, enabled: bool = true) -> Button:
	var button = ui.button(ui.overlay,value,rect,callback,GOLD)
	button.add_theme_font_size_override("font_size",21)
	button.disabled = not enabled
	return button

func backdrop() -> void:
	ui.shade()
	# Shared scenic background stays visible, but body text needs contrast.
	var veil = ColorRect.new()
	veil.color = Color(0.025,0.045,0.065,0.53)
	veil.size = Vector2(1920,1080)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.overlay.add_child(veil)

func icon(id: int, rect: Rect2) -> void:
	var region = AtlasTexture.new()
	region.atlas = Atlas
	region.region = C.REGIONS[id]
	var node = TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture = region
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.overlay.add_child(node)

func show_select() -> void:
	game.state = "menu"
	reset()
	ui.hud.hide()
	backdrop()
	text("R E L I C   D E F E N S E",Rect2(125,90,1500,45),22,GOLD)
	text("遗迹守卫",Rect2(120,145,1500,85),60)
	text("以角色迎战，以设施布防。守住两波，或追加第三波精英挑战。",Rect2(125,240,1600,55),27,MUTED)
	for role in range(3):
		var x = 125+role*560
		ui.box(ui.overlay,Rect2(x,345,525,390),Color("#142633"),Color("#45606a"))
		ui.portrait(ui.overlay,role,Vector2(x+105,550),1.35)
		text(game.Data.ROLES[role].name,Rect2(x+245,390,260,60),35,GOLD)
		text(game.Data.ROLES[role].tag,Rect2(x+245,470,245,100),22)
		var id = role
		action("选择角色 · 开始布防",Rect2(x+35,640,455,60),func(): game.start_defense(id))
	text("12种设施 · 10个建造位 · Ⅰ—Ⅳ级成长\n同类设施可重复建造。消耗本局灵能升级；重复蓝图可免费建造或升级一级。",Rect2(125,770,1630,100),26)
	text("继承已有装备、等级和技能。原探索存档保留；守卫战本身不提供中途存档。",Rect2(125,895,1450,50),22,MUTED)
	action("返回营地",Rect2(1530,975,270,60),game.back_to_menu)

func shell(title: String) -> void:
	reset()
	ui.hud.visible = game.state in ["combat","paused"]
	if game.state=="td_build":
		ui.box(ui.overlay,Rect2(50,35,1320,100),Color("#10222c"),Color("#40545d"))
		text(title,Rect2(80,48,900,42),31,GOLD)
		text("点击编号建造位 → 选设施 → 建造；点击已有设施升级。",Rect2(80,92,1210,30),21,MUTED)
	var panel = ui.box(ui.overlay,Rect2(1425,160,450,790),Color("#10232f"),Color("#516977"))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	text(title,Rect2(1450,180,400,45),29,GOLD)
	energy_label = text("",Rect2(1450,230,400,40),24)
	status = text("",Rect2(1450,275,400,45),21,MUTED)

func show_build() -> void:
	shell("布防阶段 · 第 %d 波准备"%(game.defense_wave+1))
	for i in range(game.PADS.size()):
		var slot = i
		var tower = game.tower_at(i)
		var label_value = str(i+1) if tower==null else C.ROMAN[tower.rank-1]
		var button = action(label_value,Rect2(game.PADS[i]-Vector2(29,20),Vector2(58,48)),func(): game.selected_pad=slot; show_build())
		button.modulate.a = 0.9 if i==game.selected_pad else 0.7
		button.tooltip_text = "建造位 %d"%(i+1) if tower==null else C.definition(tower.kind).name+" · "+C.ROMAN[tower.rank-1]
	var selected = game.tower_at(game.selected_pad)
	if selected==null:
		for id in range(12):
			var kind = id
			var definition = C.definition(id)
			var row = floori(id/2.0)
			var column = id%2
			var blueprint_count = int(game.blueprints.get(id,0))
			var label_value = "%s  %d"%[definition.name,game.price(id)]
			if blueprint_count>0: label_value += " ★"
			var button = action(label_value,Rect2(1447+column*205,335+row*49,195,42),func(): game.selected_kind=kind; show_build())
			button.add_theme_font_size_override("font_size",18)
			button.tooltip_text = definition.tag+"\n"+definition.steps[3]
			if game.selected_kind==id: button.modulate = Color("#b4e6da")
		var kind: int = game.selected_kind
		var definition = C.definition(kind)
		icon(kind,Rect2(1450,644,100,94))
		text(definition.name+" · "+definition.tag,Rect2(1555,650,280,65),21,GOLD)
		text("射程 %d · %s"%[C.reach(kind,1),definition.steps[0]],Rect2(1450,745,400,65),21)
		action("建造 · %d 灵能"%game.price(kind),Rect2(1450,825,400,48),func(): game.build_facility(game.selected_pad,kind),game.energy>=game.price(kind))
		action("使用蓝图 · 免费建造",Rect2(1450,885,400,45),func(): game.build_facility(game.selected_pad,kind,true),game.blueprints.get(kind,0)>0)
	else:
		var definition = C.definition(selected.kind)
		icon(selected.kind,Rect2(1545,325,205,180))
		text(definition.name+"  "+C.ROMAN[selected.rank-1],Rect2(1450,510,400,45),30,GOLD)
		text("射程 %d  /  基础伤害 %.0f\n攻击或触发间隔 %.2f 秒"%[selected.reach(),C.damage(selected.kind,selected.rank),C.interval(selected.kind,selected.rank)],Rect2(1450,565,400,70),21)
		text("当前："+definition.steps[selected.rank-1]+("\n下一级："+definition.steps[selected.rank] if selected.rank<4 else "\n已达最高Ⅳ级"),Rect2(1450,650,400,110),22)
		var cap: bool = selected.rank>=4
		var cost: int = game.price(selected.kind,selected.rank)
		action("已达Ⅳ级上限" if cap else "升级 · %d 灵能"%cost,Rect2(1450,775,400,45),func(): game.upgrade_facility(game.selected_pad),not cap and game.energy>=cost)
		action("使用同类蓝图 · 升一级",Rect2(1450,830,400,45),func(): game.upgrade_facility(game.selected_pad,true),not cap and game.blueprints.get(selected.kind,0)>0)
		action("拆除 · 返还 %d 灵能"%floori(selected.invested*0.7),Rect2(1450,885,400,45),func(): game.sell_facility(game.selected_pad))
	text("下一波：%d名敌人 · 双路进攻%s\n波间全设施修复；角色恢复25%%生命。"%[C.wave_plan(game.defense_wave+1).size()," · 含精英" if game.defense_wave==2 else ""],Rect2(80,965,760,84),23)
	action("修复核心 · 25",Rect2(860,985,245,60),game.repair_core,game.core_hp<100 and game.energy>=25)
	action("开始守卫",Rect2(1120,985,250,60),game.start_wave,not game.facilities.is_empty())
	action("离开守卫战",Rect2(1450,985,400,60),show_leave)

func show_combat() -> void:
	shell("守卫中 · 第 %d 波"%game.defense_wave)
	text("阻止敌人沿双路抵达核心。\n角色倒下或核心归零即结束。\n95秒后余敌将直接冲击核心。",Rect2(1450,350,395,120),22)
	text("WASD 移动 · 鼠标左键普攻\n空格闪避 · E / Q / F / C 技能\n道具和改键沿用原有设置。",Rect2(1450,500,395,130),22,MUTED)
	text("每击杀获得灵能。\n设施在波间建造、升级、拆除。\n守住两波即可领取奖励，\n第三波为自选精英挑战。",Rect2(1450,685,395,150),22)
	action("暂停 / Esc",Rect2(1450,870,400,52),game.pause_game)

func show_blueprints() -> void:
	reset()
	backdrop()
	text("第 %d 波守住了"%game.cleared_waves,Rect2(150,150,1600,85),48,GOLD)
	text("选择一份设施蓝图。可以免费建造一座Ⅰ级设施，或让同类设施升一级（最高Ⅳ级）。",Rect2(150,255,1600,80),26)
	for i in range(game.blueprint_offer.size()):
		var kind: int = game.blueprint_offer[i]
		var x = 150+i*555
		ui.box(ui.overlay,Rect2(x,390,515,450),Color("#162938"),Color("#547078"))
		icon(kind,Rect2(x+145,410,225,200))
		text(C.definition(kind).name,Rect2(x+35,630,445,55),34,GOLD)
		text(C.definition(kind).tag,Rect2(x+35,690,445,50),23)
		action("选择这份蓝图",Rect2(x+35,765,445,55),func(): game.choose_blueprint(kind))
	text("已获得波次灵能，可在下一布防阶段使用。未使用蓝图保留至本局结束。",Rect2(150,900,1600,55),24,MUTED)

func show_choice() -> void:
	reset()
	backdrop()
	text("基础守卫完成",Rect2(200,190,1450,95),52,GOLD)
	text("现在领取：180金币 + 200经验 + 1件稀有装备\n或再守一波：总计420金币 + 300经验 + 1件史诗装备。",Rect2(200,350,1460,150),32)
	text("追加挑战有32名敌人，其中4名精英。失败仍保留已守住两波的基础奖励。\n现有设施和蓝图继续保留，开始前还能布防、修复核心。",Rect2(200,560,1450,125),27,MUTED)
	action("领取奖励 · 结束守卫",Rect2(220,790,680,75),game.collect_defense_reward)
	action("追加精英波 · 继续布防",Rect2(1010,790,680,75),game.accept_challenge)

func show_pause() -> void:
	reset()
	backdrop()
	text("守卫已暂停",Rect2(550,270,850,90),50,GOLD)
	action("继续守卫",Rect2(660,450,600,65),game.resume_game)
	action("离开本局",Rect2(660,550,600,65),show_leave)

func show_leave() -> void:
	reset()
	backdrop()
	text("离开会放弃未结算的守卫战奖励。\n原探索与深渊存档不受影响。",Rect2(420,340,1080,150),32)
	action("继续守卫",Rect2(450,590,475,65),func():
		if game.state=="paused": game.resume_game()
		else: show_build())
	action("确认返回营地",Rect2(995,590,475,65),game.back_to_menu)

func show_result() -> void:
	reset()
	backdrop()
	text(game.result_text,Rect2(200,170,1500,95),54,GOLD)
	text("守住 %d 波  ·  击杀 %d  ·  漏怪 %d  ·  用时 %02d:%02d"%[game.cleared_waves,game.kills,game.leaks,int(game.elapsed)/60,int(game.elapsed)%60],Rect2(200,315,1500,70),30)
	text("已入库：%d金币  /  %d经验  /  %d件装备"%[game.earned_gold,game.earned_xp,game.earned_gear],Rect2(200,440,1500,70),32,GOLD)
	text("设施、灵能和蓝图属于本局。金币、经验和装备已保存到原有角色档案。",Rect2(200,575,1500,70),26,MUTED)
	action("同角色再战",Rect2(220,785,680,75),func(): game.start_defense(game.selected_role))
	action("返回营地 · 查看装备",Rect2(1010,785,680,75),game.back_to_menu)

func _process(_delta: float) -> void:
	if is_instance_valid(energy_label): energy_label.text = "灵能 %d    核心 %d / 100"%[game.energy,game.core_hp]
	if is_instance_valid(status):
		status.text = "场上 %d · 待出场 %d · 剩余 %ds"%[game.enemies.size(),game.wave_queue.size(),maxi(0,ceili(95-game.wave_time))] if game.state=="combat" else "已建 %d / 10 · 同类可重复建造"%game.facilities.size()
	if game.state=="combat":
		ui.stage_label.text = "遗迹守卫 · 第 %d 波"%game.defense_wave
		ui.detail_label.text = "守护核心 %d%% · 击杀 %d · 灵能 %d"%[game.core_hp,game.kills,game.energy]
