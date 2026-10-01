extends SceneTree

const Progression = preload("res://scripts/buff_progression.gd")
const Stats = preload("res://scripts/stats.gd")
const Data = preload("res://scripts/data.gd")
var game
var checks: int = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label_text: String) -> void:
	checks += 1
	if not ok:
		failures.append(label_text)
		push_error(label_text)

func has_text(node: Node, fragment: String) -> bool:
	if node is Label and node.text.contains(fragment): return true
	for child in node.get_children():
		if has_text(child,fragment): return true
	return false

func run() -> void:
	check(Progression.tier(2)==0,"two stacks remain dormant")
	check(Progression.tier(3)==1,"three stacks unlock basic enhancement")
	check(Progression.tier(5)==2,"five stacks unlock added mechanic")
	check(Progression.tier(10)==3,"ten stacks unlock form change")
	check(Progression.tier(20)==4,"twenty stacks unlock advanced change")
	check(Progression.tier(100)==4,"physical mechanic tier remains bounded")
	check(Progression.power_nodes(20)==4 and Progression.power_nodes(30)==5 and Progression.power_nodes(50)==7,"post twenty cycles add safe power nodes")
	check(Progression.next_milestone(0)==3 and Progression.next_milestone(3)==5,"early next milestones are exposed")
	check(Progression.next_milestone(20)==30 and Progression.next_milestone(30)==40,"endless next milestones continue")
	check(Progression.crossed(2,10)==[3,5,10],"multi-layer grants report every crossed milestone")
	check(Progression.stage_name(3)=="基础强化" and Progression.stage_name(10)=="形态变化","stage names communicate behavior")
	check(Progression.stage_name(30).contains("循环突破"),"post cap stage communicates cyclic breakthrough")
	check(Progression.description("attack").contains("3 / 5 / 10 / 20"),"codex description documents revised cadence")
	var stats = Stats.new(0)
	stats.abyss = true
	var upgrade: Array = Data.UPGRADES.filter(func(u): return u[3]=="attack" and int(u[7]) in [-1,0])[0]
	for i in range(29): stats.apply(upgrade)
	var overflow_before = stats.overflow_power()
	stats.apply(upgrade)
	check(stats.overflow_power()>=overflow_before+0.099,"thirty-stack breakthrough increases bounded power")
	check(stats.eligible(upgrade),"buff remains eligible after advanced change")

	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.profile.data.unlocked = 6
	game.profile.data.cleared = [1,2,3,4,5,6]
	game.start_run(0,8500,6)
	game.flow.abyss = true
	game.player.stats.abyss = true
	game.player.stats.apply(upgrade)
	game.player.stats.apply(upgrade)
	game.state = "reward"
	game.rewards = [upgrade]
	game.choose_reward(0)
	check(int(game.player.stats.stacks[upgrade[0]])>=3,"reward choice reaches first milestone")
	check(game.banner.contains("基础强化"),"milestone receives center-screen feedback")
	check(game.profile.events.any(func(event): return str(event.title).contains("Buff 进阶") and str(event.text).contains("3 层")),"milestone is recorded in event log")
	game.state = "reward"
	game.ui.show_rewards([upgrade,upgrade,upgrade])
	check(has_text(game.ui.overlay,"下一进阶 5 层"),"reward UI exposes next milestone")
	game.state = "paused"
	game.ui.show_characters()
	check(has_text(game.ui.overlay,"基础强化 · 下一进阶 5 层"),"attribute page exposes active stage and target")

	var report = {"checks":checks,"failures":failures}
	var file = FileAccess.open("res://tests/regression_abyss_v8_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("ABYSS_V8_REGRESSION="+JSON.stringify(report))
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
