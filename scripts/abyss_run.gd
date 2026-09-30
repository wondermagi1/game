extends RefCounted
## A checkpoint and permanent rewards share one checksummed profile transaction.
var game
func unlocked() -> bool:
	return game.profile.data.cleared.has(6)
func start(role: int, seed_value: int = -1) -> void:
	if not unlocked(): return
	if not game.profile.data.checkpoint.is_empty() or not game.profile.data.exploration.is_empty():
		game.notify_player("已有深渊存档，请继续或明确放弃后再开始。")
		return
	game.start_run(role,seed_value,6)
	game.rooms.stop()
	game.flow.abyss = true
	game.flow.run_id = "%d-%d"%[Time.get_ticks_usec(),game.run_seed]
	game.player.stats.abyss = true
	game.begin_stage()
func scaling() -> Dictionary:
	var floor_id: float = game.flow.floor_number
	# Independent of player gear. Continuous, finite growth; never raise entity caps.
	return {"hp":minf(1.0e12,0.45+0.045*floor_id+0.0025*pow(floor_id,1.7)),"damage":minf(1.0e8,0.6+0.022*floor_id+0.0004*pow(floor_id,1.5))}
func cleared() -> void:
	var floor_id: int = game.flow.floor_number
	var role: int = game.selected_role
	game.profile.data.abyss_best[role] = maxi(int(game.profile.data.abyss_best[role]),floor_id)
	game.profile.discover("mode_abyss")
	if floor_id>=10: game.profile.unlock("abyss10")
	if floor_id>=30: game.profile.unlock("abyss30")
	game.profile.dirty = true
	game.state = "reward"
	game.rewards = game.player.stats.reward_choices(game.rng,game.player.hp,true)
	game.ui.show_rewards(game.rewards)
func after_reward() -> void:
	if game.flow.floor_number%5==0:
		var slot = game.rng.randi_range(0,3)
		game.player.skills.temporary[slot] = mini(9,int(game.player.skills.temporary[slot])+1)
		game.profile.events.append({"title":"深渊技能领悟","text":game.Catalog.SKILLS[game.selected_role][slot].name+" 本次深渊等级 +1（有效上限 10）"})
		game.state = "intermission"
		game.ensure_shop()
		game.ui.show_intermission()
	else: next_floor()
func next_floor() -> void:
	game.flow.floor_number += 1
	game.flow.stock.clear()
	game.state = "combat"
	game.ui.clear_overlay()
	game.begin_stage()
	# Once-per-run revive remains used. Rest heals only every fifth cleared floor.
	if (game.flow.floor_number-1)%5==0: game.player.heal(game.player.stats.value("hp")*0.25)
func checkpoint() -> Dictionary:
	var p = game.player
	return {"version":1,"id":game.flow.run_id,"cleared":game.flow.floor_number,"next":game.flow.floor_number+1,"role":game.selected_role,"hp":p.hp,"seed":game.run_seed,"rng":str(game.rng.state),"bonuses":p.stats.bonuses.duplicate(true),"stacks":p.stats.stacks.duplicate(true),"temporary":p.skills.temporary.duplicate(),"revive_used":p.revive_used,"stock":game.flow.stock.duplicate(true),"elapsed":game.elapsed,"kills":game.kills,"gold":game.earned_gold,"xp":game.earned_xp,"gear":game.earned_gear,"reward_claimed":true,"item_clocks":p.item_clocks.duplicate(),"barrier":p.barrier,"barrier_time":p.barrier_time}
func save_exit() -> bool:
	if not game.flow.abyss or game.state!="intermission" or game.flow.floor_number%5!=0: return false
	var old: Dictionary = game.profile.data.checkpoint.duplicate(true)
	game.profile.data.checkpoint = checkpoint()
	if not game.profile.save_profile():
		game.profile.data.checkpoint = old
		game.notify_player("保存失败，仍停留在整备点。"+game.profile.notice,8)
		return false
	game.state = "menu"
	game.reset_entities()
	game.ui.show_menu()
	return true
func valid(c: Dictionary) -> bool:
	if int(c.get("version",0))!=1 or not c.get("reward_claimed",false): return false
	for key in ["id","rng"]:
		if not c.get(key) is String: return false
	for key in ["bonuses","stacks","item_clocks"]:
		if not c.get(key) is Dictionary: return false
	if not c.get("stock") is Array or not c.get("temporary") is Array or c.temporary.size()!=4: return false
	if int(c.get("cleared",0))<5 or int(c.cleared)%5!=0 or int(c.get("next",0))!=int(c.cleared)+1: return false
	if int(c.get("role",-1)) not in [0,1,2] or float(c.get("hp",0))<=0: return false
	return true
func resume() -> bool:
	var c: Dictionary = game.profile.data.checkpoint.duplicate(true)
	if not valid(c):
		game.notify_player("深渊存档不完整或版本不兼容，已保留原文件。",8)
		return false
	# Consume before exposing any resumable state; a force-quit cannot replay rewards.
	game.profile.data.checkpoint = {}
	if not game.profile.save_profile():
		game.profile.data.checkpoint = c
		game.notify_player("无法保存续行记录，暂不能继续。",8)
		return false
	game.start_run(int(c.role),int(c.seed),6)
	game.rooms.stop()
	game.flow.abyss = true
	game.flow.run_id = c.id
	game.flow.floor_number = int(c.cleared)
	game.flow.wave = 1
	game.flow.stock = c.stock
	game.player.stats.abyss = true
	game.player.stats.bonuses = c.bonuses
	game.player.stats.stacks = c.stacks
	game.player.skills.temporary = c.temporary
	game.player.hp = minf(float(c.hp),game.player.stats.value("hp"))
	game.player.revive_used = c.revive_used
	game.player.item_clocks = c.item_clocks
	game.player.barrier = float(c.barrier)
	game.player.barrier_time = float(c.barrier_time)
	game.elapsed = c.elapsed
	game.kills = int(c.kills)
	game.earned_gold = int(c.gold)
	game.earned_xp = int(c.xp)
	game.earned_gear = int(c.gear)
	game.rng.state = int(c.rng)
	game.rooms.abyss_room(int(c.cleared))
	game.state = "intermission"
	game.director.reset()
	game.ui.show_intermission()
	return true
func abandon() -> bool:
	var old: Dictionary = game.profile.data.checkpoint
	game.profile.data.checkpoint = {}
	if not game.profile.save_profile():
		game.profile.data.checkpoint = old
		return false
	return true
