extends SceneTree

func _initialize() -> void:
 call_deferred("configure")

func configure() -> void:
 var game = load("res://scenes/Main.tscn").instantiate()
 game.test_mode = true
 root.add_child(game)
 for action in ["move_left","move_right","move_up","move_down","dash","skill","skill_2","skill_3","skill_4","reload","item_1","item_2","item_3","attack"]:
  ProjectSettings.set_setting("input/"+action,{"deadzone":0.2,"events":InputMap.action_get_events(action)})
 ProjectSettings.set_setting("application/config/version","0.2.0")
 ProjectSettings.set_setting("display/window/stretch/aspect","keep")
 ProjectSettings.save()
 game.free()
 quit()
