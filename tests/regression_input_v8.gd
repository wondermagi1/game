extends SceneTree

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

func setup_role(role: int) -> void:
	game.profile.data.unlocked = 6
	game.profile.data.roles[role].level = 30
	game.profile.data.roles[role].skills = [10,10,10,10]
	game.start_run(role,8700+role,1)
	game.player.manual_control = true
	game.player.invulnerable = 999
	game.state = "combat"
	game.player.attack_clock = 0

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.sound.volume = 0
	game.profile.memory_only = true
	game.profile.fresh()
	setup_role(0)
	var p = game.player
	p.action_recovery = 0.1
	var before = game.projectiles.size()
	check(not p.request_attack(),"attack during recovery enters buffer")
	check(p.attack_buffer>0,"attack buffer receives a short grace window")
	p.action_recovery = 0
	p.tick_action_buffers()
	check(game.projectiles.size()>before,"buffered attack fires after recovery")
	check(p.attack_buffer==0,"successful buffered attack clears queue")
	check(p.action_recovery>0 and p.action_recovery<=0.16,"attack applies rate-scaled recovery")

	p.attack_clock = 0
	p.action_recovery = 0.1
	p.skills.cooldowns[0] = 0
	check(not p.request_skill(0),"skill during attack recovery enters buffer")
	check(p.skill_buffer==0 and p.skill_buffer_time>0,"skill buffer records requested slot")
	p.action_recovery = 0
	p.tick_action_buffers()
	check(p.skills.cooldowns[0]>0,"buffered skill casts when recovery ends")
	check(p.skill_buffer==-1,"successful buffered skill clears queue")

	p.skills.cooldowns[1] = 0.18
	p.action_recovery = 0.1
	check(not p.request_skill(1) and p.skill_buffer==1,"nearly ready skill can be buffered")
	p.skills.cooldowns[1] = 0
	p.action_recovery = 0
	p.tick_action_buffers()
	check(p.skills.cooldowns[1]>0,"near-cooldown buffer casts on readiness")
	p.skill_buffer = -1
	p.skill_buffer_time = 0
	check(not p.request_skill(7) and p.skill_buffer==-1,"invalid skills never occupy buffer")

	setup_role(1)
	p = game.player
	p.ammo = 2
	p.reload()
	check(p.reload_time>0,"gunner begins reload")
	p.action_recovery = 0.2
	p.attack_buffer = 0.1
	p.skill_buffer = 0
	p.skill_buffer_time = 0.1
	check(p.dash(Vector2.RIGHT),"dodge remains available as defensive cancel")
	check(p.reload_time==0 and p.ammo==2,"dodge cancels reload without granting ammunition")
	check(p.action_recovery==0,"dodge cancels action recovery")
	check(p.attack_buffer==0 and p.skill_buffer==-1,"dodge clears queued actions")
	check(p.dash_time>0 and p.invulnerable>0,"dodge still grants movement and protection")

	setup_role(2)
	p = game.player
	p.action_recovery = 0
	check(p.request_attack(),"free action fires immediately")
	check(not p.request_attack() and p.attack_buffer>0,"repeat attack during cadence is buffered")

	var report = {"checks":checks,"failures":failures}
	var file = FileAccess.open("res://tests/regression_input_v8_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("INPUT_V8_REGRESSION="+JSON.stringify(report))
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
