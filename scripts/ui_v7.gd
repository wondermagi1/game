extends "res://scripts/ui_v6.gd"
const V7 = preload("res://scripts/v7_catalog.gd")
const Graph = preload("res://scripts/room_graph.gd")
var combo_pulse: float=0

func show_menu() -> void:
	super.show_menu()
	for child in overlay.get_children():
		if child is Label: child.text = child.text.replace("合刃同行  0.6.2","灵境重铸  0.8.0").replace("九流化境  0.7.0","灵境重铸  0.8.0")
	box(overlay,Rect2(1050,120,715,70),Color("#10232d"),Color("#6d8d86"))
	label(overlay,V7.CAMP_NPC+"："+camp_story_line(),Rect2(1070,130,675,50),17,Color("#c8e5d9"))

func _process(delta: float) -> void:
	super._process(delta)
	combo_pulse+=delta
	if game.state=="combat" and game.rooms.active and not game.rooms.objective_state.is_empty() and not game.rooms.objective_state.get("done",false):
		detail_label.text += "  ·  "+game.rooms.objective_text()
	if game.state=="combat" and is_instance_valid(game.player) and game.selected_role==1 and game.player.skills.dominant_branch()==0:
		detail_label.text += "  ·  热量 %d%%"%roundi(game.player.skills.heat)
	if game.state=="combat" and is_instance_valid(game.player) and is_instance_valid(combo_hint):
		var status=game.player.skills.combo_status()
		if not status.is_empty():
			var time_text=" · %.1fs"%float(status.time) if float(status.time)>0 else ""
			combo_hint.text=("连携就绪 · " if status.ready else "连携提示 · ")+str(status.title)+"｜"+bound_hint(str(status.hint))+time_text
			combo_hint.add_theme_color_override("font_color",Color("#fff0a8") if status.ready else Color("#9fc8c1"))
			combo_hint.modulate.a=.82+.18*sin(combo_pulse*7) if status.ready and not game.reduced_motion else 1.0

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
			var count = int(game.player.stats.stacks.get(u[0],0))
			state_text = "已获得 %d 层 · %s"%[count,Evo.progress_text(count)] if game.flow.abyss else "已获得 %d / %d 层 · 本局有效"%[count,u[5]]
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
		if game.player.stats.abyss:
			for child in buff_bar.get_children():
				if not child is Button: continue
				var buff_name = child.text.get_slice(" ×",0)
				for u in Data.UPGRADES:
					if u[1]!=buff_name: continue
					var count = int(game.player.stats.stacks.get(u[0],0))
					child.tooltip_text = u[2]+"\n"+Evo.progress_text(count)+" · 深渊无限叠加"
					break

func render_item_detail() -> void:
	super.render_item_detail()
	var item: Dictionary = game.profile.item_by_id(selected_uid)
	if item.is_empty() or not item.has("mechanic"): return
	var mechanic = V7.gear_mechanic(int(item.role),int(item.get("build_branch",int(item.slot)%3)))
	for child in inventory_detail.get_children():
		if child is Label and child.position.y==297:
			child.text = "构筑机制 · %s\n%s\n标签：%s"%[mechanic.name,mechanic.text," / ".join(V7.BUILD_TAGS[int(item.role)][int(item.get("build_branch",0))])]
			child.add_theme_font_size_override("font_size",17)

func show_pause(stats_view: bool = false) -> void:
	super.show_pause(stats_view)
	button(overlay,"本局流派与进化",Rect2(560,865,800,65),show_build_panel,Color("#85cfc2"))

func show_end(victory: bool) -> void:
	super.show_end(victory)
	if game.stage==2:
		for child in overlay.get_children():
			if child is Label and child.position.y==215:
				child.text = (V7.CHAPTER_TWO_ROLE_LINES[game.selected_role]+"  督军倒下时，战旗指向裂隙要塞。") if victory else "砚秋：记住战旗抬起后的停顿。火种会等你再来。"
	button(overlay,"查看详细战报",Rect2(760,795,400,55),show_run_report,Color("#85cfc2"))

