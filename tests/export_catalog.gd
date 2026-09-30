extends SceneTree
## Export human-readable configuration snapshots; does not load or change player saves.
const C = preload("res://scripts/catalog.gd")
const D = preload("res://scripts/data.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs"))
	var roles: Array = D.ROLES.duplicate(true)
	for role in roles: role.color = "#"+role.color.to_html(false)
	var sets: Array = []
	for role in range(3):
		sets.append({"role":role,"name":C.SETS[role],"pieces":C.NAMES[role],"bonuses":C.set_text(role),"legendary_weapon":C.special_text(role),"hidden_relic":C.special_text(role,true)})
	var snapshot = {"version":C.VERSION,"roles":roles,"chapters":C.CHAPTERS,"buffs":D.UPGRADES,"skills":C.SKILLS,"skill_unlock_levels":C.SKILL_LEVELS,"passives":C.PASSIVES,"sets":sets,"slots":C.SLOTS,"slot_base_stats":C.SLOT_STATS,"qualities":C.QUALITIES,"quality_colors":C.COLORS,"quality_scale":C.QUALITY_SCALE,"affixes":C.AFFIXES,"drop_chance":C.DROP_CHANCE,"drop_quality_weights":C.DROP_WEIGHTS,"consumables":C.ITEMS,"achievements":C.ACHIEVEMENTS,"enemies":C.ENEMIES,"enemy_descriptions":C.ENEMY_TEXT,"max_level":C.MAX_LEVEL,"max_enhance":C.MAX_ENHANCE,"inventory_capacity":C.CAPACITY}
	snapshot["pacing"] = C.PACING
	snapshot["difficulty"] = C.DIFFICULTY
	snapshot["enemy_limit"] = C.ENEMY_LIMIT
	snapshot["spawn_interval"] = C.SPAWN_INTERVAL
	var file = FileAccess.open("res://docs/catalog_v2.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot,"  "))
	file.close()
	var lines = PackedStringArray(["# 三途试炼 · 局内强化表","","本表由 `scripts/data.gd` 导出。每个非章节终结波三选一；随机强化只在本次章节挑战内有效。立即治疗不提供持续属性。","","| 稳定 ID | 名称 | 效果 | 适用角色 | 品质 | 层数上限 |","| --- | --- | --- | --- | --- | --- |"])
	for buff in D.UPGRADES:
		lines.append("| %s | %s | %s | %s | %s | %d |"%[buff[0],buff[1],buff[2],"通用" if int(buff[7])<0 else D.ROLES[int(buff[7])].name,C.QUALITIES[int(buff[6])],buff[5]])
	lines.append("\n基础抽取权重为普通 6、稀有 3、史诗 1；当前角色专属权重乘 1.3；回合末稀有与史诗条目再乘 1.4。总体概率随可选池变化。排除同屏重复、已满层和不适用角色条目；满血时不提供立即治疗。有效池不足三项时用 40 金币补给补齐。\n\n属性页显示已选强化的层数、来源和累计收益。套装、等级、天赋属于永久来源，单独显示。修改中文名称不会改变存档中的稳定 ID。")
	file = FileAccess.open("res://UPGRADES.md",FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("EXPORTED docs/catalog_v2.json and UPGRADES.md")
	quit()
