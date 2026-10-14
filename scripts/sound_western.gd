extends "res://scripts/sound_v6.gd"
## Short physical sources, independent cosmetic RNG and bounded priority voices.
const BANK = {
	"sword":["sword_0","sword_1","sword_2"],"bow":["bow"],
	"gun":["gun_0","gun_1","gun_2"],"explosion":["gun_heavy"],
	"hit":["body_hit"],"hit_flesh":["body_hit"],"hit_metal":["metal_hit"],"crit":["metal_hit"],
	"reload":["reload_0","reload_1"],"dash":["dash"],"hurt":["body_hit"],
	"giant_sword":["sword_2"],"giant_arrow":["bow"],
	"combo_sword":["sword_2"],"combo_gun":["gun_heavy"],"combo_bow":["bow"],
	"ultimate_0_start":["magic_charge"],"ultimate_0_loop":["sword_0","sword_1"],"ultimate_0_finish":["magic_release"],
	"ultimate_1_start":["reload_1"],"ultimate_1_loop":["gun_0","gun_2"],"ultimate_1_finish":["gun_heavy"],
	"ultimate_2_start":["magic_charge"],"ultimate_2_loop":["bow"],"ultimate_2_finish":["magic_release"],
	"reward":["coin"],"forge":["metal_hit"],"train":["magic_release"],
	"monster_organic":["monster_organic"],"monster_heavy":["monster_heavy"],"monster_insect":["monster_insect"],
	"boss":["monster_heavy"],"boss_intro":["magic_charge"],"boss_finish":["magic_release"],
	"ui_hover":["ui_click"],"ui_click":["ui_click"],"ui_confirm":["coin"],
	"lulu_bubble":["bubble"],"lulu_splash":["splash"]
}
var curated: Dictionary = {}
var played_keys: Dictionary = {}
var music_player: AudioStreamPlayer
var music_volume: float = .4
var music_fade: float = 0.0

func start_music() -> void:
	if music_player.playing: return
	music_fade = 0.0
	refresh_music_gain()
	music_player.play()

func refresh_music_gain() -> void:
	if music_player==null: return
	var gain = clampf(music_volume,0.0,1.0)*clampf(master_volume,0.0,1.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),gain<=0.0)
	music_player.volume_db = linear_to_db(maxf(.0001,gain*music_fade))

func _ready() -> void:
	super._ready()
	# One persistent stream spans menu, rooms, pause and results without restarting.
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.bus = "Music"
	var track = load("res://audio/music/moment-of-peace.mp3").duplicate() as AudioStreamMP3
	track.loop = true
	track.loop_offset = 0.0
	music_player.stream = track
	add_child(music_player)
	for key in BANK:
		var streams: Array[AudioStream] = []
		for filename in BANK[key]: streams.append(load("res://audio/western/%s.wav"%filename))
		curated[key] = streams

func play(key: String) -> void:
	if volume*master_volume<=0: return
	if not curated.has(key):
		# The shared skill cue deliberately uses the earlier 0.12 s sound.gd clip.
		# Do not layer the western magic_release rumble over every role's cast.
		super.play(key)
		return
	var ui_sound = key.begins_with("ui_") or key in ["reward","forge","train"]
	var creature = key.begins_with("monster_")
	var impact = key in ["hit","hit_flesh","hit_metal","crit"]
	var priority = key.begins_with("combo") or key.ends_with("finish") or key in ["hurt","boss_intro"]
	var group = "creature" if creature else ("impact" if impact else key)
	var spacing = 650 if creature else (95 if impact else (110 if priority else 45))
	var now = Time.get_ticks_msec()
	if now-int(last_play.get(group,-10000))<spacing: return
	last_play[group] = now
	var pool: Array = curated[key]
	var index = sound_rng.randi_range(0,pool.size()-1)
	if pool.size()>1 and index==variants_played.get(key,-1): index=(index+1)%pool.size()
	variants_played[key] = index
	var slot = 10+cursor%2 if ui_sound else (12+cursor%2 if priority else cursor%10)
	cursor += 1
	var voice = foley[slot]
	voice.bus = "UI" if ui_sound else "Combat"
	voice.stream = pool[index]
	voice.pitch_scale = sound_rng.randf_range(.975,1.025)
	if key in ["giant_sword","giant_arrow"] or key.begins_with("combo"): voice.pitch_scale *= .86
	var gain = .5 if impact else (.44 if creature else (.22 if key=="ui_hover" else .88))
	voice.volume_db = linear_to_db(maxf(.0001,volume*master_volume*gain))
	voice.set_meta("remaining",voice.stream.get_length()/voice.pitch_scale+.04)
	voice.set_meta("level",voice.volume_db)
	voice.play()
	played_keys[key] = int(played_keys.get(key,0))+1

func enemy_voice(kind: int) -> void:
	if kind==14: play("lulu_bubble")
	elif kind in [3,4,5,6,12]: play("hit_metal")
	elif kind==10: play("monster_insect")
	elif kind in [7,13]: play("monster_heavy")
	else: play("monster_organic")

func _process(delta: float) -> void:
	music_fade = minf(1.0,music_fade+delta/.8)
	refresh_music_gain()
	for voice in foley:
		if not voice.playing: continue
		var remaining = float(voice.get_meta("remaining",1.0))-delta
		voice.set_meta("remaining",remaining)
		if remaining<.04: voice.volume_db=float(voice.get_meta("level",-10))+linear_to_db(maxf(.001,remaining/.04))
		if remaining<=0 or volume*master_volume<=0: voice.stop()
	if game!=null and game.state!=previous_state:
		if game.state not in ["combat","end","cinematic"]:
			for voice in foley+voices:
				if voice.bus=="Combat": voice.stop()
		previous_state = game.state
