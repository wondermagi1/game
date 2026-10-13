extends SceneTree
var game
var checks: int = 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note); push_error(note)
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	root.size = Vector2i(1920,1080)
	var sound = game.sound
	sound.volume = 0
	sound.music_volume = 0
	var music = sound.music_player
	check(music.stream is AudioStreamMP3,"user MP3 decodes")
	check(music.stream.get_length()>30,"full music track loaded")
	check(music.stream.loop and music.stream.loop_offset==0,"whole track loops from its beginning")
	sound.start_music()
	await create_timer(.1).timeout
	check(music.playing,"music starts")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"zero music volume mutes independently")
	music.seek(8)
	game.ui.show_settings(false)
	game.state = "paused"
	sound.stop_all()
	await create_timer(.1).timeout
	check(music.playing and music.get_playback_position()>=8,"pause and settings preserve playback")
	game.back_to_menu()
	await create_timer(.1).timeout
	check(music.get_playback_position()>=8,"menu navigation does not restart track")
	music.seek(music.stream.get_length()-.1)
	await create_timer(.55).timeout
	check(music.playing and music.get_playback_position()<2,"decoder loops at actual track end")
	sound.music_volume = .37
	sound.master_volume = 0
	sound.refresh_music_gain()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"master mute also silences music")
	game.ui.show_settings(false)
	var slider = game.ui.overlay.get_node("MusicVolume")
	slider.value = .26
	check(is_equal_approx(sound.music_volume,.26) and sound.volume==0,"music slider does not change effects")
	# This script must be run with isolated APPDATA, as documented in the report.
	game.test_mode = false
	game.save_settings()
	sound.music_volume = .91
	game.load_settings()
	check(is_equal_approx(sound.music_volume,.26),"music volume survives settings save/load")
	game.test_mode = true
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.erase_section_key("settings","music")
	config.save("user://settings.cfg")
	game.test_mode = false
	game.load_settings()
	check(is_equal_approx(sound.music_volume,.4),"old settings without a music key receive default")
	game.test_mode = true
	sound.master_volume = 1
	sound.music_volume = 0
	sound.refresh_music_gain()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"effects can remain available with music muted")
	game.ui.show_settings(false)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screenshots-western/12-music-settings.png")
	var report = {"checks":checks,"failures":failures,"track_seconds":music.stream.get_length()}
	FileAccess.open("res://tests/music_bgm_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MUSIC_BGM="+JSON.stringify(report))
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
