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
	for tier in range(1,4):
		var parsed = V7.parse_id(V7.evolution_id(2,3,1,tier))
		check(parsed.role==2 and parsed.slot==3 and parsed.branch==1 and parsed.tier==tier,"evolution ids round trip tier %d"%tier)

	var chapter_two = Graph.generate(2,70702)
	check(Graph.reachable(chapter_two),"chapter two sample graph is fully reachable")
	check(chapter_two.get("sample",false),"chapter two uses authored sample route")
	check(chapter_two.rooms.r1.neighbors.size()==3,"first battle presents safe and elite route choices")
	check(chapter_two.rooms.cross.neighbors.has("shop") and chapter_two.rooms.cross.neighbors.has("hunt"),"second fork presents shop and hunt")
	check(chapter_two.rooms.cross.objective=="defend" and chapter_two.rooms.hunt.objective=="hunt","sample route assigns objective rooms")
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

	var report = {"checks":checks,"failures":failures}
	var file = FileAccess.open("res://tests/regression_v7_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("V7_REGRESSION="+JSON.stringify(report))
	game.free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
