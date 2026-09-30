extends "res://scripts/ui_v6.gd"
const V7 = preload("res://scripts/v7_catalog.gd")

func show_menu() -> void:
	super.show_menu()
	for child in overlay.get_children():
		if child is Label: child.text = child.text.replace("合刃同行  0.6.2","九流化境  0.7.0")

func show_rewards(choices: Array) -> void:
	var has_evolution = choices.any(func(choice): return choice[3]=="evolution")
	page_start("技能进化 · 三选一" if has_evolution else "清房馈赠 · 构筑进阶","技能进化会改变攻击行为并锁定该技能的互斥路线。" if has_evolution else "强化保留至本次章节挑战结束。","reward")
	hide_back()
	for i in range(choices.size()):
		var u: Array = choices[i]
		var c = Color(C.COLORS[int(u[6])])
		var x = 130+i*565
		box(overlay,Rect2(x,330,530,555),INK,Color(c,0.62))
		icon(overlay,Rect2(x+34,360,58,58),buff_icon(u[3]),c)
		label(overlay,"技能进化" if u[3]=="evolution" else ["普通","稀有","史诗"][int(u[6])],Rect2(x+115,368,345,36),23,c)
		label(overlay,u[1],Rect2(x+35,445,460,75),34)
		label(overlay,u[2],Rect2(x+35,535,455,145),23,MUTED)
		var state_text: String
		if u[3]=="evolution":
			var parsed = V7.parse_id(u[0])
			var current = game.player.skills.evolutions.get(str(parsed.get("slot",-1)),{})
			state_text = "当前：未定路线" if current.is_empty() else "当前：%s %d阶"%[V7.BUILD_NAMES[game.selected_role][int(current.branch)],int(current.tier)]
		else:
			state_text = "已获得 %d / %d 层 · 本局有效"%[game.player.stats.stacks.get(u[0],0),u[5]]
		label(overlay,state_text,Rect2(x+35,705,460,42),21,c)
		button(overlay,"选择进化 →" if u[3]=="evolution" else "选择强化 →",Rect2(x+35,790,460,62),game.choose_reward.bind(i),c)
	button(overlay,"重抽奖励 · 剩余 %d"%game.player.skills.rerolls,Rect2(130,925,420,55),game.reroll_rewards).disabled = game.player.skills.rerolls<=0
	button(overlay,"查看当前流派",Rect2(580,925,420,55),show_build_panel,Color("#85cfc2"))
	label(overlay,"%s · %s"%[game.flow.title(),game.player.skills.build_name()],Rect2(1040,935,750,42),24,GOLD)

func show_build_panel() -> void:
	page_start("本局流派构筑","技能路线互斥；同一列路线形成协同，但允许混搭。","v7_build")
	var skills = game.player.skills if is_instance_valid(game.player) else null
	if skills==null:
		label(overlay,"开始挑战后可在清房奖励中选择技能进化。",Rect2(180,380,1500,80),30,MUTED)
	else:
		label(overlay,"当前流派：%s    构筑标签：%s"%[skills.build_name()," / ".join(skills.build_tags()) if not skills.build_tags().is_empty() else "尚未形成"],Rect2(160,300,1600,55),29,GOLD)
		for slot in range(4):
			var y = 390+slot*135
			var selected = skills.branch(slot)
			var level = skills.tier(slot)
			var title = C.SKILLS[game.selected_role][slot].name
			var body = "尚未选择进化路线"
			var color = MUTED
			if selected>=0:
				var entry = V7.branch(game.selected_role,slot,selected)
				body = "%s · %s %d阶\n%s"%[V7.BUILD_NAMES[game.selected_role][selected],entry[3],level,entry[4][level-1]]
				color = Color(C.COLORS[mini(2,level-1)])
			box(overlay,Rect2(160,y,1600,112),INK,Color(color,0.45))
			label(overlay,C.SKILL_KEYS[slot]+" · "+title,Rect2(190,y+12,350,80),28,color)
			label(overlay,body,Rect2(540,y+12,1180,82),22)
	button(overlay,"返回",Rect2(620,940,680,58),func(): show_pause(true) if game.state=="paused" else show_characters())

func show_characters() -> void:
	super.show_characters()
	if is_instance_valid(game.player) and view_role==game.selected_role:
		button(overlay,"本局流派构筑",Rect2(1470,294,320,54),show_build_panel,Color("#85cfc2"))

func show_pause(stats_view: bool = false) -> void:
	super.show_pause(stats_view)
	button(overlay,"本局流派与进化",Rect2(560,865,800,65),show_build_panel,Color("#85cfc2"))

func codex_entries() -> Array:
	var entries = super.codex_entries()
	if codex_category==3:
		for entry in V7.BRANCHES:
			entries.append({"id":V7.evolution_id(entry[0],entry[1],entry[2],1),"name":entry[3]+" · "+V7.BUILD_NAMES[entry[0]][entry[2]],"text":"1阶：%s\n2阶：%s\n3阶：%s\n标签：%s"%[entry[4][0],entry[4][1],entry[4][2]," / ".join(V7.BUILD_TAGS[entry[0]][entry[2]])],"role":int(entry[0]),"quality":2,"hidden":false})
	elif codex_category==5:
		for modifier in V7.ELITE_MODIFIERS:
			entries.append({"id":"elite_"+modifier.id,"name":"精英词缀 · "+modifier.name,"text":modifier.text+"\n携带词缀的敌人会提供更高奖励，并拥有独立颜色标记。","role":-1,"quality":1,"hidden":false})
	elif codex_category==6:
		for objective in V7.ROOM_OBJECTIVES:
			entries.append({"id":"objective_"+objective.id,"name":"房间目标 · "+objective.name,"text":objective.text+"\n主要奖励："+objective.reward,"role":-1,"quality":1,"hidden":false})
	return entries

func page_start(title: String, subtitle: String, key: String) -> void:
	super.page_start(title,subtitle,key)
	for child in overlay.get_children():
		if child is Label: child.text = child.text.replace("第六版 · 合刃同行","第七版 · 九流化境")
