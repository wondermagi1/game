extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var results=[];var all=PackedByteArray()
	var names=["explosionCrunch_000","explosionCrunch_001","explosionCrunch_002","drawKnife1","drawKnife2","drawKnife3","creak1","creak2","creak3","slime_000"]
	for name in names:
		var stream=load("res://audio/v6/"+name+".ogg")
		var playback=stream.instantiate_playback();playback.start()
		var count=int(minf(1.5,stream.get_length())*AudioServer.get_mix_rate())
		var data=playback.mix_audio(1,count)
		var peak: float=0;var energy: float=0
		for sample in data:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)));energy+=sample.length_squared()/2
		results.append({"name":name,"duration":stream.get_length(),"peak":peak,"rms":sqrt(energy/maxi(1,data.size()))})
		for i in range(0,data.size(),4):
			var index=all.size();all.resize(index+2);all.encode_s16(index,int(clampf((data[i].x+data[i].y)*.32,-1,1)*32767))
		var silence=PackedByteArray();silence.resize(2205*2);all.append_array(silence)
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=int(AudioServer.get_mix_rate()/4);wav.data=all
	wav.save_to_wav("res://../v6-audio-source-review.wav")
	var file=FileAccess.open("res://tests/audio_v6_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "))
	print("AUDIO_V6="+JSON.stringify(results));quit()
