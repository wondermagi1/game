extends Node
## 无外部音频依赖的短合成占位音效，后续可直接替换为音频资源。
var clips: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor: int = 0
var volume: float = 0.35
var master_volume: float = 1.0
var last_play: Dictionary = {}

func _ready() -> void:
	var pitches = {"sword":780.0,"gun":110.0,"bow":480.0,"hit":300.0,"crit":980.0,"hurt":90.0,"dash":650.0,"reload":240.0,"skill":420.0,"reward":880.0,"boss":70.0,"win":1040.0,"lose":130.0,"combo_sword":620.0,"combo_gun":65.0,"combo_bow":1150.0,"explosion":85.0,"achievement":1320.0}
	for role in range(3):
		clips["ultimate_%d_start"%role] = layered(role,0,0.55)
		clips["ultimate_%d_loop"%role] = layered(role,1,0.18)
		clips["ultimate_%d_finish"%role] = layered(role,2,0.8)
	clips["giant_sword"] = layered(0,2,0.35)
	clips["giant_arrow"] = layered(2,2,0.35)
	clips["ui_hover"] = synth(720,.035)
	clips["ui_click"] = synth(560,.07)
	clips["forge"] = layered(0,2,.48)
	clips["train"] = layered(2,0,.42)
	clips["boss_intro"] = layered(1,0,1.15)
	clips["boss_finish"] = layered(1,2,.75)
	for key in pitches: clips[key] = synth(pitches[key],0.45 if key.begins_with("combo") or key in ["explosion","achievement"] else (0.12 if key!="boss" else 0.35))
	for i in range(10):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func synth(freq: float, duration: float) -> AudioStreamWAV:
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples = int(22050 * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t = float(i)/22050.0
		var env = pow(1.0-float(i)/samples,2.0) * minf(1.0,t*250)
		var wave = sin(TAU*freq*t*(1.0-t*1.5))*0.65 + sin(TAU*freq*2*t)*0.15
		if freq<120: wave = wave*0.6+(fmod(sin(i*12.9898)*43758.5453,1.0)-0.5)*0.7
		if duration>0.4 and freq>400: wave += sin(TAU*freq*1.5*t)*sin(t*18)*0.2
		bytes.encode_s16(i*2,int(clampf(wave*env,-1,1)*18000))
	sound.data = bytes
	return sound

func play(key: String) -> void:
	if volume*master_volume<=0 or not clips.has(key): return
	var now = Time.get_ticks_msec()
	if now-int(last_play.get(key,-10000))<(220 if key.begins_with("combo") else 45): return
	last_play[key] = now
	var voice = voices[9 if key.begins_with("combo") or key=="achievement" or key.ends_with("finish") else cursor%9]
	cursor += 1
	voice.stream = clips[key]
	voice.volume_db = linear_to_db(volume*master_volume*(.20 if key=="ui_hover" else (.45 if key=="ui_click" else 1.0)))
	voice.play()


func layered(role: int, phase: int, duration: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data = PackedByteArray()
	var count = int(duration*22050)
	data.resize(count*2)
	var frequencies = [260.0,85.0,540.0]
	for i in range(count):
		var t = i/22050.0
		var p = t/duration
		var env = sin(PI*minf(1,t*45))*0.15+pow(1-p,2)*minf(1,t*100)
		var pitch = frequencies[role]*(1+p*1.5 if phase==0 else 1-p*0.6)
		var metallic = sin(TAU*pitch*t)*0.35+sin(TAU*pitch*2.01*t)*0.12+sin(TAU*pitch*3.98*t)*0.07
		var noise = (fposmod(sin(i*12.9898)*43758.5453,1)-0.5)*exp(-p*8)
		var sub = sin(TAU*(52 if role==1 else 85)*t)*exp(-p*5)
		var wave = metallic+noise*(0.8 if role==1 else 0.25)+sub*(0.5 if phase==2 else 0.12)
		data.encode_s16(i*2,int(clampf(wave*env,-1,1)*23000))
	stream.data = data
	return stream
