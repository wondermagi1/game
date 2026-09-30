extends SceneTree
const Scene = preload("res://scenes/Main.tscn")
var game

func _initialize() -> void:
 call_deferred("run_capture")

func shot(name: String) -> void:
 for i in range(4): await process_frame
 await RenderingServer.frame_post_draw
 var path = ProjectSettings.globalize_path("res://../v2-"+name+".png")
 root.get_texture().get_image().save_png(path)
 print("CAPTURE "+path)

func run_capture() -> void:
 game = Scene.instantiate()
 game.test_mode = true
 root.add_child(game)
 await shot("menu")
 game.ui.show_select()
 await shot("characters")
 game.profile.data.unlocked = 4
 game.ui.show_chapters()
 await shot("chapters")
 game.profile.data.gold = 2600
 game.profile.data.material = 100
 game.profile.data.roles[0].level = 20
 for i in range(12):
  var item = game.profile.make_item(0,i%6,i%4,1+(i%3)*4,game.rng)
  item.enhance = i%5
  game.profile.receive_item(item)
  if i<6: game.profile.equip(0,item.uid)
  game.ui.selected_uid = item.uid
 game.state = "menu"
 game.ui.show_equipment()
 await shot("equipment")
 game.ui.show_talents()
 await shot("talents")
 game.ui.codex_category = 2
 game.ui.show_codex()
 await shot("codex")
 game.start_run(0,778,3)
 game.begin_wave()
 game.pending.clear()
 game.player.manual_control = true
 game.progress_delay = 999
 game.player.position = Vector2(850,590)
 game.player.aim = Vector2.RIGHT
 game.player.stats.apply(game.Data.UPGRADES[2])
 game.player.stats.apply(game.Data.UPGRADES[4])
 game.player.stats.apply(game.Data.UPGRADES[15])
 for i in range(10):
  var enemy = game.spawn_enemy(i%4,Vector2(420+(i%5)*260,330+floori(i/5.0)*400),i==8)
  enemy.state = "move"
  enemy.cooldown = 5
 game.player.use_skill(0)
 game.player.use_skill(1)
 game.player.use_skill(3)
 game.player.attack()
 for i in range(12): await physics_frame
 await shot("combat")
 game.pause_game()
 game.ui.show_characters()
 await shot("buffs")
 game.state = "reward"
 game.rewards = game.player.stats.reward_choices(game.rng,game.player.hp)
 game.ui.show_rewards(game.rewards)
 await shot("rewards")
 game.state = "intermission"
 game.flow.round_number = 3
 game.flow.runes.assign([0,1,2])
 game.ui.show_intermission()
 await shot("intermission")
 game.ui.show_shop()
 await shot("shop")
 game.state = "combat"
 game.end_run(true)
 await shot("result")
 game.free()
 quit()
