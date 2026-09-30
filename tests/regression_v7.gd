extends SceneTree

const V7 = preload("res://scripts/v7_catalog.gd")
const Graph = preload("res://scripts/room_graph.gd")
const C = preload("res://scripts/catalog.gd")

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	check(V7.BRANCHES.size()==36,"three roles expose 36 skill evolution branches")
	check(V7.BUILD_NAMES.size()==3,"three role build catalogs")
	for role in range(3):
		check(V7.BUILD_NAMES[role].size()==3,"role %d has three coherent builds"%role)
		for slot in range(4):
			for branch in range(3):
				var entry = V7.branch(role,slot,branch)
				check(entry.size()==5 and entry[4].size()==3,"role %d skill %d branch %d has three tiers"%[role,slot,branch])
	check(V7.ELITE_MODIFIERS.size()==6,"six elite modifiers")
	check(V7.ROOM_OBJECTIVES.size()==3,"three room objectives")
	check(V7.GEAR_MECHANICS.size()==3 and V7.GEAR_MECHANICS.all(func(role): return role.size()==3),"nine build-linked equipment mechanics")
	for tier in range(1,4):
		var parsed = V7.parse_id(V7.evolution_id(2,3,1,tier))
		check(parsed.role==2 and parsed.slot==3 and parsed.branch==1 and parsed.tier==tier,"evolution ids round trip tier %d"%tier)

	var chapter_two = Graph.generate(2,70702)
	check(Graph.reachable(chapter_two),"chapter two sample graph is fully reachable")
	check(chapter_two.get("sample",false),"chapter two uses authored sample route")
	check(chapter_two.rooms.r1.neighbors.size()==3,"first battle presents safe and elite route choices")
	check(chapter_two.rooms.cross.neighbors.has("shop") and chapter_two.rooms.cross.neighbors.has("hunt") and chapter_two.rooms.cross.neighbors.has("seal"),"second fork presents shop, hunt and seal")
	check(chapter_two.rooms.cross.objective=="defend" and chapter_two.rooms.hunt.objective=="hunt" and chapter_two.rooms.seal.objective=="seal","sample route assigns all objective rooms")
	for id in chapter_two.rooms:
		var room: Dictionary = chapter_two.rooms[id]
		check(room.has("danger") and room.has("reward_hint") and room.has("enemy_hint"),"room %s exposes route information"%id)

	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	check(int(game.profile.data.version)>=5,"profile migrated to version 5")
	check(game.profile.data.has("v7_migrated") and game.profile.data.has("chapter_pity") and game.profile.data.has("camp_dialogue"),"v7 profile fields are additive")
	check(C.ENEMIES.size()>=19,"catalog exposes four new normal enemies")
	game.profile.data.roles[0].level = 30
	var epic = game.profile.make_item(0,2,2,10,game.rng)
	epic.mechanic = V7.gear_mechanic(0,1).id
	epic.build_branch = 1
	check(game.profile.receive_item(epic) and game.profile.equip(0,epic.uid)=="已装备","epic mechanic item can be received and equipped")
	check(game.profile.permanent_bonuses(0).get("gear_branch_1",0)>=1,"equipped mechanic exposes its build hook")
	game.profile.data.chapter_pity["0_2"] = 7
	var pity_drop = game.profile.roll_equipment(0,0,2,game.rng)
	check(not pity_drop.is_empty() and pity_drop.quality>=1 and pity_drop.drop_source=="章节保底","chapter pity guarantees a rare targeted drop")
	check(pity_drop.slot==(2+0)%6 and int(game.profile.data.chapter_pity["0_2"])==0,"pity drop uses deterministic chapter slot and resets counter")

	game.profile.data.unlocked = 6
	game.profile.data.roles[0].level = 30
	game.profile.data.roles[0].skills = [10,10,10,10]
	game.start_run(0,70703,2)
	await process_frame
	var skills = game.player.skills
	check(skills.rerolls==2 and skills.evolutions.is_empty(),"new run starts with two rerolls and no locked path")
	var choices = skills.evolution_choices(game.rng)
	check(choices.size()==3 and choices.all(func(c): return c[3]=="evolution"),"evolution reward produces three choices")
	check(skills.apply_evolution(V7.evolution_id(0,0,1,1)),"first evolution tier applies")
	check(skills.branch(0)==1 and skills.tier(0)==1,"selected branch is stored")
	check(not skills.apply_evolution(V7.evolution_id(0,0,2,2)),"mutually exclusive branch cannot replace selected path")
	check(skills.apply_evolution(V7.evolution_id(0,0,1,2)),"matching second tier applies")
	check(skills.apply_evolution(V7.evolution_id(0,0,1,3)),"matching third tier applies")
	check(not skills.apply_evolution(V7.evolution_id(0,0,1,3)),"maximum tier cannot be repeated")
	check(skills.build_name()==V7.BUILD_NAMES[0][1],"dominant branch determines build name")
	check(not skills.build_tags().is_empty(),"formed build exposes tags")
	var enhanced = skills.enhance_rewards(game.player.stats.reward_choices(game.rng,game.player.hp,false),game.rng,true)
	check(enhanced.size()==3 and enhanced.count(enhanced[0])>=1,"forced reward keeps three-card contract")
	check(enhanced.filter(func(c): return c[3]=="evolution").size()>=1,"elite reward protects an evolution choice")

	game.rooms.enter("cross","r1")
	check(game.rooms.objective_state.id=="defend" and game.rooms.objective_text().contains("灵石坚守"),"defend objective starts with visible status")
	game.rooms.objective_state.time = 0.01
	game.rooms.tick(0.02)
	check(game.rooms.current().cleared and game.state=="reward","defend timer completes the room")
	game.choose_reward(0)
	game.rooms.enter("hunt","cross")
	for i in range(12): game.rooms.tick(0.4)
	check(is_instance_valid(game.rooms.objective_target) and game.rooms.objective_target.hunt_stacks==3,"hunt target receives three visible marks")
	game.rooms.objective_target.dead = true
	game.rooms.tick(0.1)
	check(game.rooms.current().cleared and game.state=="reward","defeating hunt target completes the room")
	game.choose_reward(0)
	game.rooms.enter("seal","cross")
	check(game.rooms.objective_state.id=="seal" and game.rooms.objective_state.points.size()==3,"seal objective creates three capture points")
	for point in game.rooms.objective_state.points.duplicate():
		game.player.global_position = point
		game.rooms.tick(1.7)
	game.rooms.tick(0.1)
	check(game.rooms.current().cleared and game.state=="reward","capturing all seal points completes the room")

	game.telemetry.record_damage(120,"skill_3",true)
	game.telemetry.damage_taken += 20
	game.telemetry.healing += 8
	var telemetry_copy = game.telemetry.snapshot()
	check(game.telemetry.damage_lines(3).size()>=1 and game.telemetry.critical_hits>=1,"telemetry summarizes damage and critical hits")
	game.telemetry.reset()
	game.telemetry.restore(telemetry_copy)
	check(game.telemetry.damage_taken>=20 and game.telemetry.healing>=8 and game.telemetry.rooms.size()>=3,"telemetry snapshot restores route and survival data")

	var report = {"checks":checks,"failures":failures}
	var file = FileAccess.open("res://tests/regression_v7_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("V7_REGRESSION="+JSON.stringify(report))
	game.free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
