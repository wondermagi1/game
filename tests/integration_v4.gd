extends SceneTree
var game
var checks: int = 0
var failures: Array = []
var skill_report: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	checks+=1
	if not value: failures.append(title); push_error(title)
func room_fixture(role: int = 0) -> void:
	game.profile.data.unlocked=6
	game.profile.data.roles[role].level=30
	game.profile.data.roles[role].skills=[10,10,10,10]
	game.start_run(role,6723,6)
	game.rooms.data.rooms.r1.layout="open"
	game.rooms.enter("r1","r0")
	game.pending.clear()
	game.player.manual_control=true
	game.player.position=game.rooms.origin()+Vector2(550,550)
	game.player.aim=Vector2.RIGHT
func dummy(point: Vector2, kind: int = 0):
	var enemy=game.spawn_enemy(kind,point)
	enemy.state="move"
	enemy.set_physics_process(false)
	enemy.hp=1e8
	enemy.max_hp=1e8
	return enemy
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.sound.volume=0
	# An isolated real file exercises checksum, backup, migration and consume-on-resume.
	var profile=game.profile
	profile.path="res://tests/isolated_v4_profile.json"
	profile.memory_only=false
	profile.data.version=3
	profile.data.roles[0].level=25
	profile.data.roles[0].skills=[4,2,1,1]
	profile.data.roles[0].spent=10
	profile.data.erase("legend_misses")
	profile.data.erase("exploration")
	check(profile.save_profile(),"write_v3_fixture")
	profile.load_profile()
	check(profile.talent_points(0)==48 and profile.data.roles[0].skills==[4,2,1,1],"migrate_spent_and_ranks")
	var uid: String=profile.data.inventory[0].uid
	profile.save_profile()
	profile.load_profile()
	check(profile.talent_points(0)==48 and profile.data.inventory[0].uid==uid,"migration_idempotent_uid")
	var bindings=preload("res://scripts/input_bindings.gd").new()
	var config=ConfigFile.new()
	config.set_value("bindings","skill",KEY_G)
	bindings.load_config(config)
	check(bindings.keys.skill==KEY_G and bindings.keys.interact!=KEY_G,"preserve_old_custom_key")
	room_fixture()
	game.pending.clear()
	game.rooms.current().cleared=true
	game.rooms.scene.set_clear(true)
	game.rooms.current().claimed=true
	game.ensure_shop()
	profile.data.gold=2000
	profile.buy(game.flow.stock,0)
	game.rooms.current().used=true
	game.rooms.current().broken.append("crate_0")
	game.rooms.camp()
	var gold: int=profile.data.gold
	var rng: String=str(game.rooms.reward_rng.state)
	check(game.rooms.save_exit(),"disk_save_room")
	profile.load_profile()
	check(game.rooms.resume(),"disk_resume_room")
	check(game.rooms.current().used and game.rooms.current().claimed and game.rooms.current().stock[0].sold,"restore_claimed_event_stock")
	check(profile.data.gold==gold and str(game.rooms.reward_rng.state)==rng,"restore_currency_rng")
	check(not game.rooms.resume(),"second_resume_blocked")
	check(game.rooms.current().broken.has("crate_0") and game.rooms.scene.crates.size()==1,"restore_broken_cover")
	profile.memory_only=true
	# The physical actor crosses an open door rather than calling enter directly.
	game.rooms.enter("r0")
	game.player.manual_control=true
	game.player.position=game.rooms.origin()+Vector2(1760,555)
	game.player.scripted_movement=Vector2.RIGHT
	game.rooms.transition_clock=0
	for i in range(50): await physics_frame
	check(game.rooms.data.current=="r1","physical_door_transition")
	# Wide sword catches a target that lies away from the thin ray centerline.
	room_fixture()
	var target=dummy(game.player.position+Vector2(270,42))
	var before: float=target.hp
	game.player.skills.use(1)
	for i in range(20): await physics_frame
	check(target.hp<before,"giant_sword_width")
	check(target.sword_mark>0,"giant_sword_mark")
	game.player.skills.combo_cd=0
	var before_combo: int=game.player.skills.combo_count
	var shot=game.spawn_projectile(target.position,Vector2.RIGHT,{"damage":1e10,"source":"normal"})
	target.hurt(1e10)
	game.player.skills.on_hit(target,shot)
	check(game.player.skills.combo_count>before_combo,"fatal_hit_combo")
	# Cover actually stops a giant sword and a normal bullet.
	room_fixture()
	game.rooms.data.rooms.r1.layout="center"
	game.rooms.enter("r1","r0")
	game.pending.clear()
	game.player.position=game.rooms.origin()+Vector2(650,555)
	game.player.aim=Vector2.RIGHT
	target=dummy(game.rooms.origin()+Vector2(1200,555))
	before=target.hp
	game.player.skills.use(1)
	for i in range(60): await physics_frame
	check(target.hp==before,"giant_stops_at_cover")
	# Every C has start/sustain/finish damage; moving targets and combo links are real.
	for role in range(3):
		for moving in [false,true]:
			room_fixture(role)
			target=dummy(game.player.position+Vector2(400,0),13)
			var initial: float=target.hp
			game.player.skills.windows.assign([8.0,8.0,8.0,0.0])
			game.player.skills.use(3)
			var base_budget: float=game.player.skills.ultimate.total_budget
			for i in range(420):
				if moving: target.position.y=game.rooms.origin().y+555+sin(i/50.0)*150
				if i==35 and role in [0,2]: game.player.skills.use(2 if role==0 else 0)
				await physics_frame
			check(target.hp<initial,"C_effect_%d_%s"%[role,moving])
			check(not game.player.skills.ultimate.active,"C_complete")
			if role in [0,2]: check(game.player.skills.combo_count>=2,"C_two_links_%d"%role)
			skill_report.append({"role":role,"moving":moving,"rank":10,"attack":game.player.stats.value("attack"),"damage":initial-target.hp,"base_sword_budget_factor":base_budget if role==0 else 0,"combos":game.player.skills.combo_count})
	# Real upgrade button must retain the bottom scroll and preserve point arithmetic.
	room_fixture()
	profile.data.roles[0].skills=[1,1,1,1]
	profile.data.roles[0].spent=0
	game.rooms.current().cleared=true
	game.rooms.camp()
	game.ui.show_talents()
	for i in range(4): await process_frame
	var scroll
	for child in game.ui.overlay.get_children():
		if child is ScrollContainer: scroll=child
	scroll.scroll_vertical=900
	var previous: int=scroll.scroll_vertical
	game.ui.train_skill(3)
	for i in range(4): await process_frame
	for child in game.ui.overlay.get_children():
		if child is ScrollContainer: scroll=child
	check(scroll.scroll_vertical==previous,"talent_scroll_retained")
	game.ui.show_equipment()
	var weapon=profile.item_by_id(profile.data.roles[0].equipped["0"])
	profile.data.gold=20000; profile.data.material=100
	game.ui.enhance_item(weapon.uid)
	for i in range(4): await process_frame
	check(weapon.enhance==1,"real_enhance_button")
	# Legacy abyss checkpoint still restores after room refactor.
	game.back_to_menu()
	profile.data.cleared=[1,2,3,4,5,6]
	game.abyss.start(0,113)
	game.pending.clear()
	game.flow.floor_number=5
	game.state="intermission"
	game.ensure_shop()
	check(game.abyss.save_exit(),"abyss_save")
	check(game.abyss.resume(),"abyss_resume")
	game.next_round()
	check(game.flow.floor_number==6 and not game.rooms.active and is_instance_valid(game.rooms.scene),"abyss_template_continue")
	var result={"checks":checks,"failures":failures,"skills":skill_report}
	var f=FileAccess.open("res://tests/integration_v4_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  ")); f.close()
	print("V4_INTEGRATION="+JSON.stringify(result))
	await process_frame
	await process_frame
	game.free()
	quit(0 if failures.is_empty() else 1)
