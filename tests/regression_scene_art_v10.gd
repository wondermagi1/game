extends SceneTree

var checks := 0
var failures: Array[String] = []
const Room = preload("res://scripts/room_template.gd")

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func run() -> void:
	check(Room.SCENE_BACKGROUNDS.size()==6,"six chapter backgrounds are registered")
	for theme in range(6):
		var path: String = Room.SCENE_BACKGROUNDS[theme]
		check(ResourceLoader.exists(path),"theme %d background exists"%theme)
		var texture: Texture2D = load(path)
		check(texture!=null,"theme %d background loads"%theme)
		if texture!=null:
			check(texture.get_width()>=1600 and texture.get_height()>=900,"theme %d background has full-screen source detail"%theme)
		var room = load("res://scenes/rooms/open.tscn").instantiate()
		room.theme = theme
		root.add_child(room)
		await process_frame
		check(room.scene_background==texture,"theme %d routes to its own background"%theme)
		check(room.has_node("SceneAtmosphere"),"theme %d has a dynamic atmosphere layer"%theme)
		if room.has_node("SceneAtmosphere"):
			check(room.get_node("SceneAtmosphere").motes.size()==34,"theme %d ambient particles stay inside budget"%theme)
		room.free()
	var result={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_scene_art_v10_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("SCENE_ART_V10_REGRESSION="+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
