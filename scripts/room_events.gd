extends RefCounted
## Concrete choices; all events are optional and once per stable room ID.
static func options(kind: String, game) -> Array:
	var chapter: int = game.stage
	match kind:
		"merchant": return [{"name":"旅途补给","text":"永久获得治疗药剂 ×3、时砂 ×1。无战斗风险。","cost":90,"effect":"supplies"},{"name":"职业装备","text":"永久获得当前角色可装备的史诗装备 1 件。","cost":160+chapter*20,"effect":"gear"},{"name":"材料补给","text":"永久获得 12 份强化材料。","cost":100,"effect":"material"}]
		"altar": return [{"name":"锋芒铭刻","text":"本局攻击 +18%。免费，无风险。","cost":0,"effect":"attack"},{"name":"灵流铭刻","text":"本局技能冷却缩减 +12%。免费。","cost":0,"effect":"cooldown"},{"name":"护身铭刻","text":"本局最大生命 +50，并恢复 50 生命。","cost":0,"effect":"vital"}]
		"chest": return [{"name":"开启古代宝箱","text":"永久获得职业史诗装备 1 件、金币 220、材料 8、探索经验。免费，无风险。","cost":0,"effect":"chest"}]
		"fountain": return [{"name":"泉水祝福","text":"恢复 65% 最大生命，本局移动速度 +30；获得探索经验。免费。","cost":0,"effect":"heal"}]
		"forge": return [{"name":"淬炼武器","text":"已装备武器永久强化 +1（最高 +10，满级则获得 12 材料），免费。","cost":0,"effect":"enhance"},{"name":"携走材料","text":"永久获得 12 强化材料与 180 金币。免费。","cost":0,"effect":"forge"}]
	return [{"name":"领悟绝艺","text":"本局 C 技能临时 +2 级（最高 10）；角色达到 15 级才可使用 C。免费。","cost":0,"effect":"mastery"},{"name":"旅者赠礼","text":"永久获得职业史诗装备一件与探索经验。免费。","cost":0,"effect":"gear"},{"name":"历练传承","text":"额外获得本章探索经验的三倍，永久生效。免费。","cost":0,"effect":"xp"}]
static func apply(run, choice: Dictionary) -> void:
	var g = run.game
	var p = g.player
	var xp: int = 100+g.stage*80
	match choice.effect:
		"supplies":
			for pair in [["potion",3],["sand",1]]: g.profile.data.consumables[pair[0]]=int(g.profile.data.consumables.get(pair[0],0))+pair[1]
		"gear", "chest":
			g.receive_gear(g.profile.make_item(g.selected_role,run.reward_rng.randi_range(0,5),3 if g.stage>=5 and run.reward_rng.randf()<0.3 else 2,mini(int(g.profile.data.roles[g.selected_role].level),g.Catalog.CHAPTERS[g.stage-1].level),run.reward_rng))
			if choice.effect=="chest": run.grant(220,0,8)
		"material": run.grant(0,0,12)
		"attack": p.stats.bonuses.attack_pct = float(p.stats.bonuses.get("attack_pct",0))+0.18
		"cooldown": p.stats.bonuses.cooldown = float(p.stats.bonuses.get("cooldown",0))+0.12
		"vital": p.stats.bonuses.hp = float(p.stats.bonuses.get("hp",0))+50; p.heal(50)
		"heal": p.heal(p.stats.value("hp")*0.65); p.stats.bonuses.speed = float(p.stats.bonuses.get("speed",0))+30
		"enhance":
			var item = g.profile.item_by_id(g.profile.data.roles[g.selected_role].equipped.get("0",""))
			if item.is_empty() or int(item.enhance)>=10: run.grant(0,0,12)
			else:
				item.enhance += 1
				if int(item.enhance)==10: g.profile.unlock("enhance10")
				g.refresh_stats()
		"forge": run.grant(180,0,12)
		"mastery": p.skills.temporary[3] = mini(9,int(p.skills.temporary[3])+2)
		"xp": xp *= 4
	run.grant(0,xp,0)
