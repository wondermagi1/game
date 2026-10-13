extends SceneTree
var game
var checks: int = 0
var failures: Array = []
var capture: bool = false
const Western = preload("res://scripts/western_art.gd")
func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note); push_error(note)
func settle() -> void:
	for i in range(8): await process_frame
func shot(id: String) -> void:
	if not capture: return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots-western/"+id+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots-western"))
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	root.size = Vector2i(1920,1080)
	game.sound.volume = 0
	await settle()
	await shot("01-menu")
	for cell in range(16):
		var frame = Western.hero_frame(Western.MONSTER_PATH,cell)
		check(frame.bands.size()>20,"monster %d has an isolated silhouette"%cell)
		check(Western.hero_mesh(Western.MONSTER_PATH,cell).get_surface_count()==1,"monster %d render mesh loads"%cell)
	for cell in range(12):
		check(Western.hero_mesh(Western.PROP_PATH,cell).get_surface_count()==1,"prop %d isolated from atlas neighbours"%cell)
	for key in game.sound.BANK:
		check(game.sound.curated.has(key) and not game.sound.curated[key].is_empty(),"sound routed: "+key)
		for clip in game.sound.curated[key]: check(clip.get_length()>0 and clip.get_length()<1,"short finite audio: "+key)
	game.sound.volume = .1
	game.sound.play("bow")
	check(game.sound.played_keys.get("bow",0)==1,"bow invokes physical recording")
	game.sound.play("hit_metal")
	game.sound.play("hit_flesh")
	check(game.sound.played_keys.get("hit_metal",0)+game.sound.played_keys.get("hit_flesh",0)==1,"shared impact cooldown prevents pileup")
	game.sound.stop_all()
	check(not game.sound.foley.any(func(v): return v.playing),"pause stop silences all curated voices")
	game.sound.volume = 0
	game.sound.play("gun")
	check(game.sound.played_keys.get("gun",0)==0,"volume zero prevents new shots")
	game.profile.data.unlocked = 6
	for role in range(3):
		game.profile.data.roles[role].level = 30
		game.profile.data.roles[role].skills = [10,10,10,10]
	for chapter in range(1,7):
		game.profile.data.checkpoint = {}
		game.profile.data.exploration = {}
		game.start_run((chapter-1)%3,10400+chapter,chapter)
		game.pending.clear()
		game.banner_time = 0
		game.player.manual_control = true
		game.player.invulnerable = 0
		game.player.global_position = game.rooms.origin()+Vector2(960,690)
		var room = game.rooms.scene
		check(room.scene_background.resource_path.contains("western"),"chapter %d uses western background"%chapter)
		var kinds = [0,3,2,9] if chapter==1 else ([15,16,17,18] if chapter==2 else [4,5,10,13])
		for i in range(kinds.size()):
			var enemy=game.spawn_enemy(kinds[i],game.rooms.origin()+room.safe(Vector2(520+i*290,440)),false)
			enemy.set_physics_process(false)
		await shot("%02d-chapter-%d"%[chapter+1,chapter])
		if chapter==3:
			room.clue = true
			room.event_name = "古代宝箱"
			game.rooms.current().event = "chest"
			room.queue_redraw()
			await shot("08-chest-runes-walls")
			room.event_used = true
			room.queue_redraw()
			await shot("09-opened-chest")
	game.profile.data.exploration = {}
	game.start_run(0,10713,3)
	game.rooms.current().layout = "lanes"
	game.rooms.enter("r0")
	game.pending.clear()
	game.banner_time = 0
	game.player.manual_control = true
	game.player.invulnerable = 0
	check(game.rooms.scene.obstacles.size()==2,"painted lane walls preserve two original collision rectangles")
	game.rooms.scene.set_clear(false)
	await shot("10-painted-walls-locked-gate")
	game.rooms.scene.set_clear(true)
	await shot("11-painted-walls-open-gate")
	game.free()
	await process_frame
	var report={"checks":checks,"failures":failures}
	FileAccess.open("res://tests/western_2d_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WESTERN_2D_REGRESSION="+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