func camp_story_line() -> String:
	var flags: Dictionary = game.profile.data.camp_dialogue
	if flags.get("secret",false): return V7.CAMP_LINES.secret
	if flags.get("chapter2_cleared",false): return V7.CAMP_LINES.cleared
	if flags.get("chapter2_failed",false): return V7.CAMP_LINES.failed
	if flags.get("chapter2_entered",false): return V7.CAMP_LINES.entered
	return V7.CAMP_LINES.new

func show_run_report() -> void:
	game.notice_clock = 0
	if is_instance_valid(notification): notification.hide()
	page_start("本局战报 · 构筑复盘","伤害占比、路线和选择记录只用于帮助判断构筑，不影响掉落。","run_report")
	var t = game.telemetry
	var damage_lines = t.damage_lines(7)
	var route_names: Array[String] = []
	if game.rooms.data.has("rooms"):
		for id in t.rooms:
			if game.rooms.data.rooms.has(id): route_names.append(Graph.NAMES[game.rooms.data.rooms[id].kind])
	var enemy_lines: Array[String] = []
	for key in t.kills_by_kind:
		var kind = int(key)
		if kind>=0 and kind<C.ENEMIES.size(): enemy_lines.append("%s ×%d"%[C.ENEMIES[kind],t.kills_by_kind[key]])
	box(overlay,Rect2(120,300,535,570),INK,Color("#4b6878"))
	box(overlay,Rect2(690,300,535,570),INK,Color("#75668f"))
	box(overlay,Rect2(1260,300,535,570),INK,Color("#806653"))
	label(overlay,"伤害构成",Rect2(155,330,460,48),31,Color("#91ddcf"))
	label(overlay,"\n".join(damage_lines) if not damage_lines.is_empty() else "尚无有效伤害记录",Rect2(155,400,460,350),23)
	label(overlay,"命中 %d · 暴击 %d · 最高 %.0f\n连携 %d · 闪避 %d · 承伤 %.0f · 治疗 %.0f"%[t.hits,t.critical_hits,t.highest_hit,game.player.skills.combo_count if is_instance_valid(game.player) else 0,t.dodges,t.damage_taken,t.healing],Rect2(155,750,460,85),20,GOLD)
	label(overlay,"敌群与路线",Rect2(725,330,460,48),31,Color("#c5a8ed"))
	label(overlay,"精英击破 %d · 首领击破 %d\n\n%s"%[t.elite_kills,t.boss_kills,"\n".join(enemy_lines.slice(0,9)) if not enemy_lines.is_empty() else "尚无击破记录"],Rect2(725,400,460,310),22)
	label(overlay,"路线：%s"%(" → ".join(route_names) if not route_names.is_empty() else "传统关卡"),Rect2(725,735,460,100),20,GOLD)
	label(overlay,"构筑与收益",Rect2(1295,330,460,48),31,Color("#efc67b"))
	var reward_text = "\n".join(t.rewards.slice(-10)) if not t.rewards.is_empty() else "尚未选择局内奖励"
	label(overlay,"%s\n%s\n\n%s"%[game.player.skills.build_name() if is_instance_valid(game.player) else "未成型",(" / ".join(game.player.skills.build_tags()) if is_instance_valid(game.player) and not game.player.skills.build_tags().is_empty() else "无构筑标签"),reward_text],Rect2(1295,400,460,330),22)
	label(overlay,"重抽 %d · 装备 %d\n%s\n%s"%[t.rerolls,t.gear_found,"失败原因："+t.failure_reason if not game.won and not t.failure_reason.is_empty() else "",report_advice()],Rect2(1295,735,460,115),19,GOLD)
	button(overlay,"返回结算",Rect2(620,930,680,62),show_end.bind(game.won))

func report_advice() -> String:
	var t = game.telemetry
	if t.damage_taken>game.player.stats.value("hp")*2.2: return "建议：补充防御、移速或控制路线。"
	if game.player.skills.evolutions.size()<2: return "建议：优先让两项核心技能完成路线进化。"
	if t.damage_lines(2).size()>=2: return "构筑已经形成双核心，可继续强化主伤害来源。"
	return "尝试让普攻与技能围绕同一套构筑标签联动。"

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
		if child is Label: child.text = child.text.replace("第六版 · 合刃同行","第八版 · 灵境重铸").replace("第七版 · 九流化境","第八版 · 灵境重铸")
