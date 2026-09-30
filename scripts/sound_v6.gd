extends "res://scripts/sound.gd"
## Licensed source layers + restrained synthesis for magic. Separate cosmetic RNG.
var variations: Dictionary={}
var foley: Array[AudioStreamPlayer]=[]
var sound_rng=RandomNumberGenerator.new()
var game
var previous_state: String=""
var variants_played: Dictionary={}
func _ready() -> void:
	super._ready()
	sound_rng.seed=60221
	for bus in ["Combat","UI","Ambience","Music"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus);AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	if AudioServer.get_bus_effect_count(0)==0:
		var limiter=AudioEffectLimiter.new();limiter.ceiling_db=-1;limiter.threshold_db=-4
		AudioServer.add_bus_effect(0,limiter)
	variations={"sword":["drawKnife1","drawKnife2","drawKnife3"],"bow":["creak1","creak2","creak3"],"gun":["explosionCrunch_000","explosionCrunch_001","explosionCrunch_002"],"hit":["impactWood_medium_000","impactWood_medium_001","impactWood_medium_002"],"crit":["impactMetal_light_000","impactMetal_light_001","impactMetal_light_002"],"reload":["metalClick","metalLatch","beltHandle1"],"explosion":["explosionCrunch_000","explosionCrunch_001","explosionCrunch_002"],"lulu_bubble":["slime_000","slime_001"],"lulu_splash":["slime_001","slime_000"]}
	# All imported streams are shared; there are only fourteen extra mix voices.
	for key in variations:
		var array=[]
		for name in variations[key]:
			var path="res://audio/v6/"+name+".ogg"
			if ResourceLoader.exists(path):array.append(load(path))
		variations[key]=array
	for i in range(14):
		var voice=AudioStreamPlayer.new();voice.bus="Combat";add_child(voice);foley.append(voice)
	clips["lulu_bubble"]=clips.gun;clips["lulu_splash"]=clips.gun
func source_key(key: String) -> String:
	if key.begins_with("combo_"):return "explosion" if key.ends_with("gun") else ("sword" if key.ends_with("sword") else "bow")
	if key.begins_with("ultimate_"):return ["sword","explosion","bow"][int(key.split("_")[1])]
	if key=="giant_sword":return "sword"
	if key=="giant_arrow":return "bow"
	return key
func uses_classic_audio(key: String) -> bool:
	# Player feedback: restore V5 gun and bow voices, including every ultimate phase.
	# Keep V6 sword, Lulu and UI audio; shared impact keys follow the current role.
	if key in ["gun","reload","combo_gun","bow","giant_arrow","combo_bow"]:return true
	if key.begins_with("ultimate_1_") or key.begins_with("ultimate_2_"):return true
	if game!=null and is_instance_valid(game.player):
		var role: int=game.player.stats.role
		if key in ["hit","crit"] and role in [1,2]:return true
		if key=="explosion" and role==1:return true
	return false
func play(key: String) -> void:
	if volume*master_volume<=0:return
	if uses_classic_audio(key):
		# No added creaking wood, long explosion sample or layered duplicate.
		for voice in voices:voice.bus="Combat"
		super.play(key)
		return
	var priority=key.begins_with("combo") or key.begins_with("ultimate") or key in ["hurt","boss_intro","achievement","boss_finish"]
	var source=source_key(key)
	if variations.has(source) and not variations[source].is_empty():
		var now=Time.get_ticks_msec()
		if now-int(last_play.get(key,-10000))<(160 if priority else 55):return
		last_play[key]=now
		var pool: Array=variations[source]
		var index=sound_rng.randi_range(0,pool.size()-1)
		if pool.size()>1 and index==variants_played.get(key,-1):index=(index+1)%pool.size()
		variants_played[key]=index
		var voice=foley[12+(cursor%2) if priority else cursor%12];cursor+=1
		voice.stream=pool[index];voice.pitch_scale=sound_rng.randf_range(.94,1.06)*(0.8 if key.ends_with("finish") else 1)
		var gain=1.0
		if source=="sword":gain=[4.0,3.0,1.2][index%3]
		voice.volume_db=linear_to_db(maxf(.0001,volume*master_volume*(.7 if source in ["gun","explosion"] else .75)*gain))
		voice.set_meta("remaining",.26 if source=="gun" and not priority else 3.0)
		voice.set_meta("level",voice.volume_db)
		voice.play()
		if priority or source in ["sword","bow"]:
			# A quiet magic resonator behind real foley, not the entire attack sound.
			var extra=voices[9 if priority else cursor%8]
			extra.bus="Combat";extra.stream=clips.get(key,clips.skill);extra.volume_db=linear_to_db(maxf(.0001,volume*master_volume*.24));extra.play()
		return
	for voice in voices:voice.bus="UI" if key.begins_with("ui") or key in ["forge","train","reward"] else "Combat"
	super.play(key)
func _process(delta: float) -> void:
	for voice in foley:
		if voice.playing:
			var time: float=voice.get_meta("remaining",3.0)-delta
			voice.set_meta("remaining",time)
			if time<.04:voice.volume_db=float(voice.get_meta("level",-10))+linear_to_db(maxf(.001,time/.04))
			if time<=0:voice.stop()
	if game==null:return
	if game.state!=previous_state:
		if game.state not in ["combat","end","cinematic"]:
			for voice in foley:voice.stop()
			for voice in voices:
				if voice.bus=="Combat":voice.stop()
		previous_state=game.state
func stop_all() -> void:
	for voice in foley:voice.stop()
	for voice in voices:voice.stop()
